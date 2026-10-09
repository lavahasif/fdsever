import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MiniPlayerBar extends StatelessWidget {
  final String title;
  final bool isPlaying;
  final int currentPositionMs;
  final int durationMs;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<int> onSeek;
  final VoidCallback? onShare;
  final VoidCallback? onWhatsAppShare;

  const MiniPlayerBar({
    super.key,
    required this.title,
    required this.isPlaying,
    required this.currentPositionMs,
    required this.durationMs,
    required this.onPlayPause,
    required this.onStop,
    required this.onSeek,
    this.onShare,
    this.onWhatsAppShare,
  });

  @override
  Widget build(BuildContext context) {
    final curSec = currentPositionMs ~/ 1000;
    final durSec = durationMs > 0 ? durationMs ~/ 1000 : 1;
    final clampedCur = curSec.clamp(0, durSec);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Zinc 900 Shadcn surface
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFF27272A), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track Info & Controls Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                      : const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPlaying ? const Color(0xFF38BDF8) : Colors.transparent,
                  ),
                ),
                child: Icon(
                  LucideIcons.audioWaveform,
                  color: isPlaying ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : 'Playing Audio',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatSec(clampedCur)} / ${_formatSec(durSec)}',
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Skip -10s
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Rewind 10s',
                icon: const Icon(LucideIcons.rotateCcw, color: Color(0xFFA1A1AA), size: 17),
                onPressed: () {
                  final target = (currentPositionMs - 10000).clamp(0, durationMs);
                  onSeek(target);
                },
              ),

              // Play / Pause round button
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isPlaying ? LucideIcons.pause : LucideIcons.play,
                    color: Colors.white,
                    size: 17,
                  ),
                  onPressed: onPlayPause,
                ),
              ),

              // Skip +10s
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Fast Forward 10s',
                icon: const Icon(LucideIcons.rotateCw, color: Color(0xFFA1A1AA), size: 17),
                onPressed: () {
                  final target = (currentPositionMs + 10000).clamp(0, durationMs);
                  onSeek(target);
                },
              ),

              // Stop
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Stop Playback',
                icon: const Icon(LucideIcons.square, color: Color(0xFFEF4444), size: 16),
                onPressed: onStop,
              ),

              // Share button
              if (onShare != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Share File',
                  icon: const Icon(LucideIcons.share2, color: Color(0xFF38BDF8), size: 16),
                  onPressed: onShare,
                ),

              // WhatsApp share button
              if (onWhatsAppShare != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Share on WhatsApp',
                  icon: const Icon(LucideIcons.messageCircle, color: Color(0xFF22C55E), size: 17),
                  onPressed: onWhatsAppShare,
                ),
            ],
          ),

          const SizedBox(height: 4),

          // Scrubber Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: const Color(0xFF38BDF8),
              inactiveTrackColor: const Color(0xFF27272A),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: clampedCur.toDouble(),
              max: durSec.toDouble(),
              onChanged: (val) {
                onSeek((val * 1000).toInt());
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatSec(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
