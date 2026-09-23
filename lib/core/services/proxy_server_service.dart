import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/proxy_models.dart';

class ProxyServerService {
  ServerSocket? _serverSocket;
  bool _isRunning = false;
  String _host = '0.0.0.0';
  int _port = 8888;
  DateTime? _startedAt;

  // Configuration
  ProxyAuth _auth = const ProxyAuth();
  UpstreamProxy _upstream = const UpstreamProxy();
  ThrottleProfile _throttle = const ThrottleProfile();
  List<ProxyRule> _rules = [];
  bool _isBlocklistEnabled = true;

  // Stream controller for real-time logs
  final StreamController<ProxyLogEntry> _logsController = StreamController<ProxyLogEntry>.broadcast();
  final List<ProxyLogEntry> _recentLogs = [];

  // Metrics
  int _totalRequests = 0;
  int _httpRequests = 0;
  int _httpsRequests = 0;
  int _socks5Requests = 0;
  int _pacRequests = 0;
  int _blockedRequests = 0;
  int _activeConnections = 0;
  int _totalBytesIn = 0;
  int _totalBytesOut = 0;

  // Speed calculation
  Timer? _speedTimer;
  int _bytesInLastSec = 0;
  int _bytesOutLastSec = 0;
  double _currentSpeedInKbps = 0.0;
  double _currentSpeedOutKbps = 0.0;

  // Getters
  bool get isRunning => _isRunning;
  String get host => _host;
  int get port => _port;
  DateTime? get startedAt => _startedAt;
  Stream<ProxyLogEntry> get logsStream => _logsController.stream;
  List<ProxyLogEntry> get recentLogs => List.unmodifiable(_recentLogs);

  ProxyAuth get auth => _auth;
  UpstreamProxy get upstream => _upstream;
  ThrottleProfile get throttle => _throttle;
  List<ProxyRule> get rules => List.unmodifiable(_rules);
  bool get isBlocklistEnabled => _isBlocklistEnabled;

  ProxyStats get stats => ProxyStats(
        totalRequests: _totalRequests,
        httpRequests: _httpRequests,
        httpsRequests: _httpsRequests,
        socks5Requests: _socks5Requests,
        pacRequests: _pacRequests,
        blockedRequests: _blockedRequests,
        activeConnections: _activeConnections,
        totalBytesIn: _totalBytesIn,
        totalBytesOut: _totalBytesOut,
        currentSpeedInKbps: _currentSpeedInKbps,
        currentSpeedOutKbps: _currentSpeedOutKbps,
        startedAt: _startedAt,
      );

  void setAuth(ProxyAuth auth) => _auth = auth;
  void setUpstream(UpstreamProxy upstream) => _upstream = upstream;
  void setThrottle(ThrottleProfile throttle) => _throttle = throttle;
  void setRules(List<ProxyRule> rules) => _rules = List.from(rules);
  void setBlocklistEnabled(bool enabled) => _isBlocklistEnabled = enabled;

  void clearLogs() {
    _recentLogs.clear();
  }

  void _recordBytes(int bytesIn, int bytesOut) {
    _totalBytesIn += bytesIn;
    _totalBytesOut += bytesOut;
    _bytesInLastSec += bytesIn;
    _bytesOutLastSec += bytesOut;
  }

  void _addLog(ProxyLogEntry entry) {
    _totalRequests++;
    switch (entry.protocol) {
      case ProxyProtocol.http:
        _httpRequests++;
        break;
      case ProxyProtocol.httpsConnect:
        _httpsRequests++;
        break;
      case ProxyProtocol.socks5:
        _socks5Requests++;
        break;
      case ProxyProtocol.pac:
        _pacRequests++;
        break;
    }
    if (entry.isBlocked) {
      _blockedRequests++;
    }

    _recentLogs.insert(0, entry);
    if (_recentLogs.length > 200) {
      _recentLogs.removeLast();
    }
    _logsController.add(entry);
  }

  /// Start the multi-protocol proxy server
  Future<bool> startServer({
    String host = '0.0.0.0',
    int port = 8888,
  }) async {
    if (_isRunning) await stopServer();

    _host = host;
    _port = port;

    try {
      final bindAddress = (host == '0.0.0.0')
          ? InternetAddress.anyIPv4
          : (InternetAddress.tryParse(host) ?? InternetAddress.anyIPv4);

      _serverSocket = await ServerSocket.bind(bindAddress, _port, shared: true);
      _isRunning = true;
      _startedAt = DateTime.now();

      _speedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _currentSpeedInKbps = (_bytesInLastSec * 8) / 1000.0;
        _currentSpeedOutKbps = (_bytesOutLastSec * 8) / 1000.0;
        _bytesInLastSec = 0;
        _bytesOutLastSec = 0;
      });

      _serverSocket!.listen(
        _handleClientConnection,
        onError: (err) {
          _addLog(ProxyLogEntry(
            id: 'err_${DateTime.now().millisecondsSinceEpoch}',
            timestamp: DateTime.now(),
            protocol: ProxyProtocol.http,
            method: 'ERROR',
            host: _host,
            port: _port,
            clientIp: 'system',
            errorMessage: err.toString(),
          ));
        },
        onDone: () {
          _isRunning = false;
        },
      );

      _addLog(ProxyLogEntry(
        id: 'start_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.http,
        method: 'START',
        host: _host,
        port: _port,
        clientIp: '127.0.0.1',
        statusCode: 200,
        errorMessage: 'Proxy server listening on $_host:$_port (HTTP, HTTPS CONNECT, SOCKS5, PAC)',
      ));

      return true;
    } catch (e) {
      _isRunning = false;
      _addLog(ProxyLogEntry(
        id: 'start_failed_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.http,
        method: 'ERROR',
        host: _host,
        port: _port,
        clientIp: '127.0.0.1',
        statusCode: 500,
        errorMessage: 'Failed to bind proxy on $_host:$_port: $e',
      ));
      return false;
    }
  }

  /// Stop the proxy server
  Future<void> stopServer() async {
    _speedTimer?.cancel();
    _speedTimer = null;
    if (_serverSocket != null) {
      try {
        await _serverSocket!.close();
      } catch (_) {}
      _serverSocket = null;
    }
    _isRunning = false;
    _activeConnections = 0;
  }

  /// Entry point for each incoming client socket with single persistent listener
  void _handleClientConnection(Socket clientSocket) {
    _activeConnections++;
    final clientIp = clientSocket.remoteAddress.address;

    final session = _ClientSession(
      clientSocket: clientSocket,
      clientIp: clientIp,
      onConnectionClosed: () {
        _activeConnections = (_activeConnections > 0) ? _activeConnections - 1 : 0;
      },
    );

    // Initial buffering to detect protocol
    final List<int> initialBuffer = [];
    bool protocolDetected = false;

    final timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!protocolDetected) {
        session.close();
      }
    });

    session.onData = (data) {
      if (protocolDetected) return;

      initialBuffer.addAll(data);
      if (initialBuffer.isEmpty) return;

      timeoutTimer.cancel();
      protocolDetected = true;

      final firstByte = initialBuffer[0];
      if (firstByte == 0x05) {
        // SOCKS5 Handshake detected
        _processSocks5(session, initialBuffer);
      } else {
        // HTTP / HTTPS CONNECT Handshake detected
        _processHttp(session, initialBuffer);
      }
    };
  }

  // ==========================================
  // SOCKS5 PROTOCOL IMPLEMENTATION (RFC 1928)
  // ==========================================

  void _processSocks5(_ClientSession session, List<int> initialData) async {
    final startTime = DateTime.now();
    try {
      // 1. Initial Greeting: [VER (0x05), NMETHODS, METHODS...]
      if (initialData.length < 2) {
        session.close();
        return;
      }

      final nmethods = initialData[1];
      if (initialData.length < 2 + nmethods) {
        session.close();
        return;
      }

      final methods = initialData.sublist(2, 2 + nmethods);
      final remaining = initialData.sublist(2 + nmethods);
      session.bufferRemaining(remaining);

      // Check if authentication is enabled
      if (_auth.enabled) {
        if (!methods.contains(0x02)) {
          // 0x02 = Username/Password (RFC 1929)
          session.clientSocket.add([0x05, 0xFF]);
          await session.clientSocket.flush();
          session.close();
          return;
        }

        // Method chosen: 0x02
        session.clientSocket.add([0x05, 0x02]);
        await session.clientSocket.flush();

        // Wait for SOCKS5 Auth sub-negotiation: [0x01, ULEN, UNAME..., PLEN, PASSWD...]
        final authData = await session.readExactBytes(5);
        if (authData.isEmpty || authData[0] != 0x01) {
          session.clientSocket.add([0x01, 0x01]);
          await session.clientSocket.flush();
          session.close();
          return;
        }

        final ulen = authData[1];
        final username = utf8.decode(authData.sublist(2, 2 + ulen), allowMalformed: true);
        final plen = authData[2 + ulen];
        final password = utf8.decode(authData.sublist(3 + ulen, 3 + ulen + plen), allowMalformed: true);

        if (username != _auth.username || password != _auth.password) {
          session.clientSocket.add([0x01, 0x01]); // Auth failed
          await session.clientSocket.flush();
          session.close();
          return;
        }

        // Auth success: [0x01, 0x00]
        session.clientSocket.add([0x01, 0x00]);
        await session.clientSocket.flush();
      } else {
        // No Auth required: [0x05, 0x00]
        session.clientSocket.add([0x05, 0x00]);
        await session.clientSocket.flush();
      }

      // 2. Read Request Details: [VER (0x05), CMD, RSV (0x00), ATYP, DST.ADDR, DST.PORT]
      final reqHeader = await session.readExactBytes(4);
      if (reqHeader.length < 4 || reqHeader[0] != 0x05) {
        session.close();
        return;
      }

      final cmd = reqHeader[1];
      final atyp = reqHeader[3];

      if (cmd != 0x01) {
        // Only CONNECT (0x01) is supported
        session.clientSocket.add([0x05, 0x07, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        await session.clientSocket.flush();
        session.close();
        return;
      }

      String targetHost = '';
      int targetPort = 0;

      if (atyp == 0x01) {
        // IPv4 (4 bytes) + 2 bytes port
        final addrData = await session.readExactBytes(6);
        if (addrData.length < 6) return;
        targetHost = '${addrData[0]}.${addrData[1]}.${addrData[2]}.${addrData[3]}';
        targetPort = (addrData[4] << 8) | addrData[5];
      } else if (atyp == 0x03) {
        // Domain Name: 1 byte len + domain bytes + 2 bytes port
        final lenByte = await session.readExactBytes(1);
        if (lenByte.isEmpty) return;
        final domainLen = lenByte[0];
        final domainData = await session.readExactBytes(domainLen + 2);
        if (domainData.length < domainLen + 2) return;
        targetHost = utf8.decode(domainData.sublist(0, domainLen), allowMalformed: true);
        targetPort = (domainData[domainLen] << 8) | domainData[domainLen + 1];
      } else if (atyp == 0x04) {
        // IPv6 (16 bytes) + 2 bytes port
        final addrData = await session.readExactBytes(18);
        if (addrData.length < 18) return;
        final ipParts = <String>[];
        for (int i = 0; i < 16; i += 2) {
          ipParts.add(((addrData[i] << 8) | addrData[i + 1]).toRadixString(16));
        }
        targetHost = ipParts.join(':');
        targetPort = (addrData[16] << 8) | addrData[17];
      } else {
        session.clientSocket.add([0x05, 0x08, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        await session.clientSocket.flush();
        session.close();
        return;
      }

      // Check rules / blocklist / rewrites
      final ruleCheck = _evaluateRule(targetHost, targetPort);
      if (ruleCheck.isBlocked) {
        session.clientSocket.add([0x05, 0x02, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        await session.clientSocket.flush();
        session.close();

        _addLog(ProxyLogEntry(
          id: 's5_blk_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          protocol: ProxyProtocol.socks5,
          method: 'CONNECT',
          host: targetHost,
          port: targetPort,
          clientIp: session.clientIp,
          statusCode: 403,
          isBlocked: true,
          durationMs: DateTime.now().difference(startTime).inMilliseconds,
        ));
        return;
      }

      final resolvedHost = ruleCheck.targetHost.isNotEmpty ? ruleCheck.targetHost : targetHost;
      final resolvedPort = (ruleCheck.targetPort != null && ruleCheck.targetPort! > 0)
          ? ruleCheck.targetPort!
          : targetPort;

      // Connect to remote target or upstream proxy
      Socket remoteSocket;
      if (_upstream.enabled && _upstream.host.isNotEmpty) {
        remoteSocket = await _connectViaUpstream(resolvedHost, resolvedPort);
      } else {
        remoteSocket = await Socket.connect(resolvedHost, resolvedPort, timeout: const Duration(seconds: 10));
      }

      // SOCKS5 Success Response
      session.clientSocket.add([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
      await session.clientSocket.flush();

      // Pipe bidirectionally
      _pipeSession(
        session: session,
        remoteSocket: remoteSocket,
        protocol: ProxyProtocol.socks5,
        method: 'CONNECT',
        host: targetHost,
        port: targetPort,
        startTime: startTime,
        isRewritten: ruleCheck.isRewritten,
      );
    } catch (e) {
      try {
        session.clientSocket.add([0x05, 0x04, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        await session.clientSocket.flush();
      } catch (_) {}
      session.close();
    }
  }

  // ==========================================
  // HTTP & HTTPS CONNECT PROXY IMPLEMENTATION
  // ==========================================

  void _processHttp(_ClientSession session, List<int> initialData) async {
    final startTime = DateTime.now();
    try {
      final requestString = utf8.decode(initialData, allowMalformed: true);
      final lines = requestString.split('\r\n');
      if (lines.isEmpty || lines[0].isEmpty) {
        session.close();
        return;
      }

      final requestLineParts = lines[0].split(' ');
      if (requestLineParts.length < 2) {
        session.close();
        return;
      }

      final method = requestLineParts[0].toUpperCase();
      final targetUri = requestLineParts[1];

      // Parse headers into map
      final Map<String, String> headers = {};
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty) break;
        final colonIdx = line.indexOf(':');
        if (colonIdx > 0) {
          final key = line.substring(0, colonIdx).trim().toLowerCase();
          final val = line.substring(colonIdx + 1).trim();
          headers[key] = val;
        }
      }

      // Check Authentication if enabled
      if (_auth.enabled) {
        final authHeader = headers['proxy-authorization'];
        if (authHeader == null || !authHeader.startsWith('Basic ')) {
          _sendHttpAuthRequired(session);
          return;
        }
        final encoded = authHeader.substring(6).trim();
        try {
          final creds = utf8.decode(base64.decode(encoded));
          final split = creds.split(':');
          if (split.length != 2 || split[0] != _auth.username || split[1] != _auth.password) {
            _sendHttpAuthRequired(session);
            return;
          }
        } catch (_) {
          _sendHttpAuthRequired(session);
          return;
        }
      }

      // Case 1: PAC File Request (Browser Auto-Config)
      if (method == 'GET' && (targetUri == '/proxy.pac' || targetUri.endsWith('/proxy.pac') || targetUri == '/wpad.dat')) {
        _servePacFile(session, startTime);
        return;
      }

      // Case 2: Status / Landing Page (Direct visit to proxy port)
      if (method == 'GET' && (targetUri == '/' || targetUri == '/status' || targetUri == '/index.html') && !targetUri.startsWith('http')) {
        _serveProxyStatusPage(session, startTime);
        return;
      }

      // Case 3: HTTPS CONNECT Tunneling
      if (method == 'CONNECT') {
        _handleHttpsConnect(
          session: session,
          targetAuthority: targetUri,
          startTime: startTime,
        );
        return;
      }

      // Case 4: Standard HTTP Forward Proxy Request (GET/POST/PUT... http://example.com/path)
      _handleHttpForward(
        session: session,
        method: method,
        targetUri: targetUri,
        headers: headers,
        rawInitialData: initialData,
        startTime: startTime,
      );
    } catch (e) {
      try {
        session.clientSocket.write('HTTP/1.1 500 Internal Error\r\nConnection: close\r\n\r\n');
        await session.clientSocket.flush();
      } catch (_) {}
      session.close();
    }
  }

  void _sendHttpAuthRequired(_ClientSession session) async {
    try {
      session.clientSocket.write(
        'HTTP/1.1 407 Proxy Authentication Required\r\n'
        'Proxy-Authenticate: Basic realm="FDServer Super Proxy"\r\n'
        'Content-Type: text/plain; charset=utf-8\r\n'
        'Connection: close\r\n\r\n'
        'Proxy Authentication Required.\n',
      );
      await session.clientSocket.flush();
    } catch (_) {}
    session.close();
  }

  void _servePacFile(_ClientSession session, DateTime startTime) async {
    final pacScript = generatePacScript(serverIp: _host == '0.0.0.0' ? '127.0.0.1' : _host, serverPort: _port);
    final bytes = utf8.encode(pacScript);

    try {
      session.clientSocket.write(
        'HTTP/1.1 200 OK\r\n'
        'Content-Type: application/x-ns-proxy-autoconfig\r\n'
        'Content-Length: ${bytes.length}\r\n'
        'Access-Control-Allow-Origin: *\r\n'
        'Connection: close\r\n\r\n',
      );
      session.clientSocket.add(bytes);
      await session.clientSocket.flush();

      _recordBytes(0, bytes.length);

      _addLog(ProxyLogEntry(
        id: 'pac_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.pac,
        method: 'GET',
        host: _host,
        port: _port,
        path: '/proxy.pac',
        clientIp: session.clientIp,
        statusCode: 200,
        bytesSent: bytes.length,
        durationMs: DateTime.now().difference(startTime).inMilliseconds,
      ));
    } catch (_) {}
    session.close();
  }

  void _serveProxyStatusPage(_ClientSession session, DateTime startTime) async {
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>FDServer Super Proxy</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #09090b; color: #f4f4f5; padding: 2rem; }
    .card { background: #18181b; border: 1px solid #27272a; border-radius: 12px; padding: 1.5rem; max-width: 600px; margin: 0 auto; }
    h1 { font-size: 1.5rem; margin-top: 0; color: #38bdf8; }
    .badge { display: inline-block; padding: 0.25rem 0.5rem; border-radius: 6px; font-size: 0.75rem; font-weight: bold; background: #10b981; color: #000; }
    p { color: #a1a1aa; line-height: 1.5; }
    code { background: #27272a; padding: 0.2rem 0.4rem; border-radius: 4px; font-size: 0.85rem; color: #38bdf8; }
  </style>
</head>
<body>
  <div class="card">
    <div style="display:flex; justify-content:space-between; align-items:center;">
      <h1>FDServer Super Proxy</h1>
      <span class="badge">ONLINE</span>
    </div>
    <p>Proxy server is active and listening on port <code>$_port</code>.</p>
    <p><strong>Supported Protocols:</strong> HTTP, HTTPS CONNECT, SOCKS5, PAC Auto-Discovery.</p>
    <p>PAC Script URL: <a href="/proxy.pac" style="color:#38bdf8;">http://$_host:$_port/proxy.pac</a></p>
  </div>
</body>
</html>
''';
    final bytes = utf8.encode(html);
    try {
      session.clientSocket.write(
        'HTTP/1.1 200 OK\r\n'
        'Content-Type: text/html; charset=utf-8\r\n'
        'Content-Length: ${bytes.length}\r\n'
        'Connection: close\r\n\r\n',
      );
      session.clientSocket.add(bytes);
      await session.clientSocket.flush();

      _addLog(ProxyLogEntry(
        id: 'status_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.http,
        method: 'GET',
        host: _host,
        port: _port,
        path: '/',
        clientIp: session.clientIp,
        statusCode: 200,
        bytesSent: bytes.length,
        durationMs: DateTime.now().difference(startTime).inMilliseconds,
      ));
    } catch (_) {}
    session.close();
  }

  void _handleHttpsConnect({
    required _ClientSession session,
    required String targetAuthority,
    required DateTime startTime,
  }) async {
    String host = targetAuthority;
    int port = 443;

    if (targetAuthority.contains(':')) {
      final parts = targetAuthority.split(':');
      host = parts[0];
      port = int.tryParse(parts[1]) ?? 443;
    }

    final ruleCheck = _evaluateRule(host, port);
    if (ruleCheck.isBlocked) {
      session.clientSocket.write('HTTP/1.1 403 Forbidden\r\nContent-Type: text/plain\r\n\r\nBlocked by FDServer Proxy Rules');
      await session.clientSocket.flush();
      session.close();

      _addLog(ProxyLogEntry(
        id: 'https_blk_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.httpsConnect,
        method: 'CONNECT',
        host: host,
        port: port,
        clientIp: session.clientIp,
        statusCode: 403,
        isBlocked: true,
        durationMs: DateTime.now().difference(startTime).inMilliseconds,
      ));
      return;
    }

    final resolvedHost = ruleCheck.targetHost.isNotEmpty ? ruleCheck.targetHost : host;
    final resolvedPort = (ruleCheck.targetPort != null && ruleCheck.targetPort! > 0)
        ? ruleCheck.targetPort!
        : port;

    try {
      Socket remoteSocket;
      if (_upstream.enabled && _upstream.host.isNotEmpty) {
        remoteSocket = await _connectViaUpstream(resolvedHost, resolvedPort);
      } else {
        remoteSocket = await Socket.connect(resolvedHost, resolvedPort, timeout: const Duration(seconds: 10));
      }

      // Tell the client the tunnel is established
      session.clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      await session.clientSocket.flush();

      _pipeSession(
        session: session,
        remoteSocket: remoteSocket,
        protocol: ProxyProtocol.httpsConnect,
        method: 'CONNECT',
        host: host,
        port: port,
        startTime: startTime,
        isRewritten: ruleCheck.isRewritten,
      );
    } catch (e) {
      try {
        session.clientSocket.write('HTTP/1.1 502 Bad Gateway\r\n\r\n');
        await session.clientSocket.flush();
      } catch (_) {}
      session.close();

      _addLog(ProxyLogEntry(
        id: 'https_err_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.httpsConnect,
        method: 'CONNECT',
        host: host,
        port: port,
        clientIp: session.clientIp,
        statusCode: 502,
        errorMessage: e.toString(),
        durationMs: DateTime.now().difference(startTime).inMilliseconds,
      ));
    }
  }

  void _handleHttpForward({
    required _ClientSession session,
    required String method,
    required String targetUri,
    required Map<String, String> headers,
    required List<int> rawInitialData,
    required DateTime startTime,
  }) async {
    Uri? uri;
    try {
      uri = Uri.parse(targetUri);
    } catch (_) {}

    String host = uri?.host ?? '';
    int port = uri != null && uri.hasPort && uri.port > 0 ? uri.port : 80;
    String path = uri != null && uri.hasAbsolutePath ? uri.path : '/';
    if (uri != null && uri.hasQuery) {
      path += '?${uri.query}';
    }

    if (host.isEmpty) {
      final hostHeader = headers['host'] ?? '';
      if (hostHeader.contains(':')) {
        final split = hostHeader.split(':');
        host = split[0];
        port = int.tryParse(split[1]) ?? 80;
      } else {
        host = hostHeader;
      }
    }

    if (host.isEmpty) {
      session.clientSocket.write('HTTP/1.1 400 Bad Request\r\n\r\n');
      await session.clientSocket.flush();
      session.close();
      return;
    }

    final ruleCheck = _evaluateRule(host, port);
    if (ruleCheck.isBlocked) {
      const blockedHtml = '<html><body><h1>403 Forbidden</h1><p>Blocked by FDServer Proxy Rules.</p></body></html>';
      final blockedBytes = utf8.encode(blockedHtml);
      session.clientSocket.write(
        'HTTP/1.1 403 Forbidden\r\n'
        'Content-Type: text/html; charset=utf-8\r\n'
        'Content-Length: ${blockedBytes.length}\r\n'
        'Connection: close\r\n\r\n',
      );
      session.clientSocket.add(blockedBytes);
      await session.clientSocket.flush();
      session.close();

      _addLog(ProxyLogEntry(
        id: 'http_blk_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.http,
        method: method,
        host: host,
        port: port,
        path: path,
        clientIp: session.clientIp,
        statusCode: 403,
        isBlocked: true,
        durationMs: DateTime.now().difference(startTime).inMilliseconds,
      ));
      return;
    }

    final resolvedHost = ruleCheck.targetHost.isNotEmpty ? ruleCheck.targetHost : host;
    final resolvedPort = (ruleCheck.targetPort != null && ruleCheck.targetPort! > 0)
        ? ruleCheck.targetPort!
        : port;

    try {
      Socket remoteSocket;
      if (_upstream.enabled && _upstream.host.isNotEmpty) {
        remoteSocket = await _connectViaUpstream(resolvedHost, resolvedPort);
      } else {
        remoteSocket = await Socket.connect(resolvedHost, resolvedPort, timeout: const Duration(seconds: 10));
      }

      // Rewrite HTTP request line to relative path
      final rawString = utf8.decode(rawInitialData, allowMalformed: true);
      final doubleCrlfIdx = rawString.indexOf('\r\n\r\n');
      final headerPart = (doubleCrlfIdx != -1) ? rawString.substring(0, doubleCrlfIdx) : rawString;
      final bodyPartBytes = (doubleCrlfIdx != -1) ? rawInitialData.sublist(doubleCrlfIdx + 4) : <int>[];

      final headerLines = headerPart.split('\r\n');
      headerLines[0] = '$method $path HTTP/1.1';

      // Clean up proxy headers
      final rewrittenHeaderLines = <String>[];
      for (final line in headerLines) {
        final lower = line.toLowerCase();
        if (lower.startsWith('proxy-connection:')) {
          rewrittenHeaderLines.add('Connection: close');
        } else if (lower.startsWith('proxy-authorization:')) {
          continue;
        } else {
          rewrittenHeaderLines.add(line);
        }
      }

      final forwardHeaderString = '${rewrittenHeaderLines.join('\r\n')}\r\n\r\n';
      remoteSocket.add(utf8.encode(forwardHeaderString));
      if (bodyPartBytes.isNotEmpty) {
        remoteSocket.add(bodyPartBytes);
      }
      await remoteSocket.flush();

      _pipeSession(
        session: session,
        remoteSocket: remoteSocket,
        protocol: ProxyProtocol.http,
        method: method,
        host: host,
        port: port,
        path: path,
        startTime: startTime,
        isRewritten: ruleCheck.isRewritten,
      );
    } catch (e) {
      try {
        session.clientSocket.write('HTTP/1.1 502 Bad Gateway\r\n\r\n');
        await session.clientSocket.flush();
      } catch (_) {}
      session.close();

      _addLog(ProxyLogEntry(
        id: 'http_err_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        protocol: ProxyProtocol.http,
        method: method,
        host: host,
        port: port,
        path: path,
        clientIp: session.clientIp,
        statusCode: 502,
        errorMessage: e.toString(),
        durationMs: DateTime.now().difference(startTime).inMilliseconds,
      ));
    }
  }

  // ==========================================
  // BIDIRECTIONAL SOCKET PIPING & THROTTLING
  // ==========================================

  void _pipeSession({
    required _ClientSession session,
    required Socket remoteSocket,
    required ProxyProtocol protocol,
    required String method,
    required String host,
    required int port,
    String path = '',
    required DateTime startTime,
    bool isRewritten = false,
  }) {
    int bytesClientToRemote = 0;
    int bytesRemoteToClient = 0;
    bool isClosed = false;

    void closeSockets() {
      if (isClosed) return;
      isClosed = true;

      session.close();
      try {
        remoteSocket.destroy();
      } catch (_) {}

      _addLog(ProxyLogEntry(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}_${session.clientSocket.hashCode}',
        timestamp: DateTime.now(),
        protocol: protocol,
        method: method,
        host: host,
        port: port,
        path: path,
        clientIp: session.clientIp,
        statusCode: 200,
        bytesSent: bytesClientToRemote,
        bytesReceived: bytesRemoteToClient,
        durationMs: DateTime.now().difference(startTime).inMilliseconds,
        isRewritten: isRewritten,
      ));
    }

    // Client -> Remote
    session.onData = (data) {
      bytesClientToRemote += data.length;
      _recordBytes(data.length, 0);

      if (_throttle.enabled && _throttle.kbpsUp > 0) {
        Future.delayed(Duration(milliseconds: _throttle.latencyMs), () {
          if (!isClosed) remoteSocket.add(data);
        });
      } else {
        remoteSocket.add(data);
      }
    };
    session.onDone = () => closeSockets();
    session.onError = (_) => closeSockets();

    // Remote -> Client
    remoteSocket.listen(
      (data) {
        bytesRemoteToClient += data.length;
        _recordBytes(0, data.length);

        if (_throttle.enabled && _throttle.kbpsDown > 0) {
          Future.delayed(Duration(milliseconds: _throttle.latencyMs), () {
            if (!isClosed) session.clientSocket.add(data);
          });
        } else {
          session.clientSocket.add(data);
        }
      },
      onError: (_) => closeSockets(),
      onDone: () => closeSockets(),
      cancelOnError: true,
    );
  }

  // ==========================================
  // HELPERS (Upstream, Rules, PAC)
  // ==========================================

  Future<Socket> _connectViaUpstream(String targetHost, int targetPort) async {
    final upstreamSocket = await Socket.connect(_upstream.host, _upstream.port, timeout: const Duration(seconds: 10));

    String connectRequest = 'CONNECT $targetHost:$targetPort HTTP/1.1\r\nHost: $targetHost:$targetPort\r\n';
    if (_upstream.username.isNotEmpty) {
      final creds = base64.encode(utf8.encode('${_upstream.username}:${_upstream.password}'));
      connectRequest += 'Proxy-Authorization: Basic $creds\r\n';
    }
    connectRequest += '\r\n';

    upstreamSocket.add(utf8.encode(connectRequest));
    await upstreamSocket.flush();

    final buffer = <int>[];
    final completer = Completer<List<int>>();
    late StreamSubscription<Uint8List> sub;
    sub = upstreamSocket.listen((d) {
      buffer.addAll(d);
      if (buffer.length >= 12 && !completer.isCompleted) {
        sub.cancel();
        completer.complete(buffer);
      }
    });

    final respBytes = await completer.future;
    final respLine = utf8.decode(respBytes, allowMalformed: true);
    if (!respLine.contains('200')) {
      upstreamSocket.destroy();
      throw Exception('Upstream proxy rejected connection: $respLine');
    }

    return upstreamSocket;
  }

  _RuleEvalResult _evaluateRule(String host, int port) {
    if (!_isBlocklistEnabled) {
      return _RuleEvalResult(isBlocked: false, isRewritten: false);
    }

    final lowerHost = host.toLowerCase();

    for (final rule in _rules) {
      if (!rule.isEnabled) continue;
      final pattern = rule.pattern.toLowerCase();

      bool matches = false;
      if (pattern == lowerHost) {
        matches = true;
      } else if (pattern.startsWith('*.') && lowerHost.endsWith(pattern.substring(1))) {
        matches = true;
      } else if (pattern.endsWith('*') && lowerHost.startsWith(pattern.substring(0, pattern.length - 1))) {
        matches = true;
      } else if (lowerHost.contains(pattern)) {
        matches = true;
      }

      if (matches) {
        if (rule.type == ProxyRuleType.block) {
          return _RuleEvalResult(isBlocked: true, isRewritten: false);
        } else if (rule.type == ProxyRuleType.rewrite && rule.targetHost.isNotEmpty) {
          return _RuleEvalResult(
            isBlocked: false,
            isRewritten: true,
            targetHost: rule.targetHost,
            targetPort: rule.targetPort,
          );
        }
      }
    }

    return _RuleEvalResult(isBlocked: false, isRewritten: false);
  }

  /// Generates a standard Proxy Auto-Configuration (PAC) script
  static String generatePacScript({required String serverIp, required int serverPort}) {
    return '''
// FDServer Proxy Auto-Configuration (PAC) Script
function FindProxyForURL(url, host) {
    // Direct connection for localhost and local domain names
    if (isPlainHostName(host) ||
        shExpMatch(host, "*.local") ||
        shExpMatch(host, "localhost") ||
        isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0") ||
        isInNet(dnsResolve(host), "172.16.0.0", "255.240.0.0") ||
        isInNet(dnsResolve(host), "192.168.0.0", "255.255.0.0") ||
        isInNet(dnsResolve(host), "127.0.0.0", "255.0.0.0")) {
        return "DIRECT";
    }

    // Forward through FDServer multi-protocol proxy, fallback to DIRECT
    return "PROXY $serverIp:$serverPort; SOCKS5 $serverIp:$serverPort; DIRECT";
}
''';
  }

  void dispose() {
    stopServer();
    _logsController.close();
  }
}

class _RuleEvalResult {
  final bool isBlocked;
  final bool isRewritten;
  final String targetHost;
  final int? targetPort;

  _RuleEvalResult({
    required this.isBlocked,
    required this.isRewritten,
    this.targetHost = '',
    this.targetPort,
  });
}

/// Manages a single persistent stream subscription for incoming client sockets
class _ClientSession {
  final Socket clientSocket;
  final String clientIp;
  final void Function() onConnectionClosed;
  late final StreamSubscription<Uint8List> _subscription;

  void Function(List<int>)? onData;
  void Function()? onDone;
  void Function(dynamic)? onError;

  final List<int> _buffered = [];
  Completer<List<int>>? _pendingReader;
  int _pendingLength = 0;
  bool _isClosed = false;

  _ClientSession({
    required this.clientSocket,
    required this.clientIp,
    required this.onConnectionClosed,
  }) {
    _subscription = clientSocket.listen(
      (data) {
        if (_isClosed) return;

        if (_pendingReader != null) {
          _buffered.addAll(data);
          if (_buffered.length >= _pendingLength && !_pendingReader!.isCompleted) {
            final result = _buffered.sublist(0, _pendingLength);
            _buffered.removeRange(0, _pendingLength);
            final comp = _pendingReader!;
            _pendingReader = null;
            comp.complete(result);
          }
          return;
        }

        onData?.call(data);
      },
      onError: (err) {
        if (!_isClosed) {
          onError?.call(err);
          close();
        }
      },
      onDone: () {
        if (!_isClosed) {
          onDone?.call();
          close();
        }
      },
      cancelOnError: true,
    );
  }

  void bufferRemaining(List<int> bytes) {
    if (bytes.isNotEmpty) {
      _buffered.addAll(bytes);
    }
  }

  Future<List<int>> readExactBytes(int length, {Duration timeout = const Duration(seconds: 5)}) async {
    if (_buffered.length >= length) {
      final res = _buffered.sublist(0, length);
      _buffered.removeRange(0, length);
      return res;
    }

    final completer = Completer<List<int>>();
    _pendingReader = completer;
    _pendingLength = length;

    Timer(timeout, () {
      if (!completer.isCompleted) {
        _pendingReader = null;
        completer.complete(_buffered);
      }
    });

    return completer.future;
  }

  void close() {
    if (_isClosed) return;
    _isClosed = true;

    try {
      _subscription.cancel();
    } catch (_) {}
    try {
      clientSocket.destroy();
    } catch (_) {}

    onConnectionClosed();
  }
}
