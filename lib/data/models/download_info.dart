import 'package:hive/hive.dart';

@HiveType(typeId: 7)
enum DownloadStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  downloading,
  @HiveField(2)
  complete,
  @HiveField(3)
  failed,
}

@HiveType(typeId: 8)
class DownloadInfo extends HiveObject {
  @HiveField(0)
  final String bookId;

  @HiveField(1)
  DownloadStatus status;

  @HiveField(2)
  double progress;

  @HiveField(3)
  String? localPath;

  @HiveField(4)
  DateTime? downloadedAt;

  DownloadInfo({
    required this.bookId,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.localPath,
    this.downloadedAt,
  });
}
