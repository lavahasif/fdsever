import 'package:flutter_test/flutter_test.dart';
import 'package:fdserver/core/services/network_service.dart';
import 'package:fdserver/core/services/proxy_server_service.dart';
import 'package:fdserver/core/services/reverse_proxy_service.dart';
import 'package:fdserver/core/services/vpn_diverter_service.dart';
import 'package:fdserver/features/proxy_server/providers/proxy_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VpnDiverterService Unit Tests', () {
    late VpnDiverterService diverterService;

    setUp(() {
      diverterService = VpnDiverterService();
    });

    tearDown(() {
      diverterService.dispose();
    });

    test('Initial state of VpnDiverterService is not running', () {
      expect(diverterService.isRunning, isFalse);
      expect(diverterService.bytesIn, equals(0));
      expect(diverterService.bytesOut, equals(0));
      expect(diverterService.downloadSpeedBps, equals(0));
      expect(diverterService.uploadSpeedBps, equals(0));
      expect(diverterService.targetHost, equals('192.168.43.1'));
      expect(diverterService.targetPort, equals(1080));
      expect(diverterService.targetProtocol, equals('SOCKS5'));
      expect(diverterService.bypassLan, isTrue);
      expect(diverterService.lastError, isNull);
    });

    test('DiscoveredProxy model formats labels accurately', () {
      final proxy = DiscoveredProxy(
        ip: '192.168.43.10',
        port: 1080,
        protocol: 'SOCKS5',
        latencyMs: 12,
      );
      expect(proxy.address, equals('192.168.43.10:1080'));
      expect(proxy.displayName, equals('192.168.43.10:1080 (SOCKS5 - 12ms)'));
    });
  });

  group('ProxyServerProvider Diverter State Tests', () {
    late ProxyServerProvider provider;
    late ProxyServerService proxyService;
    late NetworkService networkService;
    late ReverseProxyService reverseProxyService;
    late VpnDiverterService vpnDiverterService;

    setUp(() {
      proxyService = ProxyServerService();
      networkService = NetworkService();
      reverseProxyService = ReverseProxyService();
      vpnDiverterService = VpnDiverterService();

      provider = ProxyServerProvider(
        proxyService,
        networkService,
        reverseProxyService,
        null,
        vpnDiverterService,
      );
    });

    tearDown(() {
      provider.dispose();
      proxyService.dispose();
      reverseProxyService.dispose();
      vpnDiverterService.dispose();
    });

    test('Default diverter settings are populated correctly', () {
      expect(provider.diverterHost, equals('192.168.43.1'));
      expect(provider.diverterPort, equals(1080));
      expect(provider.diverterProtocol, equals('SOCKS5'));
      expect(provider.diverterBypassLan, isTrue);
      expect(provider.isDiverterRunning, isFalse);
      expect(provider.isScanningProxy, isFalse);
      expect(provider.diverterBytesIn, equals(0));
      expect(provider.diverterBytesOut, equals(0));
      expect(provider.diverterDownloadSpeed, equals(0));
      expect(provider.diverterUploadSpeed, equals(0));
    });

    test('Updates diverter host, port, protocol, and bypassLan', () {
      provider.setDiverterHost('192.168.43.55');
      expect(provider.diverterHost, equals('192.168.43.55'));

      provider.setDiverterPort(8080);
      expect(provider.diverterPort, equals(8080));

      provider.setDiverterProtocol('HTTP');
      expect(provider.diverterProtocol, equals('HTTP'));

      provider.setDiverterBypassLan(false);
      expect(provider.diverterBypassLan, isFalse);
    });
  });
}
