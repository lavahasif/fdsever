import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MotivationQuote {
  final String text;
  final String author;
  final String? source;

  const MotivationQuote({
    required this.text,
    required this.author,
    this.source,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'author': author,
    'source': source,
  };

  factory MotivationQuote.fromJson(Map<String, dynamic> json) => MotivationQuote(
    text: json['text'] as String? ?? 'Your future is created by what you do today, not what you scroll.',
    author: json['author'] as String? ?? 'Discipline Anchor',
    source: json['source'] as String?,
  );

  static const List<MotivationQuote> fallbackQuotes = [
    MotivationQuote(
      text: 'The dopamine you crave from scrolling is stealing the legacy you could build.',
      author: 'Deep Focus Imperative',
    ),
    MotivationQuote(
      text: 'Discipline is choosing between what you want now and what you want most.',
      author: 'Abraham Lincoln',
    ),
    MotivationQuote(
      text: 'Deep work is the superpower of the 21st century. Master it and you become irreplaceable.',
      author: 'Cal Newport',
    ),
    MotivationQuote(
      text: 'You have power over your mind - not outside events. Realize this, and you will find strength.',
      author: 'Marcus Aurelius',
    ),
    MotivationQuote(
      text: 'Someone who is disciplined will always outperform someone who is motivated.',
      author: 'Jocko Willink',
    ),
    MotivationQuote(
      text: 'Every minute spent on reels is a minute given away to someone else’s algorithm.',
      author: 'Focus Anchor',
    ),
    MotivationQuote(
      text: 'Small disciplines repeated with consistency every day lead to great achievements.',
      author: 'John C. Maxwell',
    ),
  ];
}

class MotivationQuoteService {
  static const String _keyCachedQuote = 'focus_guard_quote_text';
  static const String _keyCachedAuthor = 'focus_guard_quote_author';
  static const String _keyCachedTime = 'focus_guard_quote_time';

  static MotivationQuote? _inMemoryQuote;

  /// Fetches an inspiring quote from free public APIs with offline fallback & caching
  static Future<MotivationQuote> getInspirationalQuote({bool forceRefresh = false}) async {
    if (!forceRefresh && _inMemoryQuote != null) {
      return _inMemoryQuote!;
    }

    final prefs = await SharedPreferences.getInstance();

    // Check recent cached quote (valid for 30 minutes unless forced)
    final cachedTime = prefs.getInt(_keyCachedTime) ?? 0;
    final cachedText = prefs.getString(_keyCachedQuote);
    final cachedAuthor = prefs.getString(_keyCachedAuthor);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!forceRefresh && cachedText != null && cachedAuthor != null && (now - cachedTime < 30 * 60 * 1000)) {
      _inMemoryQuote = MotivationQuote(text: cachedText, author: cachedAuthor, source: 'cache');
      return _inMemoryQuote!;
    }

    // Attempt 1: ZenQuotes API (Free, fast public endpoint)
    try {
      final response = await http
          .get(Uri.parse('https://zenquotes.io/api/random'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          final item = decoded.first as Map<String, dynamic>;
          final text = (item['q'] as String?)?.trim() ?? '';
          final author = (item['a'] as String?)?.trim() ?? 'Unknown';
          if (text.isNotEmpty) {
            final quote = MotivationQuote(text: text, author: author, source: 'zenquotes');
            await _cacheQuote(prefs, quote);
            _inMemoryQuote = quote;
            return quote;
          }
        }
      }
    } catch (e) {
      debugPrint('ZenQuotes fetch error, trying secondary source: $e');
    }

    // Attempt 2: DummyJSON Quotes API (Free, highly available secondary endpoint)
    try {
      final response = await http
          .get(Uri.parse('https://dummyjson.com/quotes/random'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (decoded['quote'] as String?)?.trim() ?? '';
        final author = (decoded['author'] as String?)?.trim() ?? 'Unknown';
        if (text.isNotEmpty) {
          final quote = MotivationQuote(text: text, author: author, source: 'dummyjson');
          await _cacheQuote(prefs, quote);
          _inMemoryQuote = quote;
          return quote;
        }
      }
    } catch (e) {
      debugPrint('Secondary quotes API fetch error: $e');
    }

    // Offline Fallback: Select from curated local motivational words
    if (cachedText != null && cachedAuthor != null) {
      _inMemoryQuote = MotivationQuote(text: cachedText, author: cachedAuthor, source: 'offline_cache');
      return _inMemoryQuote!;
    }

    final rand = Random();
    final fallback = MotivationQuote.fallbackQuotes[rand.nextInt(MotivationQuote.fallbackQuotes.length)];
    _inMemoryQuote = fallback;
    return fallback;
  }

  static Future<void> _cacheQuote(SharedPreferences prefs, MotivationQuote quote) async {
    await prefs.setString(_keyCachedQuote, quote.text);
    await prefs.setString(_keyCachedAuthor, quote.author);
    await prefs.setInt(_keyCachedTime, DateTime.now().millisecondsSinceEpoch);
  }
}
