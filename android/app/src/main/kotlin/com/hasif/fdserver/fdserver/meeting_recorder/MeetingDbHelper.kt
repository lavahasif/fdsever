package com.hasif.fdserver.fdserver.meeting_recorder

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

/**
 * SQLite helper for Meeting Recorder & Decoupled Refocus Alarms.
 * Operates independently on both background threads/services and Flutter UI threads.
 */
class MeetingDbHelper private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val TAG = "MeetingDbHelper"
        private const val DATABASE_NAME = "meeting_recorder.db"
        private const val DATABASE_VERSION = 1

        @Volatile
        private var instance: MeetingDbHelper? = null

        fun getInstance(context: Context): MeetingDbHelper {
            return instance ?: synchronized(this) {
                instance ?: MeetingDbHelper(context).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE recordings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_path TEXT NOT NULL UNIQUE,
                title TEXT NOT NULL,
                started_at INTEGER NOT NULL,
                ended_at INTEGER,
                duration_ms INTEGER DEFAULT 0,
                size_bytes INTEGER DEFAULT 0,
                trigger_type TEXT NOT NULL,
                tags TEXT DEFAULT '',
                notes TEXT DEFAULT ''
            );
            """.trimIndent()
        )

        db.execSQL(
            """
            CREATE TABLE meeting_schedules (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                start_hour INTEGER NOT NULL,
                start_minute INTEGER NOT NULL,
                end_hour INTEGER NOT NULL,
                end_minute INTEGER NOT NULL,
                repeat_days INTEGER DEFAULT 0,
                target_date TEXT,
                alarm_count INTEGER NOT NULL,
                start_alarm_mode TEXT NOT NULL DEFAULT 'ring',
                nudge_alarm_mode TEXT NOT NULL DEFAULT 'vibrate',
                ringtone_uri TEXT,
                ringtone_name TEXT,
                volume REAL DEFAULT 0.8,
                is_enabled INTEGER DEFAULT 1
            );
            """.trimIndent()
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Future schema migrations
    }

    // --- Recordings Helpers ---

    fun insertRecording(
        filePath: String,
        title: String,
        startedAt: Long,
        triggerType: String
    ): Long {
        return try {
            val cv = ContentValues().apply {
                put("file_path", filePath)
                put("title", title)
                put("started_at", startedAt)
                put("trigger_type", triggerType)
            }
            writableDatabase.insert("recordings", null, cv)
        } catch (e: Exception) {
            Log.e(TAG, "Error inserting recording: ${e.message}")
            -1L
        }
    }

    fun finalizeRecording(
        filePath: String,
        endedAt: Long,
        durationMs: Long,
        sizeBytes: Long
    ): Boolean {
        return try {
            val cv = ContentValues().apply {
                put("ended_at", endedAt)
                put("duration_ms", durationMs)
                put("size_bytes", sizeBytes)
            }
            val rows = writableDatabase.update("recordings", cv, "file_path = ?", arrayOf(filePath))
            rows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error finalizing recording: ${e.message}")
            false
        }
    }

    fun updateRecordingTitle(id: Long, newTitle: String): Boolean {
        return try {
            val cv = ContentValues().apply {
                put("title", newTitle)
            }
            val rows = writableDatabase.update("recordings", cv, "id = ?", arrayOf(id.toString()))
            rows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error updating title: ${e.message}")
            false
        }
    }

    fun updateRecordingNotes(id: Long, notes: String, tags: String): Boolean {
        return try {
            val cv = ContentValues().apply {
                put("notes", notes)
                put("tags", tags)
            }
            val rows = writableDatabase.update("recordings", cv, "id = ?", arrayOf(id.toString()))
            rows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error updating notes: ${e.message}")
            false
        }
    }

    fun deleteRecording(id: Long): Boolean {
        return try {
            val rows = writableDatabase.delete("recordings", "id = ?", arrayOf(id.toString()))
            rows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting recording: ${e.message}")
            false
        }
    }

    fun getRecordingById(id: Long): Map<String, Any?>? {
        val cursor = readableDatabase.query(
            "recordings",
            null,
            "id = ?",
            arrayOf(id.toString()),
            null,
            null,
            null
        )
        return cursor.use {
            if (it.moveToFirst()) cursorToRecordingMap(it) else null
        }
    }

    fun getAllRecordings(): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        val cursor = readableDatabase.query(
            "recordings",
            null,
            null,
            null,
            null,
            null,
            "started_at DESC"
        )
        cursor.use {
            while (it.moveToNext()) {
                list.add(cursorToRecordingMap(it))
            }
        }
        return list
    }

    private fun cursorToRecordingMap(cursor: Cursor): Map<String, Any?> {
        return mapOf(
            "id" to cursor.getLong(cursor.getColumnIndexOrThrow("id")),
            "filePath" to cursor.getString(cursor.getColumnIndexOrThrow("file_path")),
            "title" to cursor.getString(cursor.getColumnIndexOrThrow("title")),
            "startedAt" to cursor.getLong(cursor.getColumnIndexOrThrow("started_at")),
            "endedAt" to if (cursor.isNull(cursor.getColumnIndexOrThrow("ended_at"))) null else cursor.getLong(cursor.getColumnIndexOrThrow("ended_at")),
            "durationMs" to cursor.getLong(cursor.getColumnIndexOrThrow("duration_ms")),
            "sizeBytes" to cursor.getLong(cursor.getColumnIndexOrThrow("size_bytes")),
            "triggerType" to cursor.getString(cursor.getColumnIndexOrThrow("trigger_type")),
            "tags" to cursor.getString(cursor.getColumnIndexOrThrow("tags")),
            "notes" to cursor.getString(cursor.getColumnIndexOrThrow("notes"))
        )
    }

    // --- Meeting Schedules Helpers ---

    fun insertOrUpdateSchedule(data: Map<String, Any?>): Long {
        return try {
            val id = (data["id"] as? Number)?.toLong() ?: -1L
            val cv = ContentValues().apply {
                put("title", data["title"] as? String ?: "Meeting Refocus")
                put("start_hour", (data["startHour"] as? Number)?.toInt() ?: 9)
                put("start_minute", (data["startMinute"] as? Number)?.toInt() ?: 0)
                put("end_hour", (data["endHour"] as? Number)?.toInt() ?: 10)
                put("end_minute", (data["endMinute"] as? Number)?.toInt() ?: 0)
                put("repeat_days", (data["repeatDays"] as? Number)?.toInt() ?: 0)
                put("target_date", data["targetDate"] as? String)
                put("alarm_count", (data["alarmCount"] as? Number)?.toInt() ?: 3)
                put("start_alarm_mode", data["startAlarmMode"] as? String ?: "ring")
                put("nudge_alarm_mode", data["nudgeAlarmMode"] as? String ?: "vibrate")
                put("ringtone_uri", data["ringtoneUri"] as? String)
                put("ringtone_name", data["ringtoneName"] as? String ?: "Default Alarm")
                put("volume", (data["volume"] as? Number)?.toDouble() ?: 0.8)
                put("is_enabled", if (data["isEnabled"] == false) 0 else 1)
            }

            if (id > 0) {
                writableDatabase.update("meeting_schedules", cv, "id = ?", arrayOf(id.toString()))
                id
            } else {
                writableDatabase.insert("meeting_schedules", null, cv)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error saving schedule: ${e.message}")
            -1L
        }
    }

    fun toggleSchedule(id: Long, enabled: Boolean): Boolean {
        return try {
            val cv = ContentValues().apply {
                put("is_enabled", if (enabled) 1 else 0)
            }
            val rows = writableDatabase.update("meeting_schedules", cv, "id = ?", arrayOf(id.toString()))
            rows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error toggling schedule: ${e.message}")
            false
        }
    }

    fun deleteSchedule(id: Long): Boolean {
        return try {
            val rows = writableDatabase.delete("meeting_schedules", "id = ?", arrayOf(id.toString()))
            rows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting schedule: ${e.message}")
            false
        }
    }

    fun getAllSchedules(): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        val cursor = readableDatabase.query(
            "meeting_schedules",
            null,
            null,
            null,
            null,
            null,
            "id ASC"
        )
        cursor.use {
            while (it.moveToNext()) {
                list.add(cursorToScheduleMap(it))
            }
        }
        return list
    }

    fun getScheduleById(id: Long): Map<String, Any?>? {
        val cursor = readableDatabase.query(
            "meeting_schedules",
            null,
            "id = ?",
            arrayOf(id.toString()),
            null,
            null,
            null
        )
        return cursor.use {
            if (it.moveToFirst()) cursorToScheduleMap(it) else null
        }
    }

    fun getEnabledSchedules(): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        val cursor = readableDatabase.query(
            "meeting_schedules",
            null,
            "is_enabled = 1",
            null,
            null,
            null,
            null
        )
        cursor.use {
            while (it.moveToNext()) {
                list.add(cursorToScheduleMap(it))
            }
        }
        return list
    }

    private fun cursorToScheduleMap(cursor: Cursor): Map<String, Any?> {
        return mapOf(
            "id" to cursor.getLong(cursor.getColumnIndexOrThrow("id")),
            "title" to cursor.getString(cursor.getColumnIndexOrThrow("title")),
            "startHour" to cursor.getInt(cursor.getColumnIndexOrThrow("start_hour")),
            "startMinute" to cursor.getInt(cursor.getColumnIndexOrThrow("start_minute")),
            "endHour" to cursor.getInt(cursor.getColumnIndexOrThrow("end_hour")),
            "endMinute" to cursor.getInt(cursor.getColumnIndexOrThrow("end_minute")),
            "repeatDays" to cursor.getInt(cursor.getColumnIndexOrThrow("repeat_days")),
            "targetDate" to cursor.getString(cursor.getColumnIndexOrThrow("target_date")),
            "alarmCount" to cursor.getInt(cursor.getColumnIndexOrThrow("alarm_count")),
            "startAlarmMode" to cursor.getString(cursor.getColumnIndexOrThrow("start_alarm_mode")),
            "nudgeAlarmMode" to cursor.getString(cursor.getColumnIndexOrThrow("nudge_alarm_mode")),
            "ringtoneUri" to cursor.getString(cursor.getColumnIndexOrThrow("ringtone_uri")),
            "ringtoneName" to cursor.getString(cursor.getColumnIndexOrThrow("ringtone_name")),
            "volume" to cursor.getDouble(cursor.getColumnIndexOrThrow("volume")),
            "isEnabled" to (cursor.getInt(cursor.getColumnIndexOrThrow("is_enabled")) == 1)
        )
    }
}
