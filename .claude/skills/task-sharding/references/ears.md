# EARS — acceptance criteria that can't be argued with

Easy Approach to Requirements Syntax. Every criterion uses **one** of five
shapes. The point isn't ceremony: a criterion in EARS form maps 1:1 to a test,
and "should work correctly" maps to nothing.

| Pattern | Shape | Use for |
|---|---|---|
| Ubiquitous | The system SHALL `<behavior>` | always-true rules |
| Event | WHEN `<trigger>`, the system SHALL `<behavior>` | responses to events |
| State | WHILE `<state>`, the system SHALL `<behavior>` | behavior during a mode |
| Option | WHERE `<feature is present>`, the system SHALL `<behavior>` | variants, flags |
| Unwanted | IF `<condition>`, THEN the system SHALL `<response>` | errors, abuse, edges |

## Rules
1. **One SHALL per criterion.** Two SHALLs = two criteria = two tests.
2. **Trigger is observable.** "WHEN the user submits the form", not "WHEN the
   user wants to log in".
3. **Behavior is checkable.** Name the status code, the field, the message, the
   state transition. "Handles it gracefully" is not a behavior.
4. **Every criterion carries its trace:** `(FR-AUTH-003, UC-1.1.3)`.
5. **Unwanted behavior is not optional.** For every happy path, write the IF/THEN
   for the ways it fails. This is where the bugs live, and it's the half that
   gets skipped.
6. **Numbers are part of the behavior.** "quickly" is not a criterion; "within
   200ms at p95" is.

## Naming the test
The id goes in the test name, so coverage is greppable and a reviewer can prove
it in one command:
```
EARS-AUTH-3  →  test_EARS_AUTH_3_refresh_rejects_expired_token
```
```bash
grep -r "EARS_AUTH_3" tests/    # the criterion is proven, or it isn't
```

## Examples

❌ "Login should be secure and fast."
✅ `EARS-AUTH-1`: WHEN a user submits valid credentials, the system SHALL return
   a 15-minute access token and a rotating refresh token. (FR-AUTH-001, UC-1.1.1)
✅ `EARS-AUTH-2`: IF credentials are invalid, THEN the system SHALL return 401
   with `AUTH.INVALID_CREDENTIALS` and SHALL NOT reveal whether the account
   exists. (FR-AUTH-003, NFR-SEC-009)
✅ `EARS-AUTH-3`: IF a refresh token has been used before, THEN the system SHALL
   reject it and revoke the whole session family. (FR-AUTH-006)

❌ "The list should be paginated."
✅ `EARS-TICKET-7`: WHEN a client requests `/tickets` without a cursor, the
   system SHALL return the first 25 items and a `next_cursor` when more exist.
   (FR-SEARCH-002)

Note what the good ones have: a reader can write the test without asking a
single follow-up question. That's the bar.

## For UI criteria
The design contract carries layout, copy and tokens — don't restate them in EARS
(you'd be writing a second source of truth that drifts). EARS carries the
*behavior*:

✅ `EARS-LOGIN-4`: WHILE the sign-in request is in flight, the system SHALL
   disable the submit button and show the loading state. (FR-AUTH-001)

Fidelity is proven by `make design-verify`. Behavior is proven by tests. Two
gates, two jobs, no overlap.
