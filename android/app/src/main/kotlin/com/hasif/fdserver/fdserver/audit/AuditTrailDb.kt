package com.hasif.fdserver.fdserver.audit

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import java.security.MessageDigest

/**
 * High-security, tamper-evident SQLite Audit Trail with SHA-256 cryptographic hash-chaining.
 * Every logged action (app block, emergency bypass, setting alteration, etc.) is irreversibly
 * linked to the prior entry's hash signature. If any record is modified, deleted, or injected,
 * the entire chain verification fails.
 */
class AuditTrailDb private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    companion object {
        private const val TAG = "AuditTrailDb"
        private const val DB_NAME = "fdserver_audit_trail.db"
        private const val DB_VERSION = 1

        const val TABLE_AUDIT = "focus_audit"
        const val COL_ID = "id"
        const val COL_TIMESTAMP = "timestamp"
        const val COL_EVENT_TYPE = "event_type"
        const val COL_PACKAGE_NAME = "package_name"
        const val COL_CATEGORY = "category"
        const val COL_PAYLOAD = "payload"
        const val COL_PREV_HASH = "prev_hash"
        const val COL_CURRENT_HASH = "current_hash"
        const val COL_LATITUDE = "latitude"
        const val COL_LONGITUDE = "longitude"

        const val GENESIS_HASH = "0000000000000000000000000000000000000000000000000000000000000000"

        @Volatile
        private var instance: AuditTrailDb? = null

        fun getInstance(context: Context): AuditTrailDb {
            return instance ?: synchronized(this) {
                instance ?: AuditTrailDb(context).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createSql = """
            CREATE TABLE IF NOT EXISTS $TABLE_AUDIT (
                $COL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_TIMESTAMP INTEGER NOT NULL,
                $COL_EVENT_TYPE TEXT NOT NULL,
                $COL_PACKAGE_NAME TEXT,
                $COL_CATEGORY TEXT NOT NULL,
                $COL_PAYLOAD TEXT,
                $COL_PREV_HASH TEXT NOT NULL,
                $COL_CURRENT_HASH TEXT NOT NULL,
                $COL_LATITUDE REAL DEFAULT 0.0,
                $COL_LONGITUDE REAL DEFAULT 0.0
            )
        """.trimIndent()
        db.execSQL(createSql)
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_audit_ts ON $TABLE_AUDIT($COL_TIMESTAMP)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_audit_cat ON $TABLE_AUDIT($COL_CATEGORY)")
        Log.i(TAG, "Audit Trail database initialized with cryptographic schema")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Migration logic if schema changes
    }

    /**
     * Compute SHA-256 hash string for chain node
     */
    private fun sha256(input: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * Retrieve the hash of the most recent audit record. Returns GENESIS_HASH if empty.
     */
    @Synchronized
    fun getLatestHash(): String {
        val db = readableDatabase
        val cursor = db.rawQuery(
            "SELECT $COL_CURRENT_HASH FROM $TABLE_AUDIT ORDER BY $COL_ID DESC LIMIT 1",
            null
        )
        cursor.use {
            if (it.moveToFirst()) {
                return it.getString(0) ?: GENESIS_HASH
            }
        }
        return GENESIS_HASH
    }

    /**
     * Atomically appends a new verified event to the cryptographic chain.
     */
    @Synchronized
    fun logEvent(
        eventType: String,
        packageName: String?,
        category: String,
        payload: String,
        latitude: Double = 0.0,
        longitude: Double = 0.0
    ): Boolean {
        return try {
            val db = writableDatabase
            val timestamp = System.currentTimeMillis()
            val prevHash = getLatestHash()

            // Compute cryptographic hash signature
            val rawInput = "$prevHash:$timestamp:$eventType:${packageName ?: ""}:$category:$payload:$latitude:$longitude"
            val currentHash = sha256(rawInput)

            val values = ContentValues().apply {
                put(COL_TIMESTAMP, timestamp)
                put(COL_EVENT_TYPE, eventType)
                put(COL_PACKAGE_NAME, packageName ?: "")
                put(COL_CATEGORY, category)
                put(COL_PAYLOAD, payload)
                put(COL_PREV_HASH, prevHash)
                put(COL_CURRENT_HASH, currentHash)
                put(COL_LATITUDE, latitude)
                put(COL_LONGITUDE, longitude)
            }

            val rowId = db.insert(TABLE_AUDIT, null, values)
            if (rowId != -1L) {
                Log.d(TAG, "Logged verified audit event #$rowId: $eventType ($category)")
                true
            } else false
        } catch (e: Exception) {
            Log.e(TAG, "Error inserting audit event: ${e.message}")
            false
        }
    }

    /**
     * Verifies the cryptographic integrity of the entire chain from Genesis to tip.
     * Returns a pair of (isValid, brokenAtId).
     */
    @Synchronized
    fun verifyIntegrity(): Pair<Boolean, Long> {
        val db = readableDatabase
        val cursor = db.rawQuery(
            "SELECT $COL_ID, $COL_TIMESTAMP, $COL_EVENT_TYPE, $COL_PACKAGE_NAME, $COL_CATEGORY, $COL_PAYLOAD, $COL_PREV_HASH, $COL_CURRENT_HASH, $COL_LATITUDE, $COL_LONGITUDE FROM $TABLE_AUDIT ORDER BY $COL_ID ASC",
            null
        )
        cursor.use {
            var expectedPrevHash = GENESIS_HASH
            while (it.moveToNext()) {
                val id = it.getLong(0)
                val ts = it.getLong(1)
                val eventType = it.getString(2) ?: ""
                val pkg = it.getString(3) ?: ""
                val cat = it.getString(4) ?: ""
                val payload = it.getString(5) ?: ""
                val prevHash = it.getString(6) ?: ""
                val recordedHash = it.getString(7) ?: ""
                val lat = it.getDouble(8)
                val lng = it.getDouble(9)

                // 1. Check chain linkage
                if (prevHash != expectedPrevHash) {
                    Log.w(TAG, "Audit chain break at ID $id: prevHash mismatch")
                    return Pair(false, id)
                }

                // 2. Recompute and verify current hash
                val rawInput = "$prevHash:$ts:$eventType:$pkg:$cat:$payload:$lat:$lng"
                val calculatedHash = sha256(rawInput)
                if (calculatedHash != recordedHash) {
                    Log.w(TAG, "Audit data corruption at ID $id: hash mismatch")
                    return Pair(false, id)
                }

                expectedPrevHash = recordedHash
            }
        }
        return Pair(true, -1L)
    }

    /**
     * Query events for timeline display
     */
    @Synchronized
    fun queryEvents(limit: Int = 100, offset: Int = 0, categoryFilter: String? = null): List<Map<String, Any>> {
        val db = readableDatabase
        val list = mutableListOf<Map<String, Any>>()
        val whereClause = if (!categoryFilter.isNullOrBlank() && categoryFilter != "ALL") "$COL_CATEGORY = ?" else null
        val whereArgs = if (whereClause != null) arrayOf(categoryFilter) else null

        val cursor = db.query(
            TABLE_AUDIT,
            null,
            whereClause,
            whereArgs,
            null,
            null,
            "$COL_ID DESC",
            "$offset, $limit"
        )

        cursor.use {
            while (it.moveToNext()) {
                val map = mutableMapOf<String, Any>()
                map["id"] = it.getLong(it.getColumnIndexOrThrow(COL_ID))
                map["timestamp"] = it.getLong(it.getColumnIndexOrThrow(COL_TIMESTAMP))
                map["eventType"] = it.getString(it.getColumnIndexOrThrow(COL_EVENT_TYPE))
                map["packageName"] = it.getString(it.getColumnIndexOrThrow(COL_PACKAGE_NAME)) ?: ""
                map["category"] = it.getString(it.getColumnIndexOrThrow(COL_CATEGORY))
                map["payload"] = it.getString(it.getColumnIndexOrThrow(COL_PAYLOAD)) ?: ""
                map["prevHash"] = it.getString(it.getColumnIndexOrThrow(COL_PREV_HASH))
                map["currentHash"] = it.getString(it.getColumnIndexOrThrow(COL_CURRENT_HASH))
                map["latitude"] = it.getDouble(it.getColumnIndexOrThrow(COL_LATITUDE))
                map["longitude"] = it.getDouble(it.getColumnIndexOrThrow(COL_LONGITUDE))
                list.add(map)
            }
        }
        return list
    }

    /**
     * Geospatial Distraction Heatmap: Group coordinates with temptation counts.
     */
    @Synchronized
    fun getDistractionCoordinates(): List<Map<String, Any>> {
        val db = readableDatabase
        val list = mutableListOf<Map<String, Any>>()
        val sql = """
            SELECT 
                ROUND($COL_LATITUDE, 3) as lat_cluster,
                ROUND($COL_LONGITUDE, 3) as lng_cluster,
                COUNT(*) as block_count,
                $COL_PACKAGE_NAME,
                MAX($COL_TIMESTAMP) as last_ts
            FROM $TABLE_AUDIT
            WHERE ($COL_LATITUDE != 0.0 OR $COL_LONGITUDE != 0.0)
            AND ($COL_EVENT_TYPE = 'TEMPTATION_BLOCKED' OR $COL_EVENT_TYPE = 'OVERLAY_ENFORCED')
            GROUP BY lat_cluster, lng_cluster
            ORDER BY block_count DESC
            LIMIT 200
        """.trimIndent()

        val cursor = db.rawQuery(sql, null)
        cursor.use {
            while (it.moveToNext()) {
                list.add(mapOf(
                    "latitude" to it.getDouble(0),
                    "longitude" to it.getDouble(1),
                    "count" to it.getInt(2),
                    "packageName" to (it.getString(3) ?: ""),
                    "lastTimestamp" to it.getLong(4)
                ))
            }
        }
        return list
    }

    /**
     * Export entire audit log to CSV format
     */
    @Synchronized
    fun exportCsv(): String {
        val events = queryEvents(limit = 10000, offset = 0)
        val sb = StringBuilder()
        sb.append("ID,Timestamp,Date,EventType,PackageName,Category,Latitude,Longitude,Hash,Payload\n")
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US)
        for (e in events) {
            val ts = e["timestamp"] as Long
            val dateStr = sdf.format(java.util.Date(ts))
            val hash = (e["currentHash"] as String).take(12)
            val payload = (e["payload"] as String).replace("\"", "\"\"")
            sb.append("${e["id"]},$ts,\"$dateStr\",\"${e["eventType"]}\",\"${e["packageName"]}\",\"${e["category"]}\",${e["latitude"]},${e["longitude"]},\"$hash\",\"$payload\"\n")
        }
        return sb.toString()
    }
}
