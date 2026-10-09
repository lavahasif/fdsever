package com.hasif.fdserver.fdserver.meeting_recorder

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.hasif.fdserver.fdserver.call_recorder.CallAudioPlayer
import com.hasif.fdserver.fdserver.meeting_recorder.alarm.AlarmTonePlayer
import com.hasif.fdserver.fdserver.meeting_recorder.alarm.MeetingAlarmScheduler
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * MethodChannel & EventChannel bridge between Flutter and Native Android
 * for Meeting Recorder and Decoupled Refocus Alarms.
 */
class MeetingRecorderBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "MeetingRecorderBridge"
        private const val CHANNEL_NAME = "fdserver/meeting_recorder"
        private const val EVENT_CHANNEL_STATUS = "fdserver/meeting_recorder_status"
        private const val EVENT_CHANNEL_PLAYBACK = "fdserver/meeting_recorder_playback"

        @Volatile
        private var instance: MeetingRecorderBridge? = null

        fun registerWith(messenger: BinaryMessenger, context: Context): MeetingRecorderBridge {
            val bridge = MeetingRecorderBridge(context)
            val channel = MethodChannel(messenger, CHANNEL_NAME)
            channel.setMethodCallHandler(bridge)

            val statusEventChannel = EventChannel(messenger, EVENT_CHANNEL_STATUS)
            statusEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bridge.statusEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    bridge.statusEventSink = null
                }
            })

            val playbackEventChannel = EventChannel(messenger, EVENT_CHANNEL_PLAYBACK)
            playbackEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bridge.playbackEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    bridge.playbackEventSink = null
                }
            })

            instance = bridge
            return bridge
        }
    }

    private var statusEventSink: EventChannel.EventSink? = null
    private var playbackEventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        MeetingRecorderService.onStateChanged = { isStandby, isRecording, path ->
            mainHandler.post {
                statusEventSink?.success(
                    mapOf(
                        "isStandby" to isStandby,
                        "isRecording" to isRecording,
                        "currentRecordingPath" to (path ?: ""),
                        "startTimeMs" to MeetingRecorderService.recordingStartTime,
                        "latestAmplitude" to MeetingRecorderService.latestAmplitude
                    )
                )
            }
        }

        CallAudioPlayer.addListener { statusMap ->
            mainHandler.post {
                playbackEventSink?.success(statusMap)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val db = MeetingDbHelper.getInstance(context)

        when (call.method) {
            "startStandby" -> {
                try {
                    val intent = Intent(context, MeetingRecorderService::class.java).apply {
                        action = MeetingRecorderService.ACTION_START_STANDBY
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Error starting standby: ${e.message}")
                    result.error("START_STANDBY_FAILED", e.message, null)
                }
            }

            "stopStandby" -> {
                try {
                    val intent = Intent(context, MeetingRecorderService::class.java).apply {
                        action = MeetingRecorderService.ACTION_STOP_STANDBY
                    }
                    context.startService(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("STOP_STANDBY_FAILED", e.message, null)
                }
            }

            "isStandbyActive" -> {
                result.success(MeetingRecorderService.isStandby)
            }

            "startRecording" -> {
                try {
                    val trigger = call.argument<String>("trigger") ?: "manual"
                    val intent = Intent(context, MeetingRecorderService::class.java).apply {
                        action = MeetingRecorderService.ACTION_START_RECORDING
                        putExtra(MeetingRecorderService.EXTRA_TRIGGER, trigger)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("START_RECORDING_FAILED", e.message, null)
                }
            }

            "stopRecording" -> {
                try {
                    val intent = Intent(context, MeetingRecorderService::class.java).apply {
                        action = MeetingRecorderService.ACTION_STOP_RECORDING
                    }
                    context.startService(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("STOP_RECORDING_FAILED", e.message, null)
                }
            }

            "getRecordingStatus" -> {
                result.success(
                    mapOf(
                        "isStandby" to MeetingRecorderService.isStandby,
                        "isRecording" to MeetingRecorderService.isRecording,
                        "currentRecordingPath" to (MeetingRecorderService.currentRecordingPath ?: ""),
                        "startTimeMs" to MeetingRecorderService.recordingStartTime,
                        "latestAmplitude" to MeetingRecorderService.latestAmplitude
                    )
                )
            }

            "getRecordings" -> {
                try {
                    val list = db.getAllRecordings()
                    result.success(list)
                } catch (e: Exception) {
                    result.error("DB_ERROR", e.message, null)
                }
            }

            "renameRecording" -> {
                val id = (call.argument<Number>("id"))?.toLong() ?: -1L
                val newTitle = call.argument<String>("newTitle") ?: ""
                if (id <= 0 || newTitle.isEmpty()) {
                    result.error("INVALID_ARGS", "Valid id and newTitle required", null)
                    return
                }
                val ok = db.updateRecordingTitle(id, newTitle)
                result.success(ok)
            }

            "updateRecordingNotes" -> {
                val id = (call.argument<Number>("id"))?.toLong() ?: -1L
                val notes = call.argument<String>("notes") ?: ""
                val tags = call.argument<String>("tags") ?: ""
                val ok = db.updateRecordingNotes(id, notes, tags)
                result.success(ok)
            }

            "deleteRecording" -> {
                val id = (call.argument<Number>("id"))?.toLong() ?: -1L
                val rec = db.getRecordingById(id)
                if (rec != null) {
                    val path = rec["filePath"] as? String
                    if (!path.isNullOrEmpty()) {
                        try {
                            val f = File(path)
                            if (f.exists()) f.delete()
                        } catch (_: Exception) {}
                    }
                    val ok = db.deleteRecording(id)
                    result.success(ok)
                } else {
                    result.success(false)
                }
            }

            // --- Decoupled Meeting Schedules ---
            "getSchedules" -> {
                try {
                    val list = db.getAllSchedules()
                    result.success(list)
                } catch (e: Exception) {
                    result.error("DB_ERROR", e.message, null)
                }
            }

            "saveSchedule" -> {
                try {
                    val map = call.argument<Map<String, Any?>>("schedule")
                    if (map == null) {
                        result.error("INVALID_ARGS", "schedule map required", null)
                        return
                    }
                    val savedId = db.insertOrUpdateSchedule(map)
                    if (savedId > 0) {
                        val fullSchedule = db.getScheduleById(savedId)
                        if (fullSchedule != null) {
                            MeetingAlarmScheduler.schedule(context, fullSchedule)
                        }
                        result.success(savedId)
                    } else {
                        result.error("SAVE_FAILED", "Could not save schedule", null)
                    }
                } catch (e: Exception) {
                    result.error("SAVE_ERROR", e.message, null)
                }
            }

            "deleteSchedule" -> {
                val id = (call.argument<Number>("id"))?.toLong() ?: -1L
                if (id > 0) {
                    MeetingAlarmScheduler.cancelAlarms(context, id)
                    val ok = db.deleteSchedule(id)
                    result.success(ok)
                } else {
                    result.success(false)
                }
            }

            "toggleSchedule" -> {
                val id = (call.argument<Number>("id"))?.toLong() ?: -1L
                val enabled = call.argument<Boolean>("isEnabled") ?: true
                if (id > 0) {
                    db.toggleSchedule(id, enabled)
                    val full = db.getScheduleById(id)
                    if (full != null) {
                        MeetingAlarmScheduler.schedule(context, full)
                    }
                    result.success(true)
                } else {
                    result.success(false)
                }
            }

            "previewAlarm" -> {
                val soundMode = call.argument<String>("soundMode") ?: "ring"
                val ringtoneUri = call.argument<String>("ringtoneUri")
                val volume = (call.argument<Number>("volume"))?.toFloat() ?: 0.8f
                AlarmTonePlayer.play(context, ringtoneUri, volume, soundMode)
                result.success(true)
            }

            "stopAlarmPreview" -> {
                AlarmTonePlayer.stop()
                result.success(true)
            }

            // --- Audio Player ---
            "playAudio" -> {
                val path = call.argument<String>("path") ?: ""
                val ok = CallAudioPlayer.play(path, context)
                result.success(ok)
            }

            "pauseAudio" -> {
                result.success(CallAudioPlayer.pause())
            }

            "resumeAudio" -> {
                result.success(CallAudioPlayer.resume())
            }

            "stopAudio" -> {
                CallAudioPlayer.stop()
                result.success(true)
            }

            "seekAudio" -> {
                val posMs = call.argument<Int>("positionMs") ?: 0
                result.success(CallAudioPlayer.seekTo(posMs))
            }

            else -> result.notImplemented()
        }
    }
}
