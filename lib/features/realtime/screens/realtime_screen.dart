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
    _serverPortController =
        TextEditingController(text: provider.localServerPort.toString());
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
                    const Text('Realtime WebSocket Hub',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      'Connect to WebSocket servers or run a local echo server for real-time messaging.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(
                isActive: realtimeProvider.isClientConnected,
                activeLabel: 'CONNECTED',
                inactiveLabel: 'IDLE',
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Client + Server control cards — responsive
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 640;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildClientCard(realtimeProvider)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildServerCard(realtimeProvider)),
                ],
              );
            }
            return Column(
              children: [
                _buildClientCard(realtimeProvider),
                const SizedBox(height: 14),
                _buildServerCard(realtimeProvider),
              ],
            );
          }),

          const SizedBox(height: 20),

          // Message Input
          ShadCard(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: ShadInput(
                    controller: _msgInputController,
                    placeholder: const Text('Type socket payload or message...'),
                    onSubmitted: (v) {
                      realtimeProvider.sendMessage(v);
                      _msgInputController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 10),
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

          const SizedBox(height: 20),

          // Message Log header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Message Stream',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              if (realtimeProvider.messages.isNotEmpty)
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => realtimeProvider.clearHistory(),
                  child:
                      const Text('Clear Log', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (realtimeProvider.messages.isEmpty)
            ShadCard(
              padding: const EdgeInsets.all(24),
              child: const Center(
                child: Text(
                  'No socket events yet.\nConnect to a server or start the echo server.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: realtimeProvider.messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final msg = realtimeProvider.messages.reversed
                    .toList()[index];
                final isClient = msg.source == MessageSource.client;
                final isSystem = msg.source == MessageSource.system;
                final badgeColor = isClient
                    ? Colors.blue.shade800
                    : (isSystem ? Colors.grey.shade700 : Colors.green.shade800);

                return ShadCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              msg.source.name.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}:${msg.timestamp.second.toString().padLeft(2, '0')}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                          const Spacer(),
                          ShadButton.ghost(
                            size: ShadButtonSize.sm,
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: msg.text));
                              ShadToaster.of(context).show(
                                const ShadToast(
                                  title: Text('Copied'),
                                  description:
                                      Text('Message text copied'),
                                ),
                              );
                            },
                            child: const Icon(LucideIcons.copy, size: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        msg.text,
                        style: const TextStyle(
                            fontSize: 13, fontFamily: 'monospace'),
                      ),
                      if (msg.extractedUrls.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: msg.extractedUrls.map((url) {
                            return ShadButton.outline(
                              size: ShadButtonSize.sm,
                              onPressed: () => launchUrl(Uri.parse(url),
                                  mode:
                                      LaunchMode.externalApplication),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      LucideIcons.externalLink,
                                      size: 11),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(url,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11)),
                                  ),
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

  Widget _buildClientCard(RealtimeProvider provider) {
    return ShadCard(
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
              enabled: !provider.isClientConnected,
              onChanged: (v) => provider.setServerUrl(v.trim()),
            ),
            const SizedBox(height: 12),
            ShadButton(
              onPressed: () => provider.toggleClientConnection(),
              backgroundColor:
                  provider.isClientConnected ? Colors.red.shade700 : null,
              child: Text(provider.isClientConnected
                  ? 'Disconnect'
                  : 'Connect Client'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerCard(RealtimeProvider provider) {
    return ShadCard(
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
              enabled: !provider.isServerRunning,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final p = int.tryParse(v.trim());
                if (p != null) provider.setLocalServerPort(p);
              },
            ),
            const SizedBox(height: 12),
            ShadButton.outline(
              onPressed: () => provider.toggleLocalServer(),
              child: Text(provider.isServerRunning
                  ? 'Stop Echo Server'
                  : 'Start Echo Server'),
            ),
          ],
        ),
      ),
    );
  }
}
