# Google Stitch MCP — AI-generated UI screens as the design source

**Why:** `documentation/Design.md` is a text-only design spec with no visual
artifact (Q-DESIGN-001, `spec/questions.md`). Google Stitch generates real
Material 3 screens (HTML + screenshot) from that spec's language, which
become `docs/UI/`'s design source for `skills/design-fidelity`.

## Known issue: Claude Code's native MCP client cannot connect

`.mcp.json`'s `stitch` entry (`type: "http"`, `url:
https://stitch.googleapis.com/mcp`) fails every tool call with:

```
Incompatible auth server: does not support dynamic client registration
```

This reproduced identically across three different auth configs — a Stitch
Settings-page API key, and the OAuth Bearer-token + `X-Goog-User-Project`
setup Google's own docs (`stitch.withgoogle.com/docs/mcp/setup`) prescribe
for Claude Code — with fresh, verified-valid credentials each time. The
constant is the error, not the auth. This points to Claude Code's MCP client
doing an OAuth-capability pre-flight probe against remote HTTP servers that
advertise OAuth, and bailing out at that probe before ever sending the
configured `headers` — i.e. a client-side bug, not a credentials problem.
(Fed back via the in-session feedback tool.) LM Studio's MCP client connects
to the same server with the same API-key header without issue, supporting
this diagnosis.

## Working alternative: direct HTTP bridge

The underlying server is a stateless MCP-over-HTTP JSON-RPC endpoint — no
session negotiation, one self-contained POST per call. Bypass Claude Code's
client entirely and speak the protocol directly with `curl`:

```bash
curl -s -X POST "https://stitch.googleapis.com/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer $STITCH_ACCESS_TOKEN" \
  -H "X-Goog-User-Project: $STITCH_PROJECT_ID" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"<tool>","arguments":{...}}}'
```

This works and has been used to successfully call `list_projects`,
`get_project`, and `generate_screen_from_text` end to end (screens
downloaded via the `htmlCode.downloadUrl` / `screenshot.downloadUrl` fields
in the response, no extra auth needed on those URLs).

### Getting credentials
Per the OAuth Setup steps at `stitch.withgoogle.com/docs/mcp/setup`:
1. Install the Google Cloud SDK, `gcloud auth login` (interactive — the
   human does this, not the agent).
2. Pick/create a GCP project, enable it: `gcloud services enable
   stitch.googleapis.com --project=<id>`.
3. `gcloud auth print-access-token` → `STITCH_ACCESS_TOKEN` in `.env`
   (**never print this token in chat/logs** — write it straight to `.env`
   via a script, same reasoning as any other secret).
4. `STITCH_PROJECT_ID=<the GCP project id>` in `.env`.

**Tokens are short-lived** (~1 hour) — expect to regenerate step 3
periodically. There is no long-lived credential path that's been proven to
work yet.

### Discovering an existing project's screens/design system
`tools/call` → `get_project` with `{"name": "projects/<id>"}` returns
`screenInstances[]`; the one with `"type": "DESIGN_SYSTEM_INSTANCE"` has
`sourceAsset` — pass that as `designSystem` on `generate_screen_from_text`
for style-consistent new screens.

## Caveats
- If Claude Code's MCP client is ever fixed for this OAuth-advertising
  server pattern, the native `mcp__stitch__*` tools are strictly nicer
  (typed schemas, no manual JSON) — prefer them once `mcp__stitch__list_projects`
  stops erroring.
- Don't let generated `.html` exports get "cleaned up" — they're read-only
  design sources per `docs/UI/README.md`, measured not shipped.
