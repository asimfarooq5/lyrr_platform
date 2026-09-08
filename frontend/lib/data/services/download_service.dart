/// Offline Download Service (FRS §9 - Offline Mode)
///
/// Downloads a book's text (chapters) and audio to local storage so it can
/// be read/listened to without a network connection. Text goes into the
/// local Drift database (already synced/read offline); audio is streamed to
/// a file under the app's documents directory.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config.dart';
import '../models/book_model.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'drm_service.dart';
import 'local_database.dart';

enum DownloadState { notDownloaded, downloading, downloaded, failed }

class DownloadProgress {
  final DownloadState state;
  final double progress; // 0.0 - 1.0
  final String? error;

  const DownloadProgress({required this.state, this.progress = 0.0, this.error});
}

class DownloadService {
  final LocalDatabase _db;
  final AuthService _authService;
  final ApiClient _apiClient;
  final DRMService _drmService;

  final _controllers = <String, StreamController<DownloadProgress>>{};

  DownloadService({
    required LocalDatabase db,
    required AuthService authService,
  })  : _db = db,
        _authService = authService,
        _apiClient = ApiClient(authService: authService),
        _drmService = DRMService(authService: authService);

  Stream<DownloadProgress> progressStream(String bookId) {
    return _controllers
        .putIfAbsent(bookId, () => StreamController<DownloadProgress>.broadcast())
        .stream;
  }

  void _emit(String bookId, DownloadProgress progress) {
    _controllers.putIfAbsent(bookId, () => StreamController<DownloadProgress>.broadcast())
        .add(progress);
  }

  /// Offline downloads need a real filesystem (dart:io File/Directory),
  /// which browsers don't expose - kIsWeb is checked everywhere this
  /// service touches disk so a web build fails fast with a clear message
  /// instead of a raw "Unsupported operation" from dart:io.
  static const _webUnsupportedMessage =
      'Downloads for offline reading are only available in the mobile and desktop app, not in the browser.';

  Future<bool> isDownloaded(String bookId) async {
    if (kIsWeb) return false;
    final path = await _db.getLocalAudioPath(bookId);
    if (path == null) return false;
    return File(path).exists();
  }

  Future<String> _audioDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, 'lyrr_audio'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Download a book's chapters (text) and audio for offline access.
  Future<void> downloadBook(BookModel book) async {
    final bookId = book.id;
    if (kIsWeb) {
      _emit(bookId, const DownloadProgress(state: DownloadState.failed, error: _webUnsupportedMessage));
      throw Exception(_webUnsupportedMessage);
    }
    _emit(bookId, const DownloadProgress(state: DownloadState.downloading, progress: 0.0));

    try {
      // 0. The book itself must exist locally first - chapters reference it
      // by id, and updateBookDownloadStatus/getLocalAudioPath below only
      // work if this row exists (books opened from the Store/Library come
      // from the server API, not local SQLite, so this row is often new).
      await _db.insertBook(book);

      // 1. Text content -> local DB (drives offline reading)
      final contentResponse = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.bookContent(bookId),
      );
      if (contentResponse.success && contentResponse.data != null) {
        final chapters = (contentResponse.data!['chapters'] as List? ?? [])
            .map((c) => ChapterModel.fromJson(c as Map<String, dynamic>))
            .toList();
        for (final chapter in chapters) {
          await _db.insertChapter(chapter);
        }
      }
      _emit(bookId, const DownloadProgress(state: DownloadState.downloading, progress: 0.3));

      // 2. DRM license -> audio URL
      final license = await _drmService.getLicense(bookId);
      String? localAudioPath;
      if (license?.downloadUrl != null) {
        localAudioPath = await _downloadAudio(bookId, license!.downloadUrl!, (p) {
          _emit(bookId, DownloadProgress(state: DownloadState.downloading, progress: 0.3 + p * 0.7));
        });
      }

      await _db.updateBookDownloadStatus(bookId, true, localAudioPath: localAudioPath);

      // Best-effort: tell the server this device has an offline copy.
      try {
        await _apiClient.post(ApiEndpoints.bookDownload(bookId));
      } catch (_) {
        // Non-fatal — offline copy already saved locally.
      }

      _emit(bookId, const DownloadProgress(state: DownloadState.downloaded, progress: 1.0));
    } catch (e) {
      _emit(bookId, DownloadProgress(state: DownloadState.failed, error: e.toString()));
      rethrow;
    }
  }

  Future<String> _downloadAudio(
    String bookId,
    String url,
    void Function(double progress) onProgress,
  ) async {
    final token = await _authService.getAccessToken();
    final request = http.Request('GET', Uri.parse(url));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Failed to download audio (HTTP ${response.statusCode})');
      }

      final ext = p.extension(Uri.parse(url).path);
      final audioDir = await _audioDir();
      final filePath = p.join(audioDir, '$bookId${ext.isEmpty ? '.mp3' : ext}');
      final tmpPath = '$filePath.part';
      final file = File(tmpPath);
      final sink = file.openWrite();

      final total = response.contentLength ?? 0;
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
      await file.rename(filePath);
      return filePath;
    } finally {
      client.close();
    }
  }

  /// Remove a downloaded book's local audio (text stays cached for reading).
  Future<void> deleteDownload(String bookId) async {
    if (kIsWeb) return;
    final path = await _db.getLocalAudioPath(bookId);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _db.updateBookDownloadStatus(bookId, false, localAudioPath: '');
    _emit(bookId, const DownloadProgress(state: DownloadState.notDownloaded, progress: 0.0));
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }
}
