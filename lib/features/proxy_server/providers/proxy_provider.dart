import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/proxy_models.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/proxy_server_service.dart';
import '../../../core/services/reverse_proxy_service.dart';

class ProxyServerProvider extends ChangeNotifier {
  final ProxyServerService _service;
  final NetworkService _networkService;
  final ReverseProxyService _reverseProxyService;

  String _host = '0.0.0.0';
  int _port = 8888;
  bool _isLoading = false;
  bool _isSearchingIps = false;
  String? _errorMessage;

  // Reverse Proxy State
  String _reverseProxyHost = '0.0.0.0';
  int _reverseProxyPort = 8080;
  bool _isReverseProxyLoading = false;
  String? _reverseProxyError;
  List<ReverseProxyRoute> _reverseProxyRoutes = [];
  bool _isCheckingHealth = false;

  List<Map<String, String>> _systemIps = [];
  String _primaryIp = '127.0.0.1';

  // Filters for Traffic Inspector
  String _searchQuery = '';
  ProxyProtocol? _selectedProtocolFilter;
  bool _autoScrollLogs = true;

  // Refresh timer for stats (to update speed gauges smoothly)
  Timer? _metricsTimer;

  ProxyServerProvider(
    this._service,
    this._networkService, [
    Object? serviceA,
    Object? serviceB,
  ]) : _reverseProxyService = (serviceA is ReverseProxyService
            ? serviceA
            : (serviceB is ReverseProxyService ? serviceB : null)) ??
        ReverseProxyService() {
    _service.logsStream.listen((_) => notifyListeners());
    _reverseProxyService.onLog = (entry) => _service.addExternalLog(entry);

    // Load default preset rules and reverse proxy routes
    _loadInitialRules();
    _loadInitialReverseRoutes();

    // Discover IPs immediately
    searchSystemIps();

    // Start 1-second ticker for live bandwidth / stats
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_service.isRunning || _reverseProxyService.isRunning) {
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

  // --- Reverse Proxy Getters ---
  bool get isReverseProxyRunning => _reverseProxyService.isRunning;
  String get reverseProxyHost => _reverseProxyHost;
  int get reverseProxyPort => _reverseProxyPort;
  bool get isReverseProxyLoading => _isReverseProxyLoading;
  String? get reverseProxyError => _reverseProxyError;
  List<ReverseProxyRoute> get reverseProxyRoutes => List.unmodifiable(_reverseProxyRoutes);
  bool get isCheckingHealth => _isCheckingHealth;

  String get effectiveReverseProxyIp {
    if (_reverseProxyHost != '0.0.0.0' && _reverseProxyHost.isNotEmpty) return _reverseProxyHost;
    return _primaryIp != '127.0.0.1' ? _primaryIp : '127.0.0.1';
  }

  String get reverseProxyUrl => 'http://$effectiveReverseProxyIp:$_reverseProxyPort';

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

  // --- Reverse Proxy Operations ---
  void _loadInitialReverseRoutes() {
    _reverseProxyRoutes = [
      const ReverseProxyRoute(
        id: 'rev_odoo',
        name: 'Odoo ERP Suite',
        pathPrefix: '/odoo',
        targetHost: '127.0.0.1',
        targetPort: 8069,
        stripPrefix: false,
        isEnabled: true,
      ),
      const ReverseProxyRoute(
        id: 'rev_web',
        name: 'Local Web Server',
        pathPrefix: '/',
        targetHost: '127.0.0.1',
        targetPort: 8081,
        stripPrefix: false,
        isEnabled: false,
      ),
    ];
    _reverseProxyService.setRoutes(_reverseProxyRoutes);
  }

  void setReverseProxyHost(String host) {
    _reverseProxyHost = host;
    notifyListeners();
  }

  void setReverseProxyPort(int port) {
    _reverseProxyPort = port;
    notifyListeners();
  }

  Future<void> toggleReverseProxy() async {
    _isReverseProxyLoading = true;
    _reverseProxyError = null;
    notifyListeners();

    if (_reverseProxyService.isRunning) {
      await _reverseProxyService.stopServer();
    } else {
      await searchSystemIps();
      _reverseProxyService.setRoutes(_reverseProxyRoutes);
      final success = await _reverseProxyService.startServer(
        host: _reverseProxyHost,
        port: _reverseProxyPort,
      );
      if (!success) {
        _reverseProxyError =
            'Failed to bind reverse proxy on $_reverseProxyHost:$_reverseProxyPort. Port may be in use.';
      } else {
        checkRouteHealth();
      }
    }

    _isReverseProxyLoading = false;
    notifyListeners();
  }

  Future<void> stopReverseProxy() async {
    if (_reverseProxyService.isRunning) {
      await _reverseProxyService.stopServer();
      notifyListeners();
    }
  }

  void addReverseProxyRoute(ReverseProxyRoute route) {
    _reverseProxyRoutes.add(route);
    _reverseProxyService.setRoutes(_reverseProxyRoutes);
    notifyListeners();
    checkRouteHealth();
  }

  void removeReverseProxyRoute(String id) {
    _reverseProxyRoutes.removeWhere((r) => r.id == id);
    _reverseProxyService.setRoutes(_reverseProxyRoutes);
    notifyListeners();
  }

  void toggleReverseProxyRoute(String id) {
    _reverseProxyRoutes = _reverseProxyRoutes.map((r) {
      if (r.id == id) {
        return r.copyWith(isEnabled: !r.isEnabled);
      }
      return r;
    }).toList();
    _reverseProxyService.setRoutes(_reverseProxyRoutes);
    notifyListeners();
  }

  Future<void> checkRouteHealth() async {
    _isCheckingHealth = true;
    notifyListeners();
    try {
      final healthMap = await _reverseProxyService.checkRoutesHealth();
      _reverseProxyRoutes = _reverseProxyRoutes.map((r) {
        if (healthMap.containsKey(r.id)) {
          return r.copyWith(isHealthy: healthMap[r.id]);
        }
        return r;
      }).toList();
    } catch (_) {}
    _isCheckingHealth = false;
    notifyListeners();
  }

  void loadOdooPresetRoute() {
    final hasOdoo = _reverseProxyRoutes.any((r) => r.targetPort == 8069 && r.pathPrefix == '/odoo');
    if (!hasOdoo) {
      addReverseProxyRoute(const ReverseProxyRoute(
        id: 'rev_odoo_8069',
        name: 'Odoo ERP Suite',
        pathPrefix: '/odoo',
        targetHost: '127.0.0.1',
        targetPort: 8069,
        stripPrefix: false,
        isEnabled: true,
      ));
    }
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _metricsTimer?.cancel();
    _service.dispose();
    _reverseProxyService.dispose();
    super.dispose();
  }
}
