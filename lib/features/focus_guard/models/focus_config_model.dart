class BlockedAppInfo {
  final String packageName;
  final String appName;
  final bool isBlocked;
  final bool isShortsOnly;

  const BlockedAppInfo({
    required this.packageName,
    required this.appName,
    this.isBlocked = true,
    this.isShortsOnly = false,
  });

  BlockedAppInfo copyWith({
    String? packageName,
    String? appName,
    bool? isBlocked,
    bool? isShortsOnly,
  }) {
    return BlockedAppInfo(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      isBlocked: isBlocked ?? this.isBlocked,
      isShortsOnly: isShortsOnly ?? this.isShortsOnly,
    );
  }

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'isBlocked': isBlocked,
        'isShortsOnly': isShortsOnly,
      };

  factory BlockedAppInfo.fromJson(Map<String, dynamic> json) => BlockedAppInfo(
        packageName: json['packageName'] as String,
        appName: json['appName'] as String,
        isBlocked: json['isBlocked'] as bool? ?? true,
        isShortsOnly: json['isShortsOnly'] as bool? ?? false,
      );
}

class RealityQuote {
  final String quote;
  final String author;
  final String category;

  const RealityQuote({
    required this.quote,
    required this.author,
    this.category = 'Discipline',
  });

  static const List<RealityQuote> curatedQuotes = [
    RealityQuote(
      quote: "You have spent hours scrolling today. Your competitors are learning, coding, and building.",
      author: "Reality Check",
      category: "Truth",
    ),
    RealityQuote(
      quote: "Do not trade what you want most for what you want now.",
      author: "Abraham Lincoln",
      category: "Focus",
    ),
    RealityQuote(
      quote: "Every swipe is engineered by silicon valley billionaires to harvest your attention and sell ads.",
      author: "Dopamine Trap",
      category: "Awareness",
    ),
    RealityQuote(
      quote: "The pain of discipline weighs ounces; the pain of regret weighs tons.",
      author: "Jim Rohn",
      category: "Discipline",
    ),
    RealityQuote(
      quote: "If you don't build your dream, someone will hire you to build theirs.",
      author: "Dhirubhai Ambani",
      category: "Ambition",
    ),
    RealityQuote(
      quote: "Ten years from now, you will wish you had started today.",
      author: "Reality Check",
      category: "Urgency",
    ),
  ];
}
