import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/web_server/providers/web_server_provider.dart';
import 'status_badge.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<WebServerProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.server, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'v${AppConstants.appVersion} • Web & Network Suite',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Actions & Status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusBadge(
                isActive: serverProvider.isRunning,
                activeLabel: 'Server :${serverProvider.port}',
                inactiveLabel: 'Server Inactive',
              ),
              if (serverProvider.isRunning) ...[
                const SizedBox(width: 8),
                ShadButton.outline(
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.copy, size: 14),
                      SizedBox(width: 4),
                      Text('Copy URL'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => launchUrl(
                    Uri.parse(serverProvider.serverUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Icon(LucideIcons.externalLink, size: 16),
                ),
              ],
              const SizedBox(width: 12),
              // Theme Toggle
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: () {
                  final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                  settingsProvider.setThemeMode(newMode);
                },
                child: Icon(
                  isDark ? LucideIcons.sun : LucideIcons.moon,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
