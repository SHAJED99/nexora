# Lessons — infra

Real findings from **this** project's reviews. Format + ladder: `README.md`.
`skills/retro` writes here; `agent/hooks/lesson-inject.py` injects these
automatically for matching tasks (see `index.yaml`).

## L-infra-001 — `flutter_test`'s default binding never delivers real `dart:io`/`Process.run` completions to a bare `await` inside a `testWidgets` body; it must go through `tester.runAsync(...)`, and the failure mode is a silent hang, not an error
- date: 2026-08-30 | source: E06-T01 (the Flutter-capable design-fidelity
  gate) — a real, hard-won, multi-session misdiagnosis
- situation: `test/design/design_probe_test.dart`'s EARS-UI-2 tests shell
  out to `node` (via `Process.run`) to run the comparison engine, and the
  gate's own probe writes files via `dart:io`. Run under plain `testWidgets`
  (no `tester.runAsync`), these real I/O calls never complete — not an
  exception, not a timeout with a clear message, just the test hanging
  until the framework's own 10-minute default per-test timeout fires. This
  was first diagnosed (wrongly) as "a RenderFlex overflow in the screen
  under test makes Flutter's own pump/layout cycle hang" — a plausible-
  sounding story that led to raising a whole bug task (`E06-B01`) partly on
  that premise, and to a probe-harness redesign (bounded `pumpAndSettle`,
  scoping the walk to the screen's own `Scaffold`) that didn't actually fix
  the hang, because the hang was never in the widget-pump path at all.
  Direct bisection (an isolated test with a bare `Directory.create` call,
  nothing related to `devices` or overflow) finally isolated the real
  cause. Wrapping every real I/O call in `tester.runAsync(...)` fixed it
  immediately and completely.
- root cause: `flutter_test`'s `TestWidgetsFlutterBinding` runs each test
  body inside a fake-async zone by default, for deterministic widget-pump
  timing — genuine `dart:io`/`Process` completions never fire inside that
  zone; `tester.runAsync()` is the documented escape hatch, but nothing in
  this project's own conventions or the design-fidelity skill said so
  before this incident, and the actual failure mode (a silent hang with no
  stack trace pointing at the real cause) makes the wrong diagnosis
  (something in the screen under test) far more attractive than the right
  one (something in the test's own async model) — the symptom looks
  identical to the very overflow the harness was built to catch.
- fix applied: `tester.runAsync(...)` wrapping added around every real I/O
  call in `flutter_probe_dumper.dart` and `design_probe_test.dart`, which
  also surfaced (and let get fixed in the same pass) two further
  previously-unreachable defects: a `Container`-vs-its-own-internal-
  `DecoratedBox` double-emitted surface element in the probe's element
  walk, and a `node -e` argv off-by-one in the fixture comparison script.
  Systemic fix proposed in this retro: state this explicitly in
  `skills/design-fidelity` (any future probe/gate work that shells out to
  real processes or does real file I/O from inside a `testWidgets` body
  must use `tester.runAsync`), since this exact probe is reused/extended by
  every future screen task.
- recurrence: 1
- status: lesson

## L-infra-002 — an autonomous coding CLI's own headless file-editing flag (e.g. `--dangerously-skip-permissions`) trips this session's permission classifier the same way a first-party subagent dispatch would not; a plain completions-API call for drafting text does not, because the orchestrator stays the one performing the file write
- date: 2026-08-30 | source: this session — routing low-risk work to
  OpenCode, then to OpenRouter, per the human's explicit request
- situation: dispatching OpenCode headlessly (`opencode run ... --dangerously-skip-permissions`,
  needed since there is no interactive prompt to approve a backgrounded
  run's edits) was blocked outright by this session's own auto-mode
  permission classifier — the flag itself reads as "a process editing
  files with no per-action approval," regardless of which external tool
  or model is behind it. Switching to OpenRouter's plain chat-completions
  API (no autonomous agent loop — the model returns text/a diff, and the
  orchestrator applies it via its own normal Edit tool, then independently
  re-runs analyze/test/gate before committing) hit no such block, because
  the orchestrator's own tool calls stayed inside its normal permission
  flow the whole time; only the *drafting* step was delegated.
- root cause: not a project-code gap — this is a genuine, useful discovery
  about this session's own operating constraints that would otherwise be
  re-learned (and re-blocked) by a future session attempting the same
  "route cheap work to an external free model" pattern the human asked
  for in this session.
- fix applied: none needed in project code. Recorded here so a future
  session (or a future task in this one) reaching for external-model
  routing knows the working shape immediately: use a plain completions API
  for drafting, keep the orchestrator's own tools as the only thing that
  ever writes a file or runs a command, independently verify before
  committing — never grant an external autonomous agent loop
  skip-permissions-style authority in this environment.
- recurrence: 1
- status: lesson
