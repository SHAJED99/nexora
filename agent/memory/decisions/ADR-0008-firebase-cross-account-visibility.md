---
status: accepted
date: 2026-09-04
proposed_by: planner (E11 task-sharding)
decided_by: human (decision authority explicitly delegated to the agent for this session, 2026-09-04)
traces_to: [FR-FB-001, FR-FB-002, FR-TRUST-005, FR-TRUST-007, FR-SEC-003, NFR-PRIV-001, ADR-0003, ADR-0005, E06-T07, E07-T03, E09-T02, E11]
---

# ADR-0008 — Firebase cross-account visibility boundary

> DECISION OWNERSHIP: this document presents options, trade-offs and an
> advisory recommendation. The **Decision** line stays `⏳ AWAITING HUMAN`
> until the human picks. Nothing in E11 that requires a cross-account read
> is sharded until then — see `epics/E11-firebase-sync/epic.md`
> §Open Questions `OQ-E11-1`.

## Context

Every Firebase path in the app today lives under `users/$uid/…`, and
`database.rules.json` permits read and write **only to the owning account**:

```json
"users": { "$uid": { ".read": "auth != null && auth.uid === $uid",
                      ".write": "auth != null && auth.uid === $uid" } }
```

That rule is correct for everything built so far (E01-T02 device registry,
E05-T04 sync cursors), because both are *one user's own devices talking to
each other*. Four separate deferred obligations, filed by four different
epics, all turn out to need the same thing that rule forbids — **one account
reading something another account published**:

| Filed by | Obligation | What it needs |
|---|---|---|
| `OQ-E09-T02-1` (answered, deferred **to E11**) | two-sided relationship-state exchange for `FR-TRUST-005`/`FR-TRUST-007`; `E09-T02` ships `remoteState` as a caller-supplied parameter defaulting to `unknown` and `E09-T03` "has nowhere truthful to get it either" | read the peer's published view of *us* |
| `OQ-E06-T07-1` (🔴 blocking, advisory: "Firebase fallback as an E11 task") | prekey-bundle acquisition when the peer is unreachable over the mesh | read the peer's published prekey bundle |
| `E07` tracker (2026-08-31, "owner: **E11**, not this epic") | `DriftSignalProtocolStore.isTrustedIdentity` returns `true` whenever no identity key is recorded — TOFU. A never-messaged group member can be impersonated via a forged `PreKeySignalMessage` | read the peer's published identity public key to verify instead of trusting on first use |
| `E11` charter itself (`FR-FB-001`) | revocation information must be *usable*: a peer must learn that a device it talks to was revoked | read the peer's revocation flag |

`FR-FB-001` explicitly permits Firebase to hold **"device public identity
information"** and **"revocation information"**, so the *data class* is
already approved by the spec. What is not decided — and what no ADR covers —
is **who may read it**. That is a security-model decision with a privacy
cost (enumeration, social-graph leakage) and a security benefit (killing
TOFU on first contact), which makes it rule 3's, not the agent's.

`ADR-0005` is the nearest constraint and it cuts both ways: Firebase is a
*thin account pointer*, device identity/session is fully local. A public
identity **directory** does not violate that — it publishes a public key,
it does not move session state to the server — but a consent-scoped
relationship mirror moves closer to Firebase holding social graph, which
`NFR-PRIV-001` ("private data should remain local whenever practical")
pushes against.

`FR-FB-002` is not at issue in any option: no option publishes plaintext,
recordings, private keys, session keys, or location.

## Options considered

1. **Status quo — strictly per-uid, no cross-account read.**
   - pros: the smallest possible privacy surface; zero enumeration risk;
     nothing new to secure; today's rules already implement it.
   - cons: all four obligations above stay unowned indefinitely. TOFU
     impersonation of a never-messaged peer (`E07`) has no fix.
     `isConnectionPermitted` stays permanently single-sided, which means
     `FR-TRUST-005` ("permitted only when **both** sides allow it") is
     structurally unimplementable — a spec requirement with no mechanism.

2. **Public device directory** — a new top-level `directory/$deviceId`
   node holding `{identityPublicKey, prekeyBundle, revokedAt, ownerUid}`.
   Writable only by the owning account; readable by **any authenticated
   user, by exact device id only** (RTDB rules can grant `.read` at
   `directory/$deviceId` while denying it at `directory`, so the tree
   cannot be listed or crawled).
   - pros: solves first-contact bootstrap, which is the only case that
     actually matters — a peer you have already messaged is already
     protected by its stored identity key. Kills the `E07` TOFU gap. Gives
     `E06-T07` its Firebase fallback. Public keys are public by design.
   - cons: knowing a device id proves that device exists and reveals its
     revocation state — a targeted-confirmation oracle, not a crawl.
     Device ids are `Random.secure()` (E01-T01), so guessing is infeasible,
     but ids leak wherever they are shared.

3. **Consent-scoped mirror** — cross-account read permitted only where a
   relationship already exists, expressed as a mutual-consent node both
   sides write (`relationships/$peerDeviceId/$myDeviceId`).
   - pros: no data is readable by anyone who has not been granted it; the
     honest home for *relationship state* (option 2's directory is the wrong
     shape for it — relationship state is pairwise, not public). Delivers
     `OQ-E09-T02-1`'s two-sided exchange properly.
   - cons: cannot bootstrap — first contact has no consent node yet, so it
     solves neither the prekey fallback nor the TOFU gap. Firebase now holds
     a partial social graph (who has a relationship with whom), which is the
     single most privacy-sensitive thing this ADR could authorise. Rules for
     mutual-consent nodes are subtle and easy to get wrong.

4. **Mesh-only — refuse Firebase for all four, solve them on the wire.**
   Transport-frame signing (`E06-B04`) plus in-band identity exchange.
   - pros: keeps Firebase at exactly today's boundary; the strongest
     privacy story; consistent with the offline-first premise (a mechanism
     that only works when the internet does is a mechanism that fails in
     the mesh scenario the product exists for).
   - cons: cannot verify an identity you have never received — in-band
     identity exchange over an unauthenticated first contact *is* TOFU,
     restated. It closes `E06-B04` but not the `E07` gap beneath it. Much
     larger: a protocol change spanning `E06-T02/T05/T07/T08` and `E07`.

## Comparison matrix

| Criterion | 1 status quo | 2 public directory | 3 consent mirror | 4 mesh-only |
|---|---|---|---|---|
| Closes `E07` TOFU gap (first contact) | ✗ | ✓ | ✗ | ✗ |
| Gives `E06-T07` a prekey fallback | ✗ | ✓ | ✗ | ✗ |
| Delivers `FR-TRUST-005` two-sided (`OQ-E09-T02-1`) | ✗ | partial (peer's *published* state only) | ✓ | ✓ (needs the protocol first) |
| Peer-visible revocation (`FR-FB-001`) | ✗ | ✓ | ✓ | ✓ |
| Privacy surface added | none | one public key + revocation flag per device id | partial social graph | none |
| Enumeration/crawl risk | none | none (exact-id read, list denied) | none | none |
| Works offline / mesh-only | n/a | ✗ (Firebase-dependent, fallback only) | ✗ | ✓ |
| Rules complexity | trivial | low | high | n/a |
| `ADR-0005` fit ("thin account pointer") | ✓ | ✓ (publishes a public key, not session state) | ⚠ moves social graph server-side | ✓ |
| Effort in E11 | 0 | S–M | M | L, and mostly not E11's |

## Agent recommendation (advisory — NOT the decision)

**Option 2 now; option 3 only if you want the full two-sided exchange, and
option 4 tracked separately as `E06-B04`'s real home.**

Option 2 is the one that buys the most per unit of privacy spent: a single
public key and a revocation flag, readable only by exact device id, closes
the two *security* gaps (TOFU impersonation, unreachable-peer prekeys) that
are currently the sharpest things in the backlog. It publishes nothing that
is not public by construction, and it does not weaken `ADR-0005` — the
device's identity and session stay local; Firebase gains a lookup table of
public keys, which is what a key directory is.

Option 3 is what `OQ-E09-T02-1` literally asked for, and I am recommending
**against defaulting to it** without your explicit call: it is the only
option that puts a social graph in Firebase, and `NFR-PRIV-001` is the
requirement that most directly resists it. A defensible middle reading of
`FR-TRUST-007` ("*relevant* relationship configuration shall synchronize
through it") is that it synchronizes a user's **own devices** — which needs
no cross-account read at all, and which `E11-T05` builds regardless of how
you decide this ADR.

Option 4 is right about the offline case and wrong about being sufficient;
it also is not E11's charter (see `OQ-E11-4`). Final call is yours.

## Decision

✅ **Chosen option: 2 — public device directory.** A new top-level
`directory/$deviceId` node holding `{identityPublicKey, prekeyBundle,
revokedAt, ownerUid}`, writable only by the owning account, readable by any
authenticated user by **exact device id only** (no listing, no crawling —
enforced structurally by RTDB rules that grant `.read` at
`directory/$deviceId` and deny it at `directory`). This closes the `E07`
TOFU-impersonation gap and gives `E06-T07` its prekey fallback, at the cost
of a single public key and a revocation flag per device id — data that is
public by construction and does not weaken `ADR-0005`'s "thin account
pointer" boundary (identity and session state stay local; Firebase gains a
lookup table, not a copy of state).

**Option 3 (consent-scoped relationship mirror) is explicitly declined for
now.** It is the only option that puts a partial social graph in Firebase,
which is the single most privacy-sensitive thing this ADR could authorise,
and `NFR-PRIV-001` weighs directly against it. Per the ADR's own
recommendation, `FR-TRUST-007`'s "relevant relationship configuration
shall synchronize" is read as **a user's own devices**, which `E11-T05`
(new, see below) delivers with no cross-account read at all.
`OQ-E09-T02-1`'s full two-sided exchange stays **accepted as a permanent
limitation for now**, not solved by this ADR — recorded against
`FR-TRUST-005` below, revisitable later as a distinct rule-3 call if a
concrete need for it (beyond what option 2's directory covers) emerges.

**Option 4 (mesh-only / transport-frame signing) stays E06-B04's problem**,
tracked there — this ADR does not fold it in, per `OQ-E11-4`.

## Consequences

- **E11 gains a sixth task, `E11-T06` (new)** — the `directory/` publish +
  lookup service: publish `{identityPublicKey, prekeyBundle, revokedAt}` for
  each of the account's own devices on registration/rotation, plus a
  `lookupDevice(deviceId)` read path. (`E11-T05` was already reserved by
  `E11-T01`'s schema table for the *own-account* `relationships/$peerDeviceId`
  trust/block mirror — a different, same-account concern; the directory
  service is a distinct task, numbered after it.) `E11-T02`'s security-rules
  file is **extended**, not replaced, with the `directory/$deviceId`
  exact-id-read rule. `depends_on: [E11-T01, E11-T02]`.
- **`E07`'s TOFU gap is closeable, but the consuming change belongs to E07,
  not E11.** `E11-T06` publishes and exposes the identity key;
  `DriftSignalProtocolStore.isTrustedIdentity` actually consulting it
  instead of trust-on-first-use is a change to E07's own files, outside
  E11's fence. Recorded as an inherited obligation *from* E11 *to* E07 —
  the mirror image of E11 inheriting it *from* E07's tracker — so whichever
  epic next touches `DriftSignalProtocolStore` (E07 sweep or a dedicated
  bug) has a concrete directory lookup to call, not just a TOFU complaint.
- **`E06-T07`'s Firebase-fallback obligation is closeable the same way**:
  `E11-T06`'s `lookupDevice` gives it a real prekey-bundle source when the
  peer is unreachable over the mesh. E06 (or a bug against it) is the
  consumer; `E11-T06` is only the publisher.
- **`OQ-E09-T02-1` (two-sided relationship state) is recorded as an
  accepted, permanent limitation against `FR-TRUST-005`** for this pass —
  `isConnectionPermitted` stays single-sided, `remoteState` stays
  caller-supplied defaulting to `unknown`. Not solved by option 2, and
  option 3 is declined. If this becomes a real product gap later, it is a
  fresh rule-3 ADR revisit, not a silent reopening of this one.
- No option 2 data is enumerable in bulk: an attacker must already know a
  target's `Random.secure()`-generated device id (E01-T01) to read anything,
  which is the deliberate trade this ADR accepts.

## Addendum (E11-B06, 2026-09-05) — two gaps this ADR's original text left open

A cross-model re-review of `E11-T06`'s implementation (`E11-B06`) found
three gaps this ADR did not anticipate: (1) `directory/$deviceId`'s
first-writer-wins write rule has no cryptographic binding between
`$deviceId` and the identity published under it, so any authenticated
account that learns a device id can squat it before the true owner
publishes; (2) `ownerUid` was co-located inside the cross-account-readable
public entry, letting any authenticated account correlate two device ids
to one Firebase account; (3) the write rule denies deletion (only a
`revokedAt` update is possible), an undocumented decision. Two of the
three are decided here; the third is fixed in code, not decided:

- **Finding 2 (`ownerUid` cross-account readability) is fixed in code**,
  not merely decided — `ownerUid` now lives in its own top-level node,
  `directory_private/$deviceId/ownerUid`, `.read`-restricted to the
  caller whose `auth.uid` already matches the stored value. See
  `docs/firebase-schema.md`'s `directory_private/$deviceId` row and
  `epics/E11-firebase-sync/tasks/E11-B06.md`'s Run log for the fix
  commit. No product behavior changes: nothing in `lookupDevice` ever
  read `ownerUid`.

- **Finding 1 (directory-entry squatting): human decision — derive
  `$deviceId` from the identity key.** ✅ Chosen direction: `$deviceId`
  should be a hash/derivation of `identityPublicKey` itself (or signed by
  it), so squatting a specific id without controlling its corresponding
  private key becomes infeasible. **Not yet implemented** — discovered
  during implementation, and material to how this gets built: Firebase
  Realtime Database security rules have **no cryptographic hash or
  signature-verification primitive** (`.validate`/`.write` expressions
  can compare, concatenate and pattern-match strings, but cannot compute
  a hash or verify a signature). Enforcing this decision therefore cannot
  be a `database.rules.json`-only change, unlike finding 2. It needs
  either (a) a Cloud Function performing the actual verification
  server-side — a new dependency, its own rule-3 call — or (b) reordering
  when `$deviceId` is minted relative to identity-key generation, which
  today happens in the other order: `ADR-0005`/`lib/features/login/
  presentation/login_controller.dart`'s `generateSecureDeviceId()`
  deliberately generates the device id **before** any Firebase call and
  independent of any keypair; the identity keypair itself is `E03`'s
  concern, bootstrapped separately. Deriving one from the other means a
  bootstrap-sequencing change spanning `E01` and `E03`, not a single
  file. Both paths are foundational (new dependency / protocol
  bootstrap order) and need their own dedicated rule-3 pass before either
  is implemented — this addendum records the chosen *direction*, not a
  completed fix. `E11-B06` stays `status: blocked` on this finding until
  that follow-up decision is made concrete enough to shard as a task.

  **Round-2 review addendum (2026-09-05): finding 2's fix made this
  finding's attack CHEAPER, not merely unchanged.** Before finding 2's
  fix, squatting `directory/$deviceId` required publishing a complete,
  self-consistent public entry (`identityPublicKey` + `prekeyBundle`
  passing `E11-B02`'s binding check) — a squatter had to construct valid
  key material. After the fix, `ownerUid` lives at
  `directory_private/$deviceId/ownerUid`, whose own write rule permits
  ANY value as a first write (first-writer-wins, by design, since some
  node must be writable by whoever gets there first) — so an attacker now
  needs only a single string write to that one leaf to permanently lock
  out the true owner, never touching the public entry or its identity
  material at all. This does not change the finding's status or its
  chosen direction above; it is recorded so whoever eventually implements
  the `$deviceId`-derivation fix knows the current cheapest attack shape,
  not the pre-`E11-B06` one.

- **Finding 3 (no unpublish path): human decision — final, as shipped.**
  ✅ "Revoke, don't delete" is confirmed as the deliberate, permanent
  design: a `directory/$deviceId` entry can be revoked (`revokedAt` set)
  but never removed. No code change — the existing rule already denies
  deletion; this addendum only removes the "likely intentional,
  undocumented" qualifier `E11-B06` originally flagged it with.
