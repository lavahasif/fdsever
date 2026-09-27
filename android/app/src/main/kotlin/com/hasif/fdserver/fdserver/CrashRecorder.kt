package com.hasif.fdserver.fdserver

import android.content.Context
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object CrashRecorder {
    private const val TAG = "CrashRecorder"
    private const val CRASH_FILE_NAME = "native_crash_logs.json"
    private var isInitialized = false

    fun init(context: Context) {
        if (isInitialized) return
        isInitialized = true

        val oldHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                record(
                    context = context,
                    type = "NATIVE_JVM_UNCAUGHT_EXCEPTION",
                    component = "Thread[${thread.name}]",
                    error = throwable
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to persist uncaught crash: ${e.message}", e)
            } finally {
                oldHandler?.uncaughtException(thread, throwable)
            }
        }
    }

    @Synchronized
    fun record(context: Context, type: String, component: String, error: Throwable, extraContext: Map<String, String>? = null) {
        try {
            val sw = StringWriter()
            error.printStackTrace(PrintWriter(sw))
            val stackTrace = sw.toString()

            val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
            val isoTimestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).format(Date())

            val crashJson = JSONObject().apply {
                put("id", "crash_${System.currentTimeMillis()}")
                put("type", type)
                put("component", component)
                put("timestamp", timestamp)
                put("isoTimestamp", isoTimestamp)
                put("message", error.message ?: error.toString())
                put("stackTrace", stackTrace)
                put("deviceModel", "${Build.MANUFACTURER} ${Build.MODEL} (${Build.DEVICE})")
                put("androidVersion", "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})")
                
                val contextObj = JSONObject()
                extraContext?.forEach { (k, v) -> contextObj.put(k, v) }
                put("context", contextObj)
            }

            val file = File(context.filesDir, CRASH_FILE_NAME)
            val currentArray = if (file.exists()) {
                try {
                    JSONArray(file.readText())
                } catch (_: Exception) {
                    JSONArray()
                }
            } else {
                JSONArray()
            }

            // Prepend newest crash
            val newArray = JSONArray()
            newArray.put(crashJson)
            for (i in 0 until minOf(currentArray.length(), 49)) {
                newArray.put(currentArray.get(i))
            }

            file.writeText(newArray.toString(2))
            Log.e(TAG, "Recorded native crash/error: ${error.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Error writing crash file: ${e.message}")
        }
    }

    @Synchronized
    fun getCrashLogs(context: Context): String {
        val file = File(context.filesDir, CRASH_FILE_NAME)
        return if (file.exists()) file.readText() else "[]"
    }

    @Synchronized
    fun clearCrashLogs(context: Context): Boolean {
        val file = File(context.filesDir, CRASH_FILE_NAME)
        return if (file.exists()) file.delete() else true
    }
}
