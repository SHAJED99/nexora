package com.nexora.nexora

import com.nexora.nexora.transport.TransportApiHost
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * E04-T03a/T03b: wires the Pigeon transport host (ADR-0004) into the
 * Flutter engine — additive to whatever else `configureFlutterEngine`
 * already does (Firebase plugins register themselves via their own
 * `FlutterPlugin`/`GeneratedPluginRegistrant` hookup, untouched here).
 *
 * E04-T03b adds `onRequestPermissionsResult`: `BluetoothTransport` needs an
 * `Activity` to request the runtime Bluetooth permissions (FR-PLAT-002),
 * and the result only reaches it by the host `Activity` forwarding its own
 * callback — there's no other path for a non-Fragment permission request.
 */
class MainActivity : FlutterActivity() {
  private var transportApiHost: TransportApiHost? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    val messenger = flutterEngine.dartExecutor.binaryMessenger
    val host = TransportApiHost(messenger, this)
    host.attach(messenger)
    transportApiHost = host
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    transportApiHost?.detach(flutterEngine.dartExecutor.binaryMessenger)
    transportApiHost = null
    super.cleanUpFlutterEngine(flutterEngine)
  }

  override fun onRequestPermissionsResult(
      requestCode: Int,
      permissions: Array<out String>,
      grantResults: IntArray,
  ) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    transportApiHost?.onRequestPermissionsResult(requestCode, grantResults)
  }
}
