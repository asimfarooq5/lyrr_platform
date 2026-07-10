import 'chapter.dart';
import 'metadata.dart';

class Book {
  final BookMetadata metadata;
  final List<Chapter> chapters;

  Book({
    required this.metadata,
    required this.chapters,
  });
}
