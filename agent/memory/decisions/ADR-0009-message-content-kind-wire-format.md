---
status: accepted
date: 2026-09-28
proposed_by: claude-opus-5 (supervisor session)
decided_by: human, 2026-09-28
traces_to: [FR-MSG-001, FR-MSG-002, FR-COMM-002, FR-LOC-003, FR-ROUTE-003, FR-ROUTE-004, design/gaps.md GAP-015]
supersedes: none
---

# ADR-0009 — Message content-kind wire format (envelope v2)

## Context

Attachments, voice notes and location-in-chat are all specified product
journeys, and **none of them can be built**, because a receiver cannot tell
what a message contains.

Neither encrypted envelope carries a content discriminator:

- `MessageEnvelope` (1:1) —
  `[u8 0xE5][u32 idLen][id][u32 cidLen][cid][u64 seq][payload…]`
- `GroupMessageEnvelope` —
  `[u8 1][u32 gidLen][gid][u32 epoch][u32 sndLen][snd][u32 midLen][mid]
  [u64 seq][u64 createdAtMs][body…]`

The payload/body is opaque bytes. Today it is always text by convention, and
that convention is the only thing making it readable.

**The frame-level type system cannot be used for this.** `PayloadType`
(`preKeySignalMessage` / `signalMessage` / `control`) is relay-visible
metadata by design, and the `kControlKind` registry (1-8) is carried in
cleartext. Putting "this is a voice note" in either would disclose content
type to every relay that forwards the packet — a direct regression against
`FR-ROUTE-003`/`FR-ROUTE-004`. **The discriminator must live inside the
encrypted envelope.**

A second, easily-missed half: the local `messages` table has no content-type
column either (`id, conversationId, senderDeviceId, sequenceNumber,
ciphertext, plaintextPayload, createdAt, deliveryState`). Wire alone is not
enough.

## Options considered

1. **Version bump + kind byte.** A new envelope version carrying an explicit
   `u8 kind`. Pros: explicit, extensible, no ambiguity, fails loudly on old
   receivers. Cons: two envelope formats to maintain; old peers cannot render
   new content.
2. **Self-describing inner envelope inside v1.** A nested header inside
   `payload`/`body`, no version change. Pros: envelopes untouched. Cons:
   **existing text payloads are raw bytes with no header**, so a new receiver
   cannot reliably distinguish "old text" from "new inner envelope" without a
   sentinel that may collide with real text. That is precisely the silent
   mis-parse class `E05-B01` already cost this project once, and the
   `0xE5`/`!=` hardening exists specifically to prevent it.
3. **Defer.** Attachments, voice and location stay unbuildable; the approved
   `image_picker`/`file_picker`/`record`/`just_audio` dependencies and the
   approved M4A/AAC-LC/2-minute audio format stay unused.

## Decision

**Option 1 — version bump plus an explicit kind byte**, with a compatibility
rule that keeps the working path byte-identical.

### Wire layout

The kind byte is inserted immediately after the version byte; every
subsequent field keeps its order and shifts by exactly one.

| | v1 (unchanged) | v2 |
|---|---|---|
| `MessageEnvelope` | `[u8 0xE5]…` | `[u8 0xE6][u8 kind]…` |
| `GroupMessageEnvelope` | `[u8 1]…` | `[u8 2][u8 kind]…` |

Note the asymmetry, which is pre-existing and deliberate: `MessageEnvelope`'s
version field is a **magic sentinel** (`0xE5`), not a counter, so its "v2" is
a second accepted sentinel `0xE6`. `GroupMessageEnvelope` uses a real
monotonic version, so its v2 is `2`. Both currently validate with strict
`!=`; both become a known-set check.

### Kind values

`1 = text` · `2 = image` · `3 = file` · `4 = voice` · `5 = location`

Exactly the currently intended journeys and nothing more. `text` is defined
so the decoder is total, but is **never emitted** — see the emission rule.
Image and file are distinct because the approved pickers are distinct
affordances (`image_picker` / `file_picker`; `GAP-015`'s `image`,
`photo_camera`, `attach_file` glyphs).

### Emission and decode rules

- **Emit v1 for text.** The existing text path produces byte-identical
  output — not merely compatible, identical.
- **Emit v2 only for non-text.**
- **Decode v1 as text**, unconditionally.
- **Unknown kinds are neither guessed nor silently dropped.** No inference
  from payload shape, filename, magic bytes or MIME sniffing. The message is
  preserved and rendered as a distinct placeholder.
- **Malformed v2** (version byte present, kind byte missing) throws, matching
  every other bounds check in these files.

### Local persistence

An additive **v24 → v25** migration adds a nullable kind field to `messages`.
`null` means text, covering every existing row. No backfill is attempted or
possible.

### Explicitly unchanged

Sender-key handling · Double Ratchet · the relay path · `PayloadType` ·
cleartext control-kind handling. The kind byte lives inside already-encrypted
plaintext, so relays observe nothing new and the encryption boundary is not
redesigned.

## Consequences

- **The working text and group sender-key path never executes new code**,
  because it never emits v2. This is the whole point of the emission rule and
  the main reason option 1 beat option 2.
- **An old peer receiving an attachment rejects it loudly** —
  `FormatException` for 1:1, `AppFailure('group.malformed_message')` for
  group. It could not render one anyway, and a loud rejection is strictly
  better than the silent mis-parse option 2 risked.
- **Old peers handle existing text exactly as today.** No behaviour change of
  any kind on the v1 path.
- **The unknown-kind placeholder copy is an open Rule-2 decision**, not
  settled here. It must read as distinct from both
  `(unable to decrypt this message)` and `Message hidden — contact is
  blocked`, because all three mean different things and conflating them makes
  the app misreport its own reason (the mistake `GAP-045` took four review
  rounds to avoid). Implementation stops at that point for a human decision.
- Two envelope versions now need maintaining, and every future kind addition
  is a deliberate, reviewable change rather than an implicit one.

## Scope fence

This ADR authorises the discriminator and nothing else. It does **not**
authorise attachment transfer/chunking design, thumbnailing, a media store,
or any change to `PayloadType`, the control-kind registry, relay behaviour or
the crypto layer. Those are separate decisions.
