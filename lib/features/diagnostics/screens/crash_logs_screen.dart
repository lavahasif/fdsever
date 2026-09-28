import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/services/crash_log_service.dart';

class CrashLogsScreen extends StatefulWidget {
  const CrashLogsScreen({super.key});

  @override
  State<CrashLogsScreen> createState() => _CrashLogsScreenState();
}

class _CrashLogsScreenState extends State<CrashLogsScreen> {
  final CrashLogService _crashService = CrashLogService();
  final Set<String> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _crashService.addListener(_onServiceUpdate);
    _crashService.syncNativeCrashLogs();
  }

  @override
  void dispose() {
    _crashService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.checkCheck, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('$label copied! Ready to paste directly into AI.')),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF18181B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _triggerTestError() {
    try {
      throw StateError('Simulated test exception in FDServer to verify Crash & AI prompt recording.');
    } catch (e, stack) {
      _crashService.recordManualError(
        'TestDiagnostic',
        e,
        stack,
        {'action': 'User pressed "Test Crash Capture" button'},
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Simulated error captured and persisted! Tap "Copy for AI" to test.'),
          backgroundColor: Color(0xFF27272A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logs = _crashService.logs;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(LucideIcons.fileWarning, size: 20, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Crash Logs & AI Diagnostics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (logs.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withAlpha(80)),
                ),
                child: Text(
                  '${logs.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
              ),
          ],
        ),
        actions: [
          if (logs.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.copy, size: 18),
              tooltip: 'Copy All Logs for AI',
              onPressed: () => _copyToClipboard(
                _crashService.generateFullDiagnosticsAiPrompt(),
                'Complete diagnostic report',
              ),
            ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Sync Native Android Crashes',
            onPressed: () => _crashService.syncNativeCrashLogs(),
          ),
          if (logs.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 18),
              tooltip: 'Clear All Logs',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Crash Logs?'),
                    content: const Text('Are you sure you want to clear all recorded crash and exception events?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _crashService.clearAllLogs();
                }
              },
            ),
        ],
      ),
      body: logs.isEmpty ? _buildEmptyState(isDark) : _buildLogsList(logs, isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.withAlpha(70)),
              ),
              child: const Icon(LucideIcons.shieldCheck, size: 48, color: Colors.green),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Crashes or Exceptions Recorded',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'All FDServer background services, proxy tunnels, and socket listeners are operating normally without errors.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _triggerTestError,
              icon: const Icon(LucideIcons.bug, size: 16),
              label: const Text('Trigger Test Error & Check AI Prompt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList(List<CrashLogItem> logs, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top banner: One click copy for AI
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B4B), const Color(0xFF18181B)]
                  : [const Color(0xFFEEF2FF), Colors.white],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6366F1).withAlpha(100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.sparkles, color: Color(0xFF818CF8), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Diagnostic Assistant Ready',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => _copyToClipboard(
                      _crashService.generateFullDiagnosticsAiPrompt(),
                      'Complete diagnostic report',
                    ),
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text('Copy All for AI', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Copying generates a complete, structured prompt containing device specs, full stack traces, and preceding activity breadcrumbs formatted specifically for ChatGPT, Claude, or Gemini.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recorded Events (${logs.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: _triggerTestError,
              icon: const Icon(LucideIcons.bug, size: 14),
              label: const Text('Test Capture', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...logs.map((log) => _buildCrashCard(log, isDark)),
      ],
    );
  }

  Widget _buildCrashCard(CrashLogItem log, bool isDark) {
    final isExpanded = _expandedItems.contains(log.id);
    final isNative = log.type.contains('NATIVE');

    Color typeColor = Colors.redAccent;
    if (isNative) {
      typeColor = Colors.orangeAccent;
    } else if (log.type.contains('ASYNC')) {
      typeColor = Colors.amberAccent;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
      ),
      color: isDark ? const Color(0xFF18181B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type badge, Component, Timestamp
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: typeColor.withAlpha(80)),
                  ),
                  child: Text(
                    log.type,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.component,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  log.timestamp,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Error Message Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(30)),
              ),
              child: SelectableText(
                log.message,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Device Context Pill
            Row(
              children: [
                Icon(LucideIcons.smartphone, size: 13, color: isDark ? Colors.white54 : Colors.black45),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${log.deviceModel} • ${log.osVersion}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Buttons: Expand Stack Trace & Copy for AI
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedItems.remove(log.id);
                      } else {
                        _expandedItems.add(log.id);
                      }
                    });
                  },
                  icon: Icon(isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 14),
                  label: Text(
                    isExpanded ? 'Hide Trace' : 'View Trace (${log.breadcrumbs.length} breadcrumbs)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _copyToClipboard(log.toAiPrompt(), 'AI crash prompt'),
                  icon: const Icon(LucideIcons.copy, size: 13),
                  label: const Text('Copy for AI', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            // Expanded details: Breadcrumbs & Stack Trace
            if (isExpanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              if (log.breadcrumbs.isNotEmpty) ...[
                const Text('Recent Actions Before Crash:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: log.breadcrumbs
                        .map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '• [${b.timestamp}] ${b.category}: ${b.message}',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              const Text('Stack Trace:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
                  child: SelectableText(
                    log.stackTrace.isNotEmpty ? log.stackTrace : 'No stack trace recorded.',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
