import '../models/book.dart';
import '../models/sync_word.dart';
import '../utils/constants.dart';
import 'asset_loader.dart';

class BookRepository {
  final AssetLoader _assetLoader;

  BookRepository({AssetLoader? assetLoader})
      : _assetLoader = assetLoader ?? AssetLoader();

  Future<Book> loadBook() async {
    final metadata = await _assetLoader.loadMetadata(AppConstants.metadataPath);
    final chapters = await _assetLoader.loadText(AppConstants.textPath);
    return Book(metadata: metadata, chapters: chapters);
  }

  Future<List<SyncWord>> loadSyncData() async {
    return await _assetLoader.loadSync(AppConstants.syncPath);
  }
}
