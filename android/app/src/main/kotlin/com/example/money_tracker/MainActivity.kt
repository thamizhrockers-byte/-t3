package com.example.money_tracker

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val channelName = "money_tracker/payment_detection"
    private val prefsName = "payment_detection"
    private val queueKey = "pending_payments"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessEnabled" -> {
                    result.success(isNotificationAccessEnabled())
                }

                "openNotificationAccessSettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "SETTINGS_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                "getPendingPayments" -> {
                    val prefs = getSharedPreferences(
                        prefsName,
                        MODE_PRIVATE
                    )

                    result.success(
                        prefs.getString(queueKey, "[]") ?: "[]"
                    )
                }

                "removePayment" -> {
                    val id = call.argument<String>("id")

                    if (id.isNullOrBlank()) {
                        result.error(
                            "BAD_ID",
                            "Payment id is missing.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    removePayment(id)
                    result.success(true)
                }

                "clearPendingPayments" -> {
                    getSharedPreferences(
                        prefsName,
                        MODE_PRIVATE
                    ).edit()
                        .putString(queueKey, "[]")
                        .apply()

                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isNotificationAccessEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false

        val component = ComponentName(
            this,
            NotificationPaymentListener::class.java
        ).flattenToString()

        return enabled
            .split(":")
            .any { it == component }
    }

    private fun removePayment(id: String) {
        val prefs = getSharedPreferences(
            prefsName,
            MODE_PRIVATE
        )

        val original = JSONArray(
            prefs.getString(queueKey, "[]") ?: "[]"
        )

        val updated = JSONArray()

        for (index in 0 until original.length()) {
            val item = original.optJSONObject(index)
                ?: continue

            if (item.optString("id") != id) {
                updated.put(item)
            }
        }

        prefs.edit()
            .putString(
                queueKey,
                updated.toString()
            )
            .apply()
    }
}
