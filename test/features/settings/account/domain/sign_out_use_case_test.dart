// E15-T01 -- SignOutUseCase: the ordering contract (teardown -> wipe ->
// auth clear) and each half's failure isolation. `LocalDataWipeService`'s
// own file-level erase is proven independently in
// test/core/session/local_data_wipe_service_test.dart; this file seams both
// collaborators via call-counters/recorded order (never `fail()` inside a
// broad catch -- swallowed and proves nothing, `L-testing`), never real
// Firebase/Google platform channels.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart';
import 'package:nexora/core/session/local_data_wipe_service.dart';
import 'package:nexora/features/settings/account/domain/sign_out_use_case.dart';

class _RecordingWipeService extends LocalDataWipeService {
  _RecordingWipeService(this._calls, {Object? wipeError})
      // Named param (`wipeError`) is the public constructor API; the
      // private field below can't share that name.
      : _wipeError = wipeError; // ignore: prefer_initializing_formals

  final List<String> _calls;
  final Object? _wipeError;
  int wipeCallCount = 0;

  @override
  Future<void> wipe() async {
    wipeCallCount++;
    _calls.add('wipe');
    final error = _wipeError;
    if (error != null) throw error;
  }
}

class _RecordingAuthService extends GoogleAuthService {
  _RecordingAuthService(this._calls, {Object? signOutError})
      // Same reasoning as `_RecordingWipeService` above.
      : _signOutError = signOutError; // ignore: prefer_initializing_formals

  final List<String> _calls;
  final Object? _signOutError;
  int signOutCallCount = 0;

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    _calls.add('authClear');
    final error = _signOutError;
    if (error != null) throw error;
  }
}

void main() {
  test(
    'test_EARS_AUTH_5_wipe_clears_auth_session',
    () async {
      final calls = <String>[];
      final wipeService = _RecordingWipeService(calls);
      final authService = _RecordingAuthService(calls);
      final useCase = SignOutUseCase(
        wipeService: wipeService,
        authService: authService,
      );

      await useCase.call();

      expect(wipeService.wipeCallCount, 1);
      expect(authService.signOutCallCount, 1);
    },
  );

  test(
    'test_EARS_AUTH_5_auth_failure_does_not_prevent_local_erase',
    () async {
      final calls = <String>[];
      final wipeService = _RecordingWipeService(calls);
      final authService = _RecordingAuthService(
        calls,
        signOutError: const AppFailure('auth.google_sign_in_failed'),
      );
      final useCase = SignOutUseCase(
        wipeService: wipeService,
        authService: authService,
      );

      // Must not throw -- the auth clear is best-effort and never fails
      // this call.
      await useCase.call();

      expect(wipeService.wipeCallCount, 1);
      expect(authService.signOutCallCount, 1);
    },
  );

  test(
    'test_EARS_AUTH_5_wipe_failure_propagates_as_app_failure',
    () async {
      final calls = <String>[];
      final wipeService = _RecordingWipeService(
        calls,
        wipeError: const AppFailure('session.local_wipe_failed'),
      );
      final authService = _RecordingAuthService(calls);
      final useCase = SignOutUseCase(
        wipeService: wipeService,
        authService: authService,
      );

      await expectLater(useCase.call(), throwsA(isA<AppFailure>()));

      // The wipe failure must stop the call before the auth clear runs --
      // otherwise a device could report "signed out" while its local data
      // still failed to erase.
      expect(authService.signOutCallCount, 0);
    },
  );

  test(
    'test_EARS_AUTH_5_teardown_runs_before_wipe_and_wipe_before_auth_clear',
    () async {
      final calls = <String>[];
      var teardownCalls = 0;
      final wipeService = _RecordingWipeService(calls);
      final authService = _RecordingAuthService(calls);
      final useCase = SignOutUseCase(
        wipeService: wipeService,
        authService: authService,
        teardown: () async {
          teardownCalls++;
          calls.add('teardown');
        },
      );

      await useCase.call();

      expect(teardownCalls, 1);
      expect(calls, ['teardown', 'wipe', 'authClear']);
    },
  );

  // E15-T12, Q-SEC-009(b): `revoke` is called exactly once, after the wipe,
  // before the auth clear.
  test(
    'test_Q_SEC_009_revoke_is_called_exactly_once_after_the_wipe',
    () async {
      final calls = <String>[];
      var revokeCalls = 0;
      final wipeService = _RecordingWipeService(calls);
      final authService = _RecordingAuthService(calls);
      final useCase = SignOutUseCase(
        wipeService: wipeService,
        authService: authService,
        revoke: () async {
          revokeCalls++;
          calls.add('revoke');
        },
      );

      await useCase.call();

      expect(revokeCalls, 1);
      expect(calls, ['wipe', 'revoke', 'authClear']);
    },
  );

  // A throwing `revoke` must not propagate and must not prevent `call()`
  // from completing (or from still running the auth clear) -- the same
  // best-effort contract the existing auth-clear catch already proves
  // above.
  test(
    'test_Q_SEC_009_a_throwing_revoke_does_not_propagate_or_block_call',
    () async {
      final calls = <String>[];
      final wipeService = _RecordingWipeService(calls);
      final authService = _RecordingAuthService(calls);
      final useCase = SignOutUseCase(
        wipeService: wipeService,
        authService: authService,
        revoke: () async {
          throw StateError('revoke boom');
        },
      );

      // Must not throw.
      await useCase.call();

      expect(wipeService.wipeCallCount, 1);
      expect(authService.signOutCallCount, 1);
    },
  );

  // The default (no `revoke` closure given) behaves exactly as today: a
  // no-op, `call()` succeeds identically.
  test(
    'test_Q_SEC_009_default_no_revoke_closure_behaves_as_a_noop',
    () async {
      final calls = <String>[];
      final wipeService = _RecordingWipeService(calls);
      final authService = _RecordingAuthService(calls);
      final useCase = SignOutUseCase(
        wipeService: wipeService,
        authService: authService,
      );

      await useCase.call();

      expect(calls, ['wipe', 'authClear']);
      expect(wipeService.wipeCallCount, 1);
      expect(authService.signOutCallCount, 1);
    },
  );
}
