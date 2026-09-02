// core/storage — Smart Mode's output value types (E08-T04).
//
// `SmartModePolicy.plan()` (smart_mode_policy.dart) is a pure function that
// turns a `StorageInventorySnapshot` (E08-T02) plus access stats (E08-T03)
// into a `RetentionPlan` — what Smart Mode *would* remove, and why. This
// file defines the shape of that answer, and nothing else: no I/O, no
// persistence of its own. `RetentionPlan` is defined once here and reused
// by later tasks (T05, T06, T08, T09) rather than re-declared (task §epic
// Analyze report, "Contract sanity").
//
// The plan is a forecast, not an act (task §2): BRD §20/§22's own worked
// example says "Will remove". Nothing in this file, or in
// `smart_mode_policy.dart`, deletes a row or writes a table.
library;

import 'storage_item.dart' show StorageItemKind;

/// The eight factors `FR-STORE-005` names, in the order the epic tables them
/// (task §2). Every one of them appears in `RetentionPlan.availableFactors`,
/// scored or `Unavailable` — never silently omitted (`EARS-STORE-1`).
enum SmartModeFactor {
  age,
  size,
  fileType,
  accessFrequency,
  conversationActivity,
  storagePressure,
  temporaryStatus,
  importance,
}

/// A factor's outcome for one plan run — a sum type (task §2), never a bare
/// number: `Scored(v)` when the factor has a real input this build can
/// measure, `Unavailable(reason)` when it does not. A factor scored `0.0`
/// reads to every downstream surface as "we measured it and it was zero" —
/// exactly the fabricated-measurement defect (E04-B03) this type exists to
/// make structurally impossible. Never compare `FactorScore`s for a
/// composite total (task §6 risk note) — read the per-factor value, and use
/// `RetentionCandidateGroup.reason` for *why* a group was chosen.
sealed class FactorScore {
  const FactorScore();

  const factory FactorScore.scored(double value) = Scored;
  const factory FactorScore.unavailable(String reason) = Unavailable;
}

/// The factor was computed from a real input in this build.
final class Scored extends FactorScore {
  const Scored(this.value);

  /// The factor's own measure — meaning is documented per factor at each
  /// call site in `smart_mode_policy.dart` (e.g. "count of items past the
  /// age threshold", "used/budget ratio"). Never a 0..1 composite score
  /// across factors (task §6).
  final double value;

  @override
  bool operator ==(Object other) => other is Scored && other.value == value;

  @override
  int get hashCode => Object.hash(Scored, value);

  @override
  String toString() => 'Scored($value)';
}

/// The factor has no real input in this build — reported honestly rather
/// than defaulted (`EARS-STORE-10`). [reason] names why, and — for the two
/// factors this build cannot measure at all — the Open Question that has to
/// be answered before it can be (`OQ-E08-1` for storage pressure,
/// `OQ-E08-4` for importance).
final class Unavailable extends FactorScore {
  const Unavailable(this.reason);

  final String reason;

  @override
  bool operator ==(Object other) =>
      other is Unavailable && other.reason == reason;

  @override
  int get hashCode => Object.hash(Unavailable, reason);

  @override
  String toString() => 'Unavailable($reason)';
}

/// The machine-readable "why" behind a candidate group (`FR-STORE-007`).
/// These are stable keys, never display copy — the user-facing strings
/// ("Older than 45 days", "No longer required") are design copy owned by
/// `E08-T07`'s contract and rendered by `E08-T08`/`E08-T09` (task §4).
enum RetentionReason {
  olderThan,
  rarelyAccessed,
  noLongerRequired,
  overSizeLimit,
  storagePressure,
}

/// What became of a candidate group, over the life of one decision-log row
/// (`storage_decisions.outcome` — E08-T01's schema). `SmartModePolicy.plan`
/// only ever produces `planned` groups (task §2/§4: this file computes and
/// explains, it does not act); `applied`/`skipped` are stamped later by
/// `E08-T06`'s executor.
enum DecisionOutcome { planned, applied, skipped }

/// One group of stored items Smart Mode would remove together, sharing one
/// [kind], one [reason], and one machine-readable [categoryKey] (e.g.
/// `messages`, `relayCache` — task §4, `storage_tables.dart`'s own doc:
/// "a stable machine key ... not display copy").
///
/// A candidate group with no items is not constructed — every group here is
/// backed by real [itemIds] and a real, measured [bytes] total
/// (`EARS-STORE-9`).
final class RetentionCandidateGroup {
  const RetentionCandidateGroup({
    required this.categoryKey,
    required this.kind,
    required this.itemIds,
    required this.itemCount,
    required this.bytes,
    required this.reason,
    this.reasonDetail,
  });

  /// A stable machine key naming the category shown to the user (not
  /// display copy — task §4). Owned by this file, consumed by the design
  /// contract (`E08-T07`) and rendered verbatim by the UI tasks.
  final String categoryKey;

  final StorageItemKind kind;

  /// Real item ids from `StorageItem.id`, sorted ascending for deterministic
  /// output (task §2 determinism requirement) — never a count-only
  /// placeholder.
  final List<String> itemIds;

  final int itemCount;

  /// Real measured bytes, summed from the group's own items — never
  /// estimated (task §2/`EARS-STORE-9`).
  final int bytes;

  /// The single, named dominant reason this group was selected — never a
  /// composite score (task §6 risk note).
  final RetentionReason reason;

  /// The reason's own parameter as text (e.g. `'45'` for "older than 45
  /// days"), or null when the reason carries no parameter (e.g.
  /// `noLongerRequired`). Never display copy (task §4).
  final String? reasonDetail;
}

/// What Smart Mode would remove, and why — the whole answer
/// `FR-STORE-007`'s explanation surface reads (task §1). Produced once per
/// `SmartModePolicy.plan()` call; never mutated afterwards.
final class RetentionPlan {
  const RetentionPlan({
    required this.mode,
    required this.groups,
    required this.totalBytes,
    required this.availableFactors,
    required this.unavailableFactors,
    required this.computedAt,
  });

  /// The `storage_policy_settings.mode` value this plan was computed under
  /// — always `'smart'` for a plan `SmartModePolicy` produces (task §4:
  /// this file knows only Smart Mode; the full `smart | olderThanDays |
  /// overSizeMb` taxonomy is `E08-T05`'s to define against its own manual
  /// policies). A plain machine-key string, not an invented enum spanning
  /// modes this task does not build.
  final String mode;

  /// Every group Smart Mode would remove, sorted deterministically by
  /// `(categoryKey, reason.name)` (task §2 determinism requirement) —
  /// never in item/scan order, which is caller-dependent.
  final List<RetentionCandidateGroup> groups;

  /// Real measured bytes across every group — the sum of each group's own
  /// [RetentionCandidateGroup.bytes], never re-estimated
  /// (`EARS-STORE-9`).
  final int totalBytes;

  /// Every one of the eight named factors (`SmartModeFactor`), scored or
  /// unavailable — exactly eight entries, always (`EARS-STORE-1`). The
  /// canonical availability map the explanation surface reads.
  final Map<SmartModeFactor, FactorScore> availableFactors;

  /// Convenience subset of [availableFactors]: just the factors that came
  /// back [Unavailable], keyed the same way — so a caller who only needs
  /// "what couldn't we measure" (`EARS-STORE-10`) does not have to filter
  /// [availableFactors] itself.
  final Map<SmartModeFactor, FactorScore> unavailableFactors;

  /// `DateTime.fromMillisecondsSinceEpoch(nowEpochMs)` — derived from the
  /// injected clock passed to `SmartModePolicy.plan`, never `DateTime.now()`
  /// (task §5/§6).
  final DateTime computedAt;
}

/// The tunable constants Smart Mode scores against (task §2, `OQ-E08-2`).
/// Every value here is a documented placeholder pending a human-supplied
/// number via `A-004`'s revisit trigger — never presented as a spec number,
/// and never repeated as a bare literal at a use site (task §6 risk note,
/// self-review checklist).
final class SmartModeThresholds {
  const SmartModeThresholds({
    required this.ageThresholdDays,
    required this.rarelyAccessedDays,
    required this.rarelyAccessedMinAgeDays,
    required this.sizeThresholdBytes,
    required this.storagePressureRatio,
    required this.activeConversationWindowDays,
  });

  /// `SmartModeThresholds.defaults()` — the documented placeholder set
  /// this task ships (`OQ-E08-T04-1`, answered via the epic's `OQ-E08-2`:
  /// option (i), a new tunable assumption `A-004` extending `A-002`'s
  /// placeholder shape to storage). Every value below is a placeholder, not
  /// a spec number — a future one-file change against `A-004`'s revisit
  /// trigger, not a rewrite.
  factory SmartModeThresholds.defaults() => const SmartModeThresholds(
        // Placeholder (A-004): BRD §20/§22's own worked example uses "Older
        // than 45 days" for the one class-example present in this build
        // (voice messages) — reused here for the `message` class since it
        // is the closest real analogue this build has. Not a spec number.
        ageThresholdDays: 45,
        // Placeholder (A-004): BRD names "Rarely accessed" as a category but
        // gives no number. 30 days with no recorded access is a
        // conservative starting point, not a measured one.
        rarelyAccessedDays: 30,
        // Placeholder (A-004): a brand-new, not-yet-accessed item should not
        // be flagged the instant it's created just because it has no access
        // row yet — this is the grace period before "never accessed" starts
        // counting as a candidate signal.
        rarelyAccessedMinAgeDays: 7,
        // Placeholder (A-004): no BRD number for a single-item size trigger;
        // 10 MB is a conservative "this one item is unusually large" bar.
        sizeThresholdBytes: 10 * 1024 * 1024,
        // Placeholder (A-004): fraction of `budgetBytes` at which storage
        // pressure is considered "high" — matches BRD §22's own worked
        // explanation, which folds pressure and low usage into one
        // "why" together. Only meaningful once a caller supplies
        // `budgetBytes` (`OQ-E08-1`); this constant does nothing until then.
        storagePressureRatio: 0.9,
        // Placeholder (A-004): a conversation with a message this recent is
        // "active" and shields its items from every other factor
        // (`EARS-STORE-1`'s conversation-activity factor) — BRD gives no
        // number for this either.
        activeConversationWindowDays: 14,
      );

  /// Days since `createdAt` past which an item qualifies for
  /// [RetentionReason.olderThan].
  final int ageThresholdDays;

  /// Days since `last_accessed_at` (or since creation, if never accessed)
  /// past which an item qualifies for [RetentionReason.rarelyAccessed].
  final int rarelyAccessedDays;

  /// Minimum age, in days, before "never accessed" starts counting as a
  /// [RetentionReason.rarelyAccessed] signal — protects brand-new items.
  final int rarelyAccessedMinAgeDays;

  /// Per-item byte size past which an item qualifies for
  /// [RetentionReason.overSizeLimit].
  final int sizeThresholdBytes;

  /// `usedBytes / budgetBytes` ratio at or above which storage pressure is
  /// "high" enough to become the dominant reason for otherwise-qualifying
  /// candidates (`OQ-E08-1`'s denominator; inert while `budgetBytes` is
  /// null).
  final double storagePressureRatio;

  /// Days since a conversation's most recent message past which that
  /// conversation is no longer considered "active" — an active
  /// conversation's items are never candidates, regardless of any other
  /// factor.
  final int activeConversationWindowDays;
}
