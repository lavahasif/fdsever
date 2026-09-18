class NetworkDevice {
  final String ip;
  final String? hostname;
  final Map<int, bool> openPorts;
  final bool isReachable;
  final int? latencyMs;
  final DateTime scannedAt;

  NetworkDevice({
    required this.ip,
    this.hostname,
    Map<int, bool>? openPorts,
    this.isReachable = true,
    this.latencyMs,
    DateTime? scannedAt,
  })  : openPorts = openPorts ?? {},
        scannedAt = scannedAt ?? DateTime.now();

  NetworkDevice copyWith({
    String? ip,
    String? hostname,
    Map<int, bool>? openPorts,
    bool? isReachable,
    int? latencyMs,
    DateTime? scannedAt,
  }) {
    return NetworkDevice(
      ip: ip ?? this.ip,
      hostname: hostname ?? this.hostname,
      openPorts: openPorts ?? Map.from(this.openPorts),
      isReachable: isReachable ?? this.isReachable,
      latencyMs: latencyMs ?? this.latencyMs,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}
