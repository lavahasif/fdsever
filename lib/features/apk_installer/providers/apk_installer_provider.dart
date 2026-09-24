import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/apk_install_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/power_service.dart';

class ApkInstallerProvider extends ChangeNotifier {
  final ApkInstallService _service;
  final NetworkService _networkService;
  final PowerService? _powerService;
  StreamSubscription<ApkInstallEvent>? _sub;
  StreamSubscription? _batterySub;

  final List<ApkInstallEvent> _log = [];
  bool _isProcessing = false;

  // ── PC Server Listener Connection State ────────────────────────────────
  String _pcIp = '10.225.138.220';
  int _pcPort = 9890;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isSearchingPc = false;
  String _connectionStatus = 'Disconnected';
  WebSocket? _pcSocket;
  StreamSubscription? _socketSub;

  // Active download state
  bool _isDownloading = false;
  String? _activeJobName;
  int _downloadPercent = 0;
  int _bytesDownloaded = 0;
  int _totalBytes = 0;

  ApkInstallerProvider(this._service, this._networkService, [this._powerService]) {
    _sub = _service.events.listen((event) {
      _log.insert(0, event);
      if (_log.length > 100) _log.removeLast();
      _isProcessing = _service.isProcessing;
      notifyListeners();
    });
    _batterySub = _powerService?.batteryOptimizationStream.listen((_) => notifyListeners());
    _initDefaultIp();
  }

  bool get isIgnoringBattery => _powerService?.isIgnoringBattery ?? true;
  bool get isScreenKeepOn => _powerService?.isScreenKeepOn ?? false;

  Future<bool> requestDisableBatteryOptimization() async {
    final res = await _powerService?.requestDisableBatteryOptimization() ?? false;
    notifyListeners();
    return res;
  }

  Future<void> openBatterySettings() async {
    await _powerService?.openBatterySettings();
  }

  Future<bool> setKeepScreenOn(bool enable) async {
    final res = await _powerService?.setKeepScreenOn(enable) ?? false;
    notifyListeners();
    return res;
  }

  List<ApkInstallEvent> get log => List.unmodifiable(_log);
  bool get isProcessing => _isProcessing;
  int get queueLength => _service.queueLength;

  String get pcIp => _pcIp;
  int get pcPort => _pcPort;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isSearchingPc => _isSearchingPc;
  String get connectionStatus => _connectionStatus;

  bool get isDownloading => _isDownloading;
  String? get activeJobName => _activeJobName;
  int get downloadPercent => _downloadPercent;
  int get bytesDownloaded => _bytesDownloaded;
  int get totalBytes => _totalBytes;

  void setPcIp(String ip) {
    _pcIp = ip.trim();
    notifyListeners();
  }

  void setPcPort(int port) {
    _pcPort = port;
    notifyListeners();
  }

  int _searchToken = 0;

  Future<void> _initDefaultIp() async {
    try {
      final primary = await _networkService.getPrimaryIp();
      if (primary != '127.0.0.1') {
        final parts = primary.split('.');
        if (parts.length == 4) {
          // Pre-populate with current LAN subnet
          _pcIp = '${parts[0]}.${parts[1]}.${parts[2]}.220';
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // ── Auto-Discover PC on LAN ───────────────────────────────────────────
  Future<bool> autoDiscoverPc() async {
    final searchToken = ++_searchToken;
    _isSearchingPc = true;
    _connectionStatus = 'Searching LAN for PersonalTasker...';
    notifyListeners();

    try {
      // 1. Fast-Path: Probe the current / pre-configured IP first (< 50ms)
      if (_pcIp.trim().isNotEmpty && _pcIp != '127.0.0.1') {
        _connectionStatus = 'Probing current IP $_pcIp...';
        notifyListeners();

        if (await _verifyPersonalTasker(_pcIp, _pcPort, timeoutMs: 500)) {
          if (searchToken != _searchToken) return false;
          _isSearchingPc = false;
          _connectionStatus = 'Found PersonalTasker at $_pcIp';
          notifyListeners();
          await connectToPc(_pcIp, _pcPort);
          return true;
        }
      }

      // 2. Discover all candidate subnets dynamically across active interfaces
      final subnets = await _discoverCandidateSubnets();

      // 3. Scan each subnet concurrently
      for (final subnet in subnets) {
        if (searchToken != _searchToken) return false;
        _connectionStatus = 'Fast-scanning subnet $subnet.0/24...';
        notifyListeners();

        final foundIp = await _scanSubnetFast(subnet, _pcPort, searchToken);
        if (foundIp != null) {
          if (searchToken != _searchToken) return false;
          _pcIp = foundIp;
          _isSearchingPc = false;
          _connectionStatus = 'Found PersonalTasker at $foundIp';
          notifyListeners();
          await connectToPc(_pcIp, _pcPort);
          return true;
        }
      }
    } catch (_) {}

    if (searchToken == _searchToken) {
      _isSearchingPc = false;
      _connectionStatus = 'PersonalTasker not found on LAN';
      notifyListeners();
    }
    return false;
  }

  void cancelDiscovery() {
    _searchToken++;
    _isSearchingPc = false;
    _connectionStatus = 'Search cancelled';
    notifyListeners();
  }

  Future<List<String>> _discoverCandidateSubnets() async {
    final subnets = <String>{};

    // 1. Active subnets from network interfaces
    try {
      final active = await _networkService.getActiveSubnets();
      subnets.addAll(active);
    } catch (_) {}

    // 2. Fallbacks: common office/home & mobile hotspot subnets
    final fallbacks = [
      '10.225.138',
      '192.168.1',
      '192.168.0',
      '192.168.137', // Windows Mobile Hotspot default
      '192.168.43',  // Android Wi-Fi Hotspot default
      '192.168.42',  // USB Tethering default
      '10.0.0',
    ];
    for (final f in fallbacks) {
      subnets.add(f);
    }

    return subnets.toList();
  }

  Future<String?> _scanSubnetFast(String subnet, int port, int searchToken) async {
    final orderedHosts = <int>[];

    // Priority 1: Check if configured _pcIp has a host suffix (e.g. 220)
    try {
      final last = int.tryParse(_pcIp.split('.').last);
      if (last != null && last >= 1 && last <= 254) {
        orderedHosts.add(last);
      }
    } catch (_) {}

    // Priority 2: Common PC / server static or DHCP addresses
    for (final h in [220, 1, 2, 100, 101, 102, 105, 150, 200, 254]) {
      if (!orderedHosts.contains(h)) orderedHosts.add(h);
    }

    // Priority 3: All remaining hosts on the /24 subnet (1..254)
    for (int i = 1; i <= 254; i++) {
      if (!orderedHosts.contains(i)) orderedHosts.add(i);
    }

    final candidateIps = orderedHosts.map((h) => '$subnet.$h').toList();
    final completer = Completer<String?>();
    const concurrency = 35;
    int nextIndex = 0;
    int activeWorkers = 0;
    int testedCount = 0;
    bool found = false;

    void launchNext() {
      if (found || completer.isCompleted || _searchToken != searchToken) {
        return;
      }

      if (nextIndex >= candidateIps.length) {
        if (activeWorkers == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
        return;
      }

      final ip = candidateIps[nextIndex++];
      activeWorkers++;

      _probeCandidatePort(ip, port).then((isOpen) async {
        testedCount++;
        if (testedCount % 35 == 0 && !found && _searchToken == searchToken) {
          _connectionStatus = 'Scanning $subnet.0/24 ($testedCount/254)...';
          notifyListeners();
        }

        if (isOpen && !found && _searchToken == searchToken) {
          final isTasker = await _verifyPersonalTasker(ip, port, timeoutMs: 600);
          if (isTasker && !found && _searchToken == searchToken) {
            found = true;
            if (!completer.isCompleted) {
              completer.complete(ip);
            }
            return;
          }
        }
      }).catchError((_) {
        // Ignore probe errors
      }).whenComplete(() {
        activeWorkers--;
        if (!found && !completer.isCompleted && _searchToken == searchToken) {
          launchNext();
        }
      });
    }

    // Launch worker pool
    for (int i = 0; i < concurrency && i < candidateIps.length; i++) {
      launchNext();
    }

    return completer.future;
  }

  Future<bool> _probeCandidatePort(String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 200),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  Future<bool> _verifyPersonalTasker(String ip, int port, {int timeoutMs = 600}) async {
    // 1. Try HTTP /api/status first
    try {
      final uri = Uri.parse('http://$ip:$port/api/status');
      final res = await http.get(uri).timeout(Duration(milliseconds: timeoutMs));
      if (res.statusCode == 200) {
        final body = res.body;
        if (body.contains('PersonalTasker') ||
            body.contains('EasyInstall') ||
            body.contains('"status":"online"') ||
            body.contains('"status": "online"') ||
            body.contains('"server"')) {
          return true;
        }
      }
    } catch (_) {}

    // 2. Fallback: Direct WebSocket connection check
    try {
      final ws = await WebSocket.connect(
        'ws://$ip:$port/ws',
      ).timeout(Duration(milliseconds: timeoutMs));
      await ws.close();
      return true;
    } catch (_) {}

    return false;
  }

  // ── Connect / Disconnect WebSocket ───────────────────────────────────
  Future<bool> connectToPc(String ip, int port) async {
    await disconnectFromPc();
    _pcIp = ip.trim();
    _pcPort = port;
    _isConnecting = true;
    _connectionStatus = 'Connecting to ws://$ip:$port/ws...';
    notifyListeners();

    try {
      final wsUrl = 'ws://$ip:$port/ws';
      final socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 4));
      _pcSocket = socket;
      _isConnected = true;
      _isConnecting = false;
      _connectionStatus = 'Connected to PersonalTasker ($ip:$port)';

      // Handshake device info
      socket.add(json.encode({
        'type': 'DEVICE_INFO',
        'device': 'FDServer Android',
        'model': Platform.operatingSystem,
      }));

      _socketSub = socket.listen(
        (data) => _handleSocketMessage(data),
        onDone: () {
          _isConnected = false;
          _isConnecting = false;
          _connectionStatus = 'Disconnected from PC server';
          _powerService?.releaseWakeLock('apk_pc_listener');
          notifyListeners();
        },
        onError: (err) {
          _isConnected = false;
          _isConnecting = false;
          _connectionStatus = 'Connection error: $err';
          _powerService?.releaseWakeLock('apk_pc_listener');
          notifyListeners();
        },
      );

      await _powerService?.acquireWakeLock('apk_pc_listener');
      notifyListeners();
      return true;
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _connectionStatus = 'Failed to connect: $e';
      _powerService?.releaseWakeLock('apk_pc_listener');
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnectFromPc() async {
    _searchToken++;
    _isSearchingPc = false;
    _socketSub?.cancel();
    _socketSub = null;
    try {
      await _pcSocket?.close();
    } catch (_) {}
    _pcSocket = null;
    _isConnected = false;
    _isConnecting = false;
    _connectionStatus = 'Disconnected';
    await _powerService?.releaseWakeLock('apk_pc_listener');
    notifyListeners();
  }

  // ── Socket Message Dispatcher ─────────────────────────────────────────
  void _handleSocketMessage(dynamic raw) {
    try {
      final text = raw.toString();
      if (!text.startsWith('{')) return;
      final data = json.decode(text) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'INSTALL_JOB') {
        _downloadAndInstallJob(data);
      }
    } catch (e) {
      debugPrint('[FDServerListener] Error processing message: $e');
    }
  }

  // ── Stream Download & Install Handler ──────────────────────────────────
  Future<void> _downloadAndInstallJob(Map<String, dynamic> job) async {
    final jobId = job['id']?.toString() ?? '';
    final apkName = job['name']?.toString() ?? 'app.apk';
    final downloadUrl = job['downloadUrl']?.toString() ?? '';

    if (downloadUrl.isEmpty) {
      _sendSocketStatus(jobId, 'failed', 'Invalid download URL');
      return;
    }

    await _powerService?.acquireWakeLock('apk_download');
    _isDownloading = true;
    _activeJobName = apkName;
    _downloadPercent = 0;
    _bytesDownloaded = 0;
    _totalBytes = job['size'] is int ? job['size'] as int : 0;
    notifyListeners();

    try {
      final uri = Uri.parse(downloadUrl);
      final client = http.Client();
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP error ${response.statusCode}: ${response.reasonPhrase}');
      }

      final contentLength = response.contentLength ?? _totalBytes;
      _totalBytes = contentLength;
      final bytes = <int>[];
      int received = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        _bytesDownloaded = received;

        if (contentLength > 0) {
          final pct = ((received / contentLength) * 100).clamp(0, 100).toInt();
          _downloadPercent = pct;
          _sendSocketProgress(jobId, pct, received, contentLength);
        }
        notifyListeners();
      }

      _isDownloading = false;
      notifyListeners();

      // Report downloaded, triggering installer
      _sendSocketStatus(jobId, 'installing', 'APK downloaded (${(bytes.length / 1024).toStringAsFixed(1)} KB) — launching installer...');

      // Enqueue in ApkInstallService (saves to cache & triggers PackageInstaller intent)
      await _service.enqueue(apkName, bytes);

      _sendSocketStatus(jobId, 'success', 'PackageInstaller launched on Android device ✓');
    } catch (e) {
      _isDownloading = false;
      notifyListeners();
      _sendSocketStatus(jobId, 'failed', e.toString());
    } finally {
      await _powerService?.releaseWakeLock('apk_download');
    }
  }

  void _sendSocketProgress(String jobId, int percent, int received, int total) {
    if (_pcSocket != null && _isConnected) {
      try {
        _pcSocket!.add(json.encode({
          'type': 'PROGRESS',
          'id': jobId,
          'percent': percent,
          'bytesReceived': received,
          'totalBytes': total,
        }));
      } catch (_) {}
    }
  }

  void _sendSocketStatus(String jobId, String status, String message) {
    if (_pcSocket != null && _isConnected) {
      try {
        _pcSocket!.add(json.encode({
          'type': 'STATUS',
          'id': jobId,
          'status': status,
          'message': message,
        }));
      } catch (_) {}
    }
  }

  /// Manual Enqueue APK bytes for installation
  Future<void> installApk(String name, List<int> bytes) async {
    await _powerService?.acquireWakeLock('apk_manual_install');
    try {
      await _service.enqueue(name, bytes);
      _isProcessing = _service.isProcessing;
      notifyListeners();
    } finally {
      await _powerService?.releaseWakeLock('apk_manual_install');
    }
  }

  void clearLog() {
    _log.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _searchToken++;
    _isSearchingPc = false;
    _sub?.cancel();
    _batterySub?.cancel();
    _socketSub?.cancel();
    _pcSocket?.close();
    _powerService?.releaseWakeLock('apk_pc_listener');
    _powerService?.releaseWakeLock('apk_download');
    _powerService?.releaseWakeLock('apk_manual_install');
    super.dispose();
  }
}
