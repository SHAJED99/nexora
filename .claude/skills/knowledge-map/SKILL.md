---
name: knowledge-map
description: Baseline and maintain spec/knowledge-map.yaml — the single queryable index over facts, assumptions, requirements, decisions, features and their edges. Use after question resolution to baseline the project knowledge map, and continuously whenever spec, ADRs, epics, design or assumptions change.
---
# Knowledge Map

One queryable index over everything the project knows. "Why does this code
exist?" is answered by walking the map: code → task → feature → requirement →
fact/decision. Without the map that walk is archaeology; with it, it's a grep.

**The map points; the files hold the truth.** Every node is a POINTER — an id,
a one-line summary, and a path to the artifact that owns the content. The map
never duplicates content, because duplicated content forks, and a forked
source of truth is two sources of lies. Every node carries the id of the
artifact it points at.

## Structure of `spec/knowledge-map.yaml`
Normative field list: `schemas/knowledge-map.schema.yaml`. Skeleton:
`templates/knowledge-map.template.yaml`. Top-level keys:

- `project` — {name, lifecycle_stage}
- `vision` · `goals[]` · `stakeholders[]` · `users[]` (personas)
- `facts[]` — {id F-nnn, statement, source}
- `assumptions[]` — {id A-nnn, statement, risk_if_wrong, status}
- `decisions[]` — ADR pointers
- `requirements` — {functional[]: FR- pointers with status, non_functional[]: NFR- pointers}
- `features[]` — epic pointers (E<NN>)
- `journeys[]` · `business_rules[]` · `data_models[]` · `apis[]` · `integrations[]`
- `architecture` — ADR pointers
- `risks[]` · `constraints[]`
- `open_questions[]` — Q- pointers, **🟡 open only** (answered questions live
  in spec/questions.md; the map only indexes what's still unknown)
- `edges[]` — {from, to, kind} traceability edges

## Procedure

### 1. Baseline
After intake and the first question rounds resolve: populate the map from the
intake report, the question log, and (brownfield) the codebase baseline.

🧍 **HUMAN GATE** (`knowledge_map_baseline`): the human skims the map — are the
facts actually facts, are the assumptions acceptable, is anything missing that
they know and the documents don't? This is the cheapest moment to catch a wrong
"fact"; every skill downstream trusts the map.

### 2. Update discipline — WHO updates WHEN
The map rots the day updates become "someone's, eventually". Ownership:

| Event | Who updates | What changes |
|---|---|---|
| intake completes | **knowledge-map**, reading `docs/intake-report.md` | facts, constraints, users, vision |
| brownfield baseline approved | codebase-analysis | facts, constraints, architecture (`imposed` ADRs) |
| question resolved / assumed | question-resolution | open_questions[], assumptions[], facts[] |
| genesis produces spec/ + ADRs | genesis | requirements, decisions, architecture |
| epic approved | epic-breakdown | features[], edges FR→E<NN> |
| epic sharded | task-sharding | edges E<NN>→task ids |
| retro writes a lesson | retro | edges lesson→area/decision |
| impact report executed | change-impact | any affected nodes + edges |

Every update is **one commit**: `docs(knowledge): <what changed>` (rule 10
style). A map updated in a mixed commit is a map nobody can bisect.

### 3. Consistency checks
Run at every baseline and every gate the map feeds:
- Every FR in the map exists in `spec/srs.md`, and every FR in `spec/srs.md`
  exists in the map. Orphans either way = fail.
- No edge points at a missing id (dangling `from`/`to`).
- Every assumption with `status: invalidated` has an IMP-nnn report — an
  invalidated assumption without an impact walk is a live landmine.
- `open_questions[]` contains only 🟡 entries per `spec/questions.md`.

### 4. Reading the map — worked example
"Is password reset actually built, and why does it work the way it does?"

```
requirements.functional: FR-AUTH-007 "password reset via email token"
  edge: FR-AUTH-007 → E02 (kind: implemented_by)
  edge: E02 → E02-T04 (kind: sharded_into)
  edge: FR-AUTH-007 → ADR-0005 (kind: constrained_by)   # auth strategy
task E02-T04 frontmatter: files: [src/auth/reset.py], tests test_EARS_AUTH_*
```
Four hops: requirement → feature → decision → task → code+test. If any hop is
missing, that's not a map problem — it's a real gap the map just exposed.
Deeper queries: `skills/traceability`.

## Where to look next
- What feeds the baseline → `skills/project-intake` · `skills/question-resolution` ·
  `skills/codebase-analysis`
- What consumes it → `skills/genesis` · `skills/change-impact` · `skills/traceability`
- Schema → `schemas/knowledge-map.schema.yaml` · skeleton →
  `templates/knowledge-map.template.yaml`
