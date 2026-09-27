import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class DiscoveredProxy {
  final String ip;
  final int port;
  final String protocol; // "SOCKS5" or "HTTP"
  final int latencyMs;

  const DiscoveredProxy({
    required this.ip,
    required this.port,
    required this.protocol,
    required this.latencyMs,
  });

  String get address => '$ip:$port';
  String get displayName => '$ip:$port ($protocol - ${latencyMs}ms)';
}

class VpnStatus {
  final bool isRunning;
  final String targetHost;
  final int targetPort;
  final String targetProtocol;
  final int bytesIn;
  final int bytesOut;
  final String? lastError;
  final List<String> logs;

  const VpnStatus({
    this.isRunning = false,
    this.targetHost = '',
    this.targetPort = 1080,
    this.targetProtocol = 'SOCKS5',
    this.bytesIn = 0,
    this.bytesOut = 0,
    this.lastError,
    this.logs = const [],
  });
}

/// Service managing device-wide transparent proxy diversion via Android VpnService
class VpnDiverterService {
  static const MethodChannel _channel = MethodChannel('fdserver/vpn');

  bool _isRunning = false;
  String _targetHost = '192.168.43.1';
  int _targetPort = 1080;
  String _targetProtocol = 'SOCKS5';
  bool _bypassLan = true;
  String? _lastError;

  int _bytesIn = 0;
  int _bytesOut = 0;
  int _bytesInLastSec = 0;
  int _bytesOutLastSec = 0;
  int _prevBytesIn = 0;
  int _prevBytesOut = 0;

  List<String> _recentLogs = [];

  Timer? _ticker;

  bool get isRunning => _isRunning;
  String get targetHost => _targetHost;
  int get targetPort => _targetPort;
  String get targetProtocol => _targetProtocol;
  bool get bypassLan => _bypassLan;
  String? get lastError => _lastError;
  List<String> get recentLogs => List.unmodifiable(_recentLogs);

  int get bytesIn => _bytesIn;
  int get bytesOut => _bytesOut;
  int get downloadSpeedBps => _bytesInLastSec;
  int get uploadSpeedBps => _bytesOutLastSec;

  void startTicker(void Function() onTick) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_isRunning) {
        await refreshStatus();
        _bytesInLastSec = (_bytesIn - _prevBytesIn).clamp(0, 100000000);
        _bytesOutLastSec = (_bytesOut - _prevBytesOut).clamp(0, 100000000);
        _prevBytesIn = _bytesIn;
        _prevBytesOut = _bytesOut;
        onTick();
      }
    });
  }

  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<bool> prepareVpn() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('prepareVpn') ?? false;
      return granted;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<bool> startVpn({
    required String host,
    required int port,
    required String protocol,
    bool bypassLan = true,
  }) async {
    _targetHost = host.trim();
    _targetPort = port;
    _targetProtocol = protocol.toUpperCase();
    _bypassLan = bypassLan;
    _lastError = null;

    if (!Platform.isAndroid) {
      _isRunning = true;
      return true;
    }

    try {
      final prepared = await prepareVpn();
      if (!prepared) {
        _lastError = 'VPN permission denied by user.';
        return false;
      }

      await clearVpnLogs();

      final success = await _channel.invokeMethod<bool>('startVpn', {
        'host': _targetHost,
        'port': _targetPort,
        'protocol': _targetProtocol,
        'bypassLan': _bypassLan,
      }) ?? false;

      _isRunning = success;
      return success;
    } catch (e) {
      _lastError = e.toString();
      _isRunning = false;
      return false;
    }
  }

  Future<bool> stopVpn() async {
    _isRunning = false;
    if (!Platform.isAndroid) return true;

    try {
      final success = await _channel.invokeMethod<bool>('stopVpn') ?? false;
      return success;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<VpnStatus> refreshStatus() async {
    if (!Platform.isAndroid) {
      return VpnStatus(
        isRunning: _isRunning,
        targetHost: _targetHost,
        targetPort: _targetPort,
        targetProtocol: _targetProtocol,
        bytesIn: _bytesIn,
        bytesOut: _bytesOut,
        lastError: _lastError,
      );
    }

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getVpnStatus');
      if (raw != null) {
        _isRunning = raw['isRunning'] as bool? ?? false;
        _targetHost = raw['targetHost'] as String? ?? _targetHost;
        _targetPort = raw['targetPort'] as int? ?? _targetPort;
        _targetProtocol = raw['targetProtocol'] as String? ?? _targetProtocol;
        _bytesIn = (raw['bytesIn'] as num?)?.toInt() ?? 0;
        _bytesOut = (raw['bytesOut'] as num?)?.toInt() ?? 0;
        _lastError = raw['lastError'] as String?;
        if (raw['logs'] is List) {
          _recentLogs = (raw['logs'] as List).map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    return VpnStatus(
      isRunning: _isRunning,
      targetHost: _targetHost,
      targetPort: _targetPort,
      targetProtocol: _targetProtocol,
      bytesIn: _bytesIn,
      bytesOut: _bytesOut,
      lastError: _lastError,
      logs: _recentLogs,
    );
  }

  Future<List<String>> fetchVpnLogs() async {
    if (!Platform.isAndroid) return _recentLogs;
    try {
      final list = await _channel.invokeListMethod<String>('getVpnLogs');
      if (list != null) {
        _recentLogs = list;
      }
    } catch (_) {}
    return _recentLogs;
  }

  Future<void> clearVpnLogs() async {
    _recentLogs.clear();
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('clearVpnLogs');
    } catch (_) {}
  }

  /// Fast-scans local subnets for open proxy ports (SOCKS5 1080 and HTTP 8080).
  /// Discovers ALL available proxies on the network and triggers [onFound]
  /// the instant each proxy responds so the UI can display chips in real-time!
  Future<List<DiscoveredProxy>> discoverAllHotspotProxies({
    String? preferredSubnet,
    String? lastKnownHost,
    List<int> ports = const [1080, 8080],
    void Function(DiscoveredProxy proxy)? onFound,
  }) async {
    final subnetsToScan = <String>{};
    if (preferredSubnet != null && preferredSubnet.isNotEmpty) {
      subnetsToScan.add(preferredSubnet);
    }
    // Default Android Hotspot subnet is universally 192.168.43.x
    subnetsToScan.add('192.168.43');

    // Also look up active network interfaces
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4 && !addr.address.startsWith('127.')) {
            subnetsToScan.add('${parts[0]}.${parts[1]}.${parts[2]}');
          }
        }
      }
    } catch (_) {}

    final foundList = <DiscoveredProxy>[];
    final foundAddresses = <String>{};

    void handleFound(DiscoveredProxy p) {
      final key = '${p.ip}:${p.port}';
      if (foundAddresses.add(key)) {
        foundList.add(p);
        onFound?.call(p);
      }
    }

    // ── PHASE 1: Priority Fast-Track (< 100ms) ────────────────────────────────
    // Check known target host, Android hotspot gateway (192.168.43.1), and ARP table neighbors FIRST!
    final priorityIps = <String>{};
    if (lastKnownHost != null && lastKnownHost.trim().isNotEmpty && !lastKnownHost.startsWith('127.')) {
      priorityIps.add(lastKnownHost.trim());
    }
    // Android standard hotspot gateway is universally 192.168.43.1
    priorityIps.add('192.168.43.1');

    // Read ARP cache for active neighbor devices (/proc/net/arp)
    try {
      final arp = await File('/proc/net/arp').readAsString();
      final lines = arp.split('\n').skip(1);
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty && parts[0].contains('.') && !parts[0].startsWith('127.')) {
          priorityIps.add(parts[0]);
        }
      }
    } catch (_) {}

    // Concurrently probe all priority targets (500ms allows for protocol verification)
    final priorityFutures = <Future<void>>[];
    for (final ip in priorityIps) {
      for (final port in ports) {
        priorityFutures.add(() async {
          final res = await _probeProxy(ip, port, timeoutMs: 500);
          if (res != null) {
            handleFound(res);
          }
        }());
      }
    }
    await Future.wait(priorityFutures);

    // ── PHASE 2: Parallel Subnet Sweep ───────────────────────────────────────
    // Probe common DHCP range (.2 to .50) first, then remaining (.51 to .254)
    // with 64 concurrent socket connections
    final remainingIps = <String>[];
    for (final subnet in subnetsToScan) {
      for (int i = 2; i <= 50; i++) {
        final ip = '$subnet.$i';
        if (!priorityIps.contains(ip)) remainingIps.add(ip);
      }
      for (int i = 51; i <= 254; i++) {
        final ip = '$subnet.$i';
        if (!priorityIps.contains(ip)) remainingIps.add(ip);
      }
    }

    const batchSize = 64;
    for (int i = 0; i < remainingIps.length; i += batchSize) {
      final batch = remainingIps.sublist(i, (i + batchSize).clamp(0, remainingIps.length));
      final batchFutures = <Future<void>>[];
      for (final ip in batch) {
        for (final port in ports) {
          batchFutures.add(() async {
            final res = await _probeProxy(ip, port, timeoutMs: 400);
            if (res != null) {
              handleFound(res);
            }
          }());
        }
      }
      await Future.wait(batchFutures);
    }

    return foundList;
  }

  /// Backward-compatible single-proxy discovery
  Future<DiscoveredProxy?> autoDiscoverHotspotProxy({
    String? preferredSubnet,
    String? lastKnownHost,
    List<int> ports = const [1080, 8080],
  }) async {
    final list = await discoverAllHotspotProxies(
      preferredSubnet: preferredSubnet,
      lastKnownHost: lastKnownHost,
      ports: ports,
    );
    return list.isNotEmpty ? list.first : null;
  }

  /// Probes a single IP:port and VERIFIES it speaks a real proxy protocol.
  /// Returns null if the port is closed, unresponsive, or not a proxy.
  Future<DiscoveredProxy?> _probeProxy(String ip, int port, {int timeoutMs = 250}) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: Duration(milliseconds: timeoutMs));
      sw.stop();
      final connectMs = sw.elapsedMilliseconds;

      // Set a tight read timeout for the handshake verification
      socket.setOption(SocketOption.tcpNoDelay, true);

      // Try SOCKS5 first (works for port 1080 and any SOCKS5 proxy on any port)
      final socks5Result = await _verifySocks5(socket, timeoutMs: 400);
      if (socks5Result) {
        return DiscoveredProxy(ip: ip, port: port, protocol: 'SOCKS5', latencyMs: connectMs);
      }

      // If SOCKS5 failed, try a fresh connection for HTTP CONNECT test
      try { socket.destroy(); } catch (_) {}
      socket = await Socket.connect(ip, port, timeout: Duration(milliseconds: timeoutMs));
      socket.setOption(SocketOption.tcpNoDelay, true);

      final httpResult = await _verifyHttpConnect(socket, timeoutMs: 400);
      if (httpResult) {
        return DiscoveredProxy(ip: ip, port: port, protocol: 'HTTP', latencyMs: connectMs);
      }

      // Port is open but does NOT speak proxy protocol — skip (e.g. router admin panel)
      return null;
    } catch (_) {
      return null;
    } finally {
      try { socket?.destroy(); } catch (_) {}
    }
  }

  /// Sends a SOCKS5 greeting [0x05, 0x01, 0x00] and checks for [0x05, 0x00] response.
  Future<bool> _verifySocks5(Socket socket, {int timeoutMs = 400}) async {
    try {
      // SOCKS5 greeting: version 5, 1 auth method, NO AUTH (0x00)
      socket.add([0x05, 0x01, 0x00]);
      await socket.flush();

      final response = await socket.timeout(Duration(milliseconds: timeoutMs)).first;
      // Valid SOCKS5 response: [0x05, 0x00] (version 5, no-auth accepted)
      if (response.length >= 2 && response[0] == 0x05 && response[1] == 0x00) {
        return true;
      }
      // Some SOCKS5 proxies respond [0x05, 0x02] (username/password required) — still a valid proxy
      if (response.length >= 2 && response[0] == 0x05 && response[1] == 0x02) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Sends HTTP CONNECT to a test target and checks for a valid 200 or 407 proxy response.
  Future<bool> _verifyHttpConnect(Socket socket, {int timeoutMs = 400}) async {
    try {
      socket.add('CONNECT 1.1.1.1:53 HTTP/1.1\r\nHost: 1.1.1.1:53\r\nUser-Agent: FDServer\r\n\r\n'.codeUnits);
      await socket.flush();

      final response = await socket.timeout(Duration(milliseconds: timeoutMs)).first;
      final responseStr = String.fromCharCodes(response);
      final firstLine = responseStr.split('\r\n').first.toUpperCase();

      // A genuine HTTP proxy MUST respond with HTTP/... 200 Connection Established or 407 Proxy Auth Required.
      // Web servers / router panels will return 400 Bad Request, 404 Not Found, 405 Method Not Allowed, or 501.
      if (firstLine.startsWith('HTTP/') && (firstLine.contains(' 200') || firstLine.contains(' 407'))) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    stopTicker();
  }
}
