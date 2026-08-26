# Master epic map

> **Starts empty.** The planner fills this via `skills/epic-breakdown` — derived
> 1:1 from `spec/srs.md`, scored, and 🧍 approved by you. Until genesis runs and
> the spec exists, there are no feature epics.

## The wave model

Epic 00 (genesis) is built, reviewed and **LOCKED at its exit gate first**. Then
the planner proposes the *first wave* — the epics the dependency graph unblocks,
plus the wedge ★. You approve the wave; it executes; the next wave is proposed.

No fixed count — **let the graph decide** (often 3–6). Tighter waves mean faster
feedback, which means wrong turns get caught while they're still cheap.

Ordering is `depends_on`, not epic number. Epics whose deps are `verified` may
run in parallel (`make next LAYER=frontend`).
★ = the wedge: the single highest-adoption-value epic — the reason the product
exists. Everything else is scaffolding around it.

## Dependency graph

```
(filled by /epic-breakdown)
```

## Epic table

| id | title | SRS modules | FR prefixes | wsjf | depends_on | status |
|----|-------|-------------|-------------|------|-----------|--------|
| E00 | Genesis / walking skeleton | — | — | — | — | todo |

WSJF = (business_value + time_criticality + risk_reduction) / job_size, each 1–10.

## Wave plan

- **Wave 1:** _(proposed after the E00 exit gate closes)_

## Coverage

Every functional SRS id lands in **exactly one** epic — orphans and duplicates
are both breakdown failures. Cross-cutting NFRs (security, audit, reliability,
performance, scale) bind as **epic-level EARS** on the epics they constrain, not
as an "NFR epic" — that's how NFRs never get done.

## Notes for the planner

- Epic ids are sequential in **execution order** (E00, E01, …), not aligned to
  SRS module numbers. Carry the module mapping in its own column.
- Each approved epic gets `epics/E<NN>-<slug>/epic.md` from `_templates/`, then
  `skills/task-sharding` → the Analyze gate → dispatch.
- **UI epics:** the design contracts get extracted and 🧍 approved *before*
  sharding. A frontend task without a `design_contract:` fails `make validate`
  (rule 2).
- Out-of-scope modules simply get no epic. No reserved gaps.
