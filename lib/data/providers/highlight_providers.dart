import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/highlight.dart';
import '../../data/models/bookmark.dart';
import '../../data/models/reading_progress.dart';
import '../datasources/local/highlights_local_ds.dart';
import '../datasources/local/bookmarks_local_ds.dart';
import '../datasources/local/progress_local_ds.dart';

final highlightDataSourceProvider = Provider<HighlightLocalDataSource>((ref) {
  return HighlightLocalDataSource();
});

final bookmarkDataSourceProvider = Provider<BookmarkLocalDataSource>((ref) {
  return BookmarkLocalDataSource();
});

final progressDataSourceProvider = Provider<ProgressLocalDataSource>((ref) {
  return ProgressLocalDataSource();
});

// Highlights for a specific book
final highlightsProvider = FutureProvider.family<List<Highlight>, String>((ref, bookId) {
  final ds = ref.watch(highlightDataSourceProvider);
  return ds.getHighlights(bookId);
});

// All highlights (for notebook)
final allHighlightsProvider = FutureProvider<List<Highlight>>((ref) {
  final ds = ref.watch(highlightDataSourceProvider);
  return ds.getAllHighlights();
});

// Bookmarks for a specific book
final bookmarksProvider = FutureProvider.family<List<Bookmark>, String>((ref, bookId) {
  final ds = ref.watch(bookmarkDataSourceProvider);
  return ds.getBookmarks(bookId);
});

// All bookmarks (for notebook)
final allBookmarksProvider = FutureProvider<List<Bookmark>>((ref) {
  final ds = ref.watch(bookmarkDataSourceProvider);
  return ds.getAllBookmarks();
});

// Reading progress for a book
final readingProgressProvider = FutureProvider.family<ReadingProgress?, String>((ref, bookId) {
  final ds = ref.watch(progressDataSourceProvider);
  return ds.getProgress(bookId);
});

// Provider to save a highlight (triggers refresh)
final saveHighlightProvider = Provider<void Function(Highlight)>((ref) {
  return (Highlight highlight) async {
    final ds = ref.read(highlightDataSourceProvider);
    await ds.saveHighlight(highlight);
    ref.invalidate(highlightsProvider(highlight.bookId));
    ref.invalidate(allHighlightsProvider);
  };
});

// Provider to save a bookmark
final saveBookmarkProvider = Provider<void Function(Bookmark)>((ref) {
  return (Bookmark bookmark) async {
    final ds = ref.read(bookmarkDataSourceProvider);
    await ds.saveBookmark(bookmark);
    ref.invalidate(bookmarksProvider(bookmark.bookId));
    ref.invalidate(allBookmarksProvider);
  };
});

// Provider to save reading progress
final saveProgressProvider = Provider<void Function(ReadingProgress)>((ref) {
  return (ReadingProgress progress) async {
    final ds = ref.read(progressDataSourceProvider);
    await ds.saveProgress(progress);
    ref.invalidate(readingProgressProvider(progress.bookId));
  };
});
