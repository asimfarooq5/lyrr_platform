/// Splits a chapter's text into chunks small enough for Android's native TTS
/// engine to accept in one `speak()` call.
///
/// Pure Dart — no I/O, no platform channel — so it is trivially unit-testable.

import 'playback_chunk.dart';
import 'reader_content.dart';

class PlaybackChunker {
  const PlaybackChunker({this.maxChunkLength = defaultMaxChunkLength});

  /// Half of Android's documented 4000-character `speak()` ceiling. The
  /// headroom covers OEM engines that enforce a stricter real-world limit,
  /// while keeping the pause between chunks short.
  static const int defaultMaxChunkLength = 2000;

  final int maxChunkLength;

  /// Builds the full chunk list for [content], in playback order.
  ///
  /// Called once per chapter, when its content finishes loading — never on
  /// each Play press. Recomputing would risk `_currentChunkIndex` (an index
  /// into this list) silently pointing at different text mid-sentence.
  List<PlaybackChunk> chunk(ReaderChapterContent content) {
    final pieces = <({int start, int end})>[];

    for (final paragraph in content.paragraphs) {
      if (paragraph.text.length <= maxChunkLength) {
        pieces.add((start: paragraph.startOffset, end: paragraph.endOffset));
      } else {
        pieces.addAll(_splitOversizedParagraph(paragraph));
      }
    }

    // Greedily pack consecutive pieces so short paragraphs don't each become
    // their own `speak()` call — that sounds choppy and multiplies engine
    // round-trips for no benefit.
    final chunks = <PlaybackChunk>[];
    int? packedStart;
    var packedEnd = 0;

    void flush() {
      final start = packedStart;
      if (start == null) return;
      chunks.add(PlaybackChunk(
        text: content.fullText.substring(start, packedEnd),
        startOffset: start,
        endOffset: packedEnd,
      ));
      packedStart = null;
    }

    for (final piece in pieces) {
      if (piece.end <= piece.start) continue;

      final fits = packedStart != null &&
          (piece.end - packedStart!) <= maxChunkLength;

      if (fits) {
        packedEnd = piece.end;
      } else {
        flush();
        packedStart = piece.start;
        packedEnd = piece.end;
      }
    }
    flush();

    return chunks;
  }

  /// Splits one oversized paragraph on sentence boundaries first, falling
  /// back to whitespace-safe hard splits only for a pathologically long
  /// sentence with no punctuation.
  List<({int start, int end})> _splitOversizedParagraph(BookParagraph paragraph) {
    final text = paragraph.text;
    final base = paragraph.startOffset;
    final result = <({int start, int end})>[];

    for (final sentence in _sentenceRanges(text)) {
      if (sentence.end - sentence.start <= maxChunkLength) {
        result.add((start: base + sentence.start, end: base + sentence.end));
      } else {
        for (final piece in _hardSplit(text, sentence.start, sentence.end)) {
          result.add((start: base + piece.start, end: base + piece.end));
        }
      }
    }

    return result;
  }

  /// Cuts AFTER sentence-ending punctuation and the whitespace that follows it,
  /// so a split can never land mid-word.
  ///
  /// Each range ends at the match's END — i.e. it keeps the inter-sentence
  /// whitespace — and the next range begins there. That contiguity matters:
  /// the chunks built from these ranges must tile the full text with no gaps,
  /// or joining them back together would silently drop characters at every
  /// split, and offsets near a boundary would no longer line up with the
  /// words they refer to.
  List<({int start, int end})> _sentenceRanges(String text) {
    final boundary = RegExp(r'(?<=[.!?])\s+');
    final ranges = <({int start, int end})>[];
    var start = 0;

    for (final match in boundary.allMatches(text)) {
      if (match.start > start) {
        ranges.add((start: start, end: match.end));
      }
      start = match.end;
    }
    if (start < text.length) {
      ranges.add((start: start, end: text.length));
    }

    return ranges;
  }

  List<({int start, int end})> _hardSplit(String text, int start, int end) {
    final ranges = <({int start, int end})>[];
    var cursor = start;

    while (end - cursor > maxChunkLength) {
      final splitAt = _findSplitIndex(text, cursor, cursor + maxChunkLength);
      // Keep the whitespace with the piece BEFORE it so the next piece does
      // not begin with a stray space — but only when that still fits inside
      // the limit, since the split index can sit exactly on the boundary.
      final pieceEnd =
          (splitAt + 1 - cursor <= maxChunkLength) ? splitAt + 1 : splitAt;
      if (pieceEnd <= cursor) break; // defensive: never emit an empty range
      ranges.add((start: cursor, end: pieceEnd));
      cursor = pieceEnd;
    }

    if (cursor < end) {
      ranges.add((start: cursor, end: end));
    }

    return ranges;
  }

  /// Searches backward for the nearest whitespace so the split never lands
  /// inside a word, falling back to [desiredIndex] only when no whitespace
  /// exists in the whole span (expected never to happen in a real book).
  int _findSplitIndex(String text, int cursor, int desiredIndex) {
    for (var i = desiredIndex; i > cursor; i--) {
      if (_isWhitespace(text.codeUnitAt(i))) {
        return _avoidSurrogateSplit(text, i);
      }
    }
    return _avoidSurrogateSplit(text, desiredIndex);
  }

  bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0xA0;

  /// Dart strings are UTF-16; an arbitrary cut could land between the two
  /// halves of a surrogate pair and corrupt the character. Nudge left in
  /// that one case.
  int _avoidSurrogateSplit(String text, int index) {
    if (index <= 0 || index >= text.length) return index;
    final unit = text.codeUnitAt(index);
    final isLowSurrogate = unit >= 0xDC00 && unit <= 0xDFFF;
    return isLowSurrogate ? index - 1 : index;
  }
}
