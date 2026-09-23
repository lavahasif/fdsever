import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../shared/widgets/status_badge.dart';
import '../providers/web_server_provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class WebServerScreen extends StatefulWidget {
  const WebServerScreen({super.key});

  @override
  State<WebServerScreen> createState() => _WebServerScreenState();
}

class _WebServerScreenState extends State<WebServerScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<WebServerProvider>();
    _hostController = TextEditingController(text: provider.host);
    _portController = TextEditingController(text: provider.port.toString());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _selectIp(String ip, WebServerProvider provider) {
    _hostController.text = ip;
    provider.setHost(ip);
  }

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<WebServerProvider>();

    // Keep controllers in sync if updated externally
    if (_hostController.text != serverProvider.host && !serverProvider.isRunning) {
      _hostController.text = serverProvider.host;
    }

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
                    const Text('Local Web Server',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      'Host web apps, APIs, and share files over your local WiFi.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(
                isActive: serverProvider.isRunning,
                activeLabel: 'RUNNING',
                inactiveLabel: 'STOPPED',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Error alert
          if (serverProvider.errorMessage != null) ...[
            ShadAlert.destructive(
              icon: const Icon(LucideIcons.triangleAlert, size: 16),
              title: const Text('Server Error'),
              description: Text(serverProvider.errorMessage!),
            ),
            const SizedBox(height: 14),
          ],

          // System IPs Discovery Card
          ShadCard(
            title: Row(
              children: [
                const Icon(LucideIcons.network, size: 18),
                const SizedBox(width: 8),
                Text('Available System IPs (${serverProvider.systemIps.length} found)'),
                const Spacer(),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: serverProvider.isSearchingIps
                      ? null
                      : () => serverProvider.searchSystemIps(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.refreshCw,
                        size: 14,
                        color: serverProvider.isSearchingIps ? Colors.grey : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        serverProvider.isSearchingIps ? 'Searching...' : 'Search System IPs',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            description: const Text(
              'Select an IP to bind, or leave 0.0.0.0 to listen on all interfaces.',
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // 0.0.0.0 chip
                  InkWell(
                    onTap: serverProvider.isRunning ? null : () => _selectIp('0.0.0.0', serverProvider),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: serverProvider.host == '0.0.0.0'
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: serverProvider.host == '0.0.0.0'
                              ? Colors.blue
                              : const Color(0xFF27272A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.globe,
                            size: 14,
                            color: serverProvider.host == '0.0.0.0' ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '0.0.0.0 (All Interfaces)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Individual system interfaces
                  ...serverProvider.systemIps.map((item) {
                    final ip = item['address'] ?? '';
                    final name = item['name'] ?? '';
                    final isLoopback = item['isLoopback'] == 'true';
                    final isSelected = serverProvider.host == ip;

                    return InkWell(
                      onTap: serverProvider.isRunning ? null : () => _selectIp(ip, serverProvider),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? Colors.green : const Color(0xFF27272A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLoopback ? LucideIcons.laptop : LucideIcons.wifi,
                              size: 14,
                              color: isSelected ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$name: $ip',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            if (ip == serverProvider.primaryIp && !isLoopback) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'Primary LAN',
                                  style: TextStyle(fontSize: 9, color: Colors.blue),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Configuration Card
          ShadCard(
            title: const Text('Server Configuration'),
            description: const Text('Set listening address and TCP port.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 480;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _labeledInput(
                              label: 'Bind Address',
                              child: ShadInput(
                                controller: _hostController,
                                placeholder: const Text('0.0.0.0 or localhost'),
                                enabled: !serverProvider.isRunning,
                                onChanged: (v) => serverProvider.setHost(v.trim()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: _labeledInput(
                              label: 'Port',
                              child: ShadInput(
                                controller: _portController,
                                placeholder: const Text('8081'),
                                enabled: !serverProvider.isRunning,
                                keyboardType: TextInputType.number,
                                onChanged: (v) {
                                  final p = int.tryParse(v.trim());
                                  if (p != null) serverProvider.setPort(p);
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _labeledInput(
                        label: 'Bind Address',
                        child: ShadInput(
                          controller: _hostController,
                          placeholder: const Text('0.0.0.0'),
                          enabled: !serverProvider.isRunning,
                          onChanged: (v) => serverProvider.setHost(v.trim()),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _labeledInput(
                        label: 'Port',
                        child: ShadInput(
                          controller: _portController,
                          placeholder: const Text('8081'),
                          enabled: !serverProvider.isRunning,
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final p = int.tryParse(v.trim());
                            if (p != null) serverProvider.setPort(p);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ShadButton(
                      onPressed: serverProvider.isLoading
                          ? null
                          : () => serverProvider.toggleServer(),
                      backgroundColor: serverProvider.isRunning
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            serverProvider.isRunning
                                ? LucideIcons.square
                                : LucideIcons.play,
                            size: 15,
                          ),
                          const SizedBox(width: 8),
                          Text(serverProvider.isRunning ? 'Stop Server' : 'Start Server'),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

          // Accessible Live Endpoints (when running)
          if (serverProvider.isRunning) ...[
            const SizedBox(height: 22),
            const Text('🌐 Accessible Server Endpoints',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Connect from other devices on your LAN using any of the URLs below:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 10),
            _buildAccessibleUrlsCard(context, serverProvider),
          ],

          const SizedBox(height: 22),
          const Text('Available Server Routes',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildEndpointsCard(context, serverProvider),

          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Server Requests',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('${serverProvider.logs.length} events',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          _buildLogsTable(serverProvider),
        ],
      ),
    );
  }

  Widget _labeledInput({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildAccessibleUrlsCard(BuildContext context, WebServerProvider provider) {
    final urls = provider.accessibleUrls;

    return ShadCard(
      padding: const EdgeInsets.all(8),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: urls.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = urls[index];
          final url = item['url'] ?? '';
          final name = item['name'] ?? '';
          final isLoopback = item['isLoopback'] == 'true';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isLoopback ? LucideIcons.laptop : LucideIcons.wifi,
                  size: 16,
                  color: isLoopback ? Colors.grey : Colors.greenAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        url,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.greenAccent,
                        ),
                      ),
                      Text(
                        '$name ${isLoopback ? "(This device only)" : "(Reachable over LAN)"}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ShadToaster.of(context).show(
                      ShadToast(
                        title: const Text('Copied URL'),
                        description: Text(url),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.copy, size: 13),
                      SizedBox(width: 4),
                      Text('Copy', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.externalLink, size: 13),
                      SizedBox(width: 4),
                      Text('Open', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEndpointsCard(BuildContext context, WebServerProvider provider) {
    final endpoints = [
      {'route': '/', 'label': 'Rich Web Portal & Edge Hub', 'type': 'GET'},
      {'route': '/upload', 'label': 'File Vault & Drag-and-Drop Uploader', 'type': 'GET'},
      {'route': '/notes', 'label': 'Synchronized Device Notes', 'type': 'GET'},
      {'route': '/api/status', 'label': 'Server Health & Telemetry', 'type': 'JSON'},
      {'route': '/api/notes', 'label': 'Device Notes JSON API', 'type': 'JSON'},
      {'route': '/api/upload', 'label': 'Binary File Upload Stream', 'type': 'POST'},
      {'route': '/api/install-apk', 'label': 'Remote APK Package Installer', 'type': 'POST'},
    ];

    return ShadCard(
      padding: const EdgeInsets.all(6),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: endpoints.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ep = endpoints[index];
          final fullUrl = '${provider.serverUrl}${ep['route']}';
          final typeColor = ep['type'] == 'POST'
              ? Colors.orange.shade700
              : ep['type'] == 'JSON'
                  ? Colors.blue.shade700
                  : Colors.green.shade700;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ep['type']!,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                        letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ep['route']!,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      Text(ep['label']!,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: fullUrl));
                    ShadToaster.of(context).show(
                      ShadToast(
                        title: const Text('Copied'),
                        description: Text(fullUrl),
                      ),
                    );
                  },
                  child: const Icon(LucideIcons.copy, size: 14),
                ),
                if (provider.isRunning && ep['type'] != 'POST') ...[
                  const SizedBox(width: 4),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () =>
                        launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.externalLink, size: 12),
                        SizedBox(width: 3),
                        Text('Open', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogsTable(WebServerProvider provider) {
    if (provider.logs.isEmpty) {
      return ShadCard(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'No requests logged yet. Start server to see live traffic.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ShadCard(
      padding: const EdgeInsets.all(6),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: provider.logs.take(15).length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = provider.logs[index];
          final isSuccess = log.statusCode >= 200 && log.statusCode < 400;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isSuccess ? Colors.green : Colors.red).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${log.statusCode}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSuccess ? Colors.green.shade400 : Colors.red.shade400),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  child: Text(log.method,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                Expanded(
                  child: Text(
                    log.path,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 8),
                Text(log.clientIp,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          );
        },
      ),
    );
  }
}
