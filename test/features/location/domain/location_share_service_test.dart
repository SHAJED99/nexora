// Tests for LocationShareService (E09-T03, task file §5/§8,
// EARS-LOC-8/9/10/11/12).
//
// Two harnesses, mirroring `call_signaling_test.dart`/
// `group_membership_service_test.dart`'s own established patterns:
//   - Real two-stack `MessagingStack`s wired through a mocked
//     `TransportService` pigeon channel, for the send-side gate
//     (EARS-LOC-9), the full encrypted round trip (EARS-LOC-8), and the
//     ciphertext-containment property.
//   - Direct `handleWireFrame(wireFrame)` calls against a hand-seeded
//     receiving stack, for the receive-side gate and malformed/undecryptable
//     rejection (EARS-LOC-10/12) -- these need a real Signal session (to
//     produce a genuine ciphertext) but not a real network hop.
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/crypto_stub.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/messaging/group_control.dart'
    show encodeCiphertextControlBody;
import 'package:nexora/core/messaging/location_share.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/location/data/location_fix_repository.dart';
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/location/domain/location_share_service.dart';
import 'package:nexora/features/location/domain/location_source.dart';
import 'package:nexora/features/location/domain/location_visibility.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// A fully-controllable [LocationSource] test fake -- the one concrete
/// implementation this task adds (task file §3: "its only concrete
/// implementation in this task is the test fake"). Records call count so a
/// refused share can be proven to never have read the device's position
/// (task file §2/§8 EARS-LOC-9).
class _FakeLocationSource implements LocationSource {
  _FakeLocationSource([this._fix]);

  LocationFix? _fix;
  int callCount = 0;

  void setFix(LocationFix? fix) => _fix = fix;

  @override
  Future<LocationFix?> currentFix() async {
    callCount++;
    return _fix;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'location-share-${suffixCounter++}';

  Future<MessagingStack> newStack(String selfDeviceId, String suffix) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = DriftSignalProtocolStore(db);
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: selfDeviceId,
      store: store,
      cryptoService: CryptoService.withStore(store),
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      ),
    );
    expect(stack.status, const MessagingStackStatus.ready());
    return stack;
  }

  Future<void> establishMutualSessions(
    MessagingStack a,
    MessagingStack b,
  ) async {
    await a.cryptoService.establishSession(
      SignalProtocolAddress(b.selfDeviceId, 1),
      await b.identityService.getLocalPreKeyBundle(),
    );
    final bootstrap = await a.cryptoService.encrypt(
      SignalProtocolAddress(b.selfDeviceId, 1),
      Uint8List.fromList([0]),
    );
    await b.cryptoService.decrypt(
      SignalProtocolAddress(a.selfDeviceId, 1),
      bootstrap,
    );
  }

  /// Grants [peerDeviceId] full FR-LOC-003 visibility from [stack]'s own
  /// perspective: trusted relationship, global sharing on, per-peer sharing
  /// on. Both [LocationShareService.share] (recipient-side gate) and
  /// [LocationShareService.handleWireFrame] (sender-side gate) read these
  /// same three facts off [stack]'s own database (this file's header: no
  /// two-sided relationship-state exchange exists yet, so a device's own
  /// local state stands in for both sides).
  Future<void> allowVisibility(MessagingStack stack, String peerDeviceId) async {
    await RelationshipRepository(stack.db)
        .upsert(peerDeviceId, RelationshipState.trusted);
    final settings = LocationSettingsRepository(db: stack.db);
    await settings.writeGlobalEnabled(true);
    await settings.writePeerEnabled(peerDeviceId, true);
  }

  LocationShareService buildService(
    MessagingStack stack, {
    LocationSource? locationSource,
  }) {
    return LocationShareService(
      stack: stack,
      settings: LocationSettingsRepository(db: stack.db),
      fixes: LocationFixRepository(db: stack.db),
      relationships: RelationshipRepository(stack.db),
      locationSource: locationSource ?? _FakeLocationSource(),
    );
  }

  group('send-side gate (EARS-LOC-9)', () {
    test('test_EARS_LOC_9_blocked_peer_share_sends_nothing', () async {
      final stack = await newStack('device-a', nextSuffix());
      addTearDown(stack.dispose);

      await RelationshipRepository(stack.db)
          .upsert('device-b', RelationshipState.blocked);
      final settings = LocationSettingsRepository(db: stack.db);
      await settings.writeGlobalEnabled(true);
      await settings.writePeerEnabled('device-b', true);

      final fake = _FakeLocationSource(
        const LocationFix(latitude: 1, longitude: 1, capturedAtMs: 1000),
      );
      final service = buildService(stack, locationSource: fake);

      final outcome = await service.share('device-b');

      expect(
        outcome,
        const LocationShareOutcomeBlockedByPolicy(
          LocationUnavailableReason.blocked,
        ),
      );
      expect(fake.callCount, 0, reason: 'a refused share must not read GPS');
    });

    test(
      'test_EARS_LOC_9_global_off_share_does_not_call_location_source',
      () async {
        final stack = await newStack('device-a', nextSuffix());
        addTearDown(stack.dispose);

        await RelationshipRepository(stack.db)
            .upsert('device-b', RelationshipState.trusted);
        final settings = LocationSettingsRepository(db: stack.db);
        await settings.writeGlobalEnabled(false);
        await settings.writePeerEnabled('device-b', true);

        final fake = _FakeLocationSource(
          const LocationFix(latitude: 1, longitude: 1, capturedAtMs: 1000),
        );
        final service = buildService(stack, locationSource: fake);

        final outcome = await service.share('device-b');

        expect(
          outcome,
          const LocationShareOutcomeBlockedByPolicy(
            LocationUnavailableReason.globalOff,
          ),
        );
        expect(fake.callCount, 0);
      },
    );

    test('noFix outcome when LocationSource reports nothing', () async {
      final stack = await newStack('device-a', nextSuffix());
      addTearDown(stack.dispose);
      await allowVisibility(stack, 'device-b');

      final fake = _FakeLocationSource(null);
      final service = buildService(stack, locationSource: fake);

      final outcome = await service.share('device-b');

      expect(outcome, const LocationShareOutcomeNoFix());
      expect(fake.callCount, 1);
    });

    test(
      'test_share_returns_rather_than_throws_on_unencodable_fix',
      () async {
        // E09-B10 reviewer repro, verbatim: an out-of-range latitude (91.0
        // degrees -- there is no such latitude) makes `LocationShareFrame
        // .serialize()`'s `_requireInRange` throw `AppFailure`. Pre-fix,
        // that throw happened above `share()`'s try block and crossed
        // `share()`'s own boundary uncaught, breaking task file §5's
        // "returns, never throws" contract.
        final stack = await newStack('device-a', nextSuffix());
        addTearDown(stack.dispose);
        await allowVisibility(stack, 'device-b');

        final fake = _FakeLocationSource(
          const LocationFix(latitude: 91.0, longitude: 0, capturedAtMs: 1),
        );
        final service = buildService(stack, locationSource: fake);

        final outcome = await service.share('device-b');

        expect(outcome, const LocationShareOutcomeNoFix());
      },
    );

    test(
      'test_share_returns_rather_than_throws_on_non_finite_fix',
      () async {
        // Companion case: `.round()` on a non-finite double throws
        // `UnsupportedError`, not `AppFailure` -- a different exception
        // type, same "must not escape share()" contract.
        final stack = await newStack('device-a', nextSuffix());
        addTearDown(stack.dispose);
        await allowVisibility(stack, 'device-b');

        final fake = _FakeLocationSource(
          const LocationFix(
            latitude: double.nan,
            longitude: 0,
            capturedAtMs: 1,
          ),
        );
        final service = buildService(stack, locationSource: fake);

        final outcome = await service.share('device-b');

        expect(outcome, const LocationShareOutcomeNoFix());
      },
    );
  });

  group('full round trip (EARS-LOC-8)', () {
    Future<void> wireStacks(
      MessagingStack a,
      String aSuffix,
      MessagingStack b,
      String bSuffix,
    ) async {
      void wireSend(String fromSuffix, String fromDeviceId, String toSuffix) {
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.send.$fromSuffix',
          (ByteData? message) async {
            final args = TransportApi.pigeonChannelCodec.decodeMessage(message)!
                as List<Object?>;
            final bytes = args[1]! as Uint8List;
            final eventMessage = TransportEventsApi.pigeonChannelCodec
                .encodeMessage(<Object?>[fromDeviceId, bytes])!;
            messenger.handlePlatformMessage(
              'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$toSuffix',
              eventMessage,
              (ByteData? _) {},
            );
            return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
          },
        );
        // E04-B05: `LocationShareService`'s direct-neighbor send branch now
        // goes through `_stack.directSend` (connect-then-send) -- mock
        // `[fromSuffix]`'s own `TransportApi.connect` to accept and settle
        // immediately, mirroring `TransportService.connect`'s real
        // two-channel contract.
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.connect.$fromSuffix',
          (ByteData? message) async {
            final args = TransportApi.pigeonChannelCodec.decodeMessage(message)!
                as List<Object?>;
            final deviceId = args[0]! as String;
            scheduleMicrotask(() {
              messenger.handlePlatformMessage(
                'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$fromSuffix',
                TransportEventsApi.pigeonChannelCodec.encodeMessage(
                  <Object?>[deviceId, ConnectionState.connected],
                )!,
                (ByteData? _) {},
              );
            });
            return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
          },
        );
      }

      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 20));

      Future<void> connectPeer(String suffix, String deviceId) async {
        final device = TransportDevice(
          id: deviceId,
          displayName: deviceId,
          type: TransportType.bluetooth,
        );
        messenger.handlePlatformMessage(
          'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
          TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device])!,
          (ByteData? _) {},
        );
        await settle();
        messenger.handlePlatformMessage(
          'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
          TransportEventsApi.pigeonChannelCodec
              .encodeMessage(<Object?>[deviceId, ConnectionState.connected])!,
          (ByteData? _) {},
        );
        await settle();
      }

      a.inbound.start();
      b.inbound.start();
      wireSend(aSuffix, a.selfDeviceId, bSuffix);
      wireSend(bSuffix, b.selfDeviceId, aSuffix);
      await connectPeer(aSuffix, b.selfDeviceId);
      await connectPeer(bSuffix, a.selfDeviceId);
    }

    test(
      'test_EARS_LOC_8_round_trip_two_stacks_decodes_identical_fix',
      () async {
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final alice = await newStack('alice', aSuffix);
        final bob = await newStack('bob', bSuffix);
        addTearDown(alice.dispose);
        addTearDown(bob.dispose);

        await establishMutualSessions(alice, bob);
        await wireStacks(alice, aSuffix, bob, bSuffix);

        await allowVisibility(alice, 'bob');
        await allowVisibility(bob, 'alice');

        final fake = _FakeLocationSource(
          const LocationFix(
            latitude: 40.7128,
            longitude: -74.0060,
            accuracyM: 5.0,
            capturedAtMs: 1_700_000_000_000,
          ),
        );
        final aliceService = buildService(alice, locationSource: fake);

        final outcome = await aliceService.share('bob');
        expect(outcome, const LocationShareOutcomeSent());

        await Future<void>.delayed(const Duration(milliseconds: 20));

        final bobFix = await LocationFixRepository(db: bob.db).readFix('alice');
        expect(bobFix, isNotNull);
        expect(bobFix!.latitude, closeTo(40.7128, 1e-6));
        expect(bobFix.longitude, closeTo(-74.0060, 1e-6));
        expect(bobFix.accuracyM, closeTo(5.0, 1e-6));
        expect(bobFix.capturedAt, 1_700_000_000_000);
      },
    );

    test(
      'test_E04_B15_share_frame_destination_uses_learned_remoteSelfDeviceId',
      () async {
        // Same defect class E04-B13 fixed for 1:1 chat, applied to
        // `LocationShareService.share`'s own `RelayPacketFrame`
        // construction site: before this fix, the frame's `destination`
        // was the raw Bluetooth MAC of the peer, which can never equal
        // that peer's real `selfDeviceId` -- `isForUs` always false on
        // the receiving device, so the share is mistaken for a relay
        // packet and never reaches `LocationShareService.handleWireFrame`
        // at all.
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final alice = await newStack('alice', aSuffix);
        final bob = await newStack('bob-real-id', bSuffix);
        addTearDown(alice.dispose);
        addTearDown(bob.dispose);

        const bMac = 'AA:BB:CC:DD:EE:70';
        const aMac = 'AA:BB:CC:DD:EE:71';

        // Mirrors `establishMutualSessions`'s own bootstrap, except
        // alice's local session with bob is keyed by `bMac` (the raw MAC
        // `share` actually addresses bob by), not by `bob.selfDeviceId`.
        await alice.cryptoService.establishSession(
          const SignalProtocolAddress(bMac, 1),
          await bob.identityService.getLocalPreKeyBundle(),
        );
        final bootstrap = await alice.cryptoService.encrypt(
          const SignalProtocolAddress(bMac, 1),
          Uint8List.fromList([0]),
        );
        await bob.cryptoService.decrypt(
          const SignalProtocolAddress('alice', 1),
          bootstrap,
        );

        alice.inbound.start();
        bob.inbound.start();

        void wireSend(String fromSuffix, String fromDeviceId, String toSuffix) {
          messenger.setMockMessageHandler(
            'dev.flutter.pigeon.nexora.TransportApi.send.$fromSuffix',
            (ByteData? message) async {
              final args = TransportApi.pigeonChannelCodec
                      .decodeMessage(message)!
                  as List<Object?>;
              final bytes = args[1]! as Uint8List;
              messenger.handlePlatformMessage(
                'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$toSuffix',
                TransportEventsApi.pigeonChannelCodec
                    .encodeMessage(<Object?>[fromDeviceId, bytes]),
                (ByteData? _) {},
              );
              return TransportApi.pigeonChannelCodec
                  .encodeMessage(<Object?>[true]);
            },
          );
          messenger.setMockMessageHandler(
            'dev.flutter.pigeon.nexora.TransportApi.connect.$fromSuffix',
            (ByteData? message) async {
              final args = TransportApi.pigeonChannelCodec
                      .decodeMessage(message)!
                  as List<Object?>;
              final deviceId = args[0]! as String;
              scheduleMicrotask(() {
                messenger.handlePlatformMessage(
                  'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$fromSuffix',
                  TransportEventsApi.pigeonChannelCodec.encodeMessage(
                    <Object?>[deviceId, ConnectionState.connected],
                  ),
                  (ByteData? _) {},
                );
              });
              return TransportApi.pigeonChannelCodec
                  .encodeMessage(<Object?>[true]);
            },
          );
        }

        Future<void> connectPeer(String suffix, String deviceId) async {
          final device = TransportDevice(
            id: deviceId,
            displayName: deviceId,
            type: TransportType.bluetooth,
          );
          messenger.handlePlatformMessage(
            'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
            TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device]),
            (ByteData? _) {},
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));
          messenger.handlePlatformMessage(
            'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
            TransportEventsApi.pigeonChannelCodec
                .encodeMessage(<Object?>[deviceId, ConnectionState.connected]),
            (ByteData? _) {},
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }

        wireSend(aSuffix, aMac, bSuffix);
        wireSend(bSuffix, bMac, aSuffix);
        await connectPeer(aSuffix, bMac);
        await connectPeer(bSuffix, aMac);

        await allowVisibility(alice, bMac);
        await allowVisibility(bob, 'alice');

        // Alice already learned (E04-B12's identity-announce, simulated
        // as its already-landed effect) that the peer on `bMac` is really
        // `bob-real-id`.
        await alice.db.into(alice.db.relationships).insertOnConflictUpdate(
              RelationshipsCompanion.insert(
                deviceId: bMac,
                state: RelationshipState.trusted.name,
                updatedAt: DateTime.now(),
                remoteSelfDeviceId: const Value('bob-real-id'),
              ),
            );

        final fake = _FakeLocationSource(
          const LocationFix(
            latitude: 10.0,
            longitude: 20.0,
            capturedAtMs: 1_700_000_000_000,
          ),
        );
        final aliceService = buildService(alice, locationSource: fake);

        final outcome = await aliceService.share(bMac);
        expect(outcome, const LocationShareOutcomeSent());

        await Future<void>.delayed(const Duration(milliseconds: 20));

        final bobFix = await LocationFixRepository(db: bob.db).readFix('alice');
        expect(bobFix, isNotNull);
        expect(bobFix!.latitude, closeTo(10.0, 1e-6));
      },
    );

    test(
      'test_EARS_LOC_8_share_payload_is_ciphertext_not_plaintext',
      () async {
        final aSuffix = nextSuffix();
        final bSuffix = nextSuffix();
        final alice = await newStack('alice', aSuffix);
        final bob = await newStack('bob', bSuffix);
        addTearDown(alice.dispose);
        addTearDown(bob.dispose);

        await establishMutualSessions(alice, bob);

        final captured = <Uint8List>[];
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.send.$aSuffix',
          (ByteData? message) async {
            final args =
                TransportApi.pigeonChannelCodec.decodeMessage(message)!
                    as List<Object?>;
            captured.add(args[1]! as Uint8List);
            return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
          },
        );
        // E04-B05: `LocationShareService`'s direct-neighbor send branch now
        // goes through `_stack.directSend` (connect-then-send) -- mock
        // `[aSuffix]`'s own `TransportApi.connect` to accept and settle
        // immediately, mirroring `TransportService.connect`'s real
        // two-channel contract.
        messenger.setMockMessageHandler(
          'dev.flutter.pigeon.nexora.TransportApi.connect.$aSuffix',
          (ByteData? message) async {
            final args =
                TransportApi.pigeonChannelCodec.decodeMessage(message)!
                    as List<Object?>;
            final deviceId = args[0]! as String;
            scheduleMicrotask(() {
              messenger.handlePlatformMessage(
                'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$aSuffix',
                TransportEventsApi.pigeonChannelCodec.encodeMessage(
                  <Object?>[deviceId, ConnectionState.connected],
                )!,
                (ByteData? _) {},
              );
            });
            return TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
          },
        );

        await allowVisibility(alice, 'bob');

        const latitude = 12.3456789;
        const longitude = -98.7654321;
        final fake = _FakeLocationSource(
          const LocationFix(
            latitude: latitude,
            longitude: longitude,
            capturedAtMs: 1234,
          ),
        );
        final aliceService = buildService(alice, locationSource: fake);

        final outcome = await aliceService.share('bob');
        expect(outcome, const LocationShareOutcomeSent());
        expect(captured, hasLength(1));

        // The plaintext wire encoding of the two coordinates must not
        // appear anywhere in what actually left this device -- proves the
        // frame travelled as ciphertext, not cleartext (FR-LOC-004).
        final plaintextFrame = LocationShareFrame(
          latitudeE7: (latitude * 1e7).round(),
          longitudeE7: (longitude * 1e7).round(),
          capturedAtMs: 1234,
        ).serialize();
        final latBytes = plaintextFrame.sublist(2, 6);
        final lonBytes = plaintextFrame.sublist(6, 10);

        bool containsSubsequence(Uint8List haystack, Uint8List needle) {
          for (var i = 0; i <= haystack.length - needle.length; i++) {
            var matched = true;
            for (var j = 0; j < needle.length; j++) {
              if (haystack[i + j] != needle[j]) {
                matched = false;
                break;
              }
            }
            if (matched) return true;
          }
          return false;
        }

        expect(containsSubsequence(captured.single, latBytes), isFalse);
        expect(containsSubsequence(captured.single, lonBytes), isFalse);
      },
    );
  });

  group('receive-side gate + malformed rejection (EARS-LOC-10/12)', () {
    Future<RelayPacketFrame> buildInboundFrame(
      MessagingStack fromStack,
      MessagingStack toStack,
      Uint8List plaintext,
    ) async {
      final ciphertext = await fromStack.cryptoService.encrypt(
        SignalProtocolAddress(toStack.selfDeviceId, 1),
        plaintext,
      );
      final body = encodeCiphertextControlBody(ciphertext);
      return RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-1',
        destination: toStack.selfDeviceId,
        source: fromStack.selfDeviceId,
        priority: 0,
        createdAtMs: 0,
        expiresAtMs: 999999999999,
        payload: body,
      );
    }

    test('test_EARS_LOC_10_receive_from_blocked_peer_stores_nothing', () async {
      final alice = await newStack('alice', nextSuffix());
      final bob = await newStack('bob', nextSuffix());
      addTearDown(alice.dispose);
      addTearDown(bob.dispose);
      await establishMutualSessions(alice, bob);

      // Bob has blocked alice.
      await RelationshipRepository(bob.db)
          .upsert('alice', RelationshipState.blocked);
      final settings = LocationSettingsRepository(db: bob.db);
      await settings.writeGlobalEnabled(true);
      await settings.writePeerEnabled('alice', true);

      final frame = LocationShareFrame(
        latitudeE7: 10,
        longitudeE7: 10,
        capturedAtMs: 100,
      ).serialize();
      final wireFrame = await buildInboundFrame(alice, bob, frame);

      await bob.locationShareService.handleWireFrame(wireFrame);

      expect(await LocationFixRepository(db: bob.db).readFix('alice'), isNull);
    });

    test(
      'test_EARS_LOC_10_receive_when_policy_fails_deletes_existing_fix',
      () async {
        final alice = await newStack('alice', nextSuffix());
        final bob = await newStack('bob', nextSuffix());
        addTearDown(alice.dispose);
        addTearDown(bob.dispose);
        await establishMutualSessions(alice, bob);

        // Bob previously had a stored fix for alice.
        final fixes = LocationFixRepository(db: bob.db);
        await fixes.upsertFix(
          peerDeviceId: 'alice',
          latitude: 1,
          longitude: 1,
          capturedAtMs: 1,
          receivedAtMs: 1,
        );
        expect(await fixes.readFix('alice'), isNotNull);

        // Bob now blocks alice -- policy fails on the next inbound frame.
        await RelationshipRepository(bob.db)
            .upsert('alice', RelationshipState.blocked);
        final settings = LocationSettingsRepository(db: bob.db);
        await settings.writeGlobalEnabled(true);
        await settings.writePeerEnabled('alice', true);

        final frame = LocationShareFrame(
          latitudeE7: 20,
          longitudeE7: 20,
          capturedAtMs: 200,
        ).serialize();
        final wireFrame = await buildInboundFrame(alice, bob, frame);

        await bob.locationShareService.handleWireFrame(wireFrame);

        expect(await fixes.readFix('alice'), isNull);
      },
    );

    test(
      'test_EARS_LOC_11_second_fix_replaces_first_via_handleWireFrame',
      () async {
        final alice = await newStack('alice', nextSuffix());
        final bob = await newStack('bob', nextSuffix());
        addTearDown(alice.dispose);
        addTearDown(bob.dispose);
        await establishMutualSessions(alice, bob);
        await allowVisibility(bob, 'alice');

        final first = LocationShareFrame(
          latitudeE7: 10,
          longitudeE7: 10,
          capturedAtMs: 100,
        ).serialize();
        await bob.locationShareService
            .handleWireFrame(await buildInboundFrame(alice, bob, first));

        final second = LocationShareFrame(
          latitudeE7: 20,
          longitudeE7: 20,
          capturedAtMs: 200,
        ).serialize();
        await bob.locationShareService
            .handleWireFrame(await buildInboundFrame(alice, bob, second));

        final rows = await bob.db.select(bob.db.locationFixes).get();
        expect(rows, hasLength(1));
        expect(rows.single.latitude, closeTo(20 / 1e7, 1e-12));
        expect(rows.single.capturedAt, 200);
      },
    );

    test('test_EARS_LOC_12_undecryptable_frame_dropped', () async {
      final alice = await newStack('alice', nextSuffix());
      final bob = await newStack('bob', nextSuffix());
      final mallory = await newStack('mallory', nextSuffix());
      addTearDown(alice.dispose);
      addTearDown(bob.dispose);
      addTearDown(mallory.dispose);
      await allowVisibility(bob, 'mallory');

      // Matches `crypto_service_test.dart`'s own "Carol" pattern rather than
      // a bare `NoSessionException`: a genuinely undecryptable frame in
      // production is far more likely to be "the claimed sender's session
      // doesn't produce this ciphertext" (a MAC failure reached via a REAL
      // ratchet) than "no session at all," and reaching the ratchet (not
      // just a precondition check) is the stronger proof that this seam
      // never trusts `frame.source` as an identity claim (E06-B04).
      //
      // Full round trip alice<->bob so alice's session becomes STEADY STATE
      // (a `SignalMessage`, not a `PreKeySignalMessage` still carrying a
      // one-time-prekey id) -- a still-unconfirmed prekey message reaching
      // `SessionBuilder.processV3` under a second, different claimed address
      // hits prekey-id bookkeeping instead of the ratchet, which is a
      // weaker, noisier failure mode this test deliberately avoids.
      await alice.cryptoService.establishSession(
        SignalProtocolAddress('bob', 1),
        await bob.identityService.getLocalPreKeyBundle(),
      );
      final toBob1 = await alice.cryptoService.encrypt(
        SignalProtocolAddress('bob', 1),
        Uint8List.fromList([0]),
      );
      await bob.cryptoService.decrypt(SignalProtocolAddress('alice', 1), toBob1);
      final bobReply = await bob.cryptoService.encrypt(
        SignalProtocolAddress('alice', 1),
        Uint8List.fromList([0]),
      );
      await alice.cryptoService.decrypt(SignalProtocolAddress('bob', 1), bobReply);

      // The genuine, steady-state ciphertext alice sends to bob, carrying a
      // real LocationShareFrame -- encrypted against alice<->bob's own
      // ratchet chain.
      final frame = LocationShareFrame(
        latitudeE7: 1,
        longitudeE7: 1,
        capturedAtMs: 1,
      ).serialize();
      final realCiphertext = await alice.cryptoService.encrypt(
        SignalProtocolAddress('bob', 1),
        frame,
      );
      expect(realCiphertext, isA<SignalMessage>());

      // Bob also has a REAL, confirmed session keyed 'mallory' (the X3DH
      // responder side -- confirmed immediately on bob's own store from one
      // inbound message, no reply needed for this direction).
      await mallory.cryptoService.establishSession(
        SignalProtocolAddress('bob', 1),
        await bob.identityService.getLocalPreKeyBundle(),
      );
      final malloryToBob = await mallory.cryptoService.encrypt(
        SignalProtocolAddress('bob', 1),
        Uint8List.fromList([0]),
      );
      await bob.cryptoService
          .decrypt(SignalProtocolAddress('mallory', 1), malloryToBob);

      // Hand bob alice's genuine ciphertext, but claim it came from
      // mallory. Bob decrypts under his OWN real, established mallory
      // chain -- ratchet math runs (no prekey lookup at all, since this is
      // already a `SignalMessage`), and MAC verification fails because the
      // key derived from the mallory<->bob chain does not match the one
      // alice<->bob's chain actually used.
      final wireFrame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: 'pkt-x',
        destination: 'bob',
        source: 'mallory',
        priority: 0,
        createdAtMs: 0,
        expiresAtMs: 999999999999,
        payload: encodeCiphertextControlBody(realCiphertext),
      );

      await bob.locationShareService.handleWireFrame(wireFrame);

      expect(await LocationFixRepository(db: bob.db).readFix('mallory'), isNull);
    });

    test(
      'test_EARS_LOC_12_prekey_message_with_forged_source_accepted_as_TOFU_risk',
      () async {
        // E09-B11 (ADR-0003 addendum, 2026-09-04): this test used to assert
        // E09-B09's gate dropped this forgery and left alice's identity
        // slot untouched. That gate is gone -- proven not to close the
        // exploit (four sibling decrypt call sites share the same
        // unguarded identity store) and shown to regress legitimate
        // first-time location sharing between already-trusted peers. The
        // human accepted TOFU's risk app-wide instead of patching this one
        // call site. This test now documents that accepted outcome instead
        // of a prevention that never actually worked: bob's session with
        // "alice" gets silently established using mallory's identity key,
        // and the forged fix IS stored. This is intentional, tracked risk,
        // not a regression -- do not "fix" this test back without revisiting
        // the ADR-0003 addendum decision first.
        final bob = await newStack('bob', nextSuffix());
        final mallory = await newStack('mallory', nextSuffix());
        addTearDown(bob.dispose);
        addTearDown(mallory.dispose);

        await allowVisibility(bob, 'alice');

        // Bob has no prior session (and no stored identity) for alice.
        expect(
          await bob.signalStore
              .getIdentity(SignalProtocolAddress('alice', 1)),
          isNull,
        );

        // Mallory establishes a session claiming to be talking to "bob" and
        // encrypts a fabricated location fix. Since bob has never confirmed
        // a session back to mallory, this ciphertext is a fresh
        // `PreKeySignalMessage` (the X3DH responder path bob would have to
        // run on receipt).
        await mallory.cryptoService.establishSession(
          SignalProtocolAddress('bob', 1),
          await bob.identityService.getLocalPreKeyBundle(),
        );
        final forgedFrame = LocationShareFrame(
          latitudeE7: 511111111,
          longitudeE7: -1111111,
          capturedAtMs: 1000,
        ).serialize();
        final maliciousCiphertext = await mallory.cryptoService.encrypt(
          SignalProtocolAddress('bob', 1),
          forgedFrame,
        );
        expect(maliciousCiphertext, isA<PreKeySignalMessage>());

        // Wrapped with `source` spoofed to alice -- a trusted contact bob
        // has never actually talked to over Signal.
        final wireFrame = RelayPacketFrame(
          payloadType: PayloadType.control,
          packetId: 'pkt-forged',
          destination: 'bob',
          source: 'alice',
          priority: 0,
          createdAtMs: 0,
          expiresAtMs: 999999999999,
          payload: encodeCiphertextControlBody(maliciousCiphertext),
        );

        await bob.locationShareService.handleWireFrame(wireFrame);

        // The forged fix IS stored under alice's name -- TOFU accepted the
        // ciphertext as a legitimate first contact from "alice".
        final storedFix = await LocationFixRepository(
          db: bob.db,
        ).readFix('alice');
        expect(storedFix, isNotNull);
        expect(storedFix!.latitude, closeTo(51.1111111, 1e-6));

        // ...and alice's identity slot IS now poisoned with mallory's key --
        // the exact accepted risk. Any genuine future contact from the real
        // alice will decrypt under mallory's identity, not her own, until
        // something out-of-band (not built for v1) catches the mismatch.
        final poisonedIdentity = await bob.signalStore.getIdentity(
          SignalProtocolAddress('alice', 1),
        );
        final malloryIdentity = (await mallory.signalStore
                .getIdentityKeyPair())
            .getPublicKey();
        expect(poisonedIdentity, isNotNull);
        expect(poisonedIdentity!.serialize(), malloryIdentity.serialize());
      },
    );

    test('test_EARS_LOC_12_malformed_frame_dropped', () async {
      final alice = await newStack('alice', nextSuffix());
      final bob = await newStack('bob', nextSuffix());
      addTearDown(alice.dispose);
      addTearDown(bob.dispose);
      await establishMutualSessions(alice, bob);
      await allowVisibility(bob, 'alice');

      // A real, successfully-decryptable ciphertext -- but its plaintext is
      // NOT a valid LocationShareFrame encoding (wrong length).
      final wireFrame =
          await buildInboundFrame(alice, bob, Uint8List.fromList([9, 9, 9]));

      await bob.locationShareService.handleWireFrame(wireFrame);

      expect(await LocationFixRepository(db: bob.db).readFix('alice'), isNull);
    });

    test('test_EARS_LOC_12_future_captured_at_dropped', () async {
      final alice = await newStack('alice', nextSuffix());
      final bob = await newStack('bob', nextSuffix());
      addTearDown(alice.dispose);
      addTearDown(bob.dispose);
      await establishMutualSessions(alice, bob);
      await allowVisibility(bob, 'alice');

      final farFuture = DateTime.now()
          .add(const Duration(days: 3650))
          .millisecondsSinceEpoch;
      final frame = LocationShareFrame(
        latitudeE7: 1,
        longitudeE7: 1,
        capturedAtMs: farFuture,
      ).serialize();
      final wireFrame = await buildInboundFrame(alice, bob, frame);

      await bob.locationShareService.handleWireFrame(wireFrame);

      expect(await LocationFixRepository(db: bob.db).readFix('alice'), isNull);
    });
  });

  group('privacy sweep (E09-B02, EARS-LOC-5)', () {
    // `pruneFixesForNonVisiblePeers()`'s regression coverage (bug file
    // "Regression test (write it first)"): each test stores a fix by
    // writing directly to `location_fixes` -- deliberately WITHOUT ever
    // sending or receiving a wire frame -- so a peer that has since become
    // non-visible cannot possibly hit `handleWireFrame`'s own
    // delete-on-not-visible branch. That absence is the point: a test that
    // routed through a frame would pass on today's (pre-fix) code and prove
    // nothing about the sweep.

    test(
      'test_EARS_LOC_5_blocking_a_peer_deletes_their_stored_fix',
      () async {
        final bob = await newStack('bob', nextSuffix());
        addTearDown(bob.dispose);
        await allowVisibility(bob, 'alice');

        final fixes = LocationFixRepository(db: bob.db);
        await fixes.upsertFix(
          peerDeviceId: 'alice',
          latitude: 12.0,
          longitude: 34.0,
          capturedAtMs: 1000,
          receivedAtMs: 1000,
        );
        expect(await fixes.readFix('alice'), isNotNull);

        // Bob blocks alice -- no frame ever arrives afterwards.
        await RelationshipRepository(bob.db)
            .upsert('alice', RelationshipState.blocked);

        final service = buildService(bob);
        await service.pruneFixesForNonVisiblePeers();

        expect(await fixes.readFix('alice'), isNull);
      },
    );

    test(
      'test_EARS_LOC_5_trusted_to_unknown_deletes_their_stored_fix',
      () async {
        final bob = await newStack('bob', nextSuffix());
        addTearDown(bob.dispose);
        await allowVisibility(bob, 'alice');

        final fixes = LocationFixRepository(db: bob.db);
        await fixes.upsertFix(
          peerDeviceId: 'alice',
          latitude: 12.0,
          longitude: 34.0,
          capturedAtMs: 1000,
          receivedAtMs: 1000,
        );
        expect(await fixes.readFix('alice'), isNotNull);

        // Relationship drops from trusted to unknown (e.g. an unfriend) --
        // no frame ever arrives afterwards.
        await RelationshipRepository(bob.db)
            .upsert('alice', RelationshipState.unknown);

        final service = buildService(bob);
        await service.pruneFixesForNonVisiblePeers();

        expect(await fixes.readFix('alice'), isNull);
      },
    );

    test(
      'test_EARS_LOC_5_global_sharing_off_deletes_their_stored_fix',
      () async {
        final bob = await newStack('bob', nextSuffix());
        addTearDown(bob.dispose);
        await allowVisibility(bob, 'alice');

        final fixes = LocationFixRepository(db: bob.db);
        await fixes.upsertFix(
          peerDeviceId: 'alice',
          latitude: 12.0,
          longitude: 34.0,
          capturedAtMs: 1000,
          receivedAtMs: 1000,
        );
        expect(await fixes.readFix('alice'), isNotNull);

        // The user turns global location sharing off entirely -- no frame
        // ever arrives afterwards.
        final settings = LocationSettingsRepository(db: bob.db);
        await settings.writeGlobalEnabled(false);

        final service = buildService(bob);
        await service.pruneFixesForNonVisiblePeers();

        expect(await fixes.readFix('alice'), isNull);
      },
    );

    test(
      'test_EARS_LOC_5_sweep_leaves_visible_peers_fix_untouched',
      () async {
        final bob = await newStack('bob', nextSuffix());
        addTearDown(bob.dispose);
        await allowVisibility(bob, 'alice');

        final fixes = LocationFixRepository(db: bob.db);
        await fixes.upsertFix(
          peerDeviceId: 'alice',
          latitude: 12.0,
          longitude: 34.0,
          capturedAtMs: 1000,
          receivedAtMs: 1000,
        );

        final service = buildService(bob);
        await service.pruneFixesForNonVisiblePeers();

        // Alice is still fully visible -- the sweep must not delete a fix
        // whose policy still holds.
        expect(await fixes.readFix('alice'), isNotNull);
      },
    );
  });
}
