library;

/// Advanced feature definitions for the Focus Guard system.
/// Each feature has a unique key, display name, description, category,
/// battery impact level, and default state.
///
/// Features are organized into 7 categories matching the architecture plan.
/// All features are controlled via runtime feature flags that persist
/// to SharedPreferences and sync to the native C++ engine.

class AdvancedFeature {
  final String key;
  final String name;
  final String description;
  final String category;
  final int batteryImpact; // 0 = none, 1 = low, 2 = medium, 3 = high
  final bool defaultEnabled;
  final bool isNative; // true = controlled at C++ level

  const AdvancedFeature({
    required this.key,
    required this.name,
    required this.description,
    required this.category,
    this.batteryImpact = 1,
    this.defaultEnabled = true,
    this.isNative = false,
  });
}

/// All 50 advanced hidden features
const List<AdvancedFeature> allAdvancedFeatures = [
  // ─── Category 1: NDK Native Blocker (1-10) ─────────────────────────────
  AdvancedFeature(
    key: 'native_monitor',
    name: 'NDK Native Process Monitor',
    description: 'C++ monitoring thread detects foreground apps via UsageStatsManager. Works without accessibility service.',
    category: 'NDK Native Blocker',
    batteryImpact: 1,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'screen_aware',
    name: 'Screen-Aware Power Gating',
    description: 'Completely stops all monitoring when screen is off. Zero CPU usage during screen-off periods.',
    category: 'NDK Native Blocker',
    batteryImpact: 0,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'battery_adaptive',
    name: 'Battery-Adaptive Polling',
    description: 'Automatically slows monitoring when battery is low. Stops at critical levels (<5%).',
    category: 'NDK Native Blocker',
    batteryImpact: 0,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'dual_engine',
    name: 'Dual-Engine Fallback',
    description: 'Uses accessibility when available (richer Shorts detection). Falls back to NDK monitor when disabled.',
    category: 'NDK Native Blocker',
    batteryImpact: 1,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'native_overlay',
    name: 'Native Overlay Engine',
    description: 'Shows blocking overlay from native Android layer, works even when Flutter engine is not running.',
    category: 'NDK Native Blocker',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'kill_protection',
    name: 'Process Kill Protection',
    description: 'Auto-restarts monitoring service if killed by user or system via AlarmManager.',
    category: 'NDK Native Blocker',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'stealth_service',
    name: 'Stealth Foreground Service',
    description: 'Runs NDK monitor with minimal notification. Low visibility, maximum protection.',
    category: 'NDK Native Blocker',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'smart_debounce',
    name: 'Smart Debounce Engine',
    description: 'Native-level 3-second per-package deduplication. Prevents redundant interventions.',
    category: 'NDK Native Blocker',
    batteryImpact: 0,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'usage_persistence',
    name: 'Usage Quota Persistence',
    description: 'Stores hourly app usage data that survives app restarts and crashes.',
    category: 'NDK Native Blocker',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'cold_start_recovery',
    name: 'Cold Start Recovery',
    description: 'Immediately restores blocking on device boot without waiting for app to open.',
    category: 'NDK Native Blocker',
    batteryImpact: 0,
    defaultEnabled: true,
  ),

  // ─── Category 2: Intelligence Features (11-20) ─────────────────────────
  AdvancedFeature(
    key: 'temptation_pattern',
    name: 'Temptation Pattern AI',
    description: 'Tracks which apps are opened at which times to identify behavioral patterns.',
    category: 'Focus Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'momentum_score',
    name: 'Focus Momentum Score',
    description: 'Real-time 0-100 score showing how well you avoid distractions. Drops on temptation, recovers over time.',
    category: 'Focus Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'chain_breaker',
    name: 'Distraction Chain Breaker',
    description: 'Detects rapid app-switching (3+ blocked apps in 60s) and triggers stronger intervention.',
    category: 'Focus Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'social_pressure_shield',
    name: 'Social Pressure Shield',
    description: 'Detects when you open a blocked app from a notification and provides extra friction.',
    category: 'Focus Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'zen_mode',
    name: 'Zen Mode Timer',
    description: 'Complete lockdown with no override for a set duration. The nuclear focus option.',
    category: 'Focus Intelligence',
    batteryImpact: 0,
    defaultEnabled: false,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'accountability_partner',
    name: 'Accountability Partner',
    description: 'Export weekly distraction reports as shareable text or images.',
    category: 'Focus Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'reward_unlock',
    name: 'Reward Unlock System',
    description: 'After sustained focus time, temporarily unlock a blocked app for 5 minutes as a reward.',
    category: 'Focus Intelligence',
    batteryImpact: 0,
    defaultEnabled: false,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'micro_break',
    name: 'Micro-Break Scheduler',
    description: 'Suggests 2-minute breaks every 25 minutes to prevent burnout while maintaining focus.',
    category: 'Focus Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'focus_zone_geofence',
    name: 'Focus Zone Geofencing',
    description: 'Auto-activate strict mode when at specific GPS locations (office, school).',
    category: 'Focus Intelligence',
    batteryImpact: 2,
    defaultEnabled: false,
  ),
  AdvancedFeature(
    key: 'night_owl',
    name: 'Night Owl Protector',
    description: 'Auto-enable strict blocking between configurable night hours (default 11PM-6AM).',
    category: 'Focus Intelligence',
    batteryImpact: 0,
    defaultEnabled: false,
    isNative: true,
  ),

  // ─── Category 3: Shorts & Reels Shield (21-25) ─────────────────────────
  AdvancedFeature(
    key: 'optimized_scanner',
    name: 'Optimized Tree Scanner',
    description: 'Reduced scan depth (15→8) and 2x debounce for 90% less CPU when scanning Shorts/Reels.',
    category: 'Shorts & Reels Shield',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'event_type_filter',
    name: 'Event Type Filter',
    description: 'Only listens to 3 event types instead of ALL. Eliminates ~90% of accessibility events.',
    category: 'Shorts & Reels Shield',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'package_scoped_events',
    name: 'Package-Scoped Events',
    description: 'Accessibility service only receives events from blocked + Shorts host apps. Ignores everything else.',
    category: 'Shorts & Reels Shield',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'tiktok_detection',
    name: 'TikTok Deep Detection',
    description: 'Block TikTok For You feed and live streams using specialized content detection.',
    category: 'Shorts & Reels Shield',
    batteryImpact: 1,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'twitter_explore_shield',
    name: 'Twitter/X Explore Shield',
    description: 'Block Twitter Explore tab and trending content to prevent doom-scrolling.',
    category: 'Shorts & Reels Shield',
    batteryImpact: 1,
    defaultEnabled: true,
  ),

  // ─── Category 4: Auto Trail Battery (26-35) ────────────────────────────
  AdvancedFeature(
    key: 'activity_adaptive_accuracy',
    name: 'Activity-Adaptive Accuracy',
    description: 'Uses low accuracy when driving (fast movement needs less precision), high when walking.',
    category: 'Auto Trail Battery',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'night_pause_trail',
    name: 'Night Pause Mode',
    description: 'Auto-pause location tracking between 12AM-5AM to save battery during sleep.',
    category: 'Auto Trail Battery',
    batteryImpact: 0,
    defaultEnabled: false,
  ),
  AdvancedFeature(
    key: 'batched_updates',
    name: 'Android Batched Updates',
    description: 'Use system-batched location updates with 60s interval for optimal battery on Android.',
    category: 'Auto Trail Battery',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'wifi_location',
    name: 'WiFi-Based Location',
    description: 'Use network-based location (zero GPS drain) when connected to known WiFi networks.',
    category: 'Auto Trail Battery',
    batteryImpact: 0,
    defaultEnabled: false,
  ),
  AdvancedFeature(
    key: 'significant_motion',
    name: 'Significant Movement API',
    description: 'Use significant motion sensor instead of continuous GPS on supported devices.',
    category: 'Auto Trail Battery',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'battery_saver_trail',
    name: 'Battery Saver Mode (Trail)',
    description: 'When battery <20%, switches to 200m filter and low accuracy for location tracking.',
    category: 'Auto Trail Battery',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'smart_resume',
    name: 'Smart Resume',
    description: 'Get one immediate location fix when phone wakes, then resume normal tracking.',
    category: 'Auto Trail Battery',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'altitude_tracking',
    name: 'Altitude Tracking',
    description: 'Log altitude data for elevation profiles during hiking or travel.',
    category: 'Auto Trail Battery',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'speed_anomaly_filter',
    name: 'Speed Anomaly Filter',
    description: 'Discard GPS points that imply impossible speed (>300 km/h = GPS glitch).',
    category: 'Auto Trail Battery',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'offline_geocode_cache',
    name: 'Offline Geocoding Cache',
    description: 'Persist geocode cache to SQLite for offline operation across restarts.',
    category: 'Auto Trail Battery',
    batteryImpact: 0,
    defaultEnabled: true,
  ),

  // ─── Category 5: System Intelligence (36-42) ───────────────────────────
  AdvancedFeature(
    key: 'battery_drain_analytics',
    name: 'Battery Drain Analytics',
    description: 'Track which features use the most battery and show breakdown in settings.',
    category: 'System Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'memory_monitor',
    name: 'Memory Pressure Monitor',
    description: 'Monitors system memory and auto-reduces service footprint under pressure.',
    category: 'System Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'thermal_throttle',
    name: 'Thermal Throttle Detector',
    description: 'Detects CPU thermal throttling via battery temp and reduces monitoring frequency when hot.',
    category: 'System Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'storage_health',
    name: 'Storage Health Check',
    description: 'Monitors available storage and warns when low. Pauses SQLite-heavy operations at <500MB.',
    category: 'System Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'network_quality_monitor',
    name: 'Network Quality Monitor',
    description: 'Tracks connection quality and defers geocoding/sync when connectivity is poor.',
    category: 'System Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'cpu_self_monitor',
    name: 'CPU Usage Self-Monitor',
    description: 'NDK engine tracks its own CPU time. Auto-throttles if exceeding 2% CPU budget.',
    category: 'System Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
    isNative: true,
  ),
  AdvancedFeature(
    key: 'doze_awareness',
    name: 'Doze Mode Awareness',
    description: 'Detects Android Doze mode and gracefully pauses. Immediately resumes on Doze exit.',
    category: 'System Intelligence',
    batteryImpact: 0,
    defaultEnabled: true,
  ),

  // ─── Category 6: Privacy & Security (43-47) ────────────────────────────
  AdvancedFeature(
    key: 'app_lock_pin',
    name: 'App Lock PIN',
    description: 'Require PIN to disable Focus Guard or change settings. Prevent self-sabotage.',
    category: 'Privacy & Security',
    batteryImpact: 0,
    defaultEnabled: false,
  ),
  AdvancedFeature(
    key: 'tamper_detection',
    name: 'Tamper Detection',
    description: 'Detect if user tries to force-stop service, clear data, or uninstall. Log and resist.',
    category: 'Privacy & Security',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'encrypted_settings',
    name: 'Encrypted Settings Store',
    description: 'Encrypt blocked app list and schedules using Android Keystore.',
    category: 'Privacy & Security',
    batteryImpact: 0,
    defaultEnabled: false,
  ),
  AdvancedFeature(
    key: 'permission_health',
    name: 'Permission Health Check',
    description: 'Monitors all required permissions and alerts if any are revoked.',
    category: 'Privacy & Security',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'stealth_icon',
    name: 'Stealth Icon Mode',
    description: 'Optionally hide the app from launcher. Access only via dialer code or notification.',
    category: 'Privacy & Security',
    batteryImpact: 0,
    defaultEnabled: false,
  ),

  // ─── Category 7: Developer Power Features (48-50) ──────────────────────
  AdvancedFeature(
    key: 'native_profiler',
    name: 'Native Performance Profiler',
    description: 'Real-time NDK engine metrics: poll count, CPU time, memory usage, thread state.',
    category: 'Developer & Power',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
  AdvancedFeature(
    key: 'debug_logcat_bridge',
    name: 'Debug Logcat Bridge',
    description: 'Stream native C++ logs to Flutter UI for debugging without ADB connection.',
    category: 'Developer & Power',
    batteryImpact: 1,
    defaultEnabled: false,
  ),
  AdvancedFeature(
    key: 'feature_flag_system',
    name: 'Feature Flag System',
    description: 'Runtime toggle for each of the 50 features. Enable/disable without app restart.',
    category: 'Developer & Power',
    batteryImpact: 0,
    defaultEnabled: true,
  ),
];

/// Get features grouped by category
Map<String, List<AdvancedFeature>> getFeaturesByCategory() {
  final map = <String, List<AdvancedFeature>>{};
  for (final f in allAdvancedFeatures) {
    map.putIfAbsent(f.category, () => []).add(f);
  }
  return map;
}

/// Category icons for the UI
const Map<String, String> categoryIcons = {
  'NDK Native Blocker': '⚡',
  'Focus Intelligence': '🧠',
  'Shorts & Reels Shield': '🛡️',
  'Auto Trail Battery': '📍',
  'System Intelligence': '🔧',
  'Privacy & Security': '🔒',
  'Developer & Power': '🔬',
};

/// Category descriptions
const Map<String, String> categoryDescriptions = {
  'NDK Native Blocker': 'C++ native engine for app blocking without accessibility service',
  'Focus Intelligence': 'AI-powered focus tracking, pattern detection, and smart interventions',
  'Shorts & Reels Shield': 'Optimized short-form content detection with minimal battery drain',
  'Auto Trail Battery': 'Battery-efficient location tracking optimizations',
  'System Intelligence': 'Self-monitoring CPU, memory, thermal, and storage health',
  'Privacy & Security': 'App lock, tamper detection, and encrypted settings',
  'Developer & Power': 'Advanced debugging, profiling, and feature management tools',
};
