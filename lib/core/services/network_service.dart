import 'dart:async';
import 'dart:io';
import '../models/network_device.dart';

class NetworkService {
  /// Retrieve all local non-loopback IPv4 addresses and interface details
  Future<List<Map<String, String>>> getLocalInterfaces() async {
    final List<Map<String, String>> results = [];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.IPv4,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          results.add({
            'name': iface.name,
            'address': addr.address,
            'isLoopback': addr.isLoopback.toString(),
          });
        }
      }
    } catch (e) {
      // Fallback
      results.add({
        'name': 'Default Loopback',
        'address': '127.0.0.1',
        'isLoopback': 'true',
      });
    }
    return results;
  }

  /// Get preferred primary local IPv4 address
  Future<String> getPrimaryIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  /// Probe a single IP and Port using TCP Socket connect
  Future<bool> probePort(String ip, int port, {int timeoutMs = 2000}) async {
    Socket? socket;
    try {
      final stopwatch = Stopwatch()..start();
      socket = await Socket.connect(
        ip,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      stopwatch.stop();
      return true;
    } catch (e) {
      return false;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  /// Scan multiple ports on an IP address
  Future<NetworkDevice> scanDevice(
    String ip,
    List<int> ports, {
    int timeoutMs = 1500,
  }) async {
    final Map<int, bool> openPorts = {};
    bool hasAnyOpen = false;

    for (final port in ports) {
      final isOpen = await probePort(ip, port, timeoutMs: timeoutMs);
      openPorts[port] = isOpen;
      if (isOpen) hasAnyOpen = true;
    }

    return NetworkDevice(
      ip: ip,
      openPorts: openPorts,
      isReachable: hasAnyOpen,
    );
  }

  /// Scan a subnet for active devices listening on a specific port
  Stream<NetworkDevice> scanSubnet(
    String baseSubnet, // e.g. "192.168.1"
    int port, {
    int startHost = 1,
    int endHost = 254,
    int timeoutMs = 800,
  }) async* {
    for (int host = startHost; host <= endHost; host++) {
      final targetIp = '$baseSubnet.$host';
      final isOpen = await probePort(targetIp, port, timeoutMs: timeoutMs);
      if (isOpen) {
        yield NetworkDevice(
          ip: targetIp,
          openPorts: {port: true},
          isReachable: true,
        );
      }
    }
  }
}
