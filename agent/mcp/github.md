# GitHub MCP — PRs, reviews and issues from inside the agents

**Why:** QA agent reviews/approves task PRs, Team Lead opens epic→dev PRs,
DevOps tags releases — all auditable on GitHub.

## Setup
- Remote (already in `.mcp.json`): `https://api.githubcopilot.com/mcp/`
  (OAuth on first use).
- Alternative: self-host `ghcr.io/github/github-mcp-server` (Docker) with a
  fine-grained PAT limited to this repo (contents, pull-requests, issues).

## Rules
- Branch protection on `main` + `dev` stays ON; the agent must go through PRs
  like everyone else (that's the point).
- Review verdict comment format: see `agent/skills/review/SKILL.md`.
- gh CLI is a fine fallback when MCP is down: `gh pr create/view/review`.
