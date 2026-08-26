# Domain Risks & Constraints — NEXORA

> What's regulated, irreversible, money, or PII; and the hard limits
> (scale/latency/integrations/team/deadline) genesis's ADRs must respect.

**Date:** 2026-08-26

## Irreversible actions in the domain

These deserve extra scrutiny at task-sharding and review time — a bug here
isn't a rollback, it's data loss or a trust breach:

- **Key loss = permanent data loss.** By design (FR-RECOVER-002). Any UX
  around key backup/export needs to make this consequence unmistakable
  *before* the irreversible event, not after.
- **Group key rotation on membership removal.** Once rotated, a removed
  member's access is gone — correct behavior, but a routing bug that rotates
  keys incorrectly (e.g. on the wrong trigger) could lock out active members.
- **Group deletion (Owner action).** Full destructive action; BRD §50 gives
  the Owner this power without describing a confirmation flow — the design
  layer should add one (Design.md §116 does list "Delete group"/"Reset
  security" among actions requiring confirmation).
- **Mandatory version-enforcement lockout.** An incorrectly-pushed
  `minimumSupportedBuild` could lock out the entire user base simultaneously
  (FR-VER-010's emergency-enforcement mechanism, if misused). This is an
  operational-safety risk, not just a code-correctness one.

## Regulated / sensitive data

- **PII**: user account identity (Google), device identity, location data,
  message content. BRD is explicit that most of this must **not** transit or
  rest in Firebase in plaintext (FR-FB-002) — this is close to a regulatory
  posture (data minimization) even though BRD never names a specific
  regulation (GDPR/CCPA are never mentioned — worth a human decision at
  genesis on whether to design toward one explicitly, or treat BRD's own
  privacy principles as sufficient).
- **No monetization = no payment data in scope** (per A-001) — this
  meaningfully reduces the regulated-data surface for now, but revisit if
  that assumption is invalidated.

## Money

None currently in scope (A-001). No payment flows, no billing, no in-app
purchase. If this changes, `auth_or_payment_code` and `secrets_or_env_change`
human_gates apply per `harness.yaml`.

## Team / delivery constraints

Not stated anywhere in BRD or Design — no team size, no deadline, no budget
ceiling appears in either document. This is a real gap for planning
(`skills/epic-breakdown`'s wave sizing needs *some* sense of throughput) but
isn't blocking genesis; it becomes relevant once epics need sequencing.

## Scale / latency / integration constraints

- **Scale**: no numeric ceiling anywhere (group size, hop count, message
  volume, concurrent devices) — NFR-SCALE-001 is qualitative only; A-002
  covers the placeholder-default approach for group size/hop count
  specifically.
- **Latency**: no numeric target (NFR-PERF-001 is "should remain
  responsive," unquantified).
- **Integrations**: exactly three named — Google Authentication, Firebase,
  Google Play in-app update. No others appear anywhere in BRD or Design.
- **Platform**: Android-only for v1 (confirmed, Q-SCOPE-002); Flutter +
  Android-native split for system-sensitive functionality (FR-PLAT-003).

## Technical risk concentration

The single largest risk concentration in this domain is the intersection of
**mesh routing + E2E encryption + multi-transport handling** — three
independently hard problems that must all work together correctly for the
product's core value proposition to hold. BRD's own §68 (30 deferred
technical-design topics) is itself evidence the business recognizes this.
Recommendation carried into `skills/epic-breakdown`: consider whether Epic 00
+ wave 1 should target *direct-connection* chat first (skip multi-hop relay
initially) to get a working, reviewable product faster, with mesh relay as
an explicit wave 2 — a phasing decision for the human at the epic-map gate,
not something to decide here.
