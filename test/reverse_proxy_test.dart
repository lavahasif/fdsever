import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fdserver/core/models/proxy_models.dart';
import 'package:fdserver/core/services/network_service.dart';
import 'package:fdserver/core/services/proxy_server_service.dart';
import 'package:fdserver/core/services/reverse_proxy_service.dart';
import 'package:fdserver/features/proxy_server/providers/proxy_provider.dart';

void main() {
  group('ReverseProxyService Tests', () {
    late ReverseProxyService reverseProxy;
    late HttpServer mockBackend;
    const reverseProxyPort = 19080;
    const backendPort = 19081;

    setUp(() async {
      reverseProxy = ReverseProxyService();
      // Start a mock backend HTTP server
      mockBackend = await HttpServer.bind(InternetAddress.loopbackIPv4, backendPort);
      mockBackend.listen((HttpRequest req) {
        if (req.uri.path == '/api/hello') {
          req.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'message': 'Hello from Backend',
              'forwarded_for': req.headers.value('x-forwarded-for'),
              'forwarded_host': req.headers.value('x-forwarded-host'),
              'forwarded_proto': req.headers.value('x-forwarded-proto'),
              'real_ip': req.headers.value('x-real-ip'),
              'received_path': req.uri.path,
            }))
            ..close();
        } else if (req.uri.path == '/prefix/test') {
          req.response
            ..statusCode = HttpStatus.ok
            ..write('with-prefix')
            ..close();
        } else if (req.uri.path == '/test') {
          req.response
            ..statusCode = HttpStatus.ok
            ..write('stripped-prefix')
            ..close();
        } else {
          req.response
            ..statusCode = HttpStatus.notFound
            ..write('Backend 404 for ${req.uri.path}')
            ..close();
        }
      });
    });

    tearDown(() async {
      await reverseProxy.stopServer();
      reverseProxy.dispose();
      await mockBackend.close(force: true);
    });

    test('Starts and stops ReverseProxyService on loopback', () async {
      final started = await reverseProxy.startServer(
        host: '127.0.0.1',
        port: reverseProxyPort,
      );
      expect(started, isTrue);
      expect(reverseProxy.isRunning, isTrue);
      expect(reverseProxy.port, equals(reverseProxyPort));

      await reverseProxy.stopServer();
      expect(reverseProxy.isRunning, isFalse);
    });

    test('Forwards HTTP request to matching backend route and injects headers', () async {
      const route = ReverseProxyRoute(
        id: 'test-api',
        name: 'Test API',
        pathPrefix: '/api',
        targetHost: '127.0.0.1',
        targetPort: backendPort,
        stripPrefix: false,
      );

      reverseProxy.setRoutes([route]);
      await reverseProxy.startServer(host: '127.0.0.1', port: reverseProxyPort);

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$reverseProxyPort/api/hello'),
      );
      final response = await request.close();

      expect(response.statusCode, equals(HttpStatus.ok));
      final bodyStr = await response.transform(utf8.decoder).join();
      final data = jsonDecode(bodyStr) as Map<String, dynamic>;

      expect(data['message'], equals('Hello from Backend'));
      expect(data['forwarded_for'], equals('127.0.0.1'));
      expect(data['forwarded_proto'], equals('http'));
      expect(data['real_ip'], equals('127.0.0.1'));
      expect(data['received_path'], equals('/api/hello'));
      client.close();
    });

    test('Strips path prefix when stripPrefix is true', () async {
      const route = ReverseProxyRoute(
        id: 'stripped-route',
        name: 'Stripped Route',
        pathPrefix: '/prefix',
        targetHost: '127.0.0.1',
        targetPort: backendPort,
        stripPrefix: true,
      );

      reverseProxy.setRoutes([route]);
      await reverseProxy.startServer(host: '127.0.0.1', port: reverseProxyPort);

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$reverseProxyPort/prefix/test'),
      );
      final response = await request.close();

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.transform(utf8.decoder).join();
      expect(body, equals('stripped-prefix'));
      client.close();
    });

    test('Returns 502 Bad Gateway when backend is unreachable', () async {
      const unreachableRoute = ReverseProxyRoute(
        id: 'dead-route',
        name: 'Dead Backend',
        pathPrefix: '/dead',
        targetHost: '127.0.0.1',
        targetPort: 39999, // Nothing running here
      );

      reverseProxy.setRoutes([unreachableRoute]);
      await reverseProxy.startServer(host: '127.0.0.1', port: reverseProxyPort);

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$reverseProxyPort/dead/something'),
      );
      final response = await request.close();

      expect(response.statusCode, equals(HttpStatus.badGateway));
      final body = await response.transform(utf8.decoder).join();
      expect(body, contains('502 Bad Gateway'));
      client.close();
    });

    test('Returns 404 with HTML gateway status when no route matches', () async {
      reverseProxy.setRoutes([]);
      await reverseProxy.startServer(host: '127.0.0.1', port: reverseProxyPort);

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$reverseProxyPort/unmatched'),
      );
      final response = await request.close();

      expect(response.statusCode, equals(HttpStatus.notFound));
      final body = await response.transform(utf8.decoder).join();
      expect(body, contains('FDServer Reverse Proxy'));
      client.close();
    });

    test('Performs TCP health check on routes', () async {
      const healthyRoute = ReverseProxyRoute(
        id: 'h1',
        name: 'Healthy Backend',
        pathPrefix: '/good',
        targetHost: '127.0.0.1',
        targetPort: backendPort,
      );

      const deadRoute = ReverseProxyRoute(
        id: 'h2',
        name: 'Dead Backend',
        pathPrefix: '/dead',
        targetHost: '127.0.0.1',
        targetPort: 39998,
      );

      reverseProxy.setRoutes([healthyRoute, deadRoute]);
      final healthMap = await reverseProxy.checkRoutesHealth();

      expect(healthMap.length, equals(2));
      expect(healthMap['h1'], isTrue);
      expect(healthMap['h2'], isFalse);
    });
  });

  group('ProxyServerProvider Integration with Reverse Proxy', () {
    late ProxyServerService forwardProxy;
    late ReverseProxyService reverseProxy;
    late NetworkService networkService;
    late ProxyServerProvider provider;

    setUp(() {
      forwardProxy = ProxyServerService();
      reverseProxy = ReverseProxyService();
      networkService = NetworkService();
      provider = ProxyServerProvider(
        forwardProxy,
        networkService,
        reverseProxy,
      );
    });

    tearDown(() async {
      await provider.stopReverseProxy();
      await provider.stopServer();
      provider.dispose();
      forwardProxy.dispose();
      reverseProxy.dispose();
    });

    test('Adds and removes reverse proxy routes via provider', () {
      final initialCount = provider.reverseProxyRoutes.length;
      
      const newRoute = ReverseProxyRoute(
        id: 'route_custom_test',
        name: 'Odoo ERP Direct',
        pathPrefix: '/odoo-test',
        targetHost: '127.0.0.1',
        targetPort: 8069,
      );

      provider.addReverseProxyRoute(newRoute);
      expect(provider.reverseProxyRoutes.length, equals(initialCount + 1));
      expect(provider.reverseProxyRoutes.any((r) => r.pathPrefix == '/odoo-test'), isTrue);

      provider.removeReverseProxyRoute(newRoute.id);
      expect(provider.reverseProxyRoutes.length, equals(initialCount));
    });

    test('Loads Odoo preset route seamlessly', () {
      provider.loadOdooPresetRoute();
      final odooRoute = provider.reverseProxyRoutes.firstWhere((r) => r.pathPrefix == '/odoo');
      expect(odooRoute.targetPort, equals(8069));
      expect(odooRoute.targetHost, equals('127.0.0.1'));
    });
  });
}
