import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meeting_recording.dart';

class GeminiVoiceResult {
  final List<String> tags;
  final List<String> keyPoints;
  final String summary;

  const GeminiVoiceResult({
    required this.tags,
    required this.keyPoints,
    required this.summary,
  });

  String get formattedTags {
    return tags.map((t) {
      final clean = t.trim();
      return clean.startsWith('#') ? clean : '#$clean';
    }).join(', ');
  }

  String get formattedNotes {
    final buffer = StringBuffer();
    if (summary.trim().isNotEmpty) {
      buffer.writeln(summary.trim());
      if (keyPoints.isNotEmpty) buffer.writeln();
    }
    for (final point in keyPoints) {
      if (point.trim().isNotEmpty) {
        buffer.writeln('• ${point.trim()}');
      }
    }
    return buffer.toString().trim();
  }
}

class GeminiVoiceService {
  static const String _keyApiKey = 'gemini_api_key';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey)?.trim();
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, key.trim());
  }

  static Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Extracts topic tags and key takeaways directly from meeting audio using Gemini API.
  static Future<GeminiVoiceResult> extractVoiceInfo({
    required String filePath,
    String? apiKeyOverride,
  }) async {
    final key = apiKeyOverride?.trim().isNotEmpty == true
        ? apiKeyOverride!.trim()
        : await getApiKey();

    if (key == null || key.isEmpty) {
      throw Exception('Gemini API key is required. Please configure your API key first.');
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Audio file not found on disk at: $filePath');
    }

    final fileLength = await file.length();
    // Gemini inline data limit is ~20 MB
    if (fileLength > 20 * 1024 * 1024) {
      throw Exception('Audio file is ${fileLength ~/ (1024 * 1024)}MB. Inline Gemini analysis supports audio files up to 20MB.');
    }

    final bytes = await file.readAsBytes();
    final base64Audio = base64Encode(bytes);

    String mimeType = 'audio/mp4';
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.wav')) {
      mimeType = 'audio/wav';
    } else if (lower.endsWith('.aac')) {
      mimeType = 'audio/aac';
    } else if (lower.endsWith('.mp3')) {
      mimeType = 'audio/mp3';
    }

    // Try gemini-2.0-flash, fallback to gemini-1.5-flash
    final models = ['gemini-2.0-flash', 'gemini-1.5-flash'];
    Exception? lastError;

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
        );

        final payload = {
          'contents': [
            {
              'parts': [
                {
                  'inlineData': {
                    'mimeType': mimeType,
                    'data': base64Audio,
                  }
                },
                {
                  'text': 'You are an AI meeting intelligence assistant. Listen to this voice recording and extract: '
                      '1) "tags": 3 to 6 concise topic keywords or category tags (e.g. "Roadmap", "Sprint Planning", "Budget", "Action Items"). '
                      '2) "keyPoints": 2 to 4 concise bullet points summarizing key decisions or action items. '
                      '3) "summary": A 1-sentence executive summary. '
                      'Respond ONLY with a valid JSON object matching this schema: '
                      '{"tags": ["Tag1", "Tag2"], "keyPoints": ["Action 1", "Decision 2"], "summary": "Brief summary"}. '
                      'Do NOT use Markdown code blocks or rich text.'
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
          }
        };

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final resJson = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = resJson['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) {
            throw Exception('Gemini returned no response candidates.');
          }

          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts == null || parts.isEmpty) {
            throw Exception('Gemini response contains no content parts.');
          }

          String textResponse = parts.first['text']?.toString() ?? '';
          textResponse = textResponse.trim();
          if (textResponse.startsWith('```json')) {
            textResponse = textResponse.substring(7);
          } else if (textResponse.startsWith('```')) {
            textResponse = textResponse.substring(3);
          }
          if (textResponse.endsWith('```')) {
            textResponse = textResponse.substring(0, textResponse.length - 3);
          }
          textResponse = textResponse.trim();

          final parsed = jsonDecode(textResponse) as Map<String, dynamic>;
          final rawTags = (parsed['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          final rawPoints = (parsed['keyPoints'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          final rawSummary = parsed['summary']?.toString() ?? '';

          return GeminiVoiceResult(
            tags: rawTags,
            keyPoints: rawPoints,
            summary: rawSummary,
          );
        } else {
          final errorBody = response.body;
          lastError = Exception('Gemini API error (${response.statusCode}): $errorBody');
        }
      } catch (e) {
        lastError = Exception('Failed with $model: $e');
      }
    }

    throw lastError ?? Exception('Failed to extract voice information from Gemini.');
  }

  /// Direct Share to Gemini Chat: dispatches audio to Google Gemini app via system share sheet.
  static Future<void> shareToGeminiChat(MeetingRecording recording) async {
    final safeTitle = recording.title.replaceAll(RegExp(r'[^\w\s-]'), '_');
    final file = XFile(
      recording.filePath,
      mimeType: 'audio/mp4',
      name: '$safeTitle.m4a',
    );

    final prompt = 'Listen to this meeting recording ("${recording.title}") and extract: '
        '1. Topic Tags\n'
        '2. Key Decisions & Action Items\n'
        '3. Summary';

    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        text: prompt,
        subject: 'Meeting Voice: ${recording.title}',
      ),
    );
  }

  /// Launch Google Gemini web portal in browser
  static Future<void> openGeminiWeb() async {
    final uri = Uri.parse('https://gemini.google.com/app');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Launch Google AI Studio API Key portal
  static Future<void> openApiKeyPortal() async {
    final uri = Uri.parse('https://aistudio.google.com/app/apikey');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
