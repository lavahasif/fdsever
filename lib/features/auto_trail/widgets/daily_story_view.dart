import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/saved_place.dart';
import '../models/story_item.dart';
import '../models/visit_cluster.dart';
import '../providers/auto_trail_provider.dart';

class DailyStoryView extends StatelessWidget {
  final List<StoryTimelineItem> storyItems;
  final AutoTrailProvider provider;
  final bool isDark;

  const DailyStoryView({
    super.key,
    required this.storyItems,
    required this.provider,
    required this.isDark,
  });

  void _showNamePlaceDialog(BuildContext context, VisitCluster visit) {
    final controller = TextEditingController(text: visit.locationName.split(',').first.trim());
    String selectedIcon = 'pin';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final icons = [
            {'key': 'home', 'label': 'Home', 'icon': LucideIcons.house},
            {'key': 'office', 'label': 'Work', 'icon': LucideIcons.briefcase},
            {'key': 'gym', 'label': 'Gym', 'icon': LucideIcons.dumbbell},
            {'key': 'cafe', 'label': 'Cafe', 'icon': LucideIcons.coffee},
            {'key': 'library', 'label': 'Study', 'icon': LucideIcons.bookOpen},
            {'key': 'pin', 'label': 'Spot', 'icon': LucideIcons.mapPin},
          ];

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
            title: const Row(
              children: [
                Icon(LucideIcons.tag, color: Color(0xFF3B82F6), size: 20),
                SizedBox(width: 8),
                Text('Name This Place', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto Trail will automatically recognize and label this place in all future visits.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Place Name (e.g. My Home, Tech Hub)',
                    hintText: 'Enter place name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose Icon',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.map((item) {
                    final key = item['key'] as String;
                    final icon = item['icon'] as IconData;
                    final isSelected = selectedIcon == key;

                    return InkWell(
                      onTap: () => setDialogState(() => selectedIcon = key),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                              : (isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: isSelected ? const Color(0xFF3B82F6) : null),
                            const SizedBox(width: 6),
                            Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFF3B82F6) : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ShadButton(
                size: ShadButtonSize.sm,
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    final newPlace = SavedPlace(
                      id: 'place_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      latitude: visit.centerLatitude,
                      longitude: visit.centerLongitude,
                      radiusMeters: 100.0,
                      icon: selectedIcon,
                      createdAt: DateTime.now(),
                    );
                    provider.saveNamedPlace(newPlace);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save Place'),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getIconForPlace(String? iconKey) {
    switch (iconKey) {
      case 'home':
        return LucideIcons.house;
      case 'office':
        return LucideIcons.briefcase;
      case 'gym':
        return LucideIcons.dumbbell;
      case 'cafe':
        return LucideIcons.coffee;
      case 'library':
        return LucideIcons.bookOpen;
      default:
        return LucideIcons.mapPin;
    }
  }

  Color _getColorForPlace(String? iconKey) {
    switch (iconKey) {
      case 'home':
        return const Color(0xFF10B981); // Emerald
      case 'office':
        return const Color(0xFF3B82F6); // Blue
      case 'gym':
        return const Color(0xFFEF4444); // Red
      case 'cafe':
        return const Color(0xFFF59E0B); // Amber
      case 'library':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  IconData _getTransitIcon(String activity) {
    switch (activity) {
      case 'in_vehicle':
        return LucideIcons.car;
      case 'on_bicycle':
        return LucideIcons.bike;
      case 'running':
        return LucideIcons.activity;
      case 'walking':
      default:
        return LucideIcons.footprints;
    }
  }

  String _getTransitLabel(String activity) {
    switch (activity) {
      case 'in_vehicle':
        return 'Drive / Vehicle Transit';
      case 'on_bicycle':
        return 'Cycling';
      case 'running':
        return 'Running';
      case 'walking':
      default:
        return 'Walking & Movement';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (storyItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.compass, size: 48, color: isDark ? const Color(0xFF52525B) : const Color(0xFFA1A1AA)),
              const SizedBox(height: 16),
              const Text(
                'No Trail Story For This Day',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep Auto Trail running passively in the background. It will automatically build your day story as you visit places and travel.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFFA1A1AA)),
              ),
            ],
          ),
        ),
      );
    }

    final timeFmt = DateFormat('hh:mm a');

    // Aggregate summary metrics
    int totalVisits = 0;
    double totalDistanceM = 0;
    int totalStationaryMins = 0;

    for (final item in storyItems) {
      if (item.type == StoryItemType.visit) {
        totalVisits++;
        totalStationaryMins += item.duration.inMinutes;
      } else {
        totalDistanceM += item.distanceMeters;
      }
    }

    final statHours = totalStationaryMins ~/ 60;
    final statMins = totalStationaryMins % 60;
    final statDurationStr = statHours > 0 ? '${statHours}h ${statMins}m' : '${statMins}m';
    final distKmStr = (totalDistanceM / 1000).toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Daily Story Summary Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B4B), const Color(0xFF18181B)]
                  : [const Color(0xFFEEF2FF), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF312E81) : const Color(0xFFC7D2FE),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.sparkles, color: Color(0xFF6366F1), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'LIFELOG DAY STORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCol('Places Visited', '$totalVisits', LucideIcons.building2, const Color(0xFF3B82F6)),
                  _buildStatCol('Distance', '$distKmStr km', LucideIcons.route, const Color(0xFF10B981)),
                  _buildStatCol('Dwell Time', statDurationStr, LucideIcons.clock, const Color(0xFFF59E0B)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Timeline Story Sequence
        ...storyItems.map((item) {
          if (item.type == StoryItemType.visit) {
            final color = _getColorForPlace(item.placeIcon);
            final icon = _getIconForPlace(item.placeIcon);
            final isSaved = item.placeIcon != 'pin';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSaved
                        ? color.withValues(alpha: 0.4)
                        : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                    width: isSaved ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Place Icon Badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Icon(icon, color: color, size: 22),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.placeName ?? 'Stationary Visit',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.durationString,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${timeFmt.format(item.startTime)} – ${timeFmt.format(item.endTime)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA1A1AA),
                            ),
                          ),
                          if (item.visit != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (!isSaved)
                                  InkWell(
                                    onTap: () => _showNamePlaceDialog(context, item.visit!),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.tag, size: 12, color: Color(0xFF3B82F6)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Name Place',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(LucideIcons.mapPin, size: 16, color: Color(0xFF3B82F6)),
                                  tooltip: 'Open in Maps',
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => provider.openInGoogleMaps(
                                    item.visit!.centerLatitude,
                                    item.visit!.centerLongitude,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Transit / Movement segment
            final actIcon = _getTransitIcon(item.primaryActivity);
            final actLabel = _getTransitLabel(item.primaryActivity);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 2,
                    height: 38,
                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 20),
                  Icon(actIcon, size: 14, color: const Color(0xFFA1A1AA)),
                  const SizedBox(width: 8),
                  Text(
                    '$actLabel • ${item.distanceString} (${item.durationString})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
            );
          }
        }),
      ],
    );
  }

  Widget _buildStatCol(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFFA1A1AA)),
        ),
      ],
    );
  }
}
