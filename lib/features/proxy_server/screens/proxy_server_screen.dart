import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/models/proxy_models.dart';
import '../../../shared/widgets/status_badge.dart';
import '../providers/proxy_provider.dart';

class ProxyServerScreen extends StatefulWidget {
  const ProxyServerScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProxyServerProvider>();
    _hostController = TextEditingController(text: provider.host);
    _portController = TextEditingController(text: provider.port.toString());
    _reverseHostController = TextEditingController(text: provider.reverseProxyHost);
    _reversePortController = TextEditingController(text: provider.reverseProxyPort.toString());
    _searchController = TextEditingController(text: provider.searchQuery);
    _tabController = TabController(length: 5, vsync: this);

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
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _reverseHostController.dispose();
    _reversePortController.dispose();
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

    // Determine aggregate status label
    String activeLabel = 'PROXY RUNNING';
    final bool isAnyActive = proxy.isRunning || proxy.isReverseProxyRunning;
    if (proxy.isRunning && proxy.isReverseProxyRunning) {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                StatusBadge(
                  isActive: isAnyActive,
                  activeLabel: activeLabel,
                  inactiveLabel: 'PROXIES STOPPED',
                ),
              ],
            ),
          ),

          // Main Tabs Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(context, proxy, isDark),
                _buildReverseProxyTab(context, proxy, isDark),
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

          // Error Alert
          if (proxy.errorMessage != null) ...[
            ShadAlert.destructive(
              icon: const Icon(LucideIcons.triangleAlert, size: 16),
              title: const Text('Proxy Server Error'),
              description: Text(proxy.errorMessage!),
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
                    Row(
                      children: [
                        Text(
                          proxy.isRunning ? 'Forward Proxy is Active & Forwarding' : 'Forward Proxy is Offline',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
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
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.8,
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
          Text('Automatic IP Discovery & Binding (${proxy.systemIps.length} interfaces)'),
          const Spacer(),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
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
                  proxy.isSearchingIps ? 'Scanning...' : 'Refresh Interfaces',
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
                    Row(
                      children: [
                        Text(
                          proxy.isReverseProxyRunning ? 'Reverse Gateway is Live' : 'Reverse Proxy is Stopped',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
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
          Text('Configured Backend Routes (${proxy.reverseProxyRoutes.length})'),
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
      title: Row(
        children: [
          const Icon(LucideIcons.slidersHorizontal, size: 18),
          const SizedBox(width: 8),
          const Text('Reverse Proxy Network & Port Binding'),
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
            Text('Request Details (${log.protocol.displayName})'),
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
                const Text('Domain Filtering & Ad-Block Shield'),
                const Spacer(),
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
                const Text('Upstream Proxy Chaining'),
                const Spacer(),
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
                const Text('Proxy Authentication (Require Username/Password)'),
                const Spacer(),
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
