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

    if (_ipController.text != provider.pcIp && !provider.isConnected) {
      _ipController.text = provider.pcIp;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.install_mobile_rounded, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('APK Easy Installer',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('PersonalTasker PC Server Listener & Direct APK Downloader',
                        style: TextStyle(fontSize: 12, color: Color(0xFF71717a))),
                  ],
                ),
              ),
              if (provider.isProcessing || provider.isDownloading)
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── PC Server Connection & Listener Card ────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18181b),
              border: Border.all(
                color: provider.isConnected ? const Color(0xFF22c55e) : const Color(0xFF27272a),
                width: provider.isConnected ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🖥️ PersonalTasker PC Server Connection',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: provider.isConnected
                            ? Colors.green.withValues(alpha: 0.15)
                            : (provider.isConnecting ? Colors.amber.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        provider.isConnected ? '● CONNECTED' : (provider.isConnecting ? '◌ CONNECTING...' : '○ DISCONNECTED'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: provider.isConnected ? Colors.green : (provider.isConnecting ? Colors.amber : Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // IP & Port Inputs
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PC Server IP', style: TextStyle(fontSize: 11, color: Color(0xFF71717a))),
                          const SizedBox(height: 4),
                          ShadInput(
                            controller: _ipController,
                            placeholder: const Text('10.225.138.220'),
                            enabled: !provider.isConnected,
                            onChanged: (v) => provider.setPcIp(v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Port', style: TextStyle(fontSize: 11, color: Color(0xFF71717a))),
                          const SizedBox(height: 4),
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
                ),
                const SizedBox(height: 12),

                // Action Buttons Row
                Row(
                  children: [
                    ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: provider.isConnecting
                          ? null
                          : () {
                              if (provider.isConnected) {
                                provider.disconnectFromPc();
                              } else {
                                provider.connectToPc(_ipController.text, int.tryParse(_portController.text) ?? 9890);
                              }
                            },
                      backgroundColor: provider.isConnected ? Colors.red.shade700 : Colors.blue.shade700,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(provider.isConnected ? Icons.link_off_rounded : Icons.link_rounded, size: 14),
                          const SizedBox(width: 6),
                          Text(provider.isConnected ? 'Disconnect' : 'Connect to PC'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: provider.isSearchingPc || provider.isConnected
                          ? null
                          : () => provider.autoDiscoverPc(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded, size: 14, color: provider.isSearchingPc ? Colors.amber : Colors.white),
                          const SizedBox(width: 6),
                          Text(provider.isSearchingPc ? 'Searching...' : '🔍 Auto-Discover PC'),
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
                    color: provider.isConnected ? Colors.green.shade400 : const Color(0xFF71717a),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Active Live Download Card (When receiving from PC) ───
          if (provider.isDownloading) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181b),
                border: Border.all(color: Colors.blue.shade600, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.downloading_rounded, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Downloading ${provider.activeJobName ?? "APK"}...',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Text('${provider.downloadPercent}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: provider.downloadPercent / 100.0,
                    backgroundColor: const Color(0xFF27272a),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(provider.bytesDownloaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(provider.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB streamed from PersonalTasker',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF71717a)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Manual Local Install Button ──────────────────────────
          ShadButton.outline(
            onPressed: () => _pickAndInstallApk(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_rounded, size: 16),
                SizedBox(width: 8),
                Text('Pick APK from Device Storage'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Install Log ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Install Log (${provider.log.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (provider.log.isNotEmpty)
                TextButton(
                  onPressed: provider.clearLog,
                  child: const Text('Clear',
                      style: TextStyle(fontSize: 12, color: Color(0xFF71717a))),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (provider.log.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF18181b),
                border: Border.all(color: const Color(0xFF27272a)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 38, color: Color(0xFF3f3f46)),
                  SizedBox(height: 8),
                  Text('No installs yet',
                      style: TextStyle(color: Color(0xFF52525b), fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Connect to PersonalTasker on your PC and click Start Install',
                      style: TextStyle(color: Color(0xFF3f3f46), fontSize: 11)),
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
