/**
 * FDServer Native Monitor Engine
 * ══════════════════════════════════════════════════════════════════════════
 * Ultra-low-power C++ monitoring thread that detects foreground apps via JNI
 * calls to UsageStatsManager. Works WITHOUT Accessibility Service.
 *
 * Battery Optimizations:
 * - Screen-off: completely stops polling (zero CPU)
 * - Battery-adaptive: polls slower at low battery, stops at critical
 * - Smart debounce: 3-second per-package deduplication
 * - Distraction chain detection: tracks rapid app-switching patterns
 * - Temptation pattern logging: records temporal access patterns
 *
 * Thread Model:
 * - Single pthread for monitoring loop
 * - All JNI calls happen on the monitor thread (attached to JVM)
 * - Atomic variables for cross-thread state (lock-free where possible)
 * - Mutex only for blocked package list and pattern log
 *
 * Copyright (c) 2026 Hasif / FDServer
 */

#include <jni.h>
#include <pthread.h>
#include <unistd.h>
#include <android/log.h>
#include <atomic>
#include <string>
#include <vector>
#include <mutex>
#include <chrono>
#include <cstring>
#include <cstdio>
#include <algorithm>

// ════════════════════════════════════════════════════════════════════════════
// Logging macros
// ════════════════════════════════════════════════════════════════════════════
#define LOG_TAG "NativeMonitor"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

namespace fdserver {

// ════════════════════════════════════════════════════════════════════════════
// JVM / JNI cached references
// ════════════════════════════════════════════════════════════════════════════
static JavaVM*    g_jvm                   = nullptr;
static jclass     g_bridge_class          = nullptr;
static jmethodID  g_get_foreground_method = nullptr;
static jmethodID  g_on_blocked_method     = nullptr;

// ════════════════════════════════════════════════════════════════════════════
// Thread control — all atomics for lock-free cross-thread access
// ════════════════════════════════════════════════════════════════════════════
static pthread_t         g_monitor_thread;
static std::atomic<bool> g_running{false};
static std::atomic<bool> g_screen_on{true};
static std::atomic<int>  g_poll_interval_ms{800};     // Base poll interval
static std::atomic<int>  g_battery_level{100};
static std::atomic<bool> g_strict_mode{false};
static std::atomic<bool> g_zen_mode{false};            // Feature #15
static std::atomic<bool> g_night_owl_active{false};    // Feature #20
static std::atomic<bool> g_reward_unlock{false};       // Feature #17
static std::atomic<int>  g_reward_unlock_remaining_s{0};
static std::atomic<bool> g_geofence_strict{false};     // Feature #19

// ════════════════════════════════════════════════════════════════════════════
// Blocked packages list
// ════════════════════════════════════════════════════════════════════════════
static std::mutex               g_packages_mutex;
static std::vector<std::string> g_blocked_packages;
// Temporarily unlocked packages (reward system)
static std::mutex               g_unlock_mutex;
static std::vector<std::string> g_unlocked_packages;

// ════════════════════════════════════════════════════════════════════════════
// Stats counters
// ════════════════════════════════════════════════════════════════════════════
static std::atomic<long long> g_total_polls{0};
static std::atomic<long long> g_total_blocks{0};
static std::atomic<long long> g_start_time{0};
static std::atomic<long long> g_total_screen_off_ms{0};
static std::atomic<long long> g_last_screen_off_time{0};
static std::atomic<int>       g_current_poll_actual_ms{0};  // Actual interval after adaptation

// CPU self-monitoring (Feature #41)
static std::atomic<long long> g_cpu_time_us{0};

// ════════════════════════════════════════════════════════════════════════════
// Debounce — prevents re-triggering for same package within window
// ════════════════════════════════════════════════════════════════════════════
static std::mutex                                g_debounce_mutex;
static std::string                               g_last_blocked_pkg;
static std::chrono::steady_clock::time_point     g_last_block_time;
static constexpr int DEBOUNCE_MS = 3000;

// ════════════════════════════════════════════════════════════════════════════
// Temptation pattern tracking (Feature #11)
// ════════════════════════════════════════════════════════════════════════════
struct TemptationEntry {
    char     pkg[128];
    int64_t  timestamp_ms;
    int      hour_of_day;   // 0-23, for pattern analysis
    int      day_of_week;   // 0-6 (Sun=0)
};

static std::mutex                    g_pattern_mutex;
static std::vector<TemptationEntry>  g_temptation_log;
static constexpr size_t MAX_PATTERN_LOG = 1000;

// ════════════════════════════════════════════════════════════════════════════
// Distraction chain detection (Feature #13)
// ════════════════════════════════════════════════════════════════════════════
static std::atomic<int> g_chain_count{0};
static std::chrono::steady_clock::time_point g_chain_start;
static constexpr int CHAIN_WINDOW_MS  = 60000;   // 60-second window
static constexpr int CHAIN_THRESHOLD  = 3;        // 3 blocked apps = chain

// ════════════════════════════════════════════════════════════════════════════
// Focus momentum score (Feature #12)
// ════════════════════════════════════════════════════════════════════════════
static std::atomic<int>       g_momentum_score{100};  // Start at 100, decrease on temptation
static std::atomic<long long> g_last_temptation_time{0};
static std::atomic<long long> g_session_start_time{0};

// ════════════════════════════════════════════════════════════════════════════
// Micro-break scheduler (Feature #18)
// ════════════════════════════════════════════════════════════════════════════
static std::atomic<bool>      g_break_suggested{false};
static std::atomic<long long> g_last_break_time{0};
static constexpr int BREAK_INTERVAL_MS = 25 * 60 * 1000;  // 25 minutes

// ════════════════════════════════════════════════════════════════════════════
// Thermal throttle detection (Feature #38)
// ════════════════════════════════════════════════════════════════════════════
static std::atomic<bool> g_thermal_throttled{false};

// ════════════════════════════════════════════════════════════════════════════
// Memory pressure monitor (Feature #37)
// ════════════════════════════════════════════════════════════════════════════
static std::atomic<bool> g_memory_pressure{false};

// ════════════════════════════════════════════════════════════════════════════
// Feature flags (Feature #50) — runtime toggles
// ════════════════════════════════════════════════════════════════════════════
struct FeatureFlags {
    std::atomic<bool> native_monitor{true};       // #1
    std::atomic<bool> screen_aware{true};          // #2
    std::atomic<bool> battery_adaptive{true};      // #3
    std::atomic<bool> smart_debounce{true};         // #8
    std::atomic<bool> temptation_pattern{true};     // #11
    std::atomic<bool> momentum_score{true};         // #12
    std::atomic<bool> chain_breaker{true};          // #13
    std::atomic<bool> zen_mode{false};              // #15
    std::atomic<bool> reward_unlock{false};         // #17
    std::atomic<bool> micro_break{true};            // #18
    std::atomic<bool> night_owl{false};             // #20
    std::atomic<bool> cpu_self_monitor{true};       // #41
    std::atomic<bool> thermal_throttle{true};       // #38
    std::atomic<bool> memory_monitor{true};         // #37
};

static FeatureFlags g_flags;

// ════════════════════════════════════════════════════════════════════════════
// Helper: get current time in milliseconds
// ════════════════════════════════════════════════════════════════════════════
static inline int64_t now_ms() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
}

static inline int64_t steady_ms() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

// ════════════════════════════════════════════════════════════════════════════
// Battery-adaptive poll interval calculator
// ════════════════════════════════════════════════════════════════════════════
static int getAdaptivePollInterval() {
    int base = g_poll_interval_ms.load(std::memory_order_relaxed);
    
    if (!g_flags.battery_adaptive.load(std::memory_order_relaxed)) {
        return base;
    }
    
    int battery = g_battery_level.load(std::memory_order_relaxed);
    int result;
    
    if (battery <= 5)       result = 0;            // Stop — critical battery
    else if (battery <= 10) result = base * 6;     // 6x slower (4.8s)
    else if (battery <= 15) result = base * 4;     // 4x slower (3.2s)
    else if (battery <= 30) result = base * 2;     // 2x slower (1.6s)
    else                    result = base;         // Normal (0.8s)
    
    // Thermal throttling → double the interval
    if (g_flags.thermal_throttle.load(std::memory_order_relaxed) &&
        g_thermal_throttled.load(std::memory_order_relaxed)) {
        result = result > 0 ? result * 2 : 0;
    }
    
    // Memory pressure → increase by 50%
    if (g_flags.memory_monitor.load(std::memory_order_relaxed) &&
        g_memory_pressure.load(std::memory_order_relaxed)) {
        result = result > 0 ? result * 3 / 2 : 0;
    }
    
    g_current_poll_actual_ms.store(result, std::memory_order_relaxed);
    return result;
}

// ════════════════════════════════════════════════════════════════════════════
// Smart debounce — prevents re-triggering for same package
// ════════════════════════════════════════════════════════════════════════════
static bool isDebounced(const std::string& pkg) {
    if (!g_flags.smart_debounce.load(std::memory_order_relaxed)) return false;
    
    std::lock_guard<std::mutex> lock(g_debounce_mutex);
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        now - g_last_block_time).count();
    
    if (pkg == g_last_blocked_pkg && elapsed < DEBOUNCE_MS) {
        return true;  // Same package, within debounce window
    }
    
    g_last_blocked_pkg = pkg;
    g_last_block_time  = now;
    return false;
}

// ════════════════════════════════════════════════════════════════════════════
// Temptation pattern logger
// ════════════════════════════════════════════════════════════════════════════
static void logTemptation(const std::string& pkg) {
    if (!g_flags.temptation_pattern.load(std::memory_order_relaxed)) return;
    
    std::lock_guard<std::mutex> lock(g_pattern_mutex);
    
    TemptationEntry entry{};
    strncpy(entry.pkg, pkg.c_str(), sizeof(entry.pkg) - 1);
    entry.timestamp_ms = now_ms();
    
    // Calculate hour/day for pattern analysis
    time_t raw_time = entry.timestamp_ms / 1000;
    struct tm* time_info = localtime(&raw_time);
    if (time_info) {
        entry.hour_of_day = time_info->tm_hour;
        entry.day_of_week = time_info->tm_wday;
    }
    
    g_temptation_log.push_back(entry);
    if (g_temptation_log.size() > MAX_PATTERN_LOG) {
        g_temptation_log.erase(g_temptation_log.begin());
    }
}

// ════════════════════════════════════════════════════════════════════════════
// Distraction chain detector
// ════════════════════════════════════════════════════════════════════════════
static bool checkDistractionChain() {
    if (!g_flags.chain_breaker.load(std::memory_order_relaxed)) return false;
    
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        now - g_chain_start).count();
    
    if (elapsed > CHAIN_WINDOW_MS) {
        g_chain_count.store(1, std::memory_order_relaxed);
        g_chain_start = now;
        return false;
    }
    
    int count = g_chain_count.fetch_add(1, std::memory_order_relaxed) + 1;
    return count >= CHAIN_THRESHOLD;
}

// ════════════════════════════════════════════════════════════════════════════
// Focus momentum score updater
// ════════════════════════════════════════════════════════════════════════════
static void updateMomentumScore(bool temptation_hit) {
    if (!g_flags.momentum_score.load(std::memory_order_relaxed)) return;
    
    if (temptation_hit) {
        // Each temptation drops score by 8 points
        int current = g_momentum_score.load(std::memory_order_relaxed);
        int next = std::max(0, current - 8);
        g_momentum_score.store(next, std::memory_order_relaxed);
        g_last_temptation_time.store(now_ms(), std::memory_order_relaxed);
    } else {
        // Recovery: +1 per poll cycle when no temptation
        int current = g_momentum_score.load(std::memory_order_relaxed);
        if (current < 100) {
            int64_t last = g_last_temptation_time.load(std::memory_order_relaxed);
            int64_t elapsed = now_ms() - last;
            // Recover 1 point every 30 seconds of clean time
            if (elapsed > 30000) {
                g_momentum_score.store(std::min(100, current + 1), std::memory_order_relaxed);
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// Micro-break suggestion checker
// ════════════════════════════════════════════════════════════════════════════
static void checkMicroBreak() {
    if (!g_flags.micro_break.load(std::memory_order_relaxed)) return;
    
    int64_t last = g_last_break_time.load(std::memory_order_relaxed);
    int64_t elapsed = now_ms() - last;
    
    if (elapsed > BREAK_INTERVAL_MS && !g_break_suggested.load(std::memory_order_relaxed)) {
        g_break_suggested.store(true, std::memory_order_relaxed);
        LOGI("Micro-break suggested after 25 minutes of focus");
    }
}

// ════════════════════════════════════════════════════════════════════════════
// Check if package is temporarily unlocked (reward system)
// ════════════════════════════════════════════════════════════════════════════
static bool isPackageUnlocked(const std::string& pkg) {
    if (!g_flags.reward_unlock.load(std::memory_order_relaxed)) return false;
    if (!g_reward_unlock.load(std::memory_order_relaxed)) return false;
    
    std::lock_guard<std::mutex> lock(g_unlock_mutex);
    for (const auto& up : g_unlocked_packages) {
        if (up == pkg) return true;
    }
    return false;
}

// ════════════════════════════════════════════════════════════════════════════
// Main monitoring loop — runs on dedicated pthread
// ════════════════════════════════════════════════════════════════════════════
static void* monitorLoop(void* arg) {
    JNIEnv* env = nullptr;
    if (g_jvm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
        LOGE("Failed to attach monitor thread to JVM");
        return nullptr;
    }
    
    LOGI("╔══════════════════════════════════════════════╗");
    LOGI("║  FDServer Native Monitor Engine Started      ║");
    LOGI("╚══════════════════════════════════════════════╝");
    
    g_start_time.store(now_ms(), std::memory_order_relaxed);
    g_session_start_time.store(now_ms(), std::memory_order_relaxed);
    g_last_break_time.store(now_ms(), std::memory_order_relaxed);
    
    while (g_running.load(std::memory_order_acquire)) {
        auto cycle_start = std::chrono::steady_clock::now();
        
        // ─── Screen-aware power gating ──────────────────────────────────
        if (g_flags.screen_aware.load(std::memory_order_relaxed) &&
            !g_screen_on.load(std::memory_order_relaxed)) {
            // Screen off → deep sleep, zero polling
            usleep(5000000);  // 5 seconds
            continue;
        }
        
        // ─── Calculate adaptive poll interval ───────────────────────────
        int interval = getAdaptivePollInterval();
        if (interval <= 0) {
            // Critical battery — hibernate
            usleep(30000000);  // 30 seconds
            continue;
        }
        
        // ─── Query foreground package via JNI ───────────────────────────
        jstring fg_pkg = nullptr;
        bool jni_ok = true;
        
        fg_pkg = (jstring)env->CallStaticObjectMethod(
            g_bridge_class, g_get_foreground_method);
        
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
            jni_ok = false;
        }
        
        g_total_polls.fetch_add(1, std::memory_order_relaxed);
        
        if (jni_ok && fg_pkg != nullptr) {
            const char* pkg_cstr = env->GetStringUTFChars(fg_pkg, nullptr);
            if (pkg_cstr != nullptr) {
                std::string current_pkg(pkg_cstr);
                env->ReleaseStringUTFChars(fg_pkg, pkg_cstr);
                
                // ─── Check against blocked list ─────────────────────────
                bool is_blocked = false;
                {
                    std::lock_guard<std::mutex> lock(g_packages_mutex);
                    for (const auto& bp : g_blocked_packages) {
                        if (current_pkg == bp) {
                            is_blocked = true;
                            break;
                        }
                    }
                }
                
                // ─── Skip if temporarily unlocked (reward system) ───────
                if (is_blocked && isPackageUnlocked(current_pkg)) {
                    is_blocked = false;
                }
                
                // ─── Trigger intervention if blocked ────────────────────
                if (is_blocked && !isDebounced(current_pkg)) {
                    g_total_blocks.fetch_add(1, std::memory_order_relaxed);
                    logTemptation(current_pkg);
                    updateMomentumScore(true);
                    bool is_chain = checkDistractionChain();
                    
                    // Determine intervention reason
                    const char* reason;
                    if (g_zen_mode.load(std::memory_order_relaxed)) {
                        reason = "zen_mode_active";
                    } else if (is_chain) {
                        reason = "distraction_chain";
                    } else if (g_strict_mode.load(std::memory_order_relaxed)) {
                        reason = "focus_lock_active";
                    } else if (g_night_owl_active.load(std::memory_order_relaxed)) {
                        reason = "night_owl_protection";
                    } else if (g_geofence_strict.load(std::memory_order_relaxed)) {
                        reason = "focus_zone_active";
                    } else {
                        reason = "native_blocker";
                    }
                    
                    // Call Kotlin intervention handler via JNI
                    jstring j_pkg    = env->NewStringUTF(current_pkg.c_str());
                    jstring j_reason = env->NewStringUTF(reason);
                    env->CallStaticVoidMethod(g_bridge_class, g_on_blocked_method,
                                              j_pkg, j_reason);
                    env->DeleteLocalRef(j_pkg);
                    env->DeleteLocalRef(j_reason);
                    
                    if (env->ExceptionCheck()) {
                        env->ExceptionClear();
                    }
                    
                    LOGW("⛔ Blocked: %s | reason=%s chain=%d momentum=%d",
                         current_pkg.c_str(), reason, is_chain,
                         g_momentum_score.load(std::memory_order_relaxed));
                } else if (!is_blocked) {
                    // Clean poll — recover momentum
                    updateMomentumScore(false);
                }
            }
            env->DeleteLocalRef(fg_pkg);
        }
        
        // ─── Micro-break scheduler ──────────────────────────────────────
        checkMicroBreak();
        
        // ─── CPU self-monitoring ────────────────────────────────────────
        if (g_flags.cpu_self_monitor.load(std::memory_order_relaxed)) {
            auto cycle_end = std::chrono::steady_clock::now();
            auto cycle_us = std::chrono::duration_cast<std::chrono::microseconds>(
                cycle_end - cycle_start).count();
            g_cpu_time_us.fetch_add(cycle_us, std::memory_order_relaxed);
        }
        
        // ─── Sleep until next poll ──────────────────────────────────────
        usleep(interval * 1000);
    }
    
    LOGI("Native monitor thread exiting cleanly");
    g_jvm->DetachCurrentThread();
    return nullptr;
}

} // namespace fdserver


// ════════════════════════════════════════════════════════════════════════════
// JNI Exports
// ════════════════════════════════════════════════════════════════════════════

extern "C" {

/**
 * Called by JVM when the native library is loaded.
 * Caches global references to the Kotlin bridge class and methods.
 */
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* /*reserved*/) {
    fdserver::g_jvm = vm;
    JNIEnv* env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK || env == nullptr) {
        LOGE("JNI_OnLoad: Failed to get JNIEnv");
        return JNI_VERSION_1_6;
    }
    
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }
    
    // Cache the Kotlin bridge class (global ref survives GC)
    jclass localClass = env->FindClass(
        "com/hasif/fdserver/fdserver/focus_guard/NativeMonitorBridge");
    if (localClass == nullptr) {
        LOGE("JNI_OnLoad: NativeMonitorBridge class not found");
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
        }
        return JNI_VERSION_1_6;
    }
    fdserver::g_bridge_class = (jclass)env->NewGlobalRef(localClass);
    env->DeleteLocalRef(localClass);
    
    // Cache method IDs
    fdserver::g_get_foreground_method = env->GetStaticMethodID(
        fdserver::g_bridge_class, "getForegroundPackage", "()Ljava/lang/String;");
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }

    fdserver::g_on_blocked_method = env->GetStaticMethodID(
        fdserver::g_bridge_class, "onBlockedAppDetected",
        "(Ljava/lang/String;Ljava/lang/String;)V");
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }
    
    if (!fdserver::g_get_foreground_method || !fdserver::g_on_blocked_method) {
        LOGW("JNI_OnLoad: Some bridge methods could not be cached");
    } else {
        LOGI("✅ FDServer NDK Monitor library loaded (JNI_VERSION_1_6)");
    }
    return JNI_VERSION_1_6;
}

// ─── Core lifecycle ────────────────────────────────────────────────────────

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeStartMonitor(
    JNIEnv*, jclass) {
    if (fdserver::g_running.load(std::memory_order_acquire)) {
        LOGW("Monitor already running — ignoring start request");
        return;
    }
    fdserver::g_running.store(true, std::memory_order_release);
    fdserver::g_momentum_score.store(100, std::memory_order_relaxed);
    fdserver::g_chain_count.store(0, std::memory_order_relaxed);
    fdserver::g_break_suggested.store(false, std::memory_order_relaxed);
    pthread_create(&fdserver::g_monitor_thread, nullptr, fdserver::monitorLoop, nullptr);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeStopMonitor(
    JNIEnv*, jclass) {
    if (!fdserver::g_running.load(std::memory_order_acquire)) return;
    fdserver::g_running.store(false, std::memory_order_release);
    pthread_join(fdserver::g_monitor_thread, nullptr);
    LOGI("Monitor thread joined and stopped");
}

// ─── Configuration setters ────────────────────────────────────────────────

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetBlockedPackages(
    JNIEnv* env, jclass, jobjectArray packages) {
    std::lock_guard<std::mutex> lock(fdserver::g_packages_mutex);
    fdserver::g_blocked_packages.clear();
    
    int len = env->GetArrayLength(packages);
    fdserver::g_blocked_packages.reserve(len);
    for (int i = 0; i < len; i++) {
        auto jstr = (jstring)env->GetObjectArrayElement(packages, i);
        const char* cstr = env->GetStringUTFChars(jstr, nullptr);
        fdserver::g_blocked_packages.emplace_back(cstr);
        env->ReleaseStringUTFChars(jstr, cstr);
        env->DeleteLocalRef(jstr);
    }
    LOGI("Blocked packages updated: %d entries", len);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetUnlockedPackages(
    JNIEnv* env, jclass, jobjectArray packages) {
    std::lock_guard<std::mutex> lock(fdserver::g_unlock_mutex);
    fdserver::g_unlocked_packages.clear();
    int len = env->GetArrayLength(packages);
    for (int i = 0; i < len; i++) {
        auto jstr = (jstring)env->GetObjectArrayElement(packages, i);
        const char* cstr = env->GetStringUTFChars(jstr, nullptr);
        fdserver::g_unlocked_packages.emplace_back(cstr);
        env->ReleaseStringUTFChars(jstr, cstr);
        env->DeleteLocalRef(jstr);
    }
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetPollInterval(
    JNIEnv*, jclass, jint intervalMs) {
    fdserver::g_poll_interval_ms.store(intervalMs, std::memory_order_relaxed);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetScreenState(
    JNIEnv*, jclass, jboolean isOn) {
    bool was_on = fdserver::g_screen_on.load(std::memory_order_relaxed);
    fdserver::g_screen_on.store(isOn, std::memory_order_relaxed);
    
    // Track screen-off time for analytics
    if (was_on && !isOn) {
        fdserver::g_last_screen_off_time.store(fdserver::now_ms(), std::memory_order_relaxed);
    } else if (!was_on && isOn) {
        int64_t off_start = fdserver::g_last_screen_off_time.load(std::memory_order_relaxed);
        if (off_start > 0) {
            int64_t off_duration = fdserver::now_ms() - off_start;
            fdserver::g_total_screen_off_ms.fetch_add(off_duration, std::memory_order_relaxed);
        }
    }
    LOGD("Screen state → %s", isOn ? "ON" : "OFF");
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetBatteryLevel(
    JNIEnv*, jclass, jint level) {
    fdserver::g_battery_level.store(level, std::memory_order_relaxed);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetStrictMode(
    JNIEnv*, jclass, jboolean strict) {
    fdserver::g_strict_mode.store(strict, std::memory_order_relaxed);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetZenMode(
    JNIEnv*, jclass, jboolean zen) {
    fdserver::g_zen_mode.store(zen, std::memory_order_relaxed);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetNightOwl(
    JNIEnv*, jclass, jboolean active) {
    fdserver::g_night_owl_active.store(active, std::memory_order_relaxed);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetRewardUnlock(
    JNIEnv*, jclass, jboolean unlock, jint remainingSeconds) {
    fdserver::g_reward_unlock.store(unlock, std::memory_order_relaxed);
    fdserver::g_reward_unlock_remaining_s.store(remainingSeconds, std::memory_order_relaxed);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetGeofenceStrict(
    JNIEnv*, jclass, jboolean active) {
    fdserver::g_geofence_strict.store(active, std::memory_order_relaxed);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetThermalThrottled(
    JNIEnv*, jclass, jboolean throttled) {
    fdserver::g_thermal_throttled.store(throttled, std::memory_order_relaxed);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetMemoryPressure(
    JNIEnv*, jclass, jboolean pressure) {
    fdserver::g_memory_pressure.store(pressure, std::memory_order_relaxed);
}

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeAcknowledgeBreak(
    JNIEnv*, jclass) {
    fdserver::g_break_suggested.store(false, std::memory_order_relaxed);
    fdserver::g_last_break_time.store(fdserver::now_ms(), std::memory_order_relaxed);
}

// ─── Feature flag setters ─────────────────────────────────────────────────

JNIEXPORT void JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeSetFeatureFlag(
    JNIEnv* env, jclass, jstring flagName, jboolean enabled) {
    const char* name = env->GetStringUTFChars(flagName, nullptr);
    std::string flag(name);
    env->ReleaseStringUTFChars(flagName, name);
    
    if      (flag == "native_monitor")    fdserver::g_flags.native_monitor.store(enabled);
    else if (flag == "screen_aware")      fdserver::g_flags.screen_aware.store(enabled);
    else if (flag == "battery_adaptive")  fdserver::g_flags.battery_adaptive.store(enabled);
    else if (flag == "smart_debounce")    fdserver::g_flags.smart_debounce.store(enabled);
    else if (flag == "temptation_pattern")fdserver::g_flags.temptation_pattern.store(enabled);
    else if (flag == "momentum_score")    fdserver::g_flags.momentum_score.store(enabled);
    else if (flag == "chain_breaker")     fdserver::g_flags.chain_breaker.store(enabled);
    else if (flag == "zen_mode")          fdserver::g_flags.zen_mode.store(enabled);
    else if (flag == "reward_unlock")     fdserver::g_flags.reward_unlock.store(enabled);
    else if (flag == "micro_break")       fdserver::g_flags.micro_break.store(enabled);
    else if (flag == "night_owl")         fdserver::g_flags.night_owl.store(enabled);
    else if (flag == "cpu_self_monitor")  fdserver::g_flags.cpu_self_monitor.store(enabled);
    else if (flag == "thermal_throttle")  fdserver::g_flags.thermal_throttle.store(enabled);
    else if (flag == "memory_monitor")    fdserver::g_flags.memory_monitor.store(enabled);
    
    LOGI("Feature flag [%s] → %s", flag.c_str(), enabled ? "ON" : "OFF");
}

// ─── Stats / telemetry getters ────────────────────────────────────────────

JNIEXPORT jstring JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeGetStats(
    JNIEnv* env, jclass) {
    
    char buf[1024];
    snprintf(buf, sizeof(buf),
        "{\"running\":%s,\"screenOn\":%s,\"pollIntervalMs\":%d,\"actualPollMs\":%d,"
        "\"batteryLevel\":%d,\"totalPolls\":%lld,\"totalBlocks\":%lld,"
        "\"blockedPkgCount\":%zu,\"strictMode\":%s,\"zenMode\":%s,"
        "\"momentumScore\":%d,\"chainCount\":%d,\"breakSuggested\":%s,"
        "\"startTime\":%lld,\"cpuTimeUs\":%lld,\"screenOffTimeMs\":%lld,"
        "\"temptationLogSize\":%zu,\"thermalThrottled\":%s,\"memoryPressure\":%s,"
        "\"nightOwl\":%s,\"rewardUnlock\":%s,\"geofenceStrict\":%s}",
        fdserver::g_running.load() ? "true" : "false",
        fdserver::g_screen_on.load() ? "true" : "false",
        fdserver::g_poll_interval_ms.load(),
        fdserver::g_current_poll_actual_ms.load(),
        fdserver::g_battery_level.load(),
        (long long)fdserver::g_total_polls.load(),
        (long long)fdserver::g_total_blocks.load(),
        fdserver::g_blocked_packages.size(),
        fdserver::g_strict_mode.load() ? "true" : "false",
        fdserver::g_zen_mode.load() ? "true" : "false",
        fdserver::g_momentum_score.load(),
        fdserver::g_chain_count.load(),
        fdserver::g_break_suggested.load() ? "true" : "false",
        (long long)fdserver::g_start_time.load(),
        (long long)fdserver::g_cpu_time_us.load(),
        (long long)fdserver::g_total_screen_off_ms.load(),
        fdserver::g_temptation_log.size(),
        fdserver::g_thermal_throttled.load() ? "true" : "false",
        fdserver::g_memory_pressure.load() ? "true" : "false",
        fdserver::g_night_owl_active.load() ? "true" : "false",
        fdserver::g_reward_unlock.load() ? "true" : "false",
        fdserver::g_geofence_strict.load() ? "true" : "false");
    
    return env->NewStringUTF(buf);
}

JNIEXPORT jstring JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeGetTemptationLog(
    JNIEnv* env, jclass) {
    
    std::lock_guard<std::mutex> lock(fdserver::g_pattern_mutex);
    
    // Build JSON array of temptation entries
    std::string json = "[";
    for (size_t i = 0; i < fdserver::g_temptation_log.size(); i++) {
        const auto& e = fdserver::g_temptation_log[i];
        if (i > 0) json += ",";
        char entry[256];
        snprintf(entry, sizeof(entry),
            "{\"pkg\":\"%s\",\"ts\":%lld,\"hour\":%d,\"day\":%d}",
            e.pkg, (long long)e.timestamp_ms, e.hour_of_day, e.day_of_week);
        json += entry;
    }
    json += "]";
    
    return env->NewStringUTF(json.c_str());
}

JNIEXPORT jint JNICALL
Java_com_hasif_fdserver_fdserver_focus_1guard_NativeMonitorBridge_nativeGetMomentumScore(
    JNIEnv*, jclass) {
    return fdserver::g_momentum_score.load(std::memory_order_relaxed);
}

} // extern "C"
