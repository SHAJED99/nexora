# docs/UI — the design source

**Put the design here.** Figma export, HTML bundle, a React app, screenshots —
whatever you have. **Read-only:** agents measure it, never edit it.

```
docs/UI/
├── sample-frontend/          ← an HTML export or bundle  → sources.kind: static
├── design-app/               ← a React/Vue design app     → sources.kind: command
└── figma/                    ← node trees + frame renders → figma-import.mjs
```

## Wire it in (one edit, then two commands)

`design/sources.yaml` — point a source at your folder and declare one entry per
screen:

```yaml
sources:
  ui:
    kind: static
    root: docs/UI/sample-frontend

screens:
  - id: login
    source: ui
    design_path: /login.html          # the path inside the source
    impl_path: /login                 # the route in the built app
    viewports: [1440x900]
    states: [{ name: default }]
```

```bash
make design-extract      # → design/golden/   (committed — it becomes the law)
make design-contract     # → design/screens/  (what agents build against)  🧍 you review
```

From then on, every UI task carries `design_contract: design/screens/<id>.md`,
and `make design-verify` blocks any merge that drifts.

Per-format detail — including **single-file bundles** (the 400KB "export
everything" artifact that switches screens by in-page routing rather than URL)
and **Figma** — is in `agent/skills/design-fidelity/references/ingest.md`.

## The one recommendation worth taking

**If you can export the design to HTML, do that** — even bad, unshippable HTML.
The extractor then reads *real computed styles* from a real browser, so the
golden is exactly what your build gets compared against. Importing a Figma node
tree works, but roles get inferred from layer names, styles come from node fills
rather than rendered CSS, and tolerances have to start looser. The export is
never shipped. It's only measured.

## What the harness does with this

It does **not** ask an agent to look at your design and reproduce it. That
approach is what v1 did and it's why implementations drifted — measured on the
fixture, a build with a missing checkbox, two rewritten strings, a wrong accent
and a wrong radius renders **0.04% different by pixel comparison**
(`make design-selftest`). No amount of care fixes that.

Instead: the design is extracted into a golden, distilled into a ~150-line
contract per screen, and every build is mechanically checked against it —
missing elements, copy character-for-character, styles against your design's own
measured tokens. See `design/README.md`.

## When the design doesn't cover something

It won't cover everything — no design does. Missing error states, empty states,
whole journeys like password reset. Those don't get improvised: they go in
`design/gaps.md`, traced to a BRD/SRS id from `docs/business/`, derived from the
primitives your design already established, and 🧍 approved by you before
they're built. That's rule 2's second half — the design gets implemented
faithfully **and** what it omits gets completed from the spec, consistently.
