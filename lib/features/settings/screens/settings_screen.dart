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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      );

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Application Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(
            'Configure network defaults, timeouts, and visual theme.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),

          const SizedBox(height: 20),

          // Network defaults
          ShadCard(
            title: const Text('Default Network Parameters'),
            description: const Text('Pre-filled IP and port values used across modules.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 400;
                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Favorite IP'), ShadInput(controller: _ipController, placeholder: const Text('192.168.1.10'))])),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Default Port'), ShadInput(controller: _portController, placeholder: const Text('8069'), keyboardType: TextInputType.number)])),
                        ],
                      );
                    }
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('Favorite IP'),
                      ShadInput(controller: _ipController, placeholder: const Text('192.168.1.10')),
                      const SizedBox(height: 10),
                      _label('Default Port'),
                      ShadInput(controller: _portController, placeholder: const Text('8069'), keyboardType: TextInputType.number),
                    ]);
                  }),

                  const SizedBox(height: 14),

                  LayoutBuilder(builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 400;
                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Probe Timeout (ms)'), ShadInput(controller: _timeoutController, placeholder: const Text('5000'), keyboardType: TextInputType.number)])),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Secondary Timeout (ms)'), ShadInput(controller: _timeout2Controller, placeholder: const Text('5000'), keyboardType: TextInputType.number)])),
                        ],
                      );
                    }
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('Probe Timeout (ms)'),
                      ShadInput(controller: _timeoutController, placeholder: const Text('5000'), keyboardType: TextInputType.number),
                      const SizedBox(height: 10),
                      _label('Secondary Timeout (ms)'),
                      ShadInput(controller: _timeout2Controller, placeholder: const Text('5000'), keyboardType: TextInputType.number),
                    ]);
                  }),

                  const SizedBox(height: 18),
                  ShadButton(
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
                        Icon(LucideIcons.save, size: 15),
                        SizedBox(width: 8),
                        Text('Save Preferences'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Theme Card
          ShadCard(
            title: const Text('Visual Appearance'),
            description: const Text('Choose your preferred color theme.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _themeOption(
                    title: 'System',
                    icon: LucideIcons.laptop,
                    mode: ThemeMode.system,
                    current: settingsProvider.themeMode,
                    onTap: () => settingsProvider.setThemeMode(ThemeMode.system),
                  ),
                  _themeOption(
                    title: 'Light',
                    icon: LucideIcons.sun,
                    mode: ThemeMode.light,
                    current: settingsProvider.themeMode,
                    onTap: () => settingsProvider.setThemeMode(ThemeMode.light),
                  ),
                  _themeOption(
                    title: 'Dark',
                    icon: LucideIcons.moon,
                    mode: ThemeMode.dark,
                    current: settingsProvider.themeMode,
                    onTap: () => settingsProvider.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // About Card
          ShadCard(
            title: const Text('About FDServer'),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FDServer Suite 5.0.0',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    'Flutter 3.44 + Shadcn UI. Local web server, port scanner, WhatsApp direct, socket hub, and file transfer.',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
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

  Widget _themeOption({
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode current,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.blue.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : null,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
