import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/apk_installer_provider.dart';
import '../widgets/install_progress_card.dart';

class ApkInstallerScreen extends StatefulWidget {
  const ApkInstallerScreen({super.key});

  @override
  State<ApkInstallerScreen> createState() => _ApkInstallerScreenState();
}

class _ApkInstallerScreenState extends State<ApkInstallerScreen> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ApkInstallerProvider>();
    _ipController = TextEditingController(text: provider.pcIp);
    _portController = TextEditingController(text: provider.pcPort.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _pickAndInstallApk() async {
    final provider = context.read<ApkInstallerProvider>();
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );
    if (files.isEmpty || !mounted) return;
    for (final file in files) {
      final bytes = await file.xFile.readAsBytes();
      await provider.installApk(file.name, bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApkInstallerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryTextColor = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B);
    final mutedTextColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
    final cardBgColor = isDark ? const Color(0xFF18181B) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    if (_ipController.text != provider.pcIp && !provider.isConnected) {
      _ipController.text = provider.pcIp;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.package, color: Color(0xFFEC4899), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APK Easy Installer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'PersonalTasker PC Server Listener & Direct APK Downloader',
                      style: TextStyle(
                        fontSize: 12,
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.isProcessing || provider.isDownloading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // ── PC Server Connection & Listener Card ────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBgColor,
              border: Border.all(
                color: provider.isConnected
                    ? const Color(0xFF10B981)
                    : (provider.isConnecting ? const Color(0xFFF59E0B) : cardBorderColor),
                width: provider.isConnected ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Status Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.monitor, size: 16, color: primaryTextColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PersonalTasker PC Server',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: primaryTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: provider.isConnected
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (provider.isConnecting
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5))),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: provider.isConnected
                                  ? const Color(0xFF10B981)
                                  : (provider.isConnecting ? const Color(0xFFF59E0B) : Colors.grey),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            provider.isConnected
                                ? 'CONNECTED'
                                : (provider.isConnecting ? 'CONNECTING...' : 'DISCONNECTED'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: provider.isConnected
                                  ? const Color(0xFF10B981)
                                  : (provider.isConnecting ? const Color(0xFFF59E0B) : mutedTextColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Responsive IP & Port Inputs
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 420;

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PC Server IP',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mutedTextColor),
                          ),
                          const SizedBox(height: 5),
                          ShadInput(
                            controller: _ipController,
                            placeholder: const Text('10.225.138.220'),
                            enabled: !provider.isConnected,
                            onChanged: (v) => provider.setPcIp(v),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Port',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mutedTextColor),
                          ),
                          const SizedBox(height: 5),
                          ShadInput(
                            controller: _portController,
                            placeholder: const Text('9890'),
                            enabled: !provider.isConnected,
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final p = int.tryParse(v);
                              if (p != null) provider.setPcPort(p);
                            },
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PC Server IP',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mutedTextColor),
                              ),
                              const SizedBox(height: 5),
                              ShadInput(
                                controller: _ipController,
                                placeholder: const Text('10.225.138.220'),
                                enabled: !provider.isConnected,
                                onChanged: (v) => provider.setPcIp(v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Port',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mutedTextColor),
                              ),
                              const SizedBox(height: 5),
                              ShadInput(
                                controller: _portController,
                                placeholder: const Text('9890'),
                                enabled: !provider.isConnected,
                                keyboardType: TextInputType.number,
                                onChanged: (v) {
                                  final p = int.tryParse(v);
                                  if (p != null) provider.setPcPort(p);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 14),

                // Responsive Action Buttons Wrap
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: provider.isConnecting
                          ? null
                          : () {
                              if (provider.isConnected) {
                                provider.disconnectFromPc();
                              } else {
                                provider.connectToPc(
                                  _ipController.text,
                                  int.tryParse(_portController.text) ?? 9890,
                                );
                              }
                            },
                      backgroundColor: provider.isConnected
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF3B82F6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            provider.isConnected ? LucideIcons.unplug : LucideIcons.plug,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            provider.isConnected ? 'Disconnect' : 'Connect to PC',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: provider.isSearchingPc || provider.isConnected
                          ? null
                          : () => provider.autoDiscoverPc(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (provider.isSearchingPc)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              LucideIcons.search,
                              size: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            provider.isSearchingPc ? 'Searching LAN...' : 'Auto-Discover PC',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Text(
                  provider.connectionStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: provider.isConnected ? const Color(0xFF10B981) : mutedTextColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Active Live Download Card (When receiving from PC) ───
          if (provider.isDownloading) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.download, color: Color(0xFF3B82F6), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Downloading ${provider.activeJobName ?? "APK"}...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: primaryTextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${provider.downloadPercent}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: provider.downloadPercent / 100.0,
                      backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(provider.bytesDownloaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(provider.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB streamed from PersonalTasker',
                    style: TextStyle(fontSize: 11, color: mutedTextColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ── Manual Local Install Button ──────────────────────────
          ShadButton.outline(
            onPressed: () => _pickAndInstallApk(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.folderOpen, size: 16, color: isDark ? Colors.white : Colors.black87),
                const SizedBox(width: 8),
                Text(
                  'Pick APK from Device Storage',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Install Log ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Install Log (${provider.log.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              if (provider.log.isNotEmpty)
                TextButton(
                  onPressed: provider.clearLog,
                  child: Text(
                    'Clear Log',
                    style: TextStyle(fontSize: 12, color: mutedTextColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (provider.log.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border.all(color: cardBorderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.inbox,
                    size: 36,
                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No installs yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Connect to PersonalTasker on your PC and click Start Install, or pick an APK manually.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: mutedTextColor, fontSize: 11),
                  ),
                ],
              ),
            )
          else
            ...provider.log.take(50).map((e) => InstallProgressCard(event: e)),
        ],
      ),
    );
  }
}
