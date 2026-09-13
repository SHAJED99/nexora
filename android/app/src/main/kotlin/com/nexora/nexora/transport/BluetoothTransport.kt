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
     * write thread. `send`'s Pigeon channel now runs on a dedicated
     * background `TaskQueue` (E04-B11 —
     * `@TaskQueue(type: TaskQueueType.serialBackgroundThread)` in
     * `pigeons/transport.dart`), so this wait no longer risks blocking the
     * platform/UI thread the way it did before that fix. It stays bounded
     * regardless: an RFCOMM `OutputStream.write()` can still block
     * indefinitely under link-layer flow control (peer stops reading, link
     * degrades without dropping), and an unbounded wait would still wedge
     * this device's own background write-dispatch queue for this transport
     * forever. On expiry the connection is torn down (see [send]) rather
     * than left half-written. The exact bound is not itself tuned by
     * E04-B11 — see that task and `E04-B12` for open questions about
     * whether 3s is the right value now that it no longer doubles as an
     * ANR guard.
     */
    private const val SEND_TIMEOUT_MS = 3_000L

    /** Bounded window of recent `send()` attempts per device, used to
     * compute `lossRate` as a real ratio (E06-T04, §6 risk: never let this
     * grow unbounded, and never let it silently blend in attempts from a
     * torn-down connection — cleared on both [disconnect] and [release]
     * below so a later reconnect under the same device id starts with a
     * clean window rather than stale history). */
    private const val LINK_QUALITY_WINDOW_SIZE = 20

    /** Request code passed to `activity.startActivityForResult` for
     * `ACTION_REQUEST_DISCOVERABLE` (E04-B09). Distinct from
     * [BluetoothPermissions.REQUEST_CODE] (4200, a runtime-permission
     * request code, not an activity-result one) and
     * `NotificationApiHost.REQUEST_CODE` (4300) — this is `MainActivity`'s
     * own `onActivityResult` forwarding, not `onRequestPermissionsResult`. */
    const val REQUEST_DISCOVERABLE_CODE = 4400

    /** `EXTRA_DISCOVERABLE_DURATION`, in seconds — the human-decided,
     * time-boxed discoverability window (E04-B09's "Discoverability" human
     * decision, 2026-09-11): reverts automatically, no background battery
     * cost once elapsed. */
    private const val DISCOVERABLE_DURATION_SECONDS = 120

    /** F2 (E04-B09 review fix): `BOND_BONDED` only means the OS-level bond
     * exists, not that the peer's SDP service record is retrievable yet --
     * an RFCOMM connect issued immediately after bonding commonly fails on
     * its first attempt in practice (a well-known Android BT quirk). A
     * short settle delay before each post-bond connect attempt, plus one
     * bounded retry on failure, covers this without touching [doConnect]'s
     * own single-attempt contract for the already-bonded case. */
    private const val POST_BOND_CONNECT_DELAY_MS = 400L
    private const val POST_BOND_CONNECT_MAX_ATTEMPTS = 2
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

  /** `ACTION_BOND_STATE_CHANGED` receiver (E04-B09), registered lazily the
   * first time [connect] needs to bond an unbonded peer — mirrors
   * [registerReceiverIfNeeded]'s own lazy-registration shape for the
   * `ACTION_FOUND`/`ACTION_DISCOVERY_FINISHED` receiver. */
  private var bondStateReceiver: BroadcastReceiver? = null

  /** Device addresses [connect] is currently waiting on a bond outcome for,
   * mapped to the `connect()` continuation to run once `BOND_BONDED` fires
   * for that address. An address present here is also the signal that a
   * `BOND_NONE` for it means "bonding just failed/was rejected" rather than
   * "this address was never bonding in the first place" — Android also
   * broadcasts `BOND_NONE` for plenty of addresses this device was never
   * trying to bond with (e.g. a completely unrelated device the user
   * un-pairs from OS Settings), and those must not spuriously fail a
   * `connect()` call that never asked for them. */
  private val pendingBondConnections = ConcurrentHashMap<String, () -> Unit>()

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
        val rawRemoteAddress =
            try {
              accepted.remoteDevice?.address
            } catch (e: SecurityException) {
              null
            }
        val rawRemoteName =
            try {
              accepted.remoteDevice?.name
            } catch (e: SecurityException) {
              null
            }
        // E04-B17: `rawRemoteAddress` can be a masked/obfuscated value (not
        // the peer's real, bonded BR/EDR address) on some OEM Bluetooth
        // stacks (confirmed live: MIUI reports a fixed placeholder for an
        // ACCEPTED connection's remote address, the same placeholder it
        // reports for its OWN local adapter identity) -- the same class of
        // address unreliability `E04-B08` already found and fixed for the
        // discovery-scan (`ACTION_FOUND`) path via `resolveDeviceId`, never
        // previously applied here. Every Dart-side stream (`connectionState`/
        // `incomingData`) is keyed by the REAL bonded address stored in
        // `relationships.device_id`, so a masked accept-time address here
        // means the connected/data events are broadcast to a deviceId
        // nothing is listening for -- silently dropped, never reaching
        // `InboundPipeline` at all. Resolving via the SAME bonded-name-match
        // helper used for discovery closes this for the (overwhelmingly
        // common, in this app's design) already-bonded-peer case; an
        // unbonded/unnamed peer falls back to the raw reported address
        // unchanged, exactly `resolveDeviceId`'s own existing contract.
        val remoteId = rawRemoteAddress?.let { resolveDeviceId(it, rawRemoteName) }
        if (remoteId == null) {
          try {
            accepted.close()
          } catch (e: IOException) {
            // Nothing to do with an already-broken socket we can't even
            // identify the far end of.
          }
          continue
        }
        // E04-B17: emit `onDeviceDiscovered` for this accepted peer BEFORE
        // `onConnectionStateChanged` -- `InboundPipeline._onDeviceDiscovered`
        // is the ONLY place a `connectionState`/`incomingData` subscription
        // ever gets created for a device id the Dart side does not already
        // have a relationship for (`_seedKnownDevices` only seeds EXISTING
        // trusted/allowed relationships; nothing previously routed a
        // genuinely-new-to-Dart accepted connection through that path at
        // all). Without this, `onConnectionStateChanged`/`onDataReceived`
        // below still fire correctly and still reach the Dart `_EventsHandler`
        // -- confirmed live -- but land on a broadcast stream nothing is
        // listening for and are silently dropped, never reaching
        // `InboundPipeline`. This also gives `_onDeviceDiscovered` the raw
        // peer name (mirrors `handleDeviceFound`'s own `name = rawName ?:
        // address` fallback), which is what lets it reconcile a stale
        // relationship address (`_reconcileStaleRelationship`) for an
        // already-bonded peer whose stored address has drifted -- the same
        // real gap this task's own root-causing found.
        //
        // `bonded` (review round 1, F1/F2): re-checked explicitly rather
        // than assumed -- both this app's socket variants
        // (`createRfcommSocketToServiceRecord`/
        // `listenUsingRfcommWithServiceRecord`) are the SECURE flavor,
        // which the platform only ever completes for an already-bonded
        // pair, so this is expected to always be `true` for an accepted
        // connection; asserting it explicitly (rather than hard-coding
        // `true`) means a future change to the socket variant, or an OS
        // quirk that somehow accepts an unbonded peer, fails safe (no
        // reconciliation) instead of silently trusting an assumption that
        // stopped holding.
        val remoteBonded = isBonded(remoteId)
        eventsScope.launch {
          eventsApi.onDeviceDiscovered(
              TransportDevice(
                  id = remoteId,
                  displayName = rawRemoteName ?: remoteId,
                  type = TransportType.BLUETOOTH,
                  rssi = null,
                  bonded = remoteBonded,
              ),
          )
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
    // E04-B17: idempotent when a live socket for [deviceId] already exists
    // -- confirmed live: `ConnectionEnsuringSender`'s own Dart-side
    // "already connected" cache (`_connectedDeviceIds`) is populated ONLY
    // by a successful OUTBOUND `connect()`, so it has no way to know about
    // a connection this device ACCEPTED (`acceptLoop`, above). Once
    // E04-B17's own address-reconciliation fix made an accepted
    // connection's device id agree with the SAME id Dart later calls
    // `directSend`/`connect` with for that peer (e.g. from
    // `IdentityAnnounceService.sendAnnounce` firing right after accept),
    // that mismatch turned into a real, observed race: the redundant
    // outbound `doConnect` this method used to always attempt fires its
    // own `CONNECTING` event, which `InboundPipeline._onConnectionStateChanged`
    // treats as "no active link" and tears down the `incomingData`
    // subscription the accept had JUST created -- silently killing the
    // very connection this call was trying to reuse. Re-emitting `CONNECTED`
    // (rather than doing nothing) keeps `TransportService.connect`'s own
    // `await settled.future` contract intact for a caller that raced in
    // after the connection was already accepted.
    if (openSockets.containsKey(deviceId)) {
      eventsScope.launch { eventsApi.onConnectionStateChanged(deviceId, ConnectionState.CONNECTED) }
      return true
    }
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

    // E04-B09: an unbonded peer's RFCOMM connect fails outright -- both of
    // this app's own secure socket variants require an OS-level bond. Same
    // `bondedDevices` check E04-B08's `resolveDeviceId` already introduced.
    // Reusing `isBonded` here (rather than re-deriving it) keeps the two
    // call sites' notion of "already bonded" identical.
    if (!isBonded(deviceId)) {
      startBondAndConnect(bt, deviceId)
      return true
    }

    doConnect(bt, deviceId)
    return true
  }

  /** `true` when [deviceId] (a raw Bluetooth MAC address) is already in
   * `adapter.bondedDevices` — the same check `resolveDeviceId` (E04-B08)
   * uses to prefer a bonded device's real address. A `SecurityException`
   * (permission revoked between [connect]'s own `hasAll` check and this
   * call — a narrow but real race) reads as "not bonded", the safe
   * direction: it routes into [startBondAndConnect], which re-checks
   * permissions via `createBond()`'s own runtime behaviour, rather than
   * silently skipping straight to an RFCOMM connect that would fail anyway.
   */
  private fun isBonded(deviceId: String): Boolean {
    val bondedDevices =
        try {
          adapter?.bondedDevices
        } catch (e: SecurityException) {
          null
        } ?: return false
    return bondedDevices.any { it.address == deviceId }
  }

  /**
   * E04-B09: bonds [deviceId] via `BluetoothDevice.createBond()` (which
   * shows Android's own system pairing-confirmation UI — no custom dialog
   * built here, per the human's 2026-09-11 bonding decision) and defers
   * [doConnect] behind the eventual `BOND_BONDED` outcome for this address,
   * observed through [bondStateReceiver]. A `BOND_NONE` after a
   * `BOND_BONDING` transition (pairing rejected/failed) emits `FAILED`
   * instead of hanging (§ risk in the task file).
   */
  private fun startBondAndConnect(bt: BluetoothAdapter, deviceId: String) {
    val device =
        try {
          bt.getRemoteDevice(deviceId)
        } catch (e: IllegalArgumentException) {
          // Malformed MAC address -- same failure BluetoothAdapter would
          // eventually surface from a direct connect attempt.
          emitFailure(deviceId)
          return
        }
    // Discovery and an active bond attempt compete for the radio, same as
    // discovery vs. connect in doConnect below; Android's own docs recommend
    // cancelling discovery before createBond() for the same reason.
    if (bt.isDiscovering) bt.cancelDiscovery()
    registerBondReceiverIfNeeded()
    pendingBondConnections[deviceId] = { doConnectAfterBond(bt, deviceId) }
    eventsScope.launch { eventsApi.onConnectionStateChanged(deviceId, ConnectionState.CONNECTING) }
    val started =
        try {
          device.createBond()
        } catch (e: SecurityException) {
          false
        }
    if (!started) {
      pendingBondConnections.remove(deviceId)
      emitFailure(deviceId)
    }
  }

  /**
   * Registers [bondStateReceiver] for `ACTION_BOND_STATE_CHANGED`, once —
   * mirrors [registerReceiverIfNeeded]'s lazy-registration shape and its
   * `RECEIVER_EXPORTED` reasoning: `ACTION_BOND_STATE_CHANGED` is likewise
   * sent by `com.android.bluetooth` (a different app/uid), as an explicit
   * broadcast, and is itself a protected system broadcast no third-party
   * app can forge.
   */
  private fun registerBondReceiverIfNeeded() {
    if (bondStateReceiver != null) return
    val receiver =
        object : BroadcastReceiver() {
          override fun onReceive(context: Context?, intent: Intent?) {
            intent ?: return
            if (intent.action == BluetoothDevice.ACTION_BOND_STATE_CHANGED) {
              handleBondStateChanged(intent)
            }
          }
        }
    val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
    ContextCompat.registerReceiver(activity, receiver, filter, ContextCompat.RECEIVER_EXPORTED)
    bondStateReceiver = receiver
  }

  private fun handleBondStateChanged(intent: Intent) {
    val device = deviceFromIntent(intent) ?: return
    val address = device.address ?: return
    val bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
    val continuation = pendingBondConnections[address] ?: return // not something we're waiting on
    when (bondState) {
      BluetoothDevice.BOND_BONDED -> {
        pendingBondConnections.remove(address)
        continuation()
      }
      BluetoothDevice.BOND_NONE -> {
        // Reached BOND_NONE while we were waiting on this exact address --
        // pairing failed or the user rejected/cancelled the system dialog.
        // A clean FAILED, never a hang (§ risk in the task file).
        pendingBondConnections.remove(address)
        emitFailure(address)
      }
      // BOND_BONDING: still in progress, nothing to do yet.
    }
  }

  private fun doConnect(bt: BluetoothAdapter, deviceId: String) {
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
  }

  /**
   * F2 (E04-B09 review fix): connects to [deviceId] right after its bond
   * just completed (`BOND_BONDED`). Unlike [doConnect] -- the proven,
   * already-bonded single-attempt path, left untouched -- this waits
   * [POST_BOND_CONNECT_DELAY_MS] before each attempt (the peer's SDP
   * record may not be resolvable the instant the bond forms) and retries
   * up to [POST_BOND_CONNECT_MAX_ATTEMPTS] times on `IOException` (the
   * transient failure this quirk actually produces). A malformed address
   * or a permission failure is not retried -- those won't resolve by
   * waiting, and existing behavior for [doConnect] already treats them
   * as immediately terminal.
   */
  private fun doConnectAfterBond(bt: BluetoothAdapter, deviceId: String) {
    eventsScope.launch { eventsApi.onConnectionStateChanged(deviceId, ConnectionState.CONNECTING) }

    Thread({
      var connected = false
      var attempt = 0
      while (!connected && attempt < POST_BOND_CONNECT_MAX_ATTEMPTS) {
        attempt++
        try {
          Thread.sleep(POST_BOND_CONNECT_DELAY_MS)
          val device = bt.getRemoteDevice(deviceId)
          val socket = device.createRfcommSocketToServiceRecord(NEXORA_SPP_UUID)
          if (bt.isDiscovering) bt.cancelDiscovery()
          socket.connect() // BLOCKING -- this background thread only.
          openSockets[deviceId] = socket
          startReadLoop(deviceId, socket)
          eventsScope.launch { eventsApi.onConnectionStateChanged(deviceId, ConnectionState.CONNECTED) }
          connected = true
        } catch (e: IOException) {
          // Transient post-bond quirk (SDP record not yet resolvable) --
          // retry once more if attempts remain, per POST_BOND_CONNECT_MAX_ATTEMPTS.
        } catch (e: SecurityException) {
          break // permission failure -- retrying won't help.
        } catch (e: IllegalArgumentException) {
          break // getRemoteDevice() malformed MAC -- retrying won't help.
        } catch (e: InterruptedException) {
          break
        }
      }
      if (!connected) emitFailure(deviceId)
    }, "nexora-bt-connect-$deviceId").start()
  }

  /**
   * E04-B09: fires `ACTION_REQUEST_DISCOVERABLE` (the human-decided,
   * time-boxed discoverability mechanism, 2026-09-11) via
   * `activity.startActivityForResult` — needs a real `Activity` (confirmed
   * held by this class's own constructor, per the task's own top-named
   * risk), not just a `Context`. Fire-and-forget from Dart's perspective:
   * the OS dialog handles user confirmation and there is no settled-state
   * event Pigeon expects back for this call. The eventual
   * `onActivityResult` callback (forwarded by `MainActivity`, mirroring how
   * `onRequestPermissionsResult` is already forwarded) has nothing further
   * to do here — Android reverts discoverability automatically after
   * [DISCOVERABLE_DURATION_SECONDS], with no separate app-level state to
   * track.
   */
  fun requestDiscoverable() {
    val intent =
        Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
          putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, DISCOVERABLE_DURATION_SECONDS)
        }
    try {
      activity.startActivityForResult(intent, REQUEST_DISCOVERABLE_CODE)
    } catch (e: SecurityException) {
      // No BLUETOOTH_ADVERTISE (API 31+) or the adapter is otherwise
      // unavailable -- nothing further this call can do; there is no
      // dedicated failure event for this one-way request (mirrors this
      // method's own doc comment: fire-and-forget).
    }
  }

  /**
   * E04-B19: this device's own Bluetooth name -- what a nearby device's OS
   * pairing UI shows for THIS phone. Never an address (see `pigeons/
   * transport.dart`'s own doc comment for why: a raw address read back from
   * the OS can be a generic, non-unique masked placeholder on some OEM
   * builds, per `E04-B17`/`E04-B18`'s live findings). Falls back to a
   * clearly-labeled placeholder rather than throwing or returning empty --
   * `adapter` is `null` when Bluetooth hardware/permission is unavailable,
   * `BluetoothAdapter.getName()` itself can return `null` even with a live
   * adapter (e.g. name not yet set by the OS), and (review round 1 finding
   * 1) `getName()` requires `BLUETOOTH_CONNECT` on API 31+ and throws
   * `SecurityException` when it is not yet granted -- the exact same
   * permission gap [isBonded] already guards a few lines above, mirrored
   * here rather than left as the one adapter read in this file that skips
   * the file's own established pattern.
   */
  fun getLocalDeviceName(): String =
      (try {
        adapter?.name
      } catch (e: SecurityException) {
        null
      }) ?: "This device (Bluetooth unavailable)"

  /** Forwarded by `TransportApiHost` from
   * `MainActivity.onActivityResult` (E04-B09) — mirrors
   * [onRequestPermissionsResult]'s existing forwarding shape. The
   * discoverable-request result carries no useful payload beyond "the
   * dialog was dismissed" (accept/deny both just mean the system window
   * closed); nothing further needs to run here, since Android alone owns
   * reverting discoverability after the fixed duration.
   */
  fun onActivityResult(requestCode: Int, resultCode: Int) {
    // Currently only REQUEST_DISCOVERABLE_CODE is ever passed through this
    // path -- the `if` exists so a future second activity-result use added
    // to this class doesn't silently get treated as a discoverable-request
    // callback.
    if (requestCode != REQUEST_DISCOVERABLE_CODE) return
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
                // E04-B17 (review round 1, F3): this read loop is the ONLY
                // thing that actually knows a connection died from the
                // REMOTE end (a clean or errored EOF) -- before this, only
                // `disconnect()` (a LOCAL close) ever removed `deviceId`
                // from `openSockets` or emitted `DISCONNECTED`, so a peer
                // that simply walked out of range left a dead socket keyed
                // in `openSockets` forever, with no event telling either
                // this file or Dart the link was gone. That was merely
                // harmless dead weight before this task's own `connect()`
                // idempotency fix (below) started trusting
                // `openSockets.containsKey(deviceId)` as "this link is
                // live" -- after that fix, a stale entry left in place by a
                // remote-initiated drop would make `connect()` re-affirm
                // `CONNECTED` for a corpse forever, and every future send to
                // that peer would fail permanently until the app restarts.
                // Two-arg `remove(deviceId, socket)`, not a plain
                // `remove(deviceId)`: if `disconnect()` already removed
                // (and closed) THIS exact socket first -- the ordinary local
                // teardown path -- this is correctly a no-op (the map no
                // longer maps `deviceId` to `socket`), so `disconnect()`'s
                // own single `DISCONNECTED` emission is never duplicated. It
                // only actually removes and emits when this socket was
                // still the live one, i.e. exactly the remote-drop case this
                // fix closes.
                if (openSockets.remove(deviceId, socket)) {
                  eventsScope.launch { eventsApi.onConnectionStateChanged(deviceId, ConnectionState.DISCONNECTED) }
                }
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
    bondStateReceiver?.let {
      try {
        activity.unregisterReceiver(it)
      } catch (e: IllegalArgumentException) {
        // Not registered — nothing to clean up.
      }
    }
    bondStateReceiver = null
    pendingBondConnections.clear()
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
    // E04-B17 (review round 1, F1/F2): re-derived independently of
    // `resolveDeviceId`'s own internal bonded-list walk -- a genuinely new,
    // not-yet-bonded peer (the overwhelmingly common discovery-scan case)
    // correctly reports `bonded = false` here, so `_reconcileStaleRelationship`
    // never runs for a passing stranger's device.
    val bonded = isBonded(resolvedId)
    eventsScope.launch {
      eventsApi.onDeviceDiscovered(
          TransportDevice(id = resolvedId, displayName = name, type = TransportType.BLUETOOTH, rssi = rssi, bonded = bonded),
      )
    }
  }

  /**
   * Resolves the address to actually report as [TransportDevice.id] for a
   * fresh discovery result (E04-B08). [scannedAddress] is the raw,
   * possibly-randomized address from this `ACTION_FOUND` broadcast;
   * [rawName] is the peer's Bluetooth-visible name straight off
   * `BluetoothDevice.name` (before any address fallback). If [rawName] is
   * non-null/non-empty and matches a currently bonded device's own name
   * exactly, that bonded device's real address is returned instead --
   * bonded devices have a real, stable, connectable address, which the
   * scan result's own address is confirmed (on real hardware) not to be.
   * Falls back to [scannedAddress] unchanged whenever there is no name to
   * match on, no bonded-devices list available (permission denied), or no
   * bonded device's name matches -- the genuinely-new, not-yet-bonded-peer
   * case, where no better address exists yet.
   *
   * **Known ambiguity, not resolved here:** if two bonded devices share the
   * same Bluetooth-visible name, this returns the FIRST match found in
   * `bondedDevices` (a `Set` -- iteration order is not contractually
   * stable), an arbitrary pick between them rather than a correct one. The
   * result is still a genuine bonded address (strictly better than the
   * randomized scan address it replaces), just not necessarily the RIGHT
   * bonded device's address. Two same-named bonded peers is expected to be
   * rare; disambiguating them would need a stronger correlator than name
   * (out of this fix's own scope -- flagged, not silently accepted).
   *
   * **E04-B21 hardening:** confirmed live (2026-09-13) that this method's
   * own fallback -- returning [scannedAddress] unchanged when [rawName] is
   * absent or matches no bonded device -- can produce a value equal to
   * THIS device's own masked address (`adapter?.address`, e.g. a fixed
   * `00:00:46:00:00:01`-shaped placeholder some OEM Bluetooth stacks
   * return for both "my own identity" and, in that same fallback
   * condition, an accepted connection's remote address). Once such a value
   * is used as a `relationships`/conversation key it can never be dialed
   * again -- no real device anywhere has this device's own address. Before
   * ever returning [scannedAddress] as a final answer, this method now
   * checks for exactly that collision and, when there is exactly one
   * bonded device to fall back to (unambiguous -- `acceptLoop`'s own
   * secure-socket precondition already guarantees the real remote peer IS
   * bonded, per this file's header), uses its real address instead.
   * Deliberately narrow: only fires for the confirmed-bad self-referential
   * case, never changes behaviour for a genuinely new, not-yet-bonded peer.
   */
  private fun resolveDeviceId(scannedAddress: String, rawName: String?): String {
    if (!rawName.isNullOrEmpty()) {
      val bondedDevices =
          try {
            adapter?.bondedDevices
          } catch (e: SecurityException) {
            null
          }
      if (bondedDevices != null) {
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
      }
    }
    return unmaskIfSelfReferential(scannedAddress)
  }

  /**
   * E04-B21: the last line of defence against baking this device's own
   * masked address in as if it were a real remote peer's identity (see
   * [resolveDeviceId]'s own doc comment for the full mechanism this
   * guards against). [candidate] is whatever [resolveDeviceId] was about
   * to return as a final answer; if it equals `adapter?.address` (this
   * device's own reported identity -- no real remote peer can ever
   * legitimately equal it), and there is EXACTLY one bonded device to
   * fall back to, that bonded device's real address is used instead.
   * Zero or multiple bonded devices leaves [candidate] unchanged --
   * still wrong, but no worse than before this hardening, and picking
   * arbitrarily among several bonded peers here would risk misattributing
   * a real message exchange to the wrong device, a strictly worse
   * failure mode than the one being fixed.
   */
  private fun unmaskIfSelfReferential(candidate: String): String {
    val selfAddress =
        try {
          adapter?.address
        } catch (e: SecurityException) {
          null
        }
    if (selfAddress == null || candidate != selfAddress) return candidate
    val bondedDevices =
        try {
          adapter?.bondedDevices
        } catch (e: SecurityException) {
          null
        } ?: return candidate
    if (bondedDevices.size != 1) return candidate
    val onlyBonded = bondedDevices.first()
    val onlyBondedAddress =
        try {
          onlyBonded.address
        } catch (e: SecurityException) {
          null
        } ?: return candidate
    return onlyBondedAddress
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
