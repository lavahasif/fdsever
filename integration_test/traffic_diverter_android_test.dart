import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fdserver/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FDServer Android Live UI Integration Test', () {
    testWidgets('Verify Bottom Nav Diverter tab & live interaction on device',
        (WidgetTester tester) async {
      // Launch the full app on the real Android device
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 1. Verify App launched and Bottom Navigation Bar is visible
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('bottom_nav_diverter')), findsOneWidget);
      expect(find.byKey(const Key('bottom_nav_hub')), findsOneWidget);
      expect(find.byKey(const Key('bottom_nav_server')), findsOneWidget);

      // 2. Tap Diverter tab on the bottom navigation bar
      await tester.tap(find.byKey(const Key('bottom_nav_diverter')));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // 3. Verify Traffic Diverter screen loaded
      expect(find.text('Traffic Diverter (Super Proxy Client)'), findsOneWidget);
      expect(find.text('Target Proxy Configuration'), findsOneWidget);

      // 4. Test Target IP input
      final hostFinder = find.byKey(const Key('diverter_host_input'));
      await tester.ensureVisible(hostFinder);
      await tester.enterText(hostFinder, '10.225.138.58');
      await tester.pumpAndSettle();

      // 5. Test Target Port input
      final portFinder = find.byKey(const Key('diverter_port_input'));
      await tester.ensureVisible(portFinder);
      await tester.enterText(portFinder, '1080');
      await tester.pumpAndSettle();

      // Verify Target text in Hero card was updated
      expect(find.textContaining('10.225.138.58:1080'), findsWidgets);

      // 6. Test SOCKS5 Shortcut Preset
      final socksChip = find.text('SOCKS5 (1080)');
      await tester.ensureVisible(socksChip);
      await tester.tap(socksChip);
      await tester.pumpAndSettle();
      expect(find.textContaining('(SOCKS5)'), findsWidgets);

      // 7. Test VPN switch toggle
      final vpnSwitch = find.byKey(const Key('diverter_vpn_switch'));
      await tester.ensureVisible(vpnSwitch);
      await tester.tap(vpnSwitch);
      await tester.pumpAndSettle();
      expect(find.text('VPN OFF (Wi-Fi Proxy)'), findsOneWidget);

      // Toggle back to VPN ON
      await tester.tap(vpnSwitch);
      await tester.pumpAndSettle();
      expect(find.text('VPN ON'), findsOneWidget);

      // 8. Test Navigation back to Hub and Server
      await tester.tap(find.byKey(const Key('bottom_nav_hub')));
      await tester.pumpAndSettle();
      expect(find.text('FDServer Network & Server Center'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bottom_nav_server')));
      await tester.pumpAndSettle();
      expect(find.text('Local Web Server'), findsOneWidget);

      // Return to Diverter
      await tester.tap(find.byKey(const Key('bottom_nav_diverter')));
      await tester.pumpAndSettle();
      expect(find.text('Traffic Diverter (Super Proxy Client)'), findsOneWidget);
    });
  });
}
