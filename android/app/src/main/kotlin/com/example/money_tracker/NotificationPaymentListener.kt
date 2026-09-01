package com.example.money_tracker

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class NotificationPaymentListener : NotificationListenerService() {
    private val prefsName = "payment_detection"
    private val queueKey = "pending_payments"

    private val amountRegex = Regex(
        """(?i)(?:₹|rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)"""
    )

    private val bankRegex = Regex(
        """(?i)(?:a/c|acct|account|card)\s*(?:no\.?|ending)?\s*(?:x+|\*+)?\s*([0-9]{2,4})"""
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        if (sbn.packageName == packageName) {
            return
        }

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras
            .getCharSequence(Notification.EXTRA_TITLE)
            ?.toString()
            ?.trim()
            .orEmpty()

        val text = extras
            .getCharSequence(Notification.EXTRA_TEXT)
            ?.toString()
            ?.trim()
            .orEmpty()

        val bigText = extras
            .getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?.toString()
            ?.trim()
            .orEmpty()

        val combined = listOf(
            title,
            text,
            bigText
        )
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString(" · ")
            .trim()

        if (combined.isBlank()) return

        val candidate = parseCandidate(
            packageName = sbn.packageName,
            title = title,
            rawText = combined,
            timestamp = sbn.postTime
        ) ?: return

        saveCandidate(candidate)
    }

    private fun parseCandidate(
        packageName: String,
        title: String,
        rawText: String,
        timestamp: Long
    ): JSONObject? {
        val lower = rawText.lowercase()

        val rejectWords = listOf(
            "failed",
            "declined",
            "unsuccessful",
            "payment request",
            "collect request",
            "offer",
            "win ₹",
            "win rs",
            "reward points"
        )

        if (rejectWords.any { lower.contains(it) }) {
            return null
        }

        val amountMatch = amountRegex.find(rawText)
            ?: return null

        val amount = amountMatch
            .groupValues[1]
            .replace(",", "")
            .toDoubleOrNull()
            ?: return null

        if (amount <= 0) return null

        val transaction = determineTransaction(lower)
            ?: return null

        val recipient = detectCounterparty(
            rawText,
            transaction
        )

        val bank = bankRegex.find(rawText)
            ?.groupValues
            ?.getOrNull(1)
            ?.let { "••••$it" }
            .orEmpty()

        val mode = detectMode(
            packageName,
            lower
        )

        val sourceApp = resolveAppLabel(
            packageName
        )

        var confidence = 70

        if (isKnownPaymentSource(packageName)) {
            confidence += 15
        } else if (
            lower.contains("a/c") ||
            lower.contains("account") ||
            lower.contains("upi") ||
            lower.contains("txn") ||
            lower.contains("transaction")
        ) {
            confidence += 10
        }

        if (recipient.isNotBlank()) {
            confidence += 10
        }

        if (bank.isNotBlank()) {
            confidence += 5
        }

        if (confidence < 75) {
            return null
        }

        return JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("timestamp", timestamp)
            put("sourcePackage", packageName)
            put("sourceApp", sourceApp)
            put("title", title)
            put("rawText", rawText)
            put("transaction", transaction)
            put("amount", amount)
            put("to", recipient)
            put("detectedBank", bank)
            put("mode", mode)
            put("confidence", confidence.coerceAtMost(100))
        }
    }

    private fun determineTransaction(
        lower: String
    ): String? {
        if (
            lower.contains("debited") ||
            lower.contains("paid to") ||
            lower.contains("sent to") ||
            lower.contains("spent") ||
            lower.contains("purchase") ||
            lower.contains("withdrawn")
        ) {
            return "Paid"
        }

        if (
            lower.contains("credited") ||
            lower.contains("received from") ||
            lower.contains("money received") ||
            lower.contains("refund") ||
            lower.contains("refunded")
        ) {
            return "Received"
        }

        if (lower.contains(" paid ")) {
            return "Paid"
        }

        if (lower.contains(" received ")) {
            return "Received"
        }

        return null
    }

    private fun detectCounterparty(
        text: String,
        transaction: String
    ): String {
        val pattern = if (transaction == "Received") {
            Regex(
                """(?i)\bfrom\s+([A-Za-z0-9][A-Za-z0-9 .&@'_-]{1,40}?)(?=\s+(?:on|via|using|ref|upi|txn|transaction|for|a/c|acct|account)\b|[,.]|$)"""
            )
        } else {
            Regex(
                """(?i)\b(?:to|at)\s+([A-Za-z0-9][A-Za-z0-9 .&@'_-]{1,40}?)(?=\s+(?:on|via|using|ref|upi|txn|transaction|for|from|a/c|acct|account)\b|[,.]|$)"""
            )
        }

        return pattern
            .find(text)
            ?.groupValues
            ?.getOrNull(1)
            ?.trim()
            .orEmpty()
    }

    private fun detectMode(
        packageName: String,
        lower: String
    ): String {
        val pkg = packageName.lowercase()

        if (
            pkg.contains("phonepe") ||
            pkg.contains("paisa") ||
            pkg.contains("paytm") ||
            pkg.contains("upiapp") ||
            lower.contains("upi") ||
            lower.contains("vpa")
        ) {
            return "UPI"
        }

        if (
            lower.contains("debit card") ||
            lower.contains("credit card") ||
            lower.contains(" card ") ||
            lower.contains("pos ")
        ) {
            return "Card"
        }

        if (
            lower.contains("imps") ||
            lower.contains("neft") ||
            lower.contains("rtgs") ||
            lower.contains("net banking") ||
            lower.contains("netbanking")
        ) {
            return "Net Banking"
        }

        return "Unknown"
    }

    private fun isKnownPaymentSource(
        packageName: String
    ): Boolean {
        val pkg = packageName.lowercase()

        return pkg.contains("phonepe") ||
            pkg.contains("paisa") ||
            pkg.contains("paytm") ||
            pkg.contains("upiapp") ||
            pkg.contains("bank") ||
            pkg.contains("banking")
    }

    private fun resolveAppLabel(
        sourcePackage: String
    ): String {
        return try {
            val info = packageManager.getApplicationInfo(
                sourcePackage,
                0
            )

            packageManager
                .getApplicationLabel(info)
                .toString()
        } catch (_: Exception) {
            sourcePackage
        }
    }

    private fun saveCandidate(
        candidate: JSONObject
    ) {
        val prefs = getSharedPreferences(
            prefsName,
            MODE_PRIVATE
        )

        val queue = JSONArray(
            prefs.getString(
                queueKey,
                "[]"
            ) ?: "[]"
        )

        val rawText = candidate
            .optString("rawText")
            .trim()

        val timestamp = candidate
            .optLong("timestamp")

        for (index in 0 until queue.length()) {
            val existing = queue
                .optJSONObject(index)
                ?: continue

            val sameText =
                existing.optString("rawText")
                    .trim() == rawText

            val closeInTime =
                kotlin.math.abs(
                    existing.optLong("timestamp") -
                        timestamp
                ) < 120_000

            if (sameText && closeInTime) {
                return
            }
        }

        queue.put(candidate)

        val trimmedQueue = JSONArray()

        val start = (queue.length() - 20)
            .coerceAtLeast(0)

        for (index in start until queue.length()) {
            trimmedQueue.put(
                queue.get(index)
            )
        }

        prefs.edit()
            .putString(
                queueKey,
                trimmedQueue.toString()
            )
            .apply()
    }
}
