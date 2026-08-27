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
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Real Android Bluetooth Classic transport (E04-T03b/T03c, ADR-0004,
 * FR-DISC-001/002, FR-PLAT-002). Discovery is `BluetoothAdapter.startDiscovery()`
 * plus a `BroadcastReceiver` for `ACTION_FOUND`/`ACTION_DISCOVERY_FINISHED`.
 * Connect opens a real RFCOMM `BluetoothSocket` — always off the main
 * thread, since `BluetoothSocket.connect()` blocks (§6's top named risk in
 * the task file).
 *
 * As of T03c: `send()` and a per-connection background read loop move real
 * length-prefixed bytes over the connected socket's I/O streams — a 4-byte
 * big-endian length prefix followed by that many payload bytes, one
 * `send()` call producing exactly one `onDataReceived` call on the other
 * end (§2/§3 of E04-T03c). `LoopbackTransport` is no longer used for
 * `send`/receive once a real Bluetooth session is connected.
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

    /** 4-byte big-endian length prefix, per §2/§3's framing contract — one
     * `send()` call is one frame, reassembled whole on the other side before
     * `onDataReceived` fires. */
    private const val LENGTH_PREFIX_BYTES = 4

    /** Defensive cap on a single frame's declared length: a corrupted or
     * malicious length prefix (e.g. a negative int reinterpreted, or a huge
     * value) must not make the read loop allocate an unbounded buffer or
     * hang forever accumulating bytes that never arrive. Comfortably above
     * any real E2EE message payload this app sends in v1. */
    private const val MAX_FRAME_BYTES = 16 * 1024 * 1024

    /**
     * Upper bound on how long [send] will park its caller waiting for the
     * write thread. This is NOT a nicety: Pigeon creates the `send` channel
     * with no `TaskQueue` (`TransportApi.g.kt` — plain
     * `BasicMessageChannel(messenger, name, codec)`), so a host `send()` call
     * runs on the platform/UI thread. An RFCOMM `OutputStream.write()` can
     * block indefinitely under link-layer flow control (peer stops reading,
     * link degrades without dropping), and the only escape hatch —
     * `disconnect()` — is itself a host call on that same blocked thread, so
     * an unbounded wait is an unrecoverable UI-thread deadlock (ANR). Bounded
     * below Android's ~5s ANR window; on expiry the connection is torn down
     * (see [send]) rather than left half-written.
     */
    private const val SEND_TIMEOUT_MS = 3_000L
  }

  private val bluetoothManager =
      activity.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
  private val adapter: BluetoothAdapter? = bluetoothManager.adapter

  /** Cleared at the start of every `startDiscovery()` call — de-dups
   * `ACTION_FOUND` within one discovery session so the same nearby device
   * isn't re-emitted every scan cycle, per §5's contract. */
  private val discoveredAddresses = ConcurrentHashMap.newKeySet<String>()
  private val openSockets = ConcurrentHashMap<String, BluetoothSocket>()

  /** One background read-loop thread per connected device, keyed the same
   * as [openSockets]. Removed (and the thread allowed to exit) whenever the
   * connection for that device tears down — see [disconnect] and
   * [release]. */
  private val readThreads = ConcurrentHashMap<String, Thread>()

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
        startReadLoop(deviceId, socket)
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
    // Closing the socket is what actually unblocks a read-loop thread
    // parked in a blocking `InputStream.read()` — Android's BluetoothSocket
    // documents that a pending read throws IOException once the socket is
    // closed from another thread, which is what lets startReadLoop's own
    // catch block exit the loop and let the thread die. `interrupt()` is
    // added defensively (it does nothing to an in-flight socket read, but
    // costs nothing and helps if the thread is ever between reads).
    readThreads.remove(deviceId)?.interrupt()
    openSockets.remove(deviceId)?.let {
      try {
        it.close()
      } catch (e: IOException) {
        // Already closed / peer gone — not actionable here.
      }
    }
    eventsScope.launch { eventsApi.onConnectionStateChanged(deviceId, ConnectionState.DISCONNECTED) }
  }

  /**
   * Length-prefixed write to [deviceId]'s connected socket: a 4-byte
   * big-endian length prefix followed by [bytes] itself, so the peer's read
   * loop can reassemble exactly one frame per `send()` call. The actual
   * `OutputStream` write runs on a dedicated background thread per §3/§5 of
   * E04-T03c — never the calling (Pigeon platform) thread — and this method
   * blocks only on that thread's own result so the Boolean return still
   * reflects whether the write actually succeeded, never throwing across
   * the Pigeon boundary.
   */
  fun send(deviceId: String, bytes: ByteArray): Boolean {
    val socket = openSockets[deviceId] ?: return false
    val result = AtomicBoolean(false)
    val done = CountDownLatch(1)
    Thread({
          result.set(writeFrame(socket, bytes))
          done.countDown()
        }, "nexora-bt-write-$deviceId")
        .start()
    val settled =
        try {
          done.await(SEND_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        } catch (e: InterruptedException) {
          // Never throw across the Pigeon boundary (§5): restore the flag for
          // whoever owns this thread and report the send as failed.
          Thread.currentThread().interrupt()
          false
        }
    if (!settled) {
      // The write is stuck mid-frame. Returning false while that thread may
      // still complete a partial frame later would leave the peer's reader
      // permanently desynced (this framing has no resync marker), so tear the
      // connection down: closing the socket both aborts the stuck write with
      // an IOException and unblocks the read loop, and DISCONNECTED travels
      // to Dart the same way every other teardown does.
      disconnect(deviceId)
      return false
    }
    return result.get()
  }

  private fun writeFrame(socket: BluetoothSocket, bytes: ByteArray): Boolean {
    return try {
      val header =
          ByteBuffer.allocate(LENGTH_PREFIX_BYTES).order(ByteOrder.BIG_ENDIAN).putInt(bytes.size).array()
      val output = socket.outputStream
      // Guard against send() and a concurrent write to the same socket
      // (e.g. two overlapping send() calls) interleaving their bytes on the
      // wire, which would corrupt both frames for the reader.
      synchronized(socket) {
        output.write(header)
        output.write(bytes)
        output.flush()
      }
      true
    } catch (e: IOException) {
      false
    }
  }

  /**
   * Background read loop for one connection: reads the 4-byte length
   * prefix, then exactly that many payload bytes (looping across partial
   * `InputStream.read()` calls — a stream socket routinely returns fewer
   * bytes than requested), and emits `onDataReceived` once a whole frame is
   * assembled. Runs until the socket closes/errors (`disconnect()`) or the
   * thread is interrupted, at which point it exits and removes itself from
   * [readThreads] — never left leaked, parked on a dead socket.
   */
  private fun startReadLoop(deviceId: String, socket: BluetoothSocket) {
    val thread =
        Thread(
            {
              try {
                val input = socket.inputStream
                while (!Thread.currentThread().isInterrupted) {
                  val header = readFully(input, LENGTH_PREFIX_BYTES) ?: break
                  val length = ByteBuffer.wrap(header).order(ByteOrder.BIG_ENDIAN).int
                  if (length < 0 || length > MAX_FRAME_BYTES) break // corrupt/hostile frame
                  val payload = readFully(input, length) ?: break
                  eventsScope.launch { eventsApi.onDataReceived(deviceId, payload) }
                }
              } catch (e: IOException) {
                // Socket closed (disconnect()) or a real I/O error — either
                // way, the loop is done; nothing to report through this
                // thread, `disconnect()` already emits DISCONNECTED.
              } catch (e: Exception) {
                // Anything unexpected (a RuntimeException out of the stream or
                // out of `eventsScope.launch`) must die with this thread, not
                // reach the default uncaught handler — an uncaught exception on
                // any Android thread kills the whole process.
              } finally {
                // Two-arg remove: only de-register THIS thread. An
                // unconditional remove() would drop a newer read thread's
                // registration if a disconnect/reconnect for the same deviceId
                // raced ahead of this thread's exit, leaving the live thread
                // untracked by disconnect()/release().
                readThreads.remove(deviceId, Thread.currentThread())
              }
            },
            "nexora-bt-read-$deviceId")
    readThreads[deviceId] = thread
    thread.start()
  }

  /**
   * Reads exactly [count] bytes from [input], looping across partial reads.
   * Returns `null` on a clean EOF (peer closed the stream) before [count]
   * bytes were available — the caller treats that the same as a socket
   * error: stop the loop.
   */
  private fun readFully(input: InputStream, count: Int): ByteArray? {
    val buffer = ByteArray(count)
    var offset = 0
    while (offset < count) {
      val read = input.read(buffer, offset, count - offset)
      if (read == -1) return null // EOF — peer closed the stream cleanly
      offset += read
    }
    return buffer
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
    readThreads.values.forEach { it.interrupt() }
    readThreads.clear()
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
