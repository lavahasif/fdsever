import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fdserver/core/models/proxy_models.dart';
import 'package:fdserver/core/services/network_service.dart';
import 'package:fdserver/core/services/proxy_server_service.dart';
import 'package:fdserver/features/proxy_server/providers/proxy_provider.dart';

void main() {
  group('ProxyServerService & Multi-Protocol Tests', () {
    late ProxyServerService proxyService;
    const testProxyPort = 18888;

    setUp(() {
      proxyService = ProxyServerService();
    });

    tearDown(() async {
      await proxyService.stopServer();
      proxyService.dispose();
    });

    test('Starts and stops proxy server on localhost', () async {
      final started = await proxyService.startServer(
        host: '127.0.0.1',
        port: testProxyPort,
      );
      expect(started, isTrue);
      expect(proxyService.isRunning, isTrue);
      expect(proxyService.port, equals(testProxyPort));

      await proxyService.stopServer();
      expect(proxyService.isRunning, isFalse);
    });

    test('Serves PAC script via HTTP GET /proxy.pac', () async {
      await proxyService.startServer(host: '127.0.0.1', port: testProxyPort);

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:$testProxyPort/proxy.pac'));
      final response = await request.close();

      expect(response.statusCode, equals(200));
      expect(response.headers.contentType?.mimeType, equals('application/x-ns-proxy-autoconfig'));

      final body = await response.transform(utf8.decoder).join();
      expect(body, contains('FindProxyForURL'));
      expect(body, contains('127.0.0.1:$testProxyPort'));
      client.close();
    });

    test('Serves Proxy Status Page via HTTP GET /', () async {
      await proxyService.startServer(host: '127.0.0.1', port: testProxyPort);

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:$testProxyPort/'));
      final response = await request.close();

      expect(response.statusCode, equals(200));
      final body = await response.transform(utf8.decoder).join();
      expect(body, contains('FDServer Super Proxy'));
      expect(body, contains('ONLINE'));
      client.close();
    });

    test('Forwards HTTP request to destination server', () async {
      // 1. Start target HTTP server
      final targetServer = await HttpServer.bind('127.0.0.1', 0);
      targetServer.listen((HttpRequest req) {
        req.response
          ..headers.contentType = ContentType.text
          ..write('Hello from Target Server!')
          ..close();
      });

      // 2. Start Proxy
      await proxyService.startServer(host: '127.0.0.1', port: testProxyPort);

      // 3. Connect to proxy with raw HTTP forward request
      final proxySocket = await Socket.connect('127.0.0.1', testProxyPort);
      final rawHttpRequest =
          'GET http://127.0.0.1:${targetServer.port}/test HTTP/1.1\r\n'
          'Host: 127.0.0.1:${targetServer.port}\r\n'
          'Connection: close\r\n\r\n';

      proxySocket.write(rawHttpRequest);
      await proxySocket.flush();

      final responseBuffer = <int>[];
      await for (final chunk in proxySocket) {
        responseBuffer.addAll(chunk);
      }
      final responseString = utf8.decode(responseBuffer);

      expect(responseString, contains('200 OK'));
      expect(responseString, contains('Hello from Target Server!'));

      await targetServer.close(force: true);
    });

    test('Handles SOCKS5 Handshake and CONNECT command (RFC 1928)', () async {
      // 1. Start target echo server
      final targetServer = await ServerSocket.bind('127.0.0.1', 0);
      targetServer.listen((client) {
        client.write('ECHO:Hello SOCKS5');
      });

      // 2. Start Proxy
      await proxyService.startServer(host: '127.0.0.1', port: testProxyPort);

      // 3. Connect to proxy and do SOCKS5 handshake
      final socket = await Socket.connect('127.0.0.1', testProxyPort);
      final receivedData = <int>[];
      final completer = Completer<String>();

      socket.listen((chunk) {
        receivedData.addAll(chunk);
        final str = utf8.decode(receivedData, allowMalformed: true);
        if (str.contains('ECHO:Hello SOCKS5') && !completer.isCompleted) {
          completer.complete(str);
        }
      });

      // Step 1: Greeting [VER=0x05, NMETHODS=1, METHOD=0x00 (No Auth)]
      socket.add([0x05, 0x01, 0x00]);
      await socket.flush();

      // Small delay to let greeting complete, then send SOCKS5 CONNECT
      await Future.delayed(const Duration(milliseconds: 50));

      final targetPort = targetServer.port;
      final portBytes = [(targetPort >> 8) & 0xFF, targetPort & 0xFF];
      socket.add([0x05, 0x01, 0x00, 0x01, 127, 0, 0, 1, ...portBytes]);
      await socket.flush();

      final text = await completer.future.timeout(const Duration(seconds: 5));
      expect(text, contains('ECHO:Hello SOCKS5'));

      await targetServer.close();
      socket.destroy();
    });

    test('Blocks domain in accordance with ProxyRule', () async {
      await proxyService.startServer(host: '127.0.0.1', port: testProxyPort);
      proxyService.setRules([
        ProxyRule(
          id: 'test_block_1',
          type: ProxyRuleType.block,
          pattern: '*.baddomain.com',
          isEnabled: true,
        ),
      ]);
      proxyService.setBlocklistEnabled(true);

      // Raw HTTP forward request to blocked domain
      final socket = await Socket.connect('127.0.0.1', testProxyPort);
      socket.write('GET http://ads.baddomain.com/banner.js HTTP/1.1\r\nHost: ads.baddomain.com\r\n\r\n');
      await socket.flush();

      final responseBuffer = <int>[];
      await for (final chunk in socket) {
        responseBuffer.addAll(chunk);
      }
      final responseString = utf8.decode(responseBuffer);
      expect(responseString, contains('403 Forbidden'));
    });
  });

  group('ProxyServerProvider Tests', () {
    test('Provider exposes network interfaces and controls server lifecycle', () async {
      final proxyService = ProxyServerService();
      final networkService = NetworkService();
      final provider = ProxyServerProvider(proxyService, networkService);

      expect(provider.isRunning, isFalse);
      expect(provider.port, equals(8888));

      provider.setPort(18889);
      expect(provider.port, equals(18889));

      await provider.searchSystemIps();
      expect(provider.systemIps, isNotEmpty);
      expect(provider.primaryIp, isNotEmpty);

      // Test helper URLs and CLI snippets
      expect(provider.proxyAddress, contains('18889'));
      expect(provider.pacUrl, contains('18889/proxy.pac'));
      expect(provider.curlCommand, contains('-x'));

      // Test start / stop
      await provider.toggleServer();
      expect(provider.isRunning, isTrue);

      await provider.toggleServer();
      expect(provider.isRunning, isFalse);

      provider.dispose();
    });
  });
}
