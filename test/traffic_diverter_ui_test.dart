import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fdserver/core/services/apk_install_service.dart';
import 'package:fdserver/core/services/crash_log_service.dart';
import 'package:fdserver/core/services/file_transfer_service.dart';
import 'package:fdserver/core/services/network_service.dart';
import 'package:fdserver/core/services/power_service.dart';
import 'package:fdserver/core/services/proxy_server_service.dart';
import 'package:fdserver/core/services/reverse_proxy_service.dart';
import 'package:fdserver/core/services/socket_service.dart';
import 'package:fdserver/core/services/storage_service.dart';
import 'package:fdserver/core/services/vpn_diverter_service.dart';
import 'package:fdserver/core/services/web_server_service.dart';
import 'package:fdserver/core/services/whatsapp_service.dart';
import 'package:fdserver/core/theme/app_theme.dart';
import 'package:fdserver/features/apk_installer/providers/apk_installer_provider.dart';
import 'package:fdserver/features/file_transfer/providers/file_transfer_provider.dart';
import 'package:fdserver/features/network_scanner/providers/scanner_provider.dart';
import 'package:fdserver/features/notes/providers/notes_provider.dart';
import 'package:fdserver/features/proxy_server/providers/proxy_provider.dart';
import 'package:fdserver/features/realtime/providers/realtime_provider.dart';
import 'package:fdserver/features/settings/providers/settings_provider.dart';
import 'package:fdserver/features/tutorials/providers/tutorials_provider.dart';
import 'package:fdserver/features/web_server/providers/web_server_provider.dart';
import 'package:fdserver/features/whatsapp/providers/whatsapp_provider.dart';
import 'package:fdserver/features/auto_trail/providers/auto_trail_provider.dart';
import 'package:fdserver/features/focus_guard/providers/focus_guard_provider.dart';
import 'package:fdserver/main.dart';

Widget createMobileTestApp({
  required StorageService storageService,
  Widget? home,
  ProxyServerProvider? customProxyProvider,
}) {
  final networkService = NetworkService();
  final webServerService = WebServerService();
  final whatsappService = WhatsAppService();
  final socketService = SocketService();
  final fileTransferService = FileTransferService();
  final apkInstallService = ApkInstallService();
  final proxyServerService = ProxyServerService();
  final reverseProxyService = ReverseProxyService();
  final powerService = PowerService();
  final vpnDiverterService = VpnDiverterService();
  final crashLogService = CrashLogService();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CrashLogService>.value(value: crashLogService),
      Provider<StorageService>.value(value: storageService),
      Provider<ApkInstallService>.value(value: apkInstallService),
      Provider<PowerService>.value(value: powerService),
      Provider<VpnDiverterService>.value(value: vpnDiverterService),
      ChangeNotifierProvider(create: (_) => SettingsProvider(storageService, powerService)),
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
        create: (_) => ApkInstallerProvider(apkInstallService, networkService, powerService),
      ),
      if (customProxyProvider != null)
        ChangeNotifierProvider<ProxyServerProvider>.value(value: customProxyProvider)
      else
        ChangeNotifierProvider(
          create: (_) => ProxyServerProvider(
            proxyServerService,
            networkService,
            reverseProxyService,
            powerService,
            vpnDiverterService,
          ),
        ),
      ChangeNotifierProvider(create: (_) => AutoTrailProvider()),
      ChangeNotifierProvider(create: (_) => FocusGuardProvider()),
    ],
    child: ShadApp(
      title: 'FDServer UI Test',
      theme: AppTheme.lightTheme(),
      builder: (context, child) {
        return ScaffoldMessenger(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home ?? const MainNavigationShell(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'diverter_host': '192.168.43.1',
      'diverter_port': 1080,
      'diverter_protocol': 'SOCKS5',
      'diverter_bypass_lan': true,
      'diverter_use_vpn': true,
    });
  });

  group('Mobile Bottom Navigation - Traffic Diverter UI Tests', () {
    testWidgets('Renders bottom navigation bar with Diverter tab on mobile screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await StorageService.init();
      await tester.pumpWidget(createMobileTestApp(storageService: storage));
      await tester.pumpAndSettle();

      // Verify Bottom Navigation Bar is present
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verify all 6 tabs exist
      expect(find.byKey(const Key('bottom_nav_hub')), findsOneWidget);
      expect(find.byKey(const Key('bottom_nav_diverter')), findsOneWidget);
      expect(find.byKey(const Key('bottom_nav_server')), findsOneWidget);
      expect(find.byKey(const Key('bottom_nav_transfer')), findsOneWidget);
      expect(find.byKey(const Key('bottom_nav_workspace')), findsOneWidget);
      expect(find.byKey(const Key('bottom_nav_settings')), findsOneWidget);

      // Verify labels
      expect(find.text('Hub'), findsOneWidget);
      expect(find.text('Diverter'), findsOneWidget);
      expect(find.text('Server'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Workspace'), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('Tapping Diverter tab opens Traffic Diverter screen immediately',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await StorageService.init();
      await tester.pumpWidget(createMobileTestApp(storageService: storage));
      await tester.pumpAndSettle();

      // Tap Diverter tab in bottom nav
      await tester.tap(find.byKey(const Key('bottom_nav_diverter')));
      await tester.pumpAndSettle();

      // Verify Traffic Diverter screen content is displayed
      expect(find.text('Traffic Diverter (Super Proxy Client)'), findsOneWidget);
      expect(find.text('Hotspot 1-Click Auto-Connect'), findsOneWidget);
      expect(find.text('Target Proxy Configuration'), findsOneWidget);
      expect(find.byKey(const Key('diverter_scan_button')), findsOneWidget);
      expect(find.byKey(const Key('diverter_vpn_switch')), findsOneWidget);
      expect(find.byKey(const Key('diverter_host_input')), findsOneWidget);
      expect(find.byKey(const Key('diverter_port_input')), findsOneWidget);

      // Drain any background network health check timers
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Traffic Diverter allows updating Target IP and Port',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await StorageService.init();
      await tester.pumpWidget(createMobileTestApp(storageService: storage));
      await tester.pumpAndSettle();

      // Navigate to Diverter
      await tester.tap(find.byKey(const Key('bottom_nav_diverter')));
      await tester.pumpAndSettle();

      // Ensure host input is visible
      final hostFinder = find.byKey(const Key('diverter_host_input'));
      await tester.ensureVisible(hostFinder);
      await tester.pumpAndSettle();

      expect(hostFinder, findsOneWidget);
      await tester.enterText(hostFinder, '10.225.138.58');
      await tester.pumpAndSettle();

      // Ensure port input is visible
      final portFinder = find.byKey(const Key('diverter_port_input'));
      await tester.ensureVisible(portFinder);
      await tester.pumpAndSettle();

      expect(portFinder, findsOneWidget);
      await tester.enterText(portFinder, '1080');
      await tester.pumpAndSettle();

      // Verify the target proxy display in Hero card reflects updated host and port
      expect(find.textContaining('10.225.138.58:1080'), findsWidgets);

      // Drain timers
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Tapping SOCKS5 quick chip applies port and protocol',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await StorageService.init();
      await tester.pumpWidget(createMobileTestApp(storageService: storage));
      await tester.pumpAndSettle();

      // Navigate to Diverter
      await tester.tap(find.byKey(const Key('bottom_nav_diverter')));
      await tester.pumpAndSettle();

      // Ensure shortcut chip is visible
      final chipFinder = find.text('SOCKS5 (1080)');
      await tester.ensureVisible(chipFinder);
      await tester.pumpAndSettle();

      // Tap SOCKS5 chip
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Verify Hero text contains SOCKS5
      expect(find.textContaining('(SOCKS5)'), findsWidgets);

      // Drain timers
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Toggling Android VPN Tunnel switch updates state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await StorageService.init();
      await tester.pumpWidget(createMobileTestApp(storageService: storage));
      await tester.pumpAndSettle();

      // Navigate to Diverter
      await tester.tap(find.byKey(const Key('bottom_nav_diverter')));
      await tester.pumpAndSettle();

      // Ensure switch is visible
      final switchFinder = find.byKey(const Key('diverter_vpn_switch'));
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();

      // Initially VPN is ON
      expect(find.text('VPN ON'), findsOneWidget);

      // Toggle switch to OFF
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Should now show VPN OFF (Wi-Fi Proxy)
      expect(find.text('VPN OFF (Wi-Fi Proxy)'), findsOneWidget);

      // Toggle switch back to ON
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(find.text('VPN ON'), findsOneWidget);

      // Drain timers
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Seamless switching between Bottom Nav tabs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await StorageService.init();
      await tester.pumpWidget(createMobileTestApp(storageService: storage));
      await tester.pumpAndSettle();

      // Start at Hub
      expect(find.text('FDServer Network & Server Center'), findsOneWidget);

      // Tap Diverter
      await tester.tap(find.byKey(const Key('bottom_nav_diverter')));
      await tester.pumpAndSettle();
      expect(find.text('Traffic Diverter (Super Proxy Client)'), findsOneWidget);

      // Tap Server
      await tester.tap(find.byKey(const Key('bottom_nav_server')));
      await tester.pumpAndSettle();
      expect(find.text('Local Web Server'), findsOneWidget);

      // Tap Transfer
      await tester.tap(find.byKey(const Key('bottom_nav_transfer')));
      await tester.pumpAndSettle();
      expect(find.text('File Transfer & Remote Uploader'), findsOneWidget);

      // Tap Workspace
      await tester.tap(find.byKey(const Key('bottom_nav_workspace')));
      await tester.pumpAndSettle();
      expect(find.text('Notes & Knowledge Base'), findsOneWidget);

      // Tap Settings
      await tester.tap(find.byKey(const Key('bottom_nav_settings')));
      await tester.pumpAndSettle();
      expect(find.text('Application Settings'), findsOneWidget);

      // Tap back to Diverter
      await tester.tap(find.byKey(const Key('bottom_nav_diverter')));
      await tester.pumpAndSettle();
      expect(find.text('Traffic Diverter (Super Proxy Client)'), findsOneWidget);

      // Drain timers
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Switching between Mobile Hotspot and Wi-Fi LAN modes updates UI state and guidance',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await StorageService.init();
      await tester.pumpWidget(createMobileTestApp(storageService: storage));
      await tester.pumpAndSettle();

      // Navigate to Diverter
      await tester.tap(find.byKey(const Key('bottom_nav_diverter')));
      await tester.pumpAndSettle();

      // Verify Network Connection Mode section is present
      expect(find.text('Network Connection Mode'), findsOneWidget);
      expect(find.byKey(const Key('mode_hotspot_button')), findsOneWidget);
      expect(find.byKey(const Key('mode_wifi_button')), findsOneWidget);

      // Initially in Hotspot Mode
      expect(find.text('Hotspot 1-Click Auto-Connect'), findsOneWidget);

      // Switch to Wi-Fi LAN Mode
      await tester.tap(find.byKey(const Key('mode_wifi_button')));
      await tester.pumpAndSettle();

      // Verify Auto-Discovery and guidance adapt to Wi-Fi Mode
      expect(find.text('Wi-Fi 1-Click Auto-Connect'), findsOneWidget);
      expect(find.text('How Wi-Fi Proxy Diversion Works'), findsOneWidget);

      // Switch back to Mobile Hotspot Mode
      await tester.tap(find.byKey(const Key('mode_hotspot_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hotspot 1-Click Auto-Connect'), findsOneWidget);
      expect(find.text('How Hotspot Proxy Diversion Works'), findsOneWidget);

      // Drain timers
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
