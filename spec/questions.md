# Question Log — NEXORA

> The project's single question register. Procedure, priorities and the
> filter: `skills/question-resolution/SKILL.md`.

**Status:** 🟡 open · 🟢 answered · ⚪ closed (assumed or deferred)

## Gate status — 🧍 `blocking_questions_resolved`

**Gate:** 🧍 `blocking_questions_resolved` — ✅ cleared by human on 2026-09-08
(answering both questions the E15 planning pass reopened it for:
**Q-SEC-009** ((b), revoke best-effort) and **Q-FUNC-010** ((a), fix the
enrollment gate, accept the rate limit as-is) — both via `AskUserQuestion`,
matching the recommended defaults exactly. `E15-T01`/`E15-T02` unblocked.)
Previously ✅ cleared by human on 2026-08-26 for round 1's Q-SCOPE-002/
Q-DESIGN-001; that clearance stands unchanged.

| | Count |
|---|---|
| 🟡 blocking | 0 |
| 🟡 important | 4 |
| 🟡 optional | 0 |
| 🟢 answered | 4 |
| ⚪ assumed / deferred | 2 |

**Genesis and implementation may not proceed while any 🟡 blocking row exists.**

---

## Round log

| Round | Date | Asked | Answered | Notes |
|---|---|---|---|---|
| 1 | 2026-08-26 | 8 | 0 | intake unknowns from `documentation/BRD.md` + `documentation/Design.md`, grouped by area |
| 2 | 2026-09-08 | 2 | 0 | `IMP-003` / E15 planning pass — both blocking, both about what a wipe-logout does to state this app does **not** hold locally (the remote device registry) and to the two gates that read it (`E12-T03` enrollment, `E13-T02` rate limit). Two, not ten: everything else E15 needed was decidable from `spec/`, the ADRs, or the code, and a question that changes nothing is not a question |

Batching rule: **≤10 per round**, grouped by area.

---

## Open questions (🟡)

### Q-SEC-009 — What happens to the REMOTE device-registry row when a device signs out?
- **Priority:** blocking — blocks `E15-T01` (and therefore `E15-T07`)
- **Raised by:** `skills/change-impact` / `IMP-003`, 2026-09-08
- **Question:** `FR-AUTH-006` wipes everything **local**. It says nothing about
  `users/$uid/devices/<deviceId>` in the Realtime Database (`FR-FB-001`'s device
  registry), which is remote and survives. Should signing out also remove or
  revoke that remote entry?
- **Why it matters:** it decides whether an account's remote registry silently
  accumulates one dead device entry per logout — each one a public identity key
  that peers may still treat as a valid endpoint, and each one visible to
  `E12-T03`'s enrollment gate (see `Q-FUNC-010`). It is a security-model call:
  option (b) tells peers the keys are dead; option (a) leaves them merely stale.
- **Options considered:**
  - **(a) Do nothing remote.** Simplest, no new failure mode in the wipe path.
    Cost: dead entries accumulate; peers cannot distinguish a logged-out device
    from an offline one; `Q-FUNC-010`'s dead end becomes real.
  - **(b) Revoke via the existing mechanism** —
    `DeviceRevocationService.revoke(uid, deviceId)` already exists (`E12`) and is
    exactly the "this device's keys are no longer valid" signal. Cost: it is a
    network write inside a destructive local operation, so the wipe must not
    depend on it succeeding (best-effort, logged, never blocking — the pattern
    `FirebaseMetadataService.registerDevice` already uses).
  - **(c) Delete the registry row outright.** Cleanest registry, but loses the
    revocation *record* — a peer that never sees the deletion just keeps a key
    it will never hear about again.
- **Recommended default (advisory):** **(b)**, best-effort and non-blocking. It
  reuses a shipped mechanism, it is the only option that actively tells peers
  anything, and its failure mode (network down during logout) degrades to (a)
  rather than to a stuck wipe.
- **Status:** 🟢 answered
- **Answer:** **(b)** — revoke via `DeviceRevocationService.revoke(uid, deviceId)`,
  best-effort and non-blocking. If the network write fails (offline at
  logout), the local wipe proceeds anyway and the failure is logged, not
  surfaced as an error — degrading to option (a)'s outcome, never to a
  stuck wipe.
- **Answered by:** human, via `AskUserQuestion` ("Revoke it, best-effort")
- **Date:** 2026-09-08
- **fed_into:** `FR-AUTH-006`'s remote clause and `E15-T01` §2/§5

### Q-FUNC-010 — Logout+login on one phone trips E12's enrollment gate and E13's rate limiter
- **Priority:** blocking — blocks `E15-T01`
- **Raised by:** `skills/change-impact` / `IMP-003`, 2026-09-08
- **Question:** After a wipe-logout, the next sign-in mints a **new** device id.
  If the old remote registry row survives (`Q-SEC-009` option (a)),
  `LoginController`'s `readOwnDeviceIds(uid).any((id) => id != deviceId)` is
  true, so the user is routed to `/device-enrollment` — an approval flow that
  needs another trusted device, which a single-phone user does not have.
  Separately, every logout+login is a genuine new registration against
  `DeviceIdentityRepository`'s 5-per-24h per-account limit, so the sixth cycle
  in a day is denied. Is either acceptable, and if not, which one moves?
- **Why it matters:** this is a **reachable dead end for the most ordinary user
  there is** — one person, one phone, who signs out and back in. It is not
  hypothetical: `E12-B01` shipped and had to be fixed for the structurally
  identical symptom (returning users permanently misrouted to
  `/device-enrollment`).
- **Options considered:**
  - **(a) Answer `Q-SEC-009` as (b)/(c)** so the stale row is gone — the
    enrollment gate then correctly sees no other device. Does **not** address
    the rate limit.
  - **(b) Exempt a post-logout re-registration from the rate limiter.** Needs a
    trustworthy local signal that survives the wipe, which by construction there
    isn't — so this is really "raise or window the limit", which weakens
    `FR-ABUSE-001`'s device-registration control.
  - **(c) Accept both.** The enrollment screen already has a documented
    "no recovery possible" notice (`GAP-028`); a single-phone user could be
    shown that and continue. Cheapest, but it means a normal logout lands on a
    recovery screen, which reads as a bug even when it is not.
- **Recommended default (advisory):** **(a)** for the enrollment gate — it falls
  out of `Q-SEC-009`(b) for free and needs no new code — and **accept the rate
  limit as-is** for now: five logout/login cycles per account per day is an
  abnormal pattern, and weakening `FR-ABUSE-001` to serve it is the wrong trade.
  If the human disagrees, that is a genuinely different answer, which is why
  this is asked rather than assumed.
- **Status:** 🟢 answered
- **Answer:** **(a)** for the enrollment gate — falls out of `Q-SEC-009`(b)
  for free, no new code needed. **Accept the rate limit as-is** — weakening
  `FR-ABUSE-001` to serve an abnormal logout-cycling pattern is the wrong
  trade.
- **Answered by:** human, via `AskUserQuestion` ("Fix the enrollment
  dead-end, accept the rate limit")
- **Date:** 2026-09-08
- **fed_into:** `E15-T01` §2 and `E15-T02`'s launch-routing composition

### Q-ARCH-003 — E2E encryption protocol/key-exchange scheme unnamed
- **Priority:** important
- **Status:** 🟢 answered (updated 2026-09-07 — resolved at genesis but never flipped from open in this registry)
- **Raised by:** `skills/project-intake`
- **Question:** BRD §66.2 explicitly defers "exact cryptographic library" to the technical design phase — that's expected. But the *protocol shape* itself (e.g. Signal-style X3DH + Double Ratchet, MLS for groups, or a custom scheme) is an architecture decision that shapes group key-rotation (§51), multi-device sync (§37), and account recovery (§55) simultaneously. Is a specific protocol family already assumed, or fully open for genesis's ADR?
- **Why it matters:** The chosen protocol constrains group-membership-change key rotation design, multi-device key distribution, and what "account recovery" can mean (BRD §55 already states keys are unrecoverable if lost — consistent with most modern E2E schemes, but group-key rotation on member removal (§51) is materially different between a pairwise-ratchet design and an MLS-style tree design).
- **Options considered:**
  | Option | Trade-off |
  |---|---|
  | A — Leave fully open for genesis ADR (no assumption now) | Correct per rule 3 (human decides foundations); this question exists only to guarantee it isn't silently skipped |
  | B — Record a non-binding assumption now (e.g. "Signal-protocol-family for 1:1, MLS-family for groups") to speed up genesis's starting point | Risks the assumption being treated as a decision by a future agent skimming the knowledge map |
- **Recommended default:** A — no assumption recorded; this is flagged purely so genesis's ADR set explicitly includes "cryptographic protocol family" as one of its human-decided items, alongside stack/architecture/auth.
- **Blocks:** genesis ADR set (a new ADR slot, not one of ADR-0001..0005 currently named in `AGENTS.md`'s conventions table)
- **Answer:** Signal Protocol (X3DH + Double Ratchet) for 1:1, Sender-Keys-style group scheme layered for membership-change rotation — Option 1 from the options table.
- **Answered by:** human, 2026-08-26 (per `agent/memory/decisions/ADR-0003-crypto-protocol.md`'s own `decided_by` field)
- **Date:** 2026-08-26
- **Fed into:** `agent/memory/decisions/ADR-0003-crypto-protocol.md` (accepted); `AGENTS.md`'s conventions table; built and shipped across E03 (E2E encryption), E07 (group key rotation on membership change, FR-GROUP-004/005/006), E11 (multi-device key distribution).

---

### Q-ARCH-004 — Routing cost function has no formula or weighting
- **Priority:** important
- **Status:** 🟢 answered (updated 2026-09-07 — resolved during E04 epic breakdown, 2026-08-27, but never flipped from open in this registry)
- **Raised by:** `skills/project-intake`
- **Question:** BRD §31 names nine routing-cost factors (battery, latency, reliability, bandwidth, hop count, congestion, stability, packet loss, traffic type) and states different traffic types prioritize different factors, but gives no formula, weighting, or even a relative ranking beyond "battery is never the sole criterion" (§3.4). §60 (Testing/Simulation) gives one worked numeric example (cost 80 vs 45) without explaining how those numbers were derived. What should the v1 routing-cost heuristic actually compute?
- **Why it matters:** The routing/relay epic cannot be sharded into concrete tasks (task-sharding needs function signatures and behavior, not just factor names) without at least a v1 heuristic — e.g. a weighted sum, a lexicographic priority order, or a small decision tree per traffic type.
- **Options considered:**
  | Option | Trade-off |
  |---|---|
  | A — Simple weighted-sum heuristic per traffic-type profile (weights tunable later) for v1, explicitly marked as a placeholder algorithm pending real-world tuning | Ships something testable quickly; likely wrong weights initially, acceptable since BRD frames routing as adaptive/evolvable |
  | B — Defer the entire routing/relay epic until a human or a follow-up design session supplies the formula | Avoids inventing business logic (rule 1), but stalls a core feature (mesh routing is the product's core differentiator) |
- **Recommended default:** A, with the specific weights/formula written into the routing epic's task file and flagged as a tunable placeholder rather than a final answer — keeps forward progress without pretending precision that doesn't exist yet.
- **Blocks:** epic-breakdown/task-sharding for the routing/relay epic
- **Answer:** Option A, applied — v1 weighted-sum heuristic: `cost = w1*latency_ms + w2*(1-reliability) + w3*battery_drain_rate + w4*hop_count`, with two named weight profiles (`interactive` for 1:1 chat, `bulk` for large transfers), explicitly flagged as tunable placeholders.
- **Answered by:** human (genesis-era decision, applied 2026-08-27)
- **Date:** 2026-08-27
- **Fed into:** `epics/E04-mesh-routing/epic.md` §Open Questions (`OQ-E04-1`, resolved) and its own task-sharding; built and merged across E04's 11 tasks.

---

### Q-FUNC-005 — "Sufficiently better route" migration threshold undefined
- **Priority:** important
- **Status:** 🟢 answered (updated 2026-09-07 — resolved alongside Q-ARCH-004 during E04 epic breakdown, 2026-08-27, but never flipped from open in this registry)
- **Raised by:** `skills/project-intake`
- **Question:** BRD §30 and §53 both gate route migration on the new route being "sufficiently better" than the current one, without defining what threshold (percentage improvement? absolute cost delta? minimum stability duration before triggering?) qualifies. This is closely related to but distinct from Q-ARCH-004 (the cost function itself) — this is specifically the *migration trigger* on top of whatever cost function is chosen.
- **Why it matters:** Without a threshold, the system risks "route flapping" (constant migration between two similarly-costed routes), which directly threatens the "minimize call interruption" goal (§53) and battery-efficiency NFR (§62.4).
- **Options considered:**
  | Option | Trade-off |
  |---|---|
  | A — Fixed percentage improvement threshold (e.g. new cost ≤ 80% of current cost) plus a minimum stability window (e.g. new route must hold for N seconds before migrating) | Simple, tunable, well-understood anti-flapping pattern; needs real-world tuning of N and the percentage |
  | B — Defer to the same routing-epic task file as Q-ARCH-004, decided together | Keeps related unknowns co-located; delays neither more nor less than resolving them separately |
- **Recommended default:** B — fold into the same routing-epic task/ADR as Q-ARCH-004 rather than resolving in isolation, since the threshold is meaningless without the cost function it's a delta of.
- **Blocks:** epic-breakdown/task-sharding for the routing/relay epic
- **Answer:** Option A, applied — migrate only when a candidate route's cost is ≥20% better AND has held that advantage for ≥10 consecutive samples (stability window), both named constants, explicitly flagged tunable.
- **Answered by:** human (genesis-era decision, applied 2026-08-27)
- **Date:** 2026-08-27
- **Fed into:** `epics/E04-mesh-routing/epic.md` §Open Questions (`OQ-E04-2`, resolved) and its own task-sharding; built and merged across E04's 11 tasks.

---

### Q-FUNC-006 — Mechanism for granting a re-added group member historical access
- **Priority:** important
- **Status:** 🟢 answered (updated 2026-09-07 — resolved and built as part of E07, but never flipped from open in this registry)
- **Raised by:** `skills/project-intake`
- **Question:** BRD §51 states a newly (re-)added group member "must not automatically gain access to historical communication unless explicitly permitted by the system" — but no mechanism for that explicit permission is described anywhere in BRD or Design (no UI, no owner/admin action, no setting). Does this permission exist for v1, or is §51's caveat describing a possible *future* capability that v1 should simply omit (i.e., v1 = re-added members never get history, full stop)?
- **Why it matters:** If the capability is real, it needs a UI (Design.md has no screen for it), an owner/admin permission model addition, and a key-distribution mechanism (re-sharing old group keys to a specific member without exposing them to anyone else). If it's not real for v1, the group-encryption epic is simpler and the BRD sentence is just future-proofing language.
- **Options considered:**
  | Option | Trade-off |
  |---|---|
  | A — v1 omits the capability entirely: re-added members never receive historical content, no exception path | Matches everything actually specified elsewhere (no UI, no described flow); simplest and most secure default |
  | B — Build the exception mechanism now | No spec basis to build from — would require inventing UI and a permission model not in either document, violating rule 1 |
- **Recommended default:** A.
- **Blocks:** epic-breakdown/task-sharding for the groups/encryption epic
- **Answer:** Option A, applied — v1 omits the capability entirely: a re-added member never automatically gains historical access, no exception path exists.
- **Answered by:** human (per prior decision, encoded as `OQ-E07-1` in `epics/E07-groups-calls/epic.md`)
- **Date:** 2026-08-27 (per E07's own epic breakdown)
- **Fed into:** `epics/E07-groups-calls/epic.md` (`EARS-GROUP-2`, `OQ-E07-1`); `E07-T05`, which encodes the refusal as a hard, mechanically-checked test (`test_EARS_GROUP_2_no_api_exists_to_grant_historical_access`), merged into `development`.

---

## Optional / to be closed by assumption if unanswered

_(both moved to "Closed by assumption" below during the knowledge-map baseline, 2026-08-26 — optional-priority questions close via their own recommended default rather than blocking forward progress; either can be reopened any time)_

---

## Answered (🟢)

### Q-SCOPE-002 — v1 platform commitment: Android-only or Android+iOS?
- **Priority:** blocking
- **Status:** 🟢 answered
- **Question:** BRD.md's header says "Primary Platform: Android-first". Every subsequent BRD/Design section that discusses platform specifics speaks only of Android — iOS is never mentioned as in-scope or out-of-scope. Is v1 Android-only, or does "Android-first" mean iOS ships in the same wave?
- **Answer (verbatim):** "A" (Android-only for all of v1; iOS is a named future epic, not scoped now)
- **Answered by:** human
- **Date:** 2026-08-26
- **Fed into:** `skills/epic-breakdown` wave planning — no iOS-specific ADRs, permission flows, or background-execution work in scope for Epic 00 / wave 1. iOS remains a future, unscoped epic.

---

### Q-DESIGN-001 — No visual design source for design-fidelity extraction
- **Priority:** blocking
- **Status:** 🟢 answered
- **Question:** `documentation/Design.md` is a 132-section written design specification but contains no visual artifact. `skills/design-fidelity` needs a golden visual source to build a machine-checkable contract from. How should the design track proceed without one?
- **Answer (verbatim):** "I want to use Google stitch." — screens generated in Google Stitch from a prompt derived from Design.md (`docs/UI/stitch-prompt.md`), then exported as real HTML (`code.html` per screen, Tailwind CDN + real computed styles) plus a `DESIGN.md` token export, and dropped into `docs/UI/stitch_nexora_mesh_messenger/`.
- **Answered by:** human (manual export + drop-in for the first 6 screens; MCP-driven generation was attempted first but `mcp__stitch__*` tool calls failed with `Incompatible auth server: does not support dynamic client registration` — reproduced across 3 different auth configs including Google's own documented Claude Code recipe, so this is a genuine Claude Code MCP-client limitation with OAuth-advertising remote servers, not a credentials problem. Fed back via the in-session feedback tool.)
- **Date:** 2026-08-26
- **Fed into:** `design/sources.yaml` (`ui` source, **7 screens**: welcome, dashboard, conversations, chat, devices, settings, login) · `design/golden/{welcome,dashboard,conversations,chat,devices,settings,login}/` (`make design-extract`) · `design/screens/{welcome,dashboard,conversations,chat,devices,settings,login}.md` (`make design-contract`) — this was effectively **Option B** from the original options table, with Stitch substituting for a hand-coded prototype. One exported folder, `nexora_secure_network_dashboard/`, is a byte-identical duplicate of the original `welcome_to_nexora/` and was intentionally left unbound in `sources.yaml`.
  > **Two follow-up gaps the human raised were closed in this same pass:**
  > 1. **No login screen existed.** BRD §5 + Design.md §81 both specify Google-only auth, but the exported Welcome screen had a generic "Get started" CTA with no Google branding, and no screen existed for the in-progress auth state. Resolved by: (a) generating a new **login** screen ("Signing in to NEXORA" — spinner, "Signing in with Google...", encryption reassurance text, no other login paths) and (b) editing the Welcome screen's CTA to a real "Continue with Google" button (Google G logo, official branding), removing all other login paths. Both match `documentation/Design.md` §81's own spec.
  > 2. **How these got made despite the broken MCP client:** built a direct HTTP bridge — `curl` straight to `https://stitch.googleapis.com/mcp`'s stateless JSON-RPC endpoint, using the `STITCH_ACCESS_TOKEN`/`STITCH_PROJECT_ID` credentials from `.env`, bypassing Claude Code's client entirely. This successfully drove `get_project`, `generate_screen_from_text`, and `edit_screens` end to end. Documented for reuse at `agent/mcp/stitch.md`. One quirk hit and worked around: `edit_screens`' response claimed the canvas was updated but `get_screen` kept returning the stale HTML (checked twice, 5s apart) — the response *did* include the exact verified DOM patch (`replace_element`, selector + new content, `verified_html_context` matching our file byte-for-byte), so that patch was applied directly to the local `welcome_to_nexora/code.html` rather than trusting the server round-trip.
  >
  > **Human review pass (2026-08-26) found and closed 3 more issues:**
  > 3. **Nav pill styling drifted across screens** — the active bottom-nav tab used 2 different colors and 2 different heights depending on which Stitch call generated the screen (dashboard/devices correct at `rgb(79,70,229)`/52px; conversations was `rgb(53,37,205)`/60px; settings was `rgb(79,70,229)`/60px). Design.md §104 lists "different component styles for the same purpose" as an anti-pattern. Fixed via the same edit-then-apply-verified-patch approach as the welcome CTA; all 4 nav-bearing screens now match exactly.
  > 4. **Conversations screen invented an unspecified "System:" message sender** with no basis in BRD (§50 only defines Owner/Admin/Member) — replaced with a real member name ("David Chen:").
  > 5. **False-alarm "font bug", traced to a real tool defect and fixed at the source.** 3 screens (welcome, devices, login) showed `ui-sans-serif` as their dominant font in the contract, suggesting broken font-loading. Investigation (isolated Playwright reproduction, exact-pipeline replica, then reading `design/tools/lib/probe.mjs`) found the actual text elements render correctly (Inter/Geist/JetBrains Mono) — the probe was counting font-family for **every visible DOM node**, including decorative SVG shapes (welcome's ~33-element background mesh graphic) that inherit an ambient default but never render text. Fixed `probe.mjs` to only census `fontFamily` where an element owns visible text (matching how `color`/`fontSize`/`fontWeight` were already gated) — a one-line, well-isolated fix confirmed against `make design-selftest` (still passes) before re-extracting all 7 screens. This was a tooling bug affecting the harness generally, not specific to this project's design.
  >
  > **Systematic contrast audit (2026-08-26), triggered by the human noticing text blending into backgrounds:** wrote a WCAG contrast checker (`.contrast_audit.cjs`, scratch — removed after use) computing real contrast ratios from each screen's `probe.json` (text color vs. its nearest enclosing surface). Found **59 violations across 6 of 7 screens** (conversations worst at 27), all one root pattern: this design system pairs text/background per color mode using **different token names** for light vs. dark (not one token resolving to two values) — e.g. a container correctly stays light via `bg-surface dark:bg-surface`, but its text was given `dark:text-primary-fixed-dim` (a color meant for an actually-dark background), so text and background silently assumed opposite modes. Fixed via a mix of targeted Stitch `edit_screens` calls (applied through the same verified-patch method, plus one full-screen regeneration for `devices` — diffed all 52 text strings against the original first, zero copy/content drift, safe to accept) and, where Stitch's own fix introduced a **new** version of the same bug (e.g. conversations' "Personal"/"Groups" headings got set to the *same* token name for both modes, which doesn't achieve a mode swap at all), direct hand-fixes based on precisely understanding the token architecture. **59 → 21 remaining**, all now confirmed (via re-audit + visual check of the golden PNGs) to be small status-color icons/pills (lock, check, warning, "Trusted"/"Allowed"/"Unknown" labels — legible, just under strict AA) or the bottom-nav's inactive-tab de-emphasis (2.94 vs. a 3.0 threshold, a hair short, arguably intentional low-emphasis-vs-active-tab UX) — not the "blending into invisibility" failures that prompted this pass. `welcome`, `dashboard`, `settings`, `login` are now at 0 violations.
  >
  > **Copy pass (2026-08-26) — placeholder text and the welcome-tagline gap both closed:**
  > - Replaced all placeholder/hacker-flavor copy across `dashboard`, `conversations`, `chat`, `devices` with plain names/messages consistent with BRD §16's own examples ("Ahmed", "Rahim") plus "Family"/"Work" for groups (matching BRD §16's Family/Work/Friends). Contacts and their device names are now internally consistent across screens (e.g. "Ahmed" in conversations = "Ahmed" in chat = "Ahmed's Laptop" in devices). Message copy was rewritten to plain conversational text (dropped "sector 7"/"deep scan"/"failover" spy-thriller flavor) while preserving functional meaning where the copy encoded real app behavior (e.g. dashboard's offline-retry status line kept its BRD §33 offline-queue meaning, just reworded plainly). One embedded card ("Deep Scan: Sector 7") was reframed as a plausible file-transfer/backup attachment ("Backup: Family Photos") rather than dropped, since attachments are a real BRD feature.
  > - Added Design.md §81's missing second tagline line to the welcome screen ("Secure communication that keeps working when the network doesn't.") as a new `<p>`, verified against the golden screenshot.
  > - Re-extracted and re-contracted all 7 screens; `make design-selftest` still passes.
  >
  > Deliberately deferred, per the human's explicit decision (not fixed, not blocking):
  > - **Missing offline/error/empty states** — correctly left for `design/gaps.md` once FR ids exist post-genesis (rule 6: a gap needs a spec id to cite; none exist pre-genesis).
  > - **21 low-severity contrast items** (status icons/pills, inactive-nav de-emphasis) — human call was to accept as-is; already confirmed legible via golden screenshots.
  >
  > 🧍 **`design_contract_approval` — ✅ APPROVED by human, 2026-08-26.** All 7 contracts in `design/screens/{welcome,dashboard,conversations,chat,devices,settings,login}.md` accepted as the binding design law for these screens (rule 2). `make design-verify SCREEN=<id>` now gates any build against them. Known, deliberately-accepted deferrals remain: missing offline/error/empty states (→ `design/gaps.md` post-genesis, needs a spec id) and 21 low-severity contrast items (status icons/pills, inactive-nav de-emphasis) — both explicit human calls, not oversights.
  >
  > **Q-DESIGN-001 fully closed.** No further action pending on this question.

---

## Closed by assumption (⚪)

### Q-BIZ-007 — No monetization or business model stated
- **Priority:** optional
- **Status:** ⚪ assumed → **A-001**
- **Question:** Neither BRD.md nor Design.md mentions pricing, subscriptions, ads, or any revenue model. Is NEXORA free/non-commercial for the scope this harness will build, or is monetization simply out of scope for these documents but planned later?
- **Assumption recorded:** A-001 — NEXORA has no monetization/business model in scope for the epics this harness plans
- **Made because:** No input available in BRD/Design; answer does not change v1 architecture (chat/mesh/security work is monetization-agnostic)
- **Risk if wrong:** Low near-term — would only matter if a future task touches payment flows, which is its own `human_gates` entry (`auth_or_payment_code`) and would surface the question again naturally
- **Recorded in:** `spec/knowledge-map.yaml` → `assumptions[]`
- **Revisit trigger:** Any task or epic that touches payment/billing flows

---

### Q-SCOPE-008 — No numeric ceiling for group size or max relay hop count
- **Priority:** optional
- **Status:** ⚪ assumed → **A-002**
- **Question:** Neither document states a maximum group size or a maximum relay hop count. Should v1 assume a conservative default pending real-world tuning, or is this intentionally unbounded?
- **Assumption recorded:** A-002 — v1 group size and relay hop count use conservative placeholder defaults, tunable later, rather than being blocking unknowns
- **Made because:** These are the kind of constants trivially changed later without architectural rework; not worth blocking epic-breakdown over
- **Risk if wrong:** Low — placeholder defaults get documented as tunable, not final, in whichever task files first need concrete numbers
- **Recorded in:** `spec/knowledge-map.yaml` → `assumptions[]`
- **Revisit trigger:** When the groups/encryption or routing/relay epics are sharded and need concrete numbers for real task acceptance criteria

---

## Closed by deferral (⚪)

_none yet_

---

## Invalidated assumptions → impact

| A-nnn | Invalidated on | Reopened as | Impact report |
|---|---|---|---|
