/// Book Models - ALL fromJson methods null-safe
import 'dart:convert';
import '../../core/config.dart';

class BookModel {
  final String id;
  final String title;
  final String? subtitle;
  final String author;
  final String? description;
  final String? coverUrl;
  final String language;
  final int? duration;
  final int? wordCount;
  final String status;
  final bool isFeatured;
  final bool drmEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDownloaded;
  final bool isPurchased;
  final double? progressPercent;
  final DateTime? lastReadAt;
  final String? bookType;

  BookModel({
    required this.id, required this.title, this.subtitle, required this.author,
    this.description, this.coverUrl, this.language = 'en', this.duration,
    this.wordCount, this.status = 'published', this.isFeatured = false,
    this.drmEnabled = true, required this.createdAt, this.updatedAt,
    this.isDownloaded = false, this.isPurchased = false,
    this.progressPercent, this.lastReadAt, this.bookType,
  });

  String? get resolvedCoverUrl {
    if (coverUrl == null) return null;
    if (coverUrl!.startsWith('http')) return coverUrl;
    final base = AppConfig.apiBaseUrl.replaceAll('/api/v1', '');
    return '$base$coverUrl';
  }

  String get formattedDuration {
    if (duration == null) return '';
    final h = duration! ~/ 3600;
    final m = (duration! % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String get displayTitle => subtitle != null ? '$title: $subtitle' : title;

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'subtitle': subtitle, 'author': author,
    'description': description, 'cover_url': coverUrl, 'language': language,
    'duration': duration, 'word_count': wordCount, 'status': status,
    'is_featured': isFeatured, 'drm_enabled': drmEnabled,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'is_downloaded': isDownloaded, 'is_purchased': isPurchased,
    'progress_percent': progressPercent,
    'last_read_at': lastReadAt?.toIso8601String(),
  };

  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(
    id: (json['id'] ?? json['book_id'] ?? '') as String,
    title: (json['title'] ?? '') as String,
    subtitle: json['subtitle'] as String?,
    author: (json['author'] ?? '') as String,
    description: json['description'] as String?,
    coverUrl: json['cover_url'] as String?,
    language: (json['language'] ?? 'en') as String,
    duration: json['duration'] as int?,
    wordCount: json['word_count'] as int?,
    status: (json['status'] ?? 'published') as String,
    isFeatured: (json['is_featured'] ?? false) as bool,
    drmEnabled: (json['drm_enabled'] ?? true) as bool,
    createdAt: json['created_at'] != null
        ? DateTime.parse((json['created_at'] as String).replaceAll('+00:00', 'Z'))
        : DateTime.now(),
    updatedAt: json['updated_at'] != null
        ? DateTime.parse((json['updated_at'] as String).replaceAll('+00:00', 'Z'))
        : null,
    isDownloaded: (json['is_downloaded'] ?? false) as bool,
    isPurchased: (json['is_purchased'] ?? false) as bool,
    progressPercent: (json['progress_percent'] as num?)?.toDouble(),
    lastReadAt: json['last_read_at'] != null
        ? DateTime.parse((json['last_read_at'] as String).replaceAll('+00:00', 'Z'))
        : null,
    bookType: json['book_type'] as String?,
  );

  BookModel copyWith({
    String? id, String? title, String? subtitle, String? author,
    String? description, String? coverUrl, String? language,
    int? duration, int? wordCount, String? status, bool? isFeatured,
    bool? drmEnabled, DateTime? createdAt, DateTime? updatedAt,
    bool? isDownloaded, bool? isPurchased, double? progressPercent,
    DateTime? lastReadAt,
  }) => BookModel(
    id: id ?? this.id, title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle, author: author ?? this.author,
    description: description ?? this.description,
    coverUrl: coverUrl ?? this.coverUrl, language: language ?? this.language,
    duration: duration ?? this.duration, wordCount: wordCount ?? this.wordCount,
    status: status ?? this.status, isFeatured: isFeatured ?? this.isFeatured,
    drmEnabled: drmEnabled ?? this.drmEnabled,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
    isDownloaded: isDownloaded ?? this.isDownloaded,
    isPurchased: isPurchased ?? this.isPurchased,
    progressPercent: progressPercent ?? this.progressPercent,
    lastReadAt: lastReadAt ?? this.lastReadAt,
  );
}

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
    required this.id, required this.bookId, required this.title,
    required this.orderIndex, required this.paragraphs, this.syncData,
    required this.createdAt, this.updatedAt,
  });

  List<WordModel> get allWords => paragraphs.expand((p) => p.words).toList();

  factory ChapterModel.fromJson(Map<String, dynamic> json) => ChapterModel(
    id: (json['id'] ?? '') as String,
    bookId: (json['book_id'] ?? '') as String,
    title: (json['title'] ?? '') as String,
    orderIndex: (json['order_index'] ?? 0) as int,
    paragraphs: ((json['paragraphs'] ?? json['content'] ?? []) as List)
        .map((p) => ParagraphModel.fromJson(p as Map<String, dynamic>))
        .toList(),
    syncData: (json['sync_data'] as List?)
        ?.map((s) => SyncWordModel.fromJson(s as Map<String, dynamic>))
        .toList(),
    createdAt: json['created_at'] != null
        ? DateTime.parse((json['created_at'] as String).replaceAll('+00:00', 'Z'))
        : DateTime.now(),
    updatedAt: json['updated_at'] != null
        ? DateTime.parse((json['updated_at'] as String).replaceAll('+00:00', 'Z'))
        : null,
  );
}

class ParagraphModel {
  final List<WordModel> words;
  ParagraphModel({required this.words});

  Map<String, dynamic> toJson() => {'words': words.map((w) => w.toJson()).toList()};

  factory ParagraphModel.fromJson(Map<String, dynamic> json) => ParagraphModel(
    words: (json['words'] as List? ?? [])
        .map((w) => WordModel.fromJson(w as Map<String, dynamic>))
        .toList(),
  );
  String get fullText => words.map((w) => w.text).join(' ');
}

class WordModel {
  final String id;
  final String text;
  WordModel({required this.id, required this.text});

  Map<String, dynamic> toJson() => {'id': id, 'text': text};

  factory WordModel.fromJson(Map<String, dynamic> json) => WordModel(
    id: (json['id'] ?? '') as String,
    text: (json['text'] ?? '') as String,
  );
}

class SyncWordModel {
  final String id;
  final double start;
  final double end;
  SyncWordModel({required this.id, required this.start, required this.end});

  double get duration => end - start;
  bool isActiveAt(double position) => position >= start && position < end;

  Map<String, dynamic> toJson() => {'id': id, 'start': start, 'end': end};

  factory SyncWordModel.fromJson(Map<String, dynamic> json) => SyncWordModel(
    id: (json['id'] ?? '') as String,
    start: (json['start'] as num?)?.toDouble() ?? 0.0,
    end: (json['end'] as num?)?.toDouble() ?? 0.0,
  );
}

class BookMediaModel {
  final String id; final String bookId; final String audioUrl;
  final String format; final String quality; final int? duration;
  final int? sizeBytes; final bool isAiNarrated; final String? voiceId;
  final bool isEncrypted; final String? encryptionKeyId; final DateTime createdAt;

  BookMediaModel({
    required this.id, required this.bookId, required this.audioUrl,
    this.format = 'mp3', this.quality = 'high', this.duration, this.sizeBytes,
    this.isAiNarrated = false, this.voiceId, this.isEncrypted = true,
    this.encryptionKeyId, required this.createdAt,
  });

  factory BookMediaModel.fromJson(Map<String, dynamic> json) => BookMediaModel(
    id: (json['id'] ?? '') as String,
    bookId: (json['book_id'] ?? '') as String,
    audioUrl: (json['audio_url'] ?? '') as String,
    format: (json['format'] ?? 'mp3') as String,
    quality: (json['quality'] ?? 'high') as String,
    duration: json['duration'] as int?,
    sizeBytes: json['size_bytes'] as int?,
    isAiNarrated: (json['is_ai_narrated'] ?? false) as bool,
    voiceId: json['voice_id'] as String?,
    isEncrypted: (json['is_encrypted'] ?? true) as bool,
    encryptionKeyId: json['encryption_key_id'] as String?,
    createdAt: DateTime.parse((json['created_at'] as String).replaceAll('+00:00', 'Z')),
  );
}

class DRMLicenseModel {
  final String licenseKey;
  final DateTime? expiresAt;
  final String? downloadUrl;
  final String? encryptionKeyId;

  DRMLicenseModel({required this.licenseKey, this.expiresAt, this.downloadUrl, this.encryptionKeyId});

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory DRMLicenseModel.fromJson(Map<String, dynamic> json) => DRMLicenseModel(
    licenseKey: (json['license_key'] ?? '') as String,
    expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
    downloadUrl: json['download_url'] as String?,
    encryptionKeyId: json['encryption_key_id'] as String?,
  );
}
