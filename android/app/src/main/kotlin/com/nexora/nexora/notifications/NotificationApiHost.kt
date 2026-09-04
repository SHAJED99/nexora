package com.nexora.nexora.notifications

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.nexora.nexora.MainActivity
import com.nexora.nexora.R
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Native Kotlin host for the Pigeon notification boundary (ADR-0004,
 * FR-PLAT-003, FR-NOTIFY-001). Implements the Dart-facing `NotificationApi`
 * (host calls) and owns the `NotificationEventsApi` (Kotlin -> Dart events)
 * used to report permission results and notification taps.
 *
 * Holds an `Activity` reference the same way `TransportApiHost` does (E04),
 * needed for the runtime `POST_NOTIFICATIONS` permission request/result flow
 * on API 33+.
 */
class NotificationApiHost(
    binaryMessenger: BinaryMessenger,
    private val activity: Activity,
) : NotificationApi {

  companion object {
    /**
     * Distinct from `BluetoothPermissions.REQUEST_CODE` (4200, E04-T03b) —
     * the task's own §6 top-named risk: a colliding request code would
     * silently break the Bluetooth permission flow, since
     * `MainActivity.onRequestPermissionsResult` forwards the same callback
     * to both hosts and each must ignore a request code it doesn't own.
     */
    const val REQUEST_CODE = 4300

    /** Intent extra key: the tapped notification's Pigeon id (a [Long]),
     * read back by [MainActivity]'s launch/new-intent handling (E10-B07). */
    const val EXTRA_NOTIFICATION_ID = "com.nexora.nexora.NOTIFICATION_ID"

    /** Intent extra key: the tapped notification's category, by
     * [NotificationCategory.name] (a [String] -- `Serializable`/`Parcelable`
     * enums round-trip awkwardly across process death, a plain name string
     * does not). */
    const val EXTRA_NOTIFICATION_CATEGORY = "com.nexora.nexora.NOTIFICATION_CATEGORY"
  }

  private val eventsScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private val eventsApi = NotificationEventsApi(binaryMessenger)

  /** Registers this host to handle `NotificationApi` calls from Dart. */
  fun attach(messenger: BinaryMessenger) {
    NotificationApi.setUp(messenger, this)
  }

  /** Unregisters this host — call from `cleanUpFlutterEngine` so a torn-down
   * engine's binary messenger doesn't keep a dangling handler registered. */
  fun detach(messenger: BinaryMessenger) {
    NotificationApi.setUp(messenger, null)
    eventsScope.cancel()
  }

  /** Forwarded by `MainActivity.onRequestPermissionsResult`. Ignores any
   * request code other than [REQUEST_CODE] — e.g. Bluetooth's 4200 — so the
   * two permission flows never interfere with each other. */
  fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
    if (requestCode != REQUEST_CODE) return
    val granted =
        grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
    eventsScope.launch { eventsApi.onPermissionResult(granted) }
  }

  override fun ensureChannels() {
    NotificationChannels.ensureChannels(activity)
  }

  /** On API < 33 there is no runtime notification permission at all, so this
   * must report `true` — reporting `false` there would silently suppress
   * every notification on older devices while the Dart-side tests (which
   * only exercise the API-33+ shape) still pass (task §6). */
  override fun hasPermission(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
    return ContextCompat.checkSelfPermission(
        activity,
        Manifest.permission.POST_NOTIFICATIONS,
    ) == PackageManager.PERMISSION_GRANTED
  }

  override fun requestPermission() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
      // Nothing to request; report the always-granted state so a caller
      // awaiting onPermissionResult still settles.
      eventsScope.launch { eventsApi.onPermissionResult(true) }
      return
    }
    ActivityCompat.requestPermissions(
        activity,
        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
        REQUEST_CODE,
    )
  }

  /**
   * Posts (or replaces, by [NotificationRequest.id]) through
   * `NotificationManagerCompat`. Reports the manager's own
   * `areNotificationsEnabled()` rather than claiming success it cannot
   * observe (task §6: a channel the user disabled makes `notify()` return
   * silently, with no exception and no other signal).
   */
  override fun post(request: NotificationRequest): Boolean {
    val manager = NotificationManagerCompat.from(activity)
    if (!manager.areNotificationsEnabled()) return false
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !hasPermission()) {
      return false
    }

    // E10-B07: every category posted through this host was previously
    // un-tappable -- no setContentIntent, so tapping a message/call/
    // trust-request notification did nothing at all, and (with no
    // setAutoCancel) it stayed in the shade until something called
    // cancel(id). The tap intent carries the id + category back through
    // MainActivity's launch/new-intent handling to
    // eventsApi.onNotificationTapped -- routing what Dart does with a tap
    // is still OQ-E10-1's open question; this only makes delivery (§4's
    // explicitly in-scope half) actually reach Dart.
    val tapIntent = Intent(activity, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
      putExtra(EXTRA_NOTIFICATION_ID, request.id)
      putExtra(EXTRA_NOTIFICATION_CATEGORY, request.category.name)
    }
    val tapPendingIntent = PendingIntent.getActivity(
        activity,
        request.id.toInt(),
        tapIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    val notification =
        NotificationCompat.Builder(activity, NotificationChannels.channelId(request.category))
            .setContentTitle(request.title)
            .setContentText(request.body)
            .setOngoing(request.ongoing)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(priorityFor(request.category))
            .setContentIntent(tapPendingIntent)
            .setAutoCancel(!request.ongoing)
            .build()

    return try {
      manager.notify(request.id.toInt(), notification)
      true
    } catch (e: SecurityException) {
      // Permission revoked between the checks above and this call.
      false
    }
  }

  override fun cancel(id: Long) {
    NotificationManagerCompat.from(activity).cancel(id.toInt())
  }

  /**
   * E10-B07: delivers a tap to Dart. Called by [MainActivity] once it
   * decodes [EXTRA_NOTIFICATION_ID]/[EXTRA_NOTIFICATION_CATEGORY] off the
   * intent that (re)launched it -- either [MainActivity.onNewIntent] (app
   * already running) or the initial launch intent (a cold start via the
   * tap alone). Best-effort like every other event send in this file: if
   * no Dart side is currently attached to receive it, the tap is simply
   * not reported, matching this host's existing posture elsewhere.
   */
  fun notifyTapped(id: Long, category: NotificationCategory) {
    eventsScope.launch { eventsApi.onNotificationTapped(id, category) }
  }

  private fun priorityFor(category: NotificationCategory): Int =
      when (category) {
        NotificationCategory.INCOMING_CALL -> NotificationCompat.PRIORITY_HIGH
        NotificationCategory.BACKGROUND_SERVICE -> NotificationCompat.PRIORITY_LOW
        else -> NotificationCompat.PRIORITY_DEFAULT
      }
}
