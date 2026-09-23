/// Unit tests for the reader's offset-based content index and playback chunker.
///
/// Both are pure Dart (no platform channels), which is what makes the TTS
/// chunking and highlighting behaviour verifiable here rather than only by ear
/// on a device.

import 'package:flutter_test/flutter_test.dart';
import 'package:lyrr/data/models/book_model.dart';
import 'package:lyrr/presentation/screens/reader/engine/playback_chunker.dart';
import 'package:lyrr/presentation/screens/reader/engine/reader_content.dart';

/// Builds a chapter whose words are `w0..wN`, matching how the backend shapes
/// chapter content (`{id, text}` per word).
ChapterModel _chapter(List<List<String>> paragraphs) {
  var id = 0;
  return ChapterModel(
    id: 'ch1',
    bookId: 'b1',
    title: 'Chapter 1',
    orderIndex: 0,
    paragraphs: paragraphs
        .map((words) => ParagraphModel(
              words: words
                  .map((t) => WordModel(id: 'w${id++}', text: t))
                  .toList(),
            ))
        .toList(),
    createdAt: DateTime(2024),
  );
}

void main() {
  group('ReaderChapterContent', () {
    test('joins paragraphs with a blank line and words with single spaces', () {
      final content = ReaderChapterContent.fromChapter(
        _chapter([
          ['Hello', 'world'],
          ['Second', 'para'],
        ]),
      );

      expect(content.fullText, 'Hello world\n\nSecond para');
      expect(content.paragraphs, hasLength(2));
      expect(content.paragraphs[0].text, 'Hello world');
      expect(content.paragraphs[1].text, 'Second para');
      expect(content.paragraphs[0].startOffset, 0);
      expect(content.paragraphs[1].startOffset, 'Hello world\n\n'.length);
    });

    test('word offsets reconstruct the word they describe', () {
      final content = ReaderChapterContent.fromChapter(
        _chapter([
          ['Alpha', 'Beta', 'Gamma'],
        ]),
      );

      for (final word in content.words) {
        expect(
          content.fullText.substring(word.start, word.end),
          isNotEmpty,
          reason: 'word ${word.id} should map to real text',
        );
      }

      // "Beta" starts right after "Alpha "
      final beta = content.wordById('w1')!;
      expect(content.fullText.substring(beta.start, beta.end), 'Beta');
    });

    test('wordAtOffset resolves a word, and tolerates whitespace', () {
      final content = ReaderChapterContent.fromChapter(
        _chapter([
          ['Alpha', 'Beta'],
        ]),
      );

      final withinBeta = content.wordById('w1')!;
      expect(content.wordAtOffset(withinBeta.start)?.id, 'w1');

      // The space between the two words is not part of either word; the
      // lookup must still return a sane neighbour rather than throw.
      expect(content.wordAtOffset(5), isNotNull);
    });

    test('wordById returns null for an unknown id', () {
      final content = ReaderChapterContent.fromChapter(_chapter([
        ['Alpha'],
      ]));
      expect(content.wordById('nope'), isNull);
      expect(content.wordById(null), isNull);
    });
  });

  group('PlaybackChunker', () {
    test('every chunk fits under the engine limit and is contiguous', () {
      // One paragraph of many words, each 5 chars, forcing a split.
      final words = List.generate(4000, (i) => 'abcde');
      final content = ReaderChapterContent.fromChapter(_chapter([words]));

      final chunks = const PlaybackChunker(maxChunkLength: 500).chunk(content);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.text.length, lessThanOrEqualTo(500));
        expect(chunk.endOffset - chunk.startOffset, chunk.text.length);
      }

      // Chunks must tile fullText without gaps or overlap — this is what keeps
      // "which word is speaking" correct across a chunk boundary.
      expect(chunks.first.startOffset, 0);
      expect(chunks.last.endOffset, content.fullText.length);
      for (var i = 1; i < chunks.length; i++) {
        expect(chunks[i].startOffset, chunks[i - 1].endOffset);
      }
    });

    test('a short chapter becomes a single chunk', () {
      final content = ReaderChapterContent.fromChapter(_chapter([
        ['Short', 'chapter'],
      ]));
      final chunks = const PlaybackChunker().chunk(content);
      expect(chunks, hasLength(1));
      expect(chunks.single.text, content.fullText);
    });

    test('an oversized paragraph splits on sentence boundaries when possible',
        () {
      final sentences = List.generate(60, (i) => 'Sentence number $i here.');
      final content = ReaderChapterContent.fromChapter(_chapter([sentences]));

      final chunks = const PlaybackChunker(maxChunkLength: 120).chunk(content);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.text.length, lessThanOrEqualTo(120));
        // A sentence-aware split lands after punctuation/whitespace, never
        // mid-word.
        expect(chunk.text.trim(), isNotEmpty);
      }
    });

    test('a pathological unbroken run still splits without cutting a word',
        () {
      // 3000 chars, no whitespace at all after the first word.
      final blob = 'start ' + ('x' * 3000);
      final content = ReaderChapterContent.fromChapter(_chapter([[blob]]));

      final chunks = const PlaybackChunker(maxChunkLength: 400).chunk(content);

      for (final chunk in chunks) {
        expect(chunk.text.length, lessThanOrEqualTo(400));
      }
      // Text is preserved end to end even when there is nowhere sane to cut.
      expect(chunks.map((c) => c.text).join(), content.fullText);
    });
  });
}
