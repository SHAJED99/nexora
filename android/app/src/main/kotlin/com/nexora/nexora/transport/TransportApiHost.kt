package com.nexora.nexora.transport

import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/**
 * Native Kotlin host for the Pigeon transport boundary (ADR-0004,
 * FR-PLAT-003). Implements the Dart-facing `TransportApi` (host calls) and
 * owns the `TransportEventsApi` (Kotlin -> Dart events) used to push
 * discovery/connection/data events back.
 *
 * As of E04-T03b: `startDiscovery`/`stopDiscovery`/`connect`/`disconnect`
 * delegate to `BluetoothTransport` (real Android Bluetooth Classic).
 * `send()` still delegates to `LoopbackTransport` — real send/receive is
 * T03c's scope (see epics/E04-mesh-routing/tasks/E04-T03b.md §4).
 */
class TransportApiHost(binaryMessenger: BinaryMessenger, activity: Activity) : TransportApi {

  private val eventsScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private val eventsApi = TransportEventsApi(binaryMessenger)
  private val loopback = LoopbackTransport(
    eventsApi = eventsApi,
    eventsScope = eventsScope,
    handler = Handler(Looper.getMainLooper()),
  )
  private val bluetooth = BluetoothTransport(
    activity = activity,
    eventsApi = eventsApi,
    eventsScope = eventsScope,
  )

  /** Registers this host to handle `TransportApi` calls from Dart. */
  fun attach(messenger: BinaryMessenger) {
    TransportApi.setUp(messenger, this)
  }

  /** Unregisters this host — call from `cleanUpFlutterEngine` so a torn-down
   * engine's binary messenger doesn't keep a dangling handler registered. */
  fun detach(messenger: BinaryMessenger) {
    TransportApi.setUp(messenger, null)
    bluetooth.release()
  }

  /** Forwarded by `MainActivity.onRequestPermissionsResult`. */
  fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
    bluetooth.onRequestPermissionsResult(requestCode, grantResults)
  }

  override fun startDiscovery() = bluetooth.startDiscovery()

  override fun stopDiscovery() = bluetooth.stopDiscovery()

  override fun connect(deviceId: String): Boolean = bluetooth.connect(deviceId)

  override fun disconnect(deviceId: String) = bluetooth.disconnect(deviceId)

  override fun send(deviceId: String, bytes: ByteArray): Boolean =
      loopback.send(deviceId, bytes)
}
