import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../network_scanner/providers/scanner_provider.dart';
import '../../notes/providers/notes_provider.dart';
import '../../proxy_server/providers/proxy_provider.dart';
import '../../tutorials/providers/tutorials_provider.dart';
import '../../web_server/providers/web_server_provider.dart';

typedef NavigationCallback = void Function(int pillarIndex, [int? subIndex]);

class DashboardScreen extends StatelessWidget {
  final NavigationCallback onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<WebServerProvider>();
    final scannerProvider = context.watch<ScannerProvider>();
    final proxyProvider = context.watch<ProxyServerProvider>();
    final notesProvider = context.watch<NotesProvider>();
    final tutsProvider = context.watch<TutorialsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Status Banner
          _buildHeroBanner(context, serverProvider, scannerProvider, isDark),

          const SizedBox(height: 28),

          // Primary Quick Launch Workspaces
          const Text(
            'Quick Access Tools',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          Text(
            'Jump directly into core server, networking, proxy gateway, and file sharing utilities.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1100 ? 5 : (constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 450 ? 2 : 1));
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth > 550 ? 1.35 : 2.0,
                children: [
                  _buildPillarCard(
                    context,
                    title: 'Web Server',
                    badge: serverProvider.isRunning ? 'Running' : 'Offline',
                    badgeColor: serverProvider.isRunning ? const Color(0xFF10B981) : Colors.grey,
                    description: 'Shelf HTTP server, REST endpoints, live request logs & API explorer.',
                    icon: LucideIcons.globe,
                    accentColor: const Color(0xFF3B82F6),
                    onTap: () => onNavigate(1, 0),
                  ),
                  _buildPillarCard(
                    context,
                    title: 'Super Proxy',
                    badge: proxyProvider.isRunning ? ':${proxyProvider.port}' : 'Offline',
                    badgeColor: proxyProvider.isRunning ? const Color(0xFF10B981) : Colors.grey,
                    description: 'HTTP, HTTPS CONNECT & SOCKS5 gateway with ad-block shield.',
                    icon: LucideIcons.shieldCheck,
                    accentColor: const Color(0xFF10B981),
                    onTap: () => onNavigate(1, 3),
                  ),
                  _buildPillarCard(
                    context,
                    title: 'Port Scanner',
                    badge: '${scannerProvider.interfaces.length} Net IF',
                    badgeColor: const Color(0xFF8B5CF6),
                    description: 'Subnet device discovery, TCP port probing, and local network diagnostics.',
                    icon: LucideIcons.radar,
                    accentColor: const Color(0xFF8B5CF6),
                    onTap: () => onNavigate(1, 1),
                  ),
                  _buildPillarCard(
                    context,
                    title: 'File Sharing (LAN)',
                    badge: 'No Cloud',
                    badgeColor: const Color(0xFFF59E0B),
                    description: 'Send and receive files directly across devices on the local Wi-Fi.',
                    icon: LucideIcons.uploadCloud,
                    accentColor: const Color(0xFFF59E0B),
                    onTap: () => onNavigate(2, 0),
                  ),
                  _buildPillarCard(
                    context,
                    title: 'APK Manager',
                    badge: 'Installer',
                    badgeColor: const Color(0xFFEC4899),
                    description: 'Distribute, install, and manage Android APK packages wirelessly.',
                    icon: LucideIcons.package,
                    accentColor: const Color(0xFFEC4899),
                    onTap: () => onNavigate(2, 1),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // Secondary Utilities Row
          const Text(
            'More Utilities & Tools',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.2),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildCompactToolButton(
                icon: LucideIcons.shieldCheck,
                label: 'Proxy Gateway (${proxyProvider.isRunning ? 'Active' : 'Offline'})',
                onPressed: () => onNavigate(1, 3),
              ),
              _buildCompactToolButton(
                icon: LucideIcons.radio,
                label: 'WebSocket Hub',
                onPressed: () => onNavigate(1, 2),
              ),
              _buildCompactToolButton(
                icon: LucideIcons.messageSquare,
                label: 'WhatsApp Direct',
                onPressed: () => onNavigate(2, 2),
              ),
              _buildCompactToolButton(
                icon: LucideIcons.notebookPen,
                label: 'Notes & KB (${notesProvider.notes.length})',
                onPressed: () => onNavigate(3, 0),
              ),
              _buildCompactToolButton(
                icon: LucideIcons.bookOpen,
                label: 'Tutorials (${tutsProvider.tutorials.length})',
                onPressed: () => onNavigate(3, 1),
              ),
              _buildCompactToolButton(
                icon: LucideIcons.settings,
                label: 'Settings',
                onPressed: () => onNavigate(4),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Server Live Activity Log Preview
          if (serverProvider.logs.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Server Activity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => onNavigate(1, 0),
                  child: const Text('View Full Logs →'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ShadCard(
              padding: const EdgeInsets.all(12),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: serverProvider.logs.take(5).length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = serverProvider.logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        ShadBadge(
                          backgroundColor: log.statusCode < 400
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          child: Text('${log.statusCode}', style: const TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 12),
                        Text(log.method, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log.path,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          log.clientIp,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroBanner(
    BuildContext context,
    WebServerProvider serverProvider,
    ScannerProvider scannerProvider,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: serverProvider.isRunning
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  serverProvider.isRunning ? LucideIcons.server : LucideIcons.serverOff,
                  color: serverProvider.isRunning ? const Color(0xFF10B981) : Colors.grey,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'FDServer Network & Server Center',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: serverProvider.isRunning
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: serverProvider.isRunning
                                      ? const Color(0xFF10B981)
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                serverProvider.isRunning ? 'Active' : 'Stopped',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: serverProvider.isRunning
                                      ? const Color(0xFF10B981)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serverProvider.isRunning
                          ? 'Listening on ${serverProvider.serverUrl}'
                          : 'Server is currently offline. Primary IP: ${scannerProvider.primaryIp}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ShadButton(
                onPressed: () => serverProvider.toggleServer(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(serverProvider.isRunning ? LucideIcons.square : LucideIcons.play, size: 15),
                    const SizedBox(width: 8),
                    Text(serverProvider.isRunning ? 'Stop Server' : 'Start Server Now'),
                  ],
                ),
              ),
              ShadButton.outline(
                onPressed: () => onNavigate(1, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(LucideIcons.slidersHorizontal, size: 15),
                    SizedBox(width: 8),
                    Text('Configure Server'),
                  ],
                ),
              ),
              if (serverProvider.isRunning)
                ShadButton.ghost(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: serverProvider.serverUrl));
                    ShadToaster.of(context).show(
                      const ShadToast(
                        title: Text('URL Copied'),
                        description: Text('Server URL copied to clipboard'),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.copy, size: 15),
                      SizedBox(width: 6),
                      Text('Copy URL'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillarCard(
    BuildContext context, {
    required String title,
    required String badge,
    required Color badgeColor,
    required String description,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Open →',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ShadButton.outline(
      size: ShadButtonSize.sm,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
