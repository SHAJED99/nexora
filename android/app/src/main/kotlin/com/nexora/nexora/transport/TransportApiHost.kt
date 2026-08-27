package com.nexora.nexora.transport

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
 * discovery/connection/data events back. Delegates all actual transport
 * behavior to `LoopbackTransport` — this task ships no real Bluetooth (see
 * epics/E04-mesh-routing/tasks/E04-T03a.md).
 */
class TransportApiHost(binaryMessenger: BinaryMessenger) : TransportApi {

  private val eventsScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private val eventsApi = TransportEventsApi(binaryMessenger)
  private val transport = LoopbackTransport(
    eventsApi = eventsApi,
    eventsScope = eventsScope,
    handler = Handler(Looper.getMainLooper()),
  )

  /** Registers this host to handle `TransportApi` calls from Dart. */
  fun attach(messenger: BinaryMessenger) {
    TransportApi.setUp(messenger, this)
  }

  /** Unregisters this host — call from `cleanUpFlutterEngine` so a torn-down
   * engine's binary messenger doesn't keep a dangling handler registered. */
  fun detach(messenger: BinaryMessenger) {
    TransportApi.setUp(messenger, null)
  }

  override fun startDiscovery() = transport.startDiscovery()

  override fun stopDiscovery() = transport.stopDiscovery()

  override fun connect(deviceId: String): Boolean = transport.connect(deviceId)

  override fun disconnect(deviceId: String) = transport.disconnect(deviceId)

  override fun send(deviceId: String, bytes: ByteArray): Boolean =
      transport.send(deviceId, bytes)
}
