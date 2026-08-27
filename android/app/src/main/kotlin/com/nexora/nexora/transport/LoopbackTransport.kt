package com.nexora.nexora.transport

import android.os.Handler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Loopback implementation of the transport boundary (E04-T03a, ADR-0004).
 * Proves the Pigeon plumbing end to end without real Bluetooth: `connect()`
 * to any device id succeeds, and `send()` echoes the same bytes back via
 * `onDataReceived` for the same device id after a short, real
 * (`Handler.postDelayed`) simulated latency — enough to prove the round
 * trip through the actual platform-channel boundary, not an in-Dart fake.
 *
 * Real Bluetooth discovery/connect/send-receive is T03b/T03c — this class
 * is the *only* implementation this task ships (§4, "what this task does
 * NOT do").
 */
class LoopbackTransport(
  private val eventsApi: TransportEventsApi,
  private val eventsScope: CoroutineScope,
  private val handler: Handler,
) {
  companion object {
    /** Matches the task's loopback delay design — real device round trip
     * should land within ~50-200ms (§8 manual test). */
    private const val LOOPBACK_DELAY_MS = 50L

    /** The single synthetic device loopback exposes to discovery, so a
     * debug caller has a deviceId to connect/send to without any real
     * radio. */
    const val LOOPBACK_DEVICE_ID = "loopback-device"
    private const val LOOPBACK_DEVICE_NAME = "Loopback (debug)"
  }

  fun startDiscovery() {
    eventsScope.launch {
      eventsApi.onDeviceDiscovered(
        TransportDevice(
          id = LOOPBACK_DEVICE_ID,
          displayName = LOOPBACK_DEVICE_NAME,
          type = TransportType.BLUETOOTH,
        ),
      )
    }
  }

  fun stopDiscovery() {
    // No-op: loopback has no ongoing scan to cancel.
  }

  /**
   * Loopback accepts any device id. The `true` return here only means
   * "accepted", matching the real-transport shape `TransportService.connect`
   * relies on (Dart awaits the eventual `onConnectionStateChanged`, never
   * assumes a synchronous accept means connected) — so even loopback's
   * always-succeeds path reports the settled state via the events channel,
   * not via this return value alone.
   */
  fun connect(deviceId: String): Boolean {
    handler.postDelayed({
      eventsScope.launch {
        eventsApi.onConnectionStateChanged(deviceId, ConnectionState.CONNECTED)
      }
    }, LOOPBACK_DELAY_MS)
    return true
  }

  fun disconnect(deviceId: String) {
    eventsScope.launch {
      eventsApi.onConnectionStateChanged(deviceId, ConnectionState.DISCONNECTED)
    }
  }

  /**
   * Echoes [bytes] back on [deviceId] via `onDataReceived` after a short,
   * real delay — proving the round trip through the actual Pigeon boundary.
   */
  fun send(deviceId: String, bytes: ByteArray): Boolean {
    handler.postDelayed({
      eventsScope.launch {
        eventsApi.onDataReceived(deviceId, bytes)
      }
    }, LOOPBACK_DELAY_MS)
    return true
  }
}
