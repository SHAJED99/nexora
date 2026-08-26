# Database MCP — schema-aware development, safely

**Why:** backend dev / QA / Team Lead can inspect real schemas, explain query
plans, and verify migrations instead of hallucinating column names.

## Default: DBHub (universal, one server for many engines)
Wired in `.mcp.json` as:
    npx -y @bytebase/dbhub --transport stdio --dsn "${HARNESS_DB_DSN}" --readonly

- Supports PostgreSQL, MySQL, MariaDB, SQL Server, SQLite via one DSN.
- Set `HARNESS_DB_DSN` in your `.env`, e.g.
  `postgres://user:pass@localhost:5432/appdb?sslmode=disable`
- `--readonly` is mandatory for dev agents. Only DevOps, on a human-approved
  task, may run a write-capable instance — and against a non-prod database.

## Alternatives
- Engine-specific MCP servers (Postgres, MySQL) exist if you want tighter
  features; verify maintenance status before adopting (several early official
  reference DB servers were archived).

## Rules for agents
1. Use it to READ: schemas, sample rows (no PII dumps), EXPLAIN plans.
2. Migrations are written as files in the repo and applied by CI/DevOps —
   never executed ad-hoc through MCP.
3. Quote findings into the task's Run Log, not entire tables.
