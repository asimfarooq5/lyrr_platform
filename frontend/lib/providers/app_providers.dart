/// Application Providers
/// 
/// Riverpod providers for dependency injection and state management

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/auth_service.dart';
import '../data/services/local_database.dart';
import '../data/services/sync_service.dart';
import '../data/services/drm_service.dart';
import '../data/services/api_client.dart';

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main.dart');
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthService(prefs: prefs);
});

/// Auth state provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.syncStream.map((_) => authService.state);
});

/// Current user provider
final currentUserProvider = Provider((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});

/// Local database provider
final databaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});

/// API client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ApiClient(authService: authService);
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final authService = ref.watch(authServiceProvider);
  
  final service = SyncService(
    db: db,
    authService: authService,
  );
  
  service.initialize();
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// DRM service provider
final drmServiceProvider = Provider<DRMService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return DRMService(authService: authService);
});

/// Sync status provider
final syncStatusProvider = StreamProvider((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.syncStream;
});

/// Books repository provider
final booksRepositoryProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final db = ref.watch(databaseProvider);
  return BooksRepository(apiClient: apiClient, db: db);
});

/// User data repository provider
final userDataRepositoryProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final db = ref.watch(databaseProvider);
  final syncService = ref.watch(syncServiceProvider);
  return UserDataRepository(
    apiClient: apiClient,
    db: db,
    syncService: syncService,
  );
});

/// Books repository
class BooksRepository {
  final ApiClient apiClient;
  final LocalDatabase db;

  BooksRepository({required this.apiClient, required this.db});

  Future<List<dynamic>> getBooks({String? search, String? language}) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.books,
      queryParams: {
        if (search != null) 'search': search,
        if (language != null) 'language': language,
      },
    );

    if (response.success && response.data != null) {
      return response.data!['items'] as List<dynamic>;
    }

    return [];
  }

  Future<Map<String, dynamic>?> getBook(String bookId) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.book(bookId),
    );

    if (response.success) {
      return response.data;
    }

    return null;
  }

  Future<List<dynamic>> getBookContent(String bookId) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.bookContent(bookId),
    );

    if (response.success && response.data != null) {
      return response.data!['chapters'] as List<dynamic>;
    }

    return [];
  }

  Future<List<dynamic>> getBookSync(String bookId) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.bookSync(bookId),
    );

    if (response.success && response.data != null) {
      return response.data!['sync_data'] as List<dynamic>;
    }

    return [];
  }

  Future<void> purchaseBook(String bookId) async {
    await apiClient.post(ApiEndpoints.bookPurchase(bookId));
  }

  Future<void> downloadBook(String bookId) async {
    await apiClient.post(ApiEndpoints.bookDownload(bookId));
  }
}

/// User data repository
class UserDataRepository {
  final ApiClient apiClient;
  final LocalDatabase db;
  final SyncService syncService;

  UserDataRepository({
    required this.apiClient,
    required this.db,
    required this.syncService,
  });

  Future<List<dynamic>> getLibrary() async {
    final response = await apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.library,
    );

    if (response.success && response.data != null) {
      return response.data!['items'] as List<dynamic>;
    }

    return [];
  }

  Future<List<dynamic>> getBookmarks(String bookId) async {
    final response = await apiClient.get<List<dynamic>>(
      ApiEndpoints.bookmarks,
      queryParams: {'book_id': bookId},
    );

    if (response.success) {
      return response.data ?? [];
    }

    return [];
  }

  Future<Map<String, dynamic>> createBookmark({
    required String bookId,
    required String wordId,
    String? chapterId,
    double? positionSeconds,
    String? note,
    String color = '#FFD700',
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.bookmarks,
      body: {
        'book_id': bookId,
        'word_id': wordId,
        'chapter_id': chapterId,
        'position_seconds': positionSeconds,
        'note': note,
        'color': color,
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    }

    throw Exception('Failed to create bookmark');
  }

  Future<List<dynamic>> getNotes(String bookId) async {
    final response = await apiClient.get<List<dynamic>>(
      ApiEndpoints.notes,
      queryParams: {'book_id': bookId},
    );

    if (response.success) {
      return response.data ?? [];
    }

    return [];
  }

  Future<Map<String, dynamic>> createNote({
    required String bookId,
    required String wordId,
    required String content,
    String? chapterId,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.notes,
      body: {
        'book_id': bookId,
        'word_id': wordId,
        'chapter_id': chapterId,
        'content': content,
      },
    );

    if (response.success && response.data != null) {
      return response.data!;
    }

    throw Exception('Failed to create note');
  }

  Future<Map<String, dynamic>?> getProgress(String bookId) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.bookProgress(bookId),
    );

    if (response.success) {
      return response.data;
    }

    return null;
  }

  Future<void> updateProgress({
    required String bookId,
    String? chapterId,
    String? wordId,
    required double positionSeconds,
    required double progressPercent,
  }) async {
    await apiClient.post(
      ApiEndpoints.progress,
      body: {
        'book_id': bookId,
        'chapter_id': chapterId,
        'word_id': wordId,
        'position_seconds': positionSeconds,
        'progress_percent': progressPercent,
      },
    );
  }

  Future<Map<String, dynamic>?> getStats() async {
    final response = await apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.stats,
    );

    if (response.success) {
      return response.data;
    }

    return null;
  }
}
