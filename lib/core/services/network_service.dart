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
    /// Retrieve all available system IPv4 addresses, prioritizing non-loopback LAN interfaces
  Future<List<Map<String, String>>> getAllSystemIps() async {
    final List<Map<String, String>> nonLoopback = [];
    final List<Map<String, String>> loopbacks = [];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final isLoopback = addr.isLoopback;
          final item = {
            'name': iface.name,
            'address': addr.address,
            'isLoopback': isLoopback.toString(),
          };
          if (isLoopback) {
            loopbacks.add(item);
          } else {
            nonLoopback.add(item);
          }
        }
      }
    } catch (_) {}
    if (nonLoopback.isEmpty && loopbacks.isEmpty) {
      return [{'name': 'Loopback', 'address': '127.0.0.1', 'isLoopback': 'true'}];
    }
    return [...nonLoopback, ...loopbacks];
  }

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

  /// Get all unique active IPv4 subnets across network interfaces
  Future<List<String>> getActiveSubnets() async {
    final subnets = <String>{};
    try {
      final primary = await getPrimaryIp();
      if (primary != '127.0.0.1') {
        final parts = primary.split('.');
        if (parts.length == 4) subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
      }
    } catch (_) {}

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
            }
          }
        }
      }
    } catch (_) {}

    return subnets.toList();
  }

  /// Scan a subnet for active devices listening on a specific port using a concurrent pool
  Stream<NetworkDevice> scanSubnet(
    String baseSubnet, // e.g. "192.168.1"
    int port, {
    int startHost = 1,
    int endHost = 254,
    int timeoutMs = 300,
    int concurrency = 30,
  }) async* {
    final controller = StreamController<NetworkDevice>();
    final hosts = [for (int h = startHost; h <= endHost; h++) h];
    int nextIndex = 0;
    int active = 0;

    void launchNext() {
      if (controller.isClosed) return;
      if (nextIndex >= hosts.length) {
        if (active == 0 && !controller.isClosed) {
          controller.close();
        }
        return;
      }

      final host = hosts[nextIndex++];
      final targetIp = '$baseSubnet.$host';
      active++;

      probePort(targetIp, port, timeoutMs: timeoutMs).then((isOpen) {
        if (isOpen && !controller.isClosed) {
          controller.add(NetworkDevice(
            ip: targetIp,
            openPorts: {port: true},
            isReachable: true,
          ));
        }
      }).catchError((_) {
        // ignore probe errors
      }).whenComplete(() {
        active--;
        launchNext();
      });
    }

    for (int i = 0; i < concurrency && i < hosts.length; i++) {
      launchNext();
    }

    yield* controller.stream;
  }
}
