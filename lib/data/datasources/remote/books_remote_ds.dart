import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/constants.dart';
import '../../../models/metadata.dart';

class BooksRemoteDataSource {
  final Dio _dio;

  BooksRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<BookMetadata>> fetchCatalog() async {
    try {
      final response = await _dio.get(
        '${AppConstants.cdnBaseUrl}/catalog.json',
      );
      final list = response.data as List;
      return list
          .map((e) => BookMetadata.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch catalog: $e');
      return [];
    }
  }

  String getBookPackageUrl(String bookId) =>
      '${AppConstants.cdnBaseUrl}/$bookId/package.zip';

  String getCoverUrl(String bookId, String cover) =>
      '${AppConstants.cdnBaseUrl}/$bookId/$cover';
}
