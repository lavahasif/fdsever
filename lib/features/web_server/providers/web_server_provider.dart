import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/web_server_service.dart';
import '../../notes/providers/notes_provider.dart';

class WebServerProvider extends ChangeNotifier {
  final WebServerService _service;
  final NotesProvider _notesProvider;

  String _host = '0.0.0.0';
  int _port = int.parse(AppConstants.defaultPort);
  bool _isLoading = false;
  String? _errorMessage;

  WebServerProvider(this._service, this._notesProvider) {
    _service.logsStream.listen((_) => notifyListeners());
  }

  bool get isRunning => _service.isRunning;
  String get host => _host;
  int get port => _port;
  String get serverUrl => 'http://${_host == '0.0.0.0' ? '127.0.0.1' : _host}:$_port';
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ServerLogEntry> get logs => _service.recentLogs;

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
