/// Owns the reader's playback state: the offset index for the open chapter,
/// the precomputed TTS chunks, which chunk is speaking, the currently
/// highlighted range, and how far into the chapter the reader is.
///
/// It is a plain `ChangeNotifier`, so the screen can subscribe with Flutter's
/// built-in `ListenableBuilder` — no extra state-management package.
///
/// Two modes share one highlight channel (a chapter-wide character range):
///   - [audiobook] — the screen feeds `just_audio` positions in via
///     [onAudioPosition]; they are mapped through the sync table to a word.
///   - TTS — [play] speaks the precomputed chunks and native word-boundary
///     events drive the same range.
///
/// Presentation calls only methods on this class and reads its getters; it
/// never touches `TtsService` or `flutter_tts` directly.

import 'package:flutter/foundation.dart';

import 'playback_chunk.dart';
import 'playback_chunker.dart';
import 'reader_content.dart';
import 'tts_playback_state.dart';
import 'tts_service.dart';

/// One word's timing from the backend's audio sync table.
class AudioSyncEntry {
  final String id;
  final double start;
  final double end;

  const AudioSyncEntry({required this.id, required this.start, required this.end});

  bool contains(double seconds) => seconds >= start && seconds < end;
}

class ReaderPlaybackController extends ChangeNotifier {
  ReaderPlaybackController({
    TtsService? ttsService,
    PlaybackChunker? chunker,
    this.language = TtsService.defaultLanguage,
  })  : _ttsService = ttsService ?? TtsService(),
        _chunker = chunker ?? const PlaybackChunker() {
    _ttsService.attachHandlers(
      onStart: () => _setPlaybackState(TtsPlaybackState.playing),
      onContinue: () => _setPlaybackState(TtsPlaybackState.playing),
      onPause: () => _setPlaybackState(TtsPlaybackState.paused),
      onCompletion: _handleChunkCompletion,
      onCancel: () => _setPlaybackState(TtsPlaybackState.stopped),
      onError: _handleTtsError,
      onProgress: _handleProgress,
    );
  }

  final TtsService _ttsService;
  final PlaybackChunker _chunker;

  /// BCP-47 tag used when configuring the engine.
  String language;

  /// Set by the screen when TTS playback reaches the end of the chapter, so
  /// the screen can advance to the next one.
  VoidCallback? onChapterFinished;

  bool _disposed = false;

  // --- Content ---------------------------------------------------------

  ReaderChapterContent? _content;
  ReaderChapterContent? get content => _content;

  bool _audiobook = false;
  bool get isAudiobook => _audiobook;

  List<AudioSyncEntry> _audioSync = const [];

  /// The chapter's chunks, computed once per [setContent] — never per Play
  /// press, so `_currentChunkIndex` always indexes the same list.
  List<PlaybackChunk> _chunks = const [];

  /// Swaps in a new chapter. Resets everything position-related.
  void setContent(ReaderChapterContent content, {required bool audiobook}) {
    _content = content;
    _audiobook = audiobook;
    _chunks = content.isEmpty ? const [] : _chunker.chunk(content);
    _currentChunkIndex = 0;
    _highlightRange = null;
    _lastKnownOffset = 0;
    _pendingResumeLocalOffset = null;
    _seekStartGlobalRange = null;
    _chunkProgressBase = 0;
    _lastChunkLocalOffset = null;
    _notify();
  }

  void setAudioSync(List<AudioSyncEntry> entries) {
    _audioSync = entries;
  }

  // --- TTS availability ------------------------------------------------

  bool _isTtsReady = false;
  bool get isTtsReady => _isTtsReady;

  String? _ttsUnavailableReason;
  String? get ttsUnavailableReason => _ttsUnavailableReason;

  /// True only while initialization is still in flight, so the UI can show a
  /// spinner instead of a control bar that pops in a beat late.
  bool get isTtsInitializing => !_isTtsReady && _ttsUnavailableReason == null;

  String? _ttsErrorMessage;
  String? get ttsErrorMessage => _ttsErrorMessage;

  void clearTtsError() {
    if (_ttsErrorMessage == null) return;
    _ttsErrorMessage = null;
    _notify();
  }

  Future<void> initializeTts() async {
    final result = await _ttsService.initialize(language: language);
    switch (result) {
      case TtsInitSuccess():
        _isTtsReady = true;
        _ttsUnavailableReason = null;
        await _ttsService.setSpeechRate(_speechRate);
        await _ttsService.setPitch(_pitch);
        await _ttsService.setVolume(_volume);
      case TtsInitUnavailable():
        _isTtsReady = false;
        _ttsUnavailableReason = 'Text-to-speech is not available on this device.';
      case TtsInitUnsupportedLanguage(:final languageCode):
        _isTtsReady = false;
        _ttsUnavailableReason =
            'Text-to-speech is not installed for $languageCode.';
      case TtsInitFailure():
        _isTtsReady = false;
        _ttsUnavailableReason = 'Text-to-speech could not be started.';
    }
    _notify();
  }

  // --- Playback state ---------------------------------------------------

  TtsPlaybackState _playbackState = TtsPlaybackState.stopped;
  TtsPlaybackState get playbackState => _playbackState;
  bool get isPlaying => _playbackState == TtsPlaybackState.playing;
  bool get isPaused => _playbackState == TtsPlaybackState.paused;

  // --- Highlight / position --------------------------------------------

  /// The range currently highlighted, in chapter-wide offsets. `null` when
  /// nothing is being tracked.
  ({int start, int end})? _highlightRange;
  ({int start, int end})? get highlightRange => _highlightRange;

  /// A stable "how far the reader is" offset. Unlike [highlightRange] it is
  /// never cleared by [stop], so progress survives a settings change.
  int _lastKnownOffset = 0;
  int get currentOffset => _lastKnownOffset;

  double get progressFraction {
    final length = _content?.length ?? 0;
    return length == 0 ? 0 : _lastKnownOffset / length;
  }

  /// The backend word id under the current position, for bookmark / note /
  /// progress persistence.
  String? get currentWordId => _content?.wordAtOffset(_lastKnownOffset)?.id;

  /// Sets the reading position without speaking — used to restore saved
  /// progress before the first Play.
  void seekToOffset(int offset) {
    final content = _content;
    if (content == null || content.length == 0) return;
    final clamped = offset.clamp(0, content.length - 1);
    _lastKnownOffset = clamped;
    final word = content.wordAtOffset(clamped);
    if (word != null) {
      _highlightRange = (start: word.start, end: word.end);
      _pendingResumeLocalOffset = null;
      _currentChunkIndex = _chunkIndexForOffset(clamped);
    }
    _notify();
  }

  // --- Offset bookkeeping (ported from the reference engine) ------------

  int _currentChunkIndex = 0;

  /// The chunk-local offset the in-flight `speak()` call's progress events
  /// are relative to. Android's pause workaround re-slices the text on
  /// resume, so resumed events restart near zero; this re-bases them.
  int _chunkProgressBase = 0;

  /// The most recent chunk-local offset reported for the chunk in flight —
  /// exactly what Android's pause workaround remembers internally.
  int? _lastChunkLocalOffset;

  /// How far into the chunk the *next* speak() should start. Consumed once.
  int? _pendingResumeLocalOffset;

  /// The tapped word's range, held as an alignment floor for the first
  /// word-boundary event after a tap-to-start (Android can skip the first
  /// boundary of a sliced utterance).
  ({int start, int end})? _seekStartGlobalRange;

  // --- Settings ---------------------------------------------------------

  double _speechRate = TtsService.defaultSpeechRate;
  double get speechRate => _speechRate;

  double _pitch = TtsService.defaultPitch;
  double get pitch => _pitch;

  /// Narration volume, `0.0`–`1.0` (FRS §7).
  double _volume = TtsService.defaultVolume;
  double get volume => _volume;

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    if (_volume == clamped) return;
    _volume = clamped;
    _notify();
    await _ttsService.setVolume(clamped);
  }

  Future<void> setSpeechRate(double rate) async {
    if (_speechRate == rate) return;
    _speechRate = rate;
    _notify();
    await _ttsService.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    if (_pitch == pitch) return;
    _pitch = pitch;
    _notify();
    await _ttsService.setPitch(pitch);
  }

  // --- Transport --------------------------------------------------------

  Future<void> play() async {
    if (!_isTtsReady) return;
    if (_playbackState == TtsPlaybackState.playing) return;
    if (_chunks.isEmpty) return;

    var pendingSeek = _pendingResumeLocalOffset;

    // Preserve the reading position across a Stop: stop() resets the chunk
    // index, but `_lastKnownOffset` is deliberately kept, so Play after a
    // settings change continues where the reader was instead of restarting.
    if (pendingSeek == null &&
        _playbackState == TtsPlaybackState.stopped &&
        _lastKnownOffset > 0) {
      _currentChunkIndex = _chunkIndexForOffset(_lastKnownOffset);
      final chunk = _chunks[_currentChunkIndex];
      pendingSeek = (_lastKnownOffset - chunk.startOffset)
          .clamp(0, chunk.text.length);
      // Discard stale seek state; this resume is the new authoritative spot.
      _seekStartGlobalRange = null;
      _lastChunkLocalOffset = null;
    }

    final resumeLocalOffset = pendingSeek ?? 0;
    _pendingResumeLocalOffset = null;

    if (_playbackState == TtsPlaybackState.paused && pendingSeek == null) {
      // Resuming a paused chunk: the paused offset is authoritative.
      _seekStartGlobalRange = null;
      _chunkProgressBase = _lastChunkLocalOffset ?? 0;
    } else {
      _chunkProgressBase = resumeLocalOffset;
      _lastChunkLocalOffset = null;
    }

    await _speakCurrentChunk(seekOffset: resumeLocalOffset);
  }

  Future<void> pause() async {
    if (_playbackState != TtsPlaybackState.playing) return;
    await _ttsService.pause();
  }

  Future<void> stop() async {
    if (_playbackState == TtsPlaybackState.stopped) return;

    // Reset synchronously before awaiting the native stop, so a chunk that
    // completes at almost the same instant can't auto-advance (its guard
    // sees `.stopped`).
    _currentChunkIndex = 0;
    _highlightRange = null;
    _chunkProgressBase = 0;
    _lastChunkLocalOffset = null;
    _seekStartGlobalRange = null;
    _setPlaybackState(TtsPlaybackState.stopped);

    await _ttsService.stop();
  }

  Future<void> toggle() => isPlaying ? pause() : play();

  /// Tap-to-start: move the reading position to [globalOffset] and (when TTS
  /// is ready) begin speaking from there.
  Future<void> startReadingFromWord({
    required int globalOffset,
    int? highlightStart,
    int? highlightEnd,
  }) async {
    if (_chunks.isEmpty) return;

    _currentChunkIndex = _chunkIndexForOffset(globalOffset);
    final chunk = _chunks[_currentChunkIndex];
    _pendingResumeLocalOffset =
        (globalOffset - chunk.startOffset).clamp(0, chunk.text.length);
    _lastKnownOffset = globalOffset;

    if (highlightStart != null && highlightEnd != null) {
      _seekStartGlobalRange = (start: highlightStart, end: highlightEnd);
      _highlightRange = (start: highlightStart, end: highlightEnd);
    }

    if (_playbackState == TtsPlaybackState.playing) {
      await _ttsService.stop();
      _chunkProgressBase = 0;
      _lastChunkLocalOffset = null;
      // Must leave `playing` before play() below, whose guard would
      // otherwise treat this as already playing and refuse the seeked start.
      _setPlaybackState(TtsPlaybackState.stopped);
    } else {
      _notify();
    }

    if (_isTtsReady) await play();
  }

  // --- Audiobook input --------------------------------------------------

  /// Called by the screen on every `just_audio` position tick. Maps the
  /// timestamp through the sync table to a word and highlights its range.
  void onAudioPosition(double seconds) {
    if (!_audiobook || _audioSync.isEmpty) return;
    final content = _content;
    if (content == null) return;

    final entry = _audioEntryAt(seconds);
    if (entry == null) return;

    final word = content.wordById(entry.id);
    if (word == null) return;
    if (_highlightRange?.start == word.start) return; // no visual change

    _highlightRange = (start: word.start, end: word.end);
    _lastKnownOffset = word.start;
    _notify();
  }

  AudioSyncEntry? _audioEntryAt(double seconds) {
    var low = 0;
    var high = _audioSync.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final entry = _audioSync[mid];
      if (seconds < entry.start) {
        high = mid - 1;
      } else if (seconds >= entry.end) {
        low = mid + 1;
      } else {
        return entry;
      }
    }
    return null;
  }

  // --- Internals --------------------------------------------------------

  Future<void> _speakCurrentChunk({int seekOffset = 0}) async {
    if (_currentChunkIndex >= _chunks.length) return;
    final chunk = _chunks[_currentChunkIndex];
    final text = (seekOffset > 0 && seekOffset < chunk.text.length)
        ? chunk.text.substring(seekOffset)
        : chunk.text;

    final started = await _ttsService.speak(text);
    if (!started) _handleTtsError('Text-to-speech could not play.');
  }

  void _handleChunkCompletion() {
    if (_playbackState != TtsPlaybackState.playing) return;

    final next = _currentChunkIndex + 1;
    if (next < _chunks.length) {
      _currentChunkIndex = next;
      _chunkProgressBase = 0;
      _lastChunkLocalOffset = null;
      _speakCurrentChunk();
    } else {
      // Chapter finished — the screen decides whether to advance.
      _currentChunkIndex = 0;
      _highlightRange = null;
      _chunkProgressBase = 0;
      _lastChunkLocalOffset = null;
      _seekStartGlobalRange = null;
      _setPlaybackState(TtsPlaybackState.stopped);
      if (_lastKnownOffset > 0) {
        _lastKnownOffset = 0;
        onChapterFinished?.call();
      }
    }
  }

  void _handleTtsError(String message) {
    _ttsErrorMessage = message;
    _playbackState = TtsPlaybackState.stopped;
    _currentChunkIndex = 0;
    _highlightRange = null;
    _chunkProgressBase = 0;
    _lastChunkLocalOffset = null;
    _seekStartGlobalRange = null;
    _notify();
  }

  void _handleProgress(String word, int localStart, int localEnd) {
    if (_currentChunkIndex >= _chunks.length) return;
    if (localEnd <= localStart) return;

    final chunk = _chunks[_currentChunkIndex];
    final chunkLocalStart = _chunkProgressBase + localStart;
    final chunkLocalEnd = _chunkProgressBase + localEnd;
    _lastChunkLocalOffset = chunkLocalStart;

    final globalStart = chunk.startOffset + chunkLocalStart;
    final globalEnd = chunk.startOffset + chunkLocalEnd;

    // First event after a tap-to-start keeps the highlight on the tapped word
    // (Android may skip the first boundary of a sliced utterance).
    final floor = _seekStartGlobalRange;
    if (floor != null) {
      _seekStartGlobalRange = null;
      _highlightRange = (start: floor.start, end: floor.end);
      _lastKnownOffset = floor.start;
      _notify();
      return;
    }

    _highlightRange = (start: globalStart, end: globalEnd);
    _lastKnownOffset = globalStart;
    _notify();
  }

  int _chunkIndexForOffset(int offset) {
    var low = 0;
    var high = _chunks.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final chunk = _chunks[mid];
      if (offset < chunk.startOffset) {
        high = mid - 1;
      } else if (offset >= chunk.endOffset) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    return low.clamp(0, _chunks.length - 1);
  }

  void _setPlaybackState(TtsPlaybackState next) {
    if (_playbackState == next) return;
    _playbackState = next;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ttsService.stop();
    super.dispose();
  }
}
