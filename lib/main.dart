import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/services/apk_install_service.dart';
import 'core/services/file_transfer_service.dart';
import 'core/services/network_service.dart';
import 'core/services/socket_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/web_server_service.dart';
import 'core/services/whatsapp_service.dart';
import 'core/theme/app_theme.dart';

import 'features/apk_installer/providers/apk_installer_provider.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/file_transfer/providers/file_transfer_provider.dart';
import 'features/network_scanner/providers/scanner_provider.dart';
import 'features/notes/providers/notes_provider.dart';
import 'features/realtime/providers/realtime_provider.dart';
import 'features/server/screens/server_hub_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/sharing/screens/sharing_hub_screen.dart';
import 'features/tutorials/providers/tutorials_provider.dart';
import 'features/web_server/providers/web_server_provider.dart';
import 'features/whatsapp/providers/whatsapp_provider.dart';
import 'features/workspace/screens/workspace_hub_screen.dart';
import 'shared/widgets/app_header.dart';
import 'shared/widgets/responsive_sidebar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();
  final networkService = NetworkService();
  final webServerService = WebServerService();
  final whatsappService = WhatsAppService();
  final socketService = SocketService();
  final fileTransferService = FileTransferService();
  final apkInstallService = ApkInstallService();

  // Wire APK install service into HTTP and WebSocket servers
  webServerService.apkInstallService = apkInstallService;
  socketService.apkInstallService = apkInstallService;

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<ApkInstallService>.value(value: apkInstallService),
        ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
        ChangeNotifierProvider(create: (_) => NotesProvider(storageService)),
        ChangeNotifierProvider(create: (_) => TutorialsProvider(storageService)),
        ChangeNotifierProvider(
          create: (ctx) => WebServerProvider(
            webServerService,
            ctx.read<NotesProvider>(),
            networkService,
          ),
        ),
        ChangeNotifierProvider(create: (_) => ScannerProvider(networkService)),
        ChangeNotifierProvider(
          create: (_) => WhatsAppProvider(whatsappService, storageService),
        ),
        ChangeNotifierProvider(create: (_) => RealtimeProvider(socketService)),
        ChangeNotifierProvider(
          create: (_) => FileTransferProvider(fileTransferService, storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => ApkInstallerProvider(apkInstallService, networkService),
        ),
      ],
      child: const FDServerApp(),
    ),
  );
}

class FDServerApp extends StatelessWidget {
  const FDServerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return ShadApp(
      title: 'FDServer',
      debugShowCheckedModeBanner: false,
      themeMode: settingsProvider.themeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  // 0: Hub (Dashboard)
  // 1: Server & Network
  // 2: Sharing & Transfer
  // 3: Workspace & Notes
  // 4: Settings
  int _selectedPillar = 0;

  // Sub-indices for hubs
  int _serverSubIndex = 0;
  int _sharingSubIndex = 0;
  int _workspaceSubIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onNavigate(int pillarIndex, [int? subIndex]) {
    setState(() {
      _selectedPillar = pillarIndex;
      if (pillarIndex == 1 && subIndex != null) {
        _serverSubIndex = subIndex;
      } else if (pillarIndex == 2 && subIndex != null) {
        _sharingSubIndex = subIndex;
      } else if (pillarIndex == 3 && subIndex != null) {
        _workspaceSubIndex = subIndex;
      }
    });
  }

  int get _currentSubIndex {
    switch (_selectedPillar) {
      case 1:
        return _serverSubIndex;
      case 2:
        return _sharingSubIndex;
      case 3:
        return _workspaceSubIndex;
      default:
        return 0;
    }
  }

  Widget _buildBody() {
    switch (_selectedPillar) {
      case 0:
        return DashboardScreen(onNavigate: _onNavigate);
      case 1:
        return ServerHubScreen(
          key: ValueKey('server_$_serverSubIndex'),
          initialSubIndex: _serverSubIndex,
        );
      case 2:
        return SharingHubScreen(
          key: ValueKey('sharing_$_sharingSubIndex'),
          initialSubIndex: _sharingSubIndex,
        );
      case 3:
        return WorkspaceHubScreen(
          key: ValueKey('workspace_$_workspaceSubIndex'),
          initialSubIndex: _workspaceSubIndex,
        );
      case 4:
        return const SettingsScreen();
      default:
        return DashboardScreen(onNavigate: _onNavigate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopOrTablet = constraints.maxWidth >= 768;

        return Scaffold(
          key: _scaffoldKey,
          drawer: isDesktopOrTablet
              ? null
              : Drawer(
                  backgroundColor:
                      isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
                  child: SafeArea(
                    child: ResponsiveSidebar(
                      width: double.infinity,
                      selectedPillarIndex: _selectedPillar,
                      selectedSubIndex: _currentSubIndex,
                      onDestinationSelected: (pillar, [sub]) {
                        _onNavigate(pillar, sub);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
          backgroundColor:
              isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5),
          body: Column(
            children: [
              AppHeader(
                onMenuPressed: isDesktopOrTablet
                    ? null
                    : () => _scaffoldKey.currentState?.openDrawer(),
                onSettingsPressed: () => _onNavigate(4),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (isDesktopOrTablet)
                      ResponsiveSidebar(
                        selectedPillarIndex: _selectedPillar,
                        selectedSubIndex: _currentSubIndex,
                        onDestinationSelected: _onNavigate,
                      ),
                    Expanded(
                      child: Container(
                        color: isDark ? const Color(0xFF09090B) : Colors.white,
                        child: _buildBody(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktopOrTablet
              ? null
              : NavigationBar(
                  selectedIndex: _selectedPillar,
                  onDestinationSelected: (index) => _onNavigate(index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(LucideIcons.layoutDashboard),
                      label: 'Hub',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.globe),
                      label: 'Server',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.uploadCloud),
                      label: 'Transfer',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.notebookPen),
                      label: 'Workspace',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.settings),
                      label: 'Settings',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
