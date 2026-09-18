import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/whatsapp_service.dart';

class WhatsAppProvider extends ChangeNotifier {
  final WhatsAppService _service;
  final StorageService _storageService;

  String _phoneNumber = '';
  String _message = '';
  List<String> _recentNumbers = [];
  bool _isLoading = false;

  WhatsAppProvider(this._service, this._storageService) {
    _message = _storageService.getWhatsAppMessage();
    _recentNumbers = _storageService.getRecentNumbers();
  }

  String get phoneNumber => _phoneNumber;
  String get message => _message;
  List<String> get recentNumbers => _recentNumbers;
  bool get isLoading => _isLoading;

  void setPhoneNumber(String number) {
    _phoneNumber = number;
    notifyListeners();
  }

  void setMessage(String msg) {
    _message = msg;
    _storageService.setWhatsAppMessage(msg);
    notifyListeners();
  }

  void appendCountryCode(String code) {
    if (!_phoneNumber.startsWith(code)) {
      _phoneNumber = '$code$_phoneNumber';
      notifyListeners();
    }
  }

  Future<bool> launchChat({bool tryNative = true}) async {
    if (_phoneNumber.trim().isEmpty) return false;
    _isLoading = true;
    notifyListeners();

    final success = await _service.openChat(
      number: _phoneNumber,
      message: _message,
      tryNativeApp: tryNative,
    );

    if (success) {
      await _storageService.addRecentNumber(_phoneNumber);
      _recentNumbers = _storageService.getRecentNumbers();
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> clearHistory() async {
    await _storageService.clearRecentNumbers();
    _recentNumbers = [];
    notifyListeners();
  }
}
