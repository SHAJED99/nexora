package com.nexora.nexora

import android.content.Context
import com.nexora.nexora.background.BackgroundApiHost
import com.nexora.nexora.background.ForegroundMeshService
import com.nexora.nexora.notifications.NotificationApiHost
import com.nexora.nexora.transport.TransportApiHost
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * E04-T03a/T03b: wires the Pigeon transport host (ADR-0004) into the
 * Flutter engine — additive to whatever else `configureFlutterEngine`
 * already does (Firebase plugins register themselves via their own
 * `FlutterPlugin`/`GeneratedPluginRegistrant` hookup, untouched here).
 *
 * E04-T03b adds `onRequestPermissionsResult`: `BluetoothTransport` needs an
 * `Activity` to request the runtime Bluetooth permissions (FR-PLAT-002),
 * and the result only reaches it by the host `Activity` forwarding its own
 * callback — there's no other path for a non-Fragment permission request.
 *
 * E10-T01 adds `NotificationApiHost` the same way, with its own distinct
 * permission request code (`NotificationApiHost.REQUEST_CODE`, 4300) so the
 * two permission flows never collide.
 *
 * E10-T08 (ADR-0007 option 1) additionally: caches this Activity's engine
 * under [ForegroundMeshService.ENGINE_ID] and overrides
 * [shouldDestroyEngineWithHost]/[cleanUpFlutterEngine] so that while
 * `ForegroundMeshService` is holding the engine, Activity destruction (the
 * app being swiped away) does NOT destroy the Dart isolate or detach the
 * Pigeon hosts `MessagingCoordinator`'s tick depends on
 * (`TransportApiHost.send` in particular) — the whole point of ADR-0007's
 * chosen option is that nothing about the messaging path changes between
 * foreground and background.
 */
class MainActivity : FlutterActivity() {
  private var transportApiHost: TransportApiHost? = null
  private var notificationApiHost: NotificationApiHost? = null
  private var backgroundApiHost: BackgroundApiHost? = null

  /**
   * Reuses the engine `ForegroundMeshService` is holding, if one is
   * cached, instead of letting `FlutterActivity` create a fresh one — e.g.
   * the user re-opens the app while the service is still alive in the
   * background. Falls back to the default behaviour (create a new engine)
   * otherwise.
   */
  override fun provideFlutterEngine(context: Context): FlutterEngine? {
    return FlutterEngineCache.getInstance().get(ForegroundMeshService.ENGINE_ID)
        ?: super.provideFlutterEngine(context)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    val messenger = flutterEngine.dartExecutor.binaryMessenger

    val host = TransportApiHost(messenger, this)
    host.attach(messenger)
    transportApiHost = host

    val notificationHost = NotificationApiHost(messenger, this)
    notificationHost.attach(messenger)
    notificationApiHost = notificationHost

    val backgroundHost = BackgroundApiHost(messenger, applicationContext)
    backgroundHost.attach(messenger)
    backgroundApiHost = backgroundHost

    // Cache under a known id (task §3) so ForegroundMeshService can find
    // this same engine, and so a later provideFlutterEngine call above
    // reuses it instead of creating a second one.
    FlutterEngineCache.getInstance().put(ForegroundMeshService.ENGINE_ID, flutterEngine)
  }

  /**
   * The actual engine-retention lever (task §6's top risk): while the
   * service is running, this Activity's own destruction must not destroy
   * the engine it shares with that service.
   */
  override fun shouldDestroyEngineWithHost(): Boolean = !ForegroundMeshService.isRunning

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    if (ForegroundMeshService.isRunning) {
      // Leave every Pigeon host attached -- the retained engine (held by
      // the service) keeps driving MessagingCoordinator's tick through the
      // exact same Transport/Notification/Background hosts it always
      // used, per this class's own header. Only this Activity's own
      // plugin/view bindings are torn down by the super call; the engine
      // and its channel handlers live on.
      super.cleanUpFlutterEngine(flutterEngine)
      return
    }
    transportApiHost?.detach(flutterEngine.dartExecutor.binaryMessenger)
    transportApiHost = null
    notificationApiHost?.detach(flutterEngine.dartExecutor.binaryMessenger)
    notificationApiHost = null
    backgroundApiHost?.detach(flutterEngine.dartExecutor.binaryMessenger)
    backgroundApiHost = null
    FlutterEngineCache.getInstance().remove(ForegroundMeshService.ENGINE_ID)
    super.cleanUpFlutterEngine(flutterEngine)
  }

  override fun onRequestPermissionsResult(
      requestCode: Int,
      permissions: Array<out String>,
      grantResults: IntArray,
  ) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    transportApiHost?.onRequestPermissionsResult(requestCode, grantResults)
    notificationApiHost?.onRequestPermissionsResult(requestCode, grantResults)
  }
}
