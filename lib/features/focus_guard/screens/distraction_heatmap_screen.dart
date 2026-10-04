import 'package:flutter/material.dart';
import '../models/audit_entry.dart';
import '../services/audit_service.dart';

/// Geospatial Distraction Heatmap & Hardware Sensor Guard Dashboard.
/// Implements Features #61, #62, #64, #65, #66, #69, and #70:
/// - Distraction Hotspot Clusters
/// - Walk-to-Unlock Kinetic Step Banking
/// - Driving Speed Detection (>25 km/h)
/// - Geofenced Focus Zones Configuration
/// - Wi-Fi Shield SSID Protection
/// - Sleep Sanctuary & Battery Throttle Status
class DistractionHeatmapScreen extends StatefulWidget {
  const DistractionHeatmapScreen({super.key});

  @override
  State<DistractionHeatmapScreen> createState() => _DistractionHeatmapScreenState();
}

class _DistractionHeatmapScreenState extends State<DistractionHeatmapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Sensor Telemetry
  KineticStepStatus _stepStatus = const KineticStepStatus(
    bankedSteps: 0,
    earnedMinutes: 0,
    usedMinutes: 0,
    remainingMinutes: 0,
  );
  Map<String, dynamic> _drivingStatus = {'isDriving': false, 'speedKmh': 0.0};
  bool _isSleepSanctuaryActive = false;
  Map<String, dynamic> _batteryStatus = {'isLowBatteryAway': false, 'batteryLevel': 100};

  // Geospatial Data
  List<Map<String, dynamic>> _distractionClusters = [];
  List<GeofenceZone> _geofenceZones = [];
  List<String> _wifiSsids = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      AuditService.getKineticStepStatus(),
      AuditService.getDrivingStatus(),
      AuditService.isSleepSanctuaryActive(),
      AuditService.getBatteryThrottleStatus(),
      AuditService.getDistractionCoordinates(),
      AuditService.getGeofenceZones(),
      AuditService.getWifiShieldSsids(),
    ]);

    if (mounted) {
      setState(() {
        _stepStatus = results[0] as KineticStepStatus;
        _drivingStatus = results[1] as Map<String, dynamic>;
        _isSleepSanctuaryActive = results[2] as bool;
        _batteryStatus = results[3] as Map<String, dynamic>;
        _distractionClusters = results[4] as List<Map<String, dynamic>>;
        _geofenceZones = results[5] as List<GeofenceZone>;
        _wifiSsids = results[6] as List<String>;
        _isLoading = false;
      });
    }
  }

  Future<void> _redeemKineticMinutes() async {
    if (_stepStatus.remainingMinutes < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 15 remaining kinetic minutes to redeem (1,000 steps = 15m).'),
        ),
      );
      return;
    }

    final success = await AuditService.consumeKineticMinutes(15);
    if (success) {
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF18181B),
            content: Row(
              children: [
                Icon(Icons.directions_walk_rounded, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 8),
                Text(
                  '15m Leisure Quota Unlocked via Step Banking!',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAddZoneDialog() async {
    final nameCtrl = TextEditingController(text: 'Office/Campus');
    final latCtrl = TextEditingController(text: '25.2048');
    final lngCtrl = TextEditingController(text: '55.2708');
    double radius = 150.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          title: const Text(
            '📍 Add Focus Geofence',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Zone Name', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dialogInputDec('e.g. University Library'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Latitude', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: latCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _dialogInputDec('25.2048'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Longitude', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: lngCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _dialogInputDec('55.2708'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Radius: ${radius.toInt()} meters',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Slider(
                  value: radius,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  activeColor: const Color(0xFF10B981),
                  inactiveColor: const Color(0xFF27272A),
                  onChanged: (val) => setDialogState(() => radius = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF71717A))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Zone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final name = nameCtrl.text.trim().isEmpty ? 'Focus Zone' : nameCtrl.text.trim();
      final lat = double.tryParse(latCtrl.text.trim()) ?? 0.0;
      final lng = double.tryParse(lngCtrl.text.trim()) ?? 0.0;
      final newZone = GeofenceZone(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        latitude: lat,
        longitude: lng,
        radiusMeters: radius,
        strictMode: true,
      );
      final updated = List<GeofenceZone>.from(_geofenceZones)..add(newZone);
      await AuditService.saveGeofenceZones(updated);
      await _loadAllData();
    }
  }

  Future<void> _deleteZone(String id) async {
    final updated = _geofenceZones.where((z) => z.id != id).toList();
    await AuditService.saveGeofenceZones(updated);
    await _loadAllData();
  }

  Future<void> _showAddWifiDialog() async {
    final ssidCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          '📶 Add Wi-Fi Auto-Shield SSID',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ssidCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _dialogInputDec('e.g. University_WiFi, Work_5G'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF71717A))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add SSID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && ssidCtrl.text.trim().isNotEmpty) {
      final updated = List<String>.from(_wifiSsids)..add(ssidCtrl.text.trim());
      await AuditService.saveWifiShieldSsids(updated);
      await _loadAllData();
    }
  }

  Future<void> _removeWifi(String ssid) async {
    final updated = _wifiSsids.where((s) => s != ssid).toList();
    await AuditService.saveWifiShieldSsids(updated);
    await _loadAllData();
  }

  InputDecoration _dialogInputDec(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF27272A),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF71717A)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        title: const Text(
          '🗺️ Geospatial & Kinetic Guard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF71717A)),
            tooltip: 'Refresh Telemetry',
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFFA1A1AA),
          tabs: const [
            Tab(icon: Icon(Icons.sensors, size: 18), text: 'Sensors HUD'),
            Tab(icon: Icon(Icons.pin_drop, size: 18), text: 'Distraction Map'),
            Tab(icon: Icon(Icons.security, size: 18), text: 'Zones & Wi-Fi'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSensorsHudTab(),
                _buildHeatmapTab(),
                _buildZonesTab(),
              ],
            ),
    );
  }

  // ─── TAB 1: SENSORS & KINETIC HUD ───
  Widget _buildSensorsHudTab() {
    final speed = (_drivingStatus['speedKmh'] as num?)?.toDouble() ?? 0.0;
    final isDriving = _drivingStatus['isDriving'] as bool? ?? false;
    final batteryLvl = (_batteryStatus['batteryLevel'] as num?)?.toInt() ?? 100;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Walk-to-Unlock / Kinetic Quota Card (#65)
        _buildKineticStepCard(),
        const SizedBox(height: 14),

        // Driving / Commute Shield Card (#62)
        _buildHudMetricCard(
          icon: Icons.directions_car_rounded,
          accentColor: const Color(0xFF06B6D4),
          title: 'Driving & Commute Shield (#62)',
          statusText: isDriving ? 'DRIVING SPEED DETECTED (>25 km/h)' : 'Stationary / Walking',
          detailText: 'Current Speed: ${speed.toStringAsFixed(1)} km/h. Feeds lock while driving.',
          isActive: isDriving,
        ),
        const SizedBox(height: 14),

        // Sleep Sanctuary Guard Card (#64)
        _buildHudMetricCard(
          icon: Icons.bedtime_rounded,
          accentColor: const Color(0xFFA855F7),
          title: 'Sleep Sanctuary Guard (#64)',
          statusText: _isSleepSanctuaryActive ? 'SANCTUARY ACTIVE (11 PM - 6 AM)' : 'Outside Bedtime Hours',
          detailText: 'Stationary night guard enforces ultra-dim monochrome friction to protect rest.',
          isActive: _isSleepSanctuaryActive,
        ),
        const SizedBox(height: 14),

        // Battery-Aware Travel Throttle Card (#69)
        _buildHudMetricCard(
          icon: Icons.battery_charging_full_rounded,
          accentColor: const Color(0xFFF59E0B),
          title: 'Battery Travel Throttle (#69)',
          statusText: batteryLvl < 30 ? 'CRITICAL BATTERY THROTTLE ACTIVE' : 'Battery Optimal ($batteryLvl%)',
          detailText: 'Freezes non-essential background processes when battery drops below 30%.',
          isActive: batteryLvl < 30,
        ),
      ],
    );
  }

  Widget _buildKineticStepCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_walk_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Walk-to-Unlock Kinetic Quota (#65)',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Hardware step counter banks 15m screen time per 1,000 steps',
                      style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepStat('Today Steps', '${_stepStatus.bankedSteps}', const Color(0xFF10B981)),
              _buildStepStat('Earned', '${_stepStatus.earnedMinutes}m', const Color(0xFF06B6D4)),
              _buildStepStat('Used', '${_stepStatus.usedMinutes}m', const Color(0xFFEF4444)),
              _buildStepStat('Remaining', '${_stepStatus.remainingMinutes}m', const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _stepStatus.progressRatio,
              backgroundColor: const Color(0xFF27272A),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.lock_open_rounded, size: 16),
              label: const Text('Redeem 15m Leisure Time (Consumes Quota)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _stepStatus.remainingMinutes >= 15 ? _redeemKineticMinutes : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF71717A), fontSize: 11)),
      ],
    );
  }

  Widget _buildHudMetricCard({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String statusText,
    required String detailText,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? accentColor.withValues(alpha: 0.5) : const Color(0xFF27272A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    color: isActive ? accentColor : const Color(0xFFA1A1AA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detailText,
                  style: const TextStyle(color: Color(0xFF71717A), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: GEOSPATIAL DISTRACTION HEATMAP (#70) ───
  Widget _buildHeatmapTab() {
    if (_distractionClusters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.map_outlined, color: Color(0xFF71717A), size: 48),
            SizedBox(height: 12),
            Text(
              'No Distraction Hotspots Logged',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Blocks with GPS coordinates will cluster here automatically.',
              style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _distractionClusters.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final cluster = _distractionClusters[index];
        final lat = (cluster['latitude'] as num?)?.toDouble() ?? 0.0;
        final lng = (cluster['longitude'] as num?)?.toDouble() ?? 0.0;
        final count = (cluster['count'] as num?)?.toInt() ?? 1;
        final pkg = cluster['packageName'] as String? ?? 'Distraction';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: count > 5 ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFF27272A),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (count > 5 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: count > 5 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hotspot #$index: $pkg',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 2),
                        Text(
                          '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}',
                          style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  count > 5 ? 'High Risk' : 'Moderate',
                  style: TextStyle(
                    color: count > 5 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── TAB 3: GEOFENCE ZONES & WI-FI AUTO-SHIELD (#61, #66) ───
  Widget _buildZonesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section A: Geofence Focus Zones (#61)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📍 Geofenced Focus Zones (#61)',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
              label: const Text('Add Zone', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
              onPressed: _showAddZoneDialog,
            ),
          ],
        ),
        const Text(
          'Automatically arms Strict Focus Mode upon entering radius (Work, Mosque, Library).',
          style: TextStyle(color: Color(0xFF71717A), fontSize: 11),
        ),
        const SizedBox(height: 10),
        if (_geofenceZones.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: const Center(
              child: Text(
                'No focus zones added yet. Tap "+ Add Zone" to create one.',
                style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
              ),
            ),
          )
        else
          ..._geofenceZones.map((zone) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${zone.latitude.toStringAsFixed(4)}, ${zone.longitude.toStringAsFixed(4)} (Radius: ${zone.radiusMeters.toInt()}m)',
                          style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                    onPressed: () => _deleteZone(zone.id),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 24),

        // Section B: Wi-Fi Auto-Shield SSIDs (#66)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📶 Wi-Fi Auto-Shield (#66)',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF06B6D4)),
              label: const Text('Add SSID', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12)),
              onPressed: _showAddWifiDialog,
            ),
          ],
        ),
        const Text(
          'Engages strict lock instantly when connecting to office or campus Wi-Fi networks.',
          style: TextStyle(color: Color(0xFF71717A), fontSize: 11),
        ),
        const SizedBox(height: 10),
        if (_wifiSsids.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: const Center(
              child: Text(
                'No Wi-Fi SSIDs configured yet.',
                style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _wifiSsids.map((ssid) {
              return Chip(
                backgroundColor: const Color(0xFF18181B),
                side: const BorderSide(color: Color(0xFF06B6D4)),
                avatar: const Icon(Icons.wifi_rounded, color: Color(0xFF06B6D4), size: 16),
                label: Text(ssid, style: const TextStyle(color: Colors.white, fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFFA1A1AA)),
                onDeleted: () => _removeWifi(ssid),
              );
            }).toList(),
          ),
      ],
    );
  }
}
