---
name: release
description: Ship development to main behind the human gate, tag it, smoke it — and unwind cleanly when something is wrong (revert vs reset vs redeploy). Use for any release, and whenever anything merged is wrong or anyone says "roll back".
---
# Release + Rollback

Merges v1's `workflows/release.md` + `rollback`.

## Release

### Preconditions (all of them)
- Target epics merged to `development`; each with P1/P2 bugs at **zero**, its
  sweep done, its retro done, and an `epic-<n>-done` tag.
- **`make trace` run, and its blocking orphan classes empty** — a requirement
  with no test, a `done` task with no passing test, a `done` task whose
  dependency is not done, a superseded ADR still cited. `skills/traceability`
  produces the list; these are release blockers, not release notes. Orphans you
  are knowingly shipping go in the changelog's Known gaps.
- CI green on `development`.

> Two gates bracket this skill, both declared in `harness.yaml`:
> 🧍 `epic_to_dev_merge` for each epic entering `development`, and
> 🧍 `dev_to_main_merge` for the release itself. Promotion is by PR only.

### Steps
1. Open the `development` → `main` PR: the epics included, the EARS satisfied,
   the known P3/P4, the migrations, the flags.
2. 🧍 **HUMAN GATE** (`dev_to_main_merge`): ship it?
3. Merge → **annotated** tag `vX.Y.Z` → deploy.
4. **Smoke checks** — the walking-skeleton path at minimum. A deploy that
   completed is not a deploy that works.
5. Success → notify. Failure → rollback, below, immediately.

## Rollback

**The first move is always: get users back to working software.** Diagnosis is
second. Every minute spent understanding a broken release is a minute it's
broken.

> **Redeploy the previous tag FIRST. Then revert the code. Then diagnose.**

### The decision table

| Situation | Action |
|---|---|
| Bad task, PR not merged | delete the branch + `git worktree remove`. Done |
| Bad task, merged to the epic branch | `git revert` that one squash commit |
| Bad epic in `development` | `git revert` its merge commit (`-m 1`) |
| Bad release in production | **redeploy `vX.Y.Z-1` first**, then revert on `main` |
| Bad migration | the down-migration if it's reversible; a forward fix if it isn't. Never edit a migration that has run anywhere |

### revert vs reset
`git revert` is the default the moment anything is **shared** — it preserves
history, and history is the only account of what actually happened.
`reset`/force-push only on a **private, unshared task branch** that nobody has
pulled. Force-pushing a shared branch destroys other agents' work and their
ability to notice.

### After any rollback
1. An incident task with the timeline (what shipped, what broke, how you knew,
   what you did).
2. A retro (`skills/retro`) — a rollback is *always* worth one. Root cause is
   never "the code was wrong"; it's the gate that let the wrong code through.
   Find that gate.
3. A regression test that would have caught it, before the fix re-ships.

## Tags
- `vX.Y.Z` — annotated, on `main`, every release.
- `epic-<n>-done` — when an epic lands in `development`. This is what makes
  "redeploy the previous tag" a five-second operation instead of an
  archaeological dig.

## Where to look next
- Preconditions come from -> `skills/bug-sweep` (P1/P2 zero) - `skills/review` (every task approved)
- Coverage evidence for the gate -> `skills/traceability` (orphan classes are release blockers)
- After the tag -> `skills/retro`
- Rolling back -> the decision table above; never edit a migration that has run
- Branch model and merge gates -> `scaffold/AGENTS.md` rules 4 and 5
