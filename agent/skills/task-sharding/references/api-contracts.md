# API contracts in the task file

The contract lives **in the task file**, so one source of truth drives backend
implementation, frontend consumption and reviewer tests — in parallel, without
anyone waiting for anyone.

An under-specified contract doesn't save time. It moves the decision to
whichever agent hits it first, at 2am, alone, with no way to know what the other
side assumed.

## Required per endpoint

```yaml
api_contracts:
  - endpoint: /api/v1/tickets
    method: POST
    auth: bearer(staff)              # public | bearer(<role>) | apikey | internal
    idempotent: false                # if true: how (key header? natural key?)
    request:
      title:       { type: string, required: true, max: 200 }
      description: { type: string, required: true, max: 10000 }
      category_id: { type: uuid,   required: true, exists: categories.id }
      priority:    { type: enum,   required: false, values: [low, normal, high], default: normal }
    response:
      201: { id: uuid, title: string, status: enum, created_at: iso8601 }
    errors:                          # every reachable status, with its code
      400: VALIDATION.FAILED         # field-level details in the envelope
      401: AUTH.REQUIRED
      403: RBAC.FORBIDDEN
      404: CATEGORY.NOT_FOUND        # unknown category_id
      409: TICKET.DUPLICATE
```

## Non-negotiables

1. **Every list endpoint declares pagination.** Style (`cursor` | `offset` |
   `page+size`), default and max page size, and the envelope shape. A list
   without pagination is a production incident with a release date.
   ```yaml
   pagination: { style: cursor, param: cursor, size: 25, max: 100 }
   response:
     200: { data: [Ticket], next_cursor: "string|null" }
   ```
2. **One error envelope, project-wide.** Decided once in genesis, never
   per-endpoint. Every error in every task uses it.
3. **Validation is per field and concrete.** `max: 200`, `format: email`,
   `exists: categories.id`. "Validated" is not a rule.
4. **Every reachable error status is listed with its code.** If the reviewer can
   reach a status you didn't list, the contract was wrong.
5. **Untrusted input is validated at the boundary.** A raw route param or body
   field must not reach a typed DB column unvalidated — it returns the *domain*
   error (a bad uuid → 404, not a driver 500). A typed column makes unvalidated
   input *look* safe; the driver's 500 is what users get instead.
6. **Auth per endpoint, explicitly.** Which role, checked where. Default-deny.
7. **Idempotency for anything that creates or charges.** State the mechanism.

## Casing and naming
Follow `docs/conventions.md` (set in genesis). The rule that matters: **decide
once, then never differ**. Two tasks describing one endpoint two ways is an
Analyze-gate failure, and it's the cheapest bug you'll ever prevent.

## The parallelism payoff
A complete contract is what lets the backend task, the frontend task and the
reviewer's tests all start on the same morning — none of them blocked, none of
them guessing, all three meeting at a shape they already agreed on. That's the
entire reason this section is long.
