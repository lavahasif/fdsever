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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Network & Port Scanner',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      'Probe open ports, test host reachability, discover LAN devices.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: () => scannerProvider.refreshInterfaces(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.refreshCw, size: 13),
                    SizedBox(width: 5),
                    Text('Refresh', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Interface Cards
          if (scannerProvider.interfaces.isNotEmpty) ...[
            const Text('Local Interfaces',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: scannerProvider.interfaces.map((iface) {
                final isLoopback = iface['isLoopback'] == 'true';
                return ShadCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLoopback ? LucideIcons.circleDot : LucideIcons.wifi,
                        size: 15,
                        color: isLoopback ? Colors.grey : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(iface['name'] ?? 'Interface',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          Text(iface['address'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(width: 6),
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: () {
                          _ipController.text = iface['address'] ?? '';
                          scannerProvider.setTargetIp(iface['address'] ?? '');
                        },
                        child: const Icon(LucideIcons.arrowDownToDot, size: 13),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Probe Config Card
          ShadCard(
            title: const Text('Probe Target'),
            description: const Text('Enter target IP and port, then choose a scan mode.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 420;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWide)
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _labeled(
                              'Target IP',
                              ShadInput(
                                controller: _ipController,
                                placeholder: const Text('192.168.1.100'),
                                onChanged: (v) => scannerProvider.setTargetIp(v.trim()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: _labeled(
                              'Port',
                              ShadInput(
                                controller: _portController,
                                placeholder: const Text('8081'),
                                keyboardType: TextInputType.number,
                                onChanged: (v) {
                                  final p = int.tryParse(v.trim());
                                  if (p != null) scannerProvider.setTargetPort(p);
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _labeled(
                        'Target IP',
                        ShadInput(
                          controller: _ipController,
                          placeholder: const Text('192.168.1.100'),
                          onChanged: (v) => scannerProvider.setTargetIp(v.trim()),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _labeled(
                        'Port',
                        ShadInput(
                          controller: _portController,
                          placeholder: const Text('8081'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final p = int.tryParse(v.trim());
                            if (p != null) scannerProvider.setTargetPort(p);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Action Buttons - always Wrap for safe mobile layout
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ShadButton(
                          onPressed: scannerProvider.isScanning
                              ? null
                              : () => scannerProvider.pingTarget(),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.activity, size: 15),
                              SizedBox(width: 7),
                              Text('Probe Target'),
                            ],
                          ),
                        ),
                        ShadButton.outline(
                          onPressed: scannerProvider.isScanning
                              ? null
                              : () => scannerProvider.scanCommonPorts(),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.listTree, size: 15),
                              SizedBox(width: 7),
                              Text('Scan Common Ports'),
                            ],
                          ),
                        ),
                        ShadButton.outline(
                          onPressed: scannerProvider.isScanning
                              ? null
                              : () => scannerProvider.scanSubnet(),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.radar, size: 15),
                              SizedBox(width: 7),
                              Text('Scan Subnet'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: 22),

          // Results Header
          Row(
            children: [
              const Text('Scanned Results',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              if (scannerProvider.isScanning)
                const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              const Spacer(),
              if (scannerProvider.scannedDevices.isNotEmpty)
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => scannerProvider.clearResults(),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(scannerProvider.scanStatus,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 12),

          // Results
          if (scannerProvider.scannedDevices.isEmpty)
            ShadCard(
              padding: const EdgeInsets.all(24),
              child: const Center(
                child: Text(
                  'No devices scanned yet.\nClick "Probe Target" or "Scan Subnet" to start.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
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
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        device.isReachable ? LucideIcons.laptop : LucideIcons.laptopMinimal,
                        color: device.isReachable ? Colors.green : Colors.grey,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(device.ip,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: device.openPorts.entries.map((entry) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (entry.value
                                            ? Colors.green
                                            : Colors.grey)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${entry.key}: ${entry.value ? "OPEN" : "CLOSED"}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: entry.value
                                          ? Colors.green.shade400
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action buttons always stacked if too narrow
                      Column(
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
                            child: const Icon(LucideIcons.copy, size: 15),
                          ),
                          ShadButton.outline(
                            size: ShadButtonSize.sm,
                            onPressed: () {
                              final port = device.openPorts.keys.firstWhere(
                                  (p) => device.openPorts[p] == true,
                                  orElse: () => 8081);
                              launchUrl(
                                  Uri.parse('http://${device.ip}:$port'),
                                  mode: LaunchMode.externalApplication);
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.externalLink, size: 13),
                                SizedBox(width: 3),
                                Text('Browse', style: TextStyle(fontSize: 12)),
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

  Widget _labeled(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
