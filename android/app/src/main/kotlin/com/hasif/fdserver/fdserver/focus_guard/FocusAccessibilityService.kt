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
    private val debounceCooldownMs: Long = 1200L

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        loadConfig(this)
        Log.i(TAG, "FocusGuard Accessibility Service connected and active=$isStrictActive")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.i(TAG, "FocusGuard Accessibility Service destroyed")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (!isStrictActive) return

        val packageName = event.packageName?.toString() ?: return

        // Never block our own app
        if (packageName == this.packageName) return

        // 1. Direct App Blacklist Interception
        if (blockedPackages.contains(packageName)) {
            triggerIntervention(packageName, "blacklisted_app")
            return
        }

        // 2. Granular YouTube Shorts / Instagram Reels Interception
        if (blockShortsAndReels) {
            if (packageName == "com.google.android.youtube" || packageName == "app.revanced.android.youtube") {
                checkAndBlockYouTubeShorts(event)
            } else if (packageName == "com.instagram.android") {
                checkAndBlockInstagramReels(event)
            }
        }
    }

    private fun checkAndBlockYouTubeShorts(event: AccessibilityEvent) {
        val rootNode = rootInActiveWindow ?: return
        try {
            // Check known view IDs and content descriptions for YouTube Shorts
            val isShorts = hasShortsIndicator(rootNode)
            if (isShorts) {
                triggerIntervention("com.google.android.youtube", "youtube_shorts")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error inspecting YouTube hierarchy: ${e.message}")
        } finally {
            rootNode.recycle()
        }
    }

    private fun hasShortsIndicator(node: AccessibilityNodeInfo): Boolean {
        val viewId = node.viewIdResourceName?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""

        // Indicators in YouTube's view hierarchy
        if (viewId.contains("reel_watch_fragment") ||
            viewId.contains("shorts_container") ||
            viewId.contains("modern_shorts_player") ||
            viewId.contains("reel_player_page_tree") ||
            viewId.contains("reel_recycler")) {
            return true
        }

        if (desc.contains("shorts") && (viewId.contains("pivot") || viewId.contains("tab_selected") || viewId.contains("player"))) {
            return true
        }

        // Check children
        val count = node.childCount
        for (i in 0 until count) {
            val child = node.getChild(i) ?: continue
            val found = hasShortsIndicator(child)
            child.recycle()
            if (found) return true
        }
        return false
    }

    private fun checkAndBlockInstagramReels(event: AccessibilityEvent) {
        val rootNode = rootInActiveWindow ?: return
        try {
            val isReels = hasInstagramReelsIndicator(rootNode)
            if (isReels) {
                triggerIntervention("com.instagram.android", "instagram_reels")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error inspecting Instagram hierarchy: ${e.message}")
        } finally {
            rootNode.recycle()
        }
    }

    private fun hasInstagramReelsIndicator(node: AccessibilityNodeInfo): Boolean {
        val viewId = node.viewIdResourceName?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""

        if (viewId.contains("clips_video_container") ||
            viewId.contains("reel_viewer") ||
            viewId.contains("clips_viewer") ||
            viewId.contains("reels_tab")) {
            return true
        }

        if (desc.contains("reels") && (viewId.contains("tab") || viewId.contains("selected"))) {
            return true
        }

        val count = node.childCount
        for (i in 0 until count) {
            val child = node.getChild(i) ?: continue
            val found = hasInstagramReelsIndicator(child)
            child.recycle()
            if (found) return true
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

        // First kick back to Home or Back to break the dopamine loop immediately
        if (reason == "youtube_shorts" || reason == "instagram_reels") {
            performGlobalAction(GLOBAL_ACTION_BACK)
        } else {
            performGlobalAction(GLOBAL_ACTION_HOME)
        }

        // Notify listener if registered
        listener?.invoke(packageName, reason)

        // Launch Reality Check Lock Screen in fdserver
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
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
