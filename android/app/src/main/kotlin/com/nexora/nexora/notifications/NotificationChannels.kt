package com.nexora.nexora.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/**
 * Creates one Android `NotificationChannel` per [NotificationCategory]
 * (E10-T01, FR-NOTIFY-001/FR-PLAT-003). `NotificationManager
 * .createNotificationChannel` is itself idempotent for an unchanged channel
 * id (a no-op re-declare), so [ensureChannels] is safe — and required by the
 * task's own contract — to call on every engine attach.
 *
 * Importance, once a channel is created, cannot be raised by Android (task
 * §6's top-of-list risk) — this table is the single place that decision is
 * made, and it is made once, here.
 *
 * Channel names/descriptions below are provisional copy, not design-approved
 * (`OQ-E10-1` — no accepted design source for any notification surface yet).
 */
object NotificationChannels {
  /** Stable per-category channel id. Also what `NotificationApiHost.post`
   * targets when building each `Notification`. */
  fun channelId(category: NotificationCategory): String =
      "nexora_${category.name.lowercase()}"

  private val importance: Map<NotificationCategory, Int> =
      mapOf(
          NotificationCategory.INCOMING_CALL to NotificationManager.IMPORTANCE_HIGH,
          NotificationCategory.MESSAGE to NotificationManager.IMPORTANCE_DEFAULT,
          NotificationCategory.VOICE_MESSAGE to NotificationManager.IMPORTANCE_DEFAULT,
          NotificationCategory.PTT to NotificationManager.IMPORTANCE_DEFAULT,
          NotificationCategory.CONNECTION_REQUEST to NotificationManager.IMPORTANCE_DEFAULT,
          NotificationCategory.TRUST_REQUEST to NotificationManager.IMPORTANCE_DEFAULT,
          NotificationCategory.GROUP_EVENT to NotificationManager.IMPORTANCE_DEFAULT,
          NotificationCategory.SECURITY_EVENT to NotificationManager.IMPORTANCE_DEFAULT,
          NotificationCategory.STORAGE_WARNING to NotificationManager.IMPORTANCE_DEFAULT,
          // LOW: no sound, no badge — the mandatory ongoing foreground-service
          // notification (E10-T08) should not alert or badge the user.
          NotificationCategory.BACKGROUND_SERVICE to NotificationManager.IMPORTANCE_LOW,
      )

  private fun displayName(category: NotificationCategory): String =
      when (category) {
        NotificationCategory.MESSAGE -> "Messages"
        NotificationCategory.VOICE_MESSAGE -> "Voice messages"
        NotificationCategory.PTT -> "Push-to-talk"
        NotificationCategory.INCOMING_CALL -> "Incoming calls"
        NotificationCategory.CONNECTION_REQUEST -> "Connection requests"
        NotificationCategory.TRUST_REQUEST -> "Trust requests"
        NotificationCategory.GROUP_EVENT -> "Group events"
        NotificationCategory.SECURITY_EVENT -> "Security events"
        NotificationCategory.STORAGE_WARNING -> "Storage warnings"
        NotificationCategory.BACKGROUND_SERVICE -> "Background service"
      }

  /** No-op below API 26 (notification channels did not exist yet — every
   * notification on those versions is implicitly on a single default
   * channel with no per-category importance to set). Idempotent above that:
   * safe, and expected, to call on every attach. */
  fun ensureChannels(context: Context) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val manager = context.getSystemService(NotificationManager::class.java) ?: return
    for (category in NotificationCategory.values()) {
      val channel =
          NotificationChannel(
              channelId(category),
              displayName(category),
              importance.getValue(category),
          )
      if (category == NotificationCategory.BACKGROUND_SERVICE) {
        channel.setSound(null, null)
        channel.enableVibration(false)
        channel.setShowBadge(false)
      }
      manager.createNotificationChannel(channel)
    }
  }
}
