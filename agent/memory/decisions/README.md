# Decision Records (ADRs)

Every foundational choice and every architecture trade-off lives here. Decisions
change **only** via a new ADR that supersedes the old one — never by editing
history. History is the account of what we believed and why; edit it and you
lose the ability to understand your own codebase.

Files: `ADR-0001-<slug>.md`, numbered, immutable once accepted.

## Rule 3 — foundational choices are the human's

Stack, language, framework, architecture style, datastore, queue, auth strategy.
The agent's job is **not** to pick. It's to make the human's pick well-informed:

> real options → honest pros/cons → a comparison matrix → **one advisory
> recommendation, with reasoning** → then STOP.

Until the human decides:
```yaml
status: proposed
Decision: ⏳ AWAITING HUMAN
```

An agent that quietly picks the stack has made the most expensive decision in
the project without anyone reviewing it. Choices *within* an accepted ADR are the
agent's to make freely.

## Why this directory has teeth

Accepted ADRs are not documentation — they're binding. `skills/implement` step 3
is "read the ADRs your files touch", and every decision your task touches gets
implemented or gets a §Deviation naming it. Silently dropping an accepted
decision is a review failure; it happened twice in v1.

## Genesis fills 0001–00NN

`skills/genesis` T01. Once accepted, `AGENTS.md` §Project conventions gets a
one-line summary + a link per decision — so the always-loaded file carries the
answer and this directory carries the reasoning.
