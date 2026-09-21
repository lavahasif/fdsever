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
  final VoidCallback? onMenuPressed;

  const AppHeader({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<WebServerProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          if (onMenuPressed != null) ...[
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: onMenuPressed,
              child: const Icon(LucideIcons.menu, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          // Logo + Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.server, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConstants.appName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    'v${AppConstants.appVersion}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Status + Actions (scrollable on very small screens)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBadge(
                  isActive: serverProvider.isRunning,
                  activeLabel: ':${serverProvider.port}',
                  inactiveLabel: 'Offline',
                ),
                if (serverProvider.isRunning) ...[
                  const SizedBox(width: 6),
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
                        Icon(LucideIcons.copy, size: 13),
                        SizedBox(width: 4),
                        Text('Copy URL', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => launchUrl(
                      Uri.parse(serverProvider.serverUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Icon(LucideIcons.externalLink, size: 15),
                  ),
                ],
                const SizedBox(width: 6),
                // Theme Toggle
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                    settingsProvider.setThemeMode(newMode);
                  },
                  child: Icon(
                    isDark ? LucideIcons.sun : LucideIcons.moon,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
