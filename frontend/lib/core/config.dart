/// LYRR Platform Configuration
/// 
/// Central configuration for the entire application

class AppConfig {
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.228:8000/api/v1',
  );
  
  static const String apiVersion = 'v1';
  static const Duration apiTimeout = Duration(seconds: 30);
  
  // Feature Flags
  static const bool enableDRM = true;
  static const bool enableOfflineMode = true;
  static const bool enableCloudSync = true;
  static const bool enableAINarration = true;
  static const bool enableDictionary = true;
  static const bool enableSocialAuth = true;
  
  // Sync Configuration
  static const Duration syncInterval = Duration(minutes: 5);
  static const int syncBatchSize = 50;
  static const Duration syncTimeout = Duration(seconds: 60);
  
  // DRM Configuration
  static const Duration drmKeyRefreshInterval = Duration(hours: 24);
  static const String drmAlgorithm = 'AES-256-GCM';
  
  // Audio Configuration
  static const int audioPreloadSeconds = 30;
  static const double defaultPlaybackSpeed = 1.0;
  static const List<double> playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5];
  
  // UI Configuration
  static const double minFontSize = 12.0;
  static const double maxFontSize = 32.0;
  static const double defaultFontSize = 18.0;
  static const double minLineHeight = 1.2;
  static const double maxLineHeight = 2.5;
  static const double defaultLineHeight = 1.6;
  
  // Cache Configuration
  static const int maxCacheSizeMB = 500;
  static const Duration cacheExpiryDays = Duration(days: 30);
  
  // Search Configuration
  static const int searchDebounceMs = 300;
  static const int searchMinChars = 2;
  static const int searchMaxResults = 50;
  
  // AI Narration
  static const String elevenLabsApiKey = String.fromEnvironment('ELEVENLABS_API_KEY');
  static const String defaultVoiceId = 'pNInz6obpgDQGcFmaJgB'; // Adam
  
  // OAuth Configuration
  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const String appleClientId = String.fromEnvironment('APPLE_CLIENT_ID');
  
  // Supported Languages
  static const List<String> supportedLanguages = [
    'en', 'es', 'fr', 'de', 'it', 'pt', 'zh', 'ja', 'ko', 'ar'
  ];
  
  static const Map<String, String> languageNames = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Português',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'ar': 'العربية',
  };
}
