/// Application Constants

class AppConstants {
  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String settingsKey = 'app_settings';
  static const String lastSyncKey = 'last_sync_timestamp';
  static const String deviceIdKey = 'device_id';
  static const String offlineBooksKey = 'offline_books';
  
  // Database Names
  static const String mainDatabase = 'lyrr_main.db';
  static const String cacheDatabase = 'lyrr_cache.db';
  static const String syncDatabase = 'lyrr_sync.db';
  
  // Table Names
  static const String booksTable = 'books';
  static const String chaptersTable = 'chapters';
  static const String bookmarksTable = 'bookmarks';
  static const String notesTable = 'notes';
  static const String progressTable = 'reading_progress';
  static const String syncQueueTable = 'sync_queue';
  
  // Asset Paths
  static const String fontsPath = 'assets/fonts/';
  static const String imagesPath = 'assets/images/';
  static const String audioPath = 'assets/audio/';
  
  // Error Messages
  static const String networkError = 'network_error';
  static const String authError = 'authentication_error';
  static const String syncError = 'synchronization_error';
  static const String drmError = 'drm_error';
  static const String offlineError = 'offline_error';
  
  // Analytics Events
  static const String eventBookOpened = 'book_opened';
  static const String eventBookmarkCreated = 'bookmark_created';
  static const String eventNoteCreated = 'note_created';
  static const String eventAudioPlayed = 'audio_played';
  static const String eventSyncCompleted = 'sync_completed';
  static const String eventDownloadStarted = 'download_started';
  static const String eventDownloadCompleted = 'download_completed';
  
  // Notification Channels
  static const String downloadChannelId = 'download_channel';
  static const String syncChannelId = 'sync_channel';
  static const String generalChannelId = 'general_channel';
}
