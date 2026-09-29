package com.hasif.fdserver.fdserver.focus_guard

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.hasif.fdserver.fdserver.MainActivity

class FocusAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "FocusGuardService"
        private const val PREFS_NAME = "focus_guard_native_prefs"
        private const val PREFS_USAGE = "focus_guard_usage_history"
        private const val KEY_IS_ACTIVE = "focus_guard_active"
        private const val KEY_BLOCK_SHORTS = "focus_guard_block_shorts"
        private const val KEY_BLOCKED_PACKAGES = "focus_guard_blocked_packages"
        private const val KEY_TEMPTATIONS_BLOCKED = "focus_guard_temptations_blocked"
        private const val KEY_HOURLY_BUDGET = "focus_guard_hourly_budget"
        var hourlyBudgetMinutes: Int = 5 // 0 = strict instant block, 5 = 5m/hr, 10 = 10m/hr

        // Track foreground usage in rolling 1-hour window: pkg -> (timestampMs, durationMs)
        private val usageHistory = mutableMapOf<String, MutableList<Pair<Long, Long>>>()
        private var activeForegroundPkg: String? = null
        private var activePkgStartTime: Long = 0L

        fun recordUsage(context: Context, pkg: String, durationMs: Long) {
            val list = usageHistory.getOrPut(pkg) { mutableListOf() }
            val now = System.currentTimeMillis()
            list.add(Pair(now, durationMs))
            pruneUsage(list, now)
            saveUsageHistory(context)
        }

        fun getUsageInLastHourMs(pkg: String): Long {
            val list = usageHistory[pkg] ?: return 0L
            val now = System.currentTimeMillis()
            pruneUsage(list, now)
            return list.sumOf { it.second }
        }

        private fun pruneUsage(list: MutableList<Pair<Long, Long>>, now: Long) {
            val oneHourAgo = now - 3600_000L
            list.removeAll { it.first < oneHourAgo }
        }

        fun saveUsageHistory(context: Context) {
            try {
                val prefs = context.getSharedPreferences(PREFS_USAGE, Context.MODE_PRIVATE)
                val editor = prefs.edit()
                editor.clear()
                val now = System.currentTimeMillis()
                for ((pkg, list) in usageHistory) {
                    pruneUsage(list, now)
                    if (list.isNotEmpty()) {
                        val serialized = list.joinToString(",") { "${it.first}:${it.second}" }
                        editor.putString(pkg, serialized)
                    }
                }
                editor.apply()
            } catch (e: Exception) {
                Log.e(TAG, "Error saving usage history: ${e.message}")
            }
        }

        fun loadUsageHistory(context: Context) {
            try {
                val prefs = context.getSharedPreferences(PREFS_USAGE, Context.MODE_PRIVATE)
                val now = System.currentTimeMillis()
                val oneHourAgo = now - 3600_000L
                for ((pkg, value) in prefs.all) {
                    if (value is String && value.isNotEmpty()) {
                        val list = mutableListOf<Pair<Long, Long>>()
                        val entries = value.split(",")
                        for (entry in entries) {
                            val parts = entry.split(":")
                            if (parts.size == 2) {
                                val time = parts[0].toLongOrNull() ?: 0L
                                val dur = parts[1].toLongOrNull() ?: 0L
                                if (time >= oneHourAgo && dur > 0) {
                                    list.add(Pair(time, dur))
                                }
                            }
                        }
                        if (list.isNotEmpty()) {
                            usageHistory[pkg] = list
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading usage history: ${e.message}")
            }
        }

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
                .putInt(KEY_HOURLY_BUDGET, hourlyBudgetMinutes)
                .putStringSet(KEY_BLOCKED_PACKAGES, blockedPackages)
                .apply()
            saveUsageHistory(context)
        }

        fun loadConfig(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            isStrictActive = prefs.getBoolean(KEY_IS_ACTIVE, false)
            blockShortsAndReels = prefs.getBoolean(KEY_BLOCK_SHORTS, true)
            hourlyBudgetMinutes = prefs.getInt(KEY_HOURLY_BUDGET, 5)
            val savedPkgs = prefs.getStringSet(KEY_BLOCKED_PACKAGES, null)
            if (savedPkgs != null) {
                blockedPackages = savedPkgs.toMutableSet()
            }
            loadUsageHistory(context)
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
    private val debounceCooldownMs: Long = 800L

    // Persistent enforcement: tracks the currently-blocked foreground package
    // and uses a Handler loop to continuously re-assert the overlay + HOME action
    private val enforcementHandler = Handler(Looper.getMainLooper())
    private var currentlyBlockedPkg: String? = null
    private var enforcementRunning = false
    private val ENFORCEMENT_INTERVAL_MS = 500L // Re-check every 500ms
    private var consecutiveHomeActions = 0
    private val MAX_CONSECUTIVE_HOME = 3 // Don't spam HOME more than 3 times in a row

    private val enforcementRunnable = object : Runnable {
        override fun run() {
            if (!enforcementRunning) return
            val blockedPkg = currentlyBlockedPkg ?: run {
                stopEnforcement()
                return
            }

            // Check if blocked app is still the foreground package
            val currentFg = activeForegroundPkg
            if (currentFg == blockedPkg) {
                // Blocked app is STILL in foreground — re-assert overlay and send HOME
                ensureOverlayShown(blockedPkg, "persistent_block")
                if (consecutiveHomeActions < MAX_CONSECUTIVE_HOME) {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    consecutiveHomeActions++
                }
            } else if (currentFg == packageName || currentFg == null) {
                // User is now in fdserver or home — stop enforcement
                stopEnforcement()
                return
            } else if (!blockedPackages.contains(currentFg ?: "")) {
                // User switched to a non-blocked app — stop enforcement
                stopEnforcement()
                return
            } else {
                // Switched to another blocked app — update target
                currentlyBlockedPkg = currentFg
                consecutiveHomeActions = 0
                ensureOverlayShown(currentFg!!, "blacklisted_app")
                performGlobalAction(GLOBAL_ACTION_HOME)
            }

            enforcementHandler.postDelayed(this, ENFORCEMENT_INTERVAL_MS)
        }
    }

    private fun startEnforcement(pkg: String) {
        currentlyBlockedPkg = pkg
        consecutiveHomeActions = 0
        if (!enforcementRunning) {
            enforcementRunning = true
            enforcementHandler.postDelayed(enforcementRunnable, ENFORCEMENT_INTERVAL_MS)
        }
    }

    private fun stopEnforcement() {
        enforcementRunning = false
        currentlyBlockedPkg = null
        consecutiveHomeActions = 0
        enforcementHandler.removeCallbacks(enforcementRunnable)
        removeInterventionOverlay()
    }

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

        Log.i(TAG, "FocusGuard Accessibility Service connected (active=$isStrictActive, blockShorts=$blockShortsAndReels, budget=${hourlyBudgetMinutes}m/h)")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (instance == null) {
            instance = this
            loadConfig(this)
        }

        val packageName = event.packageName?.toString() ?: return
        val nowRealtime = SystemClock.elapsedRealtime()

        // Never intercept or block fdserver itself; dismiss any active overlay
        if (packageName == this.packageName) {
            if (activeForegroundPkg != null && activeForegroundPkg != packageName) {
                val elapsed = nowRealtime - activePkgStartTime
                if (elapsed > 500) {
                    recordUsage(this, activeForegroundPkg!!, elapsed)
                }
                activeForegroundPkg = packageName
                activePkgStartTime = nowRealtime
            }
            stopEnforcement()
            return
        }

        // Ignore system UI (status bar, navigation, etc.)
        if (packageName == "com.android.systemui" ||
            packageName == "com.android.launcher" ||
            packageName == "com.android.launcher3" ||
            packageName == "com.google.android.apps.nexuslauncher" ||
            packageName == "com.miui.home" ||
            packageName == "com.sec.android.app.launcher" ||
            packageName == "com.huawei.android.launcher" ||
            packageName == "com.oppo.launcher" ||
            packageName == "com.realme.launcher" ||
            packageName == "com.nothing.launcher" ||
            packageName == "com.microsoft.launcher") {
            // User went to home screen / status bar — stop enforcement
            if (activeForegroundPkg != null && activeForegroundPkg != packageName) {
                val elapsed = nowRealtime - activePkgStartTime
                if (elapsed > 500) {
                    recordUsage(this, activeForegroundPkg!!, elapsed)
                }
                activeForegroundPkg = null
                activePkgStartTime = 0L
            }
            stopEnforcement()
            return
        }

        // Track foreground transitions to log usage in 1-hour window
        if (activeForegroundPkg != null && activeForegroundPkg != packageName) {
            val elapsed = nowRealtime - activePkgStartTime
            if (elapsed > 500) {
                recordUsage(this, activeForegroundPkg!!, elapsed)
            }
            activeForegroundPkg = packageName
            activePkgStartTime = nowRealtime
        } else if (activeForegroundPkg == null) {
            activeForegroundPkg = packageName
            activePkgStartTime = nowRealtime
        }

        val isBlockedPkg = blockedPackages.contains(packageName)

        // 1. Blacklisted Apps (Strict mode OR Quota enforcement: 0m, 5m, or 10m in 1 hour)
        if (isBlockedPkg) {
            if (isStrictActive || hourlyBudgetMinutes <= 0) {
                // Instant 0-tolerance block!
                val reason = if (isStrictActive) "focus_lock_active" else "blacklisted_app"
                triggerIntervention(packageName, reason)
                return
            } else {
                val elapsedCurrent = nowRealtime - activePkgStartTime
                val totalUsedMs = getUsageInLastHourMs(packageName) + elapsedCurrent
                val maxAllowedMs = hourlyBudgetMinutes * 60_000L
                if (totalUsedMs >= maxAllowedMs) {
                    recordUsage(this, packageName, elapsedCurrent)
                    triggerIntervention(packageName, "hourly_quota_exceeded")
                    return
                }
            }
        }

        // 2. Continuous Shorts & Reels Shield (runs whenever shield is enabled)
        if (blockShortsAndReels) {
            val isYouTubePkg = packageName == "com.google.android.youtube" ||
                    packageName == "app.revanced.android.youtube" ||
                    packageName == "com.google.android.youtube.tv"
            val isInstagramPkg = packageName == "com.instagram.android"

            if (isYouTubePkg) {
                checkAndBlockYouTubeShorts(event, packageName)
            } else if (isInstagramPkg) {
                checkAndBlockInstagramReels(event)
            }
        }
    }

    private var lastYouTubeScanTime: Long = 0L
    private val youTubeScanDebounceMs: Long = 200L

    private fun checkAndBlockYouTubeShorts(event: AccessibilityEvent, actualPkg: String) {
        // Fast-path: Check event class or text directly without scanning tree (0 CPU)
        val eventClass = event.className?.toString()?.lowercase() ?: ""
        if (eventClass.contains("reelwatch") ||
            eventClass.contains("shortsactivity") ||
            (eventClass.contains("shorts") && eventClass.contains("player"))) {
            triggerIntervention(actualPkg, "youtube_shorts")
            return
        }

        // Check event text for direct Shorts indicators
        val eventText = event.text?.joinToString(" ")?.lowercase() ?: ""
        if (eventText.contains("shorts") && (eventText.contains("subscribe") || eventText.contains("remix"))) {
            triggerIntervention(actualPkg, "youtube_shorts")
            return
        }

        val type = event.eventType
        val isRelevant = type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                type == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
                type == AccessibilityEvent.TYPE_VIEW_CLICKED ||
                type == AccessibilityEvent.TYPE_VIEW_SCROLLED ||
                type == AccessibilityEvent.TYPE_VIEW_SELECTED

        val now = SystemClock.elapsedRealtime()
        if (!isRelevant && (now - lastYouTubeScanTime < youTubeScanDebounceMs)) {
            return
        }
        lastYouTubeScanTime = now

        val rootNode = rootInActiveWindow ?: return
        try {
            if (isYouTubeShortsActive(rootNode, event)) {
                triggerIntervention(actualPkg, "youtube_shorts")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking YouTube Shorts: ${e.message}")
        }
    }

    private fun isYouTubeShortsActive(rootNode: AccessibilityNodeInfo, event: AccessibilityEvent?): Boolean {
        // A. Class Name indicator
        val eventClass = event?.className?.toString()?.lowercase() ?: ""
        if (eventClass.contains("reelwatch") ||
            eventClass.contains("shortsactivity") ||
            (eventClass.contains("shorts") && eventClass.contains("player"))) {
            return true
        }

        // B. Bottom Navigation "Shorts" Tab Selected Check
        try {
            val shortsNodes = rootNode.findAccessibilityNodeInfosByText("Shorts")
            for (node in shortsNodes) {
                if (node.isSelected) return true
                val desc = node.contentDescription?.toString()?.lowercase() ?: ""
                if (desc.contains("selected") || desc.contains("tab 2") || desc.contains("shorts, tab") || desc.contains("shorts tab")) {
                    return true
                }
                // Check parent for selected state (bottom nav wraps tab in container)
                val parent = node.parent
                if (parent != null && parent.isSelected) return true
            }
        } catch (_: Exception) {}

        // C. Shorts Player Unique Action Buttons
        try {
            val remixNodes = rootNode.findAccessibilityNodeInfosByText("Remix")
            if (remixNodes.isNotEmpty()) {
                // Verify this is shorts context (Remix button near video controls)
                for (node in remixNodes) {
                    val desc = node.contentDescription?.toString()?.lowercase() ?: ""
                    if (desc.contains("remix") || desc.contains("short")) return true
                    // If Remix button exists in YouTube, it's almost certainly Shorts
                    return true
                }
            }
        } catch (_: Exception) {}

        // D. Check for "Sound" label unique to Shorts
        try {
            val soundNodes = rootNode.findAccessibilityNodeInfosByText("Sound")
            for (node in soundNodes) {
                val desc = node.contentDescription?.toString()?.lowercase() ?: ""
                if (desc.contains("sound") && (desc.contains("short") || desc.contains("original"))) {
                    return true
                }
            }
        } catch (_: Exception) {}

        // E. Hierarchy scan for known view IDs
        return scanNodeForShorts(rootNode, 0)
    }

    private fun scanNodeForShorts(node: AccessibilityNodeInfo, depth: Int): Boolean {
        if (depth > 15) return false // Limit depth to prevent ANR

        val viewId = node.viewIdResourceName?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""
        val className = node.className?.toString()?.lowercase() ?: ""

        // Known YouTube Shorts view identifiers
        if (viewId.contains("shorts_container") ||
            viewId.contains("reel_watch_fragment") ||
            viewId.contains("reel_watch_player") ||
            viewId.contains("modern_shorts_player") ||
            viewId.contains("reel_player") ||
            viewId.contains("reel_recycler") ||
            viewId.contains("shorts_shelf") ||
            viewId.contains("shorts_video_player") ||
            viewId.contains("reel_action") ||
            viewId.contains("reel_multi_format") ||
            viewId.contains("shorts_surface_view") ||
            viewId.contains("shorts_paused_state")) {
            return true
        }

        // Selected Shorts tab (bottom nav or pivot bar)
        if ((text == "shorts" || desc.contains("shorts")) &&
            (node.isSelected || desc.contains("selected") || viewId.contains("pivot") || viewId.contains("tab") || viewId.contains("bottom_nav"))) {
            return true
        }

        // Shorts unique action labels
        if (desc.contains("sound used in this short") ||
            desc.contains("open comments for this short") ||
            desc.contains("remix this video") ||
            desc.contains("dislike this short") ||
            desc.contains("like this short") ||
            desc.contains("share this short")) {
            return true
        }

        // Activity class check within the tree
        if (className.contains("reelwatch") || className.contains("shortsactivity")) {
            return true
        }

        val childCount = node.childCount
        for (i in 0 until childCount) {
            val child = node.getChild(i) ?: continue
            try {
                if (scanNodeForShorts(child, depth + 1)) {
                    return true
                }
            } finally {
                // Recycle to prevent memory leak
                try { child.recycle() } catch (_: Exception) {}
            }
        }

        return false
    }

    private var lastInstagramScanTime: Long = 0L
    private val instagramScanDebounceMs: Long = 200L

    private fun checkAndBlockInstagramReels(event: AccessibilityEvent) {
        // Fast-path: event class check
        val eventClass = event.className?.toString()?.lowercase() ?: ""
        if (eventClass.contains("reelviewer") ||
            eventClass.contains("clipsviewer") ||
            eventClass.contains("reelfragment") ||
            eventClass.contains("clipsfragment")) {
            triggerIntervention("com.instagram.android", "instagram_reels")
            return
        }

        val type = event.eventType
        val isRelevant = type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                type == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
                type == AccessibilityEvent.TYPE_VIEW_CLICKED ||
                type == AccessibilityEvent.TYPE_VIEW_SCROLLED ||
                type == AccessibilityEvent.TYPE_VIEW_SELECTED

        val now = SystemClock.elapsedRealtime()
        if (!isRelevant && (now - lastInstagramScanTime < instagramScanDebounceMs)) {
            return
        }
        lastInstagramScanTime = now

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
        if (eventClass.contains("reelviewer") || eventClass.contains("clipsviewer") ||
            eventClass.contains("reelfragment") || eventClass.contains("clipsfragment")) {
            return true
        }

        // Check for Reels tab selected in bottom navigation
        try {
            val reelsNodes = rootNode.findAccessibilityNodeInfosByText("Reels")
            for (node in reelsNodes) {
                if (node.isSelected) return true
                val desc = node.contentDescription?.toString()?.lowercase() ?: ""
                if (desc.contains("selected") || desc.contains("reels tab") || desc.contains("reels, tab")) {
                    return true
                }
                val parent = node.parent
                if (parent != null && parent.isSelected) return true
            }
        } catch (_: Exception) {}

        // Also check for video playback context clues unique to Reels
        try {
            val audioNodes = rootNode.findAccessibilityNodeInfosByText("Original audio")
            if (audioNodes.isNotEmpty()) return true
        } catch (_: Exception) {}

        return scanNodeForReels(rootNode, 0)
    }

    private fun scanNodeForReels(node: AccessibilityNodeInfo, depth: Int): Boolean {
        if (depth > 15) return false

        val viewId = node.viewIdResourceName?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""
        val className = node.className?.toString()?.lowercase() ?: ""

        if (viewId.contains("clips_video_container") ||
            viewId.contains("reel_viewer") ||
            viewId.contains("clips_viewer") ||
            viewId.contains("reels_tab") ||
            viewId.contains("clips_swipe_refresh_layout") ||
            viewId.contains("clips_player") ||
            viewId.contains("reel_fragment") ||
            viewId.contains("clips_surface") ||
            viewId.contains("reel_surface_view")) {
            return true
        }

        if ((text == "reels" || desc.contains("reels")) && (node.isSelected || desc.contains("selected"))) {
            return true
        }

        if (desc.contains("audio for this reel") || desc.contains("remix this reel") ||
            desc.contains("original audio") || desc.contains("share reel")) {
            return true
        }

        if (className.contains("reelviewer") || className.contains("clipsfragment")) {
            return true
        }

        val childCount = node.childCount
        for (i in 0 until childCount) {
            val child = node.getChild(i) ?: continue
            try {
                if (scanNodeForReels(child, depth + 1)) {
                    return true
                }
            } finally {
                try { child.recycle() } catch (_: Exception) {}
            }
        }
        return false
    }

    private fun triggerIntervention(packageName: String, reason: String) {
        val now = SystemClock.elapsedRealtime()

        // ALWAYS immediately show overlay (no debounce on the visual blocker)
        ensureOverlayShown(packageName, reason)

        // Start persistent enforcement loop
        startEnforcement(packageName)

        // Debounce only the expensive side-effects (not the overlay)
        if (now - lastInterventionTime < debounceCooldownMs) {
            return
        }
        lastInterventionTime = now

        incrementTemptationsCount(this)
        Log.w(TAG, "Intervention triggered for $packageName due to $reason")

        // 1. Drop blocked app to home screen
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

        // 4. Launch FDServer MainActivity via PendingIntent (bypasses Android 10+ background activity launch restrictions)
        launchMainActivity(this, packageName, reason)
    }

    private var overlayView: View? = null
    private var currentOverlayPkg: String? = null

    /**
     * Ensures overlay is visible. If already shown for the same package, no-op.
     * If shown for a different package, recreate. If not shown, create.
     */
    private fun ensureOverlayShown(pkg: String, reason: String) {
        if (overlayView != null && currentOverlayPkg == pkg) {
            // Overlay already showing for this package — ensure it's visible
            overlayView?.alpha = 1f
            return
        }
        // Remove any stale overlay first
        if (overlayView != null) {
            removeInterventionOverlayImmediate()
        }
        showInterventionOverlay(pkg, reason)
    }

    private fun showInterventionOverlay(pkg: String, reason: String) {
        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
                },
                // FLAG_NOT_FOCUSABLE: don't steal keyboard focus
                // FLAG_LAYOUT_IN_SCREEN + FLAG_FULLSCREEN: cover entire display including status/nav bars
                // NO FLAG_NOT_TOUCH_MODAL: overlay captures ALL touch events, nothing leaks through
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_FULLSCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            )

            val layout = createOverlayView(pkg, reason)
            overlayView = layout
            currentOverlayPkg = pkg
            wm.addView(layout, params)
        } catch (e: Exception) {
            Log.e(TAG, "Error displaying intervention overlay: ${e.message}")
        }
    }

    private fun removeInterventionOverlay() {
        try {
            val v = overlayView ?: return
            overlayView = null
            currentOverlayPkg = null
            v.animate()
                .alpha(0f)
                .setDuration(160)
                .withEndAction {
                    try {
                        val wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                        wm?.removeView(v)
                    } catch (_: Exception) {}
                }
                .start()
        } catch (e: Exception) {
            Log.e(TAG, "Error removing intervention overlay: ${e.message}")
        }
    }

    /** Immediately remove overlay without animation (used before re-creation) */
    private fun removeInterventionOverlayImmediate() {
        try {
            val v = overlayView ?: return
            overlayView = null
            currentOverlayPkg = null
            val wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
            wm?.removeView(v)
        } catch (e: Exception) {
            Log.e(TAG, "Error removing intervention overlay (immediate): ${e.message}")
        }
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }

    private fun createOverlayView(pkg: String, reason: String): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F209090B")) // Opaque dark overlay
            setPadding(dpToPx(24), dpToPx(24), dpToPx(24), dpToPx(24))
            // Consume ALL touches — nothing passes through to blocked app
            setOnTouchListener { _, _ -> true }
            isClickable = true
            isFocusable = true
            alpha = 0f
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#18181B"))
                cornerRadius = dpToPx(18).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#27272A"))
            }
            background = bg
            setPadding(dpToPx(24), dpToPx(28), dpToPx(24), dpToPx(28))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            alpha = 0f
            translationY = dpToPx(30).toFloat()
        }

        val badge = TextView(this).apply {
            text = "🛡️ FOCUS GUARD ACTIVE"
            setTextColor(Color.parseColor("#F59E0B"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        card.addView(badge)

        val title = TextView(this).apply {
            text = "Distraction Intercepted"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(10), 0, 0)
        }
        card.addView(title)

        val desc = TextView(this).apply {
            text = when (reason) {
                "hourly_quota_exceeded" -> "You exceeded your ${hourlyBudgetMinutes}m hourly limit for this app. Locked to protect your focus."
                "focus_lock_active" -> "Focus Lock session is active. Zero tolerance for distractions."
                "youtube_shorts" -> "YouTube Shorts feed intercepted to protect your attention."
                "instagram_reels" -> "Instagram Reels loop blocked."
                "persistent_block" -> "This app is currently blocked. Stay focused!"
                else -> "This app is blacklisted by your Focus Guard."
            }
            setTextColor(Color.parseColor("#A1A1AA"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(8), 0, dpToPx(16))
        }
        card.addView(desc)

        // Read live or cached motivational quote
        var quoteText = "\"Your future is created by what you do today, not what you scroll.\"\n— Focus Anchor"
        try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val cachedQ = flutterPrefs.getString("flutter.focus_guard_quote_text", null)
            val cachedA = flutterPrefs.getString("flutter.focus_guard_quote_author", null)
            if (!cachedQ.isNullOrBlank()) {
                quoteText = "\"$cachedQ\"" + if (!cachedA.isNullOrBlank()) "\n— $cachedA" else ""
            }
        } catch (_: Exception) {}

        val quote = TextView(this).apply {
            text = quoteText
            setTextColor(Color.parseColor("#CBD5E1"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTypeface(typeface, Typeface.ITALIC)
            gravity = Gravity.CENTER
            setPadding(dpToPx(12), dpToPx(10), dpToPx(12), dpToPx(10))
            val quoteBg = GradientDrawable().apply {
                setColor(Color.parseColor("#27272A"))
                cornerRadius = dpToPx(10).toFloat()
            }
            background = quoteBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dpToPx(20)
            }
        }
        card.addView(quote)

        // Button 1: Read Motivation Guide
        val btnGuide = Button(this).apply {
            text = "📖 Read Motivation & Mindset Guide"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.DEFAULT_BOLD
            val btnBg = GradientDrawable().apply {
                setColor(Color.parseColor("#4F46E5"))
                cornerRadius = dpToPx(12).toFloat()
            }
            background = btnBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(48)
            ).apply {
                bottomMargin = dpToPx(10)
            }
            setOnClickListener {
                stopEnforcement()
                launchMainActivity(this@FocusAccessibilityService, pkg, reason)
            }
        }
        card.addView(btnGuide)

        // Button 2: Watch Pep Video
        val btnVideo = Button(this).apply {
            text = "🎬 Watch Motivation Video"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.DEFAULT_BOLD
            val btnBg = GradientDrawable().apply {
                setColor(Color.parseColor("#DC2626"))
                cornerRadius = dpToPx(12).toFloat()
            }
            background = btnBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(48)
            ).apply {
                bottomMargin = dpToPx(10)
            }
            setOnClickListener {
                stopEnforcement()
                try {
                    val videoIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/watch?v=kYfNvmF0Bqw")).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(videoIntent)
                } catch (_: Exception) {}
            }
        }
        card.addView(btnVideo)

        // Button 3: Return to Home
        val btnHome = Button(this).apply {
            text = "🏠 Back to Productivity (Home)"
            setTextColor(Color.parseColor("#A1A1AA"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            val btnBg = GradientDrawable().apply {
                setColor(Color.parseColor("#27272A"))
                cornerRadius = dpToPx(12).toFloat()
            }
            background = btnBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(44)
            )
            setOnClickListener {
                stopEnforcement()
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        }
        card.addView(btnHome)

        root.addView(card)

        // Smooth fluid entry transition (avoids abrupt pop/flash)
        root.animate().alpha(1f).setDuration(220).start()
        card.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(300)
            .setInterpolator(android.view.animation.DecelerateInterpolator())
            .start()

        return root
    }

    private fun launchMainActivity(context: Context, packageName: String, reason: String) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.hasif.fdserver.FOCUS_INTERVENTION"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("action", "com.hasif.fdserver.FOCUS_INTERVENTION")
                putExtra("blocked_package", packageName)
                putExtra("block_reason", reason)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                1001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            try {
                pendingIntent.send()
            } catch (_: Exception) {
                context.startActivity(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch MainActivity intervention: ${e.message}")
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.i(TAG, "Application task removed from recents - FocusGuard remains active in background")
        loadConfig(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        stopEnforcement()
        instance = null
        Log.i(TAG, "FocusGuard Accessibility Service destroyed")
    }

    override fun onInterrupt() {
        stopEnforcement()
        Log.w(TAG, "FocusGuard Accessibility Service interrupted")
    }
}
