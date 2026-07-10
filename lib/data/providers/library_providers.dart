import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/metadata.dart';
import '../../features/download/services/download_manager.dart';

// Download manager provider
final downloadManagerProvider = Provider<DownloadManager>((ref) => DownloadManager());

// Book catalog (from CDN)
final bookCatalogProvider = FutureProvider<List<BookMetadata>>((ref) async {
  // For now return the sample book metadata
  final metadata = BookMetadata(
    id: 1,
    title: 'Sample Book',
    author: 'John Doe',
    duration: 624,
    language: 'English',
    cover: 'cover.jpg',
  );
  return [metadata];
});

// Downloaded book IDs
final downloadedBookIdsProvider = Provider<List<String>>((ref) {
  final manager = ref.watch(downloadManagerProvider);
  return manager.getDownloadedBookIds();
});

// Download progress for a specific book
final downloadProgressProvider = Provider.family<double, String>((ref, bookId) {
  final manager = ref.watch(downloadManagerProvider);
  return manager.getDownloadProgress(bookId);
});

// Is book downloaded
final isBookDownloadedProvider = Provider.family<bool, String>((ref, bookId) {
  final downloadedIds = ref.watch(downloadedBookIdsProvider);
  return downloadedIds.contains(bookId);
});

// Combined library items (metadata + download status)
final libraryItemsProvider = FutureProvider<List<BookMetadata>>((ref) {
  return ref.watch(bookCatalogProvider.future);
});
