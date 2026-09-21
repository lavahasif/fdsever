import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/file_transfer_service.dart';
import '../../../core/services/storage_service.dart';

class FileTransferProvider extends ChangeNotifier {
  final FileTransferService _service;
  final StorageService _storageService;

  List<SelectedFileInfo> _selectedFiles = [];
  String _destinationIp = AppConstants.defaultFavIp;
  int _destinationPort = int.parse(AppConstants.defaultPort);
  bool _deleteAfterUpload = false;
  bool _isUploading = false;
  String _uploadStatus = 'No file chosen';

  FileTransferProvider(this._service, this._storageService) {
    _destinationIp = _storageService.getFavIp();
    _deleteAfterUpload = _storageService.getDeleteAfterUpload();
  }

  List<SelectedFileInfo> get selectedFiles => _selectedFiles;
  String get destinationIp => _destinationIp;
  int get destinationPort => _destinationPort;
  bool get deleteAfterUpload => _deleteAfterUpload;
  bool get isUploading => _isUploading;
  String get uploadStatus => _uploadStatus;

  void setDestinationIp(String ip) {
    _destinationIp = ip;
    notifyListeners();
  }

  void setDestinationPort(int port) {
    _destinationPort = port;
    notifyListeners();
  }

  void setDeleteAfterUpload(bool value) {
    _deleteAfterUpload = value;
    _storageService.setDeleteAfterUpload(value);
    notifyListeners();
  }

  Future<void> pickFiles() async {
    final files = await _service.pickFiles();
    if (files.isNotEmpty) {
      _selectedFiles = files;
      _uploadStatus = '${files.length} file(s) selected';
      notifyListeners();
    }
  }

  void removeFile(int index) {
    if (index >= 0 && index < _selectedFiles.length) {
      _selectedFiles.removeAt(index);
      if (_selectedFiles.isEmpty) _uploadStatus = 'No file chosen';
      notifyListeners();
    }
  }

  void clearFiles() {
    _selectedFiles.clear();
    _uploadStatus = 'No file chosen';
    notifyListeners();
  }

  Future<void> uploadAll() async {
    if (_selectedFiles.isEmpty) return;

    _isUploading = true;
    int successCount = 0;
    notifyListeners();

    for (int i = 0; i < _selectedFiles.length; i++) {
      final file = _selectedFiles[i];
      _uploadStatus = 'Uploading (${i + 1}/${_selectedFiles.length}): ${file.name}...';
      notifyListeners();

      final success = await _service.uploadFile(
        filePath: file.path,
        targetIp: _destinationIp,
        targetPort: _destinationPort,
        deleteAfterUpload: _deleteAfterUpload,
      );

      if (success) successCount++;
    }

    _isUploading = false;
    _uploadStatus = 'Uploaded $successCount of ${_selectedFiles.length} file(s) successfully';
    if (successCount == _selectedFiles.length) {
      _selectedFiles.clear();
    }
    notifyListeners();
  }
}
