import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../shared/widgets/resource_telemetry_modal.dart';
import '../providers/auto_trail_provider.dart';
import '../services/auto_trail_permission_service.dart';
import '../services/trail_export_service.dart';
import '../widgets/trail_map_view.dart';
import '../widgets/trail_permission_banner.dart';
import '../widgets/trail_timeline_card.dart';
import '../widgets/trail_visit_card.dart';

class AutoTrailScreen extends StatefulWidget {
  const AutoTrailScreen({super.key});

  @override
  State<AutoTrailScreen> createState() => _AutoTrailScreenState();
}

class _AutoTrailScreenState extends State<AutoTrailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showExportSheet(BuildContext context, AutoTrailProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.download, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Export Trail Data',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(LucideIcons.fileCode, color: Color(0xFF3B82F6)),
                title: const Text('Export as GPX'),
                subtitle: const Text('Compatible with Strava, Garmin, and GIS tools'),
                onTap: () {
                  Navigator.pop(ctx);
                  provider.exportDayTrail('gpx');
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.map, color: Color(0xFF10B981)),
                title: const Text('Export as GeoJSON'),
                subtitle: const Text('Standard open format with point coordinates & route'),
                onTap: () {
                  Navigator.pop(ctx);
                  provider.exportDayTrail('geojson');
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.share2, color: Color(0xFF8B5CF6)),
                title: const Text('Share Day Summary Text'),
                subtitle: const Text('Share list of places & Google Maps links'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (provider.points.isNotEmpty) {
                    final summary = TrailExportService.generateTextSummary(
                      provider.points,
                      provider.selectedDate,
                    );
                    TrailExportService.shareText(summary, subject: 'Auto Trail Summary');
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showClearConfirmDialog(BuildContext context, AutoTrailProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text('Clear All History?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all recorded trail points and visits from the local SQLite database. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ShadButton.destructive(
            size: ShadButtonSize.sm,
            onPressed: () {
              Navigator.pop(ctx);
              provider.clearAllHistory();
            },
            child: const Text('Clear Database'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, AutoTrailProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      provider.setSelectedDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AutoTrailProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildAppBar(context, provider, isDark),

            // Date Navigation and Search Bar
            _buildDateAndSearchBar(context, provider, isDark),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF3B82F6),
                labelColor: const Color(0xFF3B82F6),
                unselectedLabelColor: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(
                    icon: const Icon(LucideIcons.list, size: 16),
                    text: 'Timeline (${provider.points.length})',
                  ),
                  const Tab(
                    icon: Icon(LucideIcons.map, size: 16),
                    text: 'Map View',
                  ),
                  Tab(
                    icon: const Icon(LucideIcons.building2, size: 16),
                    text: 'Visits (${provider.visits.length})',
                  ),
                ],
              ),
            ),

            // Tab View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Timeline
                  _buildTimelineTab(context, provider, isDark),

                  // Tab 2: Map
                  TrailMapView(
                    points: provider.points,
                    selectedPoint: provider.selectedPoint,
                    onPointSelected: (pt) => provider.selectPoint(pt),
                    onOpenMaps: (pt) => provider.openInGoogleMaps(pt.latitude, pt.longitude),
                    onShare: (pt) => provider.sharePoint(pt),
                  ),

                  // Tab 3: Visits
                  _buildVisitsTab(context, provider, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AutoTrailProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          ),
        ),
      ),
      child: Row(
        children: [
          // App Title + Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.navigation,
                  size: 20,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Auto Trail',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: provider.isServiceRunning
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        provider.isServiceRunning
                            ? 'Tracking (${provider.currentActivity})'
                            : 'Tracking Paused',
                        style: TextStyle(
                          fontSize: 11,
                          color: provider.isServiceRunning
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Manual "Log Now" button
          IconButton(
            icon: const Icon(LucideIcons.locateFixed, size: 20),
            tooltip: 'Log current location now',
            onPressed: () async {
              final pt = await provider.recordCurrentLocation();
              if (context.mounted && pt != null) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text('Logged: ${pt.address}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),

          // Power & Data Diagnostics Button
          IconButton(
            icon: const Icon(LucideIcons.gauge, size: 20, color: Color(0xFF10B981)),
            tooltip: 'Power & Data Diagnostics',
            onPressed: () => ResourceTelemetryModal.show(context, feature: 'auto_trail'),
          ),

          // Export Button
          IconButton(
            icon: const Icon(LucideIcons.download, size: 20),
            tooltip: 'Export GPX / GeoJSON',
            onPressed: () => _showExportSheet(context, provider),
          ),

          // Service On/Off Switch
          ShadSwitch(
            value: provider.isServiceRunning,
            onChanged: (val) => provider.toggleService(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateAndSearchBar(
    BuildContext context,
    AutoTrailProvider provider,
    bool isDark,
  ) {
    final isToday = DateTime.now().year == provider.selectedDate.year &&
        DateTime.now().month == provider.selectedDate.month &&
        DateTime.now().day == provider.selectedDate.day;

    final formattedDate = isToday
        ? 'Today, ${DateFormat('MMM d').format(provider.selectedDate)}'
        : DateFormat('EEE, MMM d, yyyy').format(provider.selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF121214) : const Color(0xFFF9FAFB),
      child: Column(
        children: [
          Row(
            children: [
              // Previous Day
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 18),
                onPressed: () {
                  provider.setSelectedDate(
                    provider.selectedDate.subtract(const Duration(days: 1)),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),

              // Date display & picker button
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, provider),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.calendar, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),
              // Next Day
              IconButton(
                icon: const Icon(LucideIcons.chevronRight, size: 18),
                onPressed: isToday
                    ? null
                    : () {
                        provider.setSelectedDate(
                          provider.selectedDate.add(const Duration(days: 1)),
                        );
                      },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              const SizedBox(width: 12),
              // Search toggle
              IconButton(
                icon: Icon(
                  _isSearching ? LucideIcons.x : LucideIcons.search,
                  size: 18,
                ),
                tooltip: 'Search timeline',
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      provider.setSearchQuery('');
                    }
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Search Field (if expanded)
          if (_isSearching) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search places, streets, dates...',
                prefixIcon: const Icon(LucideIcons.search, size: 16),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                  ),
                ),
              ),
              onChanged: (text) => provider.setSearchQuery(text),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineTab(BuildContext context, AutoTrailProvider provider, bool isDark) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final distanceKm = (provider.dayDistanceMeters / 1000).toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Permission Banner
        TrailPermissionBanner(
          status: provider.permissionStatus,
          onRequestPermission: () => provider.requestPermissions(),
          onOpenSettings: () => AutoTrailPermissionService.openSettings(),
        ),

        // Day Summary Mini Bar
        if (provider.points.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Points', '${provider.points.length}', LucideIcons.mapPin),
                _buildStatItem('Est. Route', '$distanceKm km', LucideIcons.route),
                _buildStatItem('Stops', '${provider.visits.length}', LucideIcons.clock),
              ],
            ),
          ),

        // Empty state
        if (provider.points.isEmpty)
          _buildEmptyState(
            context,
            isDark,
            provider,
            'No locations logged for this day',
            'Auto Trail silently tracks your movement in the background. Keep the service active and carry your phone as normal.',
          )
        else
          // List of timeline points
          ...provider.points.asMap().entries.map((entry) {
            final index = entry.key;
            final pt = entry.value;
            final isFirst = index == 0;
            final isLast = index == provider.points.length - 1;

            return TrailTimelineCard(
              point: pt,
              isFirst: isFirst,
              isLast: isLast,
              isSelected: provider.selectedPoint?.id == pt.id,
              onOpenMaps: () => provider.openInGoogleMaps(pt.latitude, pt.longitude),
              onShare: () => provider.sharePoint(pt),
              onFocusMap: () {
                provider.selectPoint(pt);
                _tabController.animateTo(1); // Jump to map tab
              },
              onDelete: () => provider.deletePoint(pt.id!),
            );
          }),

        const SizedBox(height: 24),
        if (provider.points.isNotEmpty)
          Center(
            child: TextButton.icon(
              icon: const Icon(LucideIcons.trash2, size: 14, color: Color(0xFFEF4444)),
              label: const Text(
                'Clear All History',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              ),
              onPressed: () => _showClearConfirmDialog(context, provider),
            ),
          ),
      ],
    );
  }

  Widget _buildVisitsTab(BuildContext context, AutoTrailProvider provider, bool isDark) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.visits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.clock,
                size: 40,
                color: isDark ? const Color(0xFF52525B) : const Color(0xFFA1A1AA),
              ),
              const SizedBox(height: 12),
              const Text(
                'No visits detected yet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'When you stay stationary in an area for at least 3 minutes (e.g. at home, coffee shop, office), Auto Trail clusters them into identified visits with dwell duration.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${provider.visits.length} Identified Stops & Stays',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        ...provider.visits.map((visit) {
          return TrailVisitCard(
            visit: visit,
            onOpenMaps: () => provider.openInGoogleMaps(
              visit.centerLatitude,
              visit.centerLongitude,
            ),
            onShare: () {
              if (visit.points.isNotEmpty) {
                provider.sharePoint(visit.points.first);
              }
            },
            onFocusMap: () {
              if (visit.points.isNotEmpty) {
                provider.selectPoint(visit.points.first);
                _tabController.animateTo(1);
              }
            },
          );
        }),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF71717A)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    AutoTrailProvider provider,
    String title,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
            ),
            child: Icon(
              LucideIcons.mapPinOff,
              size: 36,
              color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 20),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: () => provider.recordCurrentLocation(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.locateFixed, size: 14),
                SizedBox(width: 6),
                Text('Log Current Location Now'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
