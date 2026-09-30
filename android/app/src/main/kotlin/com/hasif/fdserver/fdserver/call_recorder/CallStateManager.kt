package com.hasif.fdserver.fdserver.call_recorder

import android.content.Context
import android.os.Build
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log

/**
 * Monitors cellular phone call state using 100% public Android APIs.
 * Supports API 29 through API 36 with TelephonyCallback / PhoneStateListener.
 */
class CallStateManager(private val context: Context) {

    companion object {
        private const val TAG = "CallStateManager"
        const val STATE_IDLE = "IDLE"
        const val STATE_RINGING = "RINGING"
        const val STATE_OFFHOOK = "OFFHOOK"
    }

    private val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
    private var isListening = false

    var currentCallState: String = STATE_IDLE
        private set

    var onCallStateChanged: ((state: String, incomingNumber: String?) -> Unit)? = null

    // For Android 12+ (API 31+)
    private var telephonyCallback: Any? = null

    // For Android 10-11 (API 29-30)
    private var legacyListener: PhoneStateListener? = null

    fun startListening() {
        if (isListening || telephonyManager == null) return

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val callback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) {
                        handleState(state, null)
                    }
                }
                telephonyManager.registerTelephonyCallback(context.mainExecutor, callback)
                telephonyCallback = callback
            } else {
                @Suppress("DEPRECATION")
                val listener = object : PhoneStateListener() {
                    @Deprecated("Deprecated in Java")
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                        handleState(state, phoneNumber)
                    }
                }
                @Suppress("DEPRECATION")
                telephonyManager.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
                legacyListener = listener
            }
            isListening = true
            Log.i(TAG, "Telephony call state listener registered")
        } catch (e: SecurityException) {
            Log.w(TAG, "READ_PHONE_STATE permission not granted: ${e.message}")
        } catch (t: Throwable) {
            Log.e(TAG, "Error starting call state listener: ${t.message}")
        }
    }

    private fun handleState(state: Int, phoneNumber: String?) {
        val stateStr = when (state) {
            TelephonyManager.CALL_STATE_RINGING -> STATE_RINGING
            TelephonyManager.CALL_STATE_OFFHOOK -> STATE_OFFHOOK
            TelephonyManager.CALL_STATE_IDLE -> STATE_IDLE
            else -> STATE_IDLE
        }

        if (stateStr != currentCallState) {
            currentCallState = stateStr
            Log.i(TAG, "Call state transition → $stateStr")
            onCallStateChanged?.invoke(stateStr, phoneNumber)
        }
    }

    fun stopListening() {
        if (!isListening || telephonyManager == null) return

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (telephonyCallback as? TelephonyCallback)?.let {
                    telephonyManager.unregisterTelephonyCallback(it)
                }
                telephonyCallback = null
            } else {
                @Suppress("DEPRECATION")
                legacyListener?.let {
                    telephonyManager.listen(it, PhoneStateListener.LISTEN_NONE)
                }
                legacyListener = null
            }
            isListening = false
            Log.i(TAG, "Telephony listener unregistered")
        } catch (t: Throwable) {
            Log.e(TAG, "Error stopping telephony listener: ${t.message}")
        }
    }
}
