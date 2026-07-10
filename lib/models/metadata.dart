class BookMetadata {
  final int id;
  final String title;
  final String author;
  final int duration; // in seconds
  final String language;
  final String cover;

  BookMetadata({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.language,
    required this.cover,
  });

  factory BookMetadata.fromJson(Map<String, dynamic> json) {
    return BookMetadata(
      id: json['id'] as int,
      title: json['title'] as String,
      author: json['author'] as String,
      duration: json['duration'] as int,
      language: json['language'] as String,
      cover: json['cover'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'duration': duration,
      'language': language,
      'cover': cover,
    };
  }
}
