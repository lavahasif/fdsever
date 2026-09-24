import 'dart:io';
import '../models/proxy_models.dart';

class ReverseProxyService {
  HttpServer? _server;
  bool _isRunning = false;
  String _host = '0.0.0.0';
  int _port = 8080;
  DateTime? _startedAt;

  List<ReverseProxyRoute> _routes = [];
  final HttpClient _client = HttpClient();

  // Callback to feed logs into ProxyServerService / ProxyServerProvider
  void Function(ProxyLogEntry)? onLog;

  int _totalRequests = 0;
  int _totalBytesIn = 0;
  int _totalBytesOut = 0;

  bool get isRunning => _isRunning;
  String get host => _host;
  int get port => _port;
  DateTime? get startedAt => _startedAt;
  List<ReverseProxyRoute> get routes => List.unmodifiable(_routes);
  int get totalRequests => _totalRequests;
  int get totalBytesIn => _totalBytesIn;
  int get totalBytesOut => _totalBytesOut;

  void setRoutes(List<ReverseProxyRoute> routes) {
    _routes = List.from(routes);
  }

  /// Start the reverse proxy gateway
  Future<bool> startServer({
    String host = '0.0.0.0',
    int port = 8080,
  }) async {
    if (_isRunning) await stopServer();

    _host = host;
    _port = port;

    try {
      final bindAddress = (host == '0.0.0.0')
          ? InternetAddress.anyIPv4
          : (InternetAddress.tryParse(host) ?? InternetAddress.anyIPv4);

      _server = await HttpServer.bind(bindAddress, _port, shared: true);
      _isRunning = true;
      _startedAt = DateTime.now();

      _server!.listen(
        _handleRequest,
        onError: (err) {
          onLog?.call(ProxyLogEntry(
            id: 'rev_err_${DateTime.now().millisecondsSinceEpoch}',
            timestamp: DateTime.now(),
            protocol: ProxyProtocol.reverseProxy,
            method: 'ERROR',
            host: _host,
            port: _port,
            clientIp: 'system',
            statusCode: 500,
            errorMessage: err.toString(),
          ));
        },
      );

      onLog?.call(ProxyLogEntry(
        id: 'rev_start_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.reverseProxy,
        method: 'START',
        host: _host,
        port: _port,
        clientIp: '127.0.0.1',
        statusCode: 200,
        errorMessage: 'Reverse Proxy listening on $_host:$_port',
      ));

      return true;
    } catch (e) {
      _isRunning = false;
      onLog?.call(ProxyLogEntry(
        id: 'rev_start_fail_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.reverseProxy,
        method: 'ERROR',
        host: _host,
        port: _port,
        clientIp: '127.0.0.1',
        statusCode: 500,
        errorMessage: 'Failed to bind reverse proxy on $_host:$_port: $e',
      ));
      return false;
    }
  }

  /// Stop the reverse proxy server
  Future<void> stopServer() async {
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (_) {}
      _server = null;
    }
    _isRunning = false;
  }

  /// Handles incoming HTTP request and proxies to matching backend route
  void _handleRequest(HttpRequest request) async {
    final startTime = DateTime.now();
    _totalRequests++;

    final clientIp = request.connectionInfo?.remoteAddress.address ?? '127.0.0.1';
    final requestPath = request.uri.path;

    // Find best matching route (longest matching pathPrefix first)
    final activeRoutes = _routes.where((r) => r.isEnabled).toList()
      ..sort((a, b) => b.pathPrefix.length.compareTo(a.pathPrefix.length));

    ReverseProxyRoute? matchedRoute;
    for (final route in activeRoutes) {
      if (route.pathPrefix == '/' ||
          requestPath == route.pathPrefix ||
          requestPath.startsWith('${route.pathPrefix}/') ||
          requestPath.startsWith(route.pathPrefix)) {
        matchedRoute = route;
        break;
      }
    }

    if (matchedRoute == null) {
      _serveNoRoutePage(request, clientIp, startTime);
      return;
    }

    // Determine target path
    String forwardPath = requestPath;
    if (matchedRoute.stripPrefix && matchedRoute.pathPrefix != '/') {
      forwardPath = requestPath.substring(matchedRoute.pathPrefix.length);
      if (!forwardPath.startsWith('/')) {
        forwardPath = '/$forwardPath';
      }
    }

    if (request.uri.hasQuery) {
      forwardPath += '?${request.uri.query}';
    }

    final targetUri = Uri(
      scheme: 'http',
      host: matchedRoute.targetHost,
      port: matchedRoute.targetPort,
      path: forwardPath.contains('?') ? forwardPath.split('?')[0] : forwardPath,
      query: request.uri.hasQuery ? request.uri.query : null,
    );

    int bytesIn = 0;
    int bytesOut = 0;

    try {
      final backendRequest = await _client.openUrl(request.method, targetUri);

      // Copy headers from client request
      request.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        // Skip hop-by-hop headers
        if (lower == 'connection' ||
            lower == 'transfer-encoding' ||
            lower == 'keep-alive' ||
            lower == 'proxy-connection') {
          return;
        }
        for (final v in values) {
          backendRequest.headers.add(name, v);
        }
      });

      // Inject standard Reverse Proxy headers
      backendRequest.headers.set('X-Forwarded-For', clientIp);
      backendRequest.headers.set('X-Forwarded-Proto', 'http');
      backendRequest.headers.set('X-Forwarded-Host', request.headers.value('host') ?? '$_host:$_port');
      backendRequest.headers.set('X-Real-IP', clientIp);

      // Stream request body from client to backend
      await for (final chunk in request) {
        bytesIn += chunk.length;
        backendRequest.add(chunk);
      }
      _totalBytesIn += bytesIn;

      final backendResponse = await backendRequest.close();

      // Copy backend response status and headers to client response
      request.response.statusCode = backendResponse.statusCode;
      backendResponse.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower == 'transfer-encoding' || lower == 'connection') return;
        for (final v in values) {
          request.response.headers.add(name, v);
        }
      });

      // Stream backend response body to client
      await for (final chunk in backendResponse) {
        bytesOut += chunk.length;
        request.response.add(chunk);
      }
      _totalBytesOut += bytesOut;

      await request.response.close();

      final duration = DateTime.now().difference(startTime).inMilliseconds;

      onLog?.call(ProxyLogEntry(
        id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.reverseProxy,
        method: request.method,
        host: '${matchedRoute.targetHost}:${matchedRoute.targetPort}',
        port: matchedRoute.targetPort,
        path: requestPath,
        clientIp: clientIp,
        statusCode: backendResponse.statusCode,
        bytesSent: bytesIn,
        bytesReceived: bytesOut,
        durationMs: duration,
        isRewritten: matchedRoute.stripPrefix,
      ));
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.badGateway;
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!DOCTYPE html>
<html>
<head><title>502 Bad Gateway - FDServer Reverse Proxy</title></head>
<body style="background:#09090b;color:#f4f4f5;font-family:sans-serif;padding:2rem;">
  <h1 style="color:#ef4444;">502 Bad Gateway</h1>
  <p>FDServer Reverse Proxy could not connect to backend server at <code>${matchedRoute.targetHost}:${matchedRoute.targetPort}</code>.</p>
  <p><strong>Error:</strong> $e</p>
  <p>Please verify that the target service (e.g. Odoo on port 8069) is running and accessible.</p>
</body>
</html>
''');
        await request.response.close();
      } catch (_) {}

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      onLog?.call(ProxyLogEntry(
        id: 'rev_err_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.reverseProxy,
        method: request.method,
        host: '${matchedRoute.targetHost}:${matchedRoute.targetPort}',
        port: matchedRoute.targetPort,
        path: requestPath,
        clientIp: clientIp,
        statusCode: 502,
        errorMessage: 'Connection to backend failed: $e',
        durationMs: duration,
      ));
    }
  }

  void _serveNoRoutePage(HttpRequest request, String clientIp, DateTime startTime) async {
    request.response.statusCode = HttpStatus.notFound;
    request.response.headers.contentType = ContentType.html;

    final routesHtml = _routes.isEmpty
        ? '<li><em>No backend routes configured yet. Add routes in FDServer.</em></li>'
        : _routes.map((r) {
            return '<li><code>${r.pathPrefix}</code> &rarr; <code>${r.targetHost}:${r.targetPort}</code> ${r.isEnabled ? "(Active)" : "(Disabled)"}</li>';
          }).join();

    request.response.write('''
<!DOCTYPE html>
<html>
<head><title>404 Not Found - FDServer Reverse Proxy</title></head>
<body style="background:#09090b;color:#f4f4f5;font-family:sans-serif;padding:2rem;">
  <h1 style="color:#f59e0b;">FDServer Reverse Proxy Gateway</h1>
  <p>No active backend route matched request path: <code>${request.uri.path}</code></p>
  <h3>Configured Routes:</h3>
  <ul>$routesHtml</ul>
</body>
</html>
''');
    await request.response.close();

    onLog?.call(ProxyLogEntry(
      id: 'rev_404_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      protocol: ProxyProtocol.reverseProxy,
      method: request.method,
      host: _host,
      port: _port,
      path: request.uri.path,
      clientIp: clientIp,
      statusCode: 404,
      durationMs: DateTime.now().difference(startTime).inMilliseconds,
    ));
  }

  /// Probes all backend routes via TCP to check whether each target host:port is currently listening
  Future<Map<String, bool>> checkRoutesHealth() async {
    final Map<String, bool> results = {};
    for (final route in _routes) {
      Socket? socket;
      try {
        socket = await Socket.connect(
          route.targetHost,
          route.targetPort,
          timeout: const Duration(milliseconds: 1200),
        );
        results[route.id] = true;
      } catch (_) {
        results[route.id] = false;
      } finally {
        try {
          socket?.destroy();
        } catch (_) {}
      }
    }
    return results;
  }

  void dispose() {
    stopServer();
    _client.close();
  }
}
