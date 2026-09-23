import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fdserver/core/services/apk_install_service.dart';
import 'package:fdserver/core/services/file_transfer_service.dart';
import 'package:fdserver/core/services/network_service.dart';
import 'package:fdserver/core/services/proxy_server_service.dart';
import 'package:fdserver/core/services/socket_service.dart';
import 'package:fdserver/core/services/storage_service.dart';
import 'package:fdserver/core/services/web_server_service.dart';
import 'package:fdserver/core/services/whatsapp_service.dart';
import 'package:fdserver/core/theme/app_theme.dart';
import 'package:fdserver/features/apk_installer/providers/apk_installer_provider.dart';
import 'package:fdserver/features/file_transfer/providers/file_transfer_provider.dart';
import 'package:fdserver/features/network_scanner/providers/scanner_provider.dart';
import 'package:fdserver/features/notes/providers/notes_provider.dart';
import 'package:fdserver/features/notes/screens/notes_screen.dart';
import 'package:fdserver/features/proxy_server/providers/proxy_provider.dart';
import 'package:fdserver/features/realtime/providers/realtime_provider.dart';
import 'package:fdserver/features/settings/providers/settings_provider.dart';
import 'package:fdserver/features/tutorials/providers/tutorials_provider.dart';
import 'package:fdserver/features/web_server/providers/web_server_provider.dart';
import 'package:fdserver/features/whatsapp/providers/whatsapp_provider.dart';
import 'package:fdserver/features/whatsapp/screens/whatsapp_screen.dart';
import 'package:fdserver/shared/widgets/responsive_sidebar.dart';
import 'package:fdserver/shared/widgets/app_header.dart';
import 'package:fdserver/main.dart';

Widget createTestApp({
  required StorageService storageService,
  Widget? home,
}) {
  final networkService = NetworkService();
  final webServerService = WebServerService();
  final whatsappService = WhatsAppService();
  final socketService = SocketService();
  final fileTransferService = FileTransferService();
  final apkInstallService = ApkInstallService();
  final proxyServerService = ProxyServerService();

  return MultiProvider(
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
      ChangeNotifierProvider(
        create: (_) => ProxyServerProvider(proxyServerService, networkService, storageService),
      ),
    ],
    child: ShadApp(
      title: 'FDServer Test',
      theme: AppTheme.lightTheme(),
      home: home ?? const MainNavigationShell(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'fav_port': '8081',
      'fav_ip': '127.0.0.1',
      'whatsapp_message': 'Test hello',
    });
  });

  testWidgets('App launches and renders MainNavigationShell and AppHeader',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final storage = await StorageService.init();
    await tester.pumpWidget(createTestApp(storageService: storage));
    await tester.pumpAndSettle();

    // Verify App Header branding
    expect(find.text('FDServer'), findsWidgets);
    expect(
      find.descendant(of: find.byType(AppHeader), matching: find.text('Offline')),
      findsOneWidget,
    );

    // Verify Dashboard screen components
    expect(find.text('FDServer Network & Server Center'), findsOneWidget);
    expect(find.text('Quick Access Tools'), findsOneWidget);
    expect(find.text('Port Scanner'), findsWidgets);
    expect(find.text('WhatsApp Direct'), findsWidgets);
  });

  testWidgets('Sidebar navigation switches views',
      (WidgetTester tester) async {
    // Set large surface size for desktop sidebar
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final storage = await StorageService.init();
    await tester.pumpWidget(createTestApp(storageService: storage));
    await tester.pumpAndSettle();

    // Tap 'Web Server' in sidebar
    await tester.tap(find.descendant(
      of: find.byType(ResponsiveSidebar),
      matching: find.text('Web Server'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Local Web Server'), findsOneWidget);
    expect(find.text('Available Server Routes'), findsOneWidget);

    // Tap 'Port Scanner' in sidebar
    await tester.tap(find.descendant(
      of: find.byType(ResponsiveSidebar),
      matching: find.text('Port Scanner'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Network & Port Scanner'), findsOneWidget);
    expect(find.text('Probe Target'), findsWidgets);

    // Tap 'WhatsApp Direct' in sidebar
    await tester.tap(find.descendant(
      of: find.byType(ResponsiveSidebar),
      matching: find.text('WhatsApp Direct'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Compose Direct Message'), findsOneWidget);

    // Tap 'Notes & KB' in sidebar
    await tester.tap(find.descendant(
      of: find.byType(ResponsiveSidebar),
      matching: find.text('Notes & KB'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Notes & Knowledge Base'), findsOneWidget);
  });

  testWidgets('Notes management screen renders and allows adding note',
      (WidgetTester tester) async {
    final storage = await StorageService.init();
    await tester.pumpWidget(
      createTestApp(
        storageService: storage,
        home: const Scaffold(body: NotesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notes & Knowledge Base'), findsOneWidget);
    expect(find.text('Add Note'), findsOneWidget);

    // Open add note dialog
    await tester.tap(find.text('Add Note'));
    await tester.pumpAndSettle();

    expect(find.text('Register New Note'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Register New Note'), findsNothing);
  });

  testWidgets('WhatsApp direct message screen renders inputs and actions',
      (WidgetTester tester) async {
    final storage = await StorageService.init();
    await tester.pumpWidget(
      createTestApp(
        storageService: storage,
        home: const Scaffold(body: WhatsAppScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp Direct Message'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsOneWidget);
    expect(find.text('+91 (IN)'), findsOneWidget);

    // Tap +91 (IN) country code chip
    await tester.tap(find.text('+91 (IN)'));
    await tester.pumpAndSettle();

    // Verify country code was added
    expect(find.text('91'), findsWidgets);
  });
}
