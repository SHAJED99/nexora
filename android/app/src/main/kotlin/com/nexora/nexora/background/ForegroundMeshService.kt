package com.nexora.nexora.background

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.nexora.nexora.R
import com.nexora.nexora.notifications.NotificationCategory
import com.nexora.nexora.notifications.NotificationChannels
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * ADR-0007 option 1: a foreground `Service` that keeps the app process
 * alive and legal in the background so `MessagingCoordinator`'s existing
 * `Timer.periodic` (E06-T06) keeps firing unchanged. This service adds NO
 * scheduler, `WorkManager` job or isolate of its own (task §2/§4) — its
 * only job is to `startForeground()` with the mandatory ongoing
 * notification and hold the process at foreground priority. The Dart-side
 * `FlutterEngine` that actually drives the tick is created and owned by
 * `MainActivity`; this service never constructs one, only looks up the one
 * `MainActivity` cached under [ENGINE_ID] (task §3 — no second composition
 * root).
 *
 * **Known limitation, recorded honestly rather than silently claimed away**
 * (task §6, ADR-0007 §S3 builder note): if the *entire process* has been
 * killed and Android restarts this service under `START_STICKY` (or the
 * `BootReceiver` starts it after a device reboot), there is no cached
 * `FlutterEngine` to find — the Dart isolate driving `MessagingCoordinator`
 * is not running until the user next opens the app. This service still
 * does its own job in that case (raises process priority, shows the
 * notification, satisfies the "service SHALL be re-created" half of
 * EARS-PLAT-8/EARS-PLAT-10) but cannot emit a `ServiceState` event to a
 * Dart side that does not exist yet. Reviving the full messaging stack
 * headlessly before the user opens the app would require a Dart entrypoint
 * change to `lib/app/main.dart`, which is outside this task's `files:`
 * fence.
 */
class ForegroundMeshService : Service() {

  companion object {
    /** The `FlutterEngineCache` id `MainActivity` caches its engine under
     * (task §3: "ensures the engine is cached under a known id"). */
    const val ENGINE_ID = "nexora_background_engine"

    private const val NOTIFICATION_ID = 1001

    /**
     * Whether the service is currently alive. A plain in-process flag is
     * sufficient — `BackgroundApiHost.isServiceRunning()` and
     * `MainActivity.shouldDestroyEngineWithHost()` both run in the same
     * process as this service and need only ask "is an instance of me
     * alive right now", never a cross-process query.
     */
    @Volatile
    var isRunning: Boolean = false
      private set

    /**
     * Set by `BackgroundApiHost.attach`/`detach` so this service can push
     * `ServiceState` events to Dart without needing its own reference to
     * `MainActivity` (there may not be an Activity at all while
     * backgrounded — that is the entire point of this service existing).
     * Null whenever no engine is currently attached to receive events.
     */
    @Volatile
    var eventsApi: BackgroundEventsApi? = null

    /**
     * Set by [com.nexora.nexora.background.BackgroundApiHost.stopService]
     * immediately before it calls `Context.stopService()`, so
     * [onDestroy] can tell a caller-initiated stop (EARS-PLAT-9: report
     * `stopped`) apart from the OS killing this service out from under the
     * app (EARS-PLAT-8: report `stoppedBySystem`) — both paths land in the
     * same `onDestroy()` callback with nothing else to distinguish them.
     * Reset to `false` the moment [onDestroy] consumes it, so a *future*
     * unexpected kill is not misreported as expected.
     */
    @Volatile
    var expectedStop: Boolean = false
  }

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private var retainedEngine: FlutterEngine? = null

  override fun onCreate() {
    super.onCreate()
    isRunning = true

    // The engine `MainActivity.configureFlutterEngine` already cached — this
    // service does not create one (task §3's "no second composition root").
    // Absent only in the known-limitation case documented on this class.
    retainedEngine = FlutterEngineCache.getInstance().get(ENGINE_ID)

    startAsForeground()
    emitState(ServiceState.RUNNING)
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    // Re-entering onStartCommand (e.g. a second startForegroundService()
    // call while already running) is idempotent: onCreate already put us
    // in the running state, so there is nothing further to do here beyond
    // re-asserting the foreground notification, which startForeground is
    // safe to call again with.
    startAsForeground()
    // START_STICKY: the OS re-creates this service after a low-memory kill
    // (EARS-PLAT-8) — task §5's contract for `onStartCommand`.
    return START_STICKY
  }

  override fun onDestroy() {
    isRunning = false
    val wasExpected = expectedStop
    expectedStop = false
    emitState(if (wasExpected) ServiceState.STOPPED else ServiceState.STOPPED_BY_SYSTEM)
    scope.cancel()
    retainedEngine = null
    super.onDestroy()
  }

  override fun onBind(intent: Intent?): IBinder? = null

  private fun emitState(state: ServiceState) {
    val api = eventsApi ?: return
    scope.launch { api.onServiceStateChanged(state) }
  }

  /**
   * `startForeground()`, declaring the `connectedDevice` service type on
   * API 29+ (ADR-0007 §S1: `connectedDevice`, matching the manifest's
   * `android:foregroundServiceType`) — API 34 enforces that the declared
   * type match what the service actually does (task §6), so the type is
   * passed explicitly rather than relying on the manifest declaration
   * alone.
   */
  private fun startAsForeground() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      startForeground(
          NOTIFICATION_ID,
          buildNotification(),
          ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
      )
    } else {
      startForeground(NOTIFICATION_ID, buildNotification())
    }
  }

  /**
   * The mandatory ongoing notification (Android requires one for a
   * foreground service). Copy is explicitly **provisional** (ADR-0007 §S4,
   * task §3/§9) — the plainest possible string, no design contract behind
   * it yet (`OQ-E10-1`).
   */
  private fun buildNotification(): Notification {
    // `E10-T01`'s `NotificationChannels` already created the
    // `backgroundService` channel (LOW importance, no sound/badge) at
    // engine attach, so this service adds no channel plumbing of its own
    // (task §2) — it only targets the channel id that class already owns.
    val channelId = NotificationChannels.channelId(NotificationCategory.BACKGROUND_SERVICE)
    return NotificationCompat.Builder(this, channelId)
        .setContentTitle("Nexora is running")
        .setContentText("Nexora is running — relaying messages")
        .setSmallIcon(R.mipmap.ic_launcher)
        .setOngoing(true)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .build()
  }
}
