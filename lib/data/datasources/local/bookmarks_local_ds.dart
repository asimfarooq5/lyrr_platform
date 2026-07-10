import '../../models/bookmark.dart';
import '../local/hive_database.dart';

class BookmarkLocalDataSource {
  Future<List<Bookmark>> getBookmarks(String bookId) async {
    final box = HiveDatabase.bookmarksBox;
    return box.values.where((b) => b.bookId == bookId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Bookmark>> getAllBookmarks() async {
    final box = HiveDatabase.bookmarksBox;
    final list = box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveBookmark(Bookmark bookmark) async {
    await HiveDatabase.bookmarksBox.put(bookmark.id, bookmark);
  }

  Future<void> deleteBookmark(String id) async {
    await HiveDatabase.bookmarksBox.delete(id);
  }
}
