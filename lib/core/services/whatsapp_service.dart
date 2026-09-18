import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  /// Strip non-numeric characters and clean formatting
  String cleanNumber(String input, {String defaultPrefix = '91'}) {
    var cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    // If number looks like a 10-digit number and prefix is provided, prepend prefix
    if (cleaned.length == 10 && !cleaned.startsWith(defaultPrefix)) {
      cleaned = '$defaultPrefix$cleaned';
    }
    return cleaned;
  }

  /// Build standard web URL (wa.me)
  String buildWebUrl(String number, String message) {
    final cleaned = cleanNumber(number);
    final encodedMsg = Uri.encodeComponent(message);
    return 'https://wa.me/$cleaned?text=$encodedMsg';
  }

  /// Build native app scheme URL
  String buildNativeScheme(String number, String message) {
    final cleaned = cleanNumber(number);
    final encodedMsg = Uri.encodeComponent(message);
    return 'whatsapp://send?phone=$cleaned&text=$encodedMsg';
  }

  /// Launch WhatsApp chat
  Future<bool> openChat({
    required String number,
    required String message,
    bool tryNativeApp = true,
  }) async {
    final cleaned = cleanNumber(number);
    if (cleaned.isEmpty) return false;

    if (tryNativeApp) {
      final nativeUri = Uri.parse(buildNativeScheme(cleaned, message));
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    }

    // Fallback to web link
    final webUri = Uri.parse(buildWebUrl(cleaned, message));
    return await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
