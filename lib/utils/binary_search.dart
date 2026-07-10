import '../models/sync_word.dart';

int binarySearchSyncWord(List<SyncWord> syncWords, double position) {
  int low = 0;
  int high = syncWords.length - 1;

  while (low <= high) {
    final mid = (low + high) >> 1;
    final word = syncWords[mid];

    if (position >= word.start && position < word.end) {
      return mid;
    } else if (position < word.start) {
      high = mid - 1;
    } else {
      low = mid + 1;
    }
  }
  return -1;
}
