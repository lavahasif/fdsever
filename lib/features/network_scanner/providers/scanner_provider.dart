import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/network_device.dart';
import '../../../core/services/network_service.dart';

class ScannerProvider extends ChangeNotifier {
  final NetworkService _networkService;

  List<Map<String, String>> _interfaces = [];
  String _primaryIp = '127.0.0.1';
  String _targetIp = '127.0.0.1';
  int _targetPort = int.parse(AppConstants.defaultFavPort);
  bool _isScanning = false;
  String _scanStatus = 'Idle';

  final List<NetworkDevice> _scannedDevices = [];

  ScannerProvider(this._networkService) {
    refreshInterfaces();
  }

  List<Map<String, String>> get interfaces => _interfaces;
  String get primaryIp => _primaryIp;
  String get targetIp => _targetIp;
  int get targetPort => _targetPort;
  bool get isScanning => _isScanning;
  String get scanStatus => _scanStatus;
  List<NetworkDevice> get scannedDevices => List.unmodifiable(_scannedDevices);

  void setTargetIp(String ip) {
    _targetIp = ip;
    notifyListeners();
  }

  void setTargetPort(int port) {
    _targetPort = port;
    notifyListeners();
  }

  Future<void> refreshInterfaces() async {
    _interfaces = await _networkService.getLocalInterfaces();
    _primaryIp = await _networkService.getPrimaryIp();
    if (_targetIp == '127.0.0.1' && _primaryIp != '127.0.0.1') {
      _targetIp = _primaryIp;
    }
    notifyListeners();
  }

  /// Ping single target on targetPort
  Future<void> pingTarget() async {
    _isScanning = true;
    _scanStatus = 'Probing $_targetIp:$_targetPort...';
    notifyListeners();

    final isOpen = await _networkService.probePort(_targetIp, _targetPort);
    final device = NetworkDevice(
      ip: _targetIp,
      openPorts: {_targetPort: isOpen},
      isReachable: isOpen,
    );

    _scannedDevices.removeWhere((d) => d.ip == _targetIp);
    _scannedDevices.insert(0, device);

    _isScanning = false;
    _scanStatus = isOpen
        ? '$_targetIp:$_targetPort is OPEN'
        : '$_targetIp:$_targetPort is CLOSED / UNREACHABLE';
    notifyListeners();
  }

  /// Scan common ports on target IP
  Future<void> scanCommonPorts() async {
    _isScanning = true;
    _scanStatus = 'Scanning common ports on $_targetIp...';
    notifyListeners();

    final device = await _networkService.scanDevice(
      _targetIp,
      AppConstants.defaultScanPorts,
    );

    _scannedDevices.removeWhere((d) => d.ip == _targetIp);
    _scannedDevices.insert(0, device);

    final openCount = device.openPorts.values.where((v) => v).length;
    _isScanning = false;
    _scanStatus = 'Scan complete: $openCount open port(s) found on $_targetIp';
    notifyListeners();
  }

  /// Scan local subnet for active devices
  Future<void> scanSubnet({int? specificPort}) async {
    final port = specificPort ?? _targetPort;
    final parts = _primaryIp.split('.');
    if (parts.length != 4) return;
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    _isScanning = true;
    _scanStatus = 'Scanning subnet $subnet.* on port $port...';
    _scannedDevices.clear();
    notifyListeners();

    try {
      await for (final device in _networkService.scanSubnet(subnet, port, startHost: 1, endHost: 254)) {
        _scannedDevices.add(device);
        notifyListeners();
      }
    } catch (_) {}

    _isScanning = false;
    _scanStatus = 'Subnet scan finished. Found ${_scannedDevices.length} device(s).';
    notifyListeners();
  }

  void clearResults() {
    _scannedDevices.clear();
    _scanStatus = 'Results cleared';
    notifyListeners();
  }
}
