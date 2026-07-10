import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../core/utils/constants.dart';
import '../../../data/datasources/local/hive_database.dart';
import '../../../data/models/download_info.dart';

class DownloadManager {
  final Dio _dio;

  DownloadManager({Dio? dio}) : _dio = dio ?? Dio();

  Future<void> downloadBook(String bookId) async {
    final downloadInfo = DownloadInfo(
      bookId: bookId,
      status: DownloadStatus.downloading,
    );
    await HiveDatabase.downloadsBox.put(bookId, downloadInfo);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final bookDir = '${appDir.path}/${AppConstants.booksDir}/$bookId';

      await Directory(bookDir).create(recursive: true);

      final url = '${AppConstants.cdnBaseUrl}/$bookId/package.zip';
      final zipPath = '$bookDir/package.zip';

      await _dio.download(
        url,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            downloadInfo.progress = progress;
            HiveDatabase.downloadsBox.put(bookId, downloadInfo);
          }
        },
      );

      downloadInfo.status = DownloadStatus.complete;
      downloadInfo.localPath = bookDir;
      downloadInfo.downloadedAt = DateTime.now();
      await HiveDatabase.downloadsBox.put(bookId, downloadInfo);
    } catch (e) {
      debugPrint('Download failed for $bookId: $e');
      downloadInfo.status = DownloadStatus.failed;
      await HiveDatabase.downloadsBox.put(bookId, downloadInfo);
    }
  }

  Future<void> removeBook(String bookId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final bookDir = Directory('${appDir.path}/${AppConstants.booksDir}/$bookId');
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
    await HiveDatabase.downloadsBox.delete(bookId);
  }

  bool isBookDownloaded(String bookId) {
    final info = HiveDatabase.downloadsBox.get(bookId);
    return info?.status == DownloadStatus.complete;
  }

  double getDownloadProgress(String bookId) {
    final info = HiveDatabase.downloadsBox.get(bookId);
    return info?.progress ?? 0.0;
  }

  List<String> getDownloadedBookIds() {
    return HiveDatabase.downloadsBox.values
        .where((d) => d.status == DownloadStatus.complete)
        .map((d) => d.bookId)
        .toList();
  }
}
