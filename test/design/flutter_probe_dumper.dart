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
//   - role mapping covers button/textbox/heading/generic/surface. `heading:N`
//     (E12-B13) is a STYLE heuristic, not a structural one: this dumper has
//     no equivalent of "this Text sits one <section> deeper than that one",
//     so the level NUMBER is approximated from order-of-first-appearance of
//     each distinct heading-scale style on the screen (see `_headingRole`'s
//     own doc comment for the known miss this leaves).
//   - icon widgets are matched to the design's icon-font glyph text via a
//     small name map (`_iconNames` below) — both sides draw from the same
//     Material Symbols font, so `Icons.search` legitimately corresponds to
//     the design's literal "search" glyph text. Icons outside the map dump
//     with empty text (a real, recorded finding), never a guessed string.
//     Their `fontFamily` (E12-B13) is honestly reported as Flutter's own
//     bundled icon font (`IconData.fontFamily`, e.g. `MaterialIcons`) — a
//     REAL, different value from the golden's `Material Symbols Outlined`
//     (no custom icon font is bundled by this app), so this stays a
//     genuine, expected style-delta finding; `fontSize` DOES resolve
//     correctly now, since every `Icon(..., size: N)` call site's `N`
//     already matches the design's measured glyph size.
//   - a `button`-role element nested inside another interactive widget's OWN
//     internal gesture wrapper (`InkWell`/`InkResponse` — see
//     `_isInteractiveBoundary`, E12-B13) now reports its real label text and
//     that label's own color/fontSize/fontFamily/fontWeight, and reads
//     `OnProcessButtonWidget.borderRadius` when set. An icon-only button
//     (no Text label — e.g. a kebab menu) still reports default/empty style
//     here: there is no label to resolve a style from, and guessing one
//     from the icon would be an invented value, exactly what
//     `design-fidelity`'s off-palette-token check exists to catch.
//   - a `Border`'s `top` and `bottom` sides are both read (E12-B13); when
//     both are non-zero-width, `top` wins — an arbitrary but documented
//     convention, matching `_decorationOf`'s existing "richer decorations
//     read as their dominant/top-left value" simplification.
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
    _headingScaleOrder.clear();
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

/// E12-B13 (issue 2): `InkWell`/`InkResponse` (and, transitively, the bare
/// `GestureDetector` THEY compose internally — see below) are the low-level
/// gesture primitives every HIGH-LEVEL button widget in `_isInteractive`
/// composes to implement its own tap handling — confirmed directly against
/// `on_process_button_widget`'s source: `OnProcessButtonWidget.build()` wraps
/// its `child` in exactly `Material > InkWell > AnimatedSize >
/// DefaultTextStyle > Container > child`. A bounded scan looking for a
/// widget's OWN label/decoration (`_collectText`, `_findFirstDecoration`,
/// `_firstLabelStyle`) must NOT stop at any of this internal plumbing —
/// stopping there is exactly what made every `button`-role element in a
/// real dump have `text: ""` (this file's own header, and E12-B13's
/// found-by report).
///
/// `GestureDetector` specifically is NOT a boundary here, even though it IS
/// one of the widgets `_isInteractive` treats as an outermost interactive
/// element: dumping the actual Element subtree of an `OnProcessButtonWidget`
/// (found directly, via a throwaway probe test) shows `InkWell` itself is
/// built from `Actions > ... > GestureDetector > RawGestureDetector >
/// Listener` — i.e. `InkWell`'s OWN internals bottom out in a bare
/// `GestureDetector`, the exact same widget type this app's OTHER,
/// intentional top-level buttons use directly. Treating `GestureDetector`
/// as a stop-boundary here doesn't distinguish "a deliberate second tap
/// target nested inside this one" from "the button's own gesture-arena
/// plumbing" — it can only ever hit the latter, since this codebase's own
/// convention (chat_view.dart's header, `L-frontend-001`) is to build custom
/// tap targets from `InkWell`/`Material`, never a bare `Listener`/
/// `GestureDetector`, so a SEPARATE nested tappable area would itself be
/// `InkWell`-based and still stop the scan below via `IconButton` et al.
/// Still stops at a widget that could represent a SEPARATE, independently-
/// tappable HIGH-LEVEL target nested inside the outer one (a card's own
/// icon button, say).
bool _isInteractiveBoundary(Widget w) {
  return w is IconButton ||
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
    // E12-B13 (issue 7): read BOTH edges, not only `top` — a design source
    // that draws its hairline on `border-bottom` (a row divider, say) used
    // to be invisible to this dumper on both the golden and implementation
    // side equally, which reads as "unmeasured", never as "passing".
    // Convention when both are non-zero-width: `top` wins (documented,
    // arbitrary — matches this class's own "richer decorations read as
    // their dominant/top-left value" simplification below).
    final side = border.top.width > 0 ? border.top : border.bottom;
    borderWidth = side.width;
    borderColor = side.color;
  }
  return _Deco(
    color: bd?.color ?? plainColor,
    borderWidth: borderWidth,
    borderColor: borderColor,
    radius: radius,
  );
}

/// Bounded scan for the first decoration in [element]'s subtree, stopping at
/// a nested interactive BOUNDARY widget (that widget owns its own decoration,
/// if any, captured separately when its turn comes) — but NOT at the outer
/// widget's own internal `InkWell`/`InkResponse` gesture wrapper, see
/// `_isInteractiveBoundary` (E12-B13).
_Deco? _findFirstDecoration(Element element) {
  _Deco? found;
  void visit(Element e) {
    if (found != null) return;
    final w = e.widget;
    if (_isInteractiveBoundary(w)) return; // a genuinely separate nested target
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
/// with a single space, stopping at nested interactive BOUNDARY widgets
/// (their own label is captured as part of THEIR own element, not this
/// one's) — but NOT at the outer widget's own internal `InkWell`/
/// `InkResponse` gesture wrapper, see `_isInteractiveBoundary` (E12-B13).
String _collectText(Element element) {
  final parts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (_isInteractiveBoundary(w)) return;
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

/// Bounded scan for the first non-empty `Text` descendant's OWN resolved
/// style (color/fontSize/fontFamily/fontWeight) — E12-B13 issue 3: gives a
/// `button`-role element its real label style instead of always falling back
/// to `_defaultStyle`. Same boundary rule as `_collectText`/
/// `_findFirstDecoration`: stops at a genuinely separate nested interactive
/// target, but is transparent through the outer widget's own internal
/// `InkWell`/`InkResponse`.
Map<String, String>? _firstLabelStyle(Element element) {
  Map<String, String>? found;
  void visit(Element e) {
    if (found != null) return;
    final w = e.widget;
    if (_isInteractiveBoundary(w)) return;
    if (w is Text) {
      final t = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
      if (t.isEmpty) return;
      final effective = DefaultTextStyle.of(e).style.merge(w.style);
      found = {
        'color': _cssColor(effective.color ?? const Color(0xFF000000)),
        'fontFamily': effective.fontFamily ?? '',
        'fontSize': _pxStr(effective.fontSize ?? 14),
        'fontWeight': '${_weightOf(effective.fontWeight)}',
      };
      return;
    }
    e.visitChildren(visit);
  }
  element.visitChildren(visit);
  return found;
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

// E12-B13 (issue 1): per-screen order-of-first-appearance heading-level
// state — reset alongside `_walkVisitCount` in `dumpScreenProbe`, same
// top-level-variable-shared-across-one-suite-run pattern already documented
// at that reset site.
final List<String> _headingScaleOrder = [];

/// A `Text`'s role is `heading:N` when its RESOLVED style is heading-scale —
/// bold/medium weight at a size body/label text in this app never uses (see
/// `design/screens/*.md`'s own `heading:N` rows: every one measures
/// `fontWeight >= 500` at `fontSize >= 20px`; this app's own row-title/badge/
/// nav-label styles all sit below that, e.g. `NexoraTextStyles.devicesBadgeLabel`
/// at 12px). Below that threshold, `null` (stays `generic`) — deliberately
/// conservative: a 16px/w500 row-title style (`devicesDeviceName`) IS a
/// `heading:3` in `devices.md` but is `generic` in `dashboard.md`'s own
/// Recent-Conversations rows (`Family`/`Rahim`/`Ahmed`, same style) — the
/// design's own source reuses one style for both a heading and plain text,
/// so a lower threshold would manufacture a false "heading" there this
/// dumper cannot tell apart from a real one. Above the threshold, the level
/// NUMBER is a heuristic too — this dumper has no signal comparable to real
/// HTML heading nesting, so it approximates: the first distinct heading-scale
/// style seen on the screen is `heading:1`, the next NEW distinct style is
/// `heading:2`, and so on (matches this app's own brand-title-then-section-
/// heading convention — verified against devices.md/conversations.md/
/// chat.md, all three exactly). Known miss, left honest rather than silent:
/// `dashboard.md`'s `heading:3` rows (`Local Storage`/`Recent Conversations`)
/// reuse `heading:2`'s exact 22px/w500 style, so this reports `heading:2` for
/// both — `compare.mjs`'s Pass C (re-role) resolves that as a SOFT "re-roled"
/// finding (same box + text, different role), never a hard "missing" one.
String? _headingRole(double fontSizePx, int fontWeight) {
  if (fontWeight < 500 || fontSizePx < 20) return null;
  final key = '${fontSizePx.round()}|$fontWeight';
  var idx = _headingScaleOrder.indexOf(key);
  if (idx == -1) {
    _headingScaleOrder.add(key);
    idx = _headingScaleOrder.length - 1;
  }
  return 'heading:${idx + 1}';
}

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
      // E12-B13 (issue 3): `OnProcessButtonWidget.borderRadius` specifically
      // is read here — it was never consulted before, so a button whose
      // background came from `widget.backgroundColor` (skipping the
      // `_findFirstDecoration` fallback below entirely) always reported
      // `radius: '0px'` regardless of what was actually set.
      double? explicitRadiusPx;
      if (widget is OnProcessButtonWidget) {
        bg = widget.backgroundColor;
        final br = widget.borderRadius;
        if (br is BorderRadius) explicitRadiusPx = br.topLeft.x;
      }
      final deco = bg == null ? _findFirstDecoration(element) : null;
      final resolvedBg = bg ?? deco?.color;
      final radiusPx = explicitRadiusPx ??
          (deco?.radius == -1 ? (box['w']! / 2) : (deco?.radius ?? 0));
      final surface = resolvedBg != null && resolvedBg.a > 0;
      final style = Map<String, String>.from(_defaultStyle);
      if (resolvedBg != null) style['background'] = _cssColor(resolvedBg);
      if (deco != null || explicitRadiusPx != null) {
        style['radius'] = _pxStr(radiusPx.toDouble());
        style['borderWidth'] = _pxStr(deco?.borderWidth ?? 0);
        if (deco?.borderColor != null) style['borderColor'] = _cssColor(deco!.borderColor!);
      }
      // E12-B13 (issue 2/3): the button's own label — reached through its
      // internal `InkWell`/`InkResponse` gesture wrapper now (see
      // `_isInteractiveBoundary`) instead of being swallowed by it — gets
      // its own real color/fontSize/fontFamily/fontWeight instead of
      // `_defaultStyle`'s always-black-14px-400 placeholder. An icon-only
      // button (no label) leaves these at their default, honestly: there is
      // no label to resolve a style from.
      final labelStyle = text.isNotEmpty ? _firstLabelStyle(element) : null;
      if (labelStyle != null) {
        style['color'] = labelStyle['color']!;
        style['fontFamily'] = labelStyle['fontFamily']!;
        style['fontSize'] = labelStyle['fontSize']!;
        style['fontWeight'] = labelStyle['fontWeight']!;
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
        final fontSizePx = effective.fontSize ?? 14;
        final fontWeight = _weightOf(effective.fontWeight);
        style['color'] = _cssColor(effective.color ?? const Color(0xFF000000));
        style['fontFamily'] = effective.fontFamily ?? '';
        style['fontSize'] = _pxStr(fontSizePx);
        style['fontWeight'] = '$fontWeight';
        // E12-B13 (issue 1): `heading:N` when this Text's own resolved style
        // is heading-scale — see `_headingRole`'s doc comment for the level
        // heuristic and its one known miss.
        final role = _headingRole(fontSizePx, fontWeight) ?? 'generic';
        out.add(_ProbeElement(role: role, text: t, box: box, surface: false, style: style));
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
        final iconTheme = IconTheme.of(element);
        final color = widget.color ?? iconTheme.color;
        if (color != null) style['color'] = _cssColor(color);
        // E12-B13 (issue 4): font metadata for `Icon` widgets. `fontSize`
        // resolves correctly now — every `Icon(..., size: N)` call site's
        // `N` already matches the design's measured glyph size. `fontFamily`
        // is honestly reported as Flutter's own bundled icon font
        // (`IconData.fontFamily`, e.g. `MaterialIcons`) — see this file's
        // header comment: a REAL, different value from the golden's
        // `Material Symbols Outlined` (no custom icon font is bundled by
        // this app), so it stays a genuine, expected style-delta finding,
        // not something to paper over here.
        final size = widget.size ?? iconTheme.size;
        if (size != null) style['fontSize'] = _pxStr(size);
        final fontFamily = widget.icon?.fontFamily;
        if (fontFamily != null) style['fontFamily'] = fontFamily;
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
