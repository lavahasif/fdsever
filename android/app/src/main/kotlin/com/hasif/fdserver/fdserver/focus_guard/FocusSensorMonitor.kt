package com.hasif.fdserver.fdserver.focus_guard

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.BatteryManager
import android.util.Log
import com.hasif.fdserver.fdserver.audit.AuditTrailDb
import java.util.Calendar

/**
 * Handles hardware telemetry for advanced Focus Guard & Audit Trail features:
 * - Feature #62: Commute & Driving Shield (Speed calculation)
 * - Feature #64: Sleep Sanctuary (Night time & stationary tracking)
 * - Feature #65: Walk-to-Unlock / Kinetic Quota (Step counting & banking)
 * - Feature #67: Attention Fragmentation Auditor (Sliding window of app hops)
 * - Feature #68: Emergency Distress Bypass Controller
 * - Feature #69: Battery-Aware Travel Throttle
 */
class FocusSensorMonitor private constructor(private val context: Context) : SensorEventListener {

    companion object {
        private const val TAG = "FocusSensorMonitor"
        private const val PREFS_SENSORS = "focus_sensor_prefs"
        private const val KEY_STEPS_BANKED = "kinetic_steps_banked"
        private const val KEY_MINUTES_EARNED = "kinetic_minutes_earned"
        private const val KEY_EMERGENCY_UNTIL = "emergency_bypass_until_ts"

        @Volatile
        private var instance: FocusSensorMonitor? = null

        fun getInstance(context: Context): FocusSensorMonitor {
            return instance ?: synchronized(this) {
                instance ?: FocusSensorMonitor(context).also { instance = it }
            }
        }
    }

    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private var initialStepCount: Float = -1f
    private var todaySteps: Int = 0

    // Feature #67: App-hopping sliding window
    private val appHopHistory = mutableListOf<Pair<Long, String>>()

    // Feature #68: Emergency bypass timestamp
    var emergencyBypassUntilMs: Long = 0L
        private set

    init {
        val prefs = context.getSharedPreferences(PREFS_SENSORS, Context.MODE_PRIVATE)
        emergencyBypassUntilMs = prefs.getLong(KEY_EMERGENCY_UNTIL, 0L)
        startStepSensor()
    }

    private fun startStepSensor() {
        try {
            val stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
            if (stepSensor != null) {
                sensorManager?.registerListener(this, stepSensor, SensorManager.SENSOR_DELAY_UI)
                Log.i(TAG, "Hardware Step Counter sensor registered")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Step sensor registration skipped: ${e.message}")
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER) {
            val totalSteps = event.values[0]
            if (initialStepCount < 0) {
                initialStepCount = totalSteps
            }
            val delta = (totalSteps - initialStepCount).toInt()
            if (delta > todaySteps) {
                todaySteps = delta
                // Every 1,000 steps banks 15 minutes of kinetic screen time
                val earnedMinutes = (todaySteps / 1000) * 15
                context.getSharedPreferences(PREFS_SENSORS, Context.MODE_PRIVATE).edit()
                    .putInt(KEY_STEPS_BANKED, todaySteps)
                    .putInt(KEY_MINUTES_EARNED, earnedMinutes)
                    .apply()
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    fun getBankedSteps(): Int = todaySteps

    fun getEarnedKineticMinutes(): Int {
        val prefs = context.getSharedPreferences(PREFS_SENSORS, Context.MODE_PRIVATE)
        return prefs.getInt(KEY_MINUTES_EARNED, 0)
    }

    /**
     * Feature #62: Commute & Driving Shield (Speed > 25 km/h)
     */
    fun isDrivingSpeed(speedMps: Float): Boolean {
        val speedKmh = speedMps * 3.6f
        val isDriving = speedKmh > 25.0f
        if (isDriving) {
            Log.d(TAG, "Commute / Driving speed detected: %.1f km/h".format(speedKmh))
        }
        return isDriving
    }

    /**
     * Feature #64: Sleep Sanctuary (Bedtime active between 11 PM and 6 AM)
     */
    fun isSleepSanctuaryTime(): Boolean {
        val cal = Calendar.getInstance()
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        return hour >= 23 || hour < 6
    }

    /**
     * Feature #67: Attention Fragmentation Auditor
     * Returns true if user has hopped between 4+ different apps within the last 60 seconds.
     */
    @Synchronized
    fun recordAppHopAndCheckFragmentation(pkg: String): Boolean {
        val now = System.currentTimeMillis()
        appHopHistory.add(Pair(now, pkg))
        // Prune older than 60s
        appHopHistory.removeAll { (ts, _) -> now - ts > 60_000L }

        // Count unique packages in last 60s
        val uniqueRecentPkgs = appHopHistory.map { it.second }.distinct().size
        val isFragmented = uniqueRecentPkgs >= 4
        if (isFragmented) {
            Log.w(TAG, "High Attention Fragmentation detected: $uniqueRecentPkgs app switches in 60s!")
            AuditTrailDb.getInstance(context).logEvent(
                eventType = "ATTENTION_FRAGMENTATION",
                packageName = pkg,
                category = "Audit & Geospatial",
                payload = "Rapid context switching detected ($uniqueRecentPkgs unique apps within 60s). Mindful breathing recommended."
            )
        }
        return isFragmented
    }

    /**
     * Feature #68: Trigger 5-Minute Emergency Distress Bypass with immutable GPS logging.
     */
    fun triggerEmergencyBypass(reason: String, latitude: Double = 0.0, longitude: Double = 0.0): Long {
        val now = System.currentTimeMillis()
        emergencyBypassUntilMs = now + (5 * 60 * 1000L) // 5 minutes
        context.getSharedPreferences(PREFS_SENSORS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_EMERGENCY_UNTIL, emergencyBypassUntilMs)
            .apply()

        AuditTrailDb.getInstance(context).logEvent(
            eventType = "EMERGENCY_BYPASS_ACTIVATED",
            packageName = null,
            category = "Audit & Geospatial",
            payload = "EMERGENCY BYPASS TRIGGERED: 5-minute unlock granted. Reason: $reason",
            latitude = latitude,
            longitude = longitude
        )

        Log.w(TAG, "Emergency Distress Bypass activated until $emergencyBypassUntilMs")
        return emergencyBypassUntilMs
    }

    fun isEmergencyBypassActive(): Boolean {
        val now = System.currentTimeMillis()
        return now < emergencyBypassUntilMs
    }

    fun getEmergencyBypassRemainingSeconds(): Long {
        val diff = emergencyBypassUntilMs - System.currentTimeMillis()
        return if (diff > 0) diff / 1000L else 0L
    }

    fun getUsedKineticMinutes(): Int {
        val prefs = context.getSharedPreferences(PREFS_SENSORS, Context.MODE_PRIVATE)
        return prefs.getInt("kinetic_minutes_used", 0)
    }

    fun consumeKineticMinutes(minutes: Int): Boolean {
        val earned = getEarnedKineticMinutes()
        val used = getUsedKineticMinutes()
        val remaining = (earned - used).coerceAtLeast(0)
        if (minutes <= remaining) {
            val prefs = context.getSharedPreferences(PREFS_SENSORS, Context.MODE_PRIVATE)
            prefs.edit().putInt("kinetic_minutes_used", used + minutes).apply()
            AuditTrailDb.getInstance(context).logEvent(
                eventType = "KINETIC_QUOTA_CONSUMED",
                packageName = null,
                category = "Audit & Geospatial",
                payload = "Consumed $minutes min of kinetic screen time quota ($todaySteps steps banked)"
            )
            return true
        }
        return false
    }

    private var currentSpeedKmh: Float = 0.0f

    fun recordGpsSpeed(speedMps: Float): Boolean {
        currentSpeedKmh = speedMps * 3.6f
        val driving = currentSpeedKmh > 25.0f
        if (driving) {
            AuditTrailDb.getInstance(context).logEvent(
                eventType = "DRIVING_SHIELD_TRIGGERED",
                packageName = null,
                category = "Audit & Geospatial",
                payload = "Driving speed of %.1f km/h detected. Media & video feeds locked for safety.".format(currentSpeedKmh)
            )
        }
        return driving
    }

    fun getCurrentSpeedKmh(): Float = currentSpeedKmh

    fun isDrivingCommuteShieldActive(): Boolean = currentSpeedKmh > 25.0f

    /**
     * Feature #69: Battery-Aware Travel Throttle (<30% battery)
     */
    fun isLowBatteryAwayFromHome(isAwayFromHome: Boolean): Boolean {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val level = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 100
        val isLow = level < 30
        return isAwayFromHome && isLow
    }

    fun getBatteryLevel(): Int {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        return batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 100
    }
}
