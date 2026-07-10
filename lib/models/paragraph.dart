import 'word.dart';

class Paragraph {
  final List<Word> words;

  Paragraph({required this.words});

  factory Paragraph.fromJson(Map<String, dynamic> json) {
    final wordsList = json['words'] as List;
    final words = wordsList.map((w) => Word.fromJson(w as Map<String, dynamic>)).toList();
    return Paragraph(words: words);
  }

  Map<String, dynamic> toJson() {
    return {
      'words': words.map((w) => w.toJson()).toList(),
    };
  }
}
