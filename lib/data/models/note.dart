import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

@HiveType(typeId: 5)
class Note extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String highlightId;

  @HiveField(2)
  String text;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  Note({
    String? id,
    required this.highlightId,
    required this.text,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}
