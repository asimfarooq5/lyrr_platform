import 'paragraph.dart';

class Chapter {
  final String title;
  final List<Paragraph> paragraphs;

  Chapter({
    required this.title,
    required this.paragraphs,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    final paragraphsList = json['paragraphs'] as List;
    final paragraphs = paragraphsList.map((p) => Paragraph.fromJson(p as Map<String, dynamic>)).toList();
    return Chapter(
      title: json['title'] as String,
      paragraphs: paragraphs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'paragraphs': paragraphs.map((p) => p.toJson()).toList(),
    };
  }
}
