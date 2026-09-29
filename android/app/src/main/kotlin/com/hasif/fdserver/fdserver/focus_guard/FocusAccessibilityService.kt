package com.hasif.fdserver.fdserver.focus_guard

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.hasif.fdserver.fdserver.MainActivity

class FocusAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "FocusGuardService"
        private const val PREFS_NAME = "focus_guard_native_prefs"
        private const val KEY_IS_ACTIVE = "focus_guard_active"
        private const val KEY_BLOCK_SHORTS = "focus_guard_block_shorts"
        private const val KEY_BLOCKED_PACKAGES = "focus_guard_blocked_pkgs"
        private const val KEY_TEMPTATIONS_BLOCKED = "focus_guard_temptations_count"

        var instance: FocusAccessibilityService? = null
            private set

        var isStrictActive: Boolean = false
        var blockShortsAndReels: Boolean = true
        var blockedPackages: MutableSet<String> = mutableSetOf(
            "com.instagram.android",
            "com.zhiliaoapp.musically",
            "com.ss.android.ugc.trill",
            "com.facebook.katana",
            "com.twitter.android",
            "com.snapchat.android"
        )

        var listener: ((packageName: String, reason: String) -> Unit)? = null

        fun isServiceRunning(): Boolean = instance != null

        fun saveConfig(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_IS_ACTIVE, isStrictActive)
                .putBoolean(KEY_BLOCK_SHORTS, blockShortsAndReels)
                .putStringSet(KEY_BLOCKED_PACKAGES, blockedPackages)
                .apply()
        }

        fun loadConfig(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            isStrictActive = prefs.getBoolean(KEY_IS_ACTIVE, false)
            blockShortsAndReels = prefs.getBoolean(KEY_BLOCK_SHORTS, true)
            val savedPkgs = prefs.getStringSet(KEY_BLOCKED_PACKAGES, null)
            if (savedPkgs != null) {
                blockedPackages = savedPkgs.toMutableSet()
            }
        }

        fun incrementTemptationsCount(context: Context): Int {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val current = prefs.getInt(KEY_TEMPTATIONS_BLOCKED, 0) + 1
            prefs.edit().putInt(KEY_TEMPTATIONS_BLOCKED, current).apply()
            return current
        }

        fun getTemptationsCount(context: Context): Int {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getInt(KEY_TEMPTATIONS_BLOCKED, 0)
        }
    }

    private var lastInterventionTime: Long = 0L
    private val debounceCooldownMs: Long = 1000L

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        loadConfig(this)

        try {
            val info = serviceInfo ?: AccessibilityServiceInfo()
            info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            info.flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            info.notificationTimeout = 20
            serviceInfo = info
        } catch (e: Exception) {
            Log.e(TAG, "Error configuring service info: ${e.message}")
        }

        Log.i(TAG, "FocusGuard Accessibility Service connected (active=$isStrictActive, blockShorts=$blockShortsAndReels)")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.i(TAG, "FocusGuard Accessibility Service destroyed")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return

        // Never intercept or block fdserver itself
        if (packageName == this.packageName) return

        // 1. Blacklisted Apps (during Strict Focus Lock)
        if (isStrictActive && blockedPackages.contains(packageName)) {
            triggerIntervention(packageName, "blacklisted_app")
            return
        }

        // 2. Continuous Shorts & Reels Shield (runs whenever shield is enabled)
        if (blockShortsAndReels) {
            if (packageName == "com.google.android.youtube" ||
                packageName == "app.revanced.android.youtube" ||
                packageName == "com.google.android.youtube.tv") {
                checkAndBlockYouTubeShorts(event)
            } else if (packageName == "com.instagram.android") {
                checkAndBlockInstagramReels(event)
            }
        }
    }

    private fun checkAndBlockYouTubeShorts(event: AccessibilityEvent) {
        val rootNode = rootInActiveWindow ?: return
        try {
            if (isYouTubeShortsActive(rootNode, event)) {
                triggerIntervention("com.google.android.youtube", "youtube_shorts")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking YouTube Shorts: ${e.message}")
        }
    }

    private fun isYouTubeShortsActive(rootNode: AccessibilityNodeInfo, event: AccessibilityEvent?): Boolean {
        // A. Class Name indicator
        val eventClass = event?.className?.toString()?.lowercase() ?: ""
        if (eventClass.contains("reelwatchactivity") ||
            (eventClass.contains("shorts") && eventClass.contains("player"))) {
            return true
        }

        // B. Bottom Navigation "Shorts" Tab Selected Check
        try {
            val shortsNodes = rootNode.findAccessibilityNodeInfosByText("Shorts")
            for (node in shortsNodes) {
                if (node.isSelected) return true
                val desc = node.contentDescription?.toString()?.lowercase() ?: ""
                if (desc.contains("selected") || desc.contains("tab 2") || desc.contains("shorts, tab")) {
                    return true
                }
            }
        } catch (_: Exception) {}

        // C. Shorts Player Unique Action Buttons ("Remix", "Sound used in this short")
        try {
            val remixNodes = rootNode.findAccessibilityNodeInfosByText("Remix")
            if (remixNodes.isNotEmpty()) {
                return true
            }
        } catch (_: Exception) {}

        // D. Hierarchy scan
        return scanNodeForShorts(rootNode, 0)
    }

    private fun scanNodeForShorts(node: AccessibilityNodeInfo, depth: Int): Boolean {
        if (depth > 20) return false

        val viewId = node.viewIdResourceName?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""

        // Known YouTube Shorts view identifiers
        if (viewId.contains("shorts_container") ||
            viewId.contains("reel_watch_fragment") ||
            viewId.contains("modern_shorts_player") ||
            viewId.contains("reel_player") ||
            viewId.contains("reel_recycler") ||
            viewId.contains("shorts_shelf") ||
            viewId.contains("reel_action")) {
            return true
        }

        // Selected Shorts tab
        if ((text == "shorts" || desc.contains("shorts")) &&
            (node.isSelected || desc.contains("selected") || viewId.contains("pivot") || viewId.contains("tab"))) {
            return true
        }

        // Shorts unique action labels
        if (desc.contains("sound used in this short") ||
            desc.contains("open comments for this short") ||
            desc.contains("remix this video") ||
            desc.contains("dislike this short")) {
            return true
        }

        val childCount = node.childCount
        for (i in 0 until childCount) {
            val child = node.getChild(i) ?: continue
            if (scanNodeForShorts(child, depth + 1)) {
                return true
            }
        }

        return false
    }

    private fun checkAndBlockInstagramReels(event: AccessibilityEvent) {
        val rootNode = rootInActiveWindow ?: return
        try {
            if (isInstagramReelsActive(rootNode, event)) {
                triggerIntervention("com.instagram.android", "instagram_reels")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Instagram Reels: ${e.message}")
        }
    }

    private fun isInstagramReelsActive(rootNode: AccessibilityNodeInfo, event: AccessibilityEvent?): Boolean {
        val eventClass = event?.className?.toString()?.lowercase() ?: ""
        if (eventClass.contains("reelviewer") || eventClass.contains("clipsviewer")) {
            return true
        }

        try {
            val reelsNodes = rootNode.findAccessibilityNodeInfosByText("Reels")
            for (node in reelsNodes) {
                if (node.isSelected) return true
                val desc = node.contentDescription?.toString()?.lowercase() ?: ""
                if (desc.contains("selected") || desc.contains("tab")) {
                    return true
                }
            }
        } catch (_: Exception) {}

        return scanNodeForReels(rootNode, 0)
    }

    private fun scanNodeForReels(node: AccessibilityNodeInfo, depth: Int): Boolean {
        if (depth > 20) return false

        val viewId = node.viewIdResourceName?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""

        if (viewId.contains("clips_video_container") ||
            viewId.contains("reel_viewer") ||
            viewId.contains("clips_viewer") ||
            viewId.contains("reels_tab") ||
            viewId.contains("clips_swipe_refresh_layout")) {
            return true
        }

        if ((text == "reels" || desc.contains("reels")) && (node.isSelected || desc.contains("selected"))) {
            return true
        }

        if (desc.contains("audio for this reel") || desc.contains("remix this reel")) {
            return true
        }

        val childCount = node.childCount
        for (i in 0 until childCount) {
            val child = node.getChild(i) ?: continue
            if (scanNodeForReels(child, depth + 1)) {
                return true
            }
        }
        return false
    }

    private fun triggerIntervention(packageName: String, reason: String) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastInterventionTime < debounceCooldownMs) {
            return
        }
        lastInterventionTime = now

        incrementTemptationsCount(this)
        Log.w(TAG, "Intervention triggered for $packageName due to $reason")

        // 1. Kick back out immediately
        performGlobalAction(GLOBAL_ACTION_BACK)
        performGlobalAction(GLOBAL_ACTION_HOME)

        // 2. Notify active in-memory listener
        listener?.invoke(packageName, reason)

        // 3. Persist pending intervention for cold-start pickup in Flutter
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString("pending_intervention_pkg", packageName)
                .putString("pending_intervention_reason", reason)
                .putLong("pending_intervention_time", System.currentTimeMillis())
                .apply()
        } catch (_: Exception) {}

        // 4. Launch Reality Check Lock Screen in fdserver
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("action", "com.hasif.fdserver.FOCUS_INTERVENTION")
                putExtra("blocked_package", packageName)
                putExtra("block_reason", reason)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch MainActivity intervention: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "FocusGuard Accessibility Service interrupted")
    }
}
