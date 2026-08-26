# Firebase MCP — project/Auth/Firestore access for agents

**Why:** E01 (Identity & Access) and E11 (Firebase Metadata Sync) need a real
Firebase project to build against — this lets an agent inspect/configure it
instead of guessing schema or hallucinating config.

## Wired in `.mcp.json` as
    firebase mcp --dir .

Uses the Firebase CLI's own `firebase login` session (already authenticated
as the project owner) — no separate token to manage. Auto-detects which
tool groups to expose from `firebase.json` + the active project's enabled
GCP APIs.

**This machine has two `firebase-tools` installs** — an old one
(`13.28.0`, no `mcp` command) shadows the upgraded one (`15.28.1`) earlier on
PATH. `.mcp.json` pins the absolute path to the upgraded install
(`E:\home\srppc3\.npm-global\firebase.cmd`) to avoid that collision. If this
machine's PATH is ever cleaned up, this can revert to a bare `firebase`
command.

## Rules for agents
1. **Provisioning the project itself** (creating it, enabling billing) is a
   human action (`harness.yaml` `human_gates: secrets_or_env_change` /
   foundational choice) — an agent may *read* project config via this MCP,
   not create the project.
2. Respect the Firebase data boundary already locked in `spec/srs.md`
   FR-FB-001/002: never write message plaintext, recordings, private/session
   keys, or permanent location history through this connection.
3. `firebase.json`/`.firebaserc`/service-account files are config, not
   secrets in the repo sense, but any actual key material still goes through
   `.env` (gitignored) — never committed.
