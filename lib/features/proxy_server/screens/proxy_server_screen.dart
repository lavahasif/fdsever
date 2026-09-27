import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/models/proxy_models.dart';
import '../../../core/services/crash_log_service.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../diagnostics/screens/crash_logs_screen.dart';
import '../providers/proxy_provider.dart';

class ProxyServerScreen extends StatefulWidget {
  final int initialTabIndex;

  const ProxyServerScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ProxyServerScreen> createState() => _ProxyServerScreenState();
}

class _ProxyServerScreenState extends State<ProxyServerScreen> with SingleTickerProviderStateMixin {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _searchController;
  late final TabController _tabController;

  // Reverse Proxy controllers
  late final TextEditingController _reverseHostController;
  late final TextEditingController _reversePortController;

  // Add Reverse Route controllers
  final _routeNameController = TextEditingController();
  final _routePathPrefixController = TextEditingController(text: '/odoo');
  final _routeTargetHostController = TextEditingController(text: '127.0.0.1');
  final _routeTargetPortController = TextEditingController(text: '8069');
  bool _routeStripPrefix = false;

  // New rule dialog controllers
  final _rulePatternController = TextEditingController();
  final _ruleTargetHostController = TextEditingController();
  final _ruleTargetPortController = TextEditingController();
  ProxyRuleType _ruleType = ProxyRuleType.block;

  // Auth controllers
  final _authUsernameController = TextEditingController();
  final _authPasswordController = TextEditingController();

  // Upstream controllers
  final _upstreamHostController = TextEditingController();
  final _upstreamPortController = TextEditingController(text: '8080');
  final _upstreamUserController = TextEditingController();
  final _upstreamPassController = TextEditingController();

  // Traffic Diverter controllers
  late final TextEditingController _diverterHostController;
  late final TextEditingController _diverterPortController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProxyServerProvider>();
    _hostController = TextEditingController(text: provider.host);
    _portController = TextEditingController(text: provider.port.toString());
    _reverseHostController = TextEditingController(text: provider.reverseProxyHost);
    _reversePortController = TextEditingController(text: provider.reverseProxyPort.toString());
    _diverterHostController = TextEditingController(text: provider.diverterHost);
    _diverterPortController = TextEditingController(text: provider.diverterPort.toString());
    _searchController = TextEditingController(text: provider.searchQuery);
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 5),
    );

    _authUsernameController.text = provider.auth.username;
    _authPasswordController.text = provider.auth.password;

    _upstreamHostController.text = provider.upstream.host;
    _upstreamPortController.text = provider.upstream.port.toString();
    _upstreamUserController.text = provider.upstream.username;
    _upstreamPassController.text = provider.upstream.password;

    // Check health of backends on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.checkRouteHealth();
    });
  }

  @override
  void didUpdateWidget(covariant ProxyServerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex.clamp(0, 5));
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _reverseHostController.dispose();
    _reversePortController.dispose();
    _diverterHostController.dispose();
    _diverterPortController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    _routeNameController.dispose();
    _routePathPrefixController.dispose();
    _routeTargetHostController.dispose();
    _routeTargetPortController.dispose();
    _rulePatternController.dispose();
    _ruleTargetHostController.dispose();
    _ruleTargetPortController.dispose();
    _authUsernameController.dispose();
    _authPasswordController.dispose();
    _upstreamHostController.dispose();
    _upstreamPortController.dispose();
    _upstreamUserController.dispose();
    _upstreamPassController.dispose();
    super.dispose();
  }

  void _selectIp(String ip, ProxyServerProvider provider) {
    _hostController.text = ip;
    provider.setHost(ip);
  }

  void _selectReverseIp(String ip, ProxyServerProvider provider) {
    _reverseHostController.text = ip;
    provider.setReverseProxyHost(ip);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ShadToaster.of(context).show(
      ShadToast(
        title: Text('$label Copied'),
        description: Text(text),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final proxy = context.watch<ProxyServerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_hostController.text != proxy.host && !proxy.isRunning) {
      _hostController.text = proxy.host;
    }
    if (_reverseHostController.text != proxy.reverseProxyHost && !proxy.isReverseProxyRunning) {
      _reverseHostController.text = proxy.reverseProxyHost;
    }
    if (_diverterHostController.text != proxy.diverterHost && !proxy.isDiverterRunning) {
      _diverterHostController.text = proxy.diverterHost;
    }
    if (_diverterPortController.text != proxy.diverterPort.toString() && !proxy.isDiverterRunning) {
      _diverterPortController.text = proxy.diverterPort.toString();
    }

    // Determine aggregate status label
    String activeLabel = 'PROXY RUNNING';
    final bool isAnyActive = proxy.isRunning || proxy.isReverseProxyRunning || proxy.isDiverterRunning;
    if (proxy.isDiverterRunning && (proxy.isRunning || proxy.isReverseProxyRunning)) {
      activeLabel = 'PROXY & TUNNEL ON';
    } else if (proxy.isDiverterRunning) {
      activeLabel = 'VPN TUNNEL ON';
    } else if (proxy.isRunning && proxy.isReverseProxyRunning) {
      activeLabel = 'DUAL PROXIES ON';
    } else if (proxy.isReverseProxyRunning) {
      activeLabel = 'REVERSE PROXY ON';
    } else if (proxy.isRunning) {
      activeLabel = 'FORWARD PROXY ON';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Sub-navigation tab bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 540;
              return Container(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: isDark ? Colors.white : Colors.black87,
                    unselectedLabelColor: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    indicatorColor: const Color(0xFF3B82F6),
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(
                        child: Row(
                          children: [
                            const Icon(LucideIcons.gauge, size: 16),
                            const SizedBox(width: 8),
                            const Text('Forward Proxy'),
                            if (proxy.isRunning) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          children: [
                            const Icon(LucideIcons.network, size: 16),
                            const SizedBox(width: 8),
                            const Text('Reverse Proxy'),
                            if (proxy.isReverseProxyRunning) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            if (proxy.reverseProxyRoutes.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${proxy.reverseProxyRoutes.where((r) => r.isEnabled).length}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          children: [
                            const Icon(LucideIcons.arrowRightLeft, size: 16),
                            const SizedBox(width: 8),
                            const Text('Traffic Diverter'),
                            if (proxy.isDiverterRunning) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          children: [
                            const Icon(LucideIcons.activity, size: 16),
                            const SizedBox(width: 8),
                            const Text('Traffic Inspector'),
                            if (proxy.stats.totalRequests > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${proxy.stats.totalRequests}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          children: [
                            const Icon(LucideIcons.shieldCheck, size: 16),
                            const SizedBox(width: 8),
                            const Text('Super Proxy Rules'),
                            if (proxy.rules.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: proxy.isBlocklistEnabled
                                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                      : Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${proxy.rules.length}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: proxy.isBlocklistEnabled ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          children: [
                            Icon(LucideIcons.smartphone, size: 16),
                            SizedBox(width: 8),
                            Text('Client Setup & PAC'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                        if (!isCompact)
                          StatusBadge(
                            isActive: isAnyActive,
                            activeLabel: activeLabel,
                            inactiveLabel: 'PROXIES STOPPED',
                          )
                        else
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isAnyActive ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isAnyActive ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAnyActive ? 'ON' : 'OFF',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isAnyActive ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

          // Main Tabs Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(context, proxy, isDark),
                _buildReverseProxyTab(context, proxy, isDark),
                _buildTrafficDiverterTab(context, proxy, isDark),
                _buildTrafficInspectorTab(context, proxy, isDark),
                _buildRulesAndFeaturesTab(context, proxy, isDark),
                _buildClientSetupTab(context, proxy, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: DASHBOARD & FORWARD PROXY
  // ==========================================

  Widget _buildDashboardTab(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Forward Proxy Server',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Universal Multi-Protocol Outbound Gateway (HTTP, HTTPS CONNECT, SOCKS5, and PAC Auto-Discovery).',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Error Alert with 1-Tap Copy for AI
          if (proxy.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.triangleAlert, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      const Text('Forward Proxy Server Error', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13)),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          final prompt = CrashLogService().generateFullDiagnosticsAiPrompt();
                          Clipboard.setData(ClipboardData(text: prompt));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied full AI Diagnostic report to clipboard! Ready to paste into AI.'),
                              backgroundColor: Color(0xFF18181B),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(LucideIcons.copy, size: 12),
                        label: const Text('Copy for AI', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CrashLogsScreen()),
                          );
                        },
                        child: const Text('Logs', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(proxy.errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Battery Optimization Alert Banner
          if (!proxy.isIgnoringBattery) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.triangleAlert, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Battery Optimization Active',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B)),
                        ),
                        Text(
                          'Android may sleep CPU or pause proxy traffic when the screen dies. Remove optimization for 24/7 uptime.',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ShadButton(
                    size: ShadButtonSize.sm,
                    onPressed: () => proxy.requestDisableBatteryOptimization(),
                    child: const Text('Disable'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Hero Status Card
          _buildHeroCard(context, proxy, isDark),

          const SizedBox(height: 20),

          // Live Metrics Counters Row
          _buildLiveMetricsCards(context, proxy, isDark),

          const SizedBox(height: 20),

          // Automatic IP Discovery & Binding Card
          _buildIpDiscoveryCard(context, proxy, isDark),

          const SizedBox(height: 20),

          // Supported Protocols Banner
          _buildProtocolsBanner(context, isDark),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: proxy.isRunning
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  proxy.isRunning ? LucideIcons.shieldCheck : LucideIcons.shieldAlert,
                  color: proxy.isRunning ? const Color(0xFF10B981) : Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          proxy.isRunning ? 'Forward Proxy is Active & Forwarding' : 'Forward Proxy is Offline',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: proxy.isRunning
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            proxy.isRunning ? 'LISTENING' : 'STANDBY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: proxy.isRunning ? const Color(0xFF10B981) : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      proxy.isRunning
                          ? 'Clients can connect to ${proxy.proxyAddress} (HTTP / HTTPS / SOCKS5)'
                          : 'Configure IP and Port below, then start the proxy gateway.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),

          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ShadButton(
                onPressed: proxy.isLoading ? null : () => proxy.toggleServer(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (proxy.isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      Icon(proxy.isRunning ? LucideIcons.square : LucideIcons.play, size: 16),
                    const SizedBox(width: 8),
                    Text(proxy.isRunning ? 'Stop Forward Proxy' : 'Start Forward Proxy'),
                  ],
                ),
              ),
              if (proxy.isRunning) ...[
                ShadButton.outline(
                  onPressed: () => _copyToClipboard(proxy.proxyAddress, 'Proxy Address'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.copy, size: 15),
                      SizedBox(width: 6),
                      Text('Copy IP:Port'),
                    ],
                  ),
                ),
                ShadButton.outline(
                  onPressed: () => _copyToClipboard(proxy.pacUrl, 'PAC Script URL'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.fileCode, size: 15),
                      SizedBox(width: 6),
                      Text('Copy PAC URL'),
                    ],
                  ),
                ),
                ShadButton.ghost(
                  onPressed: () => _tabController.animateTo(2),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.activity, size: 15),
                      SizedBox(width: 6),
                      Text('View Live Traffic →'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMetricsCards(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    final stats = proxy.stats;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 550 ? 3 : 2);
        final childAspectRatio = constraints.maxWidth < 550 ? 1.45 : (constraints.maxWidth < 900 ? 1.6 : 1.8);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            _buildMetricTile(
              title: 'Total Requests',
              value: '${stats.totalRequests}',
              subtitle: 'HTTP: ${stats.httpRequests} • S5: ${stats.socks5Requests}',
              icon: LucideIcons.arrowUpDown,
              color: const Color(0xFF3B82F6),
              isDark: isDark,
            ),
            _buildMetricTile(
              title: 'Active Sockets',
              value: '${stats.activeConnections}',
              subtitle: 'Live tunnels',
              icon: LucideIcons.radio,
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            _buildMetricTile(
              title: 'Throughput Speed',
              value: '${stats.currentSpeedInKbps.toStringAsFixed(1)} Kbps',
              subtitle: 'Up: ${stats.currentSpeedOutKbps.toStringAsFixed(1)} Kbps',
              icon: LucideIcons.gauge,
              color: const Color(0xFFF59E0B),
              isDark: isDark,
            ),
            _buildMetricTile(
              title: 'Total Transferred',
              value: _formatBytes(stats.totalBytesIn + stats.totalBytesOut),
              subtitle: 'In: ${_formatBytes(stats.totalBytesIn)}',
              icon: LucideIcons.database,
              color: const Color(0xFF8B5CF6),
              isDark: isDark,
            ),
            _buildMetricTile(
              title: 'Blocked / Filtered',
              value: '${stats.blockedRequests}',
              subtitle: proxy.isBlocklistEnabled ? 'Ad/Rule Shield On' : 'Filter Disabled',
              icon: LucideIcons.shieldAlert,
              color: const Color(0xFFEF4444),
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIpDiscoveryCard(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    return ShadCard(
      title: Row(
        children: [
          const Icon(LucideIcons.network, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Automatic IP Discovery & Binding (${proxy.systemIps.length} interfaces)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            onPressed: proxy.isSearchingIps ? null : () => proxy.searchSystemIps(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.refreshCw,
                  size: 14,
                  color: proxy.isSearchingIps ? Colors.grey : Colors.blue,
                ),
                const SizedBox(width: 6),
                Text(
                  proxy.isSearchingIps ? 'Scanning...' : 'Refresh',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      description: const Text(
        'Select an auto-detected network interface to bind, or select 0.0.0.0 to listen on all WiFi/Ethernet adapters.',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IP Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 0.0.0.0 (All Interfaces)
                InkWell(
                  onTap: proxy.isRunning ? null : () => _selectIp('0.0.0.0', proxy),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: proxy.host == '0.0.0.0'
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: proxy.host == '0.0.0.0' ? const Color(0xFF3B82F6) : const Color(0xFF27272A),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.globe,
                          size: 15,
                          color: proxy.host == '0.0.0.0' ? const Color(0xFF3B82F6) : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '0.0.0.0 (All Adapters)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // System interface IPs
                for (final iface in proxy.systemIps)
                  InkWell(
                    onTap: proxy.isRunning ? null : () => _selectIp(iface['address'] ?? '', proxy),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: proxy.host == iface['address']
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: proxy.host == iface['address']
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF27272A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            iface['isLoopback'] == 'true' ? LucideIcons.laptop : LucideIcons.wifi,
                            size: 14,
                            color: proxy.host == iface['address'] ? const Color(0xFF3B82F6) : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${iface['address']} (${iface['name']})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // Manual Host & Port inputs
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bind Host / IP (Manual)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ShadInput(
                        controller: _hostController,
                        enabled: !proxy.isRunning,
                        placeholder: const Text('e.g. 0.0.0.0 or 192.168.1.100'),
                        onChanged: (val) => proxy.setHost(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Forward Proxy Port', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ShadInput(
                        controller: _portController,
                        enabled: !proxy.isRunning,
                        placeholder: const Text('8888'),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          final p = int.tryParse(val);
                          if (p != null && p > 0 && p <= 65535) {
                            proxy.setPort(p);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Quick Port Presets
            if (!proxy.isRunning)
              Row(
                children: [
                  const Text('Common Ports: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  for (final port in [8888, 8080, 1080, 3128, 8000]) ...[
                    InkWell(
                      onTap: () {
                        _portController.text = port.toString();
                        proxy.setPort(port);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: proxy.port == port
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$port',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: proxy.port == port ? FontWeight.bold : FontWeight.normal,
                            color: proxy.port == port ? const Color(0xFF3B82F6) : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolsBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Supported Proxy Protocols & Architecture',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildProtocolBadge('HTTP Proxy', 'Standard GET/POST forward forwarding', LucideIcons.globe, Colors.blue),
              _buildProtocolBadge('HTTPS CONNECT', 'Raw TCP tunneling with SSL/TLS passthrough', LucideIcons.lock, Colors.green),
              _buildProtocolBadge('SOCKS5 (RFC 1928)', 'Dual-handshake auto-detected on same port', LucideIcons.layers, Colors.purple),
              _buildProtocolBadge('PAC File', 'Served dynamically at /proxy.pac for auto-config', LucideIcons.fileCode, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolBadge(String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              Text(desc, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: REVERSE PROXY GATEWAY
  // ==========================================

  Widget _buildReverseProxyTab(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reverse Proxy Gateway',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expose internal servers (e.g. Odoo ERP on 8069, APIs, web apps) to other devices on the LAN via path routes.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Error alert
          if (proxy.reverseProxyError != null) ...[
            ShadAlert.destructive(
              icon: const Icon(LucideIcons.triangleAlert, size: 16),
              title: const Text('Reverse Proxy Error'),
              description: Text(proxy.reverseProxyError!),
            ),
            const SizedBox(height: 16),
          ],

          // Battery Optimization Alert Banner
          if (!proxy.isIgnoringBattery) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.triangleAlert, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Battery Optimization Active',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B)),
                        ),
                        Text(
                          'Android may pause reverse proxy routes when the screen dies. Remove optimization for 24/7 uptime.',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ShadButton(
                    size: ShadButtonSize.sm,
                    onPressed: () => proxy.requestDisableBatteryOptimization(),
                    child: const Text('Disable'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Reverse Proxy Error Alert
          if (proxy.reverseProxyError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.triangleAlert, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      const Text('Reverse Proxy Gateway Error', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13)),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          final prompt = CrashLogService().generateFullDiagnosticsAiPrompt();
                          Clipboard.setData(ClipboardData(text: prompt));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied full AI Diagnostic report to clipboard! Ready to paste into AI.'),
                              backgroundColor: Color(0xFF18181B),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(LucideIcons.copy, size: 12),
                        label: const Text('Copy for AI', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CrashLogsScreen()),
                          );
                        },
                        child: const Text('Logs', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(proxy.reverseProxyError!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Reverse Proxy Hero Card
          _buildReverseHeroCard(context, proxy, isDark),

          const SizedBox(height: 20),

          // Backend Routes Management Card
          _buildReverseRoutesCard(context, proxy, isDark),

          const SizedBox(height: 20),

          // Reverse Proxy Network & Port Binding Card
          _buildReverseIpCard(context, proxy, isDark),

          const SizedBox(height: 20),

          // How Reverse Proxy Works Card
          _buildReverseProxyExplainerCard(context, proxy, isDark),
        ],
      ),
    );
  }

  Widget _buildReverseHeroCard(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: proxy.isReverseProxyRunning
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  proxy.isReverseProxyRunning ? LucideIcons.network : LucideIcons.serverOff,
                  color: proxy.isReverseProxyRunning ? const Color(0xFF10B981) : Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          proxy.isReverseProxyRunning ? 'Reverse Gateway is Live' : 'Reverse Proxy is Stopped',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: proxy.isReverseProxyRunning
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            proxy.isReverseProxyRunning ? 'ACTIVE' : 'STANDBY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: proxy.isReverseProxyRunning ? const Color(0xFF10B981) : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      proxy.isReverseProxyRunning
                          ? 'Listening on ${proxy.reverseProxyUrl} (${proxy.reverseProxyRoutes.where((r) => r.isEnabled).length} active routes)'
                          : 'Configure backend routes below, then start the reverse gateway.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),

          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ShadButton(
                onPressed: proxy.isReverseProxyLoading ? null : () => proxy.toggleReverseProxy(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (proxy.isReverseProxyLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      Icon(proxy.isReverseProxyRunning ? LucideIcons.square : LucideIcons.play, size: 16),
                    const SizedBox(width: 8),
                    Text(proxy.isReverseProxyRunning ? 'Stop Reverse Proxy' : 'Start Reverse Proxy'),
                  ],
                ),
              ),
              if (proxy.isReverseProxyRunning) ...[
                ShadButton.outline(
                  onPressed: () => _copyToClipboard(proxy.reverseProxyUrl, 'Reverse Gateway URL'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.copy, size: 15),
                      SizedBox(width: 6),
                      Text('Copy Gateway URL'),
                    ],
                  ),
                ),
              ],
              ShadButton.outline(
                onPressed: proxy.isCheckingHealth ? null : () => proxy.checkRouteHealth(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.heartPulse,
                      size: 15,
                      color: proxy.isCheckingHealth ? Colors.grey : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(proxy.isCheckingHealth ? 'Checking...' : 'Check Backend Health'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReverseRoutesCard(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    return ShadCard(
      title: Row(
        children: [
          const Icon(LucideIcons.route, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Configured Backend Routes (${proxy.reverseProxyRoutes.length})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      description: const Text(
        'Incoming requests matching these path prefixes will be transparently proxied to target internal servers.',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () => proxy.loadOdooPresetRoute(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.sparkles, size: 14, color: Color(0xFFF59E0B)),
                      SizedBox(width: 6),
                      Text('1-Click Add Odoo ERP (8069)'),
                    ],
                  ),
                ),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () => _showAddReverseRouteDialog(context, proxy),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 14),
                      SizedBox(width: 6),
                      Text('Add Custom Route'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (proxy.reverseProxyRoutes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No routes configured yet. Click above to add a backend route.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: proxy.reverseProxyRoutes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final route = proxy.reverseProxyRoutes[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        ShadSwitch(
                          value: route.isEnabled,
                          onChanged: (_) => proxy.toggleReverseProxyRoute(route.id),
                        ),
                        const SizedBox(width: 12),

                        // Route details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    route.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),

                                  // Health badge
                                  _buildHealthBadge(route.isHealthy),

                                  if (route.stripPrefix) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Strip Prefix', style: TextStyle(fontSize: 9, color: Colors.blue)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Path: ${route.pathPrefix}/*',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF38BDF8)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(LucideIcons.arrowRight, size: 12, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Forward to ${route.targetUrl}',
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.grey),
                          onPressed: () => proxy.removeReverseProxyRoute(route.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthBadge(bool? isHealthy) {
    if (isHealthy == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('UNCHECKED', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      );
    }
    if (isHealthy) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.check, size: 10, color: Color(0xFF10B981)),
            SizedBox(width: 3),
            Text('ONLINE', style: TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.x, size: 10, color: Color(0xFFEF4444)),
          SizedBox(width: 3),
          Text('OFFLINE', style: TextStyle(fontSize: 9, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReverseIpCard(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    return ShadCard(
      title: const Row(
        children: [
          Icon(LucideIcons.slidersHorizontal, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reverse Proxy Network & Port Binding',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      description: const Text(
        'Configure the host address and listening port for the reverse proxy gateway.',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 0.0.0.0 (All Interfaces)
                InkWell(
                  onTap: proxy.isReverseProxyRunning ? null : () => _selectReverseIp('0.0.0.0', proxy),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: proxy.reverseProxyHost == '0.0.0.0'
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: proxy.reverseProxyHost == '0.0.0.0' ? const Color(0xFF3B82F6) : const Color(0xFF27272A),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.globe,
                          size: 15,
                          color: proxy.reverseProxyHost == '0.0.0.0' ? const Color(0xFF3B82F6) : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        const Text('0.0.0.0 (All Adapters)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

                for (final iface in proxy.systemIps)
                  InkWell(
                    onTap: proxy.isReverseProxyRunning ? null : () => _selectReverseIp(iface['address'] ?? '', proxy),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: proxy.reverseProxyHost == iface['address']
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: proxy.reverseProxyHost == iface['address'] ? const Color(0xFF3B82F6) : const Color(0xFF27272A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.wifi, size: 14, color: proxy.reverseProxyHost == iface['address'] ? const Color(0xFF3B82F6) : Colors.grey),
                          const SizedBox(width: 6),
                          Text('${iface['address']} (${iface['name']})', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bind Host / IP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ShadInput(
                        controller: _reverseHostController,
                        enabled: !proxy.isReverseProxyRunning,
                        placeholder: const Text('0.0.0.0'),
                        onChanged: (val) => proxy.setReverseProxyHost(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reverse Proxy Port', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ShadInput(
                        controller: _reversePortController,
                        enabled: !proxy.isReverseProxyRunning,
                        placeholder: const Text('8080'),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          final p = int.tryParse(val);
                          if (p != null && p > 0 && p <= 65535) {
                            proxy.setReverseProxyPort(p);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (!proxy.isReverseProxyRunning)
              Row(
                children: [
                  const Text('Common Ports: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  for (final port in [8080, 80, 8000, 3000, 8069]) ...[
                    InkWell(
                      onTap: () {
                        _reversePortController.text = port.toString();
                        proxy.setReverseProxyPort(port);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: proxy.reverseProxyPort == port
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$port',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: proxy.reverseProxyPort == port ? FontWeight.bold : FontWeight.normal,
                            color: proxy.reverseProxyPort == port ? const Color(0xFF3B82F6) : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReverseProxyExplainerCard(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How Reverse Proxy Routing Works', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '1. External client (phone, browser, tablet on Wi-Fi) accesses:\n   ${proxy.reverseProxyUrl}/odoo/web\n'
            '2. FDServer Reverse Proxy matches path prefix "/odoo" to backend 127.0.0.1:8069.\n'
            '3. Proxy automatically injects X-Forwarded-For, X-Forwarded-Proto, and X-Forwarded-Host.\n'
            '4. Backend response is streamed back directly to the client.',
            style: const TextStyle(fontSize: 12, height: 1.5, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  void _showAddReverseRouteDialog(BuildContext context, ProxyServerProvider proxy) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => ShadDialog(
          title: const Text('Add Reverse Proxy Route'),
          description: const Text('Route inbound requests matching path prefix to an internal backend service.'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ShadButton(
              onPressed: () {
                final name = _routeNameController.text.trim();
                final path = _routePathPrefixController.text.trim();
                final host = _routeTargetHostController.text.trim();
                final port = int.tryParse(_routeTargetPortController.text.trim()) ?? 80;

                if (path.isNotEmpty && host.isNotEmpty) {
                  proxy.addReverseProxyRoute(ReverseProxyRoute(
                    id: 'route_${DateTime.now().millisecondsSinceEpoch}',
                    name: name.isNotEmpty ? name : 'Route $path',
                    pathPrefix: path.startsWith('/') ? path : '/$path',
                    targetHost: host,
                    targetPort: port,
                    stripPrefix: _routeStripPrefix,
                    isEnabled: true,
                  ));
                  _routeNameController.clear();
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Save Route'),
            ),
          ],
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Route Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ShadInput(
                  controller: _routeNameController,
                  placeholder: const Text('e.g. Odoo ERP or API Service'),
                ),
                const SizedBox(height: 12),

                const Text('Path Prefix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ShadInput(
                  controller: _routePathPrefixController,
                  placeholder: const Text('e.g. /odoo or /api or /'),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target Host', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          ShadInput(
                            controller: _routeTargetHostController,
                            placeholder: const Text('127.0.0.1'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target Port', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          ShadInput(
                            controller: _routeTargetPortController,
                            placeholder: const Text('8069'),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    ShadSwitch(
                      value: _routeStripPrefix,
                      onChanged: (val) => setModalState(() => _routeStripPrefix = val),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Strip Path Prefix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('If enabled, removes /prefix before forwarding to backend.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB: TRAFFIC DIVERTER (HOTSPOT CLIENT)
  // ==========================================

  Widget _buildTrafficDiverterTab(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    final primaryTextColor = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B);
    final mutedTextColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
    final cardBgColor = isDark ? const Color(0xFF18181B) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Traffic Diverter (Super Proxy Client)',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tunnel 100% of all apps and device traffic directly to another phone\'s EveryProxy on the hotspot via Android VpnService.',
                      style: TextStyle(color: mutedTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Error Alert with 1-Tap Copy for AI
          if (proxy.diverterError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.triangleAlert, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      const Text('Traffic Diverter Error', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13)),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          final prompt = CrashLogService().generateFullDiagnosticsAiPrompt();
                          Clipboard.setData(ClipboardData(text: prompt));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied full AI Diagnostic report to clipboard! Ready to paste into AI.'),
                              backgroundColor: Color(0xFF18181B),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(LucideIcons.copy, size: 12),
                        label: const Text('Copy for AI', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CrashLogsScreen()),
                          );
                        },
                        child: const Text('Logs', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(proxy.diverterError!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (proxy.isDiverterRunning) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.shieldAlert, color: Color(0xFFEF4444), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Traffic Diverter is Currently Active',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tunneling to ${proxy.diverterHost}:${proxy.diverterPort}',
                          style: TextStyle(fontSize: 12, color: primaryTextColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ShadButton.destructive(
                    size: ShadButtonSize.sm,
                    onPressed: proxy.isDiverterLoading ? null : () => proxy.toggleDiverter(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (proxy.isDiverterLoading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        else
                          const Icon(LucideIcons.square, size: 14),
                        const SizedBox(width: 6),
                        const Text('STOP NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Network Connection Mode (Hotspot vs Wi-Fi LAN)
          _buildDiverterNetworkModeSelector(context, proxy, isDark, primaryTextColor, mutedTextColor, cardBgColor, cardBorderColor),

          const SizedBox(height: 18),

          // 1-Click Auto-Discovery Card
          _buildDiverterAutoDiscoveryCard(context, proxy, isDark, primaryTextColor, mutedTextColor, cardBgColor, cardBorderColor),

          const SizedBox(height: 18),

          // Diverter Hero Status Card
          _buildDiverterHeroCard(context, proxy, isDark, primaryTextColor, mutedTextColor, cardBgColor, cardBorderColor),

          const SizedBox(height: 18),

          if (!proxy.diverterUseVpn) ...[
            // Direct Wi-Fi Proxy Card (when VPN is off)
            _buildDiverterWifiProxyCard(context, proxy, isDark, primaryTextColor, mutedTextColor, cardBgColor, cardBorderColor),
            const SizedBox(height: 18),
          ] else ...[
            // Live Metrics Counters (when VPN is on)
            _buildDiverterMetrics(context, proxy, isDark, primaryTextColor, mutedTextColor, cardBgColor, cardBorderColor),
            const SizedBox(height: 18),
          ],

          // Target Proxy Configuration Card
          _buildDiverterConfigCard(context, proxy, isDark, primaryTextColor, mutedTextColor, cardBgColor, cardBorderColor),

          const SizedBox(height: 18),

          // Live Diagnostics & Event Logs Card
          _buildDiverterDiagnosticsCard(context, proxy, isDark, primaryTextColor, mutedTextColor, cardBgColor, cardBorderColor),

          const SizedBox(height: 18),

          // Step-by-Step Guide Card (Hotspot & Wi-Fi)
          _buildDiverterHotspotGuide(context, proxy, isDark, primaryTextColor, mutedTextColor, cardBgColor, cardBorderColor),
        ],
      ),
    );
  }

  Widget _buildDiverterNetworkModeSelector(
    BuildContext context,
    ProxyServerProvider proxy,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color cardBorderColor,
  ) {
    final isWifi = proxy.diverterNetworkMode == DiverterNetworkMode.wifi;
    final isHotspot = proxy.diverterNetworkMode == DiverterNetworkMode.hotspot;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.router, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Text(
                'Network Connection Mode',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const Spacer(),
              if (proxy.isWifiConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Wi-Fi: ${proxy.detectedWifiIp ?? 'Active'}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Mobile Hotspot Mode Button
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('mode_hotspot_button'),
                    onTap: proxy.isDiverterRunning
                        ? null
                        : () => proxy.setDiverterNetworkMode(DiverterNetworkMode.hotspot),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isHotspot
                            ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isHotspot
                              ? const Color(0xFF6366F1)
                              : cardBorderColor,
                          width: isHotspot ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.radio,
                            size: 18,
                            color: isHotspot ? const Color(0xFF6366F1) : mutedTextColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mobile Hotspot',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isHotspot ? (isDark ? Colors.white : const Color(0xFF4338CA)) : primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '192.168.43.x / iOS',
                                  style: TextStyle(fontSize: 10.5, color: mutedTextColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isHotspot)
                            const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF6366F1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Wi-Fi LAN Mode Button
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('mode_wifi_button'),
                    onTap: proxy.isDiverterRunning
                        ? null
                        : () => proxy.setDiverterNetworkMode(DiverterNetworkMode.wifi),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isWifi
                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isWifi
                              ? const Color(0xFF10B981)
                              : cardBorderColor,
                          width: isWifi ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.wifi,
                            size: 18,
                            color: isWifi ? const Color(0xFF10B981) : mutedTextColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Wi-Fi LAN',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isWifi ? (isDark ? Colors.white : const Color(0xFF065F46)) : primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  proxy.detectedWifiGateway != null
                                      ? 'Router ${proxy.detectedWifiGateway}'
                                      : 'Same Wi-Fi Network',
                                  style: TextStyle(fontSize: 10.5, color: mutedTextColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isWifi)
                            const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF10B981)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isWifi
                ? 'Routing through Phone B on your local Wi-Fi. Ensure Phone B is connected to the same Wi-Fi with EveryProxy active.'
                : 'Routing through Phone B on mobile hotspot. Phone A is connected to Phone B\'s hotspot (gateway 192.168.43.1).',
            style: TextStyle(fontSize: 11, color: mutedTextColor, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildDiverterAutoDiscoveryCard(
    BuildContext context,
    ProxyServerProvider proxy,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color cardBorderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF18181B)]
              : [const Color(0xFFEEF2FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 500;

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.radar, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proxy.diverterNetworkMode == DiverterNetworkMode.wifi
                              ? 'Wi-Fi 1-Click Auto-Connect'
                              : 'Hotspot 1-Click Auto-Connect',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          proxy.diverterNetworkMode == DiverterNetworkMode.wifi
                              ? 'Scans the local Wi-Fi subnet and locks onto Phone B running EveryProxy with zero typing.'
                              : 'Scans the hotspot subnet and locks onto Phone B running EveryProxy with zero typing.',
                          style: TextStyle(fontSize: 12, color: mutedTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (proxy.isScanningProxy && proxy.discoveredProxies.isEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      proxy.diverterNetworkMode == DiverterNetworkMode.wifi
                          ? 'Fast-scanning Wi-Fi subnet for active proxies...'
                          : 'Fast-scanning hotspot subnet for active proxies...',
                      style: TextStyle(fontSize: 12, color: mutedTextColor, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ],
              if (proxy.discoveredProxies.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(LucideIcons.listFilter, size: 13, color: mutedTextColor),
                    const SizedBox(width: 6),
                    Text(
                      proxy.discoveredProxies.length == 1
                          ? 'Found Proxy Device (Tap to connect):'
                          : 'Found ${proxy.discoveredProxies.length} Proxy Devices (Tap to connect):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: proxy.discoveredProxies.map((disc) {
                    final isSelected = proxy.diverterHost == disc.ip && proxy.diverterPort == disc.port;
                    final isConnected = isSelected && proxy.isDiverterRunning;
                    final isConnecting = isSelected && proxy.isDiverterLoading;
                    final isSocks = disc.protocol.toUpperCase() == 'SOCKS5';

                    Color activeColor = const Color(0xFF6366F1);
                    if (isConnected) {
                      activeColor = const Color(0xFF10B981);
                    }

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: proxy.isDiverterLoading
                            ? null
                            : () async {
                                final connected = await proxy.connectToDiscoveredProxy(disc);
                                if (!context.mounted) return;
                                if (connected) {
                                  ShadToaster.of(context).show(
                                    ShadToast(
                                      title: const Text('Connected to Proxy!'),
                                      description: Text('Routing all device traffic through ${disc.ip}:${disc.port} (${disc.protocol})'),
                                    ),
                                  );
                                } else if (!proxy.isDiverterRunning && isConnected) {
                                  ShadToaster.of(context).show(
                                    ShadToast(
                                      title: const Text('Disconnected Proxy Tunnel'),
                                      description: Text('Stopped routing through ${disc.ip}:${disc.port}'),
                                    ),
                                  );
                                }
                              },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isConnected
                                ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.15)
                                : isSelected
                                    ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.15)
                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isConnected
                                  ? const Color(0xFF10B981)
                                  : isSelected
                                      ? const Color(0xFF6366F1)
                                      : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1)),
                              width: (isSelected || isConnected) ? 1.6 : 1.0,
                            ),
                            boxShadow: (isSelected || isConnected)
                                ? [
                                    BoxShadow(
                                      color: activeColor.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isConnecting)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                                )
                              else
                                Icon(
                                  isConnected
                                      ? LucideIcons.checkCheck
                                      : isSelected
                                          ? LucideIcons.checkCircle2
                                          : LucideIcons.radio,
                                  size: 14,
                                  color: isConnected
                                      ? const Color(0xFF10B981)
                                      : isSelected
                                          ? const Color(0xFF6366F1)
                                          : mutedTextColor,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                '${disc.ip}:${disc.port}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: (isSelected || isConnected) ? FontWeight.bold : FontWeight.w600,
                                  color: isConnected
                                      ? const Color(0xFF10B981)
                                      : isSelected
                                          ? (isDark ? Colors.white : const Color(0xFF4338CA))
                                          : primaryTextColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isSocks
                                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                      : const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  disc.protocol,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSocks ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${disc.latencyMs}ms',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: mutedTextColor,
                                ),
                              ),
                              if (isConnected) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ] else if (isConnecting) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  'Connecting...',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ] else if (proxy.lastDiscoveredProxy != null) ...[
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: proxy.isDiverterLoading
                        ? null
                        : () async {
                            final disc = proxy.lastDiscoveredProxy!;
                            final connected = await proxy.connectToDiscoveredProxy(disc);
                            if (!context.mounted) return;
                            if (connected) {
                              ShadToaster.of(context).show(
                                ShadToast(
                                  title: const Text('Connected to Proxy!'),
                                  description: Text('Routing all device traffic through ${disc.ip}:${disc.port} (${disc.protocol})'),
                                ),
                              );
                            }
                          },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.checkCheck, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Phone B: ${proxy.lastDiscoveredProxy!.ip}:${proxy.lastDiscoveredProxy!.port} (${proxy.lastDiscoveredProxy!.protocol} · ${proxy.lastDiscoveredProxy!.latencyMs}ms) · Tap to connect',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );

          final button = ShadButton(
            key: const Key('diverter_scan_button'),
            onPressed: (proxy.isDiverterRunning || proxy.isScanningProxy)
                ? null
                : () async {
                    final connected = await proxy.autoDiscoverAndConnectHotspot();
                    if (!context.mounted) return;
                    if (connected) {
                      ShadToaster.of(context).show(
                        ShadToast(
                          title: const Text('Connected to Hotspot Proxy!'),
                          description: Text('All device traffic is now diverted through ${proxy.diverterHost}:${proxy.diverterPort}'),
                        ),
                      );
                    }
                  },
            backgroundColor: const Color(0xFF6366F1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (proxy.isScanningProxy) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    proxy.discoveredProxies.isEmpty
                        ? 'Scanning Subnet...'
                        : 'Found (${proxy.discoveredProxies.length})...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ] else ...[
                  const Icon(LucideIcons.zap, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      proxy.discoveredProxies.isEmpty
                          ? 'Scan & Auto-Connect'
                          : (proxy.diverterNetworkMode == DiverterNetworkMode.wifi ? 'Rescan Wi-Fi' : 'Rescan Hotspot'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 12),
                button,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: content),
              const SizedBox(width: 16),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiverterHeroCard(
    BuildContext context,
    ProxyServerProvider proxy,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color cardBorderColor,
  ) {
    final isRunning = proxy.isDiverterRunning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRunning ? const Color(0xFF10B981) : cardBorderColor,
          width: isRunning ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 450;

          final isVpnEnabled = proxy.diverterUseVpn;

          final statusSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: !isVpnEnabled
                              ? Colors.amber
                              : (isRunning ? const Color(0xFF10B981) : Colors.grey),
                          shape: BoxShape.circle,
                          boxShadow: (isVpnEnabled && isRunning)
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          !isVpnEnabled
                              ? 'WI-FI PROXY MODE (VPN OFF)'
                              : (isRunning ? 'VPN TUNNEL ACTIVE' : 'DIVERTER STOPPED'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: !isVpnEnabled
                                ? Colors.amber
                                : (isRunning ? const Color(0xFF10B981) : mutedTextColor),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (isVpnEnabled && isRunning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('ALL APPS DIVERTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ),
                  if (!isVpnEnabled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('NO VPN OVERHEAD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Target proxy: ${proxy.diverterHost}:${proxy.diverterPort} (${proxy.diverterProtocol})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(!isVpnEnabled ? '📡 ' : '🔑 ', style: const TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      !isVpnEnabled
                          ? 'VPN tunnel is OFF. To route traffic, configure Proxy: Manual (${proxy.diverterHost}:${proxy.diverterPort}) in Wi-Fi settings.'
                          : (isRunning
                              ? 'Android VPN Key active. 100% of phone traffic is routing through Phone B.'
                              : 'Tap start to tunnel all phone traffic directly to the target proxy IP & port.'),
                      style: TextStyle(fontSize: 12, color: mutedTextColor),
                    ),
                  ),
                ],
              ),
            ],
          );

          final actionButton = isRunning
              ? ShadButton.destructive(
                  key: const Key('diverter_stop_button'),
                  size: ShadButtonSize.lg,
                  onPressed: proxy.isDiverterLoading
                      ? null
                      : () async {
                          await proxy.toggleDiverter();
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (proxy.isDiverterLoading) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Text('Stopping...'),
                      ] else ...[
                        const Icon(LucideIcons.square, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text('STOP TRAFFIC DIVERTER', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ],
                  ),
                )
              : (!isVpnEnabled
                  ? ShadButton.outline(
                      size: ShadButtonSize.lg,
                      onPressed: proxy.isTestingProxy ? null : () => proxy.testDiverterProxyConnection(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (proxy.isTestingProxy) ...[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            const Text('Testing...'),
                          ] else ...[
                            const Icon(LucideIcons.radio, size: 18),
                            const SizedBox(width: 8),
                            const Text('Test Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    )
                  : ShadButton(
                      key: const Key('diverter_start_button'),
                      size: ShadButtonSize.lg,
                      onPressed: proxy.isDiverterLoading
                          ? null
                          : () async {
                              await proxy.toggleDiverter();
                            },
                      backgroundColor: const Color(0xFF10B981),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (proxy.isDiverterLoading) ...[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            const Text('Connecting...'),
                          ] else ...[
                            const Icon(LucideIcons.shieldCheck, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text('Start Diverting', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ],
                      ),
                    ));

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                statusSection,
                const SizedBox(height: 16),
                actionButton,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: statusSection),
              const SizedBox(width: 16),
              actionButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiverterMetrics(
    BuildContext context,
    ProxyServerProvider proxy,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color cardBorderColor,
  ) {
    final downKbps = (proxy.diverterDownloadSpeed * 8 / 1024).toStringAsFixed(1);
    final upKbps = (proxy.diverterUploadSpeed * 8 / 1024).toStringAsFixed(1);
    final totalMb = ((proxy.diverterBytesIn + proxy.diverterBytesOut) / (1024 * 1024)).toStringAsFixed(2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final itemWidth = isWide
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth < 380 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildDiverterGaugeCard(
              title: 'Download Speed',
              value: '$downKbps Kbps',
              icon: LucideIcons.arrowDownToLine,
              color: const Color(0xFF10B981),
              width: itemWidth,
              isDark: isDark,
              cardBgColor: cardBgColor,
              cardBorderColor: cardBorderColor,
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
            ),
            _buildDiverterGaugeCard(
              title: 'Upload Speed',
              value: '$upKbps Kbps',
              icon: LucideIcons.arrowUpFromLine,
              color: const Color(0xFF3B82F6),
              width: itemWidth,
              isDark: isDark,
              cardBgColor: cardBgColor,
              cardBorderColor: cardBorderColor,
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
            ),
            _buildDiverterGaugeCard(
              title: 'Total Diverted',
              value: '$totalMb MB',
              icon: LucideIcons.database,
              color: const Color(0xFF8B5CF6),
              width: itemWidth,
              isDark: isDark,
              cardBgColor: cardBgColor,
              cardBorderColor: cardBorderColor,
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
            ),
            _buildDiverterGaugeCard(
              title: 'Protocol & Port',
              value: '${proxy.diverterProtocol} :${proxy.diverterPort}',
              icon: LucideIcons.network,
              color: const Color(0xFFF59E0B),
              width: itemWidth,
              isDark: isDark,
              cardBgColor: cardBgColor,
              cardBorderColor: cardBorderColor,
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiverterGaugeCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
    required bool isDark,
    required Color cardBgColor,
    required Color cardBorderColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: mutedTextColor, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiverterConfigCard(
    BuildContext context,
    ProxyServerProvider proxy,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color cardBorderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.slidersHorizontal, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Target Proxy Configuration',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryTextColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Specify the IP and port of Phone B (or any local/remote proxy) to divert all traffic through.',
            style: TextStyle(fontSize: 12, color: mutedTextColor),
          ),

          const SizedBox(height: 16),

          // Routing Mode: Enable VPN Tunnel (ON / OFF)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: proxy.diverterUseVpn
                  ? const Color(0xFF10B981).withValues(alpha: 0.08)
                  : Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: proxy.diverterUseVpn
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  proxy.diverterUseVpn ? LucideIcons.shieldCheck : LucideIcons.wifi,
                  color: proxy.diverterUseVpn ? const Color(0xFF10B981) : Colors.amber,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Enable Android VPN Tunnel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (proxy.diverterUseVpn ? const Color(0xFF10B981) : Colors.amber).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              proxy.diverterUseVpn ? 'VPN ON' : 'VPN OFF (Wi-Fi Proxy)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: proxy.diverterUseVpn ? const Color(0xFF10B981) : Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        proxy.diverterUseVpn
                            ? 'Diverts 100% of all apps through EveryProxy via Android VpnService.'
                            : 'VPN disabled. Enter Phone B\'s IP in Android Wi-Fi settings without any VPN overhead.',
                        style: TextStyle(fontSize: 11, color: mutedTextColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  key: const Key('diverter_vpn_switch'),
                  value: proxy.diverterUseVpn,
                  onChanged: proxy.isDiverterRunning
                      ? null
                      : (val) {
                          proxy.setDiverterUseVpn(val);
                        },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Host & Port Row (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 450;

              final hostInput = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target IP / Host', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryTextColor)),
                  const SizedBox(height: 6),
                  ShadInput(
                    key: const Key('diverter_host_input'),
                    controller: _diverterHostController,
                    enabled: !proxy.isDiverterRunning,
                    placeholder: const Text('192.168.43.1'),
                    onChanged: (val) => proxy.setDiverterHost(val),
                  ),
                ],
              );

              final portInput = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target Port', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryTextColor)),
                  const SizedBox(height: 6),
                  ShadInput(
                    key: const Key('diverter_port_input'),
                    controller: _diverterPortController,
                    enabled: !proxy.isDiverterRunning,
                    placeholder: const Text('1080'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final p = int.tryParse(val);
                      if (p != null && p > 0 && p <= 65535) {
                        proxy.setDiverterPort(p);
                      }
                    },
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  children: [
                    hostInput,
                    const SizedBox(height: 12),
                    portInput,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: hostInput),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: portInput),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // Quick Host & Port Presets
          if (!proxy.isDiverterRunning) ...[
            Text('Quick Shortcuts:', style: TextStyle(fontSize: 11, color: mutedTextColor, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (proxy.diverterNetworkMode == DiverterNetworkMode.wifi && proxy.detectedWifiGateway != null)
                  _buildQuickChip(
                    label: 'Wi-Fi Gateway (${proxy.detectedWifiGateway})',
                    onTap: () {
                      _diverterHostController.text = proxy.detectedWifiGateway!;
                      proxy.setDiverterHost(proxy.detectedWifiGateway!);
                    },
                    isSelected: proxy.diverterHost == proxy.detectedWifiGateway,
                  ),
                _buildQuickChip(
                  label: 'Hotspot Gateway (192.168.43.1)',
                  onTap: () {
                    _diverterHostController.text = '192.168.43.1';
                    proxy.setDiverterHost('192.168.43.1');
                  },
                  isSelected: proxy.diverterHost == '192.168.43.1',
                ),
                _buildQuickChip(
                  label: 'iPhone Hotspot (172.20.10.1)',
                  onTap: () {
                    _diverterHostController.text = '172.20.10.1';
                    proxy.setDiverterHost('172.20.10.1');
                  },
                  isSelected: proxy.diverterHost == '172.20.10.1',
                ),
                _buildQuickChip(
                  label: 'SOCKS5 (1080)',
                  onTap: () {
                    _diverterPortController.text = '1080';
                    proxy.setDiverterPort(1080);
                    proxy.setDiverterProtocol('SOCKS5');
                  },
                  isSelected: proxy.diverterPort == 1080,
                ),
                _buildQuickChip(
                  label: 'HTTP (8080)',
                  onTap: () {
                    _diverterPortController.text = '8080';
                    proxy.setDiverterPort(8080);
                    proxy.setDiverterProtocol('HTTP');
                  },
                  isSelected: proxy.diverterPort == 8080,
                ),
                _buildQuickChip(
                  label: 'Local Proxy (8888)',
                  onTap: () {
                    _diverterPortController.text = '8888';
                    proxy.setDiverterPort(8888);
                  },
                  isSelected: proxy.diverterPort == 8888,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Direct Socket Connection Test Button
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: proxy.isTestingProxy ? null : () => proxy.testDiverterProxyConnection(),
                  icon: proxy.isTestingProxy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.radio, size: 15),
                  label: Text(
                    proxy.isTestingProxy ? 'Testing Connection...' : 'Test Connection to EveryProxy',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            if (proxy.proxyTestResult != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: proxy.proxyTestResult!.startsWith('SUCCESS')
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: proxy.proxyTestResult!.startsWith('SUCCESS')
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      proxy.proxyTestResult!.startsWith('SUCCESS')
                          ? LucideIcons.circleCheck
                          : LucideIcons.circleAlert,
                      size: 16,
                      color: proxy.proxyTestResult!.startsWith('SUCCESS')
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        proxy.proxyTestResult!,
                        style: TextStyle(
                          fontSize: 12,
                          color: proxy.proxyTestResult!.startsWith('SUCCESS')
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Protocol Selector (SOCKS5 vs HTTP)
          Text('Proxy Protocol', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryTextColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildProtocolPill(
                title: 'SOCKS5 (Recommended)',
                description: 'Best for all apps, UDP, TCP, games & chat',
                protocol: 'SOCKS5',
                current: proxy.diverterProtocol,
                enabled: !proxy.isDiverterRunning,
                onTap: () => proxy.setDiverterProtocol('SOCKS5'),
              ),
              _buildProtocolPill(
                title: 'HTTP CONNECT',
                description: 'Standard HTTP tunnel proxy',
                protocol: 'HTTP',
                current: proxy.diverterProtocol,
                enabled: !proxy.isDiverterRunning,
                onTap: () => proxy.setDiverterProtocol('HTTP'),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Bypass Local LAN Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bypass Local LAN Traffic', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryTextColor)),
                    const SizedBox(height: 2),
                    Text(
                      proxy.diverterNetworkMode == DiverterNetworkMode.wifi
                          ? 'Keep local Wi-Fi router & devices (printers, local servers) direct while diverting all internet traffic.'
                          : 'Keep private networks (192.168.x.x, 10.x.x.x) direct so local routers and printers remain accessible.',
                      style: TextStyle(fontSize: 11, color: mutedTextColor),
                    ),
                  ],
                ),
              ),
              Switch(
                value: proxy.diverterBypassLan,
                onChanged: proxy.isDiverterRunning ? null : (val) => proxy.setDiverterBypassLan(val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({required String label, required VoidCallback onTap, required bool isSelected}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF3B82F6) : null,
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolPill({
    required String title,
    required String description,
    required String protocol,
    required String current,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final isSelected = protocol == current;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6).withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF3B82F6) : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiverterWifiProxyCard(
    BuildContext context,
    ProxyServerProvider proxy,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color cardBorderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.wifi, size: 18, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Direct Wi-Fi Proxy Setup (Zero VPN Overhead)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryTextColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Since VPN mode is turned OFF, configure your phone\'s Wi-Fi connection directly to EveryProxy. This bypasses Android VpnService and guarantees direct data transfer:',
            style: TextStyle(fontSize: 12, color: mutedTextColor),
          ),
          const SizedBox(height: 14),

          // Host & Port Chips with 1-Tap Copy
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Proxy Host: ', style: TextStyle(fontSize: 12, color: mutedTextColor)),
                    Flexible(
                      child: Text(
                        proxy.diverterHost,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryTextColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: proxy.diverterHost));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Host ${proxy.diverterHost} copied to clipboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Icon(LucideIcons.copy, size: 14, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Proxy Port: ', style: TextStyle(fontSize: 12, color: mutedTextColor)),
                    Text(
                      '${proxy.diverterPort}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryTextColor),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: '${proxy.diverterPort}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Port ${proxy.diverterPort} copied to clipboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Icon(LucideIcons.copy, size: 14, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Text(
            'Recommended Ways to Route Traffic:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryTextColor),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Option A (Super Proxy App): Open Super Proxy on this device, add HTTP/SOCKS5 with Host (${proxy.diverterHost}) and Port (${proxy.diverterPort}), and tap Start. It tunnels 100% of all apps seamlessly.',
                    style: TextStyle(fontSize: 11, color: primaryTextColor, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.wifi, size: 16, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Option B (Wi-Fi Settings): Android Settings > Wi-Fi > Hotspot Network > Edit / Advanced > Proxy: Manual > Enter Host (${proxy.diverterHost}) & Port (${proxy.diverterPort}). Zero battery overhead.',
                    style: TextStyle(fontSize: 11, color: primaryTextColor, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiverterHotspotGuide(
    BuildContext context,
    ProxyServerProvider proxy,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color cardBorderColor,
  ) {
    final isWifi = proxy.diverterNetworkMode == DiverterNetworkMode.wifi;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isWifi ? LucideIcons.wifi : LucideIcons.helpCircle, size: 18, color: isWifi ? const Color(0xFF10B981) : const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isWifi ? 'How Wi-Fi Proxy Diversion Works' : 'How Hotspot Proxy Diversion Works',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryTextColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGuideStep(
            step: '1',
            title: isWifi ? 'Connect to the Same Wi-Fi' : 'Turn on Mobile Hotspot',
            description: isWifi
                ? 'Ensure both Phone A and Phone B are connected to the same Wi-Fi router / office network.'
                : 'Turn on Hotspot on Phone A. Connect Phone B to this Hotspot Wi-Fi network (or vice versa).',
            primaryTextColor: primaryTextColor,
            mutedTextColor: mutedTextColor,
          ),
          const SizedBox(height: 10),
          _buildGuideStep(
            step: '2',
            title: 'Open EveryProxy on Connected Phone',
            description: isWifi
                ? 'On Phone B, start EveryProxy with SOCKS5 (port 1080) or HTTP (port 8080). EveryProxy will display Phone B\'s local Wi-Fi IP.'
                : 'On Phone B, start EveryProxy with SOCKS5 (port 1080) or HTTP (port 8080).',
            primaryTextColor: primaryTextColor,
            mutedTextColor: mutedTextColor,
          ),
          const SizedBox(height: 10),
          _buildGuideStep(
            step: '3',
            title: isWifi ? 'Auto-Discover & Divert Traffic' : 'Route Apps via Diverter Tunnel',
            description: isWifi
                ? 'Tap "Scan Wi-Fi" to automatically locate Phone B or enter its Wi-Fi IP in Target Host, then tap "Start Diverting" to route 100% of all apps through Phone B!'
                : 'Use "Scan & Auto-Connect" to lock onto Phone B (gateway 192.168.43.1). Tap "Start Diverting" to route all apps through Phone B seamlessly!',
            primaryTextColor: primaryTextColor,
            mutedTextColor: mutedTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep({
    required String step,
    required String title,
    required String description,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryTextColor)),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(fontSize: 11, color: mutedTextColor, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiverterDiagnosticsCard(
    BuildContext context,
    ProxyServerProvider proxy,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color cardBorderColor,
  ) {
    final logs = proxy.diverterLogs;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.terminal, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Diverter Diagnostics & Logs',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryTextColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${logs.length} events',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () {
                      final report = proxy.getFormattedDiverterDiagnosticReport();
                      Clipboard.setData(ClipboardData(text: report));
                      ShadToaster.of(context).show(
                        const ShadToast(
                          title: Text('Copied Diagnostic Report'),
                          description: Text('Ready to paste to AI or share for troubleshooting.'),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.copy, size: 13),
                        SizedBox(width: 4),
                        Text('Copy AI Log', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () => proxy.refreshDiverterLogs(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.refreshCw, size: 13),
                        SizedBox(width: 4),
                        Text('Refresh', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: logs.isEmpty ? null : () => proxy.clearDiverterLogs(),
                    child: const Icon(LucideIcons.trash2, size: 13, color: Colors.redAccent),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Real-time network events, packet interceptions, and proxy handshakes recorded by Android VpnService:',
            style: TextStyle(fontSize: 11, color: mutedTextColor),
          ),
          const SizedBox(height: 10),

          // Terminal-style log box
          Container(
            width: double.infinity,
            height: 190,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No events logged yet.\nTap "Start Diverting" above to record real-time connection events and proxy handshakes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5), fontFamily: 'monospace'),
                    ),
                  )
                : ListView.builder(
                    reverse: false,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final line = logs[index];
                      Color logColor = const Color(0xFF94A3B8);
                      if (line.contains('[OK]') || line.contains('SUCCEEDED') || line.contains('ESTABLISHED')) {
                        logColor = const Color(0xFF34D399); // Emerald
                      } else if (line.contains('[ERROR]') || line.contains('[EXCEPTION]') || line.contains('-ERR')) {
                        logColor = const Color(0xFFF87171); // Red
                      } else if (line.contains('[TUN-IN]')) {
                        logColor = const Color(0xFF38BDF8); // Sky blue
                      } else if (line.contains('[TUNNEL]') || line.contains('[WARN]')) {
                        logColor = const Color(0xFFFBBF24); // Amber
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Text(
                          line,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: logColor,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: LIVE TRAFFIC INSPECTOR
  // ==========================================

  Widget _buildTrafficInspectorTab(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    final filteredLogs = proxy.filteredLogs;

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ShadInput(
                  controller: _searchController,
                  placeholder: const Text('Filter by host, path, client IP...'),
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(LucideIcons.search, size: 16, color: Colors.grey),
                  ),
                  onChanged: (val) => proxy.setSearchFilter(val),
                ),
              ),
              const SizedBox(width: 10),

              // Protocol dropdown / chips
              Wrap(
                spacing: 6,
                children: [
                  _buildProtocolFilterChip('All', null, proxy),
                  _buildProtocolFilterChip('HTTP', ProxyProtocol.http, proxy),
                  _buildProtocolFilterChip('HTTPS', ProxyProtocol.httpsConnect, proxy),
                  _buildProtocolFilterChip('SOCKS5', ProxyProtocol.socks5, proxy),
                  _buildProtocolFilterChip('Reverse', ProxyProtocol.reverseProxy, proxy),
                ],
              ),

              const SizedBox(width: 10),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: () => proxy.clearLogs(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.trash2, size: 14),
                    SizedBox(width: 6),
                    Text('Clear Logs'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Logs list view
        Expanded(
          child: filteredLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.activity, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text(
                        'No Traffic Captured Yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (proxy.isRunning || proxy.isReverseProxyRunning)
                            ? 'Configure client apps to use proxy or make requests to reverse proxy'
                            : 'Start the proxy server to begin inspecting requests',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredLogs.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                  ),
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return _buildLogListItem(context, log, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProtocolFilterChip(String label, ProxyProtocol? protocol, ProxyServerProvider proxy) {
    final isSelected = proxy.selectedProtocolFilter == protocol;
    return InkWell(
      onTap: () => proxy.setProtocolFilter(protocol),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildLogListItem(BuildContext context, ProxyLogEntry log, bool isDark) {
    Color statusColor;
    if (log.isBlocked) {
      statusColor = const Color(0xFFEF4444);
    } else if (log.statusCode < 400) {
      statusColor = const Color(0xFF10B981);
    } else if (log.statusCode < 500) {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFFEF4444);
    }

    return InkWell(
      onTap: () => _showLogDetailsDialog(context, log, isDark),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Status code / Blocked badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                log.isBlocked ? 'BLOCKED' : '${log.statusCode}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Protocol tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.protocol.shortCode,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
            const SizedBox(width: 10),

            // Method
            Text(
              log.method,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(width: 10),

            // Host & Path
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log.host}:${log.port}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (log.path.isNotEmpty && log.path != '/')
                    Text(
                      log.path,
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Client IP
            Text(
              log.clientIp,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(width: 14),

            // Bytes & Duration
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatBytes(log.totalBytes),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${log.durationMs}ms',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLogDetailsDialog(BuildContext context, ProxyLogEntry log, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => ShadDialog(
        title: Row(
          children: [
            const Icon(LucideIcons.fileSearch, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Request Details (${log.protocol.displayName})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        description: Text('${log.method} ${log.host}:${log.port}'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Timestamp', log.timestamp.toIso8601String()),
              _buildDetailRow('Protocol', log.protocol.displayName),
              _buildDetailRow('Method', log.method),
              _buildDetailRow('Target Host', log.host),
              _buildDetailRow('Target Port', '${log.port}'),
              if (log.path.isNotEmpty) _buildDetailRow('Request Path', log.path),
              _buildDetailRow('Client IP', log.clientIp),
              _buildDetailRow('Status Code', '${log.statusCode}'),
              _buildDetailRow('Bytes Sent (In)', _formatBytes(log.bytesSent)),
              _buildDetailRow('Bytes Received (Out)', _formatBytes(log.bytesReceived)),
              _buildDetailRow('Duration', '${log.durationMs} ms'),
              if (log.isBlocked) _buildDetailRow('Filter Status', 'Blocked by Rule'),
              if (log.isRewritten) _buildDetailRow('Rewrite Status', 'Redirected by Rule'),
              if (log.errorMessage != null) _buildDetailRow('Error', log.errorMessage!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: SUPER PROXY RULES & AD-BLOCKING
  // ==========================================

  Widget _buildRulesAndFeaturesTab(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Domain Filtering & Ad Shield
          ShadCard(
            title: Row(
              children: [
                const Icon(LucideIcons.shieldCheck, size: 20, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Domain Filtering & Ad-Block Shield',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      proxy.isBlocklistEnabled ? 'Active' : 'Disabled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: proxy.isBlocklistEnabled ? const Color(0xFF10B981) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadSwitch(
                      value: proxy.isBlocklistEnabled,
                      onChanged: (val) => proxy.setBlocklistEnabled(val),
                    ),
                  ],
                ),
              ],
            ),
            description: const Text(
              'Block ads, trackers, and telemetry domains across all devices routed through this proxy.',
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        onPressed: () => proxy.loadPopularAdBlockRules(),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.sparkles, size: 14, color: Color(0xFFF59E0B)),
                            SizedBox(width: 6),
                            Text('Load 1-Click Ad & Tracker Preset'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        onPressed: () => _showAddRuleDialog(context, proxy),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.plus, size: 14),
                            SizedBox(width: 6),
                            Text('Add Custom Rule'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rules list
                  if (proxy.rules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No domain rules configured yet.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: proxy.rules.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final rule = proxy.rules[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              ShadSwitch(
                                value: rule.isEnabled,
                                onChanged: (_) => proxy.toggleRule(rule.id),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: rule.type == ProxyRuleType.block
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                      : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  rule.type == ProxyRuleType.block ? 'BLOCK' : 'REWRITE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: rule.type == ProxyRuleType.block
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rule.pattern,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    if (rule.type == ProxyRuleType.rewrite)
                                      Text(
                                        '→ Redirect to ${rule.targetHost}:${rule.targetPort ?? 80}',
                                        style: const TextStyle(fontSize: 11, color: Colors.blue),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.grey),
                                onPressed: () => proxy.removeRule(rule.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section 2: Bandwidth Simulator / Throttling
          ShadCard(
            title: const Row(
              children: [
                Icon(LucideIcons.gauge, size: 20, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text('Bandwidth Simulator & Throttling'),
              ],
            ),
            description: const Text(
              'Simulate slower mobile network conditions (3G, 2G, DSL) to test client apps under poor connections.',
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final profile in ThrottleProfile.presets)
                    InkWell(
                      onTap: () => proxy.updateThrottle(profile),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: (proxy.throttle.name == profile.name)
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (proxy.throttle.name == profile.name)
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF27272A),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: (proxy.throttle.name == profile.name)
                                    ? const Color(0xFFF59E0B)
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.enabled
                                  ? 'Down: ${profile.kbpsDown} Kbps • ${profile.latencyMs}ms'
                                  : 'No limits applied',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section 3: Upstream Proxy Chaining
          ShadCard(
            title: Row(
              children: [
                const Icon(LucideIcons.gitMerge, size: 20, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Upstream Proxy Chaining',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ShadSwitch(
                  value: proxy.upstream.enabled,
                  onChanged: (val) {
                    proxy.updateUpstream(proxy.upstream.copyWith(enabled: val));
                  },
                ),
              ],
            ),
            description: const Text(
              'Route all outgoing traffic through a parent upstream HTTP/HTTPS proxy (e.g. corporate proxy or Tor).',
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ShadInput(
                      controller: _upstreamHostController,
                      placeholder: const Text('Upstream Host (e.g. proxy.corp.com)'),
                      onChanged: (val) {
                        proxy.updateUpstream(proxy.upstream.copyWith(host: val));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ShadInput(
                      controller: _upstreamPortController,
                      placeholder: const Text('Port (8080)'),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final p = int.tryParse(val);
                        if (p != null) {
                          proxy.updateUpstream(proxy.upstream.copyWith(port: p));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section 4: Basic Proxy Authentication
          ShadCard(
            title: Row(
              children: [
                const Icon(LucideIcons.keyRound, size: 20, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Proxy Authentication (Require Username/Password)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ShadSwitch(
                  value: proxy.auth.enabled,
                  onChanged: (val) {
                    proxy.updateAuth(proxy.auth.copyWith(enabled: val));
                  },
                ),
              ],
            ),
            description: const Text(
              'Require clients to authenticate via RFC 1929 (SOCKS5) or Proxy-Authorization HTTP headers.',
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  Expanded(
                    child: ShadInput(
                      controller: _authUsernameController,
                      placeholder: const Text('Username (e.g. admin)'),
                      onChanged: (val) {
                        proxy.updateAuth(proxy.auth.copyWith(username: val));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ShadInput(
                      controller: _authPasswordController,
                      placeholder: const Text('Password'),
                      obscureText: true,
                      onChanged: (val) {
                        proxy.updateAuth(proxy.auth.copyWith(password: val));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, ProxyServerProvider proxy) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => ShadDialog(
          title: const Text('Add Custom Proxy Rule'),
          description: const Text('Enter domain pattern with optional wildcards (*.example.com)'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ShadButton(
              onPressed: () {
                final pattern = _rulePatternController.text.trim();
                if (pattern.isNotEmpty) {
                  proxy.addRule(ProxyRule(
                    id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
                    type: _ruleType,
                    pattern: pattern,
                    targetHost: _ruleTargetHostController.text.trim(),
                    targetPort: int.tryParse(_ruleTargetPortController.text.trim()),
                    isEnabled: true,
                  ));
                  _rulePatternController.clear();
                  _ruleTargetHostController.clear();
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add Rule'),
            ),
          ],
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rule Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => _ruleType = ProxyRuleType.block),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _ruleType == ProxyRuleType.block
                                ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _ruleType == ProxyRuleType.block ? const Color(0xFFEF4444) : Colors.transparent,
                            ),
                          ),
                          child: const Text('Block Domain', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => _ruleType = ProxyRuleType.rewrite),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _ruleType == ProxyRuleType.rewrite
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _ruleType == ProxyRuleType.rewrite ? const Color(0xFF3B82F6) : Colors.transparent,
                            ),
                          ),
                          child: const Text('Rewrite / Redirect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Domain Pattern', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ShadInput(
                  controller: _rulePatternController,
                  placeholder: const Text('e.g. *.adserver.com or badsite.org'),
                ),
                if (_ruleType == ProxyRuleType.rewrite) ...[
                  const SizedBox(height: 14),
                  const Text('Redirect Target Host', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _ruleTargetHostController,
                    placeholder: const Text('e.g. 192.168.1.50 or localhost'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 5: CLIENT SETUP & PAC
  // ==========================================

  Widget _buildClientSetupTab(BuildContext context, ProxyServerProvider proxy, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PAC Card
          ShadCard(
            title: const Row(
              children: [
                Icon(LucideIcons.fileCode, size: 20, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text('Automatic Proxy Configuration (PAC Script)'),
              ],
            ),
            description: const Text(
              'Devices can point their "Auto Proxy URL" directly to this address without manual port typing.',
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            proxy.pacUrl,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.blue),
                          ),
                        ),
                        ShadButton.ghost(
                          size: ShadButtonSize.sm,
                          onPressed: () => _copyToClipboard(proxy.pacUrl, 'PAC URL'),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.copy, size: 14),
                              SizedBox(width: 4),
                              Text('Copy'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 1-Click Code Snippets
          ShadCard(
            title: const Row(
              children: [
                Icon(LucideIcons.terminal, size: 20, color: Color(0xFF3B82F6)),
                SizedBox(width: 8),
                Text('Terminal & CLI Setup Commands'),
              ],
            ),
            description: const Text('Quick commands to configure developer tools to route through this proxy.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                children: [
                  _buildCommandSnippet('cURL Test', proxy.curlCommand, isDark),
                  const SizedBox(height: 10),
                  _buildCommandSnippet('Git Proxy', proxy.gitCommand, isDark),
                  const SizedBox(height: 10),
                  _buildCommandSnippet('NPM Proxy', proxy.npmCommand, isDark),
                  const SizedBox(height: 10),
                  _buildCommandSnippet('Windows PowerShell', proxy.powershellCommand, isDark),
                  const SizedBox(height: 10),
                  _buildCommandSnippet('Linux / macOS Bash', proxy.bashCommand, isDark),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Step by step Mobile guides
          ShadCard(
            title: const Row(
              children: [
                Icon(LucideIcons.smartphone, size: 20, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('Mobile Wi-Fi Setup Guide (Android & iOS)'),
              ],
            ),
            description: const Text('How to route all smartphone Wi-Fi traffic through this computer.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSetupStep('1. Connect to Same Wi-Fi', 'Ensure your phone and this computer are connected to the same local Wi-Fi router or mobile hotspot.'),
                  _buildSetupStep('2. Open Wi-Fi Network Details', 'On your phone, go to Settings → Wi-Fi → Tap your connected Wi-Fi network (or gear icon).'),
                  _buildSetupStep('3. Change Proxy to Manual', 'Select "Proxy" and change from None to "Manual".'),
                  _buildSetupStep('4. Enter Hostname & Port', 'Proxy Hostname: ${proxy.effectiveIp}\nProxy Port: ${proxy.port}'),
                  _buildSetupStep('5. Save and Browse', 'Tap Save. All web requests will now be logged and filtered in this app!'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandSnippet(String label, String command, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              command,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.blue),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.copy, size: 15),
            onPressed: () => _copyToClipboard(command, label),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupStep(String stepTitle, String stepDesc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stepTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(stepDesc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
