/// One safely-sized piece of a chapter, handed to `TtsService.speak()` in a
/// single call.
///
/// Android's native TTS engine rejects any single `speak()` request beyond
/// `TextToSpeech.getMaxSpeechInputLength()` (documented as 4000 characters),
/// so a whole chapter — or one very long paragraph — cannot be sent at once.
///
/// [startOffset]/[endOffset] are in `ReaderChapterContent.fullText`'s offset
/// space, the same space word ranges use, so a word-boundary event reported
/// relative to a chunk can be rebased to a chapter-wide position by adding
/// `chunk.startOffset`.
class PlaybackChunk {
  const PlaybackChunk({
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });

  /// The exact text passed to `speak()` — always a real substring of the
  /// chapter's `fullText`, never rebuilt by joining pieces.
  final String text;

  /// Inclusive index into `fullText` where this chunk begins.
  final int startOffset;

  /// Exclusive index into `fullText` where this chunk ends.
  final int endOffset;
}
