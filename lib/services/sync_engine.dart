import '../models/sync_word.dart';
import '../utils/binary_search.dart' show binarySearchSyncWord;
import '../core/utils/timestamp_smoother.dart';

class SyncEngine {
  final List<SyncWord> _syncWords;
  final TimestampSmoother _smoother;

  SyncEngine(this._syncWords, {TimestampSmoother? smoother})
      : _smoother = smoother ?? TimestampSmoother();

  String? getActiveWordId(double positionInSeconds) {
    if (_syncWords.isEmpty) return null;
    final index = binarySearchSyncWord(_syncWords, positionInSeconds);
    final rawId = index != -1 ? _syncWords[index].id : null;
    return _smoother.smooth(rawId);
  }

  /// Direct lookup without smoothing (for seeking)
  String? getWordIdAt(double positionInSeconds) {
    if (_syncWords.isEmpty) return null;
    final index = binarySearchSyncWord(_syncWords, positionInSeconds);
    return index != -1 ? _syncWords[index].id : null;
  }

  List<SyncWord> get syncWords => _syncWords;
  void resetSmoother() => _smoother.reset();
}
