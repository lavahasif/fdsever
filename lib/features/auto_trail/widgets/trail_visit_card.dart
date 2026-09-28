import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/visit_cluster.dart';

class TrailVisitCard extends StatelessWidget {
  final VisitCluster visit;
  final VoidCallback onOpenMaps;
  final VoidCallback onShare;
  final VoidCallback onFocusMap;

  const TrailVisitCard({
    super.key,
    required this.visit,
    required this.onOpenMaps,
    required this.onShare,
    required this.onFocusMap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');
    final startStr = timeFormat.format(visit.startTime);
    final endStr = timeFormat.format(visit.endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.clock,
                    size: 18,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            visit.durationString,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF27272A)
                                  : const Color(0xFFF4F4F5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${visit.pointsCount} pings',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? const Color(0xFFA1A1AA)
                                    : const Color(0xFF71717A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$startStr — $endStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFA1A1AA)
                              : const Color(0xFF71717A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              visit.locationName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF09090B),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ShadButton(
                    size: ShadButtonSize.sm,
                    onPressed: onOpenMaps,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.externalLink, size: 14),
                        SizedBox(width: 6),
                        Text('Google Maps'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: onFocusMap,
                  child: const Icon(LucideIcons.map, size: 15),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: onShare,
                  child: const Icon(LucideIcons.share2, size: 15),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
