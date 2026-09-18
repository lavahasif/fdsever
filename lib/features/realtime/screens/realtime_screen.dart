import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/socket_message.dart';
import '../../../shared/widgets/status_badge.dart';
import '../providers/realtime_provider.dart';

class RealtimeScreen extends StatefulWidget {
  const RealtimeScreen({super.key});

  @override
  State<RealtimeScreen> createState() => _RealtimeScreenState();
}

class _RealtimeScreenState extends State<RealtimeScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _serverPortController;
  final TextEditingController _msgInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<RealtimeProvider>();
    _urlController = TextEditingController(text: provider.serverUrl);
    _serverPortController = TextEditingController(text: provider.localServerPort.toString());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _serverPortController.dispose();
    _msgInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final realtimeProvider = context.watch<RealtimeProvider>();

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
                    const Text('Realtime WebSocket & Signal Hub', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(
                      'Connect to WebSocket or SignalR servers, test bi-directional socket messaging, or run a local echo server.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              StatusBadge(
                isActive: realtimeProvider.isClientConnected,
                activeLabel: 'CLIENT CONNECTED',
                inactiveLabel: 'CLIENT IDLE',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Two Control Cards in Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client Controller
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: ShadCard(
                      title: const Text('WebSocket Client'),
                      description: const Text('Connect to any remote WS endpoint.'),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShadInput(
                              controller: _urlController,
                              placeholder: const Text('ws://127.0.0.1:8082'),
                              enabled: !realtimeProvider.isClientConnected,
                              onChanged: (val) => realtimeProvider.setServerUrl(val.trim()),
                            ),
                            const SizedBox(height: 12),
                            ShadButton(
                              onPressed: () => realtimeProvider.toggleClientConnection(),
                              backgroundColor: realtimeProvider.isClientConnected ? Colors.red.shade700 : null,
                              child: Text(realtimeProvider.isClientConnected ? 'Disconnect Client' : 'Connect Client'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),

                  // Echo Server Controller
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: ShadCard(
                      title: const Text('Local Echo Server'),
                      description: const Text('Run an on-device echo WebSocket server.'),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShadInput(
                              controller: _serverPortController,
                              placeholder: const Text('8082'),
                              enabled: !realtimeProvider.isServerRunning,
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                final p = int.tryParse(val.trim());
                                if (p != null) realtimeProvider.setLocalServerPort(p);
                              },
                            ),
                            const SizedBox(height: 12),
                            ShadButton.outline(
                              onPressed: () => realtimeProvider.toggleLocalServer(),
                              child: Text(realtimeProvider.isServerRunning ? 'Stop Echo Server' : 'Start Echo Server'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Message Input Card
          ShadCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ShadInput(
                    controller: _msgInputController,
                    placeholder: const Text('Type socket payload or message...'),
                    onSubmitted: (val) {
                      realtimeProvider.sendMessage(val);
                      _msgInputController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ShadButton(
                  onPressed: () {
                    realtimeProvider.sendMessage(_msgInputController.text);
                    _msgInputController.clear();
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.send, size: 14),
                      SizedBox(width: 6),
                      Text('Send'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Message Timeline Log
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Message Stream', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (realtimeProvider.messages.isNotEmpty)
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => realtimeProvider.clearHistory(),
                  child: const Text('Clear Log'),
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (realtimeProvider.messages.isEmpty)
            ShadCard(
              padding: const EdgeInsets.all(24),
              child: const Center(
                child: Text('No socket events logged yet. Connect to a socket or start the echo server.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: realtimeProvider.messages.reversed.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final msg = realtimeProvider.messages.reversed.toList()[index];
                final isClient = msg.source == MessageSource.client;
                final isSystem = msg.source == MessageSource.system;

                return ShadCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ShadBadge(
                                backgroundColor: isClient
                                    ? Colors.blue.shade800
                                    : (isSystem ? Colors.grey.shade800 : Colors.green.shade800),
                                child: Text(
                                  msg.source.name.toUpperCase(),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}:${msg.timestamp.second.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          ShadButton.ghost(
                            size: ShadButtonSize.sm,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: msg.text));
                              ShadToaster.of(context).show(
                                const ShadToast(
                                  title: Text('Copied'),
                                  description: Text('Message text copied to clipboard'),
                                ),
                              );
                            },
                            child: const Icon(LucideIcons.copy, size: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        msg.text,
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      ),
                      if (msg.extractedUrls.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: msg.extractedUrls.map((url) {
                            return ShadButton.outline(
                              size: ShadButtonSize.sm,
                              onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.externalLink, size: 12),
                                  const SizedBox(width: 4),
                                  Text(url, style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
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
