import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

@HiveType(typeId: 3)
class Highlight extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final String chapterId;

  @HiveField(3)
  final int paragraphIndex;

  @HiveField(4)
  final int startWordIndex;

  @HiveField(5)
  final int endWordIndex;

  @HiveField(6)
  final String selectedText;

  @HiveField(7)
  final String color;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final String? noteId;

  @HiveField(10)
  final List<String> wordIds;

  Highlight({
    String? id,
    required this.bookId,
    required this.chapterId,
    required this.paragraphIndex,
    required this.startWordIndex,
    required this.endWordIndex,
    required this.selectedText,
    required this.color,
    DateTime? createdAt,
    this.noteId,
    required this.wordIds,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}

const List<String> highlightColors = [
  'yellow',
  'green',
  'blue',
  'pink',
  'orange',
];

const Map<String, Color> highlightColorValues = {
  'yellow': Color(0xFFFFF176),
  'green': Color(0xFFA5D6A7),
  'blue': Color(0xFF90CAF9),
  'pink': Color(0xFFF48FB1),
  'orange': Color(0xFFFFCC80),
};
