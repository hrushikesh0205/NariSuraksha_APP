package com.narisuraksha.nari_suraksha

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Main activity with a MethodChannel for native SMS sending.
 *
 * Channel: `com.narisuraksha/sms`
 *
 * Methods:
 * - `sendSms(phone: String, message: String)` → `{success: bool, error: String?}`
 * - `checkSmsPermission()` → `{granted: bool, permanentlyDenied: bool}`
 * - `requestSmsPermission()` → `{granted: bool}`
 * - `hasSmsCapability()` → `bool`
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.narisuraksha/sms"
        private const val TAG = "MainActivity"
        private const val SMS_PERMISSION_REQUEST_CODE = 1001
    }

    private var smsSenderHelper: SmsSenderHelper? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        smsSenderHelper = SmsSenderHelper(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")

                    if (phone == null || message == null) {
                        result.error("INVALID_ARGS", "phone and message are required", null)
                        return@setMethodCallHandler
                    }

                    // Check permission first
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS)
                        != PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(mapOf("success" to false, "error" to "SEND_SMS permission not granted"))
                        return@setMethodCallHandler
                    }

                    smsSenderHelper?.sendSms(phone, message) { sendResult ->
                        runOnUiThread {
                            result.success(sendResult)
                        }
                    }
                }

                "checkSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
                            PackageManager.PERMISSION_GRANTED

                    // Check if permanently denied (shouldShowRequestPermissionRationale returns false
                    // when permission was never asked OR when permanently denied)
                    val permanentlyDenied = !granted &&
                            !ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.SEND_SMS)

                    result.success(
                        mapOf(
                            "granted" to granted,
                            "permanentlyDenied" to permanentlyDenied
                        )
                    )
                }

                "requestSmsPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(mapOf("granted" to true))
                        return@setMethodCallHandler
                    }

                    pendingPermissionResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.SEND_SMS),
                        SMS_PERMISSION_REQUEST_CODE
                    )
                }

                "hasSmsCapability" -> {
                    result.success(smsSenderHelper?.hasSmsCapability() ?: false)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED

            Log.d(TAG, "SMS permission result: granted=$granted")

            pendingPermissionResult?.success(mapOf("granted" to granted))
            pendingPermissionResult = null
        }
    }
}
