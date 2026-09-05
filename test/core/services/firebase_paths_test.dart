// E11-T01 — FirebasePaths tests (EARS-FB-3).
//
// Hard-coded expected strings, not "call the function twice" — the task's
// own §6 Risks names this explicitly: the produced paths are live data,
// already written by devices in the field, and must stay byte-identical to
// what `FirebaseMetadataService`/`SyncCursorService` produced before this
// task existed.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/services/firebase_paths.dart';

void main() {
  test(
    'test_EARS_FB_3_device_path_matches_firebase_metadata_service_original',
    () {
      // Byte-identical to FirebaseMetadataService.writeDeviceMetadata's
      // original inline path: 'users/$uid/devices/$deviceId'.
      expect(
        FirebasePaths.device('uid-123', 'device-abc'),
        'users/uid-123/devices/device-abc',
      );
    },
  );

  test(
    'test_EARS_FB_3_sync_cursor_path_matches_sync_cursor_service_original',
    () {
      // Byte-identical to SyncCursorService._cursorPath's original inline
      // path: 'users/$uid/sync_cursors/$writerDeviceId/$conversationId/$aboutDeviceId'.
      // Argument order preserved exactly: writer, conversation, about.
      expect(
        FirebasePaths.syncCursor(
          'uid-123',
          'writer-device',
          'conv-1',
          'about-device',
        ),
        'users/uid-123/sync_cursors/writer-device/conv-1/about-device',
      );
    },
  );

  test(
    'test_EARS_FB_3_sync_cursor_argument_order_is_not_transposable',
    () {
      // The writer/about argument order is easy to transpose and the bug is
      // silent (task §6 Risks) -- assert the two positions are genuinely
      // distinguishable, not accidentally symmetric.
      final path = FirebasePaths.syncCursor(
        'uid-123',
        'device-A',
        'conv-1',
        'device-B',
      );
      expect(path, 'users/uid-123/sync_cursors/device-A/conv-1/device-B');
      expect(
        path,
        isNot('users/uid-123/sync_cursors/device-B/conv-1/device-A'),
      );
    },
  );
}
