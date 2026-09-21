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

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<WebServerProvider>();

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
                      onPressed: serverProvider.isLoading ? null : () => serverProvider.toggleServer(),
                      backgroundColor: serverProvider.isRunning ? Colors.red.shade700 : Colors.green.shade700,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            serverProvider.isRunning ? LucideIcons.square : LucideIcons.play,
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

  Widget _buildEndpointsCard(BuildContext context, WebServerProvider provider) {
    final endpoints = [
      {'route': '/', 'label': 'Index Web Page', 'type': 'GET'},
      {'route': '/notes', 'label': 'Published Notes Explorer', 'type': 'GET'},
      {'route': '/files', 'label': 'Shared Files Directory', 'type': 'GET'},
      {'route': '/bim', 'label': 'BIM Architecture Demo', 'type': 'GET'},
      {'route': '/upload', 'label': 'Web Upload Portal', 'type': 'GET'},
      {'route': '/api/status', 'label': 'Server Status', 'type': 'JSON'},
      {'route': '/api/notes', 'label': 'Notes API', 'type': 'JSON'},
      {'route': '/api/upload', 'label': 'Upload Endpoint', 'type': 'POST'},
    ];

    return ShadCard(
      padding: const EdgeInsets.all(6),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: endpoints.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
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
        separatorBuilder: (_, __) => const Divider(height: 1),
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
