# Design gaps — what the design doesn't cover, and what we'll do about it

Rule 2 has two halves. Every part of the provided design gets implemented as
accurately as possible **and** every journey it omits gets completed from the
BRD / SRS / feature list, consistent with the design that exists.

This file is the second half. Everything here is 🧍 human-approved before it is
built — "what should happen when the list is empty" is a product decision
wearing a UI costume.

**Method:** `agent/skills/design-fidelity/references/gaps.md`
**Rule:** a gap cites a spec id. No id → it's an idea, not a gap; ideas go to
the human. And no gap gets filled quietly inside an implementation task — that
is how a product acquires seven different empty states.

## Status legend
🟡 proposed · 🟢 approved · ⚪ deferred · ✅ built (golden extracted)

---

<!-- Template — copy, don't edit this one.

## GAP-001 — <screen>, <what's missing>
- **status:** 🟡 proposed
- **screen:** <id> (`design/screens/<id>.md`) — or "new screen"
- **spec:** FR-XXXX-000, UC-0.0.0 — "<the EARS criterion that requires it>"
- **design shows:** <what the design actually drew>
- **derived from:** <the primitives this reuses, from the contract's token table>
- **proposal:** <one paragraph — what gets built>
- **approved by:** _<human>_ on _<date>_
- **built:** <task id> · golden extracted ✅

-->

_(none yet — the planner fills this while sharding the first UI epic)_

## The usual suspects

Checklist for the gap pass. In rough order of how often each is missed:

| Category | Typically missing from a design |
|---|---|
| Error states | validation, 401/403, 404, 500, network dead |
| Empty states | first-run, no results, filtered-to-nothing |
| Loading | skeletons, spinners, optimistic updates |
| Boundary data | very long strings, huge numbers, deep nesting |
| Whole journeys | password reset, invite, onboarding, offboarding |
| Permission variants | the same screen for a role with less access |
| Responsive | design shows desktop; the spec promises mobile |
| Confirmation | destructive-action dialogs |
