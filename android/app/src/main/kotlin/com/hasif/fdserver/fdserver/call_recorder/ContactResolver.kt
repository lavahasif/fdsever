package com.hasif.fdserver.fdserver.call_recorder

import android.content.Context
import android.net.Uri
import android.provider.ContactsContract
import android.util.Log

/**
 * Resolves phone numbers to contact display names using the device's contacts database.
 * Uses ContactsContract.PhoneLookup for fast, normalized phone number matching.
 */
object ContactResolver {
    private const val TAG = "ContactResolver"

    /**
     * Look up the display name for a given phone number from the device contacts.
     * Returns the contact name if found, or null if the number is not in contacts.
     *
     * @param context Application context (requires READ_CONTACTS permission)
     * @param phoneNumber The phone number to look up (can be any format: +971..., 05..., etc.)
     * @return The contact display name, or null if not found or permission denied
     */
    fun resolveContactName(context: Context, phoneNumber: String): String? {
        if (phoneNumber.isBlank() || phoneNumber == "Unknown" || phoneNumber == "VoIP Call") {
            return null
        }

        return try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber)
            )

            val projection = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)

            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        val name = cursor.getString(nameIndex)
                        if (!name.isNullOrBlank()) {
                            Log.i(TAG, "Resolved '$phoneNumber' → '$name'")
                            return@use name.trim()
                        }
                    }
                }
                null
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "READ_CONTACTS permission not granted: ${e.message}")
            null
        } catch (e: Exception) {
            Log.w(TAG, "Failed to resolve contact for '$phoneNumber': ${e.message}")
            null
        }
    }

    /**
     * Determine call direction based on phone state context.
     * @param isOutgoing true if the call was initiated by the user
     * @return "outgoing" or "incoming"
     */
    fun getCallDirection(isOutgoing: Boolean): String {
        return if (isOutgoing) "outgoing" else "incoming"
    }

    /**
     * Sanitize a phone number string for use in filenames.
     * Removes all characters except digits and leading +.
     */
    fun sanitizeForFilename(phoneNumber: String): String {
        return phoneNumber.replace(Regex("[^0-9+]"), "").ifEmpty { "Unknown" }
    }

    /**
     * Generate a display-friendly label combining contact name and number.
     * @return "Ahmed (+971501234567)" or "+971501234567" or "Unknown"
     */
    fun formatDisplayLabel(phoneNumber: String, contactName: String?): String {
        return when {
            !contactName.isNullOrBlank() && phoneNumber.isNotBlank() && phoneNumber != "Unknown" ->
                "$contactName ($phoneNumber)"
            !contactName.isNullOrBlank() -> contactName
            phoneNumber.isNotBlank() && phoneNumber != "Unknown" -> phoneNumber
            else -> "Unknown"
        }
    }
}
