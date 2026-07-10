import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

@HiveType(typeId: 4)
class Bookmark extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final String chapterId;

  @HiveField(3)
  final int paragraphIndex;

  @HiveField(4)
  final int wordIndex;

  @HiveField(5)
  final String? previewText;

  @HiveField(6)
  final DateTime createdAt;

  Bookmark({
    String? id,
    required this.bookId,
    required this.chapterId,
    required this.paragraphIndex,
    required this.wordIndex,
    this.previewText,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}
