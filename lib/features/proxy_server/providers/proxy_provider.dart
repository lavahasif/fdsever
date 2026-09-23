import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/proxy_models.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/proxy_server_service.dart';
import '../../../core/services/storage_service.dart';

class ProxyServerProvider extends ChangeNotifier {
  final ProxyServerService _service;
  final NetworkService _networkService;

  String _host = '0.0.0.0';
  int _port = 8888;
  bool _isLoading = false;
  bool _isSearchingIps = false;
  String? _errorMessage;

  List<Map<String, String>> _systemIps = [];
  String _primaryIp = '127.0.0.1';

  // Filters for Traffic Inspector
  String _searchQuery = '';
  ProxyProtocol? _selectedProtocolFilter;
  bool _autoScrollLogs = true;

  // Refresh timer for stats (to update speed gauges smoothly)
  Timer? _metricsTimer;

  ProxyServerProvider(this._service, this._networkService, [StorageService? storageService]) {
    _service.logsStream.listen((_) => notifyListeners());

    // Load default preset rules
    _loadInitialRules();

    // Discover IPs immediately
    searchSystemIps();

    // Start 1-second ticker for live bandwidth / stats
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_service.isRunning) {
        notifyListeners();
      }
    });
  }

  // Getters
  bool get isRunning => _service.isRunning;
  String get host => _host;
  int get port => _port;
  bool get isLoading => _isLoading;
  bool get isSearchingIps => _isSearchingIps;
  String? get errorMessage => _errorMessage;
  List<Map<String, String>> get systemIps => List.unmodifiable(_systemIps);
  String get primaryIp => _primaryIp;

  ProxyAuth get auth => _service.auth;
  UpstreamProxy get upstream => _service.upstream;
  ThrottleProfile get throttle => _service.throttle;
  List<ProxyRule> get rules => _service.rules;
  bool get isBlocklistEnabled => _service.isBlocklistEnabled;
  ProxyStats get stats => _service.stats;

  String get searchQuery => _searchQuery;
  ProxyProtocol? get selectedProtocolFilter => _selectedProtocolFilter;
  bool get autoScrollLogs => _autoScrollLogs;

  /// Effective host for client connections
  String get effectiveIp {
    if (_host != '0.0.0.0' && _host.isNotEmpty) return _host;
    return _primaryIp != '127.0.0.1' ? _primaryIp : '127.0.0.1';
  }

  /// Single formatted primary proxy URL
  String get proxyAddress => '$effectiveIp:$_port';
  String get proxyUrl => 'http://$effectiveIp:$_port';
  String get pacUrl => 'http://$effectiveIp:$_port/proxy.pac';

  /// Setup command generators
  String get curlCommand => 'curl -x http://$effectiveIp:$_port https://httpbin.org/ip';
  String get gitCommand => 'git config --global http.proxy http://$effectiveIp:$_port';
  String get npmCommand => 'npm config set proxy http://$effectiveIp:$_port';
  String get powershellCommand => '\$env:HTTP_PROXY="http://$effectiveIp:$_port"; \$env:HTTPS_PROXY="http://$effectiveIp:$_port"';
  String get bashCommand => 'export http_proxy="http://$effectiveIp:$_port"; export https_proxy="http://$effectiveIp:$_port"';

  /// Filtered logs for traffic inspection
  List<ProxyLogEntry> get filteredLogs {
    final allLogs = _service.recentLogs;
    if (_searchQuery.isEmpty && _selectedProtocolFilter == null) {
      return allLogs;
    }

    final query = _searchQuery.toLowerCase();
    return allLogs.where((log) {
      if (_selectedProtocolFilter != null && log.protocol != _selectedProtocolFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesHost = log.host.toLowerCase().contains(query);
        final matchesMethod = log.method.toLowerCase().contains(query);
        final matchesClient = log.clientIp.toLowerCase().contains(query);
        final matchesPath = log.path.toLowerCase().contains(query);
        return matchesHost || matchesMethod || matchesClient || matchesPath;
      }
      return true;
    }).toList();
  }

  void _loadInitialRules() {
    _service.setRules([
      ProxyRule(
        id: 'rule_ad1',
        type: ProxyRuleType.block,
        pattern: '*.doubleclick.net',
        isEnabled: true,
      ),
      ProxyRule(
        id: 'rule_ad2',
        type: ProxyRuleType.block,
        pattern: '*.google-analytics.com',
        isEnabled: true,
      ),
      ProxyRule(
        id: 'rule_ad3',
        type: ProxyRuleType.block,
        pattern: 'telemetry.*',
        isEnabled: false,
      ),
    ]);
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

  void setSearchFilter(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setProtocolFilter(ProxyProtocol? protocol) {
    _selectedProtocolFilter = protocol;
    notifyListeners();
  }

  void toggleAutoScrollLogs() {
    _autoScrollLogs = !_autoScrollLogs;
    notifyListeners();
  }

  void clearLogs() {
    _service.clearLogs();
    notifyListeners();
  }

  Future<void> toggleServer() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (_service.isRunning) {
      await _service.stopServer();
    } else {
      await searchSystemIps();

      final success = await _service.startServer(
        host: _host,
        port: _port,
      );
      if (!success) {
        _errorMessage = 'Failed to bind proxy to $_host:$_port. Port may be in use by another service.';
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

  // --- Rule Management ---
  void addRule(ProxyRule rule) {
    final updated = List<ProxyRule>.from(_service.rules)..add(rule);
    _service.setRules(updated);
    notifyListeners();
  }

  void removeRule(String id) {
    final updated = List<ProxyRule>.from(_service.rules)..removeWhere((r) => r.id == id);
    _service.setRules(updated);
    notifyListeners();
  }

  void toggleRule(String id) {
    final updated = _service.rules.map((r) {
      if (r.id == id) {
        return r.copyWith(isEnabled: !r.isEnabled);
      }
      return r;
    }).toList();
    _service.setRules(updated);
    notifyListeners();
  }

  void setBlocklistEnabled(bool enabled) {
    _service.setBlocklistEnabled(enabled);
    notifyListeners();
  }

  void loadPopularAdBlockRules() {
    final popular = [
      '*.doubleclick.net',
      '*.google-analytics.com',
      '*.googletagmanager.com',
      '*.adnxs.com',
      '*.criteo.com',
      '*.scorecardresearch.com',
      '*.quantserve.com',
      '*.taboola.com',
      '*.outbrain.com',
      'ad.*',
      'ads.*',
      'track.*',
      'tracker.*',
      'telemetry.*',
    ];

    final existingPatterns = _service.rules.map((r) => r.pattern.toLowerCase()).toSet();
    final updated = List<ProxyRule>.from(_service.rules);

    for (final pattern in popular) {
      if (!existingPatterns.contains(pattern.toLowerCase())) {
        updated.add(ProxyRule(
          id: 'ad_${DateTime.now().millisecondsSinceEpoch}_${pattern.hashCode}',
          type: ProxyRuleType.block,
          pattern: pattern,
          isEnabled: true,
        ));
      }
    }

    _service.setRules(updated);
    _service.setBlocklistEnabled(true);
    notifyListeners();
  }

  // --- Super Proxy Configurations ---
  void updateAuth(ProxyAuth auth) {
    _service.setAuth(auth);
    notifyListeners();
  }

  void updateUpstream(UpstreamProxy upstream) {
    _service.setUpstream(upstream);
    notifyListeners();
  }

  void updateThrottle(ThrottleProfile throttle) {
    _service.setThrottle(throttle);
    notifyListeners();
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _service.dispose();
    super.dispose();
  }
}
