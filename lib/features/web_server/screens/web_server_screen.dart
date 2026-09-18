import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/status_badge.dart';
import '../providers/web_server_provider.dart';

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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Local Web Server', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(
                      'Host web applications, APIs, and share files directly over your local WiFi network.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              StatusBadge(
                isActive: serverProvider.isRunning,
                activeLabel: 'RUNNING',
                inactiveLabel: 'STOPPED',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Error alert if any
          if (serverProvider.errorMessage != null) ...[
            ShadAlert.destructive(
              icon: const Icon(LucideIcons.triangleAlert, size: 16),
              title: const Text('Server Error'),
              description: Text(serverProvider.errorMessage!),
            ),
            const SizedBox(height: 16),
          ],

          // Control & Configuration Card
          ShadCard(
            title: const Text('Server Configuration'),
            description: const Text('Set listening host IP and TCP port to bind the Shelf HTTP server.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bind Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        ShadInput(
                          controller: _hostController,
                          placeholder: const Text('e.g. 0.0.0.0 or localhost'),
                          enabled: !serverProvider.isRunning,
                          onChanged: (val) => serverProvider.setHost(val.trim()),
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
                          placeholder: const Text('e.g. 8081'),
                          enabled: !serverProvider.isRunning,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final p = int.tryParse(val.trim());
                            if (p != null) serverProvider.setPort(p);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: ShadButton(
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
                            serverProvider.isRunning ? LucideIcons.square : LucideIcons.play,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(serverProvider.isRunning ? 'Stop Server' : 'Start Server'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Active Endpoints Explorer
          const Text('Available Server Routes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildEndpointsCard(context, serverProvider),

          const SizedBox(height: 24),

          // Realtime Server Request Logs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Server Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${serverProvider.logs.length} logged events', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          _buildLogsTable(serverProvider),
        ],
      ),
    );
  }

  Widget _buildEndpointsCard(BuildContext context, WebServerProvider provider) {
    final endpoints = [
      {'route': '/', 'label': 'Index Web Page', 'type': 'HTML'},
      {'route': '/notes', 'label': 'Published Notes Explorer', 'type': 'HTML'},
      {'route': '/files', 'label': 'Shared Files Directory', 'type': 'HTML'},
      {'route': '/bim', 'label': 'BIM Architecture Demo', 'type': 'HTML'},
      {'route': '/upload', 'label': 'Web Upload Portal', 'type': 'HTML'},
      {'route': '/api/status', 'label': 'Server Status API', 'type': 'JSON'},
      {'route': '/api/notes', 'label': 'Notes API Endpoint', 'type': 'JSON'},
      {'route': '/api/upload', 'label': 'Multipart Upload Target', 'type': 'POST'},
    ];

    return ShadCard(
      padding: const EdgeInsets.all(8),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: endpoints.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ep = endpoints[index];
          final fullUrl = '${provider.serverUrl}${ep['route']}';

          return ListTile(
            dense: true,
            leading: ShadBadge.outline(
              child: Text(ep['type']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
            ),
            title: Text(ep['route']!, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
            subtitle: Text(ep['label']!, style: const TextStyle(fontSize: 12)),
            trailing: Wrap(
              spacing: 8,
              children: [
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: fullUrl));
                    ShadToaster.of(context).show(
                      ShadToast(
                        title: const Text('Endpoint Copied'),
                        description: Text(fullUrl),
                      ),
                    );
                  },
                  child: const Icon(LucideIcons.copy, size: 14),
                ),
                if (provider.isRunning && ep['type'] != 'POST')
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () => launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.externalLink, size: 12),
                        SizedBox(width: 4),
                        Text('Open'),
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

  Widget _buildLogsTable(WebServerProvider provider) {
    if (provider.logs.isEmpty) {
      return ShadCard(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text('No request traffic logged yet. Start server and make requests to see live logs.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ShadCard(
      padding: const EdgeInsets.all(8),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: provider.logs.take(15).length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = provider.logs[index];
          final isSuccess = log.statusCode >= 200 && log.statusCode < 400;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ShadBadge(
                  backgroundColor: isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                  child: Text('${log.statusCode}', style: const TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  child: Text(log.method, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Text(log.clientIp, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }
}
