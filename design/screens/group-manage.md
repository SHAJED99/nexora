---
id: group-manage
impl_path: /groups/:id
source: derived
derived_from: [devices, conversations]
states: [owner, admin, member-readonly, confirm-leave, confirm-delete, loading, error]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-GROUP-001, FR-GROUP-002, FR-GROUP-003]
gap: GAP-019
---
# group-manage · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **nothing** here: no group detail screen, no member list, no role label, no
> destructive-action treatment anywhere in the seven measured contracts. This
> contract composes the screen **only** from primitives
> `design/screens/devices.md` and `design/screens/conversations.md` already
> measure.
>
> **Built against GAP-019, approved by the human on 2026-08-31**, with both of
> its forks resolved: **(1)** destructive confirmation is a **full-screen
> confirm step**, not a new modal primitive; **(2)** roles are a **plain text
> label** per row, not an icon. Both decisions are honoured literally below.
> This contract is *written against* that approval; it is **not**
> independently approved by an agent. Written by `E07-T12`.

- **Route:** `/groups/:id` — a new route. Registering it is the build task's job.
- **Parent contracts:** `design/screens/devices.md` (the per-peer row with a
  per-row action and a state label — this design's only existing "manage a
  list of peers" shape) · `design/screens/conversations.md` (frame, section
  headings, the editable-name field, row content)
- **Source of truth for what renders:** `GroupPermissions.allows` (`E07-T02`).
  This screen holds **no** second permission rule of its own. If the matrix and
  this contract ever disagree, the matrix wins and the contract is the bug.

## Derivation boundary — what is NOT derived

1. **`more_vert` is deliberately not used here.** `devices.md` draws it
   (elements 12/20/28/36) and it implies a menu — but no contract in
   `design/screens/` draws a menu, sheet or popup anywhere. Rendering
   `more_vert` would promise a surface that does not exist, so per-row actions
   are **inline chips** in devices' own `Verify` treatment (element 31)
   instead. This is the same reasoning GAP-017 used to refuse PTT: an
   interaction with no primitive is not derivable.
2. **One measured value is deliberately not copied.** `devices.md` element 31
   measures `r4px`, and `r4px` does **not** appear in devices' own measured
   token table. Using it would put a value in a derived contract that
   `DOC-UI-6`'s check cannot find in a source table. The chips below use
   `r8px` — which is in that table, and which devices' own `Discover` button
   uses (element 6). Everything else about element 31 (`11px`,
   `rgb(53, 37, 205)`, the min 56×24 box) is carried over exactly.
3. **New copy.** Every string this screen introduces is listed in §Copy and is
   proposed copy in devices' voice. No glyph is new — see §Copy.
4. **Role colours are deliberately absent.** `devices.md`'s state labels are
   colour-coded (`rgb(78, 222, 163)` trusted, `rgb(137, 206, 255)` allowed,
   `rgb(245, 158, 11)` unknown, `rgb(186, 26, 26)` blocked) — but those colours
   carry **trust** semantics, not **role** semantics. Reusing them for
   Owner/Admin/Member would import a meaning the design never assigned, which
   is inventing language by borrowing it. All three role labels therefore
   render in one neutral treatment.

Out of this contract entirely: the control frames that carry rename/add/
remove/promote/transfer/delete (`E07-T03`), key rotation on membership change
(`E07-T05`), and the group thread itself (GAP-020, still waiting on
`OQ-E07-13`).

## Surface story — which parent supplies what
`devices.md` supplies the **management vocabulary**: the per-peer row with a
trailing slot and a state label (elements 8-15), the inline per-row action chip
(element 31 — `Verify`), the primary button (element 6 — `Discover`), the
screen title/subtitle pair (elements 4/5), and the destructive text colour
`rgb(186, 26, 26)` (elements 32/37/38).

`conversations.md` supplies the **frame**: the header icon-button (48×48
`r9999px`, glyph `24px` `rgb(195, 192, 255)` — elements 1/2, 4/5), the
`heading:2` section heading (`22px` `w500` `rgb(234, 241, 255)` — 8/21), the
editable-name field (element 7's textbox), the avatar-initials treatment
(element 15), and the row title (10/16/23).

## States

The role states are not variants of one screen with things hidden — they are
**what the matrix returns**, rendered. A row's chip set is exactly the set of
actions for which `GroupPermissions.allows(actorRole, action, subjectRole)` is
true. Nothing is drawn and disabled; a forbidden action is absent.

### 1. `owner`
Name editable. Every permitted chip renders. `Delete group` renders.
**`Leave group` does NOT render** — `allows(owner, leave)` is `false` until
ownership is transferred (`E07-T02` §2, the single-owner invariant), so
drawing it would promise an action the matrix refuses.

### 2. `admin`
Name editable (`rename` ✅). Chips: `Remove` on Member-role rows only.
`Leave group` renders. `Delete group` does not.

### 3. `member-readonly` — a required state, not an edge case
The roster renders in full, the group name renders as **static text** rather
than a field, and **no management chip renders on any row**.

> **Clarification against GAP-019's wording.** GAP-019 says a Member "sees the
> roster and no actions at all". Read literally against `E07-T02`'s matrix that
> is one row too strong: `allows(member, leave)` is **`true`** — every role may
> leave. So a Member sees no *management* actions, and `Leave group` still
> renders. This contract follows the matrix, which is the named source of
> truth in GAP-019's own proposal; the discrepancy is recorded in
> `design/gaps.md` under GAP-019 rather than silently resolved here.

### 4. `confirm-leave` / 5. `confirm-delete` — the approved fork (1)
A **full-screen step**, not a dialog. It replaces the screen's body; the
header (GM1/GM2) stays, and back cancels. No scrim, no elevation, no new
surface — a modal primitive is exactly what fork (1) chose not to introduce.

### 6. `loading` / 7. `error`
`loading`: the frame with an unpopulated roster (the design draws no spinner
or skeleton anywhere, so none is invented). `error`: one centred line in the
roster area, in GAP-002's already-approved treatment; the roster is not
cleared and no destructive step is entered.

## Elements — the build checklist

### Frame (all role states)
| # | role | copy / label | size | key styles (cited from the parent contracts) |
|---|---|---|---|---|
| GM1 | `button` | — | 48×48 | `r9999px` — the conversations header icon-button (conv 1/4) |
| GM2 | `generic` | `arrow_back` | 24×24 | `24px` · `rgb(195, 192, 255)` — the conversations header glyph treatment (conv 2/5); glyph from `chat.md` (chat 2) |
| GM3 | `textbox:text` | (the group's name) | 358×39 | `14px` · `bg rgb(229, 238, 255)` · `r8px` — the conversations search field (conv 7). **`owner`/`admin` only** |
| GM3b | `heading:2` | (the group's name) | 358×28 | `22px` · `w500` · `rgb(234, 241, 255)` — the section-heading treatment (conv 8/21). **`member-readonly` only**, replacing GM3 |
| GM4 | `generic` | (member count, e.g. `4 members`) | 242×40 | `14px` · `rgb(70, 69, 85)` — the devices screen subtitle (devices 5) |
| GM5 | `heading:2` | `Members` | 358×28 | `22px` · `w500` · `rgb(234, 241, 255)` — (conv 8/21) |

### Member row (repeated)
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| GM6 | `generic` | (initials, e.g. `MS`) | 35×28 | `22px` · `w500` · `rgb(53, 37, 205)` — the conversations avatar-initials treatment (conv 15) |
| GM7 | `heading:3` | (member name) | — | `w500` · `rgb(11, 28, 48)` — the devices row title (devices 9/17/25/33) |
| GM8 | `generic` | `Owner` \| `Admin` \| `Member` | — | `12px` · `w500` · `rgb(70, 69, 85)` — the devices state-label treatment (devices 14/22/30/38) in the neutral colour, per §Derivation boundary 4. **A plain text label — fork (2), as approved. No icon.** |
| GM9 | `button` | `Remove` | ≥56×24 | `11px` · `rgb(53, 37, 205)` · `r8px` — the devices `Verify` chip (devices 31), with the radius substitution from §Derivation boundary 2 |
| GM10 | `button` | `Make admin` | ≥56×24 | as GM9 |
| GM11 | `button` | `Revoke admin` | ≥56×24 | as GM9 |
| GM12 | `button` | `Transfer ownership` | ≥56×24 | as GM9 |

**Chip layout is load-bearing.** GM9-GM12 **wrap** onto their own line inside
the row rather than sitting after a `Spacer()` in the title row. `E06-B01` is
this exact row shape overflowing by 57px and hanging `flutter test` for a full
10-minute timeout when trailing content after a `Spacer()` had no width bound.
GM7 is the flexible child with an ellipsis policy; a member name is
user-supplied.

**Which chips render, per the matrix (`E07-T02` §5) — this table is derived
from it, not a second copy of it:**

| Actor \ subject | Owner row | Admin row | Member row |
|---|---|---|---|
| Owner | — | `Remove`, `Revoke admin` | `Remove`, `Make admin`, `Transfer ownership` |
| Admin | — | — | `Remove` |
| Member | — | — | — |

(`Transfer ownership` is Owner-only and targets a member; `grantAdmin` /
`revokeAdmin` are Owner-only. Every cell above is `allows(...) == true` in the
matrix. If they ever diverge, regenerate this table from the matrix.)

### Screen actions (bottom of the roster)
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| GM13 | `button` | `Leave group` | ≥56×24 | the GM9 chip treatment with its label at `rgb(186, 26, 26)` — devices' measured destructive text colour (devices 32/37/38). Renders when `allows(role, leave)`: **Admin and Member only** |
| GM14 | `button` | `Delete group` | ≥56×24 | as GM13. **Owner only** |

No filled destructive button exists anywhere in the design, so none is drawn:
`rgb(186, 26, 26)` stays in its measured role as a **text** colour.

### States `confirm-leave` / `confirm-delete`
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| GM15 | `heading:2` | `Leave group?` \| `Delete group?` | 242×28 | `22px` · `w500` · `rgb(11, 28, 48)` — the devices screen title (devices 4) |
| GM16 | `generic` | (consequence line — see §Copy) | 242×40 | `14px` · `rgb(70, 69, 85)` — the devices subtitle (devices 5) |
| GM17 | `button` | `Cancel` | ≥56×24 | the GM9 chip, label `rgb(53, 37, 205)` |
| GM18 | `button` | `Leave group` \| `Delete group` | ≥56×24 | the GM9 chip, label `rgb(186, 26, 26)` |

### State `error`
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| GM19 | `generic` | `Couldn't apply that change. Try again.` | — | `14px` · `rgb(70, 69, 85)`, centred — GAP-002's approved treatment. No error colour is invented (GAP-009's precedent) |

## Copy — verbatim
Strings this contract introduces (proposed copy):

- `Members`
- `Owner`
- `Admin`
- `Member`
- `Remove`
- `Make admin`
- `Revoke admin`
- `Transfer ownership`
- `Leave group`
- `Delete group`
- `Leave group?`
- `Delete group?`
- `You'll stop receiving this group's messages.` *(consequence line, leave)*
- `This deletes the group for everyone. It can't be undone.` *(consequence line, delete)*
- `Cancel`
- `Couldn't apply that change. Try again.`
- `4 members` *(format `N members`; the number is data, the format is the contract)*

Reused unchanged from `chat.md`: `arrow_back`.
**No glyph is introduced by this contract** — the only glyph on the screen is
`arrow_back`, which already exists. Nothing here is marked
`[glyph — pending human confirmation]`.

## Tokens — every value cited from a parent contract's measured table
Every value below is in a parent contract's §"Tokens this screen actually
uses". Two further colours appear in this document — `rgb(78, 222, 163)` and
`rgb(245, 158, 11)` — **only in §Derivation boundary 4, naming the devices
trust colours this contract deliberately does not reuse**. They are not
tokens of this screen and no element below uses them.

| role | value | source contract | used here for |
|---|---|---|---|
| text colour | `rgb(234, 241, 255)` | conversations | GM3b, GM5 |
| text colour | `rgb(195, 192, 255)` | conversations · devices | GM2 |
| text colour | `rgb(11, 28, 48)` | conversations · devices | GM7, GM15 |
| text colour | `rgb(70, 69, 85)` | conversations · devices | GM4, GM8, GM16, GM19 |
| text colour | `rgb(53, 37, 205)` | conversations | GM6, GM9-GM12, GM17 |
| text colour | `rgb(186, 26, 26)` | devices (32/37/38) | GM13, GM14, GM18 |
| surface / fill | `rgb(229, 238, 255)` | conversations | GM3 field fill |
| font size | `22px` | conversations · devices | GM3b, GM5, GM6, GM15 |
| font size | `14px` | conversations · devices | GM3, GM4, GM16, GM19 |
| font size | `12px` | conversations · devices | GM8 |
| font size | `11px` | devices | GM9-GM14, GM17, GM18 |
| font size | `24px` | conversations · devices | GM2 |
| font weight | `500` | conversations · devices | headings, labels, names |
| radius | `8px` | conversations · devices | GM3, all chips |
| radius | `9999px` | conversations · devices | GM1 |
| font family | `Material Symbols Outlined` | conversations · devices | `arrow_back` |
| font family | `Inter` | conversations · devices | all prose |

## Derivation
| What | Borrowed from | Serves |
|---|---|---|
| per-peer row, state-label treatment, inline action chip, screen title/subtitle, destructive text colour | `design/screens/devices.md` (elements 4, 5, 6, 8-15, 31, 32/37/38) | FR-GROUP-002, FR-GROUP-003 |
| frame, header icon-button, section headings, editable-name field, avatar initials, row title | `design/screens/conversations.md` (elements 1/2, 4/5, 7, 8, 10, 15, 16, 21) | FR-GROUP-001, FR-GROUP-002 |
| `arrow_back` glyph | `design/screens/chat.md` (element 2) | navigation |
| centred error line | GAP-002, already approved and built | FR-GROUP-002 |
| which chips exist at all | `E07-T02` `GroupPermissions.allows` — not a design source, the **authority** | FR-GROUP-001, FR-GROUP-002, FR-GROUP-003 |

**Spec served:** FR-GROUP-001 (Owner/Admin/Member — GM8 is where the roles
become visible at all), FR-GROUP-002 (rename → GM3; add → `group-create.md`;
remove, assign administrators, transfer ownership, delete → GM9-GM14),
FR-GROUP-003 (Admins perform permitted actions, Members participate — the
`admin` and `member-readonly` states are literally this requirement rendered).

## Notes for the implementing agent
- **Never re-implement the matrix in a widget.** Call
  `GroupPermissions.allows`. Two similar answers is the failure `E07-T02`
  exists to prevent.
- The role a row shows is the member's **current role in this group**, loaded
  locally — never a role a control frame claims for itself (`E07-T02` §2).
- A removed member has no role and no row. Do not render a tombstone; the
  membership-event line in the thread (GAP-020) is where a removal is visible,
  once `OQ-E07-13` is answered and that contract is written.
- Read `E06-B01` before laying out the member row. Same shape, same trap.
- Once built, extract the built screen as its own golden.
