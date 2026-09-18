import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class SelectedFileInfo {
  final String path;
  final String name;
  final int size;

  SelectedFileInfo({
    required this.path,
    required this.name,
    required this.size,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class FileTransferService {
  /// Pick files from local file system
  Future<List<SelectedFileInfo>> pickFiles({bool allowMultiple = true}) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (files.isEmpty) return [];

      return files
          .where((f) => f.path != null)
          .map((f) => SelectedFileInfo(
                path: f.path!,
                name: f.name,
                size: f.lengthSync() ?? 0,
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Upload file to target endpoint
  Future<bool> uploadFile({
    required String filePath,
    required String targetIp,
    required int targetPort,
    bool deleteAfterUpload = false,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    try {
      final uri = Uri.parse('http://$targetIp:$targetPort/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (deleteAfterUpload) {
          try {
            await file.delete();
          } catch (_) {}
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
