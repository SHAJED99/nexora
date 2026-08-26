# The security lens

Run this when the diff touches auth, payments, RBAC, single-use tokens, money,
or a state machine. Every item below gets an explicit **PASS or FAIL with a
file:line** — "seems fine" is not a verdict, and an unchecked item is a FAIL.
These are the attacks that actually land on codebases like this one, in roughly
the order they land.

## 1. Authentication

1. **Token lifetime is enforced, correctly.** Expiry compared with `<=`, not
   `<` — an exactly-expired token must fail. Cite the comparison line.
2. **Tokens rotate and revoke.** Refresh rotates the pair; logout/password-change
   revokes server-side. A JWT you can't revoke is a session you can't end.
3. **Session fixation.** The session id is regenerated on login and on privilege
   change. A pre-auth id that survives login is an account handed to whoever
   planted it.
4. **Password storage.** bcrypt/argon2 with a real cost factor. Not sha256, not
   "hashed", not reversible. Cite the hashing call.
5. **Single-use tokens are single-use.** Reset/invite/verify tokens are consumed
   atomically on first use and expire. A reusable reset token is a persistent
   backdoor with the user's own email as the key.

## 2. Authorization

6. **Default-deny.** An endpoint with no explicit auth declaration must be
   rejected by middleware, not silently public. Find the default; cite it.
7. **RBAC at the API layer, never only the UI.** A hidden button is not a
   control. Every role check the UI implies exists server-side too.
8. **IDOR / object-level checks on EVERY id param.** `GET /tickets/:id` verifies
   the caller may see *that* ticket, not just that they're logged in. Check
   every route that takes an id — this is the single most common finding.
9. **No privilege escalation path.** The role/permissions field is not writable
   via any user-facing update endpoint (see mass assignment, below).

## 3. Input handling

10. **Boundary validation on all untrusted input.** Route params, query, body,
    headers — validated before use, returning the domain error (bad uuid → 404,
    not a driver 500).
11. **Injection.** SQL is parameterized (no string-built queries), no user input
    reaches a shell command, no user input reaches a template engine unescaped.
    Grep the diff for concatenation near queries/exec/render.
12. **Mass assignment.** Create/update handlers use an explicit field allowlist,
    never `...req.body` into the model. `is_admin: true` in a JSON body is free
    to try and catastrophic to allow.

## 4. Secrets

13. **Never logged.** No token, password, key or card data in any log line the
    diff adds. Check error paths — that's where secrets leak.
14. **Never committed.** No credentials in the diff, tests included. Env only,
    with a `.env.example` placeholder.

## 5. Money and state machines

15. **Idempotency keys on anything that charges.** Stated mechanism, enforced
    server-side. A double-submitted charge without one is a refund ticket and a
    trust incident.
16. **No floats for money.** Integer minor units or decimal type. `0.1 + 0.2`
    is not an accounting policy.
17. **State transitions validated server-side.** The machine rejects illegal
    transitions (`shipped → cart`) regardless of what the client sends. Cite the
    transition guard.
18. **Race conditions on double-submit.** Concurrent requests can't both pass
    the same check-then-act (balance check, seat claim, coupon use). Look for a
    transaction, lock, or unique constraint — a code review that ignores
    concurrency approves a bug that only fires in production.

## 6. Data

19. **No PII in logs.** Emails, names, addresses, tokens — none of it in log
    lines, including debug lines the diff adds "temporarily".
20. **Audit trail on lifecycle writes.** Who did what, when — on the state
    transitions that matter (refunds, role grants, deletions). Regulated or
    money-adjacent writes without an audit line are FAIL.

## 7. Transport and config

21. **CORS is a list, not `*`** — especially with credentials.
22. **Cookie flags.** Session cookies are `HttpOnly`, `Secure`, and have an
    explicit `SameSite`.
23. **Rate limiting on auth endpoints.** Login, reset, verify — the endpoints
    that get brute-forced are the ones that need it, and they're the ones that
    ship without it.

## Verdict

Report in the review's `security:` line as PASS or FAIL. FAIL requires the
failing item numbers, each with file:line and one line on why it matters.
PASS requires that every applicable item above was actually checked — an item
skipped is an item failed.
