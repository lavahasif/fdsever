enum MessageSource { client, server, system }

class SocketMessage {
  final String id;
  final String text;
  final MessageSource source;
  final DateTime timestamp;
  final List<String> extractedUrls;

  SocketMessage({
    required this.id,
    required this.text,
    required this.source,
    DateTime? timestamp,
    List<String>? extractedUrls,
  })  : timestamp = timestamp ?? DateTime.now(),
        extractedUrls = extractedUrls ?? _findUrls(text);

  static List<String> _findUrls(String text) {
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final matches = urlRegex.allMatches(text);
    return matches.map((m) => m.group(0)!).toList();
  }
}
