/// Book Models
/// 
/// Comprehensive book data models for the LYRR platform

import 'dart:convert';

/// Book model representing a published book
class BookModel {
  final String id;
  final String title;
  final String? subtitle;
  final String author;
  final String? description;
  final String? coverUrl;
  final String language;
  final int? duration; // in seconds
  final int? wordCount;
  final String status;
  final bool isFeatured;
  final bool drmEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Local state
  final bool isDownloaded;
  final bool isPurchased;
  final double? progressPercent;
  final DateTime? lastReadAt;

  BookModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.author,
    this.description,
    this.coverUrl,
    this.language = 'en',
    this.duration,
    this.wordCount,
    this.status = 'published',
    this.isFeatured = false,
    this.drmEnabled = true,
    required this.createdAt,
    this.updatedAt,
    this.isDownloaded = false,
    this.isPurchased = false,
    this.progressPercent,
    this.lastReadAt,
  });

  String get formattedDuration {
    if (duration == null) return '';
    final hours = duration! ~/ 3600;
    final minutes = (duration! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get displayTitle => subtitle != null ? '$title: $subtitle' : title;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'author': author,
    'description': description,
    'cover_url': coverUrl,
    'language': language,
    'duration': duration,
    'word_count': wordCount,
    'status': status,
    'is_featured': isFeatured,
    'drm_enabled': drmEnabled,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'is_downloaded': isDownloaded,
    'is_purchased': isPurchased,
    'progress_percent': progressPercent,
    'last_read_at': lastReadAt?.toIso8601String(),
  };

  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(
    id: json['id'],
    title: json['title'],
    subtitle: json['subtitle'],
    author: json['author'],
    description: json['description'],
    coverUrl: json['cover_url'],
    language: json['language'] ?? 'en',
    duration: json['duration'],
    wordCount: json['word_count'],
    status: json['status'] ?? 'published',
    isFeatured: json['is_featured'] ?? false,
    drmEnabled: json['drm_enabled'] ?? true,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : null,
    isDownloaded: json['is_downloaded'] ?? false,
    isPurchased: json['is_purchased'] ?? false,
    progressPercent: json['progress_percent']?.toDouble(),
    lastReadAt: json['last_read_at'] != null 
        ? DateTime.parse(json['last_read_at']) 
        : null,
  );

  BookModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? author,
    String? description,
    String? coverUrl,
    String? language,
    int? duration,
    int? wordCount,
    String? status,
    bool? isFeatured,
    bool? drmEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDownloaded,
    bool? isPurchased,
    double? progressPercent,
    DateTime? lastReadAt,
  }) => BookModel(
    id: id ?? this.id,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    author: author ?? this.author,
    description: description ?? this.description,
    coverUrl: coverUrl ?? this.coverUrl,
    language: language ?? this.language,
    duration: duration ?? this.duration,
    wordCount: wordCount ?? this.wordCount,
    status: status ?? this.status,
    isFeatured: isFeatured ?? this.isFeatured,
    drmEnabled: drmEnabled ?? this.drmEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDownloaded: isDownloaded ?? this.isDownloaded,
    isPurchased: isPurchased ?? this.isPurchased,
    progressPercent: progressPercent ?? this.progressPercent,
    lastReadAt: lastReadAt ?? this.lastReadAt,
  );
}

/// Chapter model
class ChapterModel {
  final String id;
  final String bookId;
  final String title;
  final int orderIndex;
  final List<ParagraphModel> paragraphs;
  final List<SyncWordModel>? syncData;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChapterModel({
    required this.id,
    required this.bookId,
    required this.title,
    required this.orderIndex,
    required this.paragraphs,
    this.syncData,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'book_id': bookId,
    'title': title,
    'order_index': orderIndex,
    'paragraphs': paragraphs.map((p) => p.toJson()).toList(),
    'sync_data': syncData?.map((s) => s.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory ChapterModel.fromJson(Map<String, dynamic> json) => ChapterModel(
    id: json['id'],
    bookId: json['book_id'],
    title: json['title'],
    orderIndex: json['order_index'],
    paragraphs: (json['content'] as List?)
        ?.map((p) => ParagraphModel.fromJson(p))
        .toList() ?? [],
    syncData: (json['sync_data'] as List?)
        ?.map((s) => SyncWordModel.fromJson(s))
        .toList(),
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : null,
  );

  /// Get all words flattened from all paragraphs
  List<WordModel> get allWords {
    return paragraphs.expand((p) => p.words).toList();
  }
}

/// Paragraph model containing words
class ParagraphModel {
  final List<WordModel> words;

  ParagraphModel({required this.words});

  Map<String, dynamic> toJson() => {
    'words': words.map((w) => w.toJson()).toList(),
  };

  factory ParagraphModel.fromJson(Map<String, dynamic> json) => ParagraphModel(
    words: (json['words'] as List)
        .map((w) => WordModel.fromJson(w))
        .toList(),
  );

  String get fullText => words.map((w) => w.text).join(' ');
}

/// Word model with unique ID
class WordModel {
  final String id;
  final String text;

  WordModel({required this.id, required this.text});

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
  };

  factory WordModel.fromJson(Map<String, dynamic> json) => WordModel(
    id: json['id'],
    text: json['text'],
  );
}

/// Synchronization word timing model
class SyncWordModel {
  final String id;
  final double start;
  final double end;

  SyncWordModel({required this.id, required this.start, required this.end});

  double get duration => end - start;
  bool isActiveAt(double position) => position >= start && position < end;

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start,
    'end': end,
  };

  factory SyncWordModel.fromJson(Map<String, dynamic> json) => SyncWordModel(
    id: json['id'],
    start: json['start'].toDouble(),
    end: json['end'].toDouble(),
  );
}

/// Book media model (audio files)
class BookMediaModel {
  final String id;
  final String bookId;
  final String audioUrl;
  final String format;
  final String quality;
  final int? duration;
  final int? sizeBytes;
  final bool isAiNarrated;
  final String? voiceId;
  final bool isEncrypted;
  final String? encryptionKeyId;
  final DateTime createdAt;

  BookMediaModel({
    required this.id,
    required this.bookId,
    required this.audioUrl,
    this.format = 'mp3',
    this.quality = 'high',
    this.duration,
    this.sizeBytes,
    this.isAiNarrated = false,
    this.voiceId,
    this.isEncrypted = true,
    this.encryptionKeyId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'book_id': bookId,
    'audio_url': audioUrl,
    'format': format,
    'quality': quality,
    'duration': duration,
    'size_bytes': sizeBytes,
    'is_ai_narrated': isAiNarrated,
    'voice_id': voiceId,
    'is_encrypted': isEncrypted,
    'encryption_key_id': encryptionKeyId,
    'created_at': createdAt.toIso8601String(),
  };

  factory BookMediaModel.fromJson(Map<String, dynamic> json) => BookMediaModel(
    id: json['id'],
    bookId: json['book_id'],
    audioUrl: json['audio_url'],
    format: json['format'] ?? 'mp3',
    quality: json['quality'] ?? 'high',
    duration: json['duration'],
    sizeBytes: json['size_bytes'],
    isAiNarrated: json['is_ai_narrated'] ?? false,
    voiceId: json['voice_id'],
    isEncrypted: json['is_encrypted'] ?? true,
    encryptionKeyId: json['encryption_key_id'],
    createdAt: DateTime.parse(json['created_at']),
  );
}

/// DRM License model
class DRMLicenseModel {
  final String licenseKey;
  final DateTime? expiresAt;
  final String? downloadUrl;
  final String? encryptionKeyId;

  DRMLicenseModel({
    required this.licenseKey,
    this.expiresAt,
    this.downloadUrl,
    this.encryptionKeyId,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory DRMLicenseModel.fromJson(Map<String, dynamic> json) => DRMLicenseModel(
    licenseKey: json['license_key'],
    expiresAt: json['expires_at'] != null 
        ? DateTime.parse(json['expires_at']) 
        : null,
    downloadUrl: json['download_url'],
    encryptionKeyId: json['encryption_key_id'],
  );
}
