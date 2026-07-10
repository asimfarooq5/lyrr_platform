import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/metadata.dart';
import '../models/chapter.dart';
import '../models/sync_word.dart';

class AssetLoader {
  Future<BookMetadata> loadMetadata(String path) async {
    final data = await rootBundle.loadString(path);
    final jsonMap = json.decode(data) as Map<String, dynamic>;
    return BookMetadata.fromJson(jsonMap);
  }

  Future<List<Chapter>> loadText(String path) async {
    final data = await rootBundle.loadString(path);
    final jsonMap = json.decode(data) as Map<String, dynamic>;
    final chaptersList = jsonMap['chapters'] as List;
    return chaptersList.map((c) => Chapter.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<List<SyncWord>> loadSync(String path) async {
    final data = await rootBundle.loadString(path);
    final jsonList = json.decode(data) as List;
    return jsonList.map((s) => SyncWord.fromJson(s as Map<String, dynamic>)).toList();
  }
}
