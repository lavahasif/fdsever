import 'dart:async';
import 'package:fdserver/core/services/apk_install_service.dart';
import 'dart:io';
import '../models/socket_message.dart';

class SocketService {
  WebSocket? _clientSocket;
  HttpServer? _testServer;
  final List<WebSocket> _connectedClients = [];

  final StreamController<SocketMessage> _messagesController =
      StreamController<SocketMessage>.broadcast();
  final List<SocketMessage> _messages = [];

  bool _isClientConnected = false;

  // --- APK streaming state (WebSocket install protocol) ---
  ApkInstallService? apkInstallService;
  String _pendingApkName = '';
  int _pendingApkTotalSize = 0;
  final List<int> _pendingApkBuffer = [];
  bool _isServerRunning = false;
  String _clientUrl = '';
  int _serverPort = 8082;

  bool get isClientConnected => _isClientConnected;
  bool get isServerRunning => _isServerRunning;
  String get clientUrl => _clientUrl;
  int get serverPort => _serverPort;
  Stream<SocketMessage> get messagesStream => _messagesController.stream;
  List<SocketMessage> get messages => List.unmodifiable(_messages);

  void _addMessage(String text, MessageSource source) {
    final msg = SocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      source: source,
    );
    _messages.add(msg);
    _messagesController.add(msg);
  }

  // --- WebSocket Server ---
  Future<bool> startServer({int port = 8082}) async {
    if (_isServerRunning) await stopServer();
    try {
      _serverPort = port;
      _testServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isServerRunning = true;
      _addMessage('Echo WebSocket Server started on port $port', MessageSource.system);

      _testServer!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final ws = await WebSocketTransformer.upgrade(request);
          _connectedClients.add(ws);
          _addMessage('Client connected to local WS server', MessageSource.system);

          ws.listen(
            (data) {
              if (data is List<int>) {
                _handleBinaryChunk(data, ws);
                return;
              }
              final text = data.toString();
              if (text.startsWith('INSTALL:')) {
                _prepareApkReceive(text, ws);
                return;
              }
              if (text == 'DONE') {
                _finalizeApkReceive(ws);
                return;
              }
              _addMessage('Received from client: $text', MessageSource.server);
              ws.add('Echo: $text');
            },
            onDone: () {
              _connectedClients.remove(ws);
              _addMessage('Client disconnected from local WS server', MessageSource.system);
            },
            onError: (err) {
              _connectedClients.remove(ws);
              _addMessage('Client socket error: $err', MessageSource.system);
            },
          );
        } else {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..write('WebSocket connections only')
            ..close();
        }
      });
      return true;
    } catch (e) {
      _isServerRunning = false;
      _addMessage('Failed to start server: $e', MessageSource.system);
      return false;
    }
  }

  Future<void> stopServer() async {
    for (final client in _connectedClients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _connectedClients.clear();
    await _testServer?.close(force: true);
    _testServer = null;
    _isServerRunning = false;
    _addMessage('WebSocket Server stopped', MessageSource.system);
  }

  // --- WebSocket Client ---
  Future<bool> connectClient(String url) async {
    await disconnectClient();
    _clientUrl = url;
    try {
      _clientSocket = await WebSocket.connect(url).timeout(const Duration(seconds: 4));
      _isClientConnected = true;
      _addMessage('Connected to $url', MessageSource.system);

      _clientSocket!.listen(
        (data) {
          _addMessage(data.toString(), MessageSource.server);
        },
        onDone: () {
          _isClientConnected = false;
          _addMessage('Connection closed by remote host', MessageSource.system);
        },
        onError: (err) {
          _isClientConnected = false;
          _addMessage('Connection error: $err', MessageSource.system);
        },
      );
      return true;
    } catch (e) {
      _isClientConnected = false;
      _addMessage('Failed to connect to $url: $e', MessageSource.system);
      return false;
    }
  }

  void sendClientMessage(String text) {
    if (_clientSocket != null && _isClientConnected) {
      _clientSocket!.add(text);
      _addMessage(text, MessageSource.client);
    } else {
      _addMessage('Cannot send: Client is not connected', MessageSource.system);
    }
  }

  Future<void> disconnectClient() async {
    if (_clientSocket != null) {
      await _clientSocket!.close();
      _clientSocket = null;
      _isClientConnected = false;
      _addMessage('Disconnected client', MessageSource.system);
    }
  }

  void clearMessages() {
    _messages.clear();
    _messagesController.add(
      SocketMessage(
        id: 'cleared',
        text: 'Message history cleared',
        source: MessageSource.system,
      ),
    );
  }

  // ── WebSocket APK install protocol helpers ─────────────────────────────
  void _prepareApkReceive(String controlMsg, WebSocket ws) {
    final parts = controlMsg.substring('INSTALL:'.length).split(':');
    if (parts.length < 2) { ws.add('ERROR:Invalid INSTALL command'); return; }
    _pendingApkName = parts[0];
    _pendingApkTotalSize = int.tryParse(parts[1]) ?? 0;
    _pendingApkBuffer.clear();
    final sizeKb = (_pendingApkTotalSize / 1024).toStringAsFixed(1);
    _addMessage('APK receive started: $_pendingApkName ($sizeKb KB)', MessageSource.system);
    ws.add('READY');
  }

  void _handleBinaryChunk(List<int> chunk, WebSocket ws) {
    _pendingApkBuffer.addAll(chunk);
    final received = _pendingApkBuffer.length;
    final total = _pendingApkTotalSize;
    if (total > 0) {
      final pct = ((received / total) * 100).clamp(0, 100).toInt();
      ws.add('PROGRESS:$pct');
    }
  }

  void _finalizeApkReceive(WebSocket ws) {
    if (_pendingApkBuffer.isEmpty || _pendingApkName.isEmpty) {
      ws.add('ERROR:No APK data buffered');
      return;
    }
    final bytes = List<int>.from(_pendingApkBuffer);
    final name = _pendingApkName;
    final sizeKb = (bytes.length / 1024).toStringAsFixed(1);
    _addMessage('APK received: $name ($sizeKb KB) — installing...', MessageSource.system);
    _pendingApkBuffer.clear();
    _pendingApkName = '';
    _pendingApkTotalSize = 0;

    ws.add('INSTALLING');
    if (apkInstallService != null) {
      apkInstallService!.enqueue(name, bytes).then((_) {
        ws.add('SUCCESS:$name');
      }).catchError((e) {
        ws.add('FAILED:$e');
      });
    } else {
      ws.add('FAILED:ApkInstallService not available');
    }
  }

  void dispose() {
    stopServer();
    disconnectClient();
    _messagesController.close();
  }
}
