# The Flutter-capable design-fidelity gate

E06-T01. Closes `OQ-E00-3` (`epics/E00-genesis/epic.md`). Makes rule 2
(`AGENTS.md`) enforceable for a built Flutter screen — no more "design gate:
n/a" + a manual eyeball diff, which is exactly the failure mode
`agent/skills/design-fidelity/SKILL.md` opens with (a build 0.04% different
by pixels and wrong in four places).

## Run it

```bash
make design-probe                                  # dump every registered screen's widget tree
make design-verify SCREEN=devices IMPL=flutter     # compare that dump against design/screens/devices.md
```

`design-probe` runs `flutter test test/design/design_probe_test.dart`, which
pumps each registered screen and writes `build/design-probe/<screenId>.json`
via `dumpScreenProbe` (`test/design/flutter_probe_dumper.dart`).
`design-verify … IMPL=flutter` then loads that JSON through
`design/tools/lib/flutter_probe.mjs`'s `loadFlutterProbe()` and runs it
through `design/tools/lib/compare.mjs` **exactly as written** — the same
`matchElements`/`copyDiff`/`styleDeltas`/`layoutDeltas`/`tokenDiff` the DOM
path uses. Nothing in that file changed for this task; that reuse is the
whole point (§2 of the task).

Two ways to point the gate at a Flutter probe:
- `IMPL=flutter` (i.e. `--impl flutter`) — resolves, **per screen in the
  loop**, to `build/design-probe/<screen.id>.json` (the directory comes from
  `design/sources.yaml`'s `impl_flutter.dir`). Use this for the normal
  `make design-verify SCREEN=<id> IMPL=flutter` invocation above.
- `--impl-probe <path>` — a direct override: one probe JSON file, used
  regardless of which screen id is filtered. Meant for a single
  `SCREEN=`-filtered run against an ad-hoc dump, e.g. while iterating on a
  screen that isn't registered in `design_probe_test.dart` yet.

Neither path touches the existing `--impl <url>` / no-`--impl` behavior
(`openSource(cfg.impl, …)` + a headless-browser `capture()`) — that DOM path
still runs exactly as before for `welcome`/`login`/`dashboard`/
`conversations`/`chat`/`settings`, none of which this task touches.

## Adding a screen (T10/T11/T12 — this is your one line)

1. In `test/design/design_probe_test.dart`, add a new `testWidgets` inside
   the `'screen probes (make design-probe)'` group:
   ```dart
   testWidgets('chat', (tester) async {
     // wire whatever GetX bindings + fixture data the screen's own widget
     // test already uses (see test/features/<feature>/presentation/
     // <screen>_view_test.dart for the pattern) …
     await dumpScreenProbe(
       tester,
       screenId: 'chat',
       screen: GetMaterialApp(home: const ChatView()),
     );
   });
   ```
   That test belongs to the screen's own task's `files:` fence (this file is
   already listed there for T10/T11/T12 — see E06-T01's task file), not this
   one's.
2. `make design-probe && make design-verify SCREEN=chat IMPL=flutter`.
3. Fix what the report says is missing/wrong, or record it as a finding for
   the epic's bug sweep — same as any other design-gate result (rule 2).

## What `dumpScreenProbe` actually measures

`test/design/flutter_probe_dumper.dart` walks the pumped widget's `Element`
tree (not the semantics tree — see §6.3) and, per element, resolves:

- **box** — global logical-pixel rect via `RenderBox.localToGlobal(Offset.zero)`
  + `.size`, with `devicePixelRatio` pinned to **1.0** (`tester.view`) so these
  logical pixels equal the CSS pixels `design/screens/*.md` contracts were
  measured at, with no unit conversion needed.
- **text** — the literal string a `Text` widget renders, or the text an
  interactive element's `Text` descendants concatenate to (§ mapping table).
- **style** — `color`/`fontFamily`/`fontSize`/`fontWeight` resolved via
  `DefaultTextStyle.of(context).style.merge(widget.style)` (never the
  widget's own possibly-null `style` field in isolation — that would silently
  under-report every inherited color/family), and
  `background`/`borderColor`/`radius`/`borderWidth` read from the nearest
  `Container`/`DecoratedBox` decoration.

Colors are emitted as CSS `rgb()`/`rgba()` strings and lengths as `"Npx"`
strings — **the Dart side does this unit conversion**, not
`flutter_probe.mjs` (a deliberate single-owner choice: pick one file to do
it, not both, or the two drift independently). `flutter_probe.mjs`'s
`loadFlutterProbe()` is a thin structural pass — read the JSON, fill any
field a hand-written dump omitted, hand back the same shape `probe.mjs`
returns for a DOM page. `fontWeight` is emitted numerically (100-900, via
`FontWeight.value`) to match the DOM probe's `cs.fontWeight` string-of-int.

## Role mapping table

The DOM contracts use `button`, `link`, `heading:N`, `textbox:TYPE`/
`textbox:multiline`, `checkbox`, `radio`, `combobox`, `label`, `image`,
`table`, `list`, `listitem`, `navigation`, `form`, `generic`. This dumper maps
the common cases only (per the task's own instruction not to chase
`compare.mjs`'s pass-C re-role matching too hard — see next section):

| Flutter signal | Role emitted | Notes |
|---|---|---|
| `GestureDetector`, `InkWell`, `InkResponse`, `IconButton`, `TextButton`, `ElevatedButton`, `OutlinedButton`, `OnProcessButtonWidget` | `button` | Recorded once at the **outermost** interactive widget; nested ones inside it (rare) are not double-captured. Its `text` is every `Text` descendant's data, concatenated, stopping at a nested interactive boundary. **Nav-style links are also mapped to `button`** — this dumper does not distinguish navigation intent from an action button; see the known mismatch below. |
| `Text` (non-empty, not inside a captured interactive element) | `generic` | No heading-level derivation (`heading:1/2/3` in the DOM contracts) — over-engineering this to chase re-role matches was explicitly out of scope for this task. A contract's heading and this dumper's `generic` with identical text and a nearby box still MATCH via `compare.mjs`'s pass C (re-role), reported as a soft finding, not a hard failure. |
| `Icon` | `generic`, `text` = the icon's Material-font ligature name (`_iconNames` map in the dumper) when known, else `''` | Both the design's icon-font glyph spans and Flutter's `Icons.*` constants draw from the same Material Symbols/Icons font — mapping `Icons.search` to `"search"` is a real correspondence, not a synthesized guess. An icon outside the map dumps with empty text: a real, recorded finding, never a guessed string. |
| `Container` / `DecoratedBox` with a real fill/border (≥8×8px) | `generic`, `surface: true` | Mirrors `probe.mjs`'s `isSurface()` test. A `BoxShape.circle` decoration has no literal radius property, so its radius is derived as `box.width / 2` (the only correct numeric equivalent — see below); an explicit `BorderRadius` value (even something like `9999px` for a pill shape) is reported **literally**, matching how `getComputedStyle` reports an unclamped declared value. |
| `TextField` / `TextFormField` | `textbox:text` or `textbox:multiline` (by `maxLines != 1`) | Not exercised by `devices` (this task's proving screen); wired ahead of T10/T11/T12's chat input needing it. |

### Known, accepted mismatch: nav items

The design's bottom-nav items are DOM `<a>` tags whose *own* text is empty —
the visible label lives in a separately-wrapped nested span, so the DOM
probe's "own text only" rule reports it as `''` (see `design/golden/devices/
default@390x844/probe.json` elements 49/52/55/58: `role: "link", text: ""`).
Flutter's `_NavItem` wraps its `InkWell` around a `Column(Icon, Text(label))`
directly — there is no such nested-wrapper split — so this dumper's
"concatenate every `Text` descendant" rule for interactive elements picks up
the label text (e.g. `"Dashboard"`) where the design contract expects `""`.
This shows up as a real, honest mismatch (a `missing` entry for the design's
empty-text `link`, an `extra` entry for this dumper's text-carrying `button`)
— not fixed here (§4 of the task), and not something a smarter role map is
worth chasing for four nav items given the instruction not to over-engineer
role mapping.

## §6 — Honest limits (read before trusting a green run)

1. **This measures the widget tree, not a rendered device frame.** No real
   platform text shaping, no OS-level insets (status bar, notch, gesture
   bar), no actual screenshot. A screen can pass every check here and still
   look subtly different on a real device. This is why pixel comparison is
   explicitly **skipped** on this path (see below), never silently treated as
   passing.
2. **`devicePixelRatio` is pinned to 1.0.** Geometry checks assume logical
   pixels here equal the CSS pixels the contract was measured at. If a
   future screen genuinely needs a different DPR, pin it explicitly in that
   screen's own `dumpScreenProbe` call and say so in that task's Run log —
   silent DPR drift makes every box comparison wrong without any error.
3. **Element tree, not semantics tree.** This dumper walks `Element`s
   (`Widget` instances as built), not `SemanticsNode`s. That was the more
   direct route to "resolved style, not source constant" (via
   `DefaultTextStyle.of(context)`/decoration lookups on the actual built
   tree) and to precise geometry (`RenderBox.localToGlobal`). The cost: role
   inference is structural (widget type), not the accessibility semantics a
   screen reader would see — a widget with a custom `Semantics` role wrapper
   but an unremarkable widget type underneath will be classified by its
   widget type here, not its declared semantic role. Not exercised by
   `devices` (E02-T02 declares no custom `Semantics` roles); revisit if a
   later screen does.
4. **Pixel comparison is skipped, and reported as skipped**, on this path —
   there is no screenshot, so `findings.pixel` is `null` and the report says
   so explicitly (`design/tools/verify.mjs`'s `writeReport()`), never
   silently omits the line. The four **hard** checks (missing elements, copy,
   style deltas, off-palette tokens) all still run in full — pixels were
   always the soft backstop, never the gate (`design/thresholds.yaml`'s own
   header comment).
5. **Role mapping only covers common cases**, deliberately (see the table
   above and the nav-item mismatch it calls out) — chasing
   `compare.mjs`'s pass-C re-role matching for every widget shape is not
   worth the complexity for what is, at worst, a soft/informational finding.
6. **An off-token `fontFamily` finding on every text element is expected
   right now**, on every screen this gate runs against, until
   `OQ-E06-T01-1`'s font-asset task lands (Inter/JetBrains Mono/Geist are not
   yet bundled — see that OQ's answer). This gate is not broken by reporting
   that; it is doing exactly what it is for.

## Why this file, and not a golden-image (`matchesGoldenFile`) suite

Deliberately not built (§4 of the task). Pixels are the eyeball backstop and
never the gate (`design/thresholds.yaml`'s header). Adding a golden-image
suite here would double the maintenance surface for the check this gate
already treats as least important. If the human wants one later, it is its
own task.
