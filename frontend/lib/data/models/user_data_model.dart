/// User Data Models - all fromJson null-safe
import 'dart:convert';

String _safeDate(dynamic val) {
  if (val == null) return DateTime.now().toIso8601String();
  return (val as String).replaceAll('+00:00', 'Z');
}

class BookmarkModel {
  final String id; final String userId; final String bookId;
  final String? chapterId; final String wordId; final double? positionSeconds;
  final String? note; final String color; final String? clientId;
  final bool isSynced; final DateTime createdAt; final DateTime? updatedAt;

  BookmarkModel({
    required this.id, required this.userId, required this.bookId,
    this.chapterId, required this.wordId, this.positionSeconds, this.note,
    this.color = '#FFD700', this.clientId, this.isSynced = true,
    required this.createdAt, this.updatedAt,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) => BookmarkModel(
    id: (json['id'] ?? '') as String, userId: (json['user_id'] ?? '') as String,
    bookId: (json['book_id'] ?? '') as String,
    chapterId: json['chapter_id'] as String?,
    wordId: (json['word_id'] ?? '') as String,
    positionSeconds: (json['position_seconds'] as num?)?.toDouble(),
    note: json['note'] as String?, color: (json['color'] ?? '#FFD700') as String,
    clientId: json['client_id'] as String?,
    isSynced: (json['is_synced'] ?? true) as bool,
    createdAt: DateTime.parse(_safeDate(json['created_at'])),
    updatedAt: json['updated_at'] != null ? DateTime.parse(_safeDate(json['updated_at'])) : null,
  );
}

class NoteModel {
  final String id; final String userId; final String bookId;
  final String? chapterId; final String wordId; final String content;
  final String? clientId; final bool isSynced;
  final DateTime createdAt; final DateTime? updatedAt;

  NoteModel({
    required this.id, required this.userId, required this.bookId,
    this.chapterId, required this.wordId, required this.content,
    this.clientId, this.isSynced = true, required this.createdAt, this.updatedAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
    id: (json['id'] ?? '') as String, userId: (json['user_id'] ?? '') as String,
    bookId: (json['book_id'] ?? '') as String,
    chapterId: json['chapter_id'] as String?,
    wordId: (json['word_id'] ?? '') as String,
    content: (json['content'] ?? '') as String,
    clientId: json['client_id'] as String?,
    isSynced: (json['is_synced'] ?? true) as bool,
    createdAt: DateTime.parse(_safeDate(json['created_at'])),
    updatedAt: json['updated_at'] != null ? DateTime.parse(_safeDate(json['updated_at'])) : null,
  );
}

class ReadingProgressModel {
  final String id; final String userId; final String bookId;
  final String? chapterId; final String? wordId; final double positionSeconds;
  final double progressPercent; final int totalReadingTimeSeconds;
  final int sessionsCount; final DateTime lastReadAt;
  final DateTime? lastSyncedAt; final String? deviceId;
  final DateTime createdAt; final DateTime? updatedAt;

  ReadingProgressModel({
    required this.id, required this.userId, required this.bookId,
    this.chapterId, this.wordId, this.positionSeconds = 0.0,
    this.progressPercent = 0.0, this.totalReadingTimeSeconds = 0,
    this.sessionsCount = 0, DateTime? lastReadAt, this.lastSyncedAt,
    this.deviceId, DateTime? createdAt, this.updatedAt,
  })  : lastReadAt = lastReadAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory ReadingProgressModel.fromJson(Map<String, dynamic> json) => ReadingProgressModel(
    id: (json['id'] ?? '') as String, userId: (json['user_id'] ?? '') as String,
    bookId: (json['book_id'] ?? '') as String,
    chapterId: json['chapter_id'] as String?,
    wordId: json['word_id'] as String?,
    positionSeconds: (json['position_seconds'] as num?)?.toDouble() ?? 0.0,
    progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
    totalReadingTimeSeconds: (json['total_reading_time_seconds'] as int?) ?? 0,
    sessionsCount: (json['sessions_count'] as int?) ?? 0,
    lastSyncedAt: json['last_synced_at'] != null ? DateTime.parse(_safeDate(json['last_synced_at'])) : null,
    lastReadAt: json['last_read_at'] != null ? DateTime.parse(_safeDate(json['last_read_at'])) : null,
    updatedAt: json['updated_at'] != null ? DateTime.parse(_safeDate(json['updated_at'])) : null,
  );

  ReadingProgressModel copyWith({
    String? id, String? userId, String? bookId, String? chapterId,
    String? wordId, double? positionSeconds, double? progressPercent,
    int? totalReadingTimeSeconds, int? sessionsCount,
    DateTime? lastReadAt, DateTime? lastSyncedAt,
  }) => ReadingProgressModel(
    id: id ?? this.id, userId: userId ?? this.userId,
    bookId: bookId ?? this.bookId, chapterId: chapterId ?? this.chapterId,
    wordId: wordId ?? this.wordId,
    positionSeconds: positionSeconds ?? this.positionSeconds,
    progressPercent: progressPercent ?? this.progressPercent,
    totalReadingTimeSeconds: totalReadingTimeSeconds ?? this.totalReadingTimeSeconds,
    sessionsCount: sessionsCount ?? this.sessionsCount,
    lastReadAt: lastReadAt ?? this.lastReadAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
}

class UserSettingsModel {
  final String id; final String userId; final double fontSize;
  final double lineHeight; final String theme; final String fontFamily;
  final double playbackSpeed; final bool autoScroll; final String highlightColor;
  final bool autoPlayNextChapter; final bool autoSync; final bool syncOverWifiOnly;
  final String interfaceLanguage; final String? contentLanguage;
  final DateTime createdAt; final DateTime? updatedAt;

  UserSettingsModel({
    required this.id, required this.userId, this.fontSize = 18.0,
    this.lineHeight = 1.6, this.theme = 'system', this.fontFamily = 'system',
    this.playbackSpeed = 1.0, this.autoScroll = true, this.highlightColor = '#6B4EFF',
    this.autoPlayNextChapter = false, this.autoSync = true, this.syncOverWifiOnly = false,
    this.interfaceLanguage = 'en', this.contentLanguage,
    DateTime? createdAt, this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) => UserSettingsModel(
    id: (json['id'] ?? '') as String, userId: (json['user_id'] ?? '') as String,
    fontSize: (json['font_size'] as num?)?.toDouble() ?? 18.0,
    lineHeight: (json['line_height'] as num?)?.toDouble() ?? 1.6,
    theme: (json['theme'] ?? 'system') as String,
    fontFamily: (json['font_family'] ?? 'system') as String,
    playbackSpeed: (json['playback_speed'] as num?)?.toDouble() ?? 1.0,
    autoScroll: (json['auto_scroll'] ?? true) as bool,
    highlightColor: (json['highlight_color'] ?? '#6B4EFF') as String,
  );
}

class SearchHistoryModel {
  final String id; final String query; final int? resultsCount;
  final String? clickedBookId; final DateTime createdAt;

  SearchHistoryModel({
    required this.id, required this.query, this.resultsCount,
    this.clickedBookId, required this.createdAt,
  });

  factory SearchHistoryModel.fromJson(Map<String, dynamic> json) => SearchHistoryModel(
    id: (json['id'] ?? '') as String, query: (json['query'] ?? '') as String,
    resultsCount: json['results_count'] as int?,
    clickedBookId: json['clicked_book_id'] as String?,
    createdAt: DateTime.parse(_safeDate(json['created_at'])),
  );
}

class ReadingStatsModel {
  final int totalBooks; final double totalReadingTimeHours;
  final int totalSessions; final double averageSessionMinutes;
  final int booksCompleted; final int booksInProgress;
  final List<String> favoriteGenres; final int readingStreakDays;

  ReadingStatsModel({
    this.totalBooks = 0, this.totalReadingTimeHours = 0.0, this.totalSessions = 0,
    this.averageSessionMinutes = 0.0, this.booksCompleted = 0, this.booksInProgress = 0,
    this.favoriteGenres = const [], this.readingStreakDays = 0,
  });

  factory ReadingStatsModel.fromJson(Map<String, dynamic> json) => ReadingStatsModel(
    totalBooks: (json['total_books'] as int?) ?? 0,
    totalReadingTimeHours: (json['total_reading_time_hours'] as num?)?.toDouble() ?? 0.0,
    totalSessions: (json['total_sessions'] as int?) ?? 0,
    averageSessionMinutes: (json['average_session_minutes'] as num?)?.toDouble() ?? 0.0,
    booksCompleted: (json['books_completed'] as int?) ?? 0,
    booksInProgress: (json['books_in_progress'] as int?) ?? 0,
    favoriteGenres: (json['favorite_genres'] as List?)?.cast<String>() ?? [],
    readingStreakDays: (json['reading_streak_days'] as int?) ?? 0,
  );
}
