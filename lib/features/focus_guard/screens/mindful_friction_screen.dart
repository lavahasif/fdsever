import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/focus_guard_provider.dart';
import '../services/motivation_quote_service.dart';
import 'reality_check_screen.dart';
import '../../../core/services/app_navigator.dart';

/// Mindful 10-second friction delay screen that interrupts the dopamine
/// impulse loop with guided deep breathing before allowing any unlock attempt.
class MindfulFrictionScreen extends StatefulWidget {
  final String? blockedPackage;
  final String? blockReason;

  const MindfulFrictionScreen({
    super.key,
    this.blockedPackage,
    this.blockReason,
  });

  @override
  State<MindfulFrictionScreen> createState() => _MindfulFrictionScreenState();
}

class _MindfulFrictionScreenState extends State<MindfulFrictionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  Timer? _countdownTimer;
  int _secondsLeft = 10;
  bool _isBreathComplete = false;

  String _breathPhase = 'Breathe In...';
  String? _quoteText;
  String? _quoteAuthor;

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    _startBreathingCycle();
    _startCountdown();
    _loadQuote();
  }

  void _startBreathingCycle() {
    _breathController.repeat(reverse: true);
    _breathController.addListener(() {
      final val = _breathController.value;
      if (!mounted) return;
      if (_breathController.status == AnimationStatus.forward) {
        if (val < 0.8) {
          if (_breathPhase != 'Breathe In Slowly...') {
            setState(() => _breathPhase = 'Breathe In Slowly...');
          }
        } else {
          if (_breathPhase != 'Hold...') {
            setState(() => _breathPhase = 'Hold...');
          }
        }
      } else {
        if (val > 0.3) {
          if (_breathPhase != 'Breathe Out Gently...') {
            setState(() => _breathPhase = 'Breathe Out Gently...');
          }
        } else {
          if (_breathPhase != 'Reflect on Your Purpose') {
            setState(() => _breathPhase = 'Reflect on Your Purpose');
          }
        }
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _isBreathComplete = true;
          _breathPhase = 'Impulse Interrupted';
        });
      }
    });
  }

  Future<void> _loadQuote() async {
    final q = await MotivationQuoteService.getInspirationalQuote();
    if (mounted) {
      setState(() {
        _quoteText = q.text;
        _quoteAuthor = q.author;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  void _onResistDistraction(FocusGuardProvider provider) {
    provider.clearPendingIntervention();
    Navigator.of(context).pop();
  }

  void _onProceedToUnlock(FocusGuardProvider provider) {
    Navigator.of(context).pushReplacement(
      smoothTransitionRoute(
        RealityCheckScreen(
          blockedPackage: widget.blockedPackage,
          blockReason: widget.blockReason,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusGuardProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // Disallow hardware back until conscious decision
      child: Scaffold(
        backgroundColor: const Color(0xFF09090B),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Top Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.sparkles, color: Color(0xFF10B981), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'MINDFUL FRICTION DELAY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 1),

                // Breathing Sphere Animation
                AnimatedBuilder(
                  animation: _breathController,
                  builder: (context, child) {
                    final scale = _scaleAnimation.value;
                    final glow = _glowAnimation.value;

                    return Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Ripple
                          Transform.scale(
                            scale: scale * 1.35,
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF10B981).withValues(alpha: 0.08 * glow),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2 * glow),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          // Mid Glow Ring
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF10B981).withValues(alpha: 0.35 * glow),
                                    const Color(0xFF059669).withValues(alpha: 0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.4 * glow),
                                    blurRadius: 30 * scale,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Center Timer / Phase
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _secondsLeft > 0 ? '$_secondsLeft' : '✓',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _secondsLeft > 0 ? 'seconds' : 'calm',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFA1A1AA),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // Phase Title
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _breathPhase,
                    key: ValueKey<String>(_breathPhase),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Most mindless scrolling impulses fade within 10 seconds. Give your brain a moment to choose consciously.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFA1A1AA),
                    height: 1.4,
                  ),
                ),

                const Spacer(flex: 1),

                // Life Goal Reminder Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.target, size: 14, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text(
                            'YOUR COMMITTED GOAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        provider.targetGoal,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (_quoteText != null) ...[
                        const Divider(height: 20, color: Color(0xFF27272A)),
                        Text(
                          '"$_quoteText"',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFFD4D4D8),
                          ),
                        ),
                        if (_quoteAuthor != null)
                          Text(
                            '— $_quoteAuthor',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFA1A1AA),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action Buttons
                Column(
                  children: [
                    // Recommended Primary: Return to Focus
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ShadButton(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        onPressed: () => _onResistDistraction(provider),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.shieldCheck, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Return to Focus (Recommended)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Secondary: Continue to Unlock
                    if (_isBreathComplete)
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () => _onProceedToUnlock(provider),
                          child: const Text(
                            'I still want to unlock (Take Verification Challenge)',
                            style: TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Unlock challenge unlocked in $_secondsLeft seconds...',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF71717A),
                            fontStyle: FontStyle.italic,
                          ),
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
}
