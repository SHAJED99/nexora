// E11-T02 — structural tests for `database.rules.json` (EARS-FB-4, FB-5,
// FB-6).
//
// These tests prove the rules FILE SAYS the right thing: they parse
// `database.rules.json` and cross-check it against `docs/firebase-schema.md`
// (the single source of truth for what fields each `live` node may carry —
// task §6 Risks: "a test that duplicates the thing it is checking passes
// even when both are wrong together"). They do not prove the Realtime
// Database SERVER enforces it — that needs the Firebase emulator, deferred
// per `OQ-E11-T02-1` to land with `E11-T05`/`E11-T06`.
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

        expect(
          _declaredFieldKeys(node),
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

  group('test_EARS_FB_6_no_cross_account_access', () {
    test('every .read/.write in the file is either false or scoped to '
        'auth.uid === \$uid; none is the literal true', () {
      final rules =
          jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>;
      final root = rules['rules'] as Map<String, dynamic>;
      final found = <MapEntry<String, dynamic>>[];
      _collectReadWriteRules(root, '', found);

      expect(found, isNotEmpty);
      for (final entry in found) {
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
  });
}
