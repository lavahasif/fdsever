import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class MotivationReaderScreen extends StatefulWidget {
  final String? reason;
  final String? blockedPackage;

  const MotivationReaderScreen({
    super.key,
    this.reason,
    this.blockedPackage,
  });

  @override
  State<MotivationReaderScreen> createState() => _MotivationReaderScreenState();
}

class _MotivationReaderScreenState extends State<MotivationReaderScreen> {
  String? _selectedLocalPdfName;
  String? _selectedLocalPdfPath;

  Future<void> _pickAndOpenExternalPdf() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt', 'doc'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final path = files.first.path!;
        setState(() {
          _selectedLocalPdfName = files.first.name;
          _selectedLocalPdfPath = path;
        });

        // Launch in native PDF viewer
        final uri = Uri.file(path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selected: ${files.first.name}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

  Future<void> _launchMotivationalVideo() async {
    const videoUrl = 'https://www.youtube.com/watch?v=kYfNvmF0Bqw';
    final uri = Uri.parse(videoUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5),
      appBar: AppBar(
        title: const Text('Mindset & Motivation Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.fileText),
            tooltip: 'Open Local PDF / Book',
            onPressed: _pickAndOpenExternalPdf,
          ),
          IconButton(
            icon: const Icon(LucideIcons.video, color: Color(0xFFEF4444)),
            tooltip: 'Watch Motivation Video',
            onPressed: _launchMotivationalVideo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Diversion Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E1B4B),
                    Color(0xFF311042),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.compass, color: Color(0xFFA5B4FC), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'AUTOMATIC DIVERSION ENGAGED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA5B4FC),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.reason == 'hourly_quota_exceeded'
                      ? 'You hit your hourly allowance on distracting apps. Your brain was seeking a dopamine hit — feed it knowledge instead.'
                      : 'You attempted to open short-form doom feeds. Redirecting your energy to high-agency execution.',
                    style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(LucideIcons.filePlus, size: 14),
                        label: const Text('Pick My PDF', style: TextStyle(fontSize: 12)),
                        onPressed: _pickAndOpenExternalPdf,
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF818CF8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(LucideIcons.playCircle, size: 14, color: Color(0xFFF87171)),
                        label: const Text('Watch Video', style: TextStyle(fontSize: 12)),
                        onPressed: _launchMotivationalVideo,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_selectedLocalPdfName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.fileCheck, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Active Document: $_selectedLocalPdfName',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_selectedLocalPdfPath != null) {
                          launchUrl(Uri.file(_selectedLocalPdfPath!));
                        }
                      },
                      child: const Text('Re-open', style: TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // In-App Motivational Blueprint Document
            const Text(
              'THE DEEP WORK & DOPAMINE DETOX BLUEPRINT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A practical protocol for reclaiming your mind and executing at the highest level.',
              style: TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)),
            ),

            const SizedBox(height: 16),

            _buildChapterCard(
              isDark: isDark,
              number: '01',
              title: 'The 1-Hour Quota Rule',
              subtitle: 'Why 5 to 10 Minutes is All You Need',
              content:
                  'Every time you check social media or YouTube, you believe you are "taking a quick 2-minute break." In reality, algorithmic feeds are designed with variable reward schedules identical to slot machines.\n\nBy capping your hourly usage to 5 or 10 minutes, you force your brain to check what is strictly necessary (a message or important update) and disengage before the dopamine trap locks in.',
            ),

            const SizedBox(height: 14),

            _buildChapterCard(
              isDark: isDark,
              number: '02',
              title: 'Attention Fragmentation & Cost',
              subtitle: 'Context Switching Destroys Cognitive IQ',
              content:
                  'Research from UC Irvine shows that after being distracted by a 30-second reel, it takes an average of 23 minutes and 15 seconds to return to the same depth of focus.\n\nWhen you scroll 10 times a day, your brain never enters "deep flow state." You feel exhausted at night not because you did hard work, but because your attention was fragmented into thousands of pieces.',
            ),

            const SizedBox(height: 14),

            _buildChapterCard(
              isDark: isDark,
              number: '03',
              title: 'The Replacement Principle',
              subtitle: 'Never Just Stop — Always Substitute',
              content:
                  'You cannot eliminate a craving with willpower alone. You must redirect the impulse to a higher-order reward:\n\n• Physical: Do 20 pushups or take a brisk 5-minute walk.\n• Intellectual: Read 2 pages of a technical book or programming docs.\n• Production: Open your code editor and write one clean function.',
            ),

            const SizedBox(height: 14),

            _buildChapterCard(
              isDark: isDark,
              number: '04',
              title: 'The 5-Second Rule for Execution',
              subtitle: 'Move Before Your Brain Rationalizes Laziness',
              content:
                  'The second you feel the urge to procrastinate, count backwards: 5 - 4 - 3 - 2 - 1 — and physically launch your work environment. Do not negotiate with comfort. Momentum creates motivation, not the other way around.',
            ),

            const SizedBox(height: 28),

            // Back to Work button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
                label: const Text(
                  'READY TO EXECUTE. BACK TO WORK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterCard({
    required bool isDark,
    required String number,
    required String title,
    required String subtitle,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFA1A1AA)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFF27272A)),
          Text(
            content,
            style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFD4D4D8)),
          ),
        ],
      ),
    );
  }
}
