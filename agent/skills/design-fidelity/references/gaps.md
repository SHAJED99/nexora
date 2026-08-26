# Completing what the design left out

A design is a set of pictures of the happy path. A product is every path. The
gap between them is where agents improvise — and improvisation is exactly what
this harness is built to prevent.

Rule 2 in full: **every part of the provided design is implemented as accurately
as possible; every journey the design omits is completed from the BRD / SRS /
feature list, consistent with the design that exists.** Both halves, or you get
either an incomplete product or an inconsistent one.

## Finding the gaps (planner, before sharding a UI epic)

Cross the two lists:
- **From the spec:** every user journey, every FR, every state the SRS names.
- **From the design:** every screen and state `make design-extract` captured.

Anything in the first list without a home in the second is a gap. The usual
suspects, in rough order of how often they're missed:

| Category | What's typically missing |
|---|---|
| Error states | validation, 401/403, 404, 500, network dead |
| Empty states | first-run, no results, filtered-to-nothing |
| Loading | skeletons, spinners, optimistic states |
| Boundary data | very long strings, huge numbers, deep nesting |
| Whole journeys | password reset, invite, onboarding, offboarding |
| Permission variants | the same screen for a role with less access |
| Responsive | the design shows desktop; the spec promises mobile |
| Confirmation | destructive-action dialogs |

## Filling one

1. **Trace it.** Every gap cites a spec id. No id → it isn't a gap, it's an
   idea. Ideas go to the human, not into the build.
2. **Derive, don't design.** Compose from primitives the contract already
   measured: the design's error colour, its input, its card, its spacing scale.
   An error state you derive should look like the designer drew it — because
   every part of it is theirs.
3. **Write it down** in `design/gaps.md` (format below).
4. 🧍 **Human approves** before it's built. This is a business decision wearing
   a UI costume: what should happen when a user does X is a product question.
5. **Build it**, then **extract the built screen as its own golden** and mark
   the contract `source: derived`. From that moment it's regression-gated like
   everything else — a derived screen is a design, it just wasn't drawn first.

## design/gaps.md format

```markdown
## GAP-012 — Ticket list, empty state
- **status:** 🟡 proposed | 🟢 approved | ⚪ deferred | ✅ built
- **screen:** tickets-list (`design/screens/tickets-list.md`)
- **spec:** FR-SEARCH-004, UC-10.2.1 — "WHEN no tickets match, the system SHALL
  tell the user and offer to clear filters"
- **design shows:** the populated table only
- **derived from:** `design/screens/tickets-list.md` primitives — zinc-500
  body copy at `--pf-fs-sm`, the secondary Button, the 24px card padding
- **proposal:** centred in the table body — icon, "No tickets match these
  filters", secondary button "Clear filters"
- **approved by:** _<human>_ on _<date>_
- **built:** E06-T04 · golden extracted from the build ✅
```

## The one thing not to do

Do not fill a gap inside an implementation task, quietly, because you were
mid-flow and it seemed obvious. That is how a product acquires seven different
empty states. The cost of stopping is minutes. The cost of not stopping shows
up in a retro months later as "our UI feels inconsistent" — with no single
commit to blame.
