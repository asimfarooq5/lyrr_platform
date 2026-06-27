/// Cloud Synchronization Service
/// 
/// Handles bidirectional sync between local database and cloud API

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../core/config.dart';
import '../models/user_data_model.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'local_database.dart';

/// Sync status
enum SyncStatus {
  idle,
  syncing,
  error,
  offline,
}

/// Sync service
class SyncService {
  final LocalDatabase _db;
  final AuthService _authService;
  final ApiClient _apiClient;
  
  final _syncController = StreamController<SyncStatus>.broadcast();
  Timer? _syncTimer;
  SyncStatus _status = SyncStatus.idle;
  
  SyncService({
    required LocalDatabase db,
    required AuthService authService,
  })  : _db = db,
        _authService = authService,
        _apiClient = ApiClient(authService: authService);

  Stream<SyncStatus> get syncStream => _syncController.stream;
  SyncStatus get status => _status;

  /// Initialize sync service
  void initialize() {
    if (AppConfig.enableCloudSync) {
      _syncTimer = Timer.periodic(AppConfig.syncInterval, (_) => sync());
    }
  }

  /// Dispose sync service
  void dispose() {
    _syncTimer?.cancel();
    _syncController.close();
  }

  /// Perform bidirectional sync
  Future<bool> sync() async {
    if (_status == SyncStatus.syncing) return false;
    if (!_authService.isAuthenticated) return false;

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      _updateStatus(SyncStatus.offline);
      return false;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      final userId = _authService.currentUser!.id;
      
      // 1. Push local changes to server
      await _pushChanges(userId);
      
      // 2. Pull server changes
      await _pullChanges(userId);
      
      _updateStatus(SyncStatus.idle);
      return true;
    } catch (e) {
      _updateStatus(SyncStatus.error);
      return false;
    }
  }

  /// Push local changes to server
  Future<void> _pushChanges(String userId) async {
    // Get unsynced bookmarks
    final unsyncedBookmarks = await _db.getUnsyncedBookmarks(userId);
    final bookmarkItems = unsyncedBookmarks.map((b) => {
      'entity_type': 'bookmark',
      'operation': 'create',
      'client_entity_id': b.clientId ?? b.id,
      'server_entity_id': b.clientId == null ? b.id : null,
      'data': {
        'book_id': b.bookId,
        'chapter_id': b.chapterId,
        'word_id': b.wordId,
        'position_seconds': b.positionSeconds,
        'note': b.note,
        'color': b.color,
      },
      'client_timestamp': b.createdAt.toIso8601String(),
    }).toList();

    // Get unsynced notes
    final unsyncedNotes = await _db.getUnsyncedNotes(userId);
    final noteItems = unsyncedNotes.map((n) => {
      'entity_type': 'note',
      'operation': 'create',
      'client_entity_id': n.clientId ?? n.id,
      'server_entity_id': n.clientId == null ? n.id : null,
      'data': {
        'book_id': n.bookId,
        'chapter_id': n.chapterId,
        'word_id': n.wordId,
        'content': n.content,
      },
      'client_timestamp': n.createdAt.toIso8601String(),
    }).toList();

    // Get unsynced progress
    final allProgress = await _db.getAllProgress(userId);
    final unsyncedProgress = allProgress.where((p) => 
      p.lastSyncedAt == null || 
      (p.updatedAt != null && p.updatedAt!.isAfter(p.lastSyncedAt!))
    ).toList();
    
    final progressItems = unsyncedProgress.map((p) => {
      'entity_type': 'progress',
      'operation': 'update',
      'client_entity_id': p.id,
      'data': {
        'book_id': p.bookId,
        'chapter_id': p.chapterId,
        'word_id': p.wordId,
        'position_seconds': p.positionSeconds,
        'progress_percent': p.progressPercent,
        'total_reading_time_seconds': p.totalReadingTimeSeconds,
        'sessions_count': p.sessionsCount,
        'last_read_at': p.lastReadAt.toIso8601String(),
      },
      'client_timestamp': (p.updatedAt ?? p.createdAt).toIso8601String(),
    }).toList();

    // Combine all items
    final allItems = [...bookmarkItems, ...noteItems, ...progressItems];

    if (allItems.isEmpty) return;

    // Send to server
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.syncPush,
      body: {
        'items': allItems,
        'device_id': _authService.deviceId,
      },
    );

    if (response.success && response.data != null) {
      // Mark synced items
      final processed = response.data!['processed'] as List<dynamic>;
      
      for (final clientId in processed) {
        // Find and update bookmark
        final bookmark = unsyncedBookmarks.firstWhere(
          (b) => (b.clientId ?? b.id) == clientId,
          orElse: () => null as BookmarkModel,
        );
        if (bookmark != null) {
          await _db.updateBookmarkSyncStatus(bookmark.id, true);
        }

        // Find and update note
        final note = unsyncedNotes.firstWhere(
          (n) => (n.clientId ?? n.id) == clientId,
          orElse: () => null as NoteModel,
        );
        if (note != null) {
          await _db.updateNoteSyncStatus(note.id, true);
        }
      }

      // Handle conflicts
      final conflicts = response.data!['conflicts'] as List<dynamic>?;
      if (conflicts != null && conflicts.isNotEmpty) {
        // Store conflicts for resolution
        for (final conflict in conflicts) {
          await _db.addToSyncQueue(
            userId: userId,
            operation: 'conflict',
            entityType: conflict['entity_type'] ?? 'unknown',
            entityId: conflict['client_id'] ?? conflict['conflict_id'],
            data: conflict,
          );
        }
      }
    }
  }

  /// Pull server changes
  Future<void> _pullChanges(String userId) async {
    // Get last sync timestamp
    final checkpoint = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.syncCheckpoint,
    );

    final lastSyncAt = checkpoint.success && checkpoint.data != null
        ? DateTime.tryParse(checkpoint.data!['last_sync_at'] ?? '')
        : null;

    // Request changes since last sync
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.syncPull,
      queryParams: {
        'since': (lastSyncAt ?? DateTime(2000)).toIso8601String(),
      },
    );

    if (!response.success || response.data == null) return;

    final changes = response.data!['changes'] as List<dynamic>;

    for (final change in changes) {
      await _applyServerChange(userId, change as Map<String, dynamic>);
    }
  }

  /// Apply a server change locally
  Future<void> _applyServerChange(String userId, Map<String, dynamic> change) async {
    final entityType = change['entity_type'] as String;
    final operation = change['operation'] as String;
    final data = change['data'] as Map<String, dynamic>;

    switch (entityType) {
      case 'bookmark':
        if (operation == 'delete') {
          await _db.deleteBookmark(data['id']);
        } else {
          final bookmark = BookmarkModel(
            id: data['id'],
            userId: userId,
            bookId: data['book_id'],
            chapterId: data['chapter_id'],
            wordId: data['word_id'],
            positionSeconds: data['position_seconds']?.toDouble(),
            note: data['note'],
            color: data['color'] ?? '#FFD700',
            isSynced: true,
            createdAt: DateTime.parse(data['created_at']),
            updatedAt: data['updated_at'] != null 
                ? DateTime.parse(data['updated_at']) 
                : null,
          );
          await _db.insertBookmark(bookmark);
        }
        break;

      case 'note':
        if (operation == 'delete') {
          await _db.deleteNote(data['id']);
        } else {
          final note = NoteModel(
            id: data['id'],
            userId: userId,
            bookId: data['book_id'],
            chapterId: data['chapter_id'],
            wordId: data['word_id'],
            content: data['content'],
            isSynced: true,
            createdAt: DateTime.parse(data['created_at']),
            updatedAt: data['updated_at'] != null 
                ? DateTime.parse(data['updated_at']) 
                : null,
          );
          await _db.insertNote(note);
        }
        break;

      case 'progress':
        final progress = ReadingProgressModel(
          id: data['id'],
          userId: userId,
          bookId: data['book_id'],
          chapterId: data['chapter_id'],
          wordId: data['word_id'],
          positionSeconds: data['position_seconds']?.toDouble() ?? 0.0,
          progressPercent: data['progress_percent']?.toDouble() ?? 0.0,
          totalReadingTimeSeconds: data['total_reading_time_seconds'] ?? 0,
          sessionsCount: data['sessions_count'] ?? 0,
          lastReadAt: DateTime.parse(data['last_read_at']),
          lastSyncedAt: DateTime.now(),
          createdAt: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
        );
        await _db.insertProgress(progress);
        break;
    }
  }

  /// Create bookmark with sync
  Future<BookmarkModel> createBookmark({
    required String userId,
    required String bookId,
    required String wordId,
    String? chapterId,
    double? positionSeconds,
    String? note,
    String color = '#FFD700',
  }) async {
    final bookmark = BookmarkModel(
      id: const Uuid().v4(),
      userId: userId,
      bookId: bookId,
      chapterId: chapterId,
      wordId: wordId,
      positionSeconds: positionSeconds,
      note: note,
      color: color,
      clientId: const Uuid().v4(),
      isSynced: false,
      createdAt: DateTime.now(),
    );

    await _db.insertBookmark(bookmark);
    
    // Trigger immediate sync if online
    unawaited(sync());
    
    return bookmark;
  }

  /// Create note with sync
  Future<NoteModel> createNote({
    required String userId,
    required String bookId,
    required String wordId,
    required String content,
    String? chapterId,
  }) async {
    final note = NoteModel(
      id: const Uuid().v4(),
      userId: userId,
      bookId: bookId,
      chapterId: chapterId,
      wordId: wordId,
      content: content,
      clientId: const Uuid().v4(),
      isSynced: false,
      createdAt: DateTime.now(),
    );

    await _db.insertNote(note);
    
    unawaited(sync());
    
    return note;
  }

  /// Update progress with sync
  Future<void> updateProgress(ReadingProgressModel progress) async {
    final updated = progress.copyWith(
      updatedAt: DateTime.now(),
    );
    
    await _db.insertProgress(updated);
    
    // Don't sync immediately for progress - batch updates
  }

  void _updateStatus(SyncStatus status) {
    _status = status;
    _syncController.add(status);
  }
}

/// Helper to ignore await
void unawaited(Future<void> future) {}
