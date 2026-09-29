import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/focus_config_model.dart';
import '../providers/focus_guard_provider.dart';
import '../services/motivation_quote_service.dart';
import 'motivation_reader_screen.dart';

class RealityCheckScreen extends StatefulWidget {
  final String? blockedPackage;
  final String? blockReason;

  const RealityCheckScreen({
    super.key,
    this.blockedPackage,
    this.blockReason,
  });

  @override
  State<RealityCheckScreen> createState() => _RealityCheckScreenState();
}

class _RealityCheckScreenState extends State<RealityCheckScreen> {
  final TextEditingController _mathController = TextEditingController();
  final TextEditingController _oathController = TextEditingController();
  bool _showUnlockDrawer = false;
  int _activeUnlockTab = 0; // 0: Math, 1: Oath
  String? _errorMessage;
  late RealityQuote _currentQuote;
  String? _apiQuoteText;
  String? _apiQuoteAuthor;
  bool _isQuoteRefreshing = false;

  @override
  void initState() {
    super.initState();
    final quotes = RealityQuote.curatedQuotes;
    _currentQuote = quotes[DateTime.now().second % quotes.length];
    _fetchLiveQuote();
  }

  Future<void> _fetchLiveQuote({bool forceRefresh = false}) async {
    setState(() => _isQuoteRefreshing = true);
    final q = await MotivationQuoteService.getInspirationalQuote(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _apiQuoteText = q.text;
        _apiQuoteAuthor = q.author;
        _isQuoteRefreshing = false;
      });
    }
  }

  @override
  void dispose() {
    _mathController.dispose();
    _oathController.dispose();
    super.dispose();
  }

  String _formatReason(String? reason, String? pkg) {
    if (reason == 'youtube_shorts') return 'YouTube Shorts Feed Intercepted';
    if (reason == 'instagram_reels') return 'Instagram Reels Loop Blocked';
    if (pkg != null && pkg.isNotEmpty) {
      if (pkg.contains('instagram')) return 'Instagram Blocked';
      if (pkg.contains('tiktok') || pkg.contains('musically')) return 'TikTok Blocked';
      if (pkg.contains('facebook')) return 'Facebook Blocked';
      if (pkg.contains('twitter')) return 'X / Twitter Blocked';
      return '$pkg Blocked';
    }
    return 'Addictive Distraction Prevented';
  }

  void _verifyMath(FocusGuardProvider provider) {
    final val = int.tryParse(_mathController.text.trim());
    if (val == null) {
      setState(() => _errorMessage = 'Enter a valid number');
      return;
    }

    final success = provider.verifyAndEmergencyUnlockWithMath(val);
    if (success) {
      provider.clearPendingIntervention();
      Navigator.of(context).pop();
    } else {
      setState(() {
        _errorMessage = 'Incorrect! New harder challenge generated.';
        _mathController.clear();
      });
    }
  }

  void _verifyOath(FocusGuardProvider provider) {
    final success = provider.verifyAndEmergencyUnlockWithOath(_oathController.text);
    if (success) {
      provider.clearPendingIntervention();
      Navigator.of(context).pop();
    } else {
      setState(() {
        _errorMessage = 'Oath text does not match word-for-word!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusGuardProvider>();
    final reasonText = _formatReason(widget.blockReason, widget.blockedPackage);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Warning badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.shieldAlert, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Text(
                      reasonText.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Shield Icon with Pulse Halo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0x33DC2626),
                      Color(0x00DC2626),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFDC2626), width: 2),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.lockKeyhole,
                    size: 48,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Stark Title
              const Text(
                'STOP. REALITY CHECK.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              // Harsh Quote Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(LucideIcons.sparkles, color: Color(0xFFEF4444), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'REALITY WAKE-UP',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: _isQuoteRefreshing ? null : () => _fetchLiveQuote(forceRefresh: true),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: _isQuoteRefreshing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                                  )
                                : const Icon(LucideIcons.refreshCw, size: 14, color: Color(0xFFA1A1AA)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        '"${_apiQuoteText ?? _currentQuote.quote}"',
                        key: ValueKey<String>(_apiQuoteText ?? _currentQuote.quote),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                          color: Color(0xFFE4E4E7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '— ${_apiQuoteAuthor ?? _currentQuote.author}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFA1A1AA),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Life Goal Anchor Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      const Color(0xFFD97706).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.trophy, color: Color(0xFFF59E0B), size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR COMMITTED GOAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            provider.targetGoal,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      icon: LucideIcons.shieldCheck,
                      title: 'Distractions Killed',
                      value: '${provider.temptationsResisted}',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMiniStat(
                      icon: LucideIcons.hourglass,
                      title: 'Minutes Saved',
                      value: '${provider.minutesSaved}m',
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Primary Action: Return to Work
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    provider.clearPendingIntervention();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(LucideIcons.arrowLeft, size: 18),
                  label: const Text(
                    'I HEAR YOU. BACK TO PRODUCTIVITY',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Educational Diversion Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA78BFA),
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        provider.clearPendingIntervention();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => MotivationReaderScreen(
                              reason: widget.blockReason,
                              blockedPackage: widget.blockedPackage,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.bookOpen, size: 16),
                      label: const Text('Read Mindset Guide', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        provider.clearPendingIntervention();
                        const videoUrl = 'https://www.youtube.com/watch?v=kYfNvmF0Bqw';
                        final uri = Uri.parse(videoUrl);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      },
                      icon: const Icon(LucideIcons.video, size: 16),
                      label: const Text('Watch Pep Video', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Emergency Hardcore Unlock Toggle
              TextButton(
                onPressed: () {
                  setState(() {
                    _showUnlockDrawer = !_showUnlockDrawer;
                    _errorMessage = null;
                  });
                },
                child: Text(
                  _showUnlockDrawer ? '▲ Hide Emergency Unlock Challenge' : '▼ Need Emergency Access? (Hardcore Challenge)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _showUnlockDrawer ? const Color(0xFFEF4444) : const Color(0xFF71717A),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              if (_showUnlockDrawer) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildTabButton('Math Challenge', 0),
                          const SizedBox(width: 8),
                          _buildTabButton('Accountability Pledge', 1),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_activeUnlockTab == 0) ...[
                        Text(
                          'Solve to unlock: ${provider.mathQuestion}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Calculate mentally. No calculator. Your brain must do real work before giving up.',
                          style: TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _mathController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: InputDecoration(
                            hintText: 'Enter answer',
                            hintStyle: const TextStyle(color: Color(0xFF71717A)),
                            filled: true,
                            fillColor: const Color(0xFF27272A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _verifyMath(provider),
                            child: const Text('Verify & Break Lock'),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Type this exact sentence to unlock:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27272A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            FocusGuardProvider.hardcoreOath,
                            style: TextStyle(fontSize: 12, color: Color(0xFFFCA5A5), fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _oathController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Type sentence exactly above...',
                            hintStyle: const TextStyle(color: Color(0xFF71717A)),
                            filled: true,
                            fillColor: const Color(0xFF27272A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _verifyOath(provider),
                            child: const Text('Confirm & Relinquish Lock'),
                          ),
                        ),
                      ],

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, color: Color(0xFFA1A1AA)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _activeUnlockTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeUnlockTab = index;
            _errorMessage = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF27272A) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : const Color(0xFF71717A),
            ),
          ),
        ),
      ),
    );
  }
}
