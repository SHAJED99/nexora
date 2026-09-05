package com.nexora.nexora.background

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Native Kotlin host for the Pigeon background-service boundary (ADR-0004,
 * ADR-0007, FR-PLAT-001/002/003). Implements the Dart-facing `BackgroundApi`
 * (host calls) and owns the `BackgroundEventsApi` (Kotlin -> Dart events)
 * used to report service-state changes.
 *
 * Persists the single "messaging active" flag `BootReceiver` reads after a
 * reboot (ADR-0007 §S3: "reuse whatever persisted flag already gates the
 * foreground-path start, do not invent a second one"). Nothing in this
 * codebase persisted such a flag before this task — `E10-T10` (which will
 * decide *when* to call [startService]) has not been built yet — so this
 * host's own [PREFS_NAME]/[KEY_MESSAGING_ACTIVE] pair, written on every
 * successful [startService]/[stopService] call, IS that flag: the one and
 * only place "was the foreground path started" is recorded, read by both
 * this host and [com.nexora.nexora.background.BootReceiver]. Logged as a
 * deviation in the task's own self-review rather than left implicit.
 */
class BackgroundApiHost(
    binaryMessenger: BinaryMessenger,
    private val context: Context,
) : BackgroundApi {

  companion object {
    private const val PREFS_NAME = "nexora_background_prefs"
    private const val KEY_MESSAGING_ACTIVE = "messaging_active"

    /** Read by `BootReceiver` on `BOOT_COMPLETED` — see this class's
     * header for why this is the one persisted flag, not a second one. */
    fun wasMessagingActive(context: Context): Boolean =
        context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_MESSAGING_ACTIVE, false)

    private fun setMessagingActive(context: Context, active: Boolean) {
      context
          .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
          .edit()
          .putBoolean(KEY_MESSAGING_ACTIVE, active)
          .apply()
    }
  }

  private val eventsApi = BackgroundEventsApi(binaryMessenger)

  /** E10-T09: reads and observes Doze/Battery-Saver/background-restriction/
   * screen-lock (task §3). Registered/unregistered in [attach]/[detach] —
   * this class's own header explains why no manifest change is needed. */
  private val powerStateMonitor = PowerStateMonitor(context)

  /** `BackgroundEventsApi.onPowerStateChanged` is a suspend function
   * (Pigeon-generated); this scope is this host's own — cancelled in
   * [detach] so a torn-down engine's binary messenger never receives a
   * send from a coroutine started before detach (task §6). */
  private var eventsScope: CoroutineScope? = null

  /** Registers this host to handle `BackgroundApi` calls from Dart, and
   * lets [ForegroundMeshService] push state events through it. */
  fun attach(messenger: BinaryMessenger) {
    BackgroundApi.setUp(messenger, this)
    ForegroundMeshService.eventsApi = eventsApi

    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    eventsScope = scope
    powerStateMonitor.onStateChanged = { state ->
      scope.launch { eventsApi.onPowerStateChanged(state) }
    }
    powerStateMonitor.register()
  }

  /** Unregisters this host — call from `cleanUpFlutterEngine` (but NOT
   * while the service is still holding this engine — see
   * `MainActivity.cleanUpFlutterEngine`'s own guard) so a torn-down
   * engine's binary messenger doesn't keep a dangling handler registered. */
  fun detach(messenger: BinaryMessenger) {
    BackgroundApi.setUp(messenger, null)
    if (ForegroundMeshService.eventsApi === eventsApi) {
      ForegroundMeshService.eventsApi = null
    }
    powerStateMonitor.unregister()
    powerStateMonitor.onStateChanged = null
    eventsScope?.cancel()
    eventsScope = null
  }

  /**
   * Starts [ForegroundMeshService]. Idempotent (task §6): a second call
   * while already running reports success without starting anything twice.
   * Fails loudly — `false`, never a thrown exception across the Pigeon
   * boundary — when the platform refuses (Android 12+ background-start
   * restriction is the expected case; task §6).
   */
  override fun startService(): Boolean {
    if (ForegroundMeshService.isRunning) return true

    return try {
      val intent = Intent(context, ForegroundMeshService::class.java)
      ContextCompat.startForegroundService(context, intent)
      setMessagingActive(context, true)
      true
    } catch (e: Exception) {
      // Covers `ForegroundServiceStartNotAllowedException` (API 31+, when
      // Android refuses a background-originated start) and any other
      // platform refusal — reported as a refusal, never propagated as an
      // exception across the Pigeon boundary.
      false
    }
  }

  /**
   * Stops the service and removes the ongoing notification. Idempotent:
   * calling this when the service is not running is a harmless no-op
   * (`Context.stopService` on a non-running service simply returns
   * `false`, which this method does not need to inspect).
   */
  override fun stopService() {
    setMessagingActive(context, false)
    // Told to ForegroundMeshService.onDestroy before stopService() so it
    // can tell this caller-initiated stop apart from the OS killing the
    // service out from under the app -- see ForegroundMeshService's own
    // `expectedStop` doc for why both land in the same onDestroy callback.
    ForegroundMeshService.expectedStop = true
    context.stopService(Intent(context, ForegroundMeshService::class.java))
  }

  override fun isServiceRunning(): Boolean = ForegroundMeshService.isRunning

  /** E10-T09: a one-shot snapshot, never a thrown exception (task §5/§6). */
  override fun powerState(): PowerState = powerStateMonitor.currentState()
}
