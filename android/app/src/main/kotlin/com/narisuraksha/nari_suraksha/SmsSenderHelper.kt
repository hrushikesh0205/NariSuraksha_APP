package com.narisuraksha.nari_suraksha

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import android.util.Log

/**
 * Isolated helper for sending SMS directly via Android [SmsManager].
 *
 * Features:
 * - Multipart message support (emergency messages exceed 160 chars)
 * - Per-message sent/delivery result tracking via PendingIntent
 * - Graceful handling of invalid phone numbers and missing telephony
 * - Does NOT open the SMS composer — sends silently in the background
 */
class SmsSenderHelper(private val activity: Activity) {

    companion object {
        private const val TAG = "SmsSenderHelper"
        private const val ACTION_SMS_SENT = "com.narisuraksha.SMS_SENT"
    }

    /**
     * Sends an SMS message directly to [phoneNumber] with [message] body.
     *
     * @return A map with keys: "success" (Boolean), "error" (String? if failed)
     */
    fun sendSms(phoneNumber: String, message: String, callback: (Map<String, Any?>) -> Unit) {
        try {
            if (phoneNumber.isBlank()) {
                callback(mapOf("success" to false, "error" to "Phone number is empty"))
                return
            }

            if (message.isBlank()) {
                callback(mapOf("success" to false, "error" to "Message is empty"))
                return
            }

            // Clean phone number — keep digits and leading +
            val cleanPhone = phoneNumber.trim().let { raw ->
                val hasPlus = raw.startsWith("+")
                val digits = raw.replace(Regex("[^\\d]"), "")
                if (hasPlus) "+$digits" else digits
            }

            if (cleanPhone.length < 7) {
                callback(mapOf("success" to false, "error" to "Invalid phone number: too short"))
                return
            }

            Log.d(TAG, "Sending SMS to: $cleanPhone (length: ${message.length} chars)")

            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                activity.getSystemService(SmsManager::class.java) ?: @Suppress("DEPRECATION") SmsManager.getDefault()
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            if (smsManager == null) {
                callback(mapOf("success" to false, "error" to "SMS service unavailable on this device"))
                return
            }

            // Create unique sent intent for tracking
            val uniqueId = java.util.UUID.randomUUID().toString()
            val sentAction = "${ACTION_SMS_SENT}_${System.currentTimeMillis()}_$uniqueId"
            val baseRequestCode = (System.currentTimeMillis() % 100000).toInt()
            val sentIntent = PendingIntent.getBroadcast(
                activity,
                baseRequestCode,
                Intent(sentAction),
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )

            // Setup timeout safety (15 seconds) so callback never hangs indefinitely
            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            var isHandled = false
            var receiver: BroadcastReceiver? = null

            val timeoutRunnable = Runnable {
                if (!isHandled) {
                    isHandled = true
                    try {
                        receiver?.let { activity.unregisterReceiver(it) }
                    } catch (_: Exception) {}
                    Log.w(TAG, "SMS send timeout for $cleanPhone")
                    callback(mapOf("success" to false, "error" to "SMS send timeout (no response from radio)"))
                }
            }
            handler.postDelayed(timeoutRunnable, 15000)

            // Register receiver to get send result
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (isHandled) return
                    isHandled = true
                    handler.removeCallbacks(timeoutRunnable)

                    try {
                        activity.unregisterReceiver(this)
                    } catch (e: Exception) {
                        Log.w(TAG, "Receiver already unregistered: ${e.message}")
                    }

                    when (resultCode) {
                        Activity.RESULT_OK -> {
                            Log.d(TAG, "SMS sent successfully to $cleanPhone")
                            callback(mapOf("success" to true, "error" to null))
                        }
                        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> {
                            Log.e(TAG, "SMS generic failure for $cleanPhone")
                            callback(mapOf("success" to false, "error" to "SMS send failed (generic failure)"))
                        }
                        SmsManager.RESULT_ERROR_NO_SERVICE -> {
                            Log.e(TAG, "SMS no service for $cleanPhone")
                            callback(mapOf("success" to false, "error" to "No cellular service"))
                        }
                        SmsManager.RESULT_ERROR_NULL_PDU -> {
                            Log.e(TAG, "SMS null PDU for $cleanPhone")
                            callback(mapOf("success" to false, "error" to "SMS send failed (null PDU)"))
                        }
                        SmsManager.RESULT_ERROR_RADIO_OFF -> {
                            Log.e(TAG, "SMS radio off for $cleanPhone")
                            callback(mapOf("success" to false, "error" to "Cellular radio is off"))
                        }
                        else -> {
                            Log.e(TAG, "SMS unknown error ($resultCode) for $cleanPhone")
                            callback(mapOf("success" to false, "error" to "SMS send failed (code: $resultCode)"))
                        }
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.registerReceiver(receiver, IntentFilter(sentAction), Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                activity.registerReceiver(receiver, IntentFilter(sentAction))
            }

            // Check if message needs multipart
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                Log.d(TAG, "Sending multipart SMS (${parts.size} parts) to $cleanPhone")
                val sentIntents = ArrayList<PendingIntent>()
                // Track parts, only the last part's status completes the delivery
                for (i in parts.indices) {
                    if (i == parts.size - 1) {
                        sentIntents.add(sentIntent)
                    } else {
                        sentIntents.add(
                            PendingIntent.getBroadcast(
                                activity,
                                baseRequestCode + i + 1,
                                Intent("${sentAction}_part_$i"),
                                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
                            )
                        )
                    }
                }
                smsManager.sendMultipartTextMessage(cleanPhone, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(cleanPhone, null, message, sentIntent, null)
            }

        } catch (e: SecurityException) {
            Log.e(TAG, "SMS permission denied: ${e.message}")
            callback(mapOf("success" to false, "error" to "SMS permission denied"))
        } catch (e: Exception) {
            Log.e(TAG, "SMS send exception: ${e.message}", e)
            callback(mapOf("success" to false, "error" to "SMS send error: ${e.message}"))
        }
    }

    /**
     * Checks if the device has telephony/SMS capability.
     */
    fun hasSmsCapability(): Boolean {
        return activity.packageManager.hasSystemFeature("android.hardware.telephony")
    }
}
