import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/audit_entry.dart';
import '../services/audit_service.dart';

/// Cryptographically chained Audit Trail Timeline Screen.
/// Displays immutable SHA-256 blackbox event logs, integrity verification,
/// CSV export, and 5-minute emergency distress unlock controller.
class AuditTimelineScreen extends StatefulWidget {
  const AuditTimelineScreen({super.key});

  @override
  State<AuditTimelineScreen> createState() => _AuditTimelineScreenState();
}

class _AuditTimelineScreenState extends State<AuditTimelineScreen> {
  List<AuditEntry> _entries = [];
  bool _isLoading = true;
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  IntegrityVerificationResult? _verificationResult;
  bool _isVerifying = false;

  // Emergency bypass state
  bool _isEmergencyActive = false;
  int _emergencyRemainingSeconds = 0;
  Timer? _emergencyTimer;

  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'ALL',
    'DISTRACTION_PREVENTION',
    'Audit & Geospatial',
  ];

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
    _checkEmergencyStatus();
    _verifyIntegrity();
  }

  @override
  void dispose() {
    _emergencyTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoading = true);
    final logs = await AuditService.getAuditLogs(
      limit: 200,
      category: _selectedCategory == 'ALL' ? null : _selectedCategory,
    );
    if (mounted) {
      setState(() {
        _entries = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyIntegrity() async {
    setState(() => _isVerifying = true);
    final result = await AuditService.verifyAuditIntegrity();
    if (mounted) {
      setState(() {
        _verificationResult = result;
        _isVerifying = false;
      });
    }
  }

  Future<void> _checkEmergencyStatus() async {
    final active = await AuditService.isEmergencyBypassActive();
    final remaining = await AuditService.getEmergencyBypassRemainingSeconds();
    if (mounted) {
      setState(() {
        _isEmergencyActive = active;
        _emergencyRemainingSeconds = remaining;
      });
      if (active && _emergencyTimer == null) {
        _startEmergencyCountdown();
      }
    }
  }

  void _startEmergencyCountdown() {
    _emergencyTimer?.cancel();
    _emergencyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_emergencyRemainingSeconds > 0) {
        setState(() {
          _emergencyRemainingSeconds--;
        });
      } else {
        timer.cancel();
        _emergencyTimer = null;
        setState(() {
          _isEmergencyActive = false;
        });
        _loadAuditLogs();
      }
    });
  }

  Future<void> _exportCsv() async {
    final csv = await AuditService.exportAuditCsv();
    if (csv.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audit logs available to export.')),
        );
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF18181B),
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Text(
                'Audit CSV copied to clipboard!',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _showEmergencyUnlockDialog() async {
    final reasonController = TextEditingController(text: 'Urgent Family/Work Contact');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text(
              'Emergency Distress Bypass',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This unlocks all apps for 5 minutes. The incident and your GPS coordinates will be immutably recorded in the SHA-256 blackbox audit trail.',
              style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Distress Justification:',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF27272A),
                hintText: 'Enter reason...',
                hintStyle: const TextStyle(color: Color(0xFF71717A)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF71717A))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Unlock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim().isEmpty ? 'Distress Override' : reasonController.text.trim();
      final until = await AuditService.triggerEmergencyBypass(reason: reason);
      if (until != null) {
        await _checkEmergencyStatus();
        await _loadAuditLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF18181B),
              content: Text(
                '🚨 5-Minute Emergency Bypass Activated until ${until.hour}:${until.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Color(0xFFF97316)),
              ),
            ),
          );
        }
      }
    }
  }

  List<AuditEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries.where((e) {
      return e.packageName.toLowerCase().contains(q) ||
          e.eventType.toLowerCase().contains(q) ||
          e.payload.toLowerCase().contains(q) ||
          e.currentHash.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        title: const Text(
          '📜 Blackbox Audit Trail',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Color(0xFF10B981)),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF71717A)),
            tooltip: 'Refresh',
            onPressed: () {
              _loadAuditLogs();
              _verifyIntegrity();
              _checkEmergencyStatus();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadAuditLogs();
          await _verifyIntegrity();
          await _checkEmergencyStatus();
        },
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF18181B),
        child: Column(
          children: [
            // ─── Emergency Bypass Active Banner ───
            if (_isEmergencyActive) _buildEmergencyBanner(),

            // ─── Cryptographic Verification & Action Bar ───
            _buildIntegrityHeader(),

            // ─── Search & Category Filters ───
            _buildFilterSection(),

            // ─── Event Timeline ───
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF10B981)),
                    )
                  : _filteredEntries.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredEntries.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildAuditEntryCard(_filteredEntries[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFEF4444),
        icon: const Icon(Icons.emergency_rounded, color: Colors.white),
        label: const Text(
          'Distress Unlock',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _showEmergencyUnlockDialog,
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    final mins = _emergencyRemainingSeconds ~/ 60;
    final secs = _emergencyRemainingSeconds % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EMERGENCY DISTRESS BYPASS ACTIVE',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'All apps unlocked. Auto-relocking in $timeStr',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrityHeader() {
    final isValid = _verificationResult?.isValid ?? false;
    final isDone = _verificationResult != null && !_isVerifying;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? (isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444))
              : const Color(0xFF27272A),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  )
                : Icon(
                    isValid ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                    color: isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isVerifying
                      ? 'Verifying cryptographic chain...'
                      : isValid
                          ? 'Chain Verified (SHA-256 Chained)'
                          : 'Chain Tampering Detected!',
                  style: TextStyle(
                    color: isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  isValid
                      ? '${_entries.length} immutable events verified from Genesis'
                      : 'Broken link detected at block #${_verificationResult?.brokenAtId ?? -1}',
                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _isVerifying ? null : _verifyIntegrity,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: const Color(0xFF27272A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Re-Verify', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF18181B),
              hintText: 'Search by package, event, or hash...',
              hintStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF71717A), size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF71717A), size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF27272A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF27272A)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Category pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    cat == 'ALL' ? 'All Events' : cat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                  backgroundColor: const Color(0xFF18181B),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFF27272A),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (_) {
                    setState(() => _selectedCategory = cat);
                    _loadAuditLogs();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildAuditEntryCard(AuditEntry entry) {
    final timeStr =
        '${entry.dateTime.month}/${entry.dateTime.day} ${entry.dateTime.hour}:${entry.dateTime.minute.toString().padLeft(2, '0')}:${entry.dateTime.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon, EventType, Timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: entry.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(entry.icon, color: entry.accentColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.eventType,
                  style: TextStyle(
                    color: entry.accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(color: Color(0xFF71717A), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Payload description
          Text(
            entry.payload,
            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 10),

          // Bottom Metadata Row: Package, Hash, Location
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (entry.packageName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.packageName,
                    style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 10),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag, size: 10, color: Color(0xFF71717A)),
                    Text(
                      entry.shortHash,
                      style: const TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.hasLocation)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 10, color: Color(0xFF10B981)),
                      const SizedBox(width: 2),
                      Text(
                        '${entry.latitude.toStringAsFixed(3)}, ${entry.longitude.toStringAsFixed(3)}',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.shield_outlined, color: Color(0xFF71717A), size: 48),
          SizedBox(height: 12),
          Text(
            'No audit events found',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Interventions, geofence crosses, and bypasses will appear here.',
            style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
