# Lessons — the harness's memory of its own mistakes

One file per area: `backend.md` · `frontend.md` · `design.md` · `qa.md` ·
`infra.md` · `process.md`.

**Written** by `skills/retro`. **Read** automatically — `agent/hooks/lesson-inject.py`
runs on prompt submit, works out which task you're on, and injects that task's
area lessons. Rule 8 without anyone having to remember rule 8.

That automation is the whole point: lessons that depend on someone remembering
to copy them aren't memory, they're paperwork. Full reasoning:
`docs/ARCHITECTURE.md` §2.

**These files start empty, and should.** They hold evidence from *this*
codebase's reviews — the recurrence count is what decides which trap gets
automated next, so seeding them with another project's findings would put fiction
in that count. Generic craft belongs in the skills. Your first retro writes the
first entry.

## The ladder (`skills/retro`)

| Recurrence | Becomes | Enforced by |
|---|---|---|
| 1st | lesson here | the agent reads it (injected) |
| 2nd | a rule in the relevant `SKILL.md` | the reviewer |
| checkable, or 3rd | a hook / lint / test | the machine, every time |

```bash
make lessons     # by area + promotion candidates (recurrence >= 2)
```

Climb as fast as the evidence allows. A hook beats a rule beats a lesson,
because a hook cannot be forgotten, skimmed, or lost to a context window.
"Remember to X" is the weakest control there is, and it's everyone's first idea.

## Format

Append; never rewrite history. One entry per lesson — if it happens again you
**increment `recurrence`**, you don't add a second entry. The count is what
drives promotion, so a duplicate hides the pattern it should be revealing.

```markdown
## L-<area>-<nnn> — <one-line title>
- date: <YYYY-MM-DD> | source: <task/bug id or incident>
- situation: <what happened, 1–2 lines>
- root cause: <the SYSTEM gap — spec? skill? gate?>
- fix applied: <what was done>
- recurrence: 1
- status: lesson | promoted-to-rule(<skill>) | promoted-to-hook(<hook>)
```

## The rule that makes these useful

**A lesson is about the system, not the agent.** "The agent forgot to await the
audit write" is an anecdote. "Nothing in the review checklist distinguished
ignorable side-effects from consequential ones, so `void` looked fine" is a
lesson — it names something you can *change*.

If a root cause reads "should have been more careful", it isn't finished.
Careful is not a mechanism.
