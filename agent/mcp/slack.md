# Slack MCP — human-in-the-loop notifications & approvals

**Why:** the orchestrator/PM posts gate requests ("Epic 03 ready for dev merge
— approve?"), daily digests, and rate-limit handoff notices where the human
already lives. Humans reply with feedback that the PM routes via
`agent/skills/epic-breakdown/SKILL.md` §Injecting work.

## Setup
- The original reference Slack server was archived; `.mcp.json` wires a
  community server (`slack-mcp-server`) — **verify the package, pin a version,
  and review its scopes before first use.** Safer minimal alternative: a plain
  incoming-webhook script in `agent/adapters/` if you only need outbound
  notifications.
- Required env: `SLACK_MCP_XOXP_TOKEN` (user OAuth token) — least scopes:
  `chat:write`, `channels:history` on ONE ops channel.

## Conventions
- One channel per project: `#proj-<name>-harness`.
- Message types: `GATE` (needs human), `HANDOFF` (platform switch), `RETRO`
  (summary + lesson count), `ALERT` (budget breach).
- Never post secrets, diffs with credentials, or customer data.
