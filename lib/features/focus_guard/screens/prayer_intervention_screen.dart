import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/prayer_dhikr_model.dart';
import '../providers/focus_guard_provider.dart';
import '../services/prayer_dhikr_service.dart';

class PrayerInterventionScreen extends StatefulWidget {
  final String? blockedPackage;
  final String? blockReason;

  const PrayerInterventionScreen({
    super.key,
    this.blockedPackage,
    this.blockReason,
  });

  @override
  State<PrayerInterventionScreen> createState() => _PrayerInterventionScreenState();
}

class _PrayerInterventionScreenState extends State<PrayerInterventionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PrayerDhikrService _prayerService = PrayerDhikrService();

  late PrayerNoteItem _currentPrayer;
  int _selectedDhikrIndex = 0;
  String _notesSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _prayerService.init().then((_) {
      if (mounted) {
        setState(() {
          _currentPrayer = _prayerService.getPrayerForIntervention();
          if (_prayerService.isAlwaysShowDhikrEnabled) {
            _tabController.index = 1; // Default to Dhikr
          }
        });
      }
    });

    _currentPrayer = _prayerService.getPrayerForIntervention();
    final initialTab = _prayerService.isAlwaysShowDhikrEnabled ? 1 : 0;
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatReason(String? reason, String? pkg) {
    if (reason == 'youtube_shorts') return 'YouTube Shorts Intercepted';
    if (reason == 'instagram_reels') return 'Instagram Reels Loop Paused';
    if (pkg != null && pkg.isNotEmpty) {
      if (pkg.contains('youtube')) return 'YouTube Paused';
      if (pkg.contains('instagram')) return 'Instagram Paused';
      if (pkg.contains('tiktok') || pkg.contains('musically')) return 'TikTok Paused';
      if (pkg.contains('facebook')) return 'Facebook Paused';
      if (pkg.contains('twitter')) return 'X / Twitter Paused';
      return '$pkg Paused';
    }
    return 'Dopamine Impulse Intercepted';
  }

  void _nextRandomPrayer() {
    setState(() {
      _currentPrayer = _prayerService.getPrayerForIntervention(forceRandom: true);
    });
  }

  void _showAddPrayerDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final arabicCtrl = TextEditingController();
    final transliterationCtrl = TextEditingController();
    final translationCtrl = TextEditingController();
    final referenceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog(
        title: const Text('Add Custom Prayer Note / Dua'),
        description: const Text(
          'Save your favorite prayer, personal reflection, or Quranic verse for mindful pauses.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || translationCtrl.text.trim().isEmpty) {
                return;
              }
              await _prayerService.addPrayerNote(
                title: titleCtrl.text.trim(),
                arabic: arabicCtrl.text.trim(),
                transliteration: transliterationCtrl.text.trim(),
                translation: translationCtrl.text.trim(),
                reference: referenceCtrl.text.trim().isEmpty
                    ? 'Personal Reflection'
                    : referenceCtrl.text.trim(),
                note: noteCtrl.text.trim(),
              );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ShadToaster.of(context).show(
                  const ShadToast(
                    title: Text('Prayer Note Saved'),
                    description: Text('Your custom prayer note is now available.'),
                  ),
                );
              }
              setState(() {});
            },
            child: const Text('Save Prayer Note'),
          ),
        ],
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputLabel('Title *'),
                ShadInput(
                  controller: titleCtrl,
                  placeholder: const Text('e.g. Dua for Deep Focus & Sincerity'),
                ),
                const SizedBox(height: 10),
                _inputLabel('Arabic Text (optional)'),
                ShadInput(
                  controller: arabicCtrl,
                  placeholder: const Text('اللَّهُمَّ...'),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 10),
                _inputLabel('Transliteration (optional)'),
                ShadInput(
                  controller: transliterationCtrl,
                  placeholder: const Text('Allahumma inni...'),
                ),
                const SizedBox(height: 10),
                _inputLabel('Translation & Meaning *'),
                ShadInput(
                  controller: translationCtrl,
                  placeholder: const Text('O Allah, grant me...'),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                _inputLabel('Reference / Source (optional)'),
                ShadInput(
                  controller: referenceCtrl,
                  placeholder: const Text('e.g. Sahih Muslim or Quran 20:114'),
                ),
                const SizedBox(height: 10),
                _inputLabel('Personal Reflection / Notes'),
                ShadInput(
                  controller: noteCtrl,
                  placeholder: const Text('Why this prayer helps you reset...'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddDhikrDialog(BuildContext context) {
    final arabicCtrl = TextEditingController();
    final transliterationCtrl = TextEditingController();
    final translationCtrl = TextEditingController();
    final virtueCtrl = TextEditingController();
    final countCtrl = TextEditingController(text: '33');

    showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog(
        title: const Text('Add Custom Dhikr'),
        description: const Text(
          'Register a new remembrance (Adhkar) to your digital Tasbih counter.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: () async {
              if (transliterationCtrl.text.trim().isEmpty) return;
              final target = int.tryParse(countCtrl.text.trim()) ?? 33;
              await _prayerService.addDhikrItem(
                arabic: arabicCtrl.text.trim(),
                transliteration: transliterationCtrl.text.trim(),
                translation: translationCtrl.text.trim(),
                virtue: virtueCtrl.text.trim(),
                targetCount: target,
              );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ShadToaster.of(context).show(
                  const ShadToast(
                    title: Text('Dhikr Added'),
                    description: Text('New Dhikr is ready on your Tasbih.'),
                  ),
                );
              }
              setState(() {});
            },
            child: const Text('Add Dhikr'),
          ),
        ],
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputLabel('Arabic Remembrance'),
                ShadInput(
                  controller: arabicCtrl,
                  placeholder: const Text('سُبْحَانَ اللَّهِ...'),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 10),
                _inputLabel('Transliteration *'),
                ShadInput(
                  controller: transliterationCtrl,
                  placeholder: const Text('e.g. SubhanAllah wa bihamdihi'),
                ),
                const SizedBox(height: 10),
                _inputLabel('English Translation'),
                ShadInput(
                  controller: translationCtrl,
                  placeholder: const Text('Glory be to Allah and His praise'),
                ),
                const SizedBox(height: 10),
                _inputLabel('Virtue / Blessing (optional)'),
                ShadInput(
                  controller: virtueCtrl,
                  placeholder: const Text('e.g. 100 times forgives minor sins'),
                ),
                const SizedBox(height: 10),
                _inputLabel('Target Count per Cycle (e.g. 33, 100, 10)'),
                ShadInput(
                  controller: countCtrl,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA1A1AA)),
      ),
    );
  }

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F3F46),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(LucideIcons.settings, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Prayer & Dhikr Preferences',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Configure how spiritual interruptions occur when blocked apps open.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)),
                  ),
                  const SizedBox(height: 20),
                  // Random prayer toggle
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.shuffle, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Randomly Pick Prayer / Dua',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                'Presents a fresh authentic prayer or note each time a distraction occurs',
                                style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA)),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _prayerService.isRandomPrayerEnabled,
                          activeTrackColor: const Color(0xFF10B981),
                          onChanged: (val) async {
                            await _prayerService.setRandomPrayerEnabled(val);
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Always show Dhikr toggle
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.repeat, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Always Show Dhikr First',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                'Directs immediately to the Tasbih counter on app block instead of prayer notes',
                                style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA)),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _prayerService.isAlwaysShowDhikrEnabled,
                          activeTrackColor: const Color(0xFF10B981),
                          onChanged: (val) async {
                            await _prayerService.setAlwaysShowDhikrEnabled(val);
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final focusProvider = context.read<FocusGuardProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF090D0C), // Deep obsidian with subtle emerald tint
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with distraction notification
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0E1A17),
                border: Border(bottom: BorderSide(color: Color(0xFF16382F))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(LucideIcons.sparkles, color: Color(0xFF34D399), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatReason(widget.blockReason, widget.blockedPackage),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pausing for mindfulness & spiritual renewal',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6EE7B7)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.slidersHorizontal, color: Color(0xFFA1A1AA), size: 18),
                    tooltip: 'Preferences',
                    onPressed: () => _showSettingsModal(context),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Color(0xFFA1A1AA), size: 20),
                    tooltip: 'Dismiss',
                    onPressed: () {
                      focusProvider.clearPendingIntervention();
                      Navigator.of(context).maybePop();
                    },
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: const Color(0xFF0C1412),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF10B981),
                indicatorWeight: 3,
                labelColor: const Color(0xFF34D399),
                unselectedLabelColor: const Color(0xFF71717A),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(
                    icon: Icon(LucideIcons.bookHeart, size: 18),
                    text: 'Prayer & Dua',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.circleDot, size: 18),
                    text: 'Dhikr Tasbih',
                  ),
                  Tab(
                    icon: Icon(LucideIcons.notebookPen, size: 18),
                    text: 'Prayer Notes',
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPrayerTab(context),
                  _buildDhikrTab(context),
                  _buildPrayerNotesListTab(context),
                ],
              ),
            ),

            // Bottom mindful completion bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0E1A17),
                border: Border(top: BorderSide(color: Color(0xFF16382F))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        focusProvider.clearPendingIntervention();
                        Navigator.of(context).maybePop();
                      },
                      icon: const Icon(LucideIcons.checkCheck, size: 18),
                      label: const Text(
                        'I Am Grounded – Back to Purpose',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 1: PRAYER & DUA ───────────────────────────────────────────────────

  Widget _buildPrayerTab(BuildContext context) {
    final isRandom = _prayerService.isRandomPrayerEnabled;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner row with random indicator and shuffle button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isRandom
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isRandom
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                        : const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRandom ? LucideIcons.shuffle : LucideIcons.pin,
                      size: 13,
                      color: isRandom ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isRandom ? 'Randomly Selected Prayer' : 'Selected Anchor Prayer',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isRandom ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isRandom)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF34D399),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: _nextRandomPrayer,
                  icon: const Icon(LucideIcons.refreshCw, size: 13),
                  label: const Text('Next Prayer', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Main Prayer Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2621), Color(0xFF111E1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Text(
                  _currentPrayer.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF0FDF4),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                // Reference
                Row(
                  children: [
                    const Icon(LucideIcons.bookmarkCheck, size: 13, color: Color(0xFF10B981)),
                    const SizedBox(width: 5),
                    Text(
                      _currentPrayer.reference,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA7F3D0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                if (_currentPrayer.arabic.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  // Arabic Text Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF061411),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1A463B)),
                    ),
                    child: Text(
                      _currentPrayer.arabic,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFFDE68A), // Warm gold
                        height: 2.1,
                      ),
                    ),
                  ),
                ],

                if (_currentPrayer.transliteration.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _currentPrayer.transliteration,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFCBD5E1),
                      height: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(color: Color(0xFF163E33), height: 1),
                const SizedBox(height: 14),

                // Translation
                const Text(
                  'MEANING & PURPOSE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _currentPrayer.translation,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                if (_currentPrayer.note.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF061A15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0E382D)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.lightbulb, size: 15, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentPrayer.note,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Card actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.copy, size: 16, color: Color(0xFFA1A1AA)),
                      tooltip: 'Copy Prayer',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: '${_currentPrayer.title}\n\n'
                                '${_currentPrayer.arabic}\n\n'
                                '${_currentPrayer.transliteration}\n\n'
                                '${_currentPrayer.translation}\n\n'
                                '(${_currentPrayer.reference})',
                          ),
                        );
                        ShadToaster.of(context).show(
                          const ShadToast(
                            title: Text('Copied to Clipboard'),
                            description: Text('Prayer text and translation copied.'),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _currentPrayer.isFavorite ? LucideIcons.heartHandshake : LucideIcons.heart,
                        size: 17,
                        color: _currentPrayer.isFavorite ? const Color(0xFFEF4444) : const Color(0xFFA1A1AA),
                      ),
                      tooltip: 'Favorite',
                      onPressed: () async {
                        await _prayerService.togglePrayerFavorite(_currentPrayer.id);
                        setState(() {
                          _currentPrayer = _currentPrayer.copyWith(
                            isFavorite: !_currentPrayer.isFavorite,
                          );
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF34D399),
                      ),
                      onPressed: () => _showAddPrayerDialog(context),
                      icon: const Icon(LucideIcons.plus, size: 14),
                      label: const Text('Add Note', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: DHIKR TASBIH COUNTER ──────────────────────────────────────────

  Widget _buildDhikrTab(BuildContext context) {
    final dhikrItems = _prayerService.dhikrItems;
    if (dhikrItems.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: () => _showAddDhikrDialog(context),
          icon: const Icon(LucideIcons.plus),
          label: const Text('Add your first Dhikr'),
        ),
      );
    }

    if (_selectedDhikrIndex >= dhikrItems.length) {
      _selectedDhikrIndex = 0;
    }
    final activeDhikr = dhikrItems[_selectedDhikrIndex];
    final progress = activeDhikr.targetCount > 0
        ? (activeDhikr.currentCount / activeDhikr.targetCount).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          // Horizontal selector chips for Dhikr
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dhikrItems.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                if (idx == dhikrItems.length) {
                  return ActionChip(
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.plus, size: 12, color: Color(0xFF34D399)),
                        SizedBox(width: 4),
                        Text('Add Dhikr', style: TextStyle(fontSize: 11, color: Color(0xFF34D399))),
                      ],
                    ),
                    onPressed: () => _showAddDhikrDialog(context),
                  );
                }

                final item = dhikrItems[idx];
                final isSelected = idx == _selectedDhikrIndex;
                return ChoiceChip(
                  label: Text(
                    item.transliteration,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF047857),
                  backgroundColor: const Color(0xFF18181B),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF34D399) : const Color(0xFF27272A),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedDhikrIndex = idx);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Arabic typography card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1815),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF163E33)),
            ),
            child: Column(
              children: [
                Text(
                  activeDhikr.arabic,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFDE68A),
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  activeDhikr.transliteration,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeDhikr.translation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA1A1AA),
                  ),
                ),
                if (activeDhikr.virtue.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '✨ ${activeDhikr.virtue}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6EE7B7)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Interactive Circular Digital Tasbih Button
          GestureDetector(
            onTap: () async {
              await _prayerService.incrementDhikr(activeDhikr.id);
              setState(() {});
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF022C22)],
                  stops: [0.6, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(color: const Color(0xFF34D399), width: 3),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 184,
                    height: 184,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: const Color(0xFF042F2E),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFDE68A)),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${activeDhikr.currentCount}',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'TARGET: ${activeDhikr.targetCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA7F3D0),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'TAP TO COUNT',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF6EE7B7),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Cycle and Reset controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.checkCircle2, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'Cycles Completed: ${activeDhikr.completedCycles}',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFA1A1AA),
                  side: const BorderSide(color: Color(0xFF3F3F46)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () async {
                  await _prayerService.resetDhikr(activeDhikr.id);
                  setState(() {});
                },
                icon: const Icon(LucideIcons.rotateCcw, size: 12),
                label: const Text('Reset', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB 3: PRAYER NOTES & REPOSITORY ─────────────────────────────────────

  Widget _buildPrayerNotesListTab(BuildContext context) {
    final allNotes = _prayerService.prayerNotes;
    final filtered = _notesSearchQuery.isEmpty
        ? allNotes
        : allNotes.where((p) {
            final q = _notesSearchQuery.toLowerCase();
            return p.title.toLowerCase().contains(q) ||
                p.translation.toLowerCase().contains(q) ||
                p.transliteration.toLowerCase().contains(q) ||
                p.note.toLowerCase().contains(q);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header search and add button
          Row(
            children: [
              Expanded(
                child: ShadInput(
                  placeholder: const Text('Search prayers or notes...'),
                  leading: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(LucideIcons.search, size: 16, color: Color(0xFFA1A1AA)),
                  ),
                  onChanged: (val) => setState(() => _notesSearchQuery = val),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onPressed: () => _showAddPrayerDialog(context),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No matching prayer notes found.',
                      style: TextStyle(color: Color(0xFF71717A)),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      final isCurrent = item.id == _currentPrayer.id;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFF0F2621) : const Color(0xFF18181B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent ? const Color(0xFF10B981) : const Color(0xFF27272A),
                            width: isCurrent ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent ? const Color(0xFF34D399) : Colors.white,
                                    ),
                                  ),
                                ),
                                if (item.isCustom)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Custom',
                                      style: TextStyle(fontSize: 10, color: Color(0xFF60A5FA)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.reference,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.translation,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFFD4D4D8)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (item.isCustom)
                                  IconButton(
                                    icon: const Icon(LucideIcons.trash2, size: 14, color: Color(0xFFEF4444)),
                                    tooltip: 'Delete',
                                    onPressed: () async {
                                      await _prayerService.deletePrayerNote(item.id);
                                      setState(() {});
                                    },
                                  ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF34D399),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _currentPrayer = item;
                                      _tabController.index = 0; // Go to prayer tab
                                    });
                                  },
                                  icon: const Icon(LucideIcons.bookOpen, size: 14),
                                  label: const Text('Recite / Read', style: TextStyle(fontSize: 11.5)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
