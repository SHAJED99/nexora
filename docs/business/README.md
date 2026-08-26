# docs/business — the source documents

**Put your BRD, SRS, feature list and any requirements docs here.** Any format —
`.docx`, `.pdf`, `.md`, a Google Docs export. They are **read-only inputs**:
agents read them, never edit them.

```
docs/business/
├── BRD.docx                  ← what the business wants and why
├── SRS.docx                  ← what the system must do (the FR/NFR ids)
├── feature-list.md           ← Module → Feature → UC hierarchy
└── <anything else>           ← meeting notes, constraints, compliance
```

## What happens to them

These are the **raw** source. `spec/` is the **canonical** source, and it doesn't
exist yet — genesis produces it:

```
docs/business/*.docx  ──[genesis T00]──▶  spec/srs.md          ← FR-ids, greppable
                                          spec/feature-list.md
                                          spec/glossary.md
                                          spec/constitution.md  ← 🧍 you approve
                                          docs/domain/          ← entities, flows, risks
```

The conversion isn't clerical. A `.docx` can't be grepped, diffed, traced or
cited by a task file — so genesis extracts it into atomic, addressable ids that
`traces_to:` can point at. **Rule 1 (spec is law) needs an id to be law.** A task
saying "implements the BRD" is unreviewable; a task saying `traces_to:
[FR-AUTH-003]` is checkable by a script.

After genesis: **`spec/` is law; `docs/business/` is history.** When they
disagree, that's not a judgement call — it's an SRS amendment the human approves.
Never silently prefer the docx.

## What genesis will ask you

Expect the T00 analysis to come back with questions, and expect them to be the
uncomfortable ones — the things the BRD implies but never says. That's the point:
every ambiguity found here costs minutes, and every one missed costs an epic.
Answers become SRS amendments with ids, so the next agent inherits the answer
instead of re-asking it.

## Filling the gaps in the design

`design/gaps.md` traces every derived journey back to an id **from here**. That's
the mechanism that lets the harness complete what the design left out without
inventing product: the design shows the happy path, the SRS says what happens
when it fails, and the gap entry cites the id that requires it.

See `agent/skills/genesis/SKILL.md` §T00 and
`agent/skills/design-fidelity/references/gaps.md`.
