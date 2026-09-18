import 'dart:convert';

class NoteItem {
  final String id;
  final String title;
  final String note;
  final String link;
  final DateTime createdAt;

  NoteItem({
    required this.id,
    required this.title,
    required this.note,
    required this.link,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'link': link,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NoteItem.fromMap(Map<String, dynamic> map) {
    return NoteItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      link: map['link']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory NoteItem.fromJson(String source) =>
      NoteItem.fromMap(json.decode(source) as Map<String, dynamic>);

  NoteItem copyWith({
    String? id,
    String? title,
    String? note,
    String? link,
    DateTime? createdAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      link: link ?? this.link,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
