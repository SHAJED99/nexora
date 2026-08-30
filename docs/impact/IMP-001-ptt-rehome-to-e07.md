# IMP-001 — Re-home push-to-talk (PTT) from E06 to E07

**Gate:** 🧍 `change_impact_approval` — ✅ cleared by human on 2026-08-30

**Class:** resolved silence. `spec/feature-list.md`'s Personal Communication
UC and `FR-COMM-001` name PTT as in-scope for personal communication but
never assign it to an owning epic. E06-T13's design gap pass (GAP-017 /
`OQ-E06-T13-1`) surfaced that the design source has no PTT primitive and none
is derivable, and put the epic-ownership question to the human. Nothing in
the spec was wrong — the silence was in which epic builds it.

**The change:** PTT moves from "implicitly E06, unbuilt" to "explicitly
E07, scheduled after E07's real-time voice-call transport is settled."

**The decision (human, 2026-08-30):** agree with the design-gap-pass
advisory. PTT is a half-duplex live-transport mode (hold to transmit,
release to listen, near-real-time), not a message bubble — it shares E07's
voice-call transport problems (routing priority, make-before-break
migration) and almost none of E06's async store-and-forward messaging
problems. Design it once, against a transport that exists.

## Blast radius

| Artifact | id | Impact | Action |
|---|---|---|---|
| `spec/srs.md` | FR-COMM-001 | None — requirement text unchanged, PTT is still "in scope for personal communication," only its owning epic is now explicit | no edit; ownership isn't an SRS-level fact |
| `design/gaps.md` | GAP-017 | Closed as decided (parked, re-homed), not approved as a contract | done — `decided by:` line added |
| `epics/E06-personal-chat/tasks/E06-T13.md` | OQ-E06-T13-1 | Closed, answered | done — Status/Answer/Answered by/Date filled in |
| `epics/E06-personal-chat/epic.md` | Open Questions table, prospective-tasks table | Row updated to reflect the decision | done |
| `epics/E07-groups-calls/epic.md` | Scope, `traces_to:`, Open Questions | PTT added to in-scope list; `FR-COMM-001` added to `traces_to:`; new `OQ-E07-2` recording the inherited obligation, owner = E07's own sharding pass | done |
| `spec/knowledge-map.yaml` | FR-COMM-001 → epic edge | If the map encodes an epic-ownership edge for FR-COMM-001, it should note the split (E06: text/voice-msg/attachment/location; E07: PTT) | not yet done — see follow-up below |
| E06/E07 tasks | none yet sharded reference PTT | No task files to update — PTT was never sharded as an E06 task | n/a |

## Effort / risk

Trivial. This is a scope-boundary relabel of unbuilt work, not a reversal of
anything built or an ADR. No code, no tests, no `done` task needs
revalidation. Risk is process-only: if E07's sharding pass doesn't read
`OQ-E07-2`, the obligation could be dropped a second time — the same failure
shape `E05-B02` already demonstrated once for the relay-queue handoff. That
risk is why this report and the epic.md line exist, rather than a bare
retitle.

## Re-plan

No task injection needed — PTT has no E06 task to move or block, and E07
has no sharded tasks yet for it to join. The only re-plan step is the record
this report already makes: `OQ-E07-2` in `epics/E07-groups-calls/epic.md`,
to be picked up explicitly when E07's own task-sharding pass runs.

## Follow-up (not executed here)

- `spec/knowledge-map.yaml`: if/when it is regenerated (`skills/knowledge-map`
  / `skills/traceability`), confirm the FR-COMM-001 → epic edge reflects the
  E06/E07 split described above. Not walked in this report since the map's
  current edge granularity for this id was not verified before writing it.

## Decision record

- **Decided by:** human, 2026-08-30, via the `design_contract_approval` gate
  response on `design/gaps.md` GAP-017.
- **Gate:** `change_impact_approval` — the human's GAP-017 answer ("park
  until E07... re-home to E07 is itself a scope decision and would go
  through `skills/change-impact`") **is** the approval; this report is the
  record the gate produces, not a second pending ask.
