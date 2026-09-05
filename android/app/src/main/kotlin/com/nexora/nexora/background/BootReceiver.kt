package com.nexora.nexora.background

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * ADR-0007 §S3 (now in scope, EARS-PLAT-10): restarts
 * [ForegroundMeshService] after a device reboot, but only if the mesh was
 * active when the device last shut down — reusing
 * [BackgroundApiHost.wasMessagingActive], the same persisted flag that
 * gates a foreground-path start (see that class's header for why it is the
 * one and only such flag in this codebase, not a second one).
 *
 * A manifest-registered `BOOT_COMPLETED` receiver calling
 * `startForegroundService()` is a documented exemption to Android's
 * background-service-start restrictions on API 26+ — it is not a generic
 * background start (ADR-0007 §Decision, S3 builder note). This has NOT
 * been verified on a real device in this environment (no physical device
 * or emulator available) — see the task's own §8 Manual / self-review for
 * the honest disclosure of what could and could not be checked.
 *
 * Known limitation, same as [ForegroundMeshService]'s own: at boot there is
 * no cached `FlutterEngine` yet (the whole process was just created by the
 * OS to deliver this broadcast), so the restarted service raises process
 * priority and shows the notification but cannot drive
 * `MessagingCoordinator`'s tick until the user next opens the app. Reviving
 * the full messaging stack headlessly at boot is out of this task's
 * `files:` fence (it would require a `lib/app/main.dart` change).
 */
class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
    if (!BackgroundApiHost.wasMessagingActive(context)) return

    val serviceIntent = Intent(context, ForegroundMeshService::class.java)
    ContextCompat.startForegroundService(context, serviceIntent)
  }
}
