import '../../models/reading_progress.dart';
import '../local/hive_database.dart';

class ProgressLocalDataSource {
  Future<ReadingProgress?> getProgress(String bookId) async {
    return HiveDatabase.progressBox.get(bookId);
  }

  Future<void> saveProgress(ReadingProgress progress) async {
    await HiveDatabase.progressBox.put(progress.bookId, progress);
  }

  Future<void> deleteProgress(String bookId) async {
    await HiveDatabase.progressBox.delete(bookId);
  }
}
