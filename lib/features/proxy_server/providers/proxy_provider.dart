import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/models/proxy_models.dart';
import '../../../core/services/crash_log_service.dart';
import '../../../core/services/network_service.dart';
import '../../../core/services/power_service.dart';
import '../../../core/services/proxy_server_service.dart';
import '../../../core/services/reverse_proxy_service.dart';
import '../../../core/services/vpn_diverter_service.dart';

enum DiverterNetworkMode {
  hotspot,
  wifi,
}

class ProxyServerProvider extends ChangeNotifier {
  final ProxyServerService _service;
  final NetworkService _networkService;
  final ReverseProxyService _reverseProxyService;
  final PowerService? _powerService;
  final VpnDiverterService _vpnDiverterService;
  StreamSubscription? _batterySub;

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

  // Traffic Diverter (Hotspot / Super Proxy Client) State
  String _diverterHost = '192.168.43.1';
  int _diverterPort = 1080;
  String _diverterProtocol = 'SOCKS5';
  bool _diverterBypassLan = true;
  bool _isDiverterLoading = false;
  bool _isScanningProxy = false;
  String? _diverterError;
  DiscoveredProxy? _lastDiscoveredProxy;
  final List<DiscoveredProxy> _discoveredProxies = [];
  bool _diverterUseVpn = true;
  bool _isTestingProxy = false;
  String? _proxyTestResult;

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
    Object? serviceC,
    Object? serviceD,
  ])  : _reverseProxyService = (serviceA is ReverseProxyService
            ? serviceA
            : (serviceB is ReverseProxyService
                ? serviceB
                : (serviceC is ReverseProxyService
                    ? serviceC
                    : (serviceD is ReverseProxyService ? serviceD : null)))) ??
        ReverseProxyService(),
        _powerService = (serviceA is PowerService
            ? serviceA
            : (serviceB is PowerService
                ? serviceB
                : (serviceC is PowerService
                    ? serviceC
                    : (serviceD is PowerService ? serviceD : null)))),
        _vpnDiverterService = (serviceA is VpnDiverterService
            ? serviceA
            : (serviceB is VpnDiverterService
                ? serviceB
                : (serviceC is VpnDiverterService
                    ? serviceC
                    : (serviceD is VpnDiverterService ? serviceD : null)))) ??
        VpnDiverterService() {
    _service.logsStream.listen((_) => notifyListeners());
    _reverseProxyService.onLog = (entry) => _service.addExternalLog(entry);
    _batterySub = _powerService?.batteryOptimizationStream.listen((_) => notifyListeners());

    _vpnDiverterService.startTicker(() {
      notifyListeners();
    });

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

  bool get isIgnoringBattery => _powerService?.isIgnoringBattery ?? true;

  Future<bool> requestDisableBatteryOptimization() async {
    final res = await _powerService?.requestDisableBatteryOptimization() ?? false;
    notifyListeners();
    return res;
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
      await refreshNetworkEnvironment();
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
    try {
      CrashLogService().addBreadcrumb('ForwardProxy', _service.isRunning ? 'User stopping forward proxy' : 'User starting forward proxy on $_host:$_port');
      if (_service.isRunning) {
        await _service.stopServer();
        await _powerService?.releaseWakeLock('forward_proxy');
      } else {
        await searchSystemIps();

        final success = await _service.startServer(
          host: _host,
          port: _port,
        );
        if (!success) {
          _errorMessage = _service.lastError ?? 'Failed to bind proxy to $_host:$_port. Port may be in use by another service.';
          CrashLogService().recordManualError('ForwardProxyServer', _errorMessage!);
        } else {
          await _powerService?.acquireWakeLock('forward_proxy');
        }
      }
    } catch (e, stack) {
      _errorMessage = 'Proxy server error: $e';
      CrashLogService().recordManualError('ForwardProxyServer', e, stack);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> stopServer() async {
    if (_service.isRunning) {
      await _service.stopServer();
      await _powerService?.releaseWakeLock('forward_proxy');
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
    try {
      CrashLogService().addBreadcrumb('ReverseProxy', _reverseProxyService.isRunning ? 'User stopping reverse proxy' : 'User starting reverse proxy on $_reverseProxyHost:$_reverseProxyPort');
      if (_reverseProxyService.isRunning) {
        await _reverseProxyService.stopServer();
        await _powerService?.releaseWakeLock('reverse_proxy');
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
          CrashLogService().recordManualError('ReverseProxyGateway', _reverseProxyError!);
        } else {
          await _powerService?.acquireWakeLock('reverse_proxy');
          checkRouteHealth();
        }
      }
    } catch (e, stack) {
      _reverseProxyError = 'Reverse proxy error: $e';
      CrashLogService().recordManualError('ReverseProxyGateway', e, stack);
    }

    _isReverseProxyLoading = false;
    notifyListeners();
  }

  Future<void> stopReverseProxy() async {
    if (_reverseProxyService.isRunning) {
      await _reverseProxyService.stopServer();
      await _powerService?.releaseWakeLock('reverse_proxy');
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

  // ── Traffic Diverter (Hotspot & Wi-Fi Super Proxy Client) ────────────────
  DiverterNetworkMode _diverterNetworkMode = DiverterNetworkMode.hotspot;
  NetworkEnvironmentInfo _networkEnv = const NetworkEnvironmentInfo();

  DiverterNetworkMode get diverterNetworkMode => _diverterNetworkMode;
  NetworkEnvironmentInfo get networkEnv => _networkEnv;
  bool get isWifiConnected => _networkEnv.isWifiConnected;
  bool get isHotspotActive => _networkEnv.isHotspotActive;
  String? get detectedWifiIp => _networkEnv.wifiIp;
  String? get detectedWifiGateway => _networkEnv.wifiGateway;
  String? get detectedHotspotGateway => _networkEnv.hotspotGateway;

  Future<void> refreshNetworkEnvironment() async {
    try {
      _networkEnv = await _vpnDiverterService.getNetworkEnvironment();
      // Auto-detect mode if Wi-Fi is connected and user hasn't explicitly set host
      if (_networkEnv.isWifiConnected && !_networkEnv.isHotspotActive && _diverterHost == '192.168.43.1') {
        if (_networkEnv.wifiGateway != null) {
          _diverterNetworkMode = DiverterNetworkMode.wifi;
          _diverterHost = _networkEnv.wifiGateway!;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  void setDiverterNetworkMode(DiverterNetworkMode mode) {
    _diverterNetworkMode = mode;
    if (!_vpnDiverterService.isRunning) {
      if (mode == DiverterNetworkMode.wifi) {
        if (_networkEnv.wifiGateway != null && (_diverterHost == '192.168.43.1' || _diverterHost.isEmpty)) {
          _diverterHost = _networkEnv.wifiGateway!;
        }
      } else {
        if (_diverterHost == _networkEnv.wifiGateway || _diverterHost.isEmpty) {
          _diverterHost = _networkEnv.hotspotGateway ?? '192.168.43.1';
        }
      }
    }
    notifyListeners();
  }

  bool get isDiverterRunning => _vpnDiverterService.isRunning;
  String get diverterHost => _diverterHost;
  int get diverterPort => _diverterPort;
  String get diverterProtocol => _diverterProtocol;
  bool get diverterBypassLan => _diverterBypassLan;
  bool get isDiverterLoading => _isDiverterLoading;
  bool get isScanningProxy => _isScanningProxy;
  String? get diverterError => _diverterError;
  DiscoveredProxy? get lastDiscoveredProxy => _lastDiscoveredProxy;
  List<DiscoveredProxy> get discoveredProxies => List.unmodifiable(_discoveredProxies);

  void selectDiscoveredProxy(DiscoveredProxy proxy) {
    _lastDiscoveredProxy = proxy;
    _diverterHost = proxy.ip;
    _diverterPort = proxy.port;
    _diverterProtocol = proxy.protocol;
    notifyListeners();
  }

  /// Connects immediately to the selected discovered proxy.
  /// If the VPN diverter was already running on this proxy, toggles it off.
  /// If running on another proxy, seamlessly switches.
  Future<bool> connectToDiscoveredProxy(DiscoveredProxy proxy) async {
    final wasRunningSame = _vpnDiverterService.isRunning &&
        _diverterHost == proxy.ip &&
        _diverterPort == proxy.port &&
        _diverterProtocol.toUpperCase() == proxy.protocol.toUpperCase();

    _lastDiscoveredProxy = proxy;
    _diverterHost = proxy.ip;
    _diverterPort = proxy.port;
    _diverterProtocol = proxy.protocol;
    notifyListeners();

    if (wasRunningSame) {
      // Tapping the active proxy disconnects / stops
      return await toggleDiverter();
    }

    _isDiverterLoading = true;
    _diverterError = null;
    notifyListeners();

    if (_vpnDiverterService.isRunning) {
      // Disconnect previous tunnel before starting the new one
      await _vpnDiverterService.stopVpn();
      await _powerService?.releaseWakeLock('vpn_diverter');
    }

    bool result = false;
    try {
      CrashLogService().addBreadcrumb(
        'TrafficDiverter',
        'Connecting to discovered proxy: ${proxy.ip}:${proxy.port} (${proxy.protocol})',
      );
      result = await _vpnDiverterService.startVpn(
        host: _diverterHost,
        port: _diverterPort,
        protocol: _diverterProtocol,
        bypassLan: _diverterBypassLan,
      );
      if (result) {
        await _powerService?.acquireWakeLock('vpn_diverter');
      } else {
        _diverterError = _vpnDiverterService.lastError ?? 'Failed to connect to ${proxy.ip}:${proxy.port}.';
        CrashLogService().recordManualError('TrafficDiverter', _diverterError!);
      }
    } catch (e, stack) {
      _diverterError = 'VPN Diverter error: $e';
      CrashLogService().recordManualError('TrafficDiverter', e, stack);
    } finally {
      _isDiverterLoading = false;
      notifyListeners();
    }

    return result;
  }

  bool get diverterUseVpn => _diverterUseVpn;
  bool get isTestingProxy => _isTestingProxy;
  String? get proxyTestResult => _proxyTestResult;

  int get diverterBytesIn => _vpnDiverterService.bytesIn;
  int get diverterBytesOut => _vpnDiverterService.bytesOut;
  int get diverterDownloadSpeed => _vpnDiverterService.downloadSpeedBps;
  int get diverterUploadSpeed => _vpnDiverterService.uploadSpeedBps;

  void setDiverterUseVpn(bool useVpn) {
    _diverterUseVpn = useVpn;
    notifyListeners();
  }

  Future<void> testDiverterProxyConnection() async {
    _isTestingProxy = true;
    _proxyTestResult = null;
    notifyListeners();

    try {
      CrashLogService().addBreadcrumb(
        'TrafficDiverter',
        'Testing socket connectivity to $_diverterHost:$_diverterPort',
      );
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(_diverterHost, _diverterPort, timeout: const Duration(seconds: 4));
      sw.stop();
      await socket.close();
      _proxyTestResult = 'SUCCESS: Reachable in ${sw.elapsedMilliseconds}ms! Phone B is accepting connections on $_diverterHost:$_diverterPort.';
      CrashLogService().addBreadcrumb('TrafficDiverter', _proxyTestResult!);
    } catch (e) {
      _proxyTestResult = 'FAILED: Cannot connect to $_diverterHost:$_diverterPort ($e). Check that EveryProxy is running on Phone B and both phones are on the same hotspot.';
      CrashLogService().addBreadcrumb('TrafficDiverter', _proxyTestResult!);
    } finally {
      _isTestingProxy = false;
      notifyListeners();
    }
  }

  void setDiverterHost(String host) {
    _diverterHost = host.trim();
    notifyListeners();
  }

  void setDiverterPort(int port) {
    _diverterPort = port;
    notifyListeners();
  }

  void setDiverterProtocol(String protocol) {
    _diverterProtocol = protocol.toUpperCase();
    notifyListeners();
  }

  void setDiverterBypassLan(bool bypass) {
    _diverterBypassLan = bypass;
    notifyListeners();
  }

  Future<bool> toggleDiverter() async {
    _isDiverterLoading = true;
    _diverterError = null;
    notifyListeners();

    bool result = false;
    try {
      CrashLogService().addBreadcrumb(
        'TrafficDiverter',
        _vpnDiverterService.isRunning
            ? 'User stopping VPN diverter'
            : 'User starting VPN diverter (Target: $_diverterHost:$_diverterPort, Proto: $_diverterProtocol, BypassLan: $_diverterBypassLan)',
      );

      if (_vpnDiverterService.isRunning) {
        result = await _vpnDiverterService.stopVpn();
        await _powerService?.releaseWakeLock('vpn_diverter');
      } else {
        result = await _vpnDiverterService.startVpn(
          host: _diverterHost,
          port: _diverterPort,
          protocol: _diverterProtocol,
          bypassLan: _diverterBypassLan,
        );
        if (result) {
          await _powerService?.acquireWakeLock('vpn_diverter');
        } else {
          _diverterError = _vpnDiverterService.lastError ?? 'Failed to start VPN tunnel.';
          CrashLogService().recordManualError('TrafficDiverter', _diverterError!);
        }
      }
    } catch (e, stack) {
      _diverterError = 'VPN Diverter error: $e';
      CrashLogService().recordManualError('TrafficDiverter', e, stack);
    }

    _isDiverterLoading = false;
    notifyListeners();
    return result;
  }

  /// Fast-scans the network (Wi-Fi or Hotspot) for Phone B running EveryProxy/SuperProxy.
  /// Discovers all matching IPs, streams them into [discoveredProxies] in real-time,
  /// and automatically selects / connects.
  Future<bool> autoDiscoverAndConnectHotspot({bool autoConnect = true}) async {
    _isScanningProxy = true;
    _diverterError = null;
    _discoveredProxies.clear();
    notifyListeners();

    final String rememberedTarget = _diverterHost;
    final String? preferredSubnet = _diverterNetworkMode == DiverterNetworkMode.wifi && _networkEnv.wifiGateway != null
        ? _networkEnv.wifiGateway!.split('.').take(3).join('.')
        : null;

    try {
      CrashLogService().addBreadcrumb('TrafficDiverter', 'Initiating multi-network (${_diverterNetworkMode.name}) auto-discovery');
      final list = await _vpnDiverterService.discoverAllProxies(
        preferredSubnet: preferredSubnet,
        lastKnownHost: rememberedTarget,
        onFound: (proxy) {
          _discoveredProxies.add(proxy);
          // Priority selection:
          // 1. Exact match with user's configured/remembered host (e.g. Phone B)
          // 2. SOCKS5 over HTTP
          // 3. First found
          final isMatchesRemembered = proxy.ip == rememberedTarget;
          final isUpgradeToSocks = _diverterProtocol.toUpperCase() != 'SOCKS5' && proxy.protocol.toUpperCase() == 'SOCKS5';
          final isFirst = _discoveredProxies.length == 1;

          if (isMatchesRemembered || isUpgradeToSocks || isFirst) {
            _lastDiscoveredProxy = proxy;
            _diverterHost = proxy.ip;
            _diverterPort = proxy.port;
            _diverterProtocol = proxy.protocol;
          }
          notifyListeners();
        },
      );

      if (list.isNotEmpty) {
        CrashLogService().addBreadcrumb('TrafficDiverter', 'Found ${list.length} proxy endpoints on subnet');
        if (autoConnect && !isDiverterRunning) {
          // Auto-connect to the selected proxy
          return await toggleDiverter();
        }
        return true;
      } else {
        _diverterError = _diverterNetworkMode == DiverterNetworkMode.wifi
            ? 'No proxy server found on local Wi-Fi. Ensure EveryProxy is running on the other device on the same Wi-Fi network.'
            : 'No proxy server found on hotspot. Ensure EveryProxy is running on the other phone and connected to the hotspot.';
        CrashLogService().addBreadcrumb('TrafficDiverter', 'Auto-discovery finished: No proxy detected on network');
      }
    } catch (e, stack) {
      _diverterError = 'Scan error: $e';
      CrashLogService().recordManualError('TrafficDiverterScan', e, stack);
    } finally {
      _isScanningProxy = false;
      notifyListeners();
    }

    return false;
  }

  List<String> get diverterLogs => _vpnDiverterService.recentLogs;

  Future<void> refreshDiverterLogs() async {
    await _vpnDiverterService.fetchVpnLogs();
    notifyListeners();
  }

  Future<void> clearDiverterLogs() async {
    await _vpnDiverterService.clearVpnLogs();
    notifyListeners();
  }

  String getFormattedDiverterDiagnosticReport() {
    final buffer = StringBuffer();
    buffer.writeln('### 📡 FDServer Traffic Diverter Diagnostic Report');
    buffer.writeln('**Generated at:** ${DateTime.now().toIso8601String()}');
    buffer.writeln('**Diverter Status:** ${isDiverterRunning ? "🟢 RUNNING (VPN ON)" : "⚪ STOPPED"}');
    buffer.writeln('**Target Host:** $_diverterHost');
    buffer.writeln('**Target Port:** $_diverterPort');
    buffer.writeln('**Protocol:** $_diverterProtocol');
    buffer.writeln('**Bypass LAN:** $_diverterBypassLan');
    buffer.writeln('**VPN Mode Enabled:** $_diverterUseVpn');
    buffer.writeln('**Bytes Transferred:** In: $diverterBytesIn B | Out: $diverterBytesOut B');
    if (_diverterError != null) {
      buffer.writeln('**Last Error:** `$_diverterError`');
    }
    if (_proxyTestResult != null) {
      buffer.writeln('**Socket Test Result:** `$_proxyTestResult`');
    }
    buffer.writeln('');
    buffer.writeln('#### 📜 Native VPN Log Trace:');
    if (diverterLogs.isEmpty) {
      buffer.writeln('_No logs recorded yet. Start the Traffic Diverter to capture network packets._');
    } else {
      buffer.writeln('```text');
      for (final line in diverterLogs) {
        buffer.writeln(line);
      }
      buffer.writeln('```');
    }
    return buffer.toString();
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
    _batterySub?.cancel();
    _powerService?.releaseWakeLock('forward_proxy');
    _powerService?.releaseWakeLock('reverse_proxy');
    _powerService?.releaseWakeLock('vpn_diverter');
    _vpnDiverterService.dispose();
    _metricsTimer?.cancel();
    _service.dispose();
    _reverseProxyService.dispose();
    super.dispose();
  }
}
