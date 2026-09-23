import 'dart:convert';

enum ProxyProtocol {
  http,
  httpsConnect,
  socks5,
  pac,
}

extension ProxyProtocolExtension on ProxyProtocol {
  String get displayName {
    switch (this) {
      case ProxyProtocol.http:
        return 'HTTP';
      case ProxyProtocol.httpsConnect:
        return 'HTTPS (CONNECT)';
      case ProxyProtocol.socks5:
        return 'SOCKS5';
      case ProxyProtocol.pac:
        return 'PAC';
    }
  }

  String get shortCode {
    switch (this) {
      case ProxyProtocol.http:
        return 'HTTP';
      case ProxyProtocol.httpsConnect:
        return 'HTTPS';
      case ProxyProtocol.socks5:
        return 'SOCKS5';
      case ProxyProtocol.pac:
        return 'PAC';
    }
  }
}

class ProxyLogEntry {
  final String id;
  final DateTime timestamp;
  final ProxyProtocol protocol;
  final String method;
  final String host;
  final int port;
  final String path;
  final String clientIp;
  final int statusCode;
  final int bytesSent;
  final int bytesReceived;
  final int durationMs;
  final String? errorMessage;
  final bool isBlocked;
  final bool isRewritten;

  ProxyLogEntry({
    required this.id,
    required this.timestamp,
    required this.protocol,
    required this.method,
    required this.host,
    required this.port,
    this.path = '',
    required this.clientIp,
    this.statusCode = 200,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.durationMs = 0,
    this.errorMessage,
    this.isBlocked = false,
    this.isRewritten = false,
  });

  int get totalBytes => bytesSent + bytesReceived;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'protocol': protocol.name,
      'method': method,
      'host': host,
      'port': port,
      'path': path,
      'clientIp': clientIp,
      'statusCode': statusCode,
      'bytesSent': bytesSent,
      'bytesReceived': bytesReceived,
      'durationMs': durationMs,
      'errorMessage': errorMessage,
      'isBlocked': isBlocked,
      'isRewritten': isRewritten,
    };
  }

  String toJson() => json.encode(toMap());
}

enum ProxyRuleType {
  block,
  rewrite,
}

class ProxyRule {
  final String id;
  final ProxyRuleType type;
  final String pattern; // e.g. "ads.*" or "*.doubleclick.net" or "badsite.com"
  final String targetHost; // used when type == rewrite
  final int? targetPort;
  final bool isEnabled;

  ProxyRule({
    required this.id,
    required this.type,
    required this.pattern,
    this.targetHost = '',
    this.targetPort,
    this.isEnabled = true,
  });

  ProxyRule copyWith({
    String? id,
    ProxyRuleType? type,
    String? pattern,
    String? targetHost,
    int? targetPort,
    bool? isEnabled,
  }) {
    return ProxyRule(
      id: id ?? this.id,
      type: type ?? this.type,
      pattern: pattern ?? this.pattern,
      targetHost: targetHost ?? this.targetHost,
      targetPort: targetPort ?? this.targetPort,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'pattern': pattern,
      'targetHost': targetHost,
      'targetPort': targetPort,
      'isEnabled': isEnabled,
    };
  }

  factory ProxyRule.fromMap(Map<String, dynamic> map) {
    return ProxyRule(
      id: map['id'] ?? '',
      type: map['type'] == 'rewrite' ? ProxyRuleType.rewrite : ProxyRuleType.block,
      pattern: map['pattern'] ?? '',
      targetHost: map['targetHost'] ?? '',
      targetPort: map['targetPort'] as int?,
      isEnabled: map['isEnabled'] ?? true,
    );
  }
}

class ProxyAuth {
  final bool enabled;
  final String username;
  final String password;

  const ProxyAuth({
    this.enabled = false,
    this.username = '',
    this.password = '',
  });

  ProxyAuth copyWith({
    bool? enabled,
    String? username,
    String? password,
  }) {
    return ProxyAuth(
      enabled: enabled ?? this.enabled,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

class UpstreamProxy {
  final bool enabled;
  final String host;
  final int port;
  final String username;
  final String password;

  const UpstreamProxy({
    this.enabled = false,
    this.host = '',
    this.port = 8080,
    this.username = '',
    this.password = '',
  });

  UpstreamProxy copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return UpstreamProxy(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

class ThrottleProfile {
  final bool enabled;
  final String name;
  final int kbpsDown; // 0 for unlimited
  final int kbpsUp;
  final int latencyMs;

  const ThrottleProfile({
    this.enabled = false,
    this.name = 'Unlimited',
    this.kbpsDown = 0,
    this.kbpsUp = 0,
    this.latencyMs = 0,
  });

  static const List<ThrottleProfile> presets = [
    ThrottleProfile(enabled: false, name: 'Unlimited', kbpsDown: 0, kbpsUp: 0, latencyMs: 0),
    ThrottleProfile(enabled: true, name: '4G LTE (15 Mbps)', kbpsDown: 15000, kbpsUp: 5000, latencyMs: 30),
    ThrottleProfile(enabled: true, name: '3G Fast (1.6 Mbps)', kbpsDown: 1600, kbpsUp: 768, latencyMs: 100),
    ThrottleProfile(enabled: true, name: '2G Edge (250 Kbps)', kbpsDown: 250, kbpsUp: 100, latencyMs: 350),
    ThrottleProfile(enabled: true, name: 'DSL (2 Mbps)', kbpsDown: 2000, kbpsUp: 512, latencyMs: 50),
  ];
}

class ProxyStats {
  final int totalRequests;
  final int httpRequests;
  final int httpsRequests;
  final int socks5Requests;
  final int pacRequests;
  final int blockedRequests;
  final int activeConnections;
  final int totalBytesIn;
  final int totalBytesOut;
  final double currentSpeedInKbps;
  final double currentSpeedOutKbps;
  final DateTime? startedAt;

  const ProxyStats({
    this.totalRequests = 0,
    this.httpRequests = 0,
    this.httpsRequests = 0,
    this.socks5Requests = 0,
    this.pacRequests = 0,
    this.blockedRequests = 0,
    this.activeConnections = 0,
    this.totalBytesIn = 0,
    this.totalBytesOut = 0,
    this.currentSpeedInKbps = 0.0,
    this.currentSpeedOutKbps = 0.0,
    this.startedAt,
  });

  ProxyStats copyWith({
    int? totalRequests,
    int? httpRequests,
    int? httpsRequests,
    int? socks5Requests,
    int? pacRequests,
    int? blockedRequests,
    int? activeConnections,
    int? totalBytesIn,
    int? totalBytesOut,
    double? currentSpeedInKbps,
    double? currentSpeedOutKbps,
    DateTime? startedAt,
  }) {
    return ProxyStats(
      totalRequests: totalRequests ?? this.totalRequests,
      httpRequests: httpRequests ?? this.httpRequests,
      httpsRequests: httpsRequests ?? this.httpsRequests,
      socks5Requests: socks5Requests ?? this.socks5Requests,
      pacRequests: pacRequests ?? this.pacRequests,
      blockedRequests: blockedRequests ?? this.blockedRequests,
      activeConnections: activeConnections ?? this.activeConnections,
      totalBytesIn: totalBytesIn ?? this.totalBytesIn,
      totalBytesOut: totalBytesOut ?? this.totalBytesOut,
      currentSpeedInKbps: currentSpeedInKbps ?? this.currentSpeedInKbps,
      currentSpeedOutKbps: currentSpeedOutKbps ?? this.currentSpeedOutKbps,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}
