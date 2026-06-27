/// User Data Models
/// 
/// Bookmarks, Notes, Reading Progress, and Settings

import 'dart:convert';

/// Bookmark model
class BookmarkModel {
  final String id;
  final String userId;
  final String bookId;
  final String? chapterId;
  final String wordId;
  final double? positionSeconds;
  final String? note;
  final String color;
  final String? clientId;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BookmarkModel({
    required this.id,
    required this.userId,
    required this.bookId,
    this.chapterId,
    required this.wordId,
    this.positionSeconds,
    this.note,
    this.color = '#FFD700',
    this.clientId,
    this.isSynced = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'book_id': bookId,
    'chapter_id': chapterId,
    'word_id': wordId,
    'position_seconds': positionSeconds,
    'note': note,
    'color': color,
    'client_id': clientId,
    'is_synced': isSynced,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory BookmarkModel.fromJson(Map<String, dynamic> json) => BookmarkModel(
    id: json['id'],
    userId: json['user_id'],
    bookId: json['book_id'],
    chapterId: json['chapter_id'],
    wordId: json['word_id'],
    positionSeconds: json['position_seconds']?.toDouble(),
    note: json['note'],
    color: json['color'] ?? '#FFD700',
    clientId: json['client_id'],
    isSynced: json['is_synced'] ?? true,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : null,
  );

  BookmarkModel copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? chapterId,
    String? wordId,
    double? positionSeconds,
    String? note,
    String? color,
    String? clientId,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BookmarkModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    wordId: wordId ?? this.wordId,
    positionSeconds: positionSeconds ?? this.positionSeconds,
    note: note ?? this.note,
    color: color ?? this.color,
    clientId: clientId ?? this.clientId,
    isSynced: isSynced ?? this.isSynced,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Note model
class NoteModel {
  final String id;
  final String userId;
  final String bookId;
  final String? chapterId;
  final String wordId;
  final String content;
  final String? clientId;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime? updatedAt;

  NoteModel({
    required this.id,
    required this.userId,
    required this.bookId,
    this.chapterId,
    required this.wordId,
    required this.content,
    this.clientId,
    this.isSynced = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'book_id': bookId,
    'chapter_id': chapterId,
    'word_id': wordId,
    'content': content,
    'client_id': clientId,
    'is_synced': isSynced,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
    id: json['id'],
    userId: json['user_id'],
    bookId: json['book_id'],
    chapterId: json['chapter_id'],
    wordId: json['word_id'],
    content: json['content'],
    clientId: json['client_id'],
    isSynced: json['is_synced'] ?? true,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : null,
  );

  NoteModel copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? chapterId,
    String? wordId,
    String? content,
    String? clientId,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NoteModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    wordId: wordId ?? this.wordId,
    content: content ?? this.content,
    clientId: clientId ?? this.clientId,
    isSynced: isSynced ?? this.isSynced,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Reading Progress model
class ReadingProgressModel {
  final String id;
  final String userId;
  final String bookId;
  final String? chapterId;
  final String? wordId;
  final double positionSeconds;
  final double progressPercent;
  final int totalReadingTimeSeconds;
  final int sessionsCount;
  final DateTime lastReadAt;
  final DateTime? lastSyncedAt;
  final String? deviceId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReadingProgressModel({
    required this.id,
    required this.userId,
    required this.bookId,
    this.chapterId,
    this.wordId,
    this.positionSeconds = 0.0,
    this.progressPercent = 0.0,
    this.totalReadingTimeSeconds = 0,
    this.sessionsCount = 0,
    required this.lastReadAt,
    this.lastSyncedAt,
    this.deviceId,
    required this.createdAt,
    this.updatedAt,
  });

  String get formattedProgress => '${progressPercent.toStringAsFixed(1)}%';
  String get formattedTime {
    final hours = totalReadingTimeSeconds ~/ 3600;
    final minutes = (totalReadingTimeSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'book_id': bookId,
    'chapter_id': chapterId,
    'word_id': wordId,
    'position_seconds': positionSeconds,
    'progress_percent': progressPercent,
    'total_reading_time_seconds': totalReadingTimeSeconds,
    'sessions_count': sessionsCount,
    'last_read_at': lastReadAt.toIso8601String(),
    'last_synced_at': lastSyncedAt?.toIso8601String(),
    'device_id': deviceId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory ReadingProgressModel.fromJson(Map<String, dynamic> json) => ReadingProgressModel(
    id: json['id'],
    userId: json['user_id'],
    bookId: json['book_id'],
    chapterId: json['chapter_id'],
    wordId: json['word_id'],
    positionSeconds: json['position_seconds']?.toDouble() ?? 0.0,
    progressPercent: json['progress_percent']?.toDouble() ?? 0.0,
    totalReadingTimeSeconds: json['total_reading_time_seconds'] ?? 0,
    sessionsCount: json['sessions_count'] ?? 0,
    lastReadAt: DateTime.parse(json['last_read_at']),
    lastSyncedAt: json['last_synced_at'] != null 
        ? DateTime.parse(json['last_synced_at']) 
        : null,
    deviceId: json['device_id'],
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : null,
  );

  ReadingProgressModel copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? chapterId,
    String? wordId,
    double? positionSeconds,
    double? progressPercent,
    int? totalReadingTimeSeconds,
    int? sessionsCount,
    DateTime? lastReadAt,
    DateTime? lastSyncedAt,
    String? deviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ReadingProgressModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    wordId: wordId ?? this.wordId,
    positionSeconds: positionSeconds ?? this.positionSeconds,
    progressPercent: progressPercent ?? this.progressPercent,
    totalReadingTimeSeconds: totalReadingTimeSeconds ?? this.totalReadingTimeSeconds,
    sessionsCount: sessionsCount ?? this.sessionsCount,
    lastReadAt: lastReadAt ?? this.lastReadAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    deviceId: deviceId ?? this.deviceId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// User Settings model
class UserSettingsModel {
  final String id;
  final String userId;
  
  // Reader settings
  final double fontSize;
  final double lineHeight;
  final String theme;
  final String fontFamily;
  
  // Audio settings
  final double playbackSpeed;
  final bool autoScroll;
  final String highlightColor;
  final bool autoPlayNextChapter;
  
  // Sync settings
  final bool autoSync;
  final bool syncOverWifiOnly;
  
  // Language
  final String interfaceLanguage;
  final String? contentLanguage;
  
  // Custom settings (extensible)
  final Map<String, dynamic> customSettings;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserSettingsModel({
    required this.id,
    required this.userId,
    this.fontSize = 18.0,
    this.lineHeight = 1.6,
    this.theme = 'system',
    this.fontFamily = 'system',
    this.playbackSpeed = 1.0,
    this.autoScroll = true,
    this.highlightColor = '#6B4EFF',
    this.autoPlayNextChapter = true,
    this.autoSync = true,
    this.syncOverWifiOnly = false,
    this.interfaceLanguage = 'en',
    this.contentLanguage,
    this.customSettings = const {},
    required this.createdAt,
    this.updatedAt,
  });

  bool get isDarkMode => theme == 'dark' || (theme == 'system' && _isSystemDark);
  bool get _isSystemDark => false; // TODO: Check platform brightness

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'font_size': fontSize,
    'line_height': lineHeight,
    'theme': theme,
    'font_family': fontFamily,
    'playback_speed': playbackSpeed,
    'auto_scroll': autoScroll,
    'highlight_color': highlightColor,
    'auto_play_next_chapter': autoPlayNextChapter,
    'auto_sync': autoSync,
    'sync_over_wifi_only': syncOverWifiOnly,
    'interface_language': interfaceLanguage,
    'content_language': contentLanguage,
    'custom_settings': customSettings,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) => UserSettingsModel(
    id: json['id'],
    userId: json['user_id'],
    fontSize: json['font_size']?.toDouble() ?? 18.0,
    lineHeight: json['line_height']?.toDouble() ?? 1.6,
    theme: json['theme'] ?? 'system',
    fontFamily: json['font_family'] ?? 'system',
    playbackSpeed: json['playback_speed']?.toDouble() ?? 1.0,
    autoScroll: json['auto_scroll'] ?? true,
    highlightColor: json['highlight_color'] ?? '#6B4EFF',
    autoPlayNextChapter: json['auto_play_next_chapter'] ?? true,
    autoSync: json['auto_sync'] ?? true,
    syncOverWifiOnly: json['sync_over_wifi_only'] ?? false,
    interfaceLanguage: json['interface_language'] ?? 'en',
    contentLanguage: json['content_language'],
    customSettings: json['custom_settings'] ?? {},
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : null,
  );

  UserSettingsModel copyWith({
    String? id,
    String? userId,
    double? fontSize,
    double? lineHeight,
    String? theme,
    String? fontFamily,
    double? playbackSpeed,
    bool? autoScroll,
    String? highlightColor,
    bool? autoPlayNextChapter,
    bool? autoSync,
    bool? syncOverWifiOnly,
    String? interfaceLanguage,
    String? contentLanguage,
    Map<String, dynamic>? customSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserSettingsModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    theme: theme ?? this.theme,
    fontFamily: fontFamily ?? this.fontFamily,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    autoScroll: autoScroll ?? this.autoScroll,
    highlightColor: highlightColor ?? this.highlightColor,
    autoPlayNextChapter: autoPlayNextChapter ?? this.autoPlayNextChapter,
    autoSync: autoSync ?? this.autoSync,
    syncOverWifiOnly: syncOverWifiOnly ?? this.syncOverWifiOnly,
    interfaceLanguage: interfaceLanguage ?? this.interfaceLanguage,
    contentLanguage: contentLanguage ?? this.contentLanguage,
    customSettings: customSettings ?? this.customSettings,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Reading Statistics model
class ReadingStatsModel {
  final int totalBooks;
  final double totalReadingTimeHours;
  final int totalSessions;
  final double averageSessionMinutes;
  final int booksCompleted;
  final int booksInProgress;
  final List<String> favoriteGenres;
  final int readingStreakDays;

  ReadingStatsModel({
    required this.totalBooks,
    required this.totalReadingTimeHours,
    required this.totalSessions,
    required this.averageSessionMinutes,
    required this.booksCompleted,
    required this.booksInProgress,
    required this.favoriteGenres,
    required this.readingStreakDays,
  });

  factory ReadingStatsModel.fromJson(Map<String, dynamic> json) => ReadingStatsModel(
    totalBooks: json['total_books'],
    totalReadingTimeHours: json['total_reading_time_hours'].toDouble(),
    totalSessions: json['total_sessions'],
    averageSessionMinutes: json['average_session_minutes'].toDouble(),
    booksCompleted: json['books_completed'],
    booksInProgress: json['books_in_progress'],
    favoriteGenres: List<String>.from(json['favorite_genres']),
    readingStreakDays: json['reading_streak_days'],
  );
}
