import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/scanner_provider.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ScannerProvider>();
    _ipController = TextEditingController(text: provider.targetIp);
    _portController = TextEditingController(text: provider.targetPort.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scannerProvider = context.watch<ScannerProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Network & Port Scanner', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(
                      'Probe open ports, test host reachability, and discover devices on your local network.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: () => scannerProvider.refreshInterfaces(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.refreshCw, size: 14),
                    SizedBox(width: 6),
                    Text('Refresh Interfaces'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Local Network Interfaces Cards
          const Text('Local Network Interfaces', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: scannerProvider.interfaces.map((iface) {
              final isLoopback = iface['isLoopback'] == 'true';
              return ShadCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLoopback ? LucideIcons.circleDot : LucideIcons.wifi,
                      size: 16,
                      color: isLoopback ? Colors.grey : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(iface['name'] ?? 'Interface', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(iface['address'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: () {
                        _ipController.text = iface['address'] ?? '';
                        scannerProvider.setTargetIp(iface['address'] ?? '');
                      },
                      child: const Icon(LucideIcons.arrowDownToDot, size: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Scanner Target Controls Card
          ShadCard(
            title: const Text('Probe Configuration'),
            description: const Text('Enter destination IP address and target port to probe.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target IP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            ShadInput(
                              controller: _ipController,
                              placeholder: const Text('192.168.1.100'),
                              onChanged: (val) => scannerProvider.setTargetIp(val.trim()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Port', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            ShadInput(
                              controller: _portController,
                              placeholder: const Text('8081'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                final p = int.tryParse(val.trim());
                                if (p != null) scannerProvider.setTargetPort(p);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ShadButton(
                        onPressed: scannerProvider.isScanning
                            ? null
                            : () => scannerProvider.pingTarget(),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.activity, size: 16),
                            SizedBox(width: 8),
                            Text('Probe Target'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ShadButton.outline(
                        onPressed: scannerProvider.isScanning
                            ? null
                            : () => scannerProvider.scanCommonPorts(),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.listTree, size: 16),
                            SizedBox(width: 8),
                            Text('Scan Common Ports'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ShadButton.outline(
                        onPressed: scannerProvider.isScanning
                            ? null
                            : () => scannerProvider.scanSubnet(),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.radar, size: 16),
                            SizedBox(width: 8),
                            Text('Scan Subnet'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Status & Results
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Scanned Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (scannerProvider.isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              if (scannerProvider.scannedDevices.isNotEmpty)
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => scannerProvider.clearResults(),
                  child: const Text('Clear Results'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(scannerProvider.scanStatus, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(height: 12),

          // Device Cards List
          if (scannerProvider.scannedDevices.isEmpty)
            ShadCard(
              padding: const EdgeInsets.all(24),
              child: const Center(
                child: Text('No devices scanned yet. Click "Probe Target" or "Scan Subnet" to start.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scannerProvider.scannedDevices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final device = scannerProvider.scannedDevices[index];
                return ShadCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        device.isReachable ? LucideIcons.laptop : LucideIcons.laptopMinimal,
                        color: device.isReachable ? Colors.green : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(device.ip, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: device.openPorts.entries.map((entry) {
                                return ShadBadge(
                                  backgroundColor: entry.value ? Colors.green.shade800 : Colors.grey.shade800,
                                  child: Text(
                                    'Port ${entry.key}: ${entry.value ? "OPEN" : "CLOSED"}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShadButton.ghost(
                            size: ShadButtonSize.sm,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: device.ip));
                              ShadToaster.of(context).show(
                                ShadToast(
                                  title: const Text('IP Copied'),
                                  description: Text(device.ip),
                                ),
                              );
                            },
                            child: const Icon(LucideIcons.copy, size: 16),
                          ),
                          const SizedBox(width: 8),
                          ShadButton.outline(
                            size: ShadButtonSize.sm,
                            onPressed: () {
                              final port = device.openPorts.keys.firstWhere((p) => device.openPorts[p] == true, orElse: () => 8081);
                              final url = 'http://${device.ip}:$port';
                              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.externalLink, size: 14),
                                SizedBox(width: 4),
                                Text('Browse'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
