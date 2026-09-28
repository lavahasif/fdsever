import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/focus_guard_provider.dart';

class AppBlacklistScreen extends StatefulWidget {
  const AppBlacklistScreen({super.key});

  @override
  State<AppBlacklistScreen> createState() => _AppBlacklistScreenState();
}

class _AppBlacklistScreenState extends State<AppBlacklistScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customPkgController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FocusGuardProvider>();
      if (provider.installedDeviceApps.isEmpty) {
        provider.fetchInstalledApps();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customPkgController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  void _showAddCustomDialog(BuildContext context, FocusGuardProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Add Custom App to Block', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customNameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'App Name (e.g. My Addictive Game)',
                labelStyle: TextStyle(color: Color(0xFFA1A1AA)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customPkgController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Package Name (e.g. com.game.addictive)',
                labelStyle: TextStyle(color: Color(0xFFA1A1AA)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              final pkg = _customPkgController.text.trim();
              final name = _customNameController.text.trim();
              if (pkg.isNotEmpty) {
                provider.addCustomApp(pkg, name.isNotEmpty ? name : pkg);
                _customPkgController.clear();
                _customNameController.clear();
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add to Blacklist', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusGuardProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final blockedList = provider.blockedApps;
    final installedApps = provider.installedDeviceApps.where((app) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final name = (app['appName'] ?? '').toLowerCase();
      final pkg = (app['packageName'] ?? '').toLowerCase();
      return name.contains(query) || pkg.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5),
      appBar: AppBar(
        title: const Text('Blocked Apps & Targets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Add Custom Package',
            onPressed: () => _showAddCustomDialog(context, provider),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Reload Installed Apps',
            onPressed: () => provider.fetchInstalledApps(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shorts & Reels Master Toggle Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEF4444).withValues(alpha: 0.15),
                    const Color(0xFFB91C1C).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.video, color: Color(0xFFEF4444), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YouTube Shorts & Reels Shield',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Allows normal tutorial videos, but instantly intercepts and kills short-form doom feeds.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: provider.blockShortsAndReels,
                    activeThumbColor: const Color(0xFFEF4444),
                    onChanged: (val) => provider.toggleShortsBlocking(val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Active Blacklisted Apps Section
            const Text(
              'Active Blacklisted Apps',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'These apps will be blocked and kicked to home whenever Focus Lock is active.',
              style: TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)),
            ),
            const SizedBox(height: 12),

            ...blockedList.map((app) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                ),
                child: Row(
                  children: [
                    Icon(
                      app.isShortsOnly ? LucideIcons.film : LucideIcons.smartphone,
                      color: app.isBlocked ? const Color(0xFFEF4444) : const Color(0xFF71717A),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.appName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            app.packageName,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF71717A)),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: app.isBlocked,
                      activeThumbColor: const Color(0xFFEF4444),
                      onChanged: (val) => provider.toggleAppBlocked(app.packageName),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),

            // Installed Apps Picker Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add from Installed Apps',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (provider.isLoadingApps)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search installed games, social apps...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (installedApps.isEmpty && !provider.isLoadingApps)
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _searchQuery.isNotEmpty ? 'No apps matching "$_searchQuery"' : 'Tap reload icon above to scan installed apps.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: installedApps.take(40).length,
                itemBuilder: (context, index) {
                  final app = installedApps[index];
                  final pkg = app['packageName'] ?? '';
                  final name = app['appName'] ?? '';
                  final isAlreadyBlocked = blockedList.any((b) => b.packageName == pkg && b.isBlocked);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141416) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.appWindow, size: 18, color: Color(0xFFA1A1AA)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(pkg, style: const TextStyle(fontSize: 9, color: Color(0xFF71717A))),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (isAlreadyBlocked) {
                              provider.toggleAppBlocked(pkg);
                            } else {
                              provider.addCustomApp(pkg, name);
                            }
                          },
                          child: Text(
                            isAlreadyBlocked ? 'Remove' : '+ Block',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isAlreadyBlocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
