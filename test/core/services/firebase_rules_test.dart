// E11-T02/E11-T04/E11-T05/E11-T06/E11-B06 — structural tests for
// `database.rules.json` (EARS-FB-4, FB-5, FB-6, FB-13, FB-16, FB-18, FB-19,
// FB-20).
//
// These tests prove the rules FILE SAYS the right thing: they parse
// `database.rules.json` and cross-check it against `docs/firebase-schema.md`
// (the single source of truth for what fields each `live` node may carry —
// task §6 Risks: "a test that duplicates the thing it is checking passes
// even when both are wrong together"). They do not prove the Realtime
// Database SERVER enforces it — that needs the Firebase emulator
// (`OQ-E11-T02-1`), still not brought in as of `E11-T06` (a new dev
// dependency, 🧍 rule 3, outside this task's own `files:` fence — see
// `docs/firebase-schema.md`'s "What this schema does not cover"). For the
// one property that matters most in `E11-T06` — that a read at `directory`
// (no child) is denied while `directory/$deviceId` grants one — the
// `_cascadingReadGranted` helper below goes one step further than every
// other group in this file: it actually SIMULATES the RTDB read-cascade
// algorithm (walk root → target, OR-ing each level's `.read`) rather than
// checking the JSON for an absent key, per `E11-T06` task §3's explicit
// requirement. It is still not a server-backed proof.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One row parsed out of `docs/firebase-schema.md`'s `## Tree` table, for
/// rows with `Status == live` only.
class _SchemaRow {
  _SchemaRow(this.path, this.fields);

  /// e.g. `users/$uid/devices/$deviceId` — segments may be literal keys or
  /// `$`-prefixed wildcards. The wildcard's exact name need not match the
  /// rules file's own wildcard name for that position (RTDB wildcard names
  /// are local to the rules file); only "is this segment a wildcard" is
  /// compared.
  final List<String> path;

  /// Field names only (the `:Type` / `(ServerValue)` annotation is stripped)
  /// — the FR-FB-001 allow-list this node's `.validate` must match exactly.
  final Set<String> fields;
}

List<_SchemaRow> _parseLiveSchemaRows(String markdown) {
  final rows = <_SchemaRow>[];
  for (final line in const LineSplitter().convert(markdown)) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|')) continue;
    final cells = trimmed
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    // Header / separator rows and short rows are not data rows.
    if (cells.length < 3) continue;
    if (cells[0] == 'Path' || cells[0].startsWith('---')) continue;
    if (cells[1] != 'live') continue;

    final rawPath = cells[0].replaceAll('`', '');
    final segments = rawPath.split('/').where((s) => s.isNotEmpty).toList();

    final fieldsCell = cells[2].replaceAll('`', '');
    final fields = fieldsCell
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .map((f) => f.split(':').first.trim())
        .toSet();

    rows.add(_SchemaRow(segments, fields));
  }
  return rows;
}

/// Walks [rules] (the decoded `{"rules": {...}}` JSON tree) following
/// [pathSegments], where a `$`-prefixed schema segment matches whichever
/// single child key of the current node is itself `$`-prefixed (an RTDB
/// wildcard), regardless of that wildcard's own name.
Map<String, dynamic> _navigate(
  Map<String, dynamic> rules,
  List<String> pathSegments,
) {
  var node = rules['rules'] as Map<String, dynamic>;
  for (final segment in pathSegments) {
    if (segment.startsWith(r'$')) {
      final wildcardKey = node.keys.firstWhere(
        (k) => k.startsWith(r'$'),
        orElse: () => throw StateError(
          'no wildcard child found under a node while matching path '
          'segment "$segment" (looked in keys: ${node.keys.toList()})',
        ),
      );
      node = node[wildcardKey] as Map<String, dynamic>;
    } else {
      expect(
        node.containsKey(segment),
        isTrue,
        reason: 'rules file has no "$segment" child at this point in the '
            'documented path ${pathSegments.join('/')}',
      );
      node = node[segment] as Map<String, dynamic>;
    }
  }
  return node;
}

/// Every key of [node] that is itself a nested rules node (i.e. a field
/// definition), excluding rule directives (`.validate`, `.read`, `.write`)
/// and the `$other` deny-catch-all.
Set<String> _declaredFieldKeys(Map<String, dynamic> node) => node.keys
    .where((k) => !k.startsWith('.') && k != r'$other')
    .toSet();

/// The literal (non-wildcard) child segment names of [parentPath] that are
/// themselves documented as their own `live` schema row (e.g. `revocation`
/// under `users/$uid/devices/$deviceId`, `E11-T04`) -- a whole separate
/// documented sub-node, not one of [parentPath]'s own scalar fields. The
/// generic per-node field-set check below must not mistake a child node's
/// name for a missing/undocumented field of its parent.
Set<String> _nestedLiveNodeNames(
  List<_SchemaRow> allRows,
  List<String> parentPath,
) {
  final names = <String>{};
  for (final row in allRows) {
    if (row.path.length != parentPath.length + 1) continue;
    var isChildOfParent = true;
    for (var i = 0; i < parentPath.length; i++) {
      if (row.path[i] != parentPath[i]) {
        isChildOfParent = false;
        break;
      }
    }
    if (!isChildOfParent) continue;
    final lastSegment = row.path.last;
    if (!lastSegment.startsWith(r'$')) names.add(lastSegment);
  }
  return names;
}

/// Recursively collects every `.read` / `.write` string (or bool) value
/// anywhere under [node], as `"<jsonPath> => <value>"` pairs for reporting.
void _collectReadWriteRules(
  Map<String, dynamic> node,
  String path,
  List<MapEntry<String, dynamic>> out,
) {
  for (final entry in node.entries) {
    if (entry.key == '.read' || entry.key == '.write') {
      out.add(MapEntry('$path/${entry.key}', entry.value));
    } else if (entry.value is Map<String, dynamic>) {
      _collectReadWriteRules(
        entry.value as Map<String, dynamic>,
        '$path/${entry.key}',
        out,
      );
    }
  }
}

/// Interprets one `.read`/`.write` rule VALUE for an authenticated caller.
/// This codebase's rules file only ever produces three shapes for a bare
/// grant check with no `$uid`/`ownerUid` bound to compare against: a
/// boolean literal, and the two string forms `"auth != null"` (any
/// authenticated user) and anything else (never a blanket grant for an
/// arbitrary caller reading an arbitrary node — `auth.uid === $uid`-shaped
/// expressions require binding `$uid` to the specific uid being tested,
/// which `_cascadingReadGranted` below deliberately does not attempt; it
/// only asks "is there an ungated grant on the way to this path").
bool _grantsForAnyAuthenticatedCaller(dynamic ruleValue) {
  if (ruleValue == null) return false;
  if (ruleValue is bool) return ruleValue;
  if (ruleValue is String) return ruleValue.trim() == 'auth != null';
  return false;
}

/// Simulates RTDB's actual read-cascade evaluation for an authenticated
/// caller: walks [rules] from the root down to (and including)
/// [pathSegments], checking each level's `.read` rule as it goes. A `.read`
/// grant at any level grants the read for that node and everything below
/// it — RTDB never looks at rules *below* the requested path, and a grant
/// never flows back UP to an ancestor. This is the real evaluation
/// algorithm, not a "does this key exist" check (`E11-T06` task §3's
/// explicit requirement for the `directory`-parent-denial proof).
///
/// Every literal segment on [pathSegments] must exist in the rules tree
/// (this helper is only ever called with paths this file's own rules
/// declare); a `$`-prefixed wildcard in [rules] matches any concrete
/// segment name at that position, mirroring `_navigate`.
bool _cascadingReadGranted(
  Map<String, dynamic> rules,
  List<String> pathSegments,
) {
  var node = rules['rules'] as Map<String, dynamic>;
  if (_grantsForAnyAuthenticatedCaller(node['.read'])) return true;

  for (final segment in pathSegments) {
    Map<String, dynamic>? next;
    if (node.containsKey(segment)) {
      next = node[segment] as Map<String, dynamic>;
    } else {
      final wildcardKey =
          node.keys.where((k) => k.startsWith(r'$')).cast<String?>().firstWhere(
                (_) => true,
                orElse: () => null,
              );
      if (wildcardKey != null) next = node[wildcardKey] as Map<String, dynamic>;
    }
    if (next == null) {
      // No node at all exists at this point in the path -- nothing to grant
      // a read on, so the walk stops here, denied.
      return false;
    }
    node = next;
    if (_grantsForAnyAuthenticatedCaller(node['.read'])) return true;
  }
  return false;
}

void main() {
  final rulesFile = File('database.rules.json');
  final schemaFile = File('docs/firebase-schema.md');

  test('test_EARS_FB_4_rules_file_is_valid_json', () {
    expect(rulesFile.existsSync(), isTrue);
    expect(
      () => jsonDecode(rulesFile.readAsStringSync()),
      returnsNormally,
    );
  });

  group('test_EARS_FB_4_every_live_node_validates_its_documented_keys', () {
    late Map<String, dynamic> rules;
    late List<_SchemaRow> liveRows;

    setUpAll(() {
      rules = jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
      liveRows = _parseLiveSchemaRows(schemaFile.readAsStringSync());
    });

    test('the schema doc actually names at least one live node', () {
      // Guards against this test silently passing because the parser found
      // nothing to check.
      expect(liveRows, isNotEmpty);
    });

    test('every live node\'s declared field keys equal the schema doc\'s '
        'allow-list, and unknown children are denied', () {
      for (final row in liveRows) {
        final node = _navigate(rules, row.path);
        // A child key that is itself a separately documented `live` node
        // (e.g. `revocation` under the `devices/$deviceId` row, E11-T04) is
        // a whole sub-node, not one of this row's own scalar fields -- its
        // own field set is checked when its own row is visited in this
        // same loop.
        final nestedNodeNames = _nestedLiveNodeNames(liveRows, row.path);

        expect(
          _declaredFieldKeys(node).difference(nestedNodeNames),
          row.fields,
          reason: 'node at "${row.path.join('/')}" declares a different '
              'field set than docs/firebase-schema.md',
        );

        expect(
          node.containsKey(r'$other'),
          isTrue,
          reason: 'node at "${row.path.join('/')}" has no \$other '
              'deny-catch-all for unlisted fields',
        );
        final otherNode = node[r'$other'] as Map<String, dynamic>;
        expect(
          otherNode['.validate'],
          isFalse,
          reason: 'node at "${row.path.join('/')}" does not deny unknown '
              'fields via \$other.validate == false',
        );
      }
    });
  });

  group('test_EARS_FB_5_undocumented_paths_are_denied', () {
    late Map<String, dynamic> rules;

    setUpAll(() {
      rules = jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('top-level \$other denies read and write', () {
      final root = rules['rules'] as Map<String, dynamic>;
      expect(root.containsKey(r'$other'), isTrue);
      final other = root[r'$other'] as Map<String, dynamic>;
      expect(other['.read'], isFalse);
      expect(other['.write'], isFalse);
    });

    test('users/\$uid denies unknown child subtrees via \$other', () {
      final root = rules['rules'] as Map<String, dynamic>;
      final users = root['users'] as Map<String, dynamic>;
      final uidKey = users.keys.firstWhere((k) => k.startsWith(r'$'));
      final uidNode = users[uidKey] as Map<String, dynamic>;
      expect(
        uidNode.containsKey(r'$other'),
        isTrue,
        reason: 'users/\$uid has no \$other deny child for unknown subtrees '
            '(devices/sync_cursors siblings)',
      );
      expect((uidNode[r'$other'] as Map<String, dynamic>)['.validate'], isFalse);
    });
  });

  group('test_EARS_FB_5_documented_containers_reject_a_leaf_overwrite', () {
    // E11-B05: `$other: {".validate": false}` only fires for an UNDOCUMENTED
    // child name -- it says nothing about writing a scalar/leaf value
    // directly at a documented CONTAINER path itself (e.g.
    // `users/$uid/devices` = "a random 10MB string" instead of an object).
    // RTDB evaluates `.validate` at every level of the written hierarchy;
    // a container with no `.validate` of its own accepts anything,
    // including a leaf, because there are no children for `$other` to even
    // apply to. The fix is `.validate: newData.hasChildren()` on every
    // container level -- present here, absent anywhere in the path, and
    // the write in question is provably let through.
    late Map<String, dynamic> rules;

    setUpAll(() {
      rules = jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
    });

    /// A container node's `.validate` must literally be
    /// `newData.hasChildren()` -- the exact expression, not merely
    /// present -- so a leaf write at this path is rejected regardless of
    /// its value (a `.validate` that instead re-checked field names would
    /// still pass a leaf if RTDB's own "no children to check" behavior let
    /// it slip past a hasChildren-less field validator).
    void expectRejectsLeafWrite(Map<String, dynamic> node, String label) {
      expect(
        node['.validate'],
        'newData.hasChildren()',
        reason: '$label has no (or the wrong) container-level .validate -- '
            r'a scalar/leaf write here would be accepted, since $other'
            "'s "
            'deny-unknown-child rule only fires on a NAMED child, never on '
            'the container itself receiving a non-object value',
      );
    }

    test('users/\$uid rejects a leaf overwrite of the whole account subtree',
        () {
      final root = rules['rules'] as Map<String, dynamic>;
      final users = root['users'] as Map<String, dynamic>;
      final uidKey = users.keys.firstWhere((k) => k.startsWith(r'$'));
      expectRejectsLeafWrite(
        users[uidKey] as Map<String, dynamic>,
        r'users/$uid',
      );
    });

    test('devices rejects a leaf overwrite of the whole device list', () {
      final uidNode = _navigate(rules, ['users', r'$uid']);
      expectRejectsLeafWrite(
        uidNode['devices'] as Map<String, dynamic>,
        'users/\$uid/devices',
      );
    });

    test('relationships rejects a leaf overwrite of the whole list', () {
      final uidNode = _navigate(rules, ['users', r'$uid']);
      expectRejectsLeafWrite(
        uidNode['relationships'] as Map<String, dynamic>,
        'users/\$uid/relationships',
      );
    });

    test(
        'sync_cursors and its two intermediate wildcard levels each reject '
        'a leaf overwrite', () {
      final uidNode = _navigate(rules, ['users', r'$uid']);
      final syncCursors = uidNode['sync_cursors'] as Map<String, dynamic>;
      expectRejectsLeafWrite(syncCursors, 'users/\$uid/sync_cursors');

      final writerKey = syncCursors.keys.firstWhere((k) => k.startsWith(r'$'));
      final writerNode = syncCursors[writerKey] as Map<String, dynamic>;
      expectRejectsLeafWrite(
        writerNode,
        'users/\$uid/sync_cursors/\$writer',
      );

      final conversationKey =
          writerNode.keys.firstWhere((k) => k.startsWith(r'$'));
      final conversationNode =
          writerNode[conversationKey] as Map<String, dynamic>;
      expectRejectsLeafWrite(
        conversationNode,
        'users/\$uid/sync_cursors/\$writer/\$conversation',
      );
    });
  });

  group('test_EARS_FB_13_revocation_node_rules', () {
    late Map<String, dynamic> rules;
    late Map<String, dynamic> revocationNode;

    setUpAll(() {
      rules = jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
      revocationNode = _navigate(
        rules,
        ['users', r'$uid', 'devices', r'$deviceId', 'revocation'],
      );
    });

    test('carries only revokedAt and revokedByDeviceId', () {
      expect(
        _declaredFieldKeys(revocationNode),
        {'revokedAt', 'revokedByDeviceId'},
      );
    });

    test('rejects any other field via \$other.validate == false', () {
      expect(revocationNode.containsKey(r'$other'), isTrue);
      expect(
        (revocationNode[r'$other'] as Map<String, dynamic>)['.validate'],
        isFalse,
      );
    });

    test('the parent devices/\$deviceId node names revocation explicitly '
        '(not swallowed by its own \$other deny)', () {
      final deviceNode = _navigate(
        rules,
        ['users', r'$uid', 'devices', r'$deviceId'],
      );
      expect(deviceNode.containsKey('revocation'), isTrue);
    });
  });

  group('test_EARS_FB_16_relationship_node_rules', () {
    late Map<String, dynamic> rules;
    late Map<String, dynamic> relationshipNode;

    setUpAll(() {
      rules = jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
      relationshipNode = _navigate(
        rules,
        ['users', r'$uid', 'relationships', r'$peerDeviceId'],
      );
    });

    test('carries only state and updatedAt', () {
      expect(
        _declaredFieldKeys(relationshipNode),
        {'state', 'updatedAt'},
      );
    });

    test('state is restricted to the four known enum-name strings', () {
      final stateValidate =
          (relationshipNode['state'] as Map<String, dynamic>)['.validate']
              as String;
      for (final name in ['trusted', 'allowed', 'unknown', 'blocked']) {
        expect(stateValidate.contains("'$name'"), isTrue,
            reason: 'state .validate does not mention "$name"');
      }
    });

    test('rejects any other field via \$other.validate == false', () {
      expect(relationshipNode.containsKey(r'$other'), isTrue);
      expect(
        (relationshipNode[r'$other'] as Map<String, dynamic>)['.validate'],
        isFalse,
      );
    });

    test('own-uid read/write is inherited from the users/\$uid rule -- no '
        'narrower .read/.write is declared at this node (it would have to '
        'be at least as restrictive, and the parent rule already is)', () {
      expect(relationshipNode.containsKey('.read'), isFalse);
      expect(relationshipNode.containsKey('.write'), isFalse);
    });

    test('a foreign uid cannot read or write this node -- the only '
        '.read/.write in the whole file scoped to this subtree is '
        'users/\$uid\'s own auth.uid === \$uid rule (EARS-FB-16)', () {
      final root = rules['rules'] as Map<String, dynamic>;
      final users = root['users'] as Map<String, dynamic>;
      final uidKey = users.keys.firstWhere((k) => k.startsWith(r'$'));
      final uidNode = users[uidKey] as Map<String, dynamic>;
      expect(uidNode['.read'], 'auth != null && auth.uid === \$uid');
      expect(uidNode['.write'], 'auth != null && auth.uid === \$uid');
    });
  });

  group('test_EARS_FB_6_no_cross_account_access', () {
    test('every .read/.write outside directory/ and directory_private/ is '
        'either false or scoped to auth.uid === \$uid; none is the '
        'literal true', () {
      final rules =
          jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
      final root = rules['rules'] as Map<String, dynamic>;
      final found = <MapEntry<String, dynamic>>[];
      _collectReadWriteRules(root, '', found);

      // `directory/$deviceId` is `ADR-0008`'s ONE deliberate, reviewed
      // exception to "every read is scoped to auth.uid === $uid" — it is
      // readable by ANY authenticated user, by exact device id only. Its
      // own read/write shape is asserted explicitly and exhaustively by
      // `test_EARS_FB_18_directory_read_rules`/
      // `test_EARS_FB_19_directory_write_rules` below, so excluding it
      // here does not weaken this test: it narrows what this test is FOR
      // (proving every node that is NOT the directory stays owner-scoped)
      // rather than silently accepting a cross-account grant anywhere.
      // `directory_private/$deviceId/ownerUid` (`E11-B06` fix) is excluded
      // for the same reason -- its own shape (owner-only read, NOT
      // `auth.uid === $uid` since there is no `$uid` segment on this path)
      // is asserted exhaustively by `test_EARS_FB_20_directory_private_rules`
      // below. The prefix check uses a trailing "/" so
      // "directory_private" is never mistaken for a "directory" match by
      // this string comparison (a bare `startsWith('/directory')` would
      // wrongly swallow `/directory_private/...` too, since that string
      // also starts with the literal characters "/directory").
      final outsideDirectory = found
          .where(
            (entry) =>
                !entry.key.startsWith('/directory/') &&
                !entry.key.startsWith('/directory_private/'),
          )
          .toList();
      expect(outsideDirectory, isNotEmpty);
      for (final entry in outsideDirectory) {
        final value = entry.value;
        if (value is bool) {
          expect(
            value,
            isFalse,
            reason: '${entry.key} is a bare boolean and it is `true` — that '
                'grants access to everyone, not just the owner',
          );
        } else {
          expect(
            value is String && value.contains('auth.uid === \$uid'),
            isTrue,
            reason: '${entry.key} = "$value" does not scope access to '
                'auth.uid === \$uid',
          );
        }
      }
    });

    test('the only rules under directory/ are the exact ones E11-T06 '
        'documents -- this test cannot be satisfied by silently adding a '
        'second, broader grant somewhere else under directory/', () {
      final rules =
          jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
      final root = rules['rules'] as Map<String, dynamic>;
      final found = <MapEntry<String, dynamic>>[];
      _collectReadWriteRules(root, '', found);
      // Trailing "/" so this does not also sweep up
      // "/directory_private/..." (that string also starts with the
      // literal characters "/directory") -- checked separately, exactly,
      // below.
      final underDirectory = found
          .where((entry) => entry.key.startsWith('/directory/'))
          .toList();

      expect(underDirectory, hasLength(2));
      expect(
        underDirectory.map((e) => e.key).toSet(),
        {r'/directory/$deviceId/.read', r'/directory/$deviceId/.write'},
      );
    });

    test('the only rules under directory_private/ are the exact ones '
        'E11-B06 documents -- this test cannot be satisfied by silently '
        'adding a second, broader grant somewhere else under '
        'directory_private/', () {
      final rules =
          jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
      final root = rules['rules'] as Map<String, dynamic>;
      final found = <MapEntry<String, dynamic>>[];
      _collectReadWriteRules(root, '', found);
      final underDirectoryPrivate = found
          .where((entry) => entry.key.startsWith('/directory_private/'))
          .toList();

      expect(underDirectoryPrivate, hasLength(2));
      expect(
        underDirectoryPrivate.map((e) => e.key).toSet(),
        {
          r'/directory_private/$deviceId/ownerUid/.read',
          r'/directory_private/$deviceId/ownerUid/.write',
        },
      );
    });
  });

  group('test_EARS_FB_18_directory_read_rules', () {
    late Map<String, dynamic> rules;

    setUpAll(() {
      rules = jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('the directory/\$deviceId node grants read to any authenticated '
        'user -- the exact string, not merely "contains"', () {
      final node = _navigate(rules, ['directory', r'$deviceId']);
      expect(node['.read'], 'auth != null');
    });

    test(
      'an authenticated caller reading the bare "directory" parent node is '
      'DENIED -- proven by simulating the RTDB read-cascade (root -> '
      'directory), not by checking the JSON for an absent key '
      '(ADR-0008\'s single highest-value property: a rule granted one '
      'level too high here would let any authenticated user list/crawl '
      'the entire device directory)',
      () {
        expect(_cascadingReadGranted(rules, ['directory']), isFalse);
      },
    );

    test(
      'the SAME cascade walk one level deeper, at directory/<any-id>, IS '
      'granted -- proves the denial above is because no rule grants a '
      'read at "directory" specifically, not because the whole subtree is '
      'unreachable by this simulator',
      () {
        expect(
          _cascadingReadGranted(rules, ['directory', 'some-known-device-id']),
          isTrue,
        );
      },
    );

    test('no other node in the whole file (users/\$uid included) grants a '
        'read that would cascade down into directory/ -- \$other at the '
        'root is the only other rule above "directory" in the tree, and it '
        'denies', () {
      final root = rules['rules'] as Map<String, dynamic>;
      // "directory" is an explicit sibling of "users" and "$other" at the
      // root (this file's own JSON structure) -- there is no ancestor of
      // "directory" other than the bare root itself, which _cascadingReadGranted
      // already checked. This test instead confirms the structural sibling
      // shape assumed above still holds, so a future edit that nested
      // "directory" under something else would fail loudly here rather
      // than silently invalidating the cascade tests' assumptions.
      expect(root.containsKey('directory'), isTrue);
      expect(root['directory'], isNot(contains('.read')));
    });
  });

  group('test_EARS_FB_19_directory_write_rules', () {
    late Map<String, dynamic> rules;
    late Map<String, dynamic> deviceIdNode;

    setUpAll(() {
      rules = jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
      deviceIdNode = _navigate(rules, ['directory', r'$deviceId']);
    });

    test('carries only identityPublicKey, prekeyBundle, revokedAt -- '
        'ownerUid moved to directory_private/\$deviceId (E11-B06 fix, so '
        'it is never cross-account readable alongside these fields)', () {
      expect(
        _declaredFieldKeys(deviceIdNode),
        {'identityPublicKey', 'prekeyBundle', 'revokedAt'},
      );
    });

    test('rejects any other field via \$other.validate == false', () {
      expect(deviceIdNode.containsKey(r'$other'), isTrue);
      expect(
        (deviceIdNode[r'$other'] as Map<String, dynamic>)['.validate'],
        isFalse,
      );
    });

    test('.validate requires identityPublicKey/prekeyBundle on every write '
        '(revokedAt stays optional -- absent when not revoked; ownerUid '
        'is no longer one of this node\'s own fields, E11-B06 fix)', () {
      final validate = deviceIdNode['.validate'] as String;
      for (final field in ['identityPublicKey', 'prekeyBundle']) {
        expect(validate.contains("'$field'"), isTrue,
            reason: '.validate does not require "$field"');
      }
      expect(validate.contains("'revokedAt'"), isFalse,
          reason: '.validate must not require "revokedAt" -- it is null/'
              'absent when a device has never been revoked');
      expect(validate.contains("'ownerUid'"), isFalse,
          reason: '.validate must not require "ownerUid" -- it is no '
              'longer a field of this node (E11-B06 fix)');
    });

    test('.write checks ownership against directory_private/\$deviceId/'
        'ownerUid (E11-B06 fix), not a field on this node -- exact string, '
        'not merely "contains"', () {
      // Round 1 review (Opus, emulator-verified) found the original
      // `root.child(...)` shape here permanently denies every new device's
      // first publish: `root` in a multi-location `update()` reflects the
      // PRE-write snapshot, never the sibling paths being written in the
      // SAME update. `newData.parent().parent()` -- walking up from this
      // rule's own location (`directory/$deviceId`) through `directory`
      // to the update's merged root -- is the Firebase-documented idiom
      // for exactly this, and was verified against a real
      // `@firebase/rules-unit-testing` emulator (not assumed) before this
      // string was written: a brand-new device's atomic
      // {directory/$id, directory_private/$id/ownerUid} update succeeds,
      // a second account's squat attempt on an existing entry is denied,
      // and the true owner's own re-publish/rotation still succeeds.
      //
      // Round 3 review (Opus, emulator-verified) found this refactor had
      // silently DROPPED a property the old self-contained `ownerUid`
      // check used to carry for free: when deleting a node, `newData` at
      // that node is null, so the OLD `newData.child('ownerUid').val() ===
      // auth.uid` check (comparing null.child(...) against a uid) was
      // never true, denying deletion. The new expression never reads
      // `newData` at THIS node's own value at all, so a delete sailed
      // through unnoticed -- reopening finding 3's "revoke, don't delete,
      // permanent" human decision as an unreviewed side effect, not a
      // choice. `newData.exists() &&` restores it explicitly, verified
      // against the same emulator: the owner's own `remove()` and a
      // multi-location `update({'directory/$id': null})` are both denied,
      // while every other case above still passes.
      expect(
        deviceIdNode['.write'],
        "auth != null && newData.exists() && newData.parent().parent()"
            ".child('directory_private').child(\$deviceId).child('ownerUid')"
            ".val() === auth.uid",
      );
    });

    test('.write denies deletion of an existing entry -- finding 3\'s '
        '"revoke, don\'t delete, permanent" human decision (ADR-0008 '
        'addendum), re-derived independently of the exact-string test '
        'above so a future edit to the ownership clause cannot silently '
        'drop this one too', () {
      final write = deviceIdNode['.write'] as String;
      // On a delete, `newData` at this node is null/absent -- `.exists()`
      // is false regardless of who is deleting or what the ownership
      // check would otherwise say, so this clause alone is what denies
      // every delete, not an accident of how the ownership check happens
      // to evaluate against a null newData. Verified against a real
      // `@firebase/rules-unit-testing` emulator (round 3 review): the
      // owner's own `remove()` and a multi-location
      // `update({'directory/$id': null})` are both denied with this
      // clause present, and both succeed if it is removed -- this is not
      // a rules-language assumption, it was falsified both ways.
      expect(write.contains('newData.exists()'), isTrue,
          reason: '.write has no newData.exists() guard -- a delete of an '
              'existing directory/\$deviceId entry would silently succeed, '
              'reopening finding 3\'s decision as an unreviewed side '
              'effect (E11-B06 round 3)');
    });
  });

  group('test_EARS_FB_20_directory_private_rules', () {
    // E11-B06 fix: `ownerUid` moved out of the cross-account-readable
    // `directory/$deviceId` node into its own node, readable only by the
    // caller whose uid it already names. This group is
    // `test_EARS_FB_19_directory_write_rules`'s own former "ownerUid
    // immutability" tests, re-targeted at the node that now actually
    // carries the field.
    late Map<String, dynamic> rules;
    late Map<String, dynamic> ownerUidNode;

    setUpAll(() {
      rules = jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
      ownerUidNode =
          _navigate(rules, ['directory_private', r'$deviceId', 'ownerUid']);
    });

    test('.read restricts this node to the caller whose auth.uid already '
        'equals the stored value -- never any other authenticated '
        'account -- exact string, not merely "contains"', () {
      expect(
        ownerUidNode['.read'],
        "auth != null && data.val() === auth.uid",
      );
    });

    test('.write requires the caller to write their OWN uid (non-owner '
        'write denied) -- exact string, not merely "contains"', () {
      expect(
        ownerUidNode['.write'],
        "auth != null && newData.val() === auth.uid && "
            "(!data.exists() || data.val() === auth.uid)",
      );
    });

    test('.write makes ownerUid immutable after first write: a caller '
        'whose uid does not match the EXISTING value is denied regardless '
        'of what they write, and a caller who does match can never write '
        'a DIFFERENT uid than their own -- both consequences fall out of '
        'the single conjunction above, verified here by re-deriving each '
        'clause independently', () {
      final write = ownerUidNode['.write'] as String;
      // Clause 1: every write's new value must equal the caller's uid --
      // this alone already forces the value to only ever be the writer's
      // own uid, on every single write, first or not.
      expect(write.contains('newData.val() === auth.uid'), isTrue);
      // Clause 2: once the node exists, the EXISTING value must also equal
      // the caller's uid -- so a second account can never overwrite a
      // first account's entry, which is exactly the "whoever publishes
      // first wins a race that should not be a race" risk `E11-B06` names.
      expect(
        write.contains('(!data.exists() || data.val() === auth.uid)'),
        isTrue,
      );
    });

    test('the parent directory/\$deviceId node reads exactly this path to '
        'authorize its own write -- proves the two nodes are actually '
        'wired together, not just independently correct', () {
      final deviceIdNode = _navigate(rules, ['directory', r'$deviceId']);
      final write = deviceIdNode['.write'] as String;
      expect(
        write.contains(
          "newData.parent().parent().child('directory_private')"
              ".child(\$deviceId).child('ownerUid')",
        ),
        isTrue,
      );
    });
  });
}
