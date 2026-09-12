package com.nexora.nexora.transport

import android.app.Activity
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
 * As of E04-T03c: `startDiscovery`/`stopDiscovery`/`connect`/`disconnect`/
 * `send` all delegate to `BluetoothTransport` (real Android Bluetooth
 * Classic, including real length-prefixed socket I/O) — no remaining
 * loopback path here. `LoopbackTransport` itself is deliberately not
 * deleted (E04-T03c §3): it stays useful for T04's non-hardware
 * tests/dev builds, which instantiate it directly rather than through
 * this host.
 */
class TransportApiHost(binaryMessenger: BinaryMessenger, activity: Activity) : TransportApi {

  private val eventsScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private val eventsApi = TransportEventsApi(binaryMessenger)
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

  /** Forwarded by `MainActivity.onActivityResult` (E04-B09) — mirrors
   * [onRequestPermissionsResult]'s own forwarding shape, for
   * `ACTION_REQUEST_DISCOVERABLE`'s `startActivityForResult` callback. */
  fun onActivityResult(requestCode: Int, resultCode: Int) {
    bluetooth.onActivityResult(requestCode, resultCode)
  }

  override fun startDiscovery() = bluetooth.startDiscovery()

  override fun stopDiscovery() = bluetooth.stopDiscovery()

  override fun connect(deviceId: String): Boolean = bluetooth.connect(deviceId)

  override fun disconnect(deviceId: String) = bluetooth.disconnect(deviceId)

  override fun send(deviceId: String, bytes: ByteArray): Boolean =
      bluetooth.send(deviceId, bytes)

  override fun requestDiscoverable() = bluetooth.requestDiscoverable()

  override fun getLocalDeviceName(): String = bluetooth.getLocalDeviceName()
}
