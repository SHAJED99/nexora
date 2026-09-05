package com.nexora.nexora.background

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PowerManager
import androidx.core.content.ContextCompat

/**
 * Reads and observes the Android power-state signals `E10-T10` needs to
 * adapt its cadence to (task §2/§3, EARS-PLAT-10/11): Doze, Battery Saver,
 * per-app background restriction, the battery-optimisation exemption, and
 * screen lock. **Reports facts only** — nothing here changes app behaviour
 * (task §4); `BackgroundApiHost` forwards what this class observes,
 * unchanged, and nothing reacts to it yet.
 *
 * Every read defaults to `false` on an API level below the one that
 * introduced the signal (task §6) — the permissive reading, since a
 * spurious "true" would make `E10-T10` throttle a device that is wide
 * awake, never a thrown exception.
 *
 * Registered with `RECEIVER_NOT_EXPORTED` — every action here is a
 * protected system broadcast, so no other app can spoof it; the same
 * posture `BluetoothTransport.registerReceiverIfNeeded` already uses for
 * `ACTION_FOUND`.
 */
class PowerStateMonitor(private val context: Context) {

  /**
   * Invoked on every observed transition with a freshly-read snapshot.
   * `BackgroundApiHost` is responsible for de-duplicating consecutive equal
   * states before forwarding to Dart (task §5/§6 — broadcast storms); this
   * class does its own cheap de-duplication first so a `SCREEN_ON`/
   * `SCREEN_OFF` storm doesn't even reach that layer when nothing actually
   * changed.
   */
  var onStateChanged: ((PowerState) -> Unit)? = null

  private val receivers = mutableListOf<BroadcastReceiver>()
  private var registered = false
  private var lastObserved: PowerState? = null

  /** One-shot snapshot for `BackgroundApiHost.powerState()`. */
  fun currentState(): PowerState {
    val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
    val activityManager =
        context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
    val keyguardManager =
        context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager

    val deviceIdle =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          powerManager?.isDeviceIdleMode ?: false
        } else {
          false
        }
    val powerSaveMode = powerManager?.isPowerSaveMode ?: false
    val backgroundRestricted =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
          activityManager?.isBackgroundRestricted ?: false
        } else {
          false
        }
    val ignoringBatteryOptimizations =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
        } else {
          false
        }
    val screenLocked = keyguardManager?.isKeyguardLocked ?: false

    return PowerState(
        deviceIdle = deviceIdle,
        powerSaveMode = powerSaveMode,
        backgroundRestricted = backgroundRestricted,
        ignoringBatteryOptimizations = ignoringBatteryOptimizations,
        screenLocked = screenLocked,
    )
  }

  /**
   * Registers the four broadcast receivers (task §3/§7). Safe to call more
   * than once — a second call is a no-op so `BackgroundApiHost.attach`
   * cannot double-register (and therefore double-emit) across a hot
   * restart.
   */
  fun register() {
    if (registered) return
    registered = true

    // Doze.
    registerFor(IntentFilter(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED))
    // Battery Saver.
    registerFor(IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED))
    // Screen lock (on/off; ACTION_USER_PRESENT below covers the unlock).
    registerFor(
        IntentFilter().apply {
          addAction(Intent.ACTION_SCREEN_ON)
          addAction(Intent.ACTION_SCREEN_OFF)
        },
    )
    registerFor(IntentFilter(Intent.ACTION_USER_PRESENT))
  }

  /**
   * Unregisters every receiver registered by [register] — must be called
   * from `BackgroundApiHost.detach` or every hot restart leaks one
   * (task §6).
   */
  fun unregister() {
    if (!registered) return
    registered = false
    receivers.forEach {
      try {
        context.unregisterReceiver(it)
      } catch (e: IllegalArgumentException) {
        // Not registered -- nothing to clean up.
      }
    }
    receivers.clear()
    lastObserved = null
  }

  private fun registerFor(filter: IntentFilter) {
    val receiver =
        object : BroadcastReceiver() {
          override fun onReceive(receivedContext: Context?, intent: Intent?) {
            emitIfChanged()
          }
        }
    ContextCompat.registerReceiver(context, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
    receivers.add(receiver)
  }

  private fun emitIfChanged() {
    val state = currentState()
    if (state == lastObserved) return
    lastObserved = state
    onStateChanged?.invoke(state)
  }
}
