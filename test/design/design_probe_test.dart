// test/design/design_probe_test.dart — the Flutter-capable design-fidelity
// gate's runner (E06-T01, closes OQ-E00-3).
//
// Two jobs, both here per the task contract:
//   1. Register every screen this gate can dump. `make design-probe` runs
//      this file; each registered screen is pumped via `dumpScreenProbe` and
//      written to build/design-probe/<screenId>.json for `make design-verify
//      SCREEN=<id> IMPL=flutter` to read (see design/tools/verify.mjs).
//      `devices` is the proving screen for this task (E02-T02, already built
//      and hand-checked) — T10/T11/T12 add their own screens here, in their
//      own files: fence, following the one-block pattern below.
//   2. The EARS falsification tests (EARS-UI-1/2). These use a small fixture
//      widget, NOT `devices` — fast, deterministic, and isolated from that
//      screen's real complexity (§8 of the task file). They reuse
//      design/tools/lib/compare.mjs and flutter_probe.mjs UNCHANGED by
//      shelling out to `node` — this is the same comparison engine
//      `make design-verify` runs, not a reimplementation of it.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/devices/presentation/devices_binding.dart';
import 'package:nexora/features/devices/presentation/devices_view.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';
import 'package:path/path.dart' as p;

import 'flutter_probe_dumper.dart';

void main() {
  // ── 1. Screens dumped for `make design-probe` ───────────────────────────
  group('screen probes (make design-probe)', () {
    late AppDatabase db;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = RelationshipRepository(db);
      // One of each RelationshipState, per design/screens/devices.md's four
      // example rows (§2). Real device names/timestamps won't literally
      // match the design's copy ("Ahmed's Laptop" etc.) — that's a real,
      // expected finding (design/gaps.md GAP-003), not something faked here
      // to dodge it (E06-T01 §4/§Run log).
      await repository.upsert('device-trusted', RelationshipState.trusted);
      await repository.upsert('device-allowed', RelationshipState.allowed);
      await repository.upsert('device-unknown', RelationshipState.unknown);
      await repository.upsert('device-blocked', RelationshipState.blocked);
      Get.put<RelationshipRepository>(repository, permanent: true);
      Get.put<BlockUseCase>(BlockUseCase(repository), permanent: true);
      DevicesBinding().dependencies();
    });

    tearDown(() async {
      await db.close();
      Get.reset();
    });

    testWidgets('devices', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'devices',
        screen: GetMaterialApp(home: const DevicesView()),
      );
    });
  });

  // ── 2. EARS falsification — a fixture, not `devices` ─────────────────────
  group('EARS-UI-1/2 — fixture falsification', () {
    testWidgets(
        'test_EARS_UI_1_flutter_probe_dumps_every_visible_element',
        (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_faithful_a',
        screen: _fixture(),
      );
      // Real dart:io read — must go through runAsync for the same reason
      // dumpScreenProbe's own file write does (see flutter_probe_dumper.dart).
      final raw = await tester.runAsync(
        () => File('build/design-probe/_fixture_faithful_a.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      final elements = (dump['elements'] as List).cast<Map<String, dynamic>>();
      expect(elements, isNotEmpty);

      final title = elements.singleWhere((e) => e['text'] == 'Fixture Title');
      expect(title['role'], 'generic');
      // Resolved via DefaultTextStyle.merge, never the widget's own (null)
      // color — proving this dumps RESOLVED styles, not source constants.
      expect(title['style']['color'], 'rgb(0, 0, 255)');
      expect(title['style']['fontSize'], '24px');
      expect(title['style']['fontWeight'], '600');

      final button = elements.singleWhere((e) => e['role'] == 'button');
      expect(button['text'], 'Go');

      final panel = elements.singleWhere(
        (e) => e['role'] == 'generic' && e['surface'] == true && e['text'] == '',
      );
      expect(panel['style']['background'], 'rgb(20, 40, 60)');
      expect(panel['style']['radius'], '8px');
    });

    testWidgets(
        'test_EARS_UI_2_faithful_fixture_passes_the_gate',
        (tester) async {
      await dumpScreenProbe(tester, screenId: '_fixture_faithful_b1', screen: _fixture());
      await dumpScreenProbe(tester, screenId: '_fixture_faithful_b2', screen: _fixture());

      final r = await _compare(tester, '_fixture_faithful_b1', '_fixture_faithful_b2');
      expect(r['missing'], 0, reason: 'unmutated fixture reported missing elements');
      expect(r['copy'], 0, reason: 'unmutated fixture reported copy drift');
      expect(r['style'], 0, reason: 'unmutated fixture reported style drift');
      expect(r['matched'], greaterThan(0));
    });

    testWidgets(
        'test_EARS_UI_2_drifted_fixture_fails_the_gate — delete an element',
        (tester) async {
      await dumpScreenProbe(tester, screenId: '_fixture_golden_del', screen: _fixture());
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_mutated_del',
        screen: _fixture(hideButton: true),
      );
      final r = await _compare(tester, '_fixture_golden_del', '_fixture_mutated_del');
      expect(r['missing'], greaterThan(0),
          reason: 'deleting the button element must be a HARD "missing" finding');
    });

    testWidgets(
        'test_EARS_UI_2_drifted_fixture_fails_the_gate — one-character copy change',
        (tester) async {
      await dumpScreenProbe(tester, screenId: '_fixture_golden_text', screen: _fixture());
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_mutated_text',
        screen: _fixture(labelSuffix: 'X'),
      );
      final r = await _compare(tester, '_fixture_golden_text', '_fixture_mutated_text');
      expect(r['copy'], greaterThan(0),
          reason: 'a one-character copy change must be a HARD copy-mismatch finding');
    });

    testWidgets(
        'test_EARS_UI_2_drifted_fixture_fails_the_gate — one colour channel',
        (tester) async {
      await dumpScreenProbe(tester, screenId: '_fixture_golden_color', screen: _fixture());
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_mutated_color',
        screen: _fixture(colorChannelDelta: 40),
      );
      final r = await _compare(tester, '_fixture_golden_color', '_fixture_mutated_color');
      expect(r['style'], greaterThan(0),
          reason: 'a single colour-channel change must be a HARD style-delta finding');
    });

    testWidgets(
        'test_EARS_UI_2_drifted_fixture_fails_the_gate — radius +4px',
        (tester) async {
      await dumpScreenProbe(tester, screenId: '_fixture_golden_radius', screen: _fixture());
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_mutated_radius',
        screen: _fixture(radiusDelta: 4),
      );
      final r = await _compare(tester, '_fixture_golden_radius', '_fixture_mutated_radius');
      expect(r['style'], greaterThan(0),
          reason: 'a 4px radius change must be a HARD style-delta finding');
    });
  });
}

/// The falsification fixture — deliberately tiny: a heading-ish `Text` under
/// a `DefaultTextStyle` (proves style RESOLUTION), a decorated `Container`
/// (a surface), and a `GestureDetector` button (an interactive element).
/// Mutation flags each isolate exactly one of the four EARS-UI-2 drifts.
Widget _fixture({
  bool hideButton = false,
  String labelSuffix = '',
  int colorChannelDelta = 0,
  double radiusDelta = 0,
}) {
  final panelColor = Color.fromARGB(255, 20 + colorChannelDelta, 40, 60);
  return MaterialApp(
    home: Scaffold(
      body: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF0000FF), fontFamily: 'Roboto'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fixture Title$labelSuffix',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            Container(
              width: 100,
              height: 40,
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(8 + radiusDelta),
              ),
            ),
            if (!hideButton)
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 80,
                  height: 32,
                  color: Colors.green,
                  child: const Center(child: Text('Go')),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Runs `design/tools/lib/compare.mjs` + `flutter_probe.mjs` (via `node`,
/// UNCHANGED) over two probe dumps and returns hard-finding counts. This is
/// the same comparison engine `design/tools/verify.mjs` runs — reused, not
/// reimplemented — so this test proves what the real gate would report.
Future<Map<String, dynamic>> _compare(
    WidgetTester tester, String goldenScreenId, String implScreenId) async {
  final root = Directory.current.path;
  final comparePath = p.join(root, 'design', 'tools', 'lib', 'compare.mjs');
  final flutterProbePath = p.join(root, 'design', 'tools', 'lib', 'flutter_probe.mjs');
  final goldenPath = p.join(root, 'build', 'design-probe', '$goldenScreenId.json');
  final implPath = p.join(root, 'build', 'design-probe', '$implScreenId.json');
  // Mirrors design/thresholds.yaml's current numeric values for this
  // self-contained fixture test — not read from that file (no YAML parser
  // dependency is added for it); the real gate always reads the real file.
  const tolerance = {
    'color': 'exact', 'font_size_px': 0.5, 'font_weight': 0,
    'radius_px': 1.0, 'spacing_px': 2.0,
  };

  const script = r'''
const { pathToFileURL } = require("node:url");
(async () => {
  // `node -e <script> arg1 arg2 ...` does NOT reserve argv[1] for a script
  // path the way `node file.js arg1 arg2 ...` does -- argv[0] is the node
  // binary and the passed args start immediately at argv[1] (verified
  // directly against this environment's Node v24; confirmed as the actual
  // cause of `_compare`'s "undefined is not valid JSON" failure, a
  // pre-existing off-by-one that only surfaced once the runAsync fix let
  // this script actually execute instead of hanging beforehand).
  const comparePath = process.argv[1];
  const flutterProbePath = process.argv[2];
  const goldenPath = process.argv[3];
  const implPath = process.argv[4];
  const tol = JSON.parse(process.argv[5]);
  const { matchElements, copyDiff, styleDeltas, tokenDiff } = await import(pathToFileURL(comparePath).href);
  const { loadFlutterProbe } = await import(pathToFileURL(flutterProbePath).href);
  const golden = loadFlutterProbe(goldenPath);
  const impl = loadFlutterProbe(implPath);
  const { pairs, missing } = matchElements(golden.elements, impl.elements);
  const copy = copyDiff(pairs, golden.elements, impl.elements, []);
  const style = styleDeltas(pairs, tol);
  const tokens = tokenDiff(golden.tokens, impl.tokens, tol);
  process.stdout.write(JSON.stringify({
    missing: missing.length, copy: copy.length, style: style.length,
    tokens: tokens.length, matched: pairs.length,
  }));
})();
''';

  // Process.run is real dart:io async I/O too — same runAsync requirement.
  final result = await tester.runAsync(() => Process.run('node', [
        '-e', script,
        comparePath, flutterProbePath, goldenPath, implPath, jsonEncode(tolerance),
      ]));
  if (result!.exitCode != 0) {
    fail('node comparison script failed: ${result.stderr}');
  }
  return jsonDecode(result.stdout as String) as Map<String, dynamic>;
}
