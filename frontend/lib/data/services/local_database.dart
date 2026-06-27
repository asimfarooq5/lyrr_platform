/// Local Database Service
/// 
/// SQLite database using Drift for offline storage of books, bookmarks, notes, etc.

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../models/book_model.dart';
import '../models/user_data_model.dart';

part 'local_database.g.dart';

/// Books table
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get subtitle => text().nullable()();
  TextColumn get author => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  IntColumn get duration => integer().nullable()();
  IntColumn get wordCount => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('published'))();
  BoolColumn get isFeatured => boolean().withDefault(const Constant(false))();
  BoolColumn get drmEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  BoolColumn get isPurchased => boolean().withDefault(const Constant(false))();
  RealColumn get progressPercent => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Chapters table
class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  IntColumn get orderIndex => integer()();
  TextColumn get contentJson => text()(); // JSON string of paragraphs
  TextColumn get syncDataJson => text().nullable()(); // JSON string of sync data
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bookmarks table
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get chapterId => text().nullable()();
  TextColumn get wordId => text()();
  RealColumn get positionSeconds => real().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get color => text().withDefault(const Constant('#FFD700'))();
  TextColumn get clientId => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Notes table
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get chapterId => text().nullable()();
  TextColumn get wordId => text()();
  TextColumn get content => text()();
  TextColumn get clientId => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reading progress table
class ReadingProgress extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get chapterId => text().nullable()();
  TextColumn get wordId => text().nullable()();
  RealColumn get positionSeconds => real().withDefault(const Constant(0.0))();
  RealColumn get progressPercent => real().withDefault(const Constant(0.0))();
  IntColumn get totalReadingTimeSeconds => integer().withDefault(const Constant(0))();
  IntColumn get sessionsCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReadAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get deviceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sync queue table for pending changes
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get operation => text()(); // create, update, delete
  TextColumn get entityType => text()(); // bookmark, note, progress
  TextColumn get entityId => text()();
  TextColumn get dataJson => text()(); // JSON data
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Settings table
class AppSettings extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  RealColumn get fontSize => real().withDefault(const Constant(18.0))();
  RealColumn get lineHeight => real().withDefault(const Constant(1.6))();
  TextColumn get theme => text().withDefault(const Constant('system'))();
  TextColumn get fontFamily => text().withDefault(const Constant('system'))();
  RealColumn get playbackSpeed => real().withDefault(const Constant(1.0))();
  BoolColumn get autoScroll => boolean().withDefault(const Constant(true))();
  TextColumn get highlightColor => text().withDefault(const Constant('#6B4EFF'))();
  BoolColumn get autoPlayNextChapter => boolean().withDefault(const Constant(true))();
  BoolColumn get autoSync => boolean().withDefault(const Constant(true))();
  BoolColumn get syncOverWifiOnly => boolean().withDefault(const Constant(false))();
  TextColumn get interfaceLanguage => text().withDefault(const Constant('en'))();
  TextColumn get contentLanguage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift database
@DriftDatabase(tables: [Books, Chapters, Bookmarks, Notes, ReadingProgress, SyncQueue, AppSettings])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Book operations
  Future<List<BookModel>> getAllBooks() async {
    final rows = await select(books).get();
    return rows.map((row) => _bookFromRow(row)).toList();
  }

  Future<BookModel?> getBook(String id) async {
    final query = select(books)..where((b) => b.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _bookFromRow(row) : null;
  }

  Future<List<BookModel>> getDownloadedBooks() async {
    final query = select(books)..where((b) => b.isDownloaded.equals(true));
    final rows = await query.get();
    return rows.map((row) => _bookFromRow(row)).toList();
  }

  Future<void> insertBook(BookModel book) async {
    await into(books).insert(
      BooksCompanion(
        id: Value(book.id),
        title: Value(book.title),
        subtitle: Value(book.subtitle),
        author: Value(book.author),
        description: Value(book.description),
        coverUrl: Value(book.coverUrl),
        language: Value(book.language),
        duration: Value(book.duration),
        wordCount: Value(book.wordCount),
        status: Value(book.status),
        isFeatured: Value(book.isFeatured),
        drmEnabled: Value(book.drmEnabled),
        isDownloaded: Value(book.isDownloaded),
        isPurchased: Value(book.isPurchased),
        progressPercent: Value(book.progressPercent ?? 0.0),
        lastReadAt: Value(book.lastReadAt),
        createdAt: Value(book.createdAt),
        updatedAt: Value(book.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updateBookDownloadStatus(String bookId, bool isDownloaded) async {
    final query = update(books)..where((b) => b.id.equals(bookId));
    await query.write(BooksCompanion(
      isDownloaded: Value(isDownloaded),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteBook(String id) async {
    final query = delete(books)..where((b) => b.id.equals(id));
    await query.go();
  }

  // Chapter operations
  Future<List<ChapterModel>> getChapters(String bookId) async {
    final query = select(chapters)
      ..where((c) => c.bookId.equals(bookId))
      ..orderBy([(c) => OrderingTerm(expression: c.orderIndex)]);
    final rows = await query.get();
    return rows.map((row) => _chapterFromRow(row)).toList();
  }

  Future<void> insertChapter(ChapterModel chapter) async {
    await into(chapters).insert(
      ChaptersCompanion(
        id: Value(chapter.id),
        bookId: Value(chapter.bookId),
        title: Value(chapter.title),
        orderIndex: Value(chapter.orderIndex),
        contentJson: Value(_encodeJson(chapter.paragraphs.map((p) => p.toJson()).toList())),
        syncDataJson: Value(chapter.syncData != null 
            ? _encodeJson(chapter.syncData!.map((s) => s.toJson()).toList())
            : null),
        createdAt: Value(chapter.createdAt),
        updatedAt: Value(chapter.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // Bookmark operations
  Future<List<BookmarkModel>> getBookmarks(String bookId) async {
    final query = select(bookmarks)
      ..where((b) => b.bookId.equals(bookId))
      ..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return rows.map((row) => _bookmarkFromRow(row)).toList();
  }

  Future<List<BookmarkModel>> getAllBookmarks(String userId) async {
    final query = select(bookmarks)
      ..where((b) => b.userId.equals(userId))
      ..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return rows.map((row) => _bookmarkFromRow(row)).toList();
  }

  Future<List<BookmarkModel>> getUnsyncedBookmarks(String userId) async {
    final query = select(bookmarks)
      ..where((b) => b.userId.equals(userId) & b.isSynced.equals(false));
    final rows = await query.get();
    return rows.map((row) => _bookmarkFromRow(row)).toList();
  }

  Future<void> insertBookmark(BookmarkModel bookmark) async {
    await into(bookmarks).insert(
      BookmarksCompanion(
        id: Value(bookmark.id),
        userId: Value(bookmark.userId),
        bookId: Value(bookmark.bookId),
        chapterId: Value(bookmark.chapterId),
        wordId: Value(bookmark.wordId),
        positionSeconds: Value(bookmark.positionSeconds),
        note: Value(bookmark.note),
        color: Value(bookmark.color),
        clientId: Value(bookmark.clientId),
        isSynced: Value(bookmark.isSynced),
        createdAt: Value(bookmark.createdAt),
        updatedAt: Value(bookmark.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updateBookmarkSyncStatus(String id, bool isSynced) async {
    final query = update(bookmarks)..where((b) => b.id.equals(id));
    await query.write(BookmarksCompanion(
      isSynced: Value(isSynced),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteBookmark(String id) async {
    final query = delete(bookmarks)..where((b) => b.id.equals(id));
    await query.go();
  }

  // Note operations
  Future<List<NoteModel>> getNotes(String bookId) async {
    final query = select(notes)
      ..where((n) => n.bookId.equals(bookId))
      ..orderBy([(n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return rows.map((row) => _noteFromRow(row)).toList();
  }

  Future<List<NoteModel>> getUnsyncedNotes(String userId) async {
    final query = select(notes)
      ..where((n) => n.userId.equals(userId) & n.isSynced.equals(false));
    final rows = await query.get();
    return rows.map((row) => _noteFromRow(row)).toList();
  }

  Future<void> insertNote(NoteModel note) async {
    await into(notes).insert(
      NotesCompanion(
        id: Value(note.id),
        userId: Value(note.userId),
        bookId: Value(note.bookId),
        chapterId: Value(note.chapterId),
        wordId: Value(note.wordId),
        content: Value(note.content),
        clientId: Value(note.clientId),
        isSynced: Value(note.isSynced),
        createdAt: Value(note.createdAt),
        updatedAt: Value(note.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updateNoteSyncStatus(String id, bool isSynced) async {
    final query = update(notes)..where((n) => n.id.equals(id));
    await query.write(NotesCompanion(
      isSynced: Value(isSynced),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteNote(String id) async {
    final query = delete(notes)..where((n) => n.id.equals(id));
    await query.go();
  }

  // Progress operations
  Future<ReadingProgressModel?> getProgress(String userId, String bookId) async {
    final query = select(readingProgress)
      ..where((p) => p.userId.equals(userId) & p.bookId.equals(bookId));
    final row = await query.getSingleOrNull();
    return row != null ? _progressFromRow(row) : null;
  }

  Future<List<ReadingProgressModel>> getAllProgress(String userId) async {
    final query = select(readingProgress)
      ..where((p) => p.userId.equals(userId))
      ..orderBy([(p) => OrderingTerm(expression: p.lastReadAt, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return rows.map((row) => _progressFromRow(row)).toList();
  }

  Future<void> insertProgress(ReadingProgressModel progress) async {
    await into(readingProgress).insert(
      ReadingProgressCompanion(
        id: Value(progress.id),
        userId: Value(progress.userId),
        bookId: Value(progress.bookId),
        chapterId: Value(progress.chapterId),
        wordId: Value(progress.wordId),
        positionSeconds: Value(progress.positionSeconds),
        progressPercent: Value(progress.progressPercent),
        totalReadingTimeSeconds: Value(progress.totalReadingTimeSeconds),
        sessionsCount: Value(progress.sessionsCount),
        lastReadAt: Value(progress.lastReadAt),
        lastSyncedAt: Value(progress.lastSyncedAt),
        deviceId: Value(progress.deviceId),
        createdAt: Value(progress.createdAt),
        updatedAt: Value(progress.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // Sync queue operations
  Future<List<SyncQueueData>> getPendingSyncItems(String userId) async {
    final query = select(syncQueue)..where((s) => s.userId.equals(userId));
    return await query.get();
  }

  Future<void> addToSyncQueue({
    required String userId,
    required String operation,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    await into(syncQueue).insert(
      SyncQueueCompanion(
        id: Value(const Uuid().v4()),
        userId: Value(userId),
        operation: Value(operation),
        entityType: Value(entityType),
        entityId: Value(entityId),
        dataJson: Value(_encodeJson(data)),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> removeFromSyncQueue(String id) async {
    final query = delete(syncQueue)..where((s) => s.id.equals(id));
    await query.go();
  }

  // Settings operations
  Future<UserSettingsModel?> getSettings(String userId) async {
    final query = select(appSettings)..where((s) => s.userId.equals(userId));
    final row = await query.getSingleOrNull();
    return row != null ? _settingsFromRow(row) : null;
  }

  Future<void> saveSettings(UserSettingsModel settings) async {
    await into(appSettings).insert(
      AppSettingsCompanion(
        id: Value(settings.id),
        userId: Value(settings.userId),
        fontSize: Value(settings.fontSize),
        lineHeight: Value(settings.lineHeight),
        theme: Value(settings.theme),
        fontFamily: Value(settings.fontFamily),
        playbackSpeed: Value(settings.playbackSpeed),
        autoScroll: Value(settings.autoScroll),
        highlightColor: Value(settings.highlightColor),
        autoPlayNextChapter: Value(settings.autoPlayNextChapter),
        autoSync: Value(settings.autoSync),
        syncOverWifiOnly: Value(settings.syncOverWifiOnly),
        interfaceLanguage: Value(settings.interfaceLanguage),
        contentLanguage: Value(settings.contentLanguage),
        createdAt: Value(settings.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // Helper methods
  BookModel _bookFromRow(Book row) => BookModel(
    id: row.id,
    title: row.title,
    subtitle: row.subtitle,
    author: row.author,
    description: row.description,
    coverUrl: row.coverUrl,
    language: row.language,
    duration: row.duration,
    wordCount: row.wordCount,
    status: row.status,
    isFeatured: row.isFeatured,
    drmEnabled: row.drmEnabled,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    isDownloaded: row.isDownloaded,
    isPurchased: row.isPurchased,
    progressPercent: row.progressPercent,
    lastReadAt: row.lastReadAt,
  );

  ChapterModel _chapterFromRow(Chapter row) => ChapterModel(
    id: row.id,
    bookId: row.bookId,
    title: row.title,
    orderIndex: row.orderIndex,
    paragraphs: (row.contentJson != null 
        ? List<Map<String, dynamic>>.from(_decodeJson(row.contentJson!))
        : [])
        .map((p) => ParagraphModel.fromJson(p))
        .toList(),
    syncData: row.syncDataJson != null
        ? List<Map<String, dynamic>>.from(_decodeJson(row.syncDataJson!))
            .map((s) => SyncWordModel.fromJson(s))
            .toList()
        : null,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  BookmarkModel _bookmarkFromRow(Bookmark row) => BookmarkModel(
    id: row.id,
    userId: row.userId,
    bookId: row.bookId,
    chapterId: row.chapterId,
    wordId: row.wordId,
    positionSeconds: row.positionSeconds,
    note: row.note,
    color: row.color,
    clientId: row.clientId,
    isSynced: row.isSynced,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  NoteModel _noteFromRow(Note row) => NoteModel(
    id: row.id,
    userId: row.userId,
    bookId: row.bookId,
    chapterId: row.chapterId,
    wordId: row.wordId,
    content: row.content,
    clientId: row.clientId,
    isSynced: row.isSynced,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  ReadingProgressModel _progressFromRow(ReadingProgressData row) => ReadingProgressModel(
    id: row.id,
    userId: row.userId,
    bookId: row.bookId,
    chapterId: row.chapterId,
    wordId: row.wordId,
    positionSeconds: row.positionSeconds,
    progressPercent: row.progressPercent,
    totalReadingTimeSeconds: row.totalReadingTimeSeconds,
    sessionsCount: row.sessionsCount,
    lastReadAt: row.lastReadAt,
    lastSyncedAt: row.lastSyncedAt,
    deviceId: row.deviceId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  UserSettingsModel _settingsFromRow(AppSetting row) => UserSettingsModel(
    id: row.id,
    userId: row.userId,
    fontSize: row.fontSize,
    lineHeight: row.lineHeight,
    theme: row.theme,
    fontFamily: row.fontFamily,
    playbackSpeed: row.playbackSpeed,
    autoScroll: row.autoScroll,
    highlightColor: row.highlightColor,
    autoPlayNextChapter: row.autoPlayNextChapter,
    autoSync: row.autoSync,
    syncOverWifiOnly: row.syncOverWifiOnly,
    interfaceLanguage: row.interfaceLanguage,
    contentLanguage: row.contentLanguage,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  String _encodeJson(dynamic data) => data.toString();
  dynamic _decodeJson(String json) => json;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.mainDatabase));
    return NativeDatabase(file);
  });
}
