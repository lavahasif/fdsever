import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/constants/app_constants.dart';
import '../../features/notes/providers/notes_provider.dart';
import '../../features/proxy_server/providers/proxy_provider.dart';
import '../../features/realtime/providers/realtime_provider.dart';
import '../../features/web_server/providers/web_server_provider.dart';

class SidebarDestination {
  final String title;
  final IconData icon;
  final int pillarIndex;
  final int? subIndex;

  const SidebarDestination({
    required this.title,
    required this.icon,
    required this.pillarIndex,
    this.subIndex,
  });
}

class SidebarGroup {
  final String header;
  final List<SidebarDestination> destinations;

  const SidebarGroup({
    required this.header,
    required this.destinations,
  });
}

class ResponsiveSidebar extends StatelessWidget {
  final int selectedPillarIndex;
  final int selectedSubIndex;
  final void Function(int pillarIndex, [int? subIndex]) onDestinationSelected;
  final double? width;

  const ResponsiveSidebar({
    super.key,
    required this.selectedPillarIndex,
    this.selectedSubIndex = 0,
    required this.onDestinationSelected,
    this.width = 250,
  });

  static const List<SidebarGroup> groups = [
    SidebarGroup(
      header: 'OVERVIEW',
      destinations: [
        SidebarDestination(
          title: 'Dashboard',
          icon: LucideIcons.layoutDashboard,
          pillarIndex: 0,
        ),
      ],
    ),
    SidebarGroup(
      header: 'SERVER & NETWORK',
      destinations: [
        SidebarDestination(
          title: 'Web Server',
          icon: LucideIcons.globe,
          pillarIndex: 1,
          subIndex: 0,
        ),
        SidebarDestination(
          title: 'Port Scanner',
          icon: LucideIcons.radar,
          pillarIndex: 1,
          subIndex: 1,
        ),
        SidebarDestination(
          title: 'WebSocket Hub',
          icon: LucideIcons.radio,
          pillarIndex: 1,
          subIndex: 2,
        ),
        SidebarDestination(
          title: 'Proxy Server',
          icon: LucideIcons.shieldCheck,
          pillarIndex: 1,
          subIndex: 3,
        ),
      ],
    ),
    SidebarGroup(
      header: 'SHARING & TOOLS',
      destinations: [
        SidebarDestination(
          title: 'File Transfer',
          icon: LucideIcons.uploadCloud,
          pillarIndex: 2,
          subIndex: 0,
        ),
        SidebarDestination(
          title: 'APK Manager',
          icon: LucideIcons.package,
          pillarIndex: 2,
          subIndex: 1,
        ),
        SidebarDestination(
          title: 'WhatsApp Direct',
          icon: LucideIcons.messageSquare,
          pillarIndex: 2,
          subIndex: 2,
        ),
      ],
    ),
    SidebarGroup(
      header: 'WORKSPACE',
      destinations: [
        SidebarDestination(
          title: 'Notes & KB',
          icon: LucideIcons.notebookPen,
          pillarIndex: 3,
          subIndex: 0,
        ),
        SidebarDestination(
          title: 'Tutorials & Docs',
          icon: LucideIcons.bookOpen,
          pillarIndex: 3,
          subIndex: 1,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final webServer = context.watch<WebServerProvider>();
    final realtime = context.watch<RealtimeProvider>();
    final proxy = context.watch<ProxyServerProvider>();
    final notes = context.watch<NotesProvider>();

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 12, bottom: 6),
                      child: Text(
                        group.header,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                        ),
                      ),
                    ),
                    for (final dest in group.destinations)
                      _buildNavItem(
                        context: context,
                        destination: dest,
                        isSelected: dest.pillarIndex == selectedPillarIndex &&
                            (dest.subIndex == null || dest.subIndex == selectedSubIndex),
                        isDark: isDark,
                        activeDot: (dest.pillarIndex == 1 && dest.subIndex == 0 && webServer.isRunning) ||
                            (dest.pillarIndex == 1 && dest.subIndex == 2 && (realtime.isServerRunning || realtime.isClientConnected)) ||
                            (dest.pillarIndex == 1 && dest.subIndex == 3 && proxy.isRunning),
                        badgeText: (dest.pillarIndex == 1 && dest.subIndex == 3 && proxy.isRunning)
                            ? ':${proxy.port}'
                            : ((dest.pillarIndex == 3 && dest.subIndex == 0 && notes.notes.isNotEmpty)
                                ? '${notes.notes.length}'
                                : null),
                      ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom System Section (Settings + About)
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildNavItem(
              context: context,
              destination: const SidebarDestination(
                title: 'Settings',
                icon: LucideIcons.settings,
                pillarIndex: 4,
              ),
              isSelected: selectedPillarIndex == 4,
              isDark: isDark,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}\nShadcn UI • Flutter 3.44',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required SidebarDestination destination,
    required bool isSelected,
    required bool isDark,
    bool activeDot = false,
    String? badgeText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: isSelected
            ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onDestinationSelected(destination.pillarIndex, destination.subIndex),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  size: 17,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    destination.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                    ),
                  ),
                ),
                if (activeDot)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
