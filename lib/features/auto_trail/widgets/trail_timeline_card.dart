import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/trail_point.dart';

class TrailTimelineCard extends StatefulWidget {
  final TrailPoint point;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onOpenMaps;
  final VoidCallback onShare;
  final VoidCallback onFocusMap;
  final VoidCallback onDelete;

  const TrailTimelineCard({
    super.key,
    required this.point,
    this.isSelected = false,
    this.isFirst = false,
    this.isLast = false,
    required this.onOpenMaps,
    required this.onShare,
    required this.onFocusMap,
    required this.onDelete,
  });

  @override
  State<TrailTimelineCard> createState() => _TrailTimelineCardState();
}

class _TrailTimelineCardState extends State<TrailTimelineCard> {
  bool _isExpanded = false;

  IconData _getActivityIcon(String? activity) {
    switch (activity?.toLowerCase()) {
      case 'walking':
      case 'on_foot':
        return LucideIcons.footprints;
      case 'in_vehicle':
        return LucideIcons.car;
      case 'on_bicycle':
        return LucideIcons.bike;
      case 'running':
        return LucideIcons.activity;
      case 'still':
        return LucideIcons.pauseCircle;
      case 'manual':
        return LucideIcons.mapPin;
      default:
        return LucideIcons.navigation;
    }
  }

  Color _getActivityColor(String? activity, bool isDark) {
    switch (activity?.toLowerCase()) {
      case 'walking':
      case 'on_foot':
        return const Color(0xFF10B981);
      case 'in_vehicle':
        return const Color(0xFF3B82F6);
      case 'on_bicycle':
        return const Color(0xFFF59E0B);
      case 'running':
        return const Color(0xFFEC4899);
      case 'still':
        return const Color(0xFF6B7280);
      default:
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('h:mm a').format(widget.point.dateTime);
    final activityColor = _getActivityColor(widget.point.activity, isDark);
    final isSelected = widget.isSelected;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical Timeline Line & Indicator
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    width: 2,
                    color: widget.isFirst
                        ? Colors.transparent
                        : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : (isDark ? const Color(0xFF18181B) : Colors.white),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : activityColor,
                      width: 3,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    width: 2,
                    color: widget.isLast
                        ? Colors.transparent
                        : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                  ),
                ),
              ],
            ),
          ),

          // Main Card Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                    : (isDark ? const Color(0xFF18181B) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Time + Activity Badge + Coordinates
                        Row(
                          children: [
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (widget.point.activity != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: activityColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getActivityIcon(widget.point.activity),
                                      size: 11,
                                      color: activityColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.point.activity!.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: activityColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Spacer(),
                            Text(
                              widget.point.coordsString,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF71717A)
                                    : const Color(0xFFA1A1AA),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Location Address
                        Text(
                          widget.point.address,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF09090B),
                          ),
                        ),

                        // Expandable Action Buttons
                        if (_isExpanded) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ShadButton(
                                size: ShadButtonSize.sm,
                                onPressed: widget.onOpenMaps,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.externalLink, size: 14),
                                    SizedBox(width: 6),
                                    Text('Open in Google Maps'),
                                  ],
                                ),
                              ),
                              ShadButton.outline(
                                size: ShadButtonSize.sm,
                                onPressed: widget.onShare,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.share2, size: 14),
                                    SizedBox(width: 6),
                                    Text('Share'),
                                  ],
                                ),
                              ),
                              ShadButton.secondary(
                                size: ShadButtonSize.sm,
                                onPressed: widget.onFocusMap,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.map, size: 14),
                                    SizedBox(width: 6),
                                    Text('View on Map'),
                                  ],
                                ),
                              ),
                              ShadButton.destructive(
                                size: ShadButtonSize.sm,
                                onPressed: widget.onDelete,
                                child: const Icon(LucideIcons.trash2, size: 14),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
