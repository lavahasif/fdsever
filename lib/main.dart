import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/services/file_transfer_service.dart';
import 'core/services/network_service.dart';
import 'core/services/socket_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/web_server_service.dart';
import 'core/services/whatsapp_service.dart';
import 'core/theme/app_theme.dart';

import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/file_transfer/providers/file_transfer_provider.dart';
import 'features/file_transfer/screens/file_transfer_screen.dart';
import 'features/network_scanner/providers/scanner_provider.dart';
import 'features/network_scanner/screens/scanner_screen.dart';
import 'features/notes/providers/notes_provider.dart';
import 'features/notes/screens/notes_screen.dart';
import 'features/realtime/providers/realtime_provider.dart';
import 'features/realtime/screens/realtime_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/tutorials/providers/tutorials_provider.dart';
import 'features/tutorials/screens/tutorials_screen.dart';
import 'features/web_server/providers/web_server_provider.dart';
import 'features/web_server/screens/web_server_screen.dart';
import 'features/whatsapp/providers/whatsapp_provider.dart';
import 'features/whatsapp/screens/whatsapp_screen.dart';
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

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
        ChangeNotifierProvider(create: (_) => NotesProvider(storageService)),
        ChangeNotifierProvider(create: (_) => TutorialsProvider(storageService)),
        ChangeNotifierProvider(
          create: (ctx) => WebServerProvider(
            webServerService,
            ctx.read<NotesProvider>(),
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
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onNavigate(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(onNavigate: _onNavigate);
      case 1:
        return const WebServerScreen();
      case 2:
        return const ScannerScreen();
      case 3:
        return const WhatsAppScreen();
      case 4:
        return const NotesScreen();
      case 5:
        return const TutorialsScreen();
      case 6:
        return const RealtimeScreen();
      case 7:
        return const FileTransferScreen();
      case 8:
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
                  backgroundColor: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
                  child: SafeArea(
                    child: ResponsiveSidebar(
                      width: double.infinity,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (idx) {
                        _onNavigate(idx);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
          backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5),
          body: Column(
            children: [
              AppHeader(
                onMenuPressed: isDesktopOrTablet
                    ? null
                    : () => _scaffoldKey.currentState?.openDrawer(),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (isDesktopOrTablet)
                      ResponsiveSidebar(
                        selectedIndex: _selectedIndex,
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
                  selectedIndex: _selectedIndex < 5 ? _selectedIndex : 0,
                  onDestinationSelected: (idx) {
                    _onNavigate(idx);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(LucideIcons.layoutDashboard),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.globe),
                      label: 'Server',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.radar),
                      label: 'Scanner',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.messageSquare),
                      label: 'WhatsApp',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.notebookPen),
                      label: 'Notes',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
