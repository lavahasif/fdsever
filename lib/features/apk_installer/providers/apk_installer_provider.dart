import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/apk_install_service.dart';
import '../../../core/services/network_service.dart';

class ApkInstallerProvider extends ChangeNotifier {
  final ApkInstallService _service;
  final NetworkService _networkService;
  StreamSubscription<ApkInstallEvent>? _sub;

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

  ApkInstallerProvider(this._service, this._networkService) {
    _sub = _service.events.listen((event) {
      _log.insert(0, event);
      if (_log.length > 100) _log.removeLast();
      _isProcessing = _service.isProcessing;
      notifyListeners();
    });
    _initDefaultIp();
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
    _isSearchingPc = true;
    _connectionStatus = 'Searching LAN for PersonalTasker...';
    notifyListeners();

    try {
      final primary = await _networkService.getPrimaryIp();
      final subnets = <String>{};
      if (primary != '127.0.0.1') {
        final parts = primary.split('.');
        if (parts.length == 4) subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
      }
      subnets.add('10.225.138');
      subnets.add('192.168.1');
      subnets.add('192.168.0');

      for (final subnet in subnets) {
        for (int i = 1; i <= 254; i++) {
          final target = '$subnet.$i';
          try {
            final uri = Uri.parse('http://$target:$_pcPort/api/status');
            final res = await http.get(uri).timeout(const Duration(milliseconds: 300));
            if (res.statusCode == 200 && res.body.contains('PersonalTasker')) {
              _pcIp = target;
              _isSearchingPc = false;
              _connectionStatus = 'Found PersonalTasker at $target';
              notifyListeners();
              // Auto-connect
              await connectToPc(_pcIp, _pcPort);
              return true;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    _isSearchingPc = false;
    _connectionStatus = 'PersonalTasker not found on LAN';
    notifyListeners();
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
          notifyListeners();
        },
        onError: (err) {
          _isConnected = false;
          _isConnecting = false;
          _connectionStatus = 'Connection error: $err';
          notifyListeners();
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _connectionStatus = 'Failed to connect: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnectFromPc() async {
    _socketSub?.cancel();
    _socketSub = null;
    try {
      await _pcSocket?.close();
    } catch (_) {}
    _pcSocket = null;
    _isConnected = false;
    _isConnecting = false;
    _connectionStatus = 'Disconnected';
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
    await _service.enqueue(name, bytes);
    _isProcessing = _service.isProcessing;
    notifyListeners();
  }

  void clearLog() {
    _log.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _socketSub?.cancel();
    _pcSocket?.close();
    super.dispose();
  }
}
