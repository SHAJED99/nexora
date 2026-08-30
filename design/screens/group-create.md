---
id: group-create
impl_path: /groups/new
source: derived
derived_from: [conversations, devices]
states: [default, empty, loading, error]
viewports: [390x844]
golden: none yet — extract from the build once implemented
spec: [FR-GROUP-001, FR-GROUP-002, FR-COMM-002]
gap: GAP-018
---
# group-create · derived design contract

> **`source: derived` — hand-written, not generated.** The design source draws
> **nothing** about creating a group: no entry point, no name field, no member
> picker. What it does draw is a `Groups` heading with three populated rows
> (`conversations.md` elements 21-33) and no way to have made any of them.
> This contract composes the missing screen **only** from primitives
> `design/screens/conversations.md` and `design/screens/devices.md` already
> measure.
>
> **Built against GAP-018, approved by the human on 2026-08-31 ("approved as
> proposed").** This contract is *written against* that approval; it is **not
> independently approved by an agent**, and one element in it — the entry
> point, which GAP-018 deliberately left to this pass — is explicitly still
> open (see §Open — the entry point). Written by `E07-T12`.

- **Route:** `/groups/new` — a new route. Registering it is the build task's
  job, not this contract's.
- **Parent contracts:** `design/screens/conversations.md` (frame, headings,
  search field, row content) · `design/screens/devices.md` (the per-row
  trailing action slot and the row state-label pair)
- **Reached from:** `/conversations` — see §Open below.
- **Leads to:** `/chat/:id` for the new group's thread on success.

## Derivation boundary — what is NOT derived

1. **The entry point.** GAP-018 says in as many words that the entry point is
   "deliberately not proposed here … `E07-T12` proposes it as part of the
   contract and the human approves it there, or it waits." It is proposed in
   §Open below and it is **not** covered by the 2026-08-31 clearance.
2. **New copy.** A screen the design never drew has strings the design never
   wrote. Every string this contract introduces is listed verbatim in §Copy
   and is proposed copy, in the voice `devices.md` already uses
   (`Manage paired and nearby devices.`). Glyph identities that no contract in
   `design/screens/` draws are marked `[glyph — pending human confirmation]`,
   exactly as `chat-voice.md` marked its own.
3. **Nothing else.** Every size, colour, weight, radius and family below is
   grep-verifiable in one of the two parent contracts' measured token tables.

Explicitly out of this contract: how trusted contacts are queried, the group
id, the key distribution that follows creation (`E07-T04`), and the control
frame that carries the create (`E07-T03`). Those are backend contracts.

## Surface story — which parent supplies what
`conversations.md` is the **frame**: the screen ground, the header icon-button
treatment (48×48 `r9999px`, glyph `24px` `rgb(195, 192, 255)` — elements 1/2,
4/5), the `heading:2` section heading (`22px` `w500` `rgb(234, 241, 255)` —
elements 8/21), the search-field textbox (358×39, `14px`, `bg rgb(229, 238,
255)`, `r8px` — element 7), and the row content vocabulary (initials `22px`
`w500` `rgb(53, 37, 205)` — element 15; title `w500` `rgb(11, 28, 48)` —
elements 10/16/23; secondary line `14px` `rgb(70, 69, 85)` — elements 13/19).

`devices.md` supplies exactly two things, and only because
`conversations.md` has no equivalent: the **per-row trailing action slot**
(`button` 24×30 with a `24px` `rgb(119, 117, 135)` glyph — elements 11/12) and
the **row state-label pair** (`check_circle` 16×16 + a `12px` `w500` label in
the state's own colour — elements 13/14). The primary action reuses devices'
`Discover` button (`116×34`, `12px` `w500` `rgb(255, 255, 255)`,
`bg rgb(53, 37, 205)`, `r8px` — element 6), which is this design's only
measured primary button.

## States

### 1. `default`
At least one trusted contact exists. Name field, member list, primary action.
The primary action is **disabled** until a non-empty name and ≥1 selected
member exist (FR-GROUP-002 presupposes a named group with members).

### 2. `empty`
No trusted contact exists yet, so there is nobody to add. The name field and
the section heading stay (rule 2 / design-fidelity rule 3 — never delete an
element to satisfy the data layer); the list area carries one centred line.

### 3. `loading`
The trusted-contact list is being read. Same frame; the list area is blank.
The design draws no spinner or skeleton anywhere in seven contracts, so none
is invented — this state is the frame with an unpopulated list.

### 4. `error`
Creation failed (`AppFailure`, the one error envelope from
`docs/conventions.md`). The frame is unchanged; one line renders in the list
area's own treatment above the primary action, and **the entered name and the
selection are not cleared**.

## Elements — the build checklist

### Frame (all states)
| # | role | copy / label | size | key styles (cited from the parent contracts) |
|---|---|---|---|---|
| GC1 | `button` | — | 48×48 | `r9999px` — the conversations header icon-button (conv 1/4) |
| GC2 | `generic` | `arrow_back` | 24×24 | `24px` · `rgb(195, 192, 255)` — the conversations header glyph treatment (conv 2/5); the glyph itself is `chat.md`'s existing `arrow_back` (chat 2), not a new one |
| GC3 | `heading:2` | `New Group` | 358×28 | `22px` · `w500` · `rgb(234, 241, 255)` — the section-heading treatment (conv 8/21) |
| GC4 | `generic` | `dns` | 24×24 | `24px` · `rgb(0, 70, 102)` — the group glyph and colour the Groups row already uses (conv 22) |
| GC5 | `textbox:text` | placeholder: `Group name` | 358×39 | `14px` · `bg rgb(229, 238, 255)` · `r8px` — the search field, unchanged in every measurable respect (conv 7) |
| GC6 | `heading:2` | `Members` | 358×28 | `22px` · `w500` · `rgb(234, 241, 255)` — same as GC3 (conv 8/21) |
| GC7 | `button` | `Create group` | 116×34 | `12px` · `w500` · `rgb(255, 255, 255)` · `bg rgb(53, 37, 205)` · `r8px` — the `Discover` primary button (devices 6). Disabled treatment: the same button with its label at `rgb(119, 117, 135)`, the muted colour conversations already uses for an inactive nav item (conv 35/36) — no new colour, no opacity value |

### State `default` — one member row, repeated
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| GC8 | `generic` | (initials, e.g. `MS`) | 35×28 | `22px` · `w500` · `rgb(53, 37, 205)` — the conversations avatar-initials treatment (conv 15). Used rather than conv 9's 46×46 `image`, because no avatar asset exists for a trusted contact |
| GC9 | `generic` | (contact name) | — | `w500` · `rgb(11, 28, 48)` — the conversations row title (conv 10/16/23) |
| GC10 | `generic` | `check_circle` | 16×16 | `rgb(78, 222, 163)` — the devices trusted-state glyph, unchanged (devices 13) |
| GC11 | `generic` | `Trusted Node` | 92×16 | `12px` · `w500` · `rgb(78, 222, 163)` — the devices state label, copy unchanged (devices 14) |
| GC12 | `button` | — | 24×30 | the devices per-row trailing action slot (devices 11/19/27/35) |
| GC13 | `generic` | `radio_button_unchecked` | 24×24 | `24px` · `rgb(119, 117, 135)` — unselected. The glyph is `dashboard.md`'s existing `radio_button_unchecked` (dashboard 33); the size and colour are the devices trailing-slot glyph treatment (devices 12) |
| GC14 | `generic` | `radio_button_checked` | 24×24 | `24px` · `rgb(53, 37, 205)` — selected. The glyph is devices' own `radio_button_checked` (devices 21); the colour is conversations' accent text colour (conv 15) |

**Row layout is load-bearing, not cosmetic.** `E06-B01` fixed two real
`RenderFlex` overflows in exactly this row shape — a trailing widget after a
`Spacer()` with no width bound overflowed by 57px and hung the test harness
for its full 10-minute timeout. The trailing slot (GC12-GC14) is fixed-width
and the name (GC9) is the flexible child with an ellipsis overflow policy.
A contact name is user-supplied and can be arbitrarily long.

### State `empty`
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| GC15 | `generic` | `No trusted contacts yet` | — | `14px` · `rgb(70, 69, 85)`, centred — **not re-derived here**: this is GAP-002/GAP-006/GAP-007's already-approved and already-built centred-subtitle pattern (`NexoraTextStyles.devicesSectionSubtitle`), reused with this screen's noun. GC7 is disabled in this state |

### State `error`
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
| GC16 | `generic` | `Couldn't create the group. Try again.` | — | `14px` · `rgb(70, 69, 85)`, centred — the same treatment as GC15. The design draws **no** error colour on either parent screen; introducing one would be the first invented token on this screen, so the failure is carried by the words, exactly as GAP-009 refused to invent an error colour for the `Failed` tick |

## Copy — verbatim
Strings this contract introduces (proposed copy — see §Derivation boundary):

- `New Group`
- `Group name` *(placeholder)*
- `Members`
- `Create group`
- `No trusted contacts yet`
- `Couldn't create the group. Try again.`

Reused unchanged from `conversations.md`: `dns`.
Reused unchanged from `devices.md`: `check_circle`, `Trusted Node`,
`radio_button_checked`.
Reused unchanged from `chat.md`: `arrow_back`.
Reused unchanged from `dashboard.md`: `radio_button_unchecked`.

No glyph in this contract is new — all five are already drawn somewhere in
`design/screens/`. There is nothing here marked
`[glyph — pending human confirmation]`.

## Tokens — every value cited from a parent contract's measured table
No value here is new. Each row is grep-verifiable in the named contract —
in its §"Tokens this screen actually uses" unless the row says otherwise.

> **Two rows are measured on an *element* rather than listed in a token
> table**, and are marked ⁂ below: `rgb(0, 70, 102)` (conversations element
> 22, the `dns` glyph) and `rgb(78, 222, 163)` (conversations element 12 /
> devices elements 13-14, the trusted-state pair). The generator's token
> table lists a screen's most-used values, not all of them, so a
> single-use measured value can be real and still absent from it. Both are
> measured design values from a parent contract's own element table — not
> invented — but a token-table-only check (`EARS-UI-6`) will not find them,
> so they are called out here rather than left to look like drift.

| role | value | source contract | used here for |
|---|---|---|---|
| text colour | `rgb(234, 241, 255)` | conversations | GC3, GC6 section headings |
| text colour | `rgb(195, 192, 255)` | conversations | GC2 header glyph |
| text colour | `rgb(11, 28, 48)` | conversations | GC9 contact name |
| text colour | `rgb(70, 69, 85)` | conversations · devices | GC15, GC16 |
| text colour | `rgb(119, 117, 135)` | conversations · devices | GC13, GC7 disabled label |
| text colour | `rgb(53, 37, 205)` | conversations | GC8 initials, GC14 selected |
| text colour | `rgb(255, 255, 255)` | conversations · devices | GC7 label |
| text colour ⁂ | `rgb(0, 70, 102)` | conversations, element 22 | GC4 `dns` |
| text colour ⁂ | `rgb(78, 222, 163)` | conversations element 12 · devices elements 13/14 | GC10, GC11 |
| surface / fill | `rgb(229, 238, 255)` | conversations | GC5 field fill |
| surface / fill | `rgb(53, 37, 205)` | conversations · devices | GC7 fill |
| font size | `22px` | conversations · devices | GC3, GC6, GC8 |
| font size | `14px` | conversations | GC5, GC15, GC16 |
| font size | `12px` | conversations · devices | GC7, GC11 |
| font size | `24px` | conversations · devices | GC2, GC4, GC13, GC14 |
| font weight | `500` | conversations · devices | headings, labels, names |
| radius | `8px` | conversations · devices | GC5, GC7 |
| radius | `9999px` | conversations · devices | GC1 |
| font family | `Material Symbols Outlined` | conversations · devices | all glyphs |
| font family | `Inter` | conversations · devices | all prose |

## Open — the entry point (NOT covered by GAP-018's clearance)
GAP-018 was approved as proposed, and what it proposed was to leave this one
decision to this contract. So it is put here, undecided:

**Proposal.** A create-group affordance in `conversations.md`'s **header**, in
that screen's own icon-button vocabulary: `button` 48×48 `r9999px` (conv 1/4)
with the glyph `add` at `24px` `rgb(195, 192, 255)` (conv 2/5 treatment;
`add` is an existing glyph — `chat.md` element 27). Nothing else about
`conversations.md` changes.

**What it costs.** It adds an element to a *measured* contract.
`make design-verify SCREEN=conversations` will then report it as an **extra
element**, and the reviewer traces that finding to this entry
(`design-fidelity` §6). `conversations.md` is **not** hand-edited to
accommodate it — `E07-T12` §4 forbids that and design-fidelity rule 1 forbids
it generally.

**Alternatives considered and not proposed.** A floating action button (no FAB
exists anywhere in seven contracts — a new primitive), and a row at the top of
the `Groups` section (it would sit inside the list and read as a group).

**Status:** ⏳ awaiting the human. Until it is approved, no build task adds any
affordance to `conversations.md`; `/groups/new` is reachable only by direct
navigation.

## Derivation
| What | Borrowed from | Serves |
|---|---|---|
| screen ground, header icon-button, section headings, name field, row content, disabled/muted colour | `design/screens/conversations.md` (elements 1/2, 4/5, 7, 8, 10, 13, 15, 16, 21, 22, 23, 35/36) | FR-GROUP-001, FR-GROUP-002 |
| per-row trailing action slot, row state-label pair, primary button | `design/screens/devices.md` (elements 6, 11/12, 13/14, 21) | FR-GROUP-002 (add members) |
| `arrow_back` glyph | `design/screens/chat.md` (element 2) | navigation |
| `radio_button_unchecked` glyph | `design/screens/dashboard.md` (element 33) | selection affordance |
| centred empty/error line | GAP-002 / GAP-006 / GAP-007, already approved and built | FR-GROUP-002, FR-COMM-002 |

**Spec served:** FR-GROUP-001 (a group with roles must first exist),
FR-GROUP-002 (the Owner's powers presuppose a group someone created),
FR-COMM-002 (group communication), `spec/feature-list.md` §Personal & Group
Communication → "UC: Owner creates and manages a group".

## Notes for the implementing agent
- The creator becomes the **Owner** — that is `E07-T03`'s doing, not this
  screen's. This contract renders no role on this screen at all.
- Selection state is UI state. Whether a *blocked* peer may be added is
  `E07-T03`'s composition of `GroupPermissions` with `RelationshipRepository`
  (`E07-T02` §4), never a rule re-decided in a widget.
- Do not add a search field over the member list. It would be a second
  instance of GC5's primitive with no spec id behind it; if the list proves
  unusable at length, that is a gap entry, not a build-time decision.
- Read `E06-B01` before laying out the member row. Same shape, same trap.
- Once built, extract the built screen as its own golden — from then on it is
  regression-gated like every other screen (`design-fidelity` §3).
