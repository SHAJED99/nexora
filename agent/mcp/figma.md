# Figma MCP — design as machine-readable source of truth

**Why:** the frontend developer and QA agents read components, variables,
layout and styles straight from the design file instead of guessing from
screenshots. Task files reference designs via `ui_reference:` (a Figma node
URL), and the agent pulls the actual spec for that node.

## Setup (local Dev Mode server — recommended)
1. Open the Figma **desktop** app → Preferences → enable **Dev Mode MCP Server**.
2. It serves at `http://127.0.0.1:3845/mcp` (already wired in `.mcp.json`).
3. Requires a seat with Dev Mode access on the file.

## Remote alternative
`https://mcp.figma.com/mcp` (OAuth) — works without the desktop app; capability
set differs slightly. Swap the URL in `.mcp.json` if you prefer remote.

## How agents should use it
- Resolve the task's `ui_reference` node → fetch component structure, variables
  (colors/spacing/typography), and any Code Connect mappings.
- NEVER eyeball-copy pixel values when a variable exists — use the token name.
- QA: compare implemented UI (via playwright) against the Figma node's specs.

## Caveats
- Endpoint/path has changed before (earlier builds used an SSE path). If
  connection fails, re-check Figma's official MCP docs.
- Large files: fetch the specific node, not the whole document (token cost).
