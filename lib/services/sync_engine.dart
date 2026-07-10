import '../models/sync_word.dart';
import '../utils/binary_search.dart';

class SyncEngine {
  final List<SyncWord> _syncWords;

  SyncEngine(this._syncWords);

  String? getActiveWordId(double positionInSeconds) {
    if (_syncWords.isEmpty) return null;
    final index = binarySearchSyncWord(_syncWords, positionInSeconds);
    if (index != -1) return _syncWords[index].id;
    return null;
  }

  List<SyncWord> get syncWords => _syncWords;
}
