import 'package:hive/hive.dart';

@HiveType(typeId: 6)
class ReadingProgress extends HiveObject {
  @HiveField(0)
  final String bookId;

  @HiveField(1)
  final String chapterId;

  @HiveField(2)
  final int paragraphIndex;

  @HiveField(3)
  final int wordIndex;

  @HiveField(4)
  final double positionSeconds;

  @HiveField(5)
  final double progress;

  @HiveField(6)
  final DateTime lastReadAt;

  ReadingProgress({
    required this.bookId,
    required this.chapterId,
    required this.paragraphIndex,
    required this.wordIndex,
    required this.positionSeconds,
    required this.progress,
    DateTime? lastReadAt,
  }) : lastReadAt = lastReadAt ?? DateTime.now();
}
