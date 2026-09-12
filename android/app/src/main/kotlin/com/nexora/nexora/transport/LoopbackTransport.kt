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

    /** Deterministic stand-in latency for the loopback link (E06-T04, §3:
     * "LoopbackTransport.kt emits deterministic values so the loopback
     * path stays testable end to end"). There is no real radio to measure,
     * so this is a fixed, named, documented constant — never presented as
     * a real device's measurement — rather than a randomised or invented
     * "plausible" value. */
    private const val LOOPBACK_LINK_LATENCY_MS = LOOPBACK_DELAY_MS

    /** Loopback never drops a frame. */
    private const val LOOPBACK_LINK_LOSS_RATE = 0.0
  }

  fun startDiscovery() {
    eventsScope.launch {
      eventsApi.onDeviceDiscovered(
        TransportDevice(
          id = LOOPBACK_DEVICE_ID,
          displayName = LOOPBACK_DEVICE_NAME,
          type = TransportType.BLUETOOTH,
          rssi = null,
          // E04-B17: the loopback double has no real Bluetooth stack to
          // check bonding against; `false` is the safe default (never
          // eligible for `_reconcileStaleRelationship`), matching every
          // other call site's own explicit-rather-than-assumed value.
          bonded = false,
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

  /** E04-B19: a fixed, documented loopback-double value -- no real adapter
   * to query, matching every other native-only field's own pattern in this
   * class (see [startDiscovery]'s `bonded` doc comment). */
  fun getLocalDeviceName(): String = "Loopback (debug)"

  /**
   * Echoes [bytes] back on [deviceId] via `onDataReceived` after a short,
   * real delay — proving the round trip through the actual Pigeon boundary.
   */
  fun send(deviceId: String, bytes: ByteArray): Boolean {
    handler.postDelayed({
      eventsScope.launch {
        eventsApi.onDataReceived(deviceId, bytes)
        // E06-T04: deterministic stand-in link-quality signal so the
        // loopback path exercises RoutingEngine end to end without a real
        // radio — see the constants' doc comments above.
        eventsApi.onLinkQuality(deviceId, LOOPBACK_LINK_LATENCY_MS, LOOPBACK_LINK_LOSS_RATE)
      }
    }, LOOPBACK_DELAY_MS)
    return true
  }
}
