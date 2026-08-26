---
status: accepted
date: 2026-08-26
proposed_by: claude-code (genesis T01)
decided_by: human, 2026-08-26
traces_to: [FR-DIAG-001, FR-DIAG-002, NFR-REL-001]
---

# ADR-0006 — Third-party observability services

## Context
BRD names exactly three integrations (Google Auth, Firebase, Google Play
in-app update) and is silent on crash reporting, analytics, or error
monitoring. FR-DIAG-001/002 are explicit and strict: diagnostics must be
useful without exposing sensitive content, and must **never** log message
plaintext, keys, voice content, or sensitive personal/location data. Any
third-party observability tool has to be evaluated against that bar
specifically, not just "is it popular."

## Options considered
1. **Firebase Crashlytics + Firebase Analytics** — pros: already in the
   stack (no new vendor relationship), tight Flutter integration, free tier
   generous enough for early stage. cons: it's the *same* vendor BRD
   explicitly restricts from seeing sensitive content (FR-FB-002) — using
   it for diagnostics means auditing every event/log call against that
   boundary within a vendor whose main product is data collection, which is
   a harder trust posture to maintain than an unrelated vendor would be.
2. **A dedicated, privacy-conscious crash/error tool (e.g. Sentry,
   self-hosted or EU-region) for crash/error reporting; no analytics/usage
   tracking at all for v1** — pros: crash/error reporting is genuinely
   useful for reliability (NFR-REL-001) without needing usage/behavior
   analytics, which BRD never asks for at all; keeping it separate from
   Firebase reduces the single-vendor blast radius for the "never expose
   sensitive content" requirement. cons: new vendor relationship, another
   privacy policy to review, more integration work than "already there."
3. **No third-party observability at all for v1 — local-only diagnostics
   (FR-DIAG-001) surfaced to the user, nothing leaves the device** —
   pros: maximally aligned with the offline-first/privacy-first
   constitution, zero new vendor risk. cons: the team gets no visibility
   into crashes/errors happening in the field, which makes it much harder
   to know if reliability (NFR-REL-001) is actually being met at scale.

## Comparison matrix
| Criterion | Firebase Crashlytics | Dedicated tool (Sentry-style) | None |
|---|---|---|---|
| New vendor relationship | None (already using Firebase) | Yes | None |
| Separation from the vendor FR-FB-002 restricts | Weak — same vendor | Strong | N/A |
| Field visibility into crashes/reliability | Good | Good | None |
| Setup effort | Low | Moderate | None |

## Agent recommendation (advisory — NOT the decision)
**A dedicated, separate crash/error tool — no analytics/usage tracking for
v1.** Crash/error visibility is genuinely useful for verifying NFR-REL-001
in the field, but doing it through Firebase specifically muddies the exact
boundary FR-FB-002 draws ("Firebase must not store sensitive content") by
putting diagnostics through the one vendor that boundary is about. A
separate, narrowly-scoped tool keeps that boundary clean and legible. Usage
analytics isn't something BRD asks for anywhere, so it's not included by
default. Final call is yours — and "none for v1" is a completely reasonable
answer too if the team prefers zero new vendor surface at this stage.

## Decision
✅ Accepted — chosen option: **A dedicated, privacy-conscious crash/error
tool (e.g. Sentry) for crash/error reporting; no analytics/usage tracking
for v1.**

## Consequences
- Crash/error reporting is integrated as a separate vendor from Firebase,
  keeping FR-FB-002's "Firebase must not store sensitive content" boundary
  legible and not muddied by routing diagnostics through the same vendor.
- Every event/log call must still be audited against FR-DIAG-001/002 —
  never plaintext, keys, voice content, or sensitive personal/location data,
  regardless of vendor.
- No usage/behavior analytics ships in v1 — BRD never requires it.
- Specific vendor selection (Sentry vs. an equivalent) and self-hosted vs.
  managed hosting are implementation details within this ADR, not new
  foundational decisions — `docs/conventions.md` (T02) can record the pick.
