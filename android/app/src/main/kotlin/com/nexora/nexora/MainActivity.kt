package com.nexora.nexora

import com.nexora.nexora.transport.TransportApiHost
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * E04-T03a: wires the Pigeon transport host (ADR-0004) into the Flutter
 * engine — additive to whatever else `configureFlutterEngine` already does
 * (Firebase plugins register themselves via their own
 * `FlutterPlugin`/`GeneratedPluginRegistrant` hookup, untouched here).
 */
class MainActivity : FlutterActivity() {
  private var transportApiHost: TransportApiHost? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    val messenger = flutterEngine.dartExecutor.binaryMessenger
    val host = TransportApiHost(messenger)
    host.attach(messenger)
    transportApiHost = host
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    transportApiHost?.detach(flutterEngine.dartExecutor.binaryMessenger)
    transportApiHost = null
    super.cleanUpFlutterEngine(flutterEngine)
  }
}
