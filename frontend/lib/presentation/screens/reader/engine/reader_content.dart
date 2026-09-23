/// Reader content index — one character-offset space per chapter.
///
/// Both reading modes resolve to the same thing: a global `[start, end)`
/// character range to highlight.
///   - audiobook mode maps an audio timestamp -> word id -> offset range
///   - TTS mode maps a native word-boundary offset -> offset range
///
/// Word IDs stay the backend key for bookmarks, notes and progress, so this
/// index is a pure client-side view over the existing chapter model.

import '../../../../data/models/book_model.dart';

/// A paragraph of the chapter, plus where it sits in [ReaderChapterContent.fullText].
class BookParagraph {
  final String text;
  final int startOffset;
  final int endOffset;

  const BookParagraph({
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });
}

/// One word's `[start, end)` range in [ReaderChapterContent.fullText],
/// carrying the backend word id so bookmarks/notes can still be addressed.
class ReaderWord {
  final String id;
  final int start;
  final int end;

  const ReaderWord({required this.id, required this.start, required this.end});

  bool overlaps(int rangeStart, int rangeEnd) =>
      rangeStart < end && rangeEnd > start;
}

/// One chapter flattened into a single string, with an index that converts
/// freely between global character offsets and backend word ids.
class ReaderChapterContent {
  final String chapterId;

  /// Paragraphs joined by a blank line — the exact string handed to TTS.
  final String fullText;

  final List<BookParagraph> paragraphs;

  /// Every word, ascending by [ReaderWord.start].
  final List<ReaderWord> words;

  ReaderChapterContent({
    required this.chapterId,
    required this.fullText,
    required this.paragraphs,
    required this.words,
  }) : _byId = {for (final w in words) w.id: w};

  final Map<String, ReaderWord> _byId;

  /// Builds the offset space from a chapter's word-level content.
  ///
  /// A word's range covers the word itself and never the space after it, so
  /// every offset in [fullText] belongs to at most one word.
  factory ReaderChapterContent.fromChapter(ChapterModel chapter) {
    final full = StringBuffer();
    final paragraphs = <BookParagraph>[];
    final words = <ReaderWord>[];

    for (var pi = 0; pi < chapter.paragraphs.length; pi++) {
      if (pi > 0) full.write('\n\n');

      final paragraph = chapter.paragraphs[pi];
      final paraBuf = StringBuffer();
      final local = <({String id, int start, int end})>[];

      for (var wi = 0; wi < paragraph.words.length; wi++) {
        if (wi > 0) paraBuf.write(' ');
        final word = paragraph.words[wi];
        final start = paraBuf.length;
        paraBuf.write(word.text);
        local.add((id: word.id, start: start, end: paraBuf.length));
      }

      final text = paraBuf.toString();
      final paraStart = full.length;
      full.write(text);

      for (final r in local) {
        words.add(ReaderWord(
          id: r.id,
          start: paraStart + r.start,
          end: paraStart + r.end,
        ));
      }

      paragraphs.add(BookParagraph(
        text: text,
        startOffset: paraStart,
        endOffset: paraStart + text.length,
      ));
    }

    return ReaderChapterContent(
      chapterId: chapter.id,
      fullText: full.toString(),
      paragraphs: paragraphs,
      words: words,
    );
  }

  int get length => fullText.length;

  bool get isEmpty => fullText.isEmpty;

  /// The word containing [offset], or the nearest preceding one when the
  /// offset lands on whitespace/punctuation (a stuck highlight is a minor
  /// glitch; throwing mid-playback is not).
  ReaderWord? wordAtOffset(int offset) {
    if (words.isEmpty) return null;

    var low = 0;
    var high = words.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final word = words[mid];
      if (offset < word.start) {
        high = mid - 1;
      } else if (offset >= word.end) {
        low = mid + 1;
      } else {
        return word;
      }
    }

    return words[low.clamp(0, words.length - 1)];
  }

  ReaderWord? wordById(String? id) => id == null ? null : _byId[id];

  /// The paragraph containing [offset], or null when the chapter is empty.
  BookParagraph? paragraphAtOffset(int offset) {
    if (paragraphs.isEmpty) return null;
    for (final paragraph in paragraphs) {
      if (offset >= paragraph.startOffset && offset < paragraph.endOffset) {
        return paragraph;
      }
    }
    return paragraphs.last;
  }
}
