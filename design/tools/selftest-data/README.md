# selftest-data — synthetic test data. NOT project design.

These three pages are the **design gate's test suite**, used only by
`design/tools/selftest.mjs` (`make design-selftest`). They are invented fixtures,
not anyone's design, and nothing here is ever built or shipped.

Your real design goes in `docs/UI/`. Your real contracts land in
`design/screens/`. This folder is neither.

| File | Role |
|---|---|
| `reference.html` | the pretend "design" — the golden is extracted from this |
| `faithful.html` | a correct port. **Deliberately different tags, class names and nesting** — proves the gate measures the design, not the markup. Must score **PASS at 100%** |
| `drifted.html` | a port with five planted defects. Must **FAIL**, naming all five |

## The five planted defects

One per detector, so a future edit that silently breaks one gets caught here
rather than through a bad merge:

1. the "Remember me" checkbox is gone → **missing element**
2. the button says "Login", the design says "Sign in" → **copy (changed)**
3. the subtitle was rewritten → **copy (absent)**
4. the accent is `#10b981`, the design is `#059669` → **style delta + off-palette token**
5. control radius is 12px, the design is 7px → **style delta**

## Why this exists at all

A gate nobody has seen fail is a gate nobody should trust — and this one makes a
strong claim, so it should have to prove it on every clone.

It also demonstrates the claim itself: that drifted page, with five real defects,
renders about **0.04% different by pixel comparison**. A human reviewer, or a
vision model, comparing two screenshots would approve it. That number is the
entire argument for measuring fidelity instead of reviewing it — see
`docs/ARCHITECTURE.md` §3.

The pages render a sign-in form because a login screen exercises the element
types that matter (labels, inputs with placeholders, a checkbox, a link, a
primary button, a card surface). It is test data. It is not a screen anyone is
building.
