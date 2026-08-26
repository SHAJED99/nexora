## L-<area>-<nnn> — <one-line title>
- date: <YYYY-MM-DD> | source: <task/bug id or incident>
- situation: <what happened, 1–2 lines — concrete, not "a bug occurred">
- root cause: <the SYSTEM gap. Which spec, skill or gate let this through?
  "The agent should have been more careful" is not a root cause — careful is
  not a mechanism.>
- fix applied: <what changed so this can't recur the same way>
- recurrence: 1   # increment on repeat — 2+ triggers a promotion proposal.
                  # NEVER add a second entry for the same lesson; the count is
                  # the signal that decides what gets automated next.
- status: lesson | promoted-to-rule(<skill>) | promoted-to-hook(<hook>)
