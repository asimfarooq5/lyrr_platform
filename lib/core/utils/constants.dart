class AppConstants {
  static const String sampleBookDir = 'assets/books/sample_book';
  static const String metadataPath = '$sampleBookDir/metadata.json';
  static const String textPath = '$sampleBookDir/text.json';
  static const String syncPath = '$sampleBookDir/sync.json';
  static const String audioPath = '$sampleBookDir/audio.aac';
  static const String coverPath = '$sampleBookDir/cover.jpg';

  // CDN base URL for book downloads (configure this to your CDN endpoint)
  static const String cdnBaseUrl = 'https://cdn.lyrr.app/books';

  // Local storage directories
  static const String booksDir = 'books';
  static const String coversDir = 'covers';
}
