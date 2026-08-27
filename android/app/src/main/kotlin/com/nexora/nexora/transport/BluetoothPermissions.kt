package com.nexora.nexora.transport

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/**
 * Runtime Bluetooth permission handling (E04-T03b, FR-PLAT-002),
 * version-branched on `Build.VERSION.SDK_INT`:
 * - API 31+ (Android 12+): `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT`, both
 *   dangerous/runtime permissions under the modern Bluetooth permission
 *   model.
 * - API <31: the legacy pair `BLUETOOTH`/`BLUETOOTH_ADMIN` (normal,
 *   install-time permissions — requesting them at runtime is harmless, they
 *   report granted immediately) plus `ACCESS_FINE_LOCATION`, which Android
 *   has historically required at runtime for Bluetooth *discovery* to
 *   actually return scan results pre-Android-12.
 */
object BluetoothPermissions {
  /** Pigeon-boundary-unrelated request code — only used locally between
   * `ActivityCompat.requestPermissions` and `Activity.onRequestPermissionsResult`. */
  const val REQUEST_CODE = 4200

  fun required(): Array<String> =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
      } else {
        arrayOf(
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_ADMIN,
            Manifest.permission.ACCESS_FINE_LOCATION,
        )
      }

  fun hasAll(context: Context): Boolean =
      required().all {
        ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
      }

  fun requestAll(activity: Activity) {
    ActivityCompat.requestPermissions(activity, required(), REQUEST_CODE)
  }
}
