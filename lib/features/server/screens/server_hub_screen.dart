import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../shared/widgets/category_segmented_bar.dart';
import '../../network_scanner/screens/scanner_screen.dart';
import '../../realtime/providers/realtime_provider.dart';
import '../../realtime/screens/realtime_screen.dart';
import '../../web_server/providers/web_server_provider.dart';
import '../../web_server/screens/web_server_screen.dart';

class ServerHubScreen extends StatefulWidget {
  final int initialSubIndex;

  const ServerHubScreen({super.key, this.initialSubIndex = 0});

  @override
  State<ServerHubScreen> createState() => _ServerHubScreenState();
}

class _ServerHubScreenState extends State<ServerHubScreen> {
  late int _selectedSubIndex;

  @override
  void initState() {
    super.initState();
    _selectedSubIndex = widget.initialSubIndex;
  }

  @override
  void didUpdateWidget(covariant ServerHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubIndex != widget.initialSubIndex) {
      _selectedSubIndex = widget.initialSubIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final webServer = context.watch<WebServerProvider>();
    final realtime = context.watch<RealtimeProvider>();

    final tabs = [
      CategoryTabItem(
        title: 'Web Server',
        icon: LucideIcons.globe,
        showActiveDot: webServer.isRunning,
        badgeText: webServer.isRunning ? ':${webServer.port}' : null,
      ),
      const CategoryTabItem(
        title: 'Port Scanner',
        icon: LucideIcons.radar,
      ),
      CategoryTabItem(
        title: 'WebSocket Hub',
        icon: LucideIcons.radio,
        showActiveDot: realtime.isServerRunning || realtime.isClientConnected,
        badgeText: realtime.isServerRunning ? 'Server' : (realtime.isClientConnected ? 'Client' : null),
      ),
    ];

    Widget body;
    switch (_selectedSubIndex) {
      case 1:
        body = const ScannerScreen();
        break;
      case 2:
        body = const RealtimeScreen();
        break;
      case 0:
      default:
        body = const WebServerScreen();
        break;
    }

    return Column(
      children: [
        CategorySegmentedBar(
          tabs: tabs,
          selectedIndex: _selectedSubIndex,
          onTabSelected: (idx) => setState(() => _selectedSubIndex = idx),
        ),
        Expanded(child: body),
      ],
    );
  }
}
