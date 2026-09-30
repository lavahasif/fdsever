package com.hasif.fdserver.fdserver.focus_guard

import android.app.*
import android.content.*
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that hosts the NDK native monitor engine.
 * Runs as a lightweight foreground service with a silent notification.
 *
 * Features:
 * - START_STICKY: auto-restart if killed by system
 * - onTaskRemoved: schedule restart via AlarmManager
 * - Registers screen/battery state receivers for power gating
 * - Config sync with FocusAccessibilityService blocked packages
 */
class NativeMonitorService : Service() {

    companion object {
        private const val TAG = "NativeMonitorService"
        const val CHANNEL_ID = "native_monitor_channel"
        const val NOTIFICATION_ID = 889
        const val ACTION_START = "com.hasif.fdserver.NATIVE_MONITOR_START"
        const val ACTION_STOP = "com.hasif.fdserver.NATIVE_MONITOR_STOP"
        const val ACTION_SYNC_CONFIG = "com.hasif.fdserver.NATIVE_MONITOR_SYNC"

        @Volatile
        var isRunning = false
            private set
    }

    private var screenStateReceiver: ScreenStateReceiver? = null
    private var batteryStateReceiver: BatteryStateReceiver? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        NativeMonitorBridge.init(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopMonitoring()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SYNC_CONFIG -> {
                syncConfig()
                return START_STICKY
            }
            else -> {
                startForeground(NOTIFICATION_ID, createNotification())
                startMonitoring()
                return START_STICKY
            }
        }
    }

    private fun startMonitoring() {
        if (isRunning) {
            syncConfig()
            return
        }

        if (!NativeMonitorBridge.isLoaded()) {
            Log.e(TAG, "Native library not loaded — cannot start monitor")
            stopSelf()
            return
        }

        // Load blocked packages from shared config
        FocusAccessibilityService.loadConfig(applicationContext)
        syncConfig()

        // Start native C++ monitor thread
        NativeMonitorBridge.safeStart()

        // Register screen state receiver (Feature #2)
        try {
            screenStateReceiver = ScreenStateReceiver()
            val screenFilter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_USER_PRESENT)
            }
            registerReceiver(screenStateReceiver, screenFilter)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register screen receiver: ${e.message}")
        }

        // Register battery state receiver (Feature #3)
        try {
            batteryStateReceiver = BatteryStateReceiver()
            val batteryFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            registerReceiver(batteryStateReceiver, batteryFilter)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register battery receiver: ${e.message}")
        }

        isRunning = true
        Log.i(TAG, "╔══════════════════════════════════════╗")
        Log.i(TAG, "║  Native Monitor Service STARTED      ║")
        Log.i(TAG, "╚══════════════════════════════════════╝")
    }

    /** Sync current config from SharedPreferences into the native engine */
    private fun syncConfig() {
        try {
            val packages = FocusAccessibilityService.blockedPackages
            NativeMonitorBridge.safeSetBlockedPackages(packages)

            if (NativeMonitorBridge.isLoaded()) {
                NativeMonitorBridge.nativeSetStrictMode(FocusAccessibilityService.isStrictActive)
                NativeMonitorBridge.nativeSetPollInterval(800)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Config sync error: ${e.message}")
        }
    }

    private fun stopMonitoring() {
        NativeMonitorBridge.safeStop()

        try { screenStateReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        try { batteryStateReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        screenStateReceiver = null
        batteryStateReceiver = null

        isRunning = false
        Log.i(TAG, "Native Monitor Service STOPPED")
    }

    private fun createNotification(): Notification {
        // Ensure channel exists
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (manager?.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Focus Guard Monitor",
                    NotificationManager.IMPORTANCE_MIN   // Silent, minimal UI
                ).apply {
                    description = "Background app monitoring for Focus Guard"
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                }
                manager?.createNotificationChannel(channel)
            }
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus Guard Active")
            .setContentText("Protecting your focus")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET) // Hide from lock screen
            .build()
    }

    override fun onDestroy() {
        stopMonitoring()
        super.onDestroy()
    }

    /**
     * Feature #6: Process kill protection.
     * When the user swipes the app from recents, schedule a restart via AlarmManager.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.w(TAG, "Task removed from recents — scheduling restart")
        try {
            val restartIntent = Intent(applicationContext, NativeMonitorService::class.java).apply {
                action = ACTION_START
            }
            val pendingIntent = PendingIntent.getService(
                applicationContext,
                1003,
                restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.set(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + 3000, // Restart after 3 seconds
                pendingIntent
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule restart: ${e.message}")
        }
        super.onTaskRemoved(rootIntent)
    }
}
