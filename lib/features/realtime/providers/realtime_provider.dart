import 'package:flutter/foundation.dart';
import '../../../core/models/socket_message.dart';
import '../../../core/services/socket_service.dart';

class RealtimeProvider extends ChangeNotifier {
  final SocketService _service;

  String _serverUrl = 'ws://127.0.0.1:8082';
  int _localServerPort = 8082;
  bool _isLoading = false;

  RealtimeProvider(this._service) {
    _service.messagesStream.listen((_) => notifyListeners());
  }

  bool get isClientConnected => _service.isClientConnected;
  bool get isServerRunning => _service.isServerRunning;
  String get serverUrl => _serverUrl;
  int get localServerPort => _localServerPort;
  bool get isLoading => _isLoading;
  List<SocketMessage> get messages => _service.messages;

  void setServerUrl(String url) {
    _serverUrl = url;
    notifyListeners();
  }

  void setLocalServerPort(int port) {
    _localServerPort = port;
    notifyListeners();
  }

  Future<void> toggleLocalServer() async {
    _isLoading = true;
    notifyListeners();

    if (_service.isServerRunning) {
      await _service.stopServer();
    } else {
      await _service.startServer(port: _localServerPort);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleClientConnection() async {
    _isLoading = true;
    notifyListeners();

    if (_service.isClientConnected) {
      await _service.disconnectClient();
    } else {
      await _service.connectClient(_serverUrl);
    }

    _isLoading = false;
    notifyListeners();
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _service.sendClientMessage(text.trim());
  }

  void clearHistory() {
    _service.clearMessages();
    notifyListeners();
  }
}
