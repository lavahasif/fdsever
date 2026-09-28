import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../services/auto_trail_permission_service.dart';

class TrailPermissionBanner extends StatelessWidget {
  final AutoTrailPermissionStatus status;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;

  const TrailPermissionBanner({
    super.key,
    required this.status,
    required this.onRequestPermission,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    if (status == AutoTrailPermissionStatus.allGranted) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isForegroundOnly = status == AutoTrailPermissionStatus.foregroundOnly;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isForegroundOnly
            ? (isDark ? const Color(0xFF2E2412) : const Color(0xFFFEF3C7))
            : (isDark ? const Color(0xFF2C1318) : const Color(0xFFFEE2E2)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isForegroundOnly
              ? (isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B))
              : (isDark ? const Color(0xFFDC2626) : const Color(0xFFEF4444)),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isForegroundOnly ? LucideIcons.shieldAlert : LucideIcons.alertTriangle,
                size: 20,
                color: isForegroundOnly
                    ? const Color(0xFFD97706)
                    : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isForegroundOnly
                      ? 'Background Location Required'
                      : 'Location Permissions Required',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isForegroundOnly
                        ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                        : (isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isForegroundOnly
                ? 'To automatically log places when your phone screen is off or when the app is closed, Android requires selecting "Allow all the time" in location settings.'
                : 'Auto Trail silently tracks your visited places in the background with zero manual input. Please grant location and motion activity permissions.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ShadButton(
                size: ShadButtonSize.sm,
                onPressed: onRequestPermission,
                child: Text(
                  isForegroundOnly ? 'Grant "Allow all the time"' : 'Grant Permissions',
                ),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: onOpenSettings,
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
