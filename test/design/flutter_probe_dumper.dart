// test/design/flutter_probe_dumper.dart — the Dart half of the Flutter
// design-fidelity gate (E06-T01). Walks a pumped widget's Element tree and
// writes a JSON dump with the SAME field names/units the DOM probe
// (design/tools/lib/probe.mjs) writes into design/golden/<screen>/probe.json,
// so design/tools/lib/compare.mjs runs UNCHANGED against either source.
//
// Honest limits (see docs/design-gate-flutter.md §6 for the full writeup):
//   - this measures the WIDGET TREE, not a rendered device frame — no real
//     font shaping, no OS insets, no screenshot.
//   - devicePixelRatio is pinned to 1.0 so logical pixels here equal the CSS
//     pixels design/screens/*.md contracts were measured at. If a future
//     screen needs a different DPR, pin it explicitly and say so in the run.
//   - role mapping only covers the common cases (button/textbox/heading-less
//     generic/surface). See docs/design-gate-flutter.md's mapping table.
//   - icon widgets are matched to the design's icon-font glyph text via a
//     small name map (`_iconNames` below) — both sides draw from the same
//     Material Symbols font, so `Icons.search` legitimately corresponds to
//     the design's literal "search" glyph text. Icons outside the map dump
//     with empty text (a real, recorded finding), never a guessed string.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_process_button_widget/on_process_button_widget.dart';

/// One probe element — mirrors `probe.mjs`'s per-element shape exactly.
class _ProbeElement {
  _ProbeElement({
    required this.role,
    required this.text,
    required this.box,
    required this.surface,
    required this.style,
    this.placeholder = '',
    this.alt = '',
    this.disabled = false,
  });

  final String role;
  final String text;
  final Map<String, num> box; // {x, y, w, h}
  final bool surface;
  final Map<String, String> style;
  final String placeholder;
  final String alt;
  final bool disabled;

  Map<String, dynamic> toJson() => {
        'tag': role.toUpperCase(),
        'role': role,
        'text': text,
        'depth': 0,
        'type': '',
        'name': '',
        'placeholder': placeholder,
        'alt': alt,
        'required': false,
        'disabled': disabled,
        'surface': surface,
        'box': box,
        'style': style,
      };
}

/// Material icon constant -> its icon-font ligature name, keyed by
/// `IconData.codePoint` (not the `IconData` object itself — it overrides
/// `==`/`hashCode`, which the analyzer rejects as a *const*-map key; this map
/// is built once at first use instead). Both the design's icon-font spans
/// and Flutter's `Icons.*` constants draw from the same Material Symbols
/// font, so this correspondence is real, not a guess. Extend as new screens
/// introduce new icons (T10/T11/T12).
final Map<int, String> _iconNames = {
  Icons.hub.codePoint: 'hub',
  Icons.lock.codePoint: 'lock',
  Icons.search.codePoint: 'search',
  Icons.devices.codePoint: 'devices',
  Icons.more_vert.codePoint: 'more_vert',
  Icons.check_circle.codePoint: 'check_circle',
  Icons.radio_button_checked.codePoint: 'radio_button_checked',
  Icons.warning.codePoint: 'warning',
  Icons.block.codePoint: 'block',
  Icons.dashboard.codePoint: 'dashboard',
  Icons.chat.codePoint: 'chat',
  Icons.router.codePoint: 'router',
  Icons.settings.codePoint: 'settings',
  Icons.laptop_mac.codePoint: 'laptop_mac',
  Icons.smartphone.codePoint: 'smartphone',
  Icons.desktop_windows.codePoint: 'desktop_windows',
  Icons.send.codePoint: 'send',
  Icons.attach_file.codePoint: 'attach_file',
  Icons.arrow_back.codePoint: 'arrow_back',
  Icons.close.codePoint: 'close',
  Icons.add.codePoint: 'add',
  Icons.done.codePoint: 'done',
  Icons.error.codePoint: 'error',
  Icons.mic.codePoint: 'mic',
  Icons.person.codePoint: 'person',
  Icons.notifications.codePoint: 'notifications',
  Icons.security.codePoint: 'security',
  Icons.storage.codePoint: 'storage',
  Icons.battery_full.codePoint: 'battery_full',
  Icons.info.codePoint: 'info',
};

String? _iconName(IconData? icon) => icon == null ? null : _iconNames[icon.codePoint];

/// Pumps [screen] at [viewport] with a pinned devicePixelRatio, walks its
/// Element tree, and writes `build/design-probe/<screenId>.json`.
///
/// The caller is responsible for wiring the screen's own DI (GetX bindings,
/// repositories, fixture data) exactly as an ordinary widget test would —
/// this function only pumps, walks and dumps.
Future<void> dumpScreenProbe(
  WidgetTester tester, {
  required String screenId,
  required Widget screen,
  Size viewport = const Size(390, 844),
}) async {
  const dpr = 1.0; // pinned — see file header. Asserted below, not silently assumed.
  tester.view.physicalSize = Size(viewport.width * dpr, viewport.height * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  assert(tester.view.devicePixelRatio == dpr);

  await tester.pumpWidget(screen);
  // A BOUNDED settle. A screen with a genuine render defect — e.g. a
  // RenderFlex overflow that keeps re-triggering layout — can leave the
  // tree never settling; an unbounded `pumpAndSettle()` there hangs the
  // entire dumper (and, transitively, `make design-probe` and every test
  // after it in the same file/suite run). `pumpAndSettle`'s own `timeout`
  // argument bounds that: if the tree hasn't settled within 5s, fall back
  // to a small fixed number of plain `pump()`s so whatever DID render is
  // still walked and dumped, rather than the probe producing nothing at
  // all. See docs/design-gate-flutter.md §6.
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  } on FlutterError {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
  // A real RenderFlex overflow (or any other framework-recorded error) means
  // the render tree is in a state the framework itself gave up trying to
  // lay out cleanly. Walking it anyway is not just unreliable — it hangs.
  // Reproduced against `devices` (E06-T01 Run log): the overflow here is
  // INSIDE the screen's own `Scaffold` (a bottom-nav `Row`), so scoping the
  // walk to the first `Scaffold` does not avoid it — `_walk` still reaches
  // the broken subtree, and something under repeated failed relayout (most
  // likely `RenderBox.localToGlobal` on a `RenderObject` the layout phase
  // never finished with) does not return, past any bounded `pumpAndSettle`.
  // So: detect the error BEFORE draining it, and skip the walk entirely when
  // one was recorded — this is a finding about the SCREEN UNDER TEST (record
  // it honestly in the dump as `renderError`), not something a probe-harness
  // walk can safely attempt to compare element-by-element anyway.
  final hadRenderError = tester.takeException() != null;
  // Drain any further queued exception so `TestWidgetsFlutterBinding` does
  // not rethrow it when this test ends.
  while (tester.takeException() != null) {}

  final elements = <_ProbeElement>[];
  final tokens = <String, Map<String, int>>{
    'color': {}, 'background': {}, 'fontFamily': {}, 'fontSize': {},
    'fontWeight': {}, 'radius': {}, 'borderColor': {}, 'shadow': {}, 'spacing': {},
  };
  void bump(String group, String? key) {
    if (key == null || key.isEmpty || key == 'none' || key == '0px') return;
    final m = tokens[group]!;
    m[key] = (m[key] ?? 0) + 1;
  }

  if (!hadRenderError) {
    // Walk from the screen's own `Scaffold`, not `tester.binding.rootElement`.
    // `screen` is pumped inside a full `GetMaterialApp`/`Navigator`/`Overlay`
    // shell (routing + overlay-entry machinery a rendered web page's DOM has
    // no equivalent of); scoping to the first `Scaffold` walks exactly the
    // screen's own content (what `probe.mjs` gets from `document.body` on
    // the DOM side). A screen with no `Scaffold` falls back to the full root.
    final scaffoldFinder = find.byType(Scaffold);
    final Element? rootElement = scaffoldFinder.evaluate().isNotEmpty
        ? scaffoldFinder.evaluate().first
        : tester.binding.rootElement;
    // Reset per call — `_walkVisitCount` is a top-level guard shared across
    // every `dumpScreenProbe` call in a test file/isolate, and this file's
    // own suite calls it ~7 times. Without a reset here, an early screen's
    // visits would count against a later, unrelated screen's budget.
    _walkVisitCount = 0;
    if (rootElement != null) {
      _walk(rootElement, elements, bump, insideInteractive: false);
    }
  }

  final dump = {
    'url': '/$screenId',
    'title': screenId,
    'viewport': {'w': viewport.width, 'h': viewport.height},
    'scrollHeight': viewport.height,
    'elements': elements.map((e) => e.toJson()).toList(),
    'tokens': tokens,
    if (hadRenderError) 'renderError': true,
  };

  // Real dart:io File/Directory operations must run through `runAsync` — the
  // default `AutomatedTestWidgetsFlutterBinding` used by `testWidgets` never
  // delivers their real OS-level completion callbacks otherwise, so an
  // ordinary `await` on them hangs forever (found directly: even a bare
  // `Directory(...).create(recursive: true)` with no relation to the pumped
  // screen hung the same way; this was misdiagnosed earlier in this task's
  // own history as a `devices_view.dart` RenderFlex-overflow pathology,
  // which is what led to raising E06-B01 — that screen bug was real and
  // worth fixing, but it was never the cause of the harness hang).
  final outPath = 'build/design-probe/$screenId.json';
  final file = File(outPath);
  await tester.runAsync(() async {
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(dump));
  });
}

// ── The walk ─────────────────────────────────────────────────────────────

bool _isInteractive(Widget w) {
  return w is GestureDetector ||
      w is InkWell ||
      w is InkResponse ||
      w is IconButton ||
      w is TextButton ||
      w is ElevatedButton ||
      w is OutlinedButton ||
      w is OnProcessButtonWidget;
}

Map<String, num>? _boxOf(Element element) {
  final ro = element.renderObject;
  if (ro is! RenderBox || !ro.hasSize) return null;
  if (!ro.attached) return null;
  final Offset origin;
  try {
    origin = ro.localToGlobal(Offset.zero);
  } catch (_) {
    return null;
  }
  final size = ro.size;
  if (size.width <= 0 || size.height <= 0) return null;
  return {
    'x': origin.dx.round(),
    'y': origin.dy.round(),
    'w': size.width.round(),
    'h': size.height.round(),
  };
}

String _cssColor(Color c) {
  final r = (c.r * 255).round();
  final g = (c.g * 255).round();
  final b = (c.b * 255).round();
  final a = c.a;
  if (a >= 0.999) return 'rgb($r, $g, $b)';
  final aStr = (a * 1000).round() / 1000;
  return 'rgba($r, $g, $b, $aStr)';
}

String _pxStr(double v) {
  final rounded = (v * 100).round() / 100;
  final asInt = rounded.round();
  if (asInt == rounded) return '${asInt}px';
  return '${rounded}px';
}

int _weightOf(FontWeight? w) => w == null ? 400 : w.value;

/// A decoration this run cares about: color + uniform border + uniform
/// radius. Anything richer (gradients, per-corner radii) reads as its
/// dominant/top-left value — matching `probe.mjs`'s own borderTopLeftRadius
/// simplification.
class _Deco {
  _Deco({this.color, this.borderWidth = 0, this.borderColor, this.radius = 0});
  final Color? color;
  final double borderWidth;
  final Color? borderColor;
  final double radius;
}

_Deco? _decorationOf(Widget w) {
  BoxDecoration? bd;
  Color? plainColor;
  if (w is Container) {
    plainColor = w.color;
    if (w.decoration is BoxDecoration) bd = w.decoration as BoxDecoration;
  } else if (w is DecoratedBox) {
    if (w.decoration is BoxDecoration) bd = w.decoration as BoxDecoration;
  } else {
    return null;
  }
  if (bd == null && plainColor == null) return null;
  double radius = 0;
  if (bd?.shape == BoxShape.circle) {
    radius = -1; // signal: derive from box size (w/2) at capture time
  } else if (bd?.borderRadius is BorderRadius) {
    radius = (bd!.borderRadius as BorderRadius).topLeft.x;
  }
  double borderWidth = 0;
  Color? borderColor;
  final border = bd?.border;
  if (border is Border) {
    borderWidth = border.top.width;
    borderColor = border.top.color;
  }
  return _Deco(
    color: bd?.color ?? plainColor,
    borderWidth: borderWidth,
    borderColor: borderColor,
    radius: radius,
  );
}

/// Bounded scan for the first decoration in [element]'s subtree, stopping at
/// a nested interactive widget (that widget owns its own decoration, if any,
/// captured separately when its turn comes).
_Deco? _findFirstDecoration(Element element) {
  _Deco? found;
  void visit(Element e) {
    if (found != null) return;
    final w = e.widget;
    if (_isInteractive(w)) return; // nested interactive owns its own subtree
    final d = _decorationOf(w);
    if (d != null) {
      found = d;
      return;
    }
    e.visitChildren(visit);
  }
  element.visitChildren(visit);
  return found;
}

/// Bounded scan collecting the plain text of every `Text` descendant, joined
/// with a single space, stopping at nested interactive widgets (their own
/// label is captured as part of THEIR own element, not this one's).
String _collectText(Element element) {
  final parts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (_isInteractive(w)) return;
    if (w is Text) {
      final t = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
      if (t.isNotEmpty) parts.add(t);
      return;
    }
    e.visitChildren(visit);
  }
  element.visitChildren(visit);
  return parts.join(' ').trim();
}

const _defaultStyle = {
  'color': 'rgb(0, 0, 0)',
  'background': 'rgba(0, 0, 0, 0)',
  'fontFamily': '',
  'fontSize': '0px',
  'fontWeight': '400',
  'radius': '0px',
  'borderWidth': '0px',
  'borderColor': 'rgba(0, 0, 0, 0)',
  'padding': '0px',
  'shadow': 'none',
  'textTransform': 'none',
};

// Defense in depth alongside the Scaffold-scoped walk root above: a hard
// cap on total elements visited so a screen with its own pathological
// subtree (not just the app-shell one that motivated scoping to Scaffold)
// still can't hang the dumper — it just truncates, which is honest and
// visible (fewer elements than the contract expects reads as `missing`
// findings), rather than never producing a dump at all.
const _maxWalkVisits = 4000;
int _walkVisitCount = 0;

bool _sameBox(Map<String, num>? a, Map<String, num>? b) {
  if (a == null || b == null) return false;
  return a['x'] == b['x'] && a['y'] == b['y'] && a['w'] == b['w'] && a['h'] == b['h'];
}

void _walk(
  Element element,
  List<_ProbeElement> out,
  void Function(String group, String? key) bump, {
  required bool insideInteractive,
  Map<String, num>? suppressDecoBox,
}) {
  if (_walkVisitCount >= _maxWalkVisits) return;
  _walkVisitCount++;
  final widget = element.widget;

  // Interactive tap targets — buttons, and (per docs/design-gate-flutter.md)
  // nav-style links too, since this dumper does not distinguish navigation
  // intent from an action button. Recorded once at the outermost interactive
  // widget; nested ones inside it are not double-captured.
  if (_isInteractive(widget) && !insideInteractive) {
    final box = _boxOf(element);
    if (box != null) {
      final text = _collectText(element);
      Color? bg;
      if (widget is OnProcessButtonWidget) bg = widget.backgroundColor;
      final deco = bg == null ? _findFirstDecoration(element) : null;
      final resolvedBg = bg ?? deco?.color;
      final radiusPx = deco?.radius == -1 ? (box['w']! / 2) : (deco?.radius ?? 0);
      final surface = resolvedBg != null && resolvedBg.a > 0;
      final style = Map<String, String>.from(_defaultStyle);
      if (resolvedBg != null) style['background'] = _cssColor(resolvedBg);
      if (deco != null) {
        style['radius'] = _pxStr(radiusPx.toDouble());
        style['borderWidth'] = _pxStr(deco.borderWidth);
        if (deco.borderColor != null) style['borderColor'] = _cssColor(deco.borderColor!);
      }
      out.add(_ProbeElement(
        role: 'button',
        text: text,
        box: box,
        surface: surface,
        style: style,
        disabled: !_enabledOf(widget),
      ));
      if (surface) {
        bump('background', style['background']);
        bump('radius', style['radius']);
      }
    }
    element.visitChildren((c) => _walk(
          c, out, bump,
          insideInteractive: true,
          suppressDecoBox: box,
        ));
    return;
  }

  if (widget is Text) {
    final t = (widget.data ?? widget.textSpan?.toPlainText() ?? '').trim();
    if (t.isNotEmpty && !insideInteractive) {
      final box = _boxOf(element);
      if (box != null) {
        final effective = DefaultTextStyle.of(element).style.merge(widget.style);
        final style = Map<String, String>.from(_defaultStyle);
        style['color'] = _cssColor(effective.color ?? const Color(0xFF000000));
        style['fontFamily'] = effective.fontFamily ?? '';
        style['fontSize'] = _pxStr(effective.fontSize ?? 14);
        style['fontWeight'] = '${_weightOf(effective.fontWeight)}';
        out.add(_ProbeElement(role: 'generic', text: t, box: box, surface: false, style: style));
        bump('color', style['color']);
        bump('fontSize', style['fontSize']);
        bump('fontWeight', style['fontWeight']);
        bump('fontFamily', style['fontFamily']);
      }
    }
    return; // Text has no descendants worth walking separately.
  }

  if (widget is Icon) {
    if (!insideInteractive) {
      final box = _boxOf(element);
      if (box != null) {
        final name = _iconName(widget.icon) ?? '';
        final style = Map<String, String>.from(_defaultStyle);
        final color = widget.color ?? IconTheme.of(element).color;
        if (color != null) style['color'] = _cssColor(color);
        out.add(_ProbeElement(
          role: 'generic',
          text: name,
          alt: widget.semanticLabel ?? '',
          box: box,
          surface: false,
          style: style,
        ));
      }
    }
    return;
  }

  if (widget is TextField || widget is TextFormField) {
    final box = _boxOf(element);
    if (box != null) {
      final isMultiline = _maxLinesOf(widget) != 1;
      out.add(_ProbeElement(
        role: isMultiline ? 'textbox:multiline' : 'textbox:text',
        text: '',
        placeholder: _hintOf(widget),
        box: box,
        surface: false,
        style: Map<String, String>.from(_defaultStyle),
        disabled: !_enabledOf(widget),
      ));
    }
    // fall through — still walk children (rare, but never lose content).
  }

  final deco = _decorationOf(widget);
  // `deco`'s own box, computed once and threaded down so a descendant with
  // the IDENTICAL box is recognized as the same visual surface.
  Map<String, num>? nextSuppressDecoBox = suppressDecoBox;
  if (deco != null) {
    final box = _boxOf(element);
    final hasFill = deco.color != null && deco.color!.a > 0;
    final hasBorder = deco.borderWidth > 0;
    // `Container` composes its own decoration via an internal `DecoratedBox`
    // descendant Element with the exact same box — walking that descendant
    // separately would double-emit the same visual surface (found directly:
    // a single fixture `Container(decoration: ...)` produced two identical
    // `surface: true` elements). Skip re-emitting when the box matches the
    // one already recorded by an ancestor in this chain; a genuinely nested
    // decorated child (a badge inside a card, say) always has a different
    // box and is still captured normally.
    final isDuplicateOfAncestor = _sameBox(box, suppressDecoBox);
    if (!isDuplicateOfAncestor &&
        box != null && box['w']! >= 8 && box['h']! >= 8 && (hasFill || hasBorder)) {
      final radiusPx = deco.radius == -1 ? box['w']! / 2 : deco.radius;
      final style = Map<String, String>.from(_defaultStyle);
      if (deco.color != null) style['background'] = _cssColor(deco.color!);
      style['radius'] = _pxStr(radiusPx.toDouble());
      style['borderWidth'] = _pxStr(deco.borderWidth);
      if (deco.borderColor != null) style['borderColor'] = _cssColor(deco.borderColor!);
      out.add(_ProbeElement(role: 'generic', text: '', box: box, surface: true, style: style));
      if (deco.color != null) bump('background', style['background']);
      bump('radius', style['radius']);
      if (hasBorder && deco.borderColor != null) bump('borderColor', style['borderColor']);
      nextSuppressDecoBox = box;
    } else if (isDuplicateOfAncestor) {
      nextSuppressDecoBox = box;
    }
  }

  element.visitChildren((c) => _walk(
        c, out, bump,
        insideInteractive: insideInteractive,
        suppressDecoBox: nextSuppressDecoBox,
      ));
}

bool _enabledOf(Widget w) {
  if (w is TextField) return w.enabled ?? true;
  if (w is IconButton) return w.onPressed != null;
  if (w is GestureDetector) return w.onTap != null;
  return true;
}

int _maxLinesOf(Widget w) {
  if (w is TextField) return w.maxLines ?? 1;
  if (w is TextFormField) return 1; // maxLines not introspectable generically
  return 1;
}

String _hintOf(Widget w) {
  if (w is TextField) return w.decoration?.hintText ?? '';
  return '';
}
