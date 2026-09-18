import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _timeoutController;
  late final TextEditingController _timeout2Controller;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SettingsProvider>();
    _ipController = TextEditingController(text: provider.favIp);
    _portController = TextEditingController(text: provider.favPort);
    _timeoutController = TextEditingController(text: provider.timeoutMs.toString());
    _timeout2Controller = TextEditingController(text: provider.timeout2Ms.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _timeoutController.dispose();
    _timeout2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text('Application Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(
            'Configure default networking parameters, socket timeout limits, and visual themes.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),

          const SizedBox(height: 20),

          // Network Defaults Card
          ShadCard(
            title: const Text('Default Network Parameters'),
            description: const Text('Preset target IP and port configurations applied across the app.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Favorite / Preset IP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            ShadInput(
                              controller: _ipController,
                              placeholder: const Text('192.168.1.10'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Default Port', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            ShadInput(
                              controller: _portController,
                              placeholder: const Text('8069'),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Probe Timeout (ms)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            ShadInput(
                              controller: _timeoutController,
                              placeholder: const Text('5000'),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Secondary Timeout (ms)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            ShadInput(
                              controller: _timeout2Controller,
                              placeholder: const Text('5000'),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ShadButton(
                      onPressed: () {
                        settingsProvider.saveSettings(
                          favPort: _portController.text,
                          favIp: _ipController.text,
                          timeoutMs: _timeoutController.text,
                          timeout2Ms: _timeout2Controller.text,
                        );
                        ShadToaster.of(context).show(
                          const ShadToast(
                            title: Text('Settings Saved'),
                            description: Text('Network configuration updated successfully'),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.save, size: 16),
                          SizedBox(width: 8),
                          Text('Save Preferences'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Theme Settings Card
          ShadCard(
            title: const Text('Visual Appearance'),
            description: const Text('Select your desired color theme preference.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  _buildThemeOption(
                    title: 'System Default',
                    mode: ThemeMode.system,
                    currentMode: settingsProvider.themeMode,
                    icon: LucideIcons.laptop,
                    onTap: () => settingsProvider.setThemeMode(ThemeMode.system),
                  ),
                  const SizedBox(width: 12),
                  _buildThemeOption(
                    title: 'Light Theme',
                    mode: ThemeMode.light,
                    currentMode: settingsProvider.themeMode,
                    icon: LucideIcons.sun,
                    onTap: () => settingsProvider.setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(width: 12),
                  _buildThemeOption(
                    title: 'Dark Theme',
                    mode: ThemeMode.dark,
                    currentMode: settingsProvider.themeMode,
                    icon: LucideIcons.moon,
                    onTap: () => settingsProvider.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // About Card
          ShadCard(
            title: const Text('About FDServer'),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FDServer Suite 5.0.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    'Modernized with Flutter 3.44 and Shadcn UI. Multiplatform local web server, TCP port scanner, direct WhatsApp messenger, and socket hub.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ShadBadge.outline(child: const Text('Flutter 3.44')),
                      ShadBadge.outline(child: const Text('Dart 3.12')),
                      ShadBadge.outline(child: const Text('Shadcn UI 0.57')),
                      ShadBadge.outline(child: const Text('Shelf HTTP 1.4')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == currentMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade800,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.blue.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
