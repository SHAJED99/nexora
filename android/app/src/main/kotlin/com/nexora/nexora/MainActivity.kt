package com.nexora.nexora

import android.content.Context
import android.content.Intent
import com.nexora.nexora.background.BackgroundApiHost
import com.nexora.nexora.background.ForegroundMeshService
import com.nexora.nexora.notifications.NotificationApiHost
import com.nexora.nexora.notifications.NotificationCategory
import com.nexora.nexora.transport.TransportApiHost
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.BinaryMessenger

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
 *
 * E10-B04 fix: because `cleanUpFlutterEngine` deliberately skips `detach()`
 * while the service is running (the paragraph above), a later
 * `configureFlutterEngine` call that reattaches onto that same cached
 * engine cannot rely on this Activity instance's own fields to know a
 * previous host set is still live — the previous instance that owned them
 * was already destroyed. [attachedHosts] survives across `MainActivity`
 * instances for exactly that reason: it lets `configureFlutterEngine`
 * find and retire whatever host set is still attached to the engine
 * being reused, via the existing `detach()` methods, before constructing a
 * new one. Without this, every close/reopen cycle while the service runs
 * leaked a `PowerStateMonitor` + 4 broadcast receivers (instance-scoped
 * `registered` guard, useless across instances) and the destroyed
 * Activity itself (retained via `TransportApiHost`/`NotificationApiHost`'s
 * strong `Activity` references).
 */
class MainActivity : FlutterActivity() {
  /**
   * One Pigeon host of each kind, attached together and detached together.
   * Captures its own `BinaryMessenger` so a later retirement always detaches
   * against the messenger it was actually attached to.
   */
  private class HostSet(
      val messenger: BinaryMessenger,
      val transportApiHost: TransportApiHost,
      val notificationApiHost: NotificationApiHost,
      val backgroundApiHost: BackgroundApiHost,
  ) {
    fun detach() {
      transportApiHost.detach(messenger)
      notificationApiHost.detach(messenger)
      backgroundApiHost.detach(messenger)
    }
  }

  companion object {
    /**
     * The host set currently attached to the cached engine, if any. Lives on
     * the companion object (not an Activity field) so it survives the
     * Activity destruction that `cleanUpFlutterEngine`'s `isRunning` guard
     * deliberately leaves the engine attached through — see this class's
     * header (E10-B04).
     */
    private var attachedHosts: HostSet? = null
  }

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

    // E10-B04: retire whatever host set is still attached (from a previous,
    // already-destroyed Activity instance that reused this same cached
    // engine) before constructing a new one. cleanUpFlutterEngine skips
    // detach() while the service is running, precisely so this engine and
    // its hosts keep driving MessagingCoordinator's tick -- which means this
    // is the only place a stale set can ever be retired. Detaching first and
    // reattaching immediately after, both synchronously on this thread,
    // means ForegroundMeshService.eventsApi (set inside BackgroundApiHost
    // .attach/.detach) is never visibly null to any other thread: no
    // suspension point separates the detach() below from the attach() a few
    // lines later.
    attachedHosts?.detach()
    attachedHosts = null

    val host = TransportApiHost(messenger, this)
    host.attach(messenger)
    transportApiHost = host

    val notificationHost = NotificationApiHost(messenger, this)
    notificationHost.attach(messenger)
    notificationApiHost = notificationHost

    val backgroundHost = BackgroundApiHost(messenger, applicationContext)
    backgroundHost.attach(messenger)
    backgroundApiHost = backgroundHost

    attachedHosts = HostSet(messenger, host, notificationHost, backgroundHost)

    // Cache under a known id (task §3) so ForegroundMeshService can find
    // this same engine, and so a later provideFlutterEngine call above
    // reuses it instead of creating a second one.
    FlutterEngineCache.getInstance().put(ForegroundMeshService.ENGINE_ID, flutterEngine)

    // E10-B07: the cold-start case -- a notification tap that launches a
    // fresh process delivers its extras on THIS launch intent, not via
    // onNewIntent (that only fires for an already-running singleTop
    // instance). notificationApiHost is now attached (just above), so the
    // tap can be delivered immediately rather than lost.
    handleNotificationTapIntent(intent)
  }

  /**
   * E10-B07: reads [NotificationApiHost.EXTRA_NOTIFICATION_ID]/
   * [NotificationApiHost.EXTRA_NOTIFICATION_CATEGORY] off [intent] (if
   * present) and forwards the tap to Dart via [notificationApiHost].
   * Called from both [onNewIntent] (app already running, `singleTop`) and
   * the end of [configureFlutterEngine] (a cold start via the tap alone).
   */
  private fun handleNotificationTapIntent(intent: Intent?) {
    val id = intent?.getLongExtra(NotificationApiHost.EXTRA_NOTIFICATION_ID, -1L) ?: -1L
    if (id < 0) return
    val categoryName =
        intent?.getStringExtra(NotificationApiHost.EXTRA_NOTIFICATION_CATEGORY) ?: return
    val category =
        NotificationCategory.values().firstOrNull { it.name == categoryName } ?: return
    notificationApiHost?.notifyTapped(id, category)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    // Keep getIntent() consistent with the intent actually being handled --
    // matches Android's own documented `singleTop` convention.
    setIntent(intent)
    handleNotificationTapIntent(intent)
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
    // E10-B04: this Activity's own set (if it is still the one recorded as
    // attached) is now fully detached above -- clear the companion-object
    // record so a later configureFlutterEngine on a freshly created engine
    // never tries to detach an already-detached set.
    attachedHosts = null
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
