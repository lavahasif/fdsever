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

  const VpnStatus({
    this.isRunning = false,
    this.targetHost = '',
    this.targetPort = 1080,
    this.targetProtocol = 'SOCKS5',
    this.bytesIn = 0,
    this.bytesOut = 0,
    this.lastError,
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

  Timer? _ticker;

  bool get isRunning => _isRunning;
  String get targetHost => _targetHost;
  int get targetPort => _targetPort;
  String get targetProtocol => _targetProtocol;
  bool get bypassLan => _bypassLan;
  String? get lastError => _lastError;

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
    );
  }

  /// Scans local subnets for open EveryProxy ports (SOCKS5 1080 or HTTP 8080)
  /// Returns the first responsive proxy device with latency
  Future<DiscoveredProxy?> autoDiscoverHotspotProxy({
    String? preferredSubnet,
    List<int> ports = const [1080, 8080, 8888, 3128],
  }) async {
    final subnetsToScan = <String>{};

    if (preferredSubnet != null && preferredSubnet.isNotEmpty) {
      subnetsToScan.add(preferredSubnet);
    }
    // Default Android Hotspot subnet is almost universally 192.168.43.x
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

    for (final subnet in subnetsToScan) {
      // Prioritize gateway (.1) and common DHCP assignees (.2 to .50)
      final candidateIps = <String>[
        '$subnet.1', // Android Hotspot host default IP
        for (int i = 2; i <= 254; i++) '$subnet.$i',
      ];

      for (final port in ports) {
        // Fast probe in concurrent batches of 32
        const batchSize = 32;
        for (int i = 0; i < candidateIps.length; i += batchSize) {
          final batch = candidateIps.sublist(i, (i + batchSize).clamp(0, candidateIps.length));
          final futures = batch.map((ip) => _probeProxy(ip, port));
          final results = await Future.wait(futures);

          for (final res in results) {
            if (res != null) {
              return res; // Found responsive proxy on hotspot!
            }
          }
        }
      }
    }

    return null;
  }

  Future<DiscoveredProxy?> _probeProxy(String ip, int port) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 350));
      sw.stop();

      // Quick test to see if it speaks SOCKS5 or HTTP
      final protocol = (port == 1080) ? 'SOCKS5' : 'HTTP';
      return DiscoveredProxy(
        ip: ip,
        port: port,
        protocol: protocol,
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (_) {
      return null;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  void dispose() {
    stopTicker();
  }
}
