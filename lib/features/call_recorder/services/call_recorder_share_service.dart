import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../models/call_recording_item.dart';

class CallRecorderShareService {
  /// Shares a single call recording via the system share sheet
  static Future<bool> shareSingle(CallRecordingItem item) async {
    final file = File(item.path);
    if (!file.existsSync()) return false;

    try {
      final safeName = item.displayName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'audio/wav',
              name: '${safeName}_${item.name}',
            ),
          ],
          text: '📞 Call: ${item.displayName} (${item.directionLabel})\n'
              '📱 ${item.phoneNumber}\n'
              '📅 ${item.formattedDate} · ⏱️ ${item.formattedDuration}',
          subject: 'Call Recording - ${item.displayName}',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shares a single call recording tailored for WhatsApp
  static Future<bool> shareSingleToWhatsApp(CallRecordingItem item) async {
    final file = File(item.path);
    if (!file.existsSync()) return false;

    try {
      final summary = StringBuffer()
        ..writeln('📞 *Call Recording: ${item.displayName}*')
        ..writeln('📱 Number: ${item.phoneNumber.isNotEmpty ? item.phoneNumber : "Unknown"}')
        ..writeln('↔️ Type: ${item.directionLabel.isNotEmpty ? item.directionLabel : "Voice Call"}')
        ..writeln('📅 Date: ${item.formattedDate}')
        ..writeln('⏱️ Duration: ${item.formattedDuration}')
        ..writeln('💾 Size: ${item.formattedSize}');

      if (item.notes.isNotEmpty) {
        summary.writeln('\n📝 *Notes:* ${item.notes}');
      }

      final safeName = item.displayName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'audio/wav',
              name: '${safeName}_${item.name}',
            ),
          ],
          text: summary.toString(),
          subject: 'Call Recording - ${item.displayName}',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shares multiple call recordings in bulk
  static Future<bool> shareBulk(List<CallRecordingItem> items) async {
    final existing = items.where((i) => File(i.path).existsSync()).toList();
    if (existing.isEmpty) return false;

    try {
      final xFiles = existing.map((i) {
        final safeName = i.displayName.replaceAll(RegExp(r'[^\w\s-]'), '_');
        return XFile(
          i.path,
          mimeType: 'audio/wav',
          name: '${safeName}_${i.name}',
        );
      }).toList();

      final summary = StringBuffer()
        ..writeln('📞 *Shared Call Recordings (${existing.length} files)*');
      for (final i in existing) {
        summary.writeln('• ${i.displayName} (${i.phoneNumber}) - ${i.formattedDuration}');
      }

      await SharePlus.instance.share(
        ShareParams(
          files: xFiles,
          text: summary.toString(),
          subject: 'Call Recordings (${existing.length} items)',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shares multiple call recordings in bulk tailored for WhatsApp
  static Future<bool> shareBulkToWhatsApp(List<CallRecordingItem> items) async {
    return shareBulk(items);
  }
}
