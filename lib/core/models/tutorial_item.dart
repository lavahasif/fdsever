import 'dart:convert';

class TutorialItem {
  final String id;
  final String title;
  final String category;
  final String description;
  final String link;
  final DateTime createdAt;

  TutorialItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.link,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'link': link,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TutorialItem.fromMap(Map<String, dynamic> map) {
    return TutorialItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
      description: map['description']?.toString() ?? '',
      link: map['link']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory TutorialItem.fromJson(String source) =>
      TutorialItem.fromMap(json.decode(source) as Map<String, dynamic>);

  TutorialItem copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    String? link,
    DateTime? createdAt,
  }) {
    return TutorialItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      link: link ?? this.link,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
