import '../../models/highlight.dart';
import '../local/hive_database.dart';

class HighlightLocalDataSource {
  Future<List<Highlight>> getHighlights(String bookId) async {
    final box = HiveDatabase.highlightsBox;
    return box.values.where((h) => h.bookId == bookId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Highlight>> getAllHighlights() async {
    final box = HiveDatabase.highlightsBox;
    final list = box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveHighlight(Highlight highlight) async {
    await HiveDatabase.highlightsBox.put(highlight.id, highlight);
  }

  Future<void> deleteHighlight(String id) async {
    await HiveDatabase.highlightsBox.delete(id);
  }
}
