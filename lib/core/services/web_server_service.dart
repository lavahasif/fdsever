import 'dart:async';
import 'package:fdserver/core/services/apk_install_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import '../models/note_item.dart';

class ServerLogEntry {
  final DateTime timestamp;
  final String method;
  final String path;
  final int statusCode;
  final String clientIp;

  ServerLogEntry({
    required this.timestamp,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.clientIp,
  });
}

class WebServerService {
  HttpServer? _server;
  bool _isRunning = false;
  String _host = '0.0.0.0';
  int _port = 8081;

  final StreamController<ServerLogEntry> _logsController =
      StreamController<ServerLogEntry>.broadcast();
  final List<ServerLogEntry> _recentLogs = [];

  ApkInstallService? apkInstallService;
  bool get isRunning => _isRunning;
  String get host => _host;
  int get port => _port;
  String get url => 'http://$_host:$_port';
  Stream<ServerLogEntry> get logsStream => _logsController.stream;
  List<ServerLogEntry> get recentLogs => List.unmodifiable(_recentLogs);

  List<NoteItem> Function()? getNotesCallback;

  void _addLog(String method, String path, int statusCode, String clientIp) {
    final entry = ServerLogEntry(
      timestamp: DateTime.now(),
      method: method,
      path: path,
      statusCode: statusCode,
      clientIp: clientIp,
    );
    _recentLogs.insert(0, entry);
    if (_recentLogs.length > 50) _recentLogs.removeLast();
    _logsController.add(entry);
  }

  Future<bool> startServer({
    String host = '0.0.0.0',
    int port = 8081,
    List<NoteItem> Function()? notesProvider,
  }) async {
    if (_isRunning) await stopServer();

    _host = host;
    _port = port;
    getNotesCallback = notesProvider;

    try {
      final app = shelf_router.Router();

      // Root and Home
      app.get('/', (Request request) => _serveAssetHtml('assets/files/index.html', 'FDServer - Home'));
      app.get('/home', (Request request) => _serveAssetHtml('assets/files/index.html', 'FDServer - Home'));
      app.get('/bim', (Request request) => _serveAssetHtml('assets/files/bim.html', 'FDServer - BIM'));
      app.get('/upload', (Request request) => _serveAssetHtml('assets/files/upload.html', 'FDServer - Upload'));
      app.get('/bootstrap', (Request request) => _serveAssetHtml('assets/files/self.html', 'FDServer - Bootstrap'));

      // API Status
      app.get('/api/status', (Request request) {
        return Response.ok(
          json.encode({
            'status': 'online',
            'server': 'FDServer 5.0 (Flutter)',
            'timestamp': DateTime.now().toIso8601String(),
            'port': _port,
          }),
          headers: {'content-type': 'application/json'},
        );
      });

      // API Notes (JSON)
      app.get('/api/notes', (Request request) {
        final notes = getNotesCallback?.call() ?? [];
        return Response.ok(
          json.encode(notes.map((n) => n.toMap()).toList()),
          headers: {'content-type': 'application/json'},
        );
      });

      // HTML Notes view
      app.get('/notes', (Request request) => _serveAssetHtml('assets/files/index.html', 'FDServer - Notes'));

      // Files list
      app.get('/files', (Request request) => _serveAssetHtml('assets/files/index.html', 'FDServer - Files'));

      // 404 Route
      app.get('/n404', (Request request) => _serveAssetHtml('assets/files/404.html', 'FDServer - 404'));

      // API Upload handler
      
      // Easy Install APK route
      app.post('/api/install-apk', (Request request) async {
        try {
          final apkName = request.headers['x-apk-name'] ?? 'app_${DateTime.now().millisecondsSinceEpoch}.apk';
          final bodyBytes = await request.read().fold<List<int>>([], (a, b) => a..addAll(b));
          if (apkInstallService != null) {
            await apkInstallService!.enqueue(apkName, bodyBytes);
            return Response.ok(
              json.encode({
                'success': true,
                'name': apkName,
                'bytesReceived': bodyBytes.length,
                'message': 'APK queued for installation',
              }),
              headers: {'content-type': 'application/json'},
            );
          } else {
            return Response.internalServerError(
              body: json.encode({'error': 'ApkInstallService not configured on server'}),
              headers: {'content-type': 'application/json'},
            );
          }
        } catch (e) {
          return Response.internalServerError(
            body: json.encode({'error': e.toString()}),
            headers: {'content-type': 'application/json'},
          );
        }
      });

      app.post('/api/upload', (Request request) async {
        try {
          final bodyBytes = await request.read().fold<List<int>>([], (a, b) => a..addAll(b));
          return Response.ok(
            json.encode({
              'success': true,
              'bytesReceived': bodyBytes.length,
              'message': 'File uploaded successfully to FDServer',
            }),
            headers: {'content-type': 'application/json'},
          );
        } catch (e) {
          return Response.internalServerError(
            body: json.encode({'error': e.toString()}),
            headers: {'content-type': 'application/json'},
          );
        }
      });

      // Middleware for logging
      final handler = const Pipeline()
          .addMiddleware((innerHandler) {
            return (Request request) async {
              final clientIp = request.context['shelf.io.connection_info'] != null
                  ? (request.context['shelf.io.connection_info'] as dynamic).remoteAddress.address
                  : 'unknown';
              try {
                final response = await innerHandler(request);
                _addLog(request.method, request.url.path, response.statusCode, clientIp);
                return response;
              } catch (e) {
                _addLog(request.method, request.url.path, 500, clientIp);
                rethrow;
              }
            };
          })
          .addHandler(app.call);

      _server = await shelf_io.serve(handler, _host, _port);
      _server!.autoCompress = true;
      _isRunning = true;
      _addLog('SYSTEM', 'SERVER_START', 200, '$_host:$_port');
      return true;
    } catch (e) {
      _isRunning = false;
      _addLog('ERROR', 'START_FAILED: $e', 500, _host);
      return false;
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _isRunning = false;
      _addLog('SYSTEM', 'SERVER_STOPPED', 200, '$_host:$_port');
    }
  }

  Future<Response> _serveAssetHtml(String assetPath, String fallbackTitle) async {
    try {
      final html = await rootBundle.loadString(assetPath);
      return Response.ok(html, headers: {'content-type': 'text/html; charset=utf-8'});
    } catch (_) {
      return Response.ok(
        '<!DOCTYPE html><html><head><title>$fallbackTitle</title></head><body style="background:#09090b;color:#f4f4f5;font-family:sans-serif;padding:2rem;"><h1>$fallbackTitle</h1><p>FDServer running successfully on port $_port.</p><a href="/notes" style="color:#38bdf8;">View Notes</a> | <a href="/api/status" style="color:#38bdf8;">API Status</a></body></html>',
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    }
  }


  void dispose() {
    stopServer();
    _logsController.close();
  }
}


