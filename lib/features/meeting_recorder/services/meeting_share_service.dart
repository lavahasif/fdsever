import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../models/meeting_recording.dart';

class MeetingShareService {
  /// Shares a single meeting audio file via the system share sheet
  static Future<bool> shareSingle(MeetingRecording recording) async {
    final file = File(recording.filePath);
    if (!file.existsSync()) return false;

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'audio/mp4',
              name: '${recording.title.replaceAll(RegExp(r'[^\w\s-]'), '_')}.m4a',
            ),
          ],
          text: '🎙️ Meeting: ${recording.title}\n📅 ${recording.formattedDate} · ⏱️ ${recording.formattedDuration}',
          subject: recording.title,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shares a single meeting recording tailored for WhatsApp
  static Future<bool> shareSingleToWhatsApp(MeetingRecording recording) async {
    final file = File(recording.filePath);
    if (!file.existsSync()) return false;

    try {
      final summary = StringBuffer()
        ..writeln('🎙️ *${recording.title}*')
        ..writeln('📅 Date: ${recording.formattedDate}')
        ..writeln('⏱️ Duration: ${recording.formattedDuration}')
        ..writeln('💾 Size: ${recording.formattedSize}');
      if (recording.tags.isNotEmpty) {
        summary.writeln('🏷️ Tags: ${recording.tags}');
      }
      if (recording.notes.isNotEmpty) {
        summary.writeln('\n📝 *Notes:*');
        summary.writeln(recording.notes);
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'audio/mp4',
              name: '${recording.title.replaceAll(RegExp(r'[^\w\s-]'), '_')}.m4a',
            ),
          ],
          text: summary.toString(),
          subject: recording.title,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shares multiple meeting audio files in bulk
  static Future<bool> shareBulk(List<MeetingRecording> recordings) async {
    final existing = recordings.where((r) => File(r.filePath).existsSync()).toList();
    if (existing.isEmpty) return false;

    try {
      final xFiles = existing.map((r) {
        return XFile(
          r.filePath,
          mimeType: 'audio/mp4',
          name: '${r.title.replaceAll(RegExp(r'[^\w\s-]'), '_')}.m4a',
        );
      }).toList();

      final summary = StringBuffer()
        ..writeln('🎙️ *Shared Meeting Recordings (${existing.length} items)*');
      for (final r in existing) {
        summary.writeln('• ${r.title} (${r.formattedDuration})');
      }

      await SharePlus.instance.share(
        ShareParams(
          files: xFiles,
          text: summary.toString(),
          subject: 'Meeting Recordings (${existing.length} items)',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shares multiple meeting audio files in bulk tailored for WhatsApp
  static Future<bool> shareBulkToWhatsApp(List<MeetingRecording> recordings) async {
    return shareBulk(recordings);
  }
}
