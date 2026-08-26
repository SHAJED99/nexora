# Intake Report — NEXORA

> Produced by `skills/project-intake` at first contact. Copy to
> `docs/intake-report.md`.
>
> **Intake never writes `spec/`.** This report plus routed questions is the
> entire output.

- **Date:** 2026-08-26
- **Prepared by:** claude-code (project-intake)
- **Gate:** 🧍 `intake_mode_confirmation` — ✅ cleared by human on 2026-08-27

---

## 1. Detected mode(s)

| Mode | Present | Signals observed |
|---|---|---|
| A — PRD | yes | `documentation/BRD.md` — prose exec summary, "Business Objectives" (12 goals stated as intent), "Product Vision", roadmap-shaped ("Future Technical Design Phase" section explicitly deferring implementation detail) |
| B — SRS | yes (secondary) | `documentation/BRD.md` — 68 numbered sections, pervasive "shall"/"must" language, a "Major Business Rules" table (§64) and explicit NFR section (§62: Security/Reliability/Performance/Battery/Scalability/Privacy) — SRS-shaped but requirements are not atomic-ized into FR-IDs with individual acceptance criteria |
| C — Design | yes (textual only) | `documentation/Design.md` — 132 numbered sections covering navigation, 87+ named screens/states, component list, color/type/spacing/shape tokens, Flutter file-tree suggestions, a "Design Acceptance Criteria" checklist (§131). **No visual artifacts**: no Figma links, no HTML/CSS export, no screenshots, no image files anywhere in the repo — every screen is described in prose + ASCII wireframe, not rendered |
| D — Existing code | no | No `pubspec.yaml`, no `.gradle`, no `lib/`, no app source of any kind; repo has zero git commits. Only the harness scaffold (`agent/`, `design/tools/`, etc.) and `node_modules` (harness's own npm deps for `design/tools/*.mjs`) exist |
| E — Raw idea | no | Superseded by A/B/C above — the docs are far more developed than a raw idea |

**Primary mode:** A (BRD, business-objectives-and-scope shaped) · **Secondary:** B (SRS-density of individual "shall" statements) + C (design intent, text-only — no visual source)

This is a **greenfield project**: no code exists yet. The command argument
`documentations/` does not exist as a path — the actual input lives at
`documentation/` (singular), containing `BRD.md` and `Design.md`.

---

## 2. Input inventory

| # | Artifact | Format | Size | Apparent intent | Read? |
|---|---|---|---|---|---|
| 1 | `documentation/BRD.md` | md | 2,135 lines / 68 sections | Business Requirements Document — full product definition: objectives, principles, scope, ~60 numbered functional/behavioral rules, NFRs, high-level architecture diagram, business-rules table | ✅ full |
| 2 | `documentation/Design.md` | md | 2,820 lines / 132 sections | Product Design Specification — Material 3 design system, navigation model, per-screen content/states for ~87 named screens, component architecture, Flutter folder-structure suggestions, accessibility/localization/RTL rules | ✅ full |
| 3 | `documentations/` (as given in the command) | — | n/a | **Does not exist.** Likely a typo for `documentation/` | n/a |

**Not provided but expected for this mode:**
- Any visual design source (Figma file, exported HTML/CSS, screenshots, component library) — required by `skills/design-fidelity` to extract a golden screen contract. Design.md is a *written spec*, not a *design source*.
- Any existing code, manifests, or CI config (expected only if mode D were present — it is not, confirmed greenfield).
- Personas / user research artifacts (BRD states the problem — no-connectivity communication — but never names who the target user is beyond "users").
- Any business-model / monetization statement.

---

## 3. Known facts by category

Only what the input **states**. Facts marked `inferred` are candidate
assumptions, not facts.

| Category | Facts (with source) |
|---|---|
| Vision | "A secure, offline-first communication platform where devices can communicate directly or through other available network paths, automatically select and migrate between connections, and continue communicating even when traditional Internet connectivity is unavailable." — BRD §67 |
| Users / personas | Not named explicitly. BRD §1 implies users who lack reliable Internet connectivity. No persona, demographic, or use-case (e.g. disaster response, off-grid, developing-region) is stated — `inferred` only |
| Requirements (functional) | Google Authentication (BRD §5) · per-device cryptographic identity (§6) · persistent trusted relationships (§7) · connection request/accept flow with Trusted/Allowed/Unknown/Blocked states (§8–10) · blocking incl. group-level invisibility (§12–14) · personal + group communication: text, voice msg, PTT, calls, attachments, location (§15) · local conversation/voice storage (§16–18) · configurable storage modes incl. default "Smart Mode" (§19–22) · multi-transport discovery (§23) · multi-hop relay + store-and-forward (§25–28) · dynamic cost-based routing with make-before-break migration (§29–32) · offline message queue with delivery states (§33–34) · dedup + ordering (§35–36) · multi-device sync (§37–39) · event-sourced security-state changes (§40) · E2E encryption excluding relays/Firebase from plaintext access (§41, §27) · threat protections listed by name (§42) · location sharing w/ per-user + global toggles and eligibility rule (§43–46) · notifications (§47) · Android background operation constraints (§48–49) · groups w/ Owner/Admin/Member roles + key rotation on membership change (§50–51) · voice calls with route migration (§52–53) · Firebase data-boundary list — what it may/must-not store (§54) · account recovery via existing trusted device, explicit "no recovery if all keys lost" (§55) · abuse-prevention control list (§56) · privacy-safe diagnostics (§57) · protocol/crypto/db version negotiation (§58) · migration-safe app updates (§59) · a testing/simulation framework requirement (§60) · full mandatory app-version-enforcement subsystem (§61, 12 sub-sections) |
| Requirements (non-functional) | BRD §62: Security (strong E2E, "must"), Reliability (auto-recovery, "should"), Performance (responsive during sync/transfer/migration/DB ops, "should"), Battery (minimize scanning/GPS/CPU/traffic, but "must not override reliability"), Scalability (multi-device/group/relay/history/future-features), Privacy (data stays local where practical, central services store minimum) — all stated qualitatively, no numeric targets |
| Features | Full feature list at BRD §4 (Product Scope) and §66.1 (BRD Scope, in-scope) — chat, groups, PTT, voice/group calls, attachments, live location, offline/multi-hop/relay/store-and-forward, dynamic routing+migration, local storage+management, multi-device sync, Firebase integration, background ops, security mgmt, version mgmt |
| User journeys | High-level flow diagram BRD §63: Google Login → Account Created → Device Setup → Discover Devices → Connection Request → (Trusted→Auto-Accept | Unknown→Authentication) → Connection → Secure Channel → {Chat,PTT,Call} → Dynamic Routing → {Bluetooth,Wi-Fi,Internet} → Relay → Destination. First-run journey also detailed in Design.md §80–87 (First Launch → Welcome → Permission Flow → Device Setup → Pairing → Trust Establishment → First Dashboard) |
| Business rules | BRD §64 "Major Business Rules" table — 40 rules, e.g. "Battery: Never sole routing criterion", "Migration: Establish new route before terminating old", "Relay Decryption: Not permitted", conflict-resolution precedence `BLOCK > TRUST`, `LOCATION OFF > LOCATION ON`, `REVOKED > ACTIVE`, `REMOVED > MEMBER` (§39) |
| UI / UX | Design.md is exhaustive at the *intent* level: Material 3 exclusively (§2.1), light/dark/system theme via `ColorScheme.fromSeed` (§4–5), type/icon/spacing/shape/elevation tokens (§6–10), adaptive nav for compact/medium/expanded (§11–13), ~87 named screens with described content/states (dashboard, network status incl. Connected/Connecting/Offline/Limited/Secure, chat, voice/PTT/call UI, device & trust & relationship screens, location screens, full settings tree, update/maintenance screens, empty/error/offline states, dialogs, context menus, group management, first-run flow), accessibility (touch targets, semantics labels, RTL, text expansion), motion/loading/dialog/snackbar/banner usage rules, explicit anti-pattern list (§104), and a self-referential "Design Acceptance Criteria" checklist (§131) — all as **text**, no pixels |
| Data | Firebase-may-store vs Firebase-must-not-store boundary (BRD §54) · version categories tracked: App Version, Build, Protocol, Crypto, Database schema (§61.10) · relay packet metadata fields (§28) · message delivery-state enum (§34) |
| APIs | None specified — no endpoint, schema, or wire-format definitions anywhere (explicitly deferred, BRD §66.2 and §68) |
| Integrations | Google Authentication (BRD §5) · Firebase (Auth, Firestore-shaped metadata, remote config-shaped version policy §61.3) · Google Play in-app update mechanism (§61.6) |
| Architecture | High-level layered diagram BRD §65: Google Auth → Firebase → Identity & Authorization → Communication App (Chat/PTT/Calls/Groups/Attachments/Location) → E2E Encryption → Sync Engine → Route Engine → Relay Engine → {Bluetooth, Wi-Fi, Internet} → Peer Devices. Flutter+Android-native split implied (Design.md §92, §94–96 suggest `lib/core/design`, `features/<domain>/{presentation,domain,data}`) but explicitly marked as *suggestion*, not contract |
| Constraints | Android-first (primary platform, BRD header) · Flutter framework (BRD header) · offline-first as a hard constraint, not a feature (§3.1) · "Battery consumption alone must never determine the best route" (§3.4, §31) · BRD explicitly excludes exact package/library/protocol choices (§66.2) — deferred to "the technical design and system requirements documents" (i.e., genesis) |

Facts destined for `spec/knowledge-map.yaml` `facts[]`: F-001 … F-0nn (to be minted by `skills/knowledge-map` after this report is confirmed — not mismated here per the intake/spec boundary).

---

## 4. Unknowns, ambiguities, contradictions

**Every entry here is routed to `skills/question-resolution` — none is answered
here.** Full question bodies are in `spec/questions.md`.

| # | Type | Description | Routed as |
|---|---|---|---|
| 1 | unknown / process gap | No visual design source exists for `skills/design-fidelity` to extract a golden screen contract from — Design.md is prose-only | Q-DESIGN-001 |
| 2 | ambiguity | "Android-first" (BRD header) never resolved to a v1 platform commitment — is iOS in scope for any wave, or Android-only until stated otherwise? | Q-SCOPE-002 |
| 3 | unknown | No cryptographic protocol/key-exchange scheme is named (E2E scheme, ratchet, X3DH-equivalent) — BRD explicitly defers "exact cryptographic library" (§66.2) but the *protocol shape* is an architecture decision, not a library choice | Q-ARCH-003 |
| 4 | unknown | Routing cost function is named ("battery, latency, reliability, bandwidth, hop count, stability, congestion, packet loss, traffic type" — BRD §31) but no weighting/formula is given, even for a v1 heuristic | Q-ARCH-004 |
| 5 | ambiguity | "Sufficiently better route" (BRD §30, §53) has no defined threshold — when does a migration actually trigger? | Q-FUNC-005 |
| 6 | unknown | BRD §51: a re-added group member "must not automatically gain access to historical communication unless explicitly permitted by the system" — no mechanism for that explicit permission is described anywhere | Q-FUNC-006 |
| 7 | unknown | No monetization/business model is stated anywhere in BRD or Design | Q-BIZ-007 |
| 8 | unknown | No numeric ceiling for group size or max relay hop count is stated | Q-SCOPE-008 |

### Contradictions in detail
No direct contradictions were found between BRD.md and Design.md — Design.md
consistently assumes the BRD's Android-first/Flutter/Firebase/Material 3
framing and does not introduce features BRD omits or vice versa. The
ambiguities above are gaps (things neither document states), not conflicts
between the two documents.

---

## 5. Per-mode readiness

| Mode present | Ready? | What's missing |
|---|---|---|
| A — PRD / business intent | ✅ ready | Vision, objectives, scope, and business rules are coherent and enumerable. Personas are only inferred (Q-BIZ area) but do not block genesis. |
| B — SRS-density requirements | ⚠️ partial | Behavioral rules are thorough but not yet atomic-ized into FR/NFR ids with individual acceptance criteria — that ids-and-criteria step is genesis's/task-sharding's job, not a gap in the source material itself. Several algorithmic gaps (routing cost formula, migration threshold) are logged as questions. |
| C — Design intent | ⚠️ partial | Screen inventory and states are exhaustive at the descriptive level, but there is **no extractable visual source** — `make design-extract` / `design-fidelity` has nothing to point a golden capture at until Q-DESIGN-001 is resolved. |
| D — Existing code | n/a | Not present. |
| E — Raw idea | n/a | Superseded. |

---

## 6. Question summary

| Priority | Count | Effect |
|---|---|---|
| blocking | 2 | genesis's design-contract step (Q-DESIGN-001) and epic-breakdown platform scoping (Q-SCOPE-002) cannot proceed cleanly without an answer |
| important | 4 | Q-ARCH-003, Q-ARCH-004, Q-FUNC-005, Q-FUNC-006 — affect specific epics' shardability, not genesis start |
| optional | 2 | Q-BIZ-007, Q-SCOPE-008 — recorded as assumptions if unanswered |

Log: `spec/questions.md`

---

## 7. Recommended path

- **Next skill:** `skills/question-resolution` (mode D is not present, so `codebase-analysis` is skipped)
- **Reason:** This is a greenfield project with rich but text-only source material (BRD + Design). The two 🟡 blocking questions should be resolved before `skills/genesis` begins, since one shapes the design workflow itself (Q-DESIGN-001) and the other shapes wave/epic platform scoping (Q-SCOPE-002).
- **Then:** `skills/question-resolution` → `skills/knowledge-map` (baseline `spec/knowledge-map.yaml`) → `skills/genesis` (Epic 00 — human-decided ADRs for stack specifics, crypto protocol, transport implementation, DB schema, all of which BRD explicitly defers to this phase)

### Risks visible already
| Risk | Severity | Note |
|---|---|---|
| Design.md has no visual source | high | Every downstream UI task depends on `make design-verify` passing against a golden contract; without a source, either the workflow must be adapted (text-spec-as-contract) or a design pass (Figma/coded prototype) must happen first — this is a process decision, not a detail |
| Mesh-networking + E2E crypto + multi-transport routing is a large, security-critical technical surface for a first release | medium | BRD itself acknowledges this by deferring 30 technical-design topics (§68) — expect Epic 00 to be unusually large; consider whether a phased/wave rollout (e.g. direct-connection chat before multi-hop relay) is preferable to building the full mesh in wave 1 |
| No numeric NFR targets anywhere (battery %, latency ms, storage MB defaults) | medium | Every NFR in §62 is qualitative ("should minimize", "should remain responsive") — acceptance criteria at task-sharding time will need human-supplied numbers or they'll be invented, violating rule 1 |

---

## 8. Human confirmation (🧍 `intake_mode_confirmation`)

**Gate:** 🧍 `intake_mode_confirmation` — ✅ cleared by human on 2026-08-27

- [x] Detected mode(s) are correct
- [x] The input inventory is complete — nothing was withheld or forgotten
- [x] The facts are actually facts
- [x] The recommended path is approved

**Corrections from the human:** none.
