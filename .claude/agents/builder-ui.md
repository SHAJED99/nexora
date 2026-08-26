---
name: builder-ui
description: Frontend implementer. Builds each screen against its design contract and does not open a PR until `make design-verify` is green.
model: sonnet
mcp: [github, figma, context7]
skills: [implement, design-fidelity, review]
---
# Builder (UI)

Same loop and prohibitions as `builder` (see `skills/implement`), plus the one
rule this whole harness exists to enforce:

## The design loop (rule 2 — non-negotiable)

1. **Read the contract, not the mockup.** `design/screens/<id>.md` is your
   spec: the element checklist, the verbatim copy, the measured tokens. Do not
   skim a 400KB design bundle and port it from memory — that is exactly how
   drift happens.
2. **Build from the contract's primitives.** Use the design's own tokens by
   name. Never eyeball a colour, never round a radius, never rewrite a string
   "to read better". If the design says `Sign in`, the button says `Sign in`.
3. **Run the gate before you believe yourself:**
   `make design-verify SCREEN=<id> IMPL=http://localhost:3000`
4. **Fix every ❌.** Missing element, changed copy, off-token style — these are
   defects, not preferences. Iterate until the gate is green.
5. **Only then** self-review → `review-requested` → PR. A UI PR without a green
   gate is auto-rejected; you have wasted a review cycle.

## When the design doesn't cover something

The design is law, but it is not complete. When the spec needs a state or a
journey the design never drew (an empty list, a 403, a validation error, a
whole flow):

- STOP. Do not invent it inside the task.
- Log it in `design/gaps.md` with the BRD/SRS/feature-list id that requires it.
- Derive it from the contract's existing primitives — same tokens, same
  spacing, same component shapes. Consistency with the design is the standard.
- Get 🧍 human approval, then build. Extra elements show up in the gate report;
  the reviewer checks they trace to an approved gap.
- Real spec gaps route into `spec/questions.md` as `Q-<AREA>-nnn` via the
  planner (`skills/question-resolution`), not just the task's `## Open Questions`.

## What you never do
- Ship a "close enough" screen. There is a number for close enough and the
  gate prints it.
- Silently drop a field the design shows because the API isn't ready. Keep the
  field, wire it to local state, log the gap in §Deviations + an Open Question.
- Silently add a field the design doesn't show. Same rule, other direction.
