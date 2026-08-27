package com.nexora.nexora.transport

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Real Android Bluetooth Classic transport (E04-T03b, ADR-0004,
 * FR-DISC-001/002, FR-PLAT-002). Discovery is `BluetoothAdapter.startDiscovery()`
 * plus a `BroadcastReceiver` for `ACTION_FOUND`/`ACTION_DISCOVERY_FINISHED`.
 * Connect opens a real RFCOMM `BluetoothSocket` — always off the main
 * thread, since `BluetoothSocket.connect()` blocks (§6's top named risk in
 * the task file).
 *
 * `send()`/receive stay on `LoopbackTransport` for this task (T03c's scope,
 * §4) — this class only replaces `startDiscovery`/`stopDiscovery`/`connect`/
 * `disconnect`.
 */
class BluetoothTransport(
    private val activity: Activity,
    private val eventsApi: TransportEventsApi,
    private val eventsScope: CoroutineScope,
) {
  companion object {
    /**
     * Fixed, app-defined RFCOMM service UUID — the well-known Serial Port
     * Profile (SPP) UUID. Both ends of a Nexora<->Nexora connection use this
     * same constant, so `createRfcommSocketToServiceRecord()` can locate the
     * matching service record via SDP without any prior negotiation. A
     * bespoke random UUID would work identically for two Nexora devices,
     * but SPP's UUID is the documented, conventional choice for a Bluetooth
     * Classic serial-style channel and keeps this greppable/recognizable in
     * tooling (e.g. `sdptool`) during manual verification.
     */
    private val NEXORA_SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    /**
     * Sentinel device id used to report discovery/adapter-level failures
     * (permission denial, Bluetooth disabled, no adapter) through the
     * existing `onConnectionStateChanged(deviceId, state)` event — the
     * Pigeon schema (owned by T03a, not in this task's `files:`) has no
     * discovery-specific failure event, and §6 explicitly allows using this
     * event for exactly this purpose ("an explicit
     * onConnectionStateChanged(..., failed)"). A caller distinguishes "no
     * devices found" (silence) from "discovery could not start" (this
     * sentinel firing `failed`) instead of the two being indistinguishable.
     */
    const val DISCOVERY_SENTINEL_ID = "bluetooth-adapter"
  }

  private val bluetoothManager =
      activity.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
  private val adapter: BluetoothAdapter? = bluetoothManager.adapter

  /** Cleared at the start of every `startDiscovery()` call — de-dups
   * `ACTION_FOUND` within one discovery session so the same nearby device
   * isn't re-emitted every scan cycle, per §5's contract. */
  private val discoveredAddresses = ConcurrentHashMap.newKeySet<String>()
  private val openSockets = ConcurrentHashMap<String, BluetoothSocket>()

  private var discoveryReceiver: BroadcastReceiver? = null

  /** Set when a call is deferred behind a runtime permission request;
   * invoked from `onRequestPermissionsResult` once granted. */
  private var pendingPermissionAction: (() -> Unit)? = null

  /** Forwarded by `TransportApiHost` from `MainActivity.onRequestPermissionsResult`. */
  fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
    if (requestCode != BluetoothPermissions.REQUEST_CODE) return
    val action = pendingPermissionAction
    pendingPermissionAction = null
    val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
    if (granted) {
      action?.invoke()
    } else {
      emitFailure(DISCOVERY_SENTINEL_ID)
    }
  }

  fun startDiscovery() {
    if (!BluetoothPermissions.hasAll(activity)) {
      pendingPermissionAction = { doStartDiscovery() }
      BluetoothPermissions.requestAll(activity)
      return
    }
    doStartDiscovery()
  }

  fun stopDiscovery() {
    adapter?.let { if (it.isDiscovering) it.cancelDiscovery() }
  }

  /**
   * Establishes a real `BluetoothSocket` on a background thread — never the
   * main thread, since `connect()` blocks until it succeeds, fails, or the
   * remote is unreachable. Returns `true` to mean "accepted, attempting" —
   * mirrors `LoopbackTransport`'s existing contract where the eventual
   * settled state always travels via `onConnectionStateChanged`, never via
   * this return value alone (the reviewer-fixed bug in T03a's
   * `TransportService.connect()` depends on that shape holding here too).
   */
  fun connect(deviceId: String): Boolean {
    val bt = adapter
    if (bt == null || !bt.isEnabled) {
      emitFailure(deviceId)
      return false
    }
    if (!BluetoothPermissions.hasAll(activity)) {
      pendingPermissionAction = { connect(deviceId) }
      BluetoothPermissions.requestAll(activity)
      return false
    }

    eventsScope.launch { eventsApi.onConnectionStateChanged(deviceId, ConnectionState.CONNECTING) }

    Thread({
      try {
        val device = bt.getRemoteDevice(deviceId)
        val socket = device.createRfcommSocketToServiceRecord(NEXORA_SPP_UUID)
        // Discovery and an active connect attempt compete for the radio;
        // Android's own docs recommend cancelling discovery before connect.
        if (bt.isDiscovering) bt.cancelDiscovery()
        socket.connect() // BLOCKING — this background thread only.
        openSockets[deviceId] = socket
        eventsScope.launch { eventsApi.onConnectionStateChanged(deviceId, ConnectionState.CONNECTED) }
      } catch (e: IOException) {
        emitFailure(deviceId)
      } catch (e: SecurityException) {
        emitFailure(deviceId)
      } catch (e: IllegalArgumentException) {
        // getRemoteDevice() throws this for a malformed MAC address.
        emitFailure(deviceId)
      }
    }, "nexora-bt-connect-$deviceId").start()

    return true
  }

  fun disconnect(deviceId: String) {
    openSockets.remove(deviceId)?.let {
      try {
        it.close()
      } catch (e: IOException) {
        // Already closed / peer gone — not actionable here.
      }
    }
    eventsScope.launch { eventsApi.onConnectionStateChanged(deviceId, ConnectionState.DISCONNECTED) }
  }

  /** Called from `TransportApiHost.detach()` — tears down the receiver and
   * any open sockets so a torn-down Flutter engine doesn't leak either. */
  fun release() {
    stopDiscovery()
    discoveryReceiver?.let {
      try {
        activity.unregisterReceiver(it)
      } catch (e: IllegalArgumentException) {
        // Not registered — nothing to clean up.
      }
    }
    discoveryReceiver = null
    openSockets.values.forEach {
      try {
        it.close()
      } catch (e: IOException) {
        // Ignore — tearing down regardless.
      }
    }
    openSockets.clear()
  }

  private fun doStartDiscovery() {
    val bt = adapter
    if (bt == null || !bt.isEnabled) {
      emitFailure(DISCOVERY_SENTINEL_ID)
      return
    }
    discoveredAddresses.clear()
    registerReceiverIfNeeded()
    if (bt.isDiscovering) bt.cancelDiscovery()
    bt.startDiscovery()
  }

  private fun registerReceiverIfNeeded() {
    if (discoveryReceiver != null) return
    val receiver =
        object : BroadcastReceiver() {
          override fun onReceive(context: Context?, intent: Intent?) {
            intent ?: return
            if (intent.action == BluetoothDevice.ACTION_FOUND) handleDeviceFound(intent)
          }
        }
    val filter =
        IntentFilter().apply {
          addAction(BluetoothDevice.ACTION_FOUND)
          addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
    // API 33+ requires an explicit exported/not-exported flag for
    // context-registered receivers; ACTION_FOUND is a protected system
    // broadcast, so RECEIVER_NOT_EXPORTED (no other app can spoof it) is
    // correct and still delivers the real system broadcast.
    ContextCompat.registerReceiver(activity, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
    discoveryReceiver = receiver
  }

  private fun handleDeviceFound(intent: Intent) {
    val device = deviceFromIntent(intent) ?: return
    val address = device.address ?: return
    if (!discoveredAddresses.add(address)) return // already emitted this session
    val name =
        try {
          device.name
        } catch (e: SecurityException) {
          null
        } ?: address
    eventsScope.launch {
      eventsApi.onDeviceDiscovered(
          TransportDevice(id = address, displayName = name, type = TransportType.BLUETOOTH),
      )
    }
  }

  private fun deviceFromIntent(intent: Intent): BluetoothDevice? =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
      } else {
        @Suppress("DEPRECATION") intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
      }

  private fun emitFailure(deviceId: String) {
    eventsScope.launch { eventsApi.onConnectionStateChanged(deviceId, ConnectionState.FAILED) }
  }
}
