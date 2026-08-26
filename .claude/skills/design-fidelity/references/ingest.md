# Ingesting a design source

One normalized golden format, several ingesters. Everything downstream
(contract, verify, reports) is identical whatever the design arrived as.

```
Figma  ─┐
HTML   ─┼─▶ golden/<screen>/<state>@<vp>/{probe.json, page.png} ─▶ contract ─▶ verify
React  ─┘
```

`probe.json` = every visible element (role, copy, box, computed styles) + the
measured token census. `page.png` = the reference screenshot.

---

## HTML export / bundled sample / static mockup

The easy case, and the most faithful — it renders in a real browser, so the
probe reads real computed styles.

```yaml
sources:
  sample:
    kind: static
    root: designs/sample-frontend    # a folder of .html
screens:
  - id: login
    source: sample
    design_path: /login.html
    impl_path: /login
    viewports: [1440x900]
```

**Single-file bundles** (one 400KB `.html` with every screen inside, the usual
"export from the design tool" artifact): they normally switch screens by
in-page routing rather than by URL. Drive it with a state setup:

```yaml
screens:
  - id: ticket-detail
    source: sample
    design_path: /Bundle.html
    impl_path: /tickets/[id]
    states:
      - name: default
        setup:
          - { click: "nav a[href='#tickets']" }
          - { click: "table tbody tr:first-child" }
          - { wait_for: ".ticket-detail" }
```

If the bundle can't be driven, split it once by hand into per-screen HTML files
and treat those as the source. Do this once; every screen benefits forever.

---

## React / Vue / Storybook (a running design app)

```yaml
sources:
  design_app:
    kind: command
    cmd: "npm --prefix designs/app run dev"
    ready_url: http://localhost:5173
    timeout_s: 120
```

The tool boots it, extracts, and kills it. Storybook works the same way —
point `design_path` at `/iframe.html?id=<story-id>` to capture one component
per screen and gate your primitives individually. That is the highest-leverage
place to be strict: get Button and Input exactly right and every screen that
uses them starts closer to green.

---

## Figma

Figma frames aren't browsable, so they take an import step rather than a
browser capture. Two options, best first.

### Option A — export the frames to HTML/React, then treat as above
Figma Dev Mode (or a Figma→code plugin) emits markup you can serve statically.
**Strongly preferred**: the probe reads real rendered styles, so the golden is
exactly what the browser will compare against. The export doesn't need to be
good code — it is never shipped, it is only measured.

### Option B — import the node tree directly
When only the Figma file exists:

1. Get the node JSON + a PNG render per frame. Via the `figma` MCP (Dev Mode
   server running, file open) ask for the node tree and the image export; or
   via REST:
   ```
   GET /v1/files/:file_key/nodes?ids=12:345          → node tree
   GET /v1/images/:file_key?ids=12:345&scale=2&format=png → render URL
   ```
   Save to `design/sources/figma/<screen>/{nodes.json,frame.png}`.
2. `node design/tools/figma-import.mjs --screen <id>` converts the node tree
   into the same `probe.json` shape (TEXT→copy, fills→colours,
   cornerRadius→radius, absoluteBoundingBox→box, name/type→role) and copies the
   render in as `page.png`.
3. Continue with `make design-contract` exactly as normal.

**Honest limits of Option B.** A Figma node tree is not a rendered DOM:
- Roles are inferred from layer names and node types. Name your layers
  (`Button/Primary`, `Input/Email`) and inference is good; ship
  `Frame 247` and it isn't.
- Auto-layout padding maps cleanly; absolute-positioned decoration doesn't.
- Interactive states (hover, focus, error) exist only if the designer drew them
  as variants — point a `state` at each variant node.
- Text is what the designer typed. Real copy comes from the spec; if they
  disagree, the spec wins (rule 2) — log it as a gap.

Because of these, Option B's `tolerance` usually needs to start looser
(`color: 8`, `radius_px: 2`) and tighten as the design system settles. Record
the loosened values and why, in `design/thresholds.yaml`. That's a 🧍 human call.

---

## Choosing viewports and states

- **Viewports:** capture what the spec promises. Desktop-only staff app →
  `[1440x900]`. Responsive surface → `[1440x900, 390x844]` and the gate holds
  both. Don't capture five widths because you can; each one is a real
  maintenance cost.
- **States:** every state a user can reach and the spec names — `default`,
  `error`, `empty`, `loading`, `disabled`. A state the design never drew is a
  **gap**, not an excuse. See `references/gaps.md`.
- **Dynamic content:** seed the implementation with the same data the design
  shows. Where you can't (timestamps, counts, avatars), use `ignore_text`
  regexes and `mask` selectors — surgically. Masking half the screen to get a
  green gate is self-deception; the gate exists to be believed.
