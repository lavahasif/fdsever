package com.hasif.fdserver.fdserver.focus_guard

import android.content.Context
import android.location.Location
import android.util.Log
import com.hasif.fdserver.fdserver.audit.AuditTrailDb
import org.json.JSONArray
import org.json.JSONObject

/**
 * Feature #61 & #66: Geofenced Focus Zones + Wi-Fi Auto-Shield.
 * Automatically checks coordinates against user-configured Focus Zones (Work, Library, Mosque, etc.)
 * and detects designated corporate/school Wi-Fi networks to trigger Strict Focus Mode.
 */
class GeofenceFocusManager private constructor(private val context: Context) {

    data class FocusZone(
        val id: String,
        val name: String,
        val latitude: Double,
        val longitude: Double,
        val radiusMeters: Float,
        val strictMode: Boolean = true
    )

    companion object {
        private const val TAG = "GeofenceFocusManager"
        private const val PREFS_ZONES = "geofence_focus_zones"
        private const val KEY_ZONES_JSON = "zones_json"
        private const val KEY_WIFI_SSIDS = "wifi_shield_ssids"

        @Volatile
        private var instance: GeofenceFocusManager? = null

        fun getInstance(context: Context): GeofenceFocusManager {
            return instance ?: synchronized(this) {
                instance ?: GeofenceFocusManager(context).also { instance = it }
            }
        }
    }

    private val activeZones = mutableListOf<FocusZone>()
    private val wifiShieldSsids = mutableSetOf<String>()
    var isInFocusZone: Boolean = false
        private set
    var currentActiveZoneName: String? = null
        private set
    var lastKnownLatitude: Double = 0.0
        private set
    var lastKnownLongitude: Double = 0.0
        private set

    init {
        loadConfig()
    }

    fun getLastKnownLocation(): Pair<Double, Double>? {
        return if (lastKnownLatitude != 0.0 || lastKnownLongitude != 0.0) {
            Pair(lastKnownLatitude, lastKnownLongitude)
        } else {
            null
        }
    }

    fun getZonesJson(): String {
        val prefs = context.getSharedPreferences(PREFS_ZONES, Context.MODE_PRIVATE)
        return prefs.getString(KEY_ZONES_JSON, "[]") ?: "[]"
    }

    fun getWifiSsids(): List<String> {
        return wifiShieldSsids.toList()
    }

    fun loadConfig() {
        val prefs = context.getSharedPreferences(PREFS_ZONES, Context.MODE_PRIVATE)
        val rawJson = prefs.getString(KEY_ZONES_JSON, null)
        activeZones.clear()
        if (!rawJson.isNullOrBlank()) {
            try {
                val array = JSONArray(rawJson)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    activeZones.add(
                        FocusZone(
                            id = obj.getString("id"),
                            name = obj.getString("name"),
                            latitude = obj.getDouble("latitude"),
                            longitude = obj.getDouble("longitude"),
                            radiusMeters = obj.getDouble("radiusMeters").toFloat(),
                            strictMode = obj.optBoolean("strictMode", true)
                        )
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading geofence zones: ${e.message}")
            }
        }

        wifiShieldSsids.clear()
        val ssids = prefs.getStringSet(KEY_WIFI_SSIDS, null)
        if (ssids != null) {
            wifiShieldSsids.addAll(ssids)
        }
    }

    fun saveZones(zonesJson: String) {
        val prefs = context.getSharedPreferences(PREFS_ZONES, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_ZONES_JSON, zonesJson).apply()
        loadConfig()
    }

    fun saveWifiSsids(ssids: Set<String>) {
        val prefs = context.getSharedPreferences(PREFS_ZONES, Context.MODE_PRIVATE)
        prefs.edit().putStringSet(KEY_WIFI_SSIDS, ssids).apply()
        loadConfig()
    }

    /**
     * Evaluates current GPS location against all configured focus zones.
     */
    fun evaluateLocation(lat: Double, lng: Double): Boolean {
        lastKnownLatitude = lat
        lastKnownLongitude = lng
        if (activeZones.isEmpty()) return false

        val currentLocation = Location("audit").apply {
            latitude = lat
            longitude = lng
        }

        var matchedZone: FocusZone? = null
        for (zone in activeZones) {
            val zoneLoc = Location("zone").apply {
                latitude = zone.latitude
                longitude = zone.longitude
            }
            val distance = currentLocation.distanceTo(zoneLoc)
            if (distance <= zone.radiusMeters) {
                matchedZone = zone
                break
            }
        }

        if (matchedZone != null) {
            if (!isInFocusZone || currentActiveZoneName != matchedZone.name) {
                isInFocusZone = true
                currentActiveZoneName = matchedZone.name
                Log.i(TAG, "Entered Focus Zone: ${matchedZone.name}")
                AuditTrailDb.getInstance(context).logEvent(
                    eventType = "GEOFENCE_ENTER",
                    packageName = null,
                    category = "Audit & Geospatial",
                    payload = "Entered focus zone: ${matchedZone.name} (radius ${matchedZone.radiusMeters}m)",
                    latitude = lat,
                    longitude = lng
                )
            }
            return true
        } else {
            if (isInFocusZone) {
                Log.i(TAG, "Exited Focus Zone: $currentActiveZoneName")
                AuditTrailDb.getInstance(context).logEvent(
                    eventType = "GEOFENCE_EXIT",
                    packageName = null,
                    category = "Audit & Geospatial",
                    payload = "Exited focus zone: $currentActiveZoneName",
                    latitude = lat,
                    longitude = lng
                )
                isInFocusZone = false
                currentActiveZoneName = null
            }
            return false
        }
    }

    /**
     * Checks if current Wi-Fi network matches configured shield SSIDs.
     */
    fun evaluateWifiSsid(ssid: String): Boolean {
        val cleanSsid = ssid.replace("\"", "")
        val matched = wifiShieldSsids.contains(cleanSsid)
        if (matched) {
            Log.i(TAG, "Connected to Focus Wi-Fi: $cleanSsid")
            AuditTrailDb.getInstance(context).logEvent(
                eventType = "WIFI_SHIELD_MATCH",
                packageName = null,
                category = "Audit & Geospatial",
                payload = "Connected to protected Wi-Fi SSID: $cleanSsid"
            )
        }
        return matched
    }
}
