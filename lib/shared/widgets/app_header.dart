import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/crash_log_service.dart';
import '../../features/diagnostics/screens/crash_logs_screen.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/web_server/providers/web_server_provider.dart';
import 'status_badge.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  final VoidCallback? onSettingsPressed;

  const AppHeader({
    super.key,
    this.onMenuPressed,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<WebServerProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final isTiny = constraints.maxWidth < 400;

          return Row(
            children: [
              if (onMenuPressed != null) ...[
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: onMenuPressed,
                  child: const Icon(LucideIcons.menu, size: 18),
                ),
                const SizedBox(width: 4),
              ],

              // App Branding
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.server, size: 16),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConstants.appName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (!isTiny)
                    Text(
                      'v${AppConstants.appVersion}',
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                    ),
                ],
              ),

              const Spacer(),

              // Status Badge
              if (!isTiny) ...[
                StatusBadge(
                  isActive: serverProvider.isRunning,
                  activeLabel: ':${serverProvider.port}',
                  inactiveLabel: 'Offline',
                ),
                const SizedBox(width: 4),
              ],

              if (!isCompact && serverProvider.isRunning) ...[
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: serverProvider.serverUrl));
                    ShadToaster.of(context).show(
                      const ShadToast(
                        title: Text('URL Copied'),
                        description: Text('Server URL copied to clipboard'),
                      ),
                    );
                  },
                  child: const Icon(LucideIcons.copy, size: 16),
                ),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => launchUrl(
                    Uri.parse(serverProvider.serverUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Icon(LucideIcons.externalLink, size: 16),
                ),
                const SizedBox(width: 2),
              ],

              // Theme Toggle
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: () {
                  final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                  settingsProvider.setThemeMode(newMode);
                },
                child: Icon(
                  isDark ? LucideIcons.sun : LucideIcons.moon,
                  size: 16,
                ),
              ),

              // Crash Logs & AI Diagnostics Button
              ListenableBuilder(
                listenable: CrashLogService(),
                builder: (context, _) {
                  final crashService = CrashLogService();
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CrashLogsScreen()),
                          );
                        },
                        child: Icon(
                          LucideIcons.fileWarning,
                          size: 16,
                          color: crashService.hasCrashes ? const Color(0xFFEF4444) : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                      if (crashService.hasCrashes)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                          ),
                        ),
                    ],
                  );
                },
              ),

              if (onSettingsPressed != null) ...[
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: onSettingsPressed,
                  child: const Icon(LucideIcons.settings, size: 16),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
