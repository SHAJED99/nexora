package com.nexora.nexora.transport

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothServerSocket
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
 *
 * As of E04-B06: this class also LISTENS. Before this fix, `connect()` was
 * the only Bluetooth Classic operation ever performed — a pure client-side
 * outbound dial, with nothing on either device's end ever accepting an
 * incoming connection. Two real Nexora installs could never complete an
 * RFCOMM handshake with each other as a result (confirmed live: a real
 * `connect()` attempt between two physical devices failed with a genuine
 * link-layer `Page Timeout`, visible in `dumpsys bluetooth_manager`, the
 * unambiguous symptom of paging a device with no listening socket on the
 * target service UUID) — regardless of `E04-B05`'s own, separate fix
 * (confirming the Dart layer now genuinely calls `connect()` at all).
 * `ensureListening()`/`acceptLoop()` open this device's own
 * `BluetoothServerSocket` on the same `NEXORA_SPP_UUID` and accept
 * incoming connections symmetrically, so either side of a Nexora<->Nexora
 * pair can be the one that dials.
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

    /** Human-readable SDP service name advertised alongside [NEXORA_SPP_UUID]
     * by [listenUsingRfcommWithServiceRecord] — cosmetic only (shown by
     * generic Bluetooth tooling doing an SDP inquiry), never read by this
     * app's own client side, which locates the service purely by UUID. */
    private const val SERVICE_NAME = "Nexora"

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

    /** Bounded window of recent `send()` attempts per device, used to
     * compute `lossRate` as a real ratio (E06-T04, §6 risk: never let this
     * grow unbounded, and never let it silently blend in attempts from a
     * torn-down connection — cleared on both [disconnect] and [release]
     * below so a later reconnect under the same device id starts with a
     * clean window rather than stale history). */
    private const val LINK_QUALITY_WINDOW_SIZE = 20
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

  /** Per-device bounded window of recent `send()` outcomes (true = write
   * completed successfully), the real basis for the `lossRate` reported to
   * `onLinkQuality` (E06-T04). Guarded by `synchronized(window)` since
   * `send()` can run from more than one caller thread. */
  private val sendOutcomes = ConcurrentHashMap<String, ArrayDeque<Boolean>>()

  private var discoveryReceiver: BroadcastReceiver? = null

  /**
   * E04-B06: this device's own listening socket, so a REMOTE device's
   * outbound [connect] has something to connect TO. Before this fix,
   * [connect] was the only Bluetooth Classic operation this class ever
   * performed — every connection was client-only, with nothing on either
   * end ever accepting one. Two real Nexora installs could never complete
   * an RFCOMM handshake with each other: confirmed live, two physical
   * devices, `dumpsys bluetooth_manager` showing the real outbound attempt
   * fail with `Page Timeout` (the link-layer symptom of paging a device
   * with no open server socket on the target UUID). `null` whenever not
   * currently listening (not yet started, or torn down by [release]).
   * `@Volatile` — written from both the main/platform thread
   * ([ensureListening]/[release]) and [acceptLoop]'s own thread (its
   * `finally`); a plain `var` gives no cross-thread visibility guarantee
   * at all (review finding, E04-B06 round 2).
   */
  @Volatile private var serverSocket: BluetoothServerSocket? = null

  /** The thread running [acceptLoop] — `null` whenever [serverSocket] is
   * `null`. Tracked separately (not just inferred from [serverSocket]) so
   * [ensureListening] can tell "listening already in progress" apart from
   * "never started". `@Volatile` for the same cross-thread-visibility
   * reason as [serverSocket]. */
  @Volatile private var acceptThread: Thread? = null

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

  /**
   * Opens this device's own listening RFCOMM socket on [NEXORA_SPP_UUID]
   * and starts [acceptLoop] on a background thread, if not already
   * running (E04-B06). Idempotent — safe to call from every permission-
   * gated entry point ([startDiscovery], [connect]) so listening starts
   * the moment permissions are actually granted, whichever call happens
   * to trigger that first, without this class needing its own separate
   * "am I initialized yet" lifecycle hook.
   *
   * Deliberately NOT gated behind discovery or an active outbound
   * `connect` attempt — a peer can only ever reach this device if
   * something is listening, symmetrically, on BOTH sides, all the time
   * this device's Bluetooth is on. This is the mesh's whole premise
   * (`ADR-0004`): a device with the app open is a potential relay hop for
   * ANY other device, not only ones it happens to be actively discovering
   * or messaging right now.
   */
  private fun ensureListening() {
    if (acceptThread != null) return // already listening
    val bt = adapter ?: return
    if (!bt.isEnabled || !BluetoothPermissions.hasAll(activity)) return
    val socket =
        try {
          bt.listenUsingRfcommWithServiceRecord(SERVICE_NAME, NEXORA_SPP_UUID)
        } catch (e: IOException) {
          // Could not open the listening socket right now (e.g. adapter
          // mid-toggle) -- not fatal, the next permission-gated call
          // retries since acceptThread is still null.
          return
        } catch (e: SecurityException) {
          return
        }
    serverSocket = socket
    val thread = Thread({ acceptLoop(socket) }, "nexora-bt-accept")
    acceptThread = thread
    thread.start()
  }

  /**
   * Runs until [socket] is closed (by [release], the only place this
   * class ever closes its OWN listening socket) or a real I/O error
   * occurs. `BluetoothServerSocket.accept()` returns one already-connected
   * [BluetoothSocket] per completed incoming handshake and can be called
   * again immediately after to accept the next one -- unlike a client
   * [connect]'s single-use socket, one server socket serves an unbounded
   * sequence of incoming connections for as long as this device keeps
   * running, exactly mirroring [connect]'s own successful-path bookkeeping
   * (`openSockets`/[startReadLoop]/`onConnectionStateChanged(CONNECTED)`)
   * so a caller of [send] cannot tell whether a given `deviceId`'s
   * connection was dialled out or accepted in.
   */
  private fun acceptLoop(socket: BluetoothServerSocket) {
    try {
      while (!Thread.currentThread().isInterrupted) {
        val accepted =
            try {
              socket.accept() // BLOCKING -- this thread only.
            } catch (e: IOException) {
              break // socket closed (release()) or a real accept error.
            }
        val remoteId =
            try {
              accepted.remoteDevice?.address
            } catch (e: SecurityException) {
              null
            }
        if (remoteId == null) {
          try {
            accepted.close()
          } catch (e: IOException) {
            // Nothing to do with an already-broken socket we can't even
            // identify the far end of.
          }
          continue
        }
        openSockets[remoteId] = accepted
        startReadLoop(remoteId, accepted)
        eventsScope.launch { eventsApi.onConnectionStateChanged(remoteId, ConnectionState.CONNECTED) }
      }
    } finally {
      // Conditional, mirroring `startReadLoop`'s own identical reasoning
      // (its `readThreads.remove(deviceId, Thread.currentThread())`,
      // two-arg for exactly this reason): an unconditional clear here
      // would let this (dying) thread wipe out a NEWER `ensureListening()`
      // call's own socket/thread if one raced ahead and started while
      // this one was already on its way out -- leaving that newer
      // listener's socket unreachable from `release()` (a real leak) and
      // `ensureListening()` permanently no-op-ing on a now-stale non-null
      // `acceptThread` that no longer belongs to any live loop (review
      // finding, E04-B06 round 2). Only clear the fields if THIS thread
      // is still the one currently registered.
      if (acceptThread === Thread.currentThread()) {
        serverSocket = null
        acceptThread = null
      }
    }
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
    ensureListening() // E04-B06 -- see that method's own doc comment.

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
    // A future reconnect under the same device id must not inherit this
    // connection's loss history — see the field's own doc comment.
    sendOutcomes.remove(deviceId)
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
    // Real, measured wall-clock time for this write to complete — the
    // basis for the `latencyMs` reported to `onLinkQuality` below (E06-T04,
    // §3: "latencyMs is a real round-trip observation"). This is the one
    // round trip the transport layer can actually observe without a new
    // application-level ack protocol (out of this task's fence — see §4):
    // `OutputStream.write()` on a connected RFCOMM socket blocks under the
    // link layer's own flow control, so its completion time reflects real
    // link conditions rather than a synthesized value.
    val startNanos = System.nanoTime()
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
      // to Dart the same way every other teardown does. disconnect() already
      // clears this device's sendOutcomes window, so there is nothing further
      // to record here — a timed-out write has no valid latency measurement
      // to report (E06-T04 §3: emit nothing for a value that cannot be
      // measured, never a placeholder).
      disconnect(deviceId)
      return false
    }
    val success = result.get()
    val lossRate = recordSendOutcome(deviceId, success)
    if (success) {
      val latencyMs = (System.nanoTime() - startNanos) / 1_000_000L
      eventsScope.launch { eventsApi.onLinkQuality(deviceId, latencyMs, lossRate) }
    }
    // A failed (but settled, non-timeout) write has no valid latency to
    // report either — only lossRate degrades for it, folded into the next
    // successful send's onLinkQuality call.
    return success
  }

  /**
   * Records [success] into [deviceId]'s bounded outcome window and returns
   * the resulting loss ratio (`0.0-1.0`) — the real basis for the
   * `lossRate` reported to `onLinkQuality`. Thread-safe: `send()` can be
   * invoked from more than one caller.
   */
  private fun recordSendOutcome(deviceId: String, success: Boolean): Double {
    val window = sendOutcomes.getOrPut(deviceId) { ArrayDeque() }
    synchronized(window) {
      window.addLast(success)
      while (window.size > LINK_QUALITY_WINDOW_SIZE) window.removeFirst()
      val failures = window.count { !it }
      return failures.toDouble() / window.size
    }
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
    // E04-B06: close this device's own listening socket -- `accept()`
    // throws `IOException` the moment its underlying `BluetoothServerSocket`
    // is closed from another thread, which is what lets `acceptLoop`'s own
    // catch exit the loop and let this thread die, mirroring `disconnect()`'s
    // identical reasoning for a client-side read loop.
    acceptThread?.interrupt()
    serverSocket?.let {
      try {
        it.close()
      } catch (e: IOException) {
        // Already closed / adapter gone — not actionable here.
      }
    }
    serverSocket = null
    acceptThread = null
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
    sendOutcomes.clear()
  }

  private fun doStartDiscovery() {
    val bt = adapter
    if (bt == null || !bt.isEnabled) {
      emitFailure(DISCOVERY_SENTINEL_ID)
      return
    }
    ensureListening() // E04-B06 -- see that method's own doc comment.
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
    // context-registered receivers. `E04-B04`: `ACTION_FOUND` is sent by
    // `com.android.bluetooth` -- a DIFFERENT app/uid than this one -- as
    // an explicit, package-targeted broadcast (`pkg=com.nexora.nexora`),
    // not a same-app broadcast. `RECEIVER_NOT_EXPORTED` (this file's own
    // prior, incorrect reasoning: "no other app can spoof it") means
    // exactly the opposite of what's needed here -- it silently drops
    // any broadcast from a different UID, confirmed on a real device via
    // `Exported Denial: ... from com.android.bluetooth (uid=1002) ...
    // not specifying RECEIVER_EXPORTED` in logcat. `RECEIVER_EXPORTED` is
    // still safe: `ACTION_FOUND` is declared a protected system broadcast
    // in the platform's own manifest, so only the OS Bluetooth stack can
    // ever actually send it -- no third-party app can forge one, exported
    // or not.
    ContextCompat.registerReceiver(activity, receiver, filter, ContextCompat.RECEIVER_EXPORTED)
    discoveryReceiver = receiver
  }

  private fun handleDeviceFound(intent: Intent) {
    val device = deviceFromIntent(intent) ?: return
    val address = device.address ?: return
    if (!discoveredAddresses.add(address)) return // already emitted this session
    val rawName =
        try {
          device.name
        } catch (e: SecurityException) {
          null
        }
    val name = rawName ?: address
    // E04-B08: confirmed on real hardware (MIUI/Xiaomi) that
    // `startDiscovery()`'s `ACTION_FOUND` address is randomized on every
    // single scan -- not merely stale -- with zero stable relationship to
    // the peer's real, bondable BR/EDR address, even for an
    // already-bonded peer. Emitting that randomized address as this
    // device's `TransportDevice.id` means a later `connect()` pages an
    // address that (per the diagnostic) may not correspond to any real,
    // reachable radio at all. The scanned address therefore cannot even
    // be used to recognize "this is the same bonded peer" -- the peer's
    // Bluetooth-visible name (`rawName`, read above -- NOT the
    // address-fallback `name` local) is the only pre-bond correlator
    // available. `resolveDeviceId` prefers a bonded device's own real
    // address when its name exactly matches; a genuinely new,
    // not-yet-bonded peer (no name match) falls back to the raw scanned
    // address, unchanged from prior behavior.
    val resolvedId = resolveDeviceId(address, rawName)
    // E06-T04: populate rssi from the scan result's own EXTRA_RSSI — it is
    // already in this broadcast and was previously dropped on the floor
    // (task §3). Android has no separate `hasExtra` contract for this key;
    // `Short.MIN_VALUE` is the documented sentinel `getShortExtra` returns
    // when the extra is absent, folded to `null` here rather than
    // synthesizing a fake dBm value (§2: "a measured value or no value,
    // never a default").
    val rssiExtra = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE)
    val rssi = if (rssiExtra == Short.MIN_VALUE) null else rssiExtra.toLong()
    eventsScope.launch {
      eventsApi.onDeviceDiscovered(
          TransportDevice(id = resolvedId, displayName = name, type = TransportType.BLUETOOTH, rssi = rssi),
      )
    }
  }

  /**
   * Resolves the address to actually report as [TransportDevice.id] for a
   * fresh discovery result (E04-B08). [scannedAddress] is the raw,
   * possibly-randomized address from this `ACTION_FOUND` broadcast;
   * [rawName] is the peer's Bluetooth-visible name straight off
   * `BluetoothDevice.name` (before any address fallback). If [rawName] is
   * non-null/non-blank and matches a currently bonded device's own name
   * exactly, that bonded device's real address is returned instead --
   * bonded devices have a real, stable, connectable address, which the
   * scan result's own address is confirmed (on real hardware) not to be.
   * Falls back to [scannedAddress] unchanged whenever there is no name to
   * match on, no bonded-devices list available (permission denied), or no
   * bonded device's name matches -- the genuinely-new, not-yet-bonded-peer
   * case, where no better address exists yet.
   */
  private fun resolveDeviceId(scannedAddress: String, rawName: String?): String {
    if (rawName.isNullOrEmpty()) return scannedAddress
    val bondedDevices =
        try {
          adapter?.bondedDevices
        } catch (e: SecurityException) {
          null
        } ?: return scannedAddress
    for (bonded in bondedDevices) {
      val bondedName =
          try {
            bonded.name
          } catch (e: SecurityException) {
            null
          }
      if (bondedName != null && bondedName == rawName) {
        val bondedAddress =
            try {
              bonded.address
            } catch (e: SecurityException) {
              null
            }
        if (bondedAddress != null) return bondedAddress
      }
    }
    return scannedAddress
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
