class SyncWord {
  final String id;
  final double start;
  final double end;

  SyncWord({
    required this.id,
    required this.start,
    required this.end,
  });

  factory SyncWord.fromJson(Map<String, dynamic> json) {
    return SyncWord(
      id: json['id'] as String,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start': start,
      'end': end,
    };
  }

  bool contains(double positionInSeconds) {
    return positionInSeconds >= start && positionInSeconds < end;
  }
}
