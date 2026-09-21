import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/web_server_service.dart';
import '../../notes/providers/notes_provider.dart';

class WebServerProvider extends ChangeNotifier {
  final WebServerService _service;
  final NotesProvider _notesProvider;
  final NetworkService _networkService;

  String _host = '0.0.0.0';
  int _port = int.parse(AppConstants.defaultPort);
  bool _isLoading = false;
  bool _isSearchingIps = false;
  String? _errorMessage;

  List<Map<String, String>> _systemIps = [];
  String _primaryIp = '127.0.0.1';

  WebServerProvider(this._service, this._notesProvider, this._networkService) {
    _service.logsStream.listen((_) => notifyListeners());
    searchSystemIps();
  }

  bool get isRunning => _service.isRunning;
  String get host => _host;
  int get port => _port;
  bool get isLoading => _isLoading;
  bool get isSearchingIps => _isSearchingIps;
  String? get errorMessage => _errorMessage;
  List<ServerLogEntry> get logs => _service.recentLogs;
  List<Map<String, String>> get systemIps => List.unmodifiable(_systemIps);
  String get primaryIp => _primaryIp;

  /// Primary formatted server URL
  String get serverUrl {
    if (_host == '0.0.0.0') {
      final preferred = _primaryIp != '127.0.0.1' ? _primaryIp : '127.0.0.1';
      return 'http://$preferred:$_port';
    }
    return 'http://$_host:$_port';
  }

  /// All accessible server URLs across all available system interfaces
  List<Map<String, String>> get accessibleUrls {
    if (!_service.isRunning) return [];
    if (_host != '0.0.0.0' && _host.isNotEmpty) {
      return [{'name': 'Bound Host', 'ip': _host, 'url': 'http://$_host:$_port', 'isLoopback': 'false'}];
    }
    final list = <Map<String, String>>[];
    for (final item in _systemIps) {
      final ip = item['address'] ?? '';
      final name = item['name'] ?? 'Interface';
      final isLoopback = item['isLoopback'] ?? 'false';
      if (ip.isNotEmpty) {
        list.add({
          'name': name,
          'ip': ip,
          'isLoopback': isLoopback,
          'url': 'http://$ip:$_port',
        });
      }
    }
    if (list.isEmpty) {
      list.add({'name': 'Localhost', 'ip': '127.0.0.1', 'isLoopback': 'true', 'url': 'http://127.0.0.1:$_port'});
    }
    return list;
  }

  /// Search system for all available network interface IPs
  Future<void> searchSystemIps() async {
    _isSearchingIps = true;
    notifyListeners();
    try {
      _systemIps = await _networkService.getAllSystemIps();
      _primaryIp = await _networkService.getPrimaryIp();
    } catch (_) {}
    _isSearchingIps = false;
    notifyListeners();
  }

  void setHost(String host) {
    _host = host;
    notifyListeners();
  }

  void setPort(int port) {
    _port = port;
    notifyListeners();
  }

  Future<void> toggleServer() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (_service.isRunning) {
      await _service.stopServer();
    } else {
      // Refresh system IPs so we always have the freshest network state
      await searchSystemIps();

      final success = await _service.startServer(
        host: _host,
        port: _port,
        notesProvider: () => _notesProvider.notes,
      );
      if (!success) {
        _errorMessage = 'Failed to bind to $_host:$_port. Port may be in use.';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> stopServer() async {
    if (_service.isRunning) {
      await _service.stopServer();
      notifyListeners();
    }
  }
}
