/// Reader Screen
/// Amazon Kindle-inspired reading experience with page-turning taps,
/// minimal chrome, progress bar, time remaining, and Aa settings

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'engine/playback_chunk.dart';
import 'engine/reader_content.dart';
import 'engine/reader_playback_controller.dart';
import 'engine/tts_service.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/book_model.dart';
import '../../../data/models/user_data_model.dart';
import '../../../data/services/api_client.dart';
import '../../../data/services/drm_service.dart';
import '../../../data/services/sync_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/audio_controls.dart';
import 'widgets/bookmark_dialog.dart';
import 'widgets/note_dialog.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/chapter_list_drawer.dart';
import 'widgets/word_action_sheet.dart';

enum ReadingMode { light, sepia, dark, green }

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderScreen({super.key, required this.bookId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  // Data
  BookModel? _book;
  List<ChapterModel> _chapters = [];
  List<SyncWordModel> _syncData = [];
  List<BookmarkModel> _bookmarks = [];
  List<NoteModel> _notes = [];
  ReadingProgressModel? _progress;
  
  // Audio
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  
  // On-device narration (chunked TTS) — see engine/reader_playback_controller.dart
  late final ReaderPlaybackController _playback;
  ReaderChapterContent? _chapterContent;
  bool _isTtsPlaying = false; // derived from the controller, for the control bar
  bool _isTtsMode = false; // true when narration is the active audio source
  bool _isTtsReady = false;
  String? _ttsUnavailableReason;
  
  // Scaffold.of(context) doesn't work from the app-bar row it's built in
  // (that context sits above the Scaffold, not below it) — open the
  // end drawer via this key instead.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // UI State
  bool _isLoading = true;
  String? _error;
  int _currentChapterIndex = 0;
  String? _currentWordId; // tracks the audio-sync playhead / reading position
  String? _selectedWordId; // tracks the word tapped for highlight/note/define
  bool _isFullscreen = false;
  bool _showBookmarksDrawer = false;
  
  // Kindle Reading Settings
  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  double _margin = 24.0;
  ReadingMode _readingMode = ReadingMode.light;
  double _playbackSpeed = 1.0;
  double _voicePitch = 1.0; // FRS §7: voice tone adjustment
  double _volume = 1.0; // FRS §7: volume control
  bool _autoScroll = true;
  bool _isPreview = false; // FRS §11: free sample for unpurchased paid books
  String? _audioError;
  bool _noAudio = false; // book ships without narration — narrate on-device

  /// Shortlist size for the narration-voice picker, and the names those
  /// entries are shown under (device voices have no human-friendly names).
  static const int _maxCuratedVoices = 5;
  static const List<String> _voiceNames = [
    'Alice', 'Daniel', 'Emma', 'George', 'Sophia', 'Liam', 'Nora', 'Owen',
  ];
  bool _showAllVoices = false;
  Color _highlightColor = AppColors.primary;
  bool _showTimeRemaining = true;
  bool _showPageNumber = true;
  
  // Reading speed tracking for time remaining (words per minute)
  double _readingSpeed = 250; // Average adult reading speed
  int _wordsReadThisSession = 0;
  DateTime _sessionStart = DateTime.now();
  
  // Scroll
  final _scrollController = ScrollController();
  // One key per paragraph, so auto-scroll can bring the paragraph containing
  // the current position into view (keyed by chapter id + paragraph index).
  final Map<String, GlobalKey> _paraKeys = {};
  double _scrollPercent = 0.0;
  double _previousScrollPercent = 0.0;
  
  // Tap feedback
  bool _showTapFeedback = false;
  Offset _tapPosition = Offset.zero;
  
  // Sync
  Timer? _syncTimer;
  Timer? _progressTimer;

  // Captured in initState() so dispose() can save progress without touching
  // ref (which Riverpod invalidates before dispose() runs).
  late final UserDataRepository _userDataRepoForDispose;
  late final SyncService _syncServiceForDispose;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playerStateSub;

  // Reading mode backgrounds
  Color get _readingBg {
    switch (_readingMode) {
      case ReadingMode.light: return AppColors.readingLight;
      case ReadingMode.sepia: return AppColors.readingSepia;
      case ReadingMode.dark:  return AppColors.readingDark;
      case ReadingMode.green: return const Color(0xFFC7EDCC);
    }
  }

  Color get _readingTextColor {
    if (_readingMode == ReadingMode.dark) return AppColors.textPrimaryDark;
    return AppColors.textPrimaryLight;
  }

  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

  Color get _readingSubtextColor {
    if (_readingMode == ReadingMode.dark) return AppColors.textSecondaryDark;
    return AppColors.textSecondaryLight;
  }
  
  /// Every callback here can fire after the user has already navigated away
  /// (a stream event, a timer tick, an async gap) - calling setState() on an
  /// unmounted State throws, and did throw in practice on every "open a
  /// book, immediately go back" cycle. This is the one place that decides
  /// whether it's still safe to update the UI.
  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    // Cache the providers dispose() needs. ref becomes unusable once
    // dispose() starts, so anything dispose()-time code reads from it must
    // be captured while the widget is still fully alive.
    _userDataRepoForDispose = ref.read(userDataRepositoryProvider);
    _syncServiceForDispose = ref.read(syncServiceProvider);
    _playback = ReaderPlaybackController();
    _playback.addListener(_onPlaybackChanged);
    _playback.onChapterFinished = _onNarrationChapterFinished;
    _loadBook();
    _setupAudioListeners();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    _playback.removeListener(_onPlaybackChanged);
    _playback.dispose();
    _scrollController.dispose();
    _syncTimer?.cancel();
    _progressTimer?.cancel();
    _saveProgressOnDispose();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll > 0) {
      _previousScrollPercent = _scrollPercent;
      _scrollPercent = (currentScroll / maxScroll).clamp(0.0, 1.0);
    }
  }

  void _setupAudioListeners() {
    _positionSub = _audioPlayer.positionStream.listen((position) {
      _safeSetState(() {
        _currentPosition = position;
      });
      _onAudioTick(position);
    });

    _durationSub = _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _safeSetState(() {
          _totalDuration = duration;
        });
      }
    });

    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      _safeSetState(() {
        _isPlaying = state.playing;
      });
    });
  }

  /// Mirrors the playback controller's position into the bits of screen state
  /// the rest of the reader still needs: the word id that bookmarks, notes and
  /// progress are keyed by, and the auto-scroll follow.
  void _onPlaybackChanged() {
    final wordId = _playback.currentWordId;
    final wordChanged = wordId != _currentWordId;
    _currentWordId = wordId;
    if (wordChanged && _autoScroll && wordId != null) {
      _scrollToOffset(_playback.currentOffset);
    }

    // A transient TTS failure (engine errored mid-sentence) is shown once,
    // then acknowledged so it doesn't reappear on the next rebuild.
    final ttsError = _playback.ttsErrorMessage;
    if (ttsError != null) {
      _playback.clearTtsError();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ttsError), behavior: SnackBarBehavior.floating),
        );
      }
    }

    _safeSetState(() {
      _isTtsPlaying = _playback.isPlaying;
      _isTtsMode = _usesOnDeviceNarration;
      _isTtsReady = _playback.isTtsReady;
      _ttsUnavailableReason = _playback.ttsUnavailableReason;
    });
  }

  /// Narration reached the end of the chapter — advance exactly like the
  /// audio follow does.
  void _onNarrationChapterFinished() {
    if (!mounted) return;
    if (_currentChapterIndex < _chapters.length - 1) {
      _goToNextChapter();
    } else if (_isPreview) {
      _showSampleEndDialog();
    }
  }

  /// Builds the offset index for the current chapter and hands it to the
  /// controller, so highlighting, progress and chunking all work in one
  /// coordinate space whether we're following audio or narrating on-device.
  void _rebuildChapterContent({bool restorePosition = false}) {
    if (_chapters.isEmpty) {
      _chapterContent = null;
      return;
    }

    final content = ReaderChapterContent.fromChapter(
      _chapters[_currentChapterIndex],
    );
    _chapterContent = content;

    // Play the uploaded narration whenever there is real audio for this book;
    // the sync table only drives word-level highlighting. Requiring sync data
    // here meant an audiobook uploaded through the admin was ignored (there is
    // no tooling to author timings), and the reader silently fell back to the
    // device voice instead of the narrator the publisher shipped.
    // A book with no audio — or only the demo placeholder tone — still
    // narrates on-device.
    _playback.setContent(
      content,
      audiobook: !_usesOnDeviceNarration,
    );

    if (restorePosition) {
      final savedWord = content.wordById(_progress?.wordId);
      if (savedWord != null) _playback.seekToOffset(savedWord.start);
    }

    _currentWordId = _playback.currentWordId;
  }

  /// True when the phone's own narration is this book's audio source — either
  /// there is no audio at all, or the only clip is the demo placeholder tone.
  bool get _usesOnDeviceNarration => _noAudio || _audioError != null || _isPlaceholderAudio;

  /// The explicit "read aloud" toggle: stops narration if running, otherwise
  /// pauses the audiobook and starts narrating from the current position.
  Future<void> _toggleTts() async {
    if (_playback.isPlaying) {
      await _playback.stop();
      return;
    }
    if (_isPlaying) await _audioPlayer.pause();
    await _playback.play();
  }

  Future<void> _loadBook() async {
    _safeSetState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final booksRepo = ref.read(booksRepositoryProvider);
      final userDataRepo = ref.read(userDataRepositoryProvider);

      final bookData = await booksRepo.getBook(widget.bookId);
      if (bookData != null) {
        _book = BookModel.fromJson(bookData);
      }

      final content = await booksRepo.getBookContentWithPreviewFlag(widget.bookId);
      _chapters = content.chapters.map((c) => ChapterModel.fromJson(c)).toList();
      _isPreview = content.isPreview;

      final syncData = await booksRepo.getBookSync(widget.bookId);
      _syncData = syncData.map((s) => SyncWordModel.fromJson(s)).toList();
      _playback.setAudioSync(_syncData
          .map((s) => AudioSyncEntry(id: s.id, start: s.start, end: s.end))
          .toList());

      final bookmarksData = await userDataRepo.getBookmarks(widget.bookId);
      _bookmarks = bookmarksData.map((b) => BookmarkModel.fromJson(b)).toList();

      final notesData = await userDataRepo.getNotes(widget.bookId);
      _notes = notesData.map((n) => NoteModel.fromJson(n)).toList();

      final progressData = await userDataRepo.getProgress(widget.bookId);
      if (progressData != null) {
        // Restore the saved position silently and continue reading — no
        // confirmation dialog interrupting the flow.
        _progress = ReadingProgressModel.fromJson(progressData);
      }

      // A stuck platform channel (e.g. no audio backend on this platform)
      // must never block the book itself from opening - text still needs
      // to load. Give audio a bounded window and move on either way.
      try {
        await _loadAudio().timeout(const Duration(seconds: 8));
      } catch (e) {
        if (mounted) _safeSetState(() => _audioError = 'Audio unavailable: $e');
      }

      // Now that audio is resolved we know whether this book narrates
      // on-device, so the chapter index can be built with the right mode.
      // The saved position is restored into it, but not scrolled to yet —
      // the reader gets a say via the resume prompt first.
      _rebuildChapterContent(restorePosition: _progress?.wordId != null);

      _safeSetState(() {
        _isLoading = false;
      });

      // On-device narration warms up in the background; the text is readable
      // immediately either way.
      _playback.language = TtsService.languageCodeFor(_book?.language);
      unawaited(_playback.initializeTts().then((_) {
        if (mounted) _onPlaybackChanged();
      }));

      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _saveProgress();
        _trackReadingSpeed();
      });
    } catch (e) {
      _safeSetState(() {
        _error = 'Failed to load book: $e';
        _isLoading = false;
      });
    }
  }

  void _trackReadingSpeed() {
    _wordsReadThisSession += 50; // Approximate words per tick
  }

  String get _estimatedTimeRemaining {
    if (_chapters.isEmpty) return '';
    
    final totalWords = _chapters.fold<int>(0, (sum, ch) => sum + ch.allWords.length);
    if (totalWords == 0) return '';
    
    final wordsRead = (totalWords * _scrollPercent).round();
    final wordsRemaining = math.max(0, totalWords - wordsRead);
    
    if (_readingSpeed <= 0) return '';
    final minutesRemaining = wordsRemaining / _readingSpeed;
    
    if (minutesRemaining < 1) return 'Less than a minute';
    if (minutesRemaining < 60) {
      return '${minutesRemaining.ceil()} min left';
    }
    final hours = minutesRemaining ~/ 60;
    final mins = minutesRemaining.ceil() % 60;
    return '${hours}h ${mins}min left';
  }

  String get _currentPageInfo {
    if (_chapters.isEmpty) return '';
    
    final currentChapter = _chapters[_currentChapterIndex];
    final totalWords = currentChapter.allWords.length;
    final wordsPerPage = (_readingSpeed / 2).round().clamp(50, 500);
    final totalPages = (totalWords / wordsPerPage).ceil().clamp(1, 9999);
    final currentPage = (_scrollPercent * totalPages).ceil().clamp(1, totalPages);
    
    return 'Page $currentPage of $totalPages';
  }

  Future<void> _loadAudio() async {
    _safeSetState(() {
      _audioError = null;
      _noAudio = false;
    });
    try {
      // Offline mode (FRS §9): prefer a previously downloaded local file so
      // playback works without a network connection. Not applicable on web
      // (no filesystem - downloads never land there in the first place).
      if (!kIsWeb) {
        final db = ref.read(databaseProvider);
        final localPath = await db.getLocalAudioPath(widget.bookId);
        if (localPath != null && localPath.isNotEmpty && await File(localPath).exists()) {
          await _audioPlayer.setFilePath(localPath);
          return;
        }
      }

      final drmService = ref.read(drmServiceProvider);
      final license = await drmService.getLicense(widget.bookId);
      if (license?.downloadUrl == null) {
        // Not an error: this book simply has no narration, so the reader
        // narrates on-device. Showing a retry banner for it would be noise.
        _safeSetState(() => _noAudio = true);
        return;
      }
      await _audioPlayer.setUrl(license!.downloadUrl!);
    } catch (e) {
      if (mounted) _safeSetState(() => _audioError = 'Could not load audio: $e');
    }
  }

  int _getChapterIndexForWord(String? wordId) {
    if (wordId == null || _chapters.isEmpty) return 0;
    for (int i = 0; i < _chapters.length; i++) {
      final words = _chapters[i].allWords;
      if (words.any((w) => w.id == wordId)) return i;
    }
    return 0;
  }

  /// Maps a playback-speed multiplier (0.5x–2.5x) onto flutter_tts's speech-rate
  /// scale (0.0–1.0).
  ///
  /// These are different scales: passing the multiplier straight through made
  /// 1.0x already the maximum speech rate, so narration sounded rushed even at
  /// the default setting. Scale around the platform default instead, and cap it
  /// below the top of the range so speech stays intelligible.
  double _speechRateFor(double speed) =>
      (TtsService.defaultSpeechRate * speed).clamp(0.1, 0.75);

  /// Lets the reader pick a different narration voice.
  ///
  /// The list comes from the platform TTS engine, so it reflects whatever
  /// voices are installed on the device (and only those that exist — no point
  /// offering a narrator the phone cannot produce).
  Future<void> _chooseVoice() async {
    final voices = await _playback.availableVoices();
    if (!mounted) return;

    if (voices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No alternative voices found on this device.'),
        ),
      );
      return;
    }

    // Prefer voices matching the book's language, but keep the rest reachable.
    // Some Android engines report an empty `locale` and only encode the
    // language in the voice name (e.g. "en-au-x-aud-local"), so match on both.
    final bookLang = TtsService.languageCodeFor(_book?.language).split('-').first;
    bool matchesBook(Map<String, String> v) {
      final locale = (v['locale'] ?? '').toLowerCase();
      final name = (v['name'] ?? '').toLowerCase();
      return locale.startsWith(bookLang) ||
          name.startsWith('$bookLang-') ||
          name.startsWith('${bookLang}_') ||
          name == bookLang;
    }

    final matching = voices.where(matchesBook).toList();
    final others = voices.where((v) => !matchesBook(v)).toList();

    // Device TTS voices have no human names (e.g. "en-us-x-sfg#male_1-local"),
    // and there can be dozens. Offer a short, named shortlist instead — the
    // way assistant apps present voices — with the full list one tap away.
    final curated = matching.take(_maxCuratedVoices).toList();

    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _readingBg,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final showAll = _showAllVoices;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      'Narration voice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _readingTextColor,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        _voiceTile(
                          sheetContext,
                          const {'name': '', 'locale': ''},
                          title: 'System default',
                          subtitle: 'Use the device default',
                          leadingIcon: Icons.settings_voice,
                        ),
                        if (!showAll) ...[
                          if (curated.isNotEmpty)
                            _voiceSectionHeader('Voices'),
                          for (var i = 0; i < curated.length; i++)
                            _voiceTile(sheetContext, curated[i], nameIndex: i),
                          if (matching.length > curated.length ||
                              others.isNotEmpty)
                            ListTile(
                              leading: Icon(Icons.more_horiz,
                                  color: _readingSubtextColor),
                              title: Text(
                                'Show all voices (${voices.length})',
                                style: TextStyle(color: AppColors.primary),
                              ),
                              onTap: () =>
                                  setSheetState(() => _showAllVoices = true),
                            ),
                        ] else ...[
                          if (matching.isNotEmpty)
                            _voiceSectionHeader('For this book\'s language'),
                          ...matching.map((v) => _voiceTile(sheetContext, v)),
                          if (others.isNotEmpty)
                            _voiceSectionHeader('Other languages'),
                          ...others.map((v) => _voiceTile(sheetContext, v)),
                          ListTile(
                            leading: Icon(Icons.expand_less,
                                color: _readingSubtextColor),
                            title: Text('Show fewer',
                                style: TextStyle(color: AppColors.primary)),
                            onTap: () =>
                                setSheetState(() => _showAllVoices = false),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    _showAllVoices = false;

    if (selected == null) return;

    if (selected['name']!.isEmpty) {
      // "System default" — re-initialising clears any explicit voice.
      await _playback.setVoice('', '');
      await _playback.initializeTts();
      _safeSetState(() {});
      return;
    }

    await _playback.setVoice(selected['name']!, selected['locale']!);
    _safeSetState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Voice set to ${_friendlyVoiceName(selected, curated)}')),
    );
  }

  Widget _voiceSectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: _readingSubtextColor,
          ),
        ),
      );

  /// Friendly label for a device voice. The shortlist is numbered, so each
  /// entry gets a distinct human name; entries beyond the shortlist (only
  /// reachable from "show all") fall back to the engine's own identifier.
  String _friendlyVoiceName(Map<String, String> v, List<Map<String, String>> curated) {
    final idx = curated.indexWhere((c) => c['name'] == v['name']);
    if (idx >= 0) return _voiceNames[idx % _voiceNames.length];
    return v['name'] ?? 'Voice';
  }

  /// Best-effort gender hint from the engine identifier, when it carries one.
  String? _voiceGenderHint(String identifier) {
    final lower = identifier.toLowerCase();
    if (lower.contains('female') || lower.contains('#f')) return 'Female';
    if (lower.contains('male') || lower.contains('#m')) return 'Male';
    return null;
  }

  Widget _voiceTile(
    BuildContext sheetContext,
    Map<String, String> v, {
    int? nameIndex,
    String? title,
    String? subtitle,
    IconData? leadingIcon,
  }) {
    final isDefault = (v['name'] ?? '').isEmpty;
    final isCurrent = isDefault
        ? _playback.voiceName == null
        : _playback.voiceName == v['name'];

    final label = title ??
        (nameIndex != null
            ? _voiceNames[nameIndex % _voiceNames.length]
            : (v['name'] ?? 'Voice'));

    // Name + language + gender, the way a voice picker usually reads.
    final parts = <String>[
      if (subtitle != null) subtitle,
      if (!isDefault && (v['locale'] ?? '').isNotEmpty) v['locale']!,
    ];
    if (!isDefault) {
      final hint = _voiceGenderHint(v['name'] ?? '');
      if (hint != null) parts.add(hint);
    }

    return ListTile(
      leading: Icon(
        isCurrent ? Icons.check_circle : (leadingIcon ?? Icons.record_voice_over_outlined),
        color: isCurrent ? AppColors.primary : _readingSubtextColor,
      ),
      title: Text(label, style: TextStyle(color: _readingTextColor)),
      subtitle: parts.isEmpty
          ? null
          : Text(parts.join(' · '),
              style: TextStyle(color: _readingSubtextColor, fontSize: 12)),
      onTap: () => Navigator.pop(sheetContext, v),
    );
  }

  /// Feeds the audiobook clock into the playback controller, which maps the
  /// timestamp through the sync table to a word and highlights its range —
  /// the same highlight channel on-device narration drives.
  void _onAudioTick(Duration position) {
    if (_usesOnDeviceNarration) return;
    _playback.onAudioPosition(position.inMilliseconds / 1000.0);
  }

  /// Brings the paragraph containing [offset] into view. Paragraph-level (not
  /// word-level) because the reading view renders paragraphs lazily, so only
  /// paragraph widgets have keys.
  void _scrollToOffset(int offset) {
    final content = _chapterContent;
    if (content == null) return;
    final paragraph = content.paragraphAtOffset(offset);
    if (paragraph == null) return;
    final index = content.paragraphs.indexOf(paragraph);
    if (index < 0) return;

    final key = _paraKeys['${content.chapterId}:$index'];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );
  }

  // Kindle tap zones: left=previous chapter, right=next chapter.
  // The playback controls are always on screen, so a centre tap has no job.
  void _handleTap(TapUpDetails details) {
    HapticFeedback.lightImpact();
    
    _safeSetState(() {
      _tapPosition = details.localPosition;
      _showTapFeedback = true;
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _safeSetState(() => _showTapFeedback = false);
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.localPosition.dx;

    if (tapX < screenWidth * 0.3) {
      _goToPreviousChapter();
    } else if (tapX > screenWidth * 0.7) {
      _goToNextChapter();
    }
  }

  /// Switches chapters, rebuilds the offset index for the new one, and clears
  /// the reading position so the new chapter opens at its start.
  void _openChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    _playback.stop();
    _safeSetState(() => _currentChapterIndex = index);
    _rebuildChapterContent();
    _safeSetState(() { _scrollPercent = 0.0; });
    // Delay the scroll reset until after the AnimatedSwitcher transition.
    Future.delayed(AppAnimations.slow, () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _goToPreviousChapter() {
    if (_currentChapterIndex > 0) _openChapter(_currentChapterIndex - 1);
  }

  void _goToNextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      _openChapter(_currentChapterIndex + 1);
    } else if (_isPreview) {
      _showSampleEndDialog();
    }
  }

  /// Free sample (FRS §11) ran out — offer to buy the full book.
  void _showSampleEndDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End of sample'),
        content: Text(
          'You\'ve reached the end of the free sample of "${_book?.title ?? 'this book'}". '
          'Buy the full book to keep reading.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // back to Store to complete checkout
            },
            child: Text(_book != null && !_book!.isFree
                ? 'Buy Now — ${_book!.formattedPrice}'
                : 'Buy Now'),
          ),
        ],
      ),
    );
  }

  // Demo/seed books ship a short placeholder tone instead of real narration
  // (generating real audio needs a TTS pipeline the demo server has no disk
  // space for right now). A chapter with real text but a suspiciously short
  // clip is that placeholder, not narration - so the main play button reads
  // it aloud on-device instead, rather than surfacing a beep to the user.
  bool get _isPlaceholderAudio {
    if (_totalDuration <= Duration.zero || _chapters.isEmpty) return false;
    final wordCount = _chapters[_currentChapterIndex].allWords.length;
    return wordCount > 15 && _totalDuration.inSeconds < (wordCount / 4).ceil();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_audioError != null) {
          await _loadAudio().timeout(const Duration(seconds: 8)); // retry loading before playing
        }
        // No usable narration audio for this book — the phone reads it instead.
        if (_usesOnDeviceNarration) {
          if (_isPlaying) await _audioPlayer.pause();
          await _playback.toggle();
          return;
        }
        await _audioPlayer.play();
      }
    } catch (e) {
      if (!mounted) return;
      // The inline banner below the text (with its own Retry/dismiss) is
      // the single source of truth for audio errors - a second SnackBar
      // saying the same thing just felt like the error was stuck twice.
      _safeSetState(() => _audioError = 'Playback error: $e');
    }
  }

  /// Moves the reading position to a word and starts playback from there.
  ///
  /// Audiobook mode seeks the audio to that word's timestamp; on-device mode
  /// asks the controller to narrate from that word. Both resolve to the same
  /// offset first, so the highlight lands in the same place either way.
  Future<void> _playFromWord(String wordId) async {
    final word = _chapterContent?.wordById(wordId);
    if (word == null) return;

    if (_usesOnDeviceNarration) {
      await _playback.startReadingFromWord(
        globalOffset: word.start,
        highlightStart: word.start,
        highlightEnd: word.end,
      );
      return;
    }

    try {
      final syncWord = _syncData.firstWhere((s) => s.id == wordId);
      await _audioPlayer.seek(
        Duration(milliseconds: (syncWord.start * 1000).round()),
      );
      await _audioPlayer.play();
    } catch (_) {
      // No timestamp for this word — still move the reading highlight there.
      _playback.seekToOffset(word.start);
    }
  }

  /// Kindle-style tap-to-define: long-pressing a word shows a compact action
  /// sheet with a dictionary lookup plus highlight/note/read-from-here.
  void _showWordActionSheet(WordModel word) {
    _safeSetState(() => _selectedWordId = word.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _readingBg,
      builder: (_) => WordActionSheet(
        word: word,
        language: _book?.language ?? 'en',
        hasBookmark: _bookmarks.any((b) => b.wordId == word.id),
        hasNote: _notes.any((n) => n.wordId == word.id),
        onHighlight: () { Navigator.pop(context); _addBookmark(); },
        onNote: () { Navigator.pop(context); _addNote(); },
        onPlayFromHere: () { Navigator.pop(context); _playFromWord(word.id); },
        defineWord: _defineWord,
      ),
    );
  }

  Future<DictionaryEntry> _defineWord(String word, String language) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.dictionary(word),
      queryParams: {'lang': language},
    );
    if (response.success && response.data != null) {
      return DictionaryEntry.fromJson(response.data!);
    }
    throw Exception(response.error ?? 'No definition found');
  }

  Future<void> _saveProgress() async {
    await _doSaveProgress(
      userDataRepo: ref.read(userDataRepositoryProvider),
      syncService: ref.read(syncServiceProvider),
    );
  }

  /// Same save, but for dispose(): ref is invalid there, so it must run on
  /// the repo/service instances captured back in initState() instead of
  /// reading providers.
  void _saveProgressOnDispose() {
    _doSaveProgress(
      userDataRepo: _userDataRepoForDispose,
      syncService: _syncServiceForDispose,
    );
  }

  Future<void> _doSaveProgress({
    required UserDataRepository userDataRepo,
    required SyncService syncService,
  }) async {
    if (_progress == null || _chapters.isEmpty) return;
    final updatedProgress = _progress!.copyWith(
      positionSeconds: _currentPosition.inMilliseconds / 1000.0,
      progressPercent: _calculateProgressPercent(),
      lastReadAt: DateTime.now(),
    );
    try {
      await userDataRepo.updateProgress(
        bookId: widget.bookId,
        chapterId: _chapters[_currentChapterIndex].id,
        wordId: _currentWordId,
        positionSeconds: updatedProgress.positionSeconds,
        progressPercent: updatedProgress.progressPercent,
      );
    } catch (e) {
      await syncService.updateProgress(updatedProgress);
    }
  }

  double _calculateProgressPercent() {
    if (_chapters.isEmpty) return 0.0;
    final totalWords = _chapters.fold<int>(0, (sum, ch) => sum + ch.allWords.length);
    if (totalWords == 0) return 0.0;
    int wordsBefore = 0;
    for (int i = 0; i < _currentChapterIndex; i++) {
      wordsBefore += _chapters[i].allWords.length;
    }
    final currentWords = _chapters[_currentChapterIndex].allWords;
    int wordIdx = 0;
    if (_currentWordId != null) {
      wordIdx = currentWords.indexWhere((w) => w.id == _currentWordId);
      if (wordIdx < 0) wordIdx = 0;
    }
    return ((wordsBefore + wordIdx) / totalWords * 100).clamp(0.0, 100.0);
  }

  Future<void> _addBookmark() async {
    if (_selectedWordId == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BookmarkDialog(
        wordId: _selectedWordId!,
        existingBookmark: _bookmarks.firstWhere(
          (b) => b.wordId == _selectedWordId,
          orElse: () => null as BookmarkModel,
        ),
      ),
    );
    if (result != null) {
      final syncService = ref.read(syncServiceProvider);
      final user = ref.read(currentUserProvider);
      try {
        if (result['delete'] == true) {
          _safeSetState(() { _bookmarks.removeWhere((b) => b.wordId == _selectedWordId); });
        } else {
          final bookmark = await syncService.createBookmark(
            userId: user!.id, bookId: widget.bookId, wordId: _selectedWordId!,
            chapterId: _chapters[_currentChapterIndex].id,
            positionSeconds: _currentPosition.inMilliseconds / 1000.0,
            note: result['note'], color: result['color'],
          );
          _safeSetState(() {
            _bookmarks.removeWhere((b) => b.wordId == _selectedWordId);
            _bookmarks.add(bookmark);
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save bookmark: $e')),
        );
      }
    }
  }

  Future<void> _addNote() async {
    if (_selectedWordId == null) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => NoteDialog(
        wordId: _selectedWordId!,
        existingNote: _notes.firstWhere(
          (n) => n.wordId == _selectedWordId,
          orElse: () => null as NoteModel,
        ),
      ),
    );
    if (result != null) {
      final syncService = ref.read(syncServiceProvider);
      final user = ref.read(currentUserProvider);
      try {
        if (result.isEmpty) {
          _safeSetState(() { _notes.removeWhere((n) => n.wordId == _selectedWordId); });
        } else {
          final note = await syncService.createNote(
            userId: user!.id, bookId: widget.bookId, wordId: _selectedWordId!,
            content: result, chapterId: _chapters[_currentChapterIndex].id,
          );
          _safeSetState(() {
            _notes.removeWhere((n) => n.wordId == _selectedWordId);
            _notes.add(note);
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: $e')),
        );
      }
    }
  }

  void _showAaSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _readingBg,
      builder: (_) => SettingsSheet(
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        theme: _readingMode == ReadingMode.dark ? 'dark' 
              : _readingMode == ReadingMode.sepia ? 'sepia' 
              : 'light',
        playbackSpeed: _playbackSpeed,
        voicePitch: _voicePitch,
        volume: _volume,
        autoScroll: _autoScroll,
        highlightColor: _highlightColor,
        readingMode: _readingMode,
        voiceLabel: _playback.voiceName,
        onChooseVoice: _chooseVoice,
        onFontSizeChanged: (v) => _safeSetState(() => _fontSize = v),
        onLineHeightChanged: (v) => _safeSetState(() => _lineHeight = v),
        onThemeChanged: (v) {
          _safeSetState(() {
            switch (v) {
              case 'light': _readingMode = ReadingMode.light; break;
              case 'sepia': _readingMode = ReadingMode.sepia; break;
              case 'dark': _readingMode = ReadingMode.dark; break;
              case 'green': _readingMode = ReadingMode.green; break;
            }
          });
        },
        onPlaybackSpeedChanged: (v) {
          _safeSetState(() => _playbackSpeed = v);
          _audioPlayer.setSpeed(v);
          _playback.setSpeechRate(_speechRateFor(v));
        },
        onVoicePitchChanged: (v) {
          _safeSetState(() => _voicePitch = v);
          _audioPlayer.setPitch(v);
          _playback.setPitch(v);
        },
        onVolumeChanged: (v) {
          _safeSetState(() => _volume = v);
          // One slider controls both audio sources, so the reader never has
          // to know which one is currently playing.
          _audioPlayer.setVolume(v);
          _playback.setVolume(v);
        },
        onAutoScrollChanged: (v) => _safeSetState(() => _autoScroll = v),
        onHighlightColorChanged: (v) => _safeSetState(() => _highlightColor = v),
        onReadingModeChanged: (mode) => _safeSetState(() => _readingMode = mode),
      ),
    );
  }

  void _toggleFullscreen() {
    _safeSetState(() { _isFullscreen = !_isFullscreen; });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _readingBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _readingBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              ElevatedButton(onPressed: _loadBook, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      endDrawer: ChapterListDrawer(
        chapters: _chapters,
        currentChapterIndex: _currentChapterIndex,
        bookmarks: _bookmarks,
        onChapterSelected: _openChapter,
      ),
      body: AnimatedContainer(
        duration: AppAnimations.slow,
        color: _readingBg,
        child: Column(
          children: [
            // Top bar — kept visible so back / chapter info are always at hand.
            _buildTopBar(),
            
            // Reading content with Kindle tap zones
            Expanded(
              child: GestureDetector(
                onTapUp: _handleTap,
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: AppAnimations.slow,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.97, end: 1.0).animate(
                              CurvedAnimation(parent: animation, curve: Curves.easeOut),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey('chapter_$_currentChapterIndex'),
                        child: _buildContent(),
                      ),
                    ),
                    // Tap feedback ripple
                    if (_showTapFeedback)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _showTapFeedback ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: _buildTapRipple(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Playback bar — always visible so the play button is reachable
            // without having to discover the tap-to-reveal gesture.
            _buildBottomBar(),
            
            // Progress bar (always visible)
            _buildMiniProgressBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: _readingBg,
        border: Border(bottom: BorderSide(color: _readingSubtextColor.withOpacity(0.15))),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Back
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: _readingTextColor,
                onPressed: () => Navigator.pop(context),
              ),
              // Book title and chapter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _book?.title ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _readingTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_chapters.isNotEmpty)
                      Text(
                        _chapters[_currentChapterIndex].title,
                        style: TextStyle(
                          fontSize: 11,
                          color: _readingSubtextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (_isPreview)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('SAMPLE', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary,
                  )),
                ),
              // Table of Contents
              IconButton(
                icon: const Icon(Icons.list),
                color: _readingTextColor,
                tooltip: 'Table of Contents',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              // Aa settings
              IconButton(
                icon: const Icon(Icons.text_fields),
                color: _readingTextColor,
                tooltip: 'Font & Theme settings',
                onPressed: _showAaSettings,
              ),
              // Bookmarks
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                color: _readingTextColor,
                tooltip: 'Bookmarks',
                onPressed: _addBookmark,
              ),
              // Notes
              IconButton(
                icon: const Icon(Icons.note_add_outlined),
                color: _readingTextColor,
                tooltip: 'Add note',
                onPressed: _addNote,
              ),
              // Fullscreen
              IconButton(
                icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                color: _readingTextColor,
                onPressed: _toggleFullscreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _readingBg,
        border: Border(top: BorderSide(color: _readingSubtextColor.withOpacity(0.15))),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kindle-style reading progress
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  // Chapter navigation
                  if (_currentChapterIndex > 0)
                    TextButton.icon(
                      onPressed: _goToPreviousChapter,
                      icon: const Icon(Icons.chevron_left, size: 18),
                      label: Text(
                        _chapters[_currentChapterIndex - 1].title,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: _readingTextColor.withOpacity(0.7),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  const Spacer(),
                  if (_currentChapterIndex < _chapters.length - 1)
                    TextButton.icon(
                      onPressed: _goToNextChapter,
                      icon: const Icon(Icons.chevron_right, size: 18),
                      label: Text(
                        _chapters[_currentChapterIndex + 1].title,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: _readingTextColor.withOpacity(0.7),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                ],
              ),
            ),
            if (_audioError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_audioError!,
                        style: const TextStyle(fontSize: 11, color: AppColors.error),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    TextButton(
                      onPressed: _loadAudio,
                      child: const Text('Retry', style: TextStyle(fontSize: 11)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      color: _readingSubtextColor,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Dismiss',
                      onPressed: () => _safeSetState(() => _audioError = null),
                    ),
                  ],
                ),
              ),
            // Audio controls
            AudioControls(
              isPlaying: _isPlaying || _isTtsPlaying,
              currentPosition: _currentPosition,
              totalDuration: _totalDuration,
              playbackSpeed: _playbackSpeed,
              isTtsPlaying: _isTtsPlaying,
              isTtsMode: _isTtsMode,
              onPlayPause: _togglePlayPause,
              onSeek: (position) => _audioPlayer.seek(position),
              onSpeedChange: (speed) {
                _safeSetState(() => _playbackSpeed = speed);
                _audioPlayer.setSpeed(speed);
                _playback.setSpeechRate(_speechRateFor(speed));
              },
              onTtsToggle: _toggleTts,
              textColor: _readingTextColor,
              bgColor: _readingBg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniProgressBar() {
    final progress = _calculateProgressPercent() / 100;
    return SizedBox(
      height: 4,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: _previousScrollPercent, end: progress),
        duration: AppAnimations.normal,
        curve: Curves.easeInOutCubic,
        builder: (context, value, _) {
          final clampedValue = value.clamp(0.0, 1.0);
          return Container(
            color: _readingSubtextColor.withOpacity(0.15),
            child: Stack(
              children: [
                // Gradient progress bar
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: clampedValue,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Glowing thumb dot
                if (clampedValue > 0 && clampedValue < 1)
                  Positioned(
                    left: (clampedValue * MediaQuery.of(context).size.width) - 3,
                    top: -1.5,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTapRipple() {
    return CustomPaint(
      painter: _TapRipplePainter(
        position: _tapPosition,
        color: _highlightColor,
      ),
    );
  }

  Widget _buildContent() {
    if (_chapters.isEmpty) {
      return Center(
        child: Text('No content available', style: TextStyle(color: _readingSubtextColor)),
      );
    }

    final chapter = _chapters[_currentChapterIndex];
    final content = _chapterContent;
    if (content == null || content.paragraphs.isEmpty) {
      return Center(
        child: Text('No content available', style: TextStyle(color: _readingSubtextColor)),
      );
    }

    // Desktop windows are much wider than a phone; keep the reading column
    // at a comfortable line length (like a real book page) and let the
    // extra width become breathing room on either side instead of
    // stretching text edge-to-edge.
    final columnWidth = _isDesktop ? 720.0 : double.infinity;

    Widget centered(Widget child) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: columnWidth),
            child: child,
          ),
        );

    // A lazy sliver list rather than a Column: a long chapter would otherwise
    // build every paragraph's widget up front, which is real jank on first
    // frame. Only visible paragraphs (plus a small buffer) are built.
    final scrollView = CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(_margin, 16, _margin, 0),
          sliver: SliverToBoxAdapter(child: centered(_buildChapterTitle(chapter.title))),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: _margin),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final paragraph = content.paragraphs[i];
                final sourceParagraph = chapter.paragraphs[i];
                final key = _paraKeys.putIfAbsent(
                  '${content.chapterId}:$i',
                  () => GlobalKey(),
                );
                return centered(Padding(
                  key: key,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReaderParagraph(
                    paragraph: paragraph,
                    source: sourceParagraph,
                    playback: _playback,
                    fontSize: _fontSize,
                    lineHeight: _lineHeight,
                    textColor: _readingTextColor,
                    highlightColor: _highlightColor,
                    onWordTap: _startReadingFromWord,
                    onWordLongPress: _showWordActionSheet,
                  ),
                ));
              },
              childCount: content.paragraphs.length,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(_margin, 0, _margin, 16),
          sliver: SliverToBoxAdapter(child: centered(_buildChapterFooter())),
        ),
      ],
    );

    return Stack(
      children: [
        // Main text
        _isDesktop
            ? Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: scrollView,
              )
            : scrollView,

        // Bookmark indicators on the right edge (Kindle-style)
        if (_bookmarks.isNotEmpty)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _bookmarks.isNotEmpty ? 1.0 : 0.0,
              duration: AppAnimations.normal,
              child: _buildBookmarkRibbons(),
            ),
          ),
      ],
    );
  }

  /// Chapter heading with a Kindle-style accent bar.
  Widget _buildChapterTitle(String title) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: AppAnimations.slow,
          width: 3,
          height: _fontSize * 1.8,
          decoration: BoxDecoration(
            color: _highlightColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: AppAnimations.slow,
            style: TextStyle(
              fontSize: _fontSize * 1.3,
              fontWeight: FontWeight.w700,
              color: _readingTextColor,
              letterSpacing: -0.3,
              height: 1.3,
            ),
            child: Text(title),
          ),
        ),
      ],
    );
  }

  /// End-of-chapter ornament plus the page / time-remaining readouts.
  Widget _buildChapterFooter() {
    return Column(
      children: [
        SizedBox(height: _fontSize * 2),
        Center(
          child: Text(
            '◆\u00A0\u00A0\u00A0◆\u00A0\u00A0\u00A0◆',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _readingSubtextColor.withOpacity(0.35),
              fontSize: _fontSize * 0.65,
              letterSpacing: 8,
            ),
          ),
        ),
        SizedBox(height: _fontSize),
        if (_showPageNumber)
          Center(
            child: Text(
              _currentPageInfo,
              style: TextStyle(
                fontSize: 12,
                color: _readingSubtextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (_showTimeRemaining)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _estimatedTimeRemaining,
                style: TextStyle(
                  fontSize: 12,
                  color: _readingSubtextColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        SizedBox(height: _fontSize * 3),
      ],
    );
  }

  Widget _buildBookmarkRibbons() {
    // Show bookmarks as tiny indicators on the right edge
    final chapter = _chapters[_currentChapterIndex];
    if (chapter.paragraphs.isEmpty) return const SizedBox();

    final bookmarkPositions = <double>[];
    for (final para in chapter.paragraphs) {
      for (final word in para.words) {
        if (_bookmarks.any((b) => b.wordId == word.id)) {
          // Calculate approximate position
          final paraIndex = chapter.paragraphs.indexOf(para);
          bookmarkPositions.add(paraIndex / chapter.paragraphs.length);
        }
      }
    }

    return IgnorePointer(
      child: Column(
        children: bookmarkPositions.map((pos) {
          return Expanded(
            child: Align(
              alignment: Alignment(0, (pos * 2) - 1),
              child: Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bookmarkYellow,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Tap-to-read-from-here. The paragraph maps the tap to a character offset
  /// and hands back the word under it plus that word's chapter-wide range.
  void _startReadingFromWord(WordModel word, int start, int end) {
    _safeSetState(() => _selectedWordId = word.id);
    if (_usesOnDeviceNarration) {
      _playback.startReadingFromWord(
        globalOffset: start,
        highlightStart: start,
        highlightEnd: end,
      );
    } else {
      _playFromWord(word.id);
    }
  }
}

/// Ripple painter for tap feedback on chapter navigation zones
class _TapRipplePainter extends CustomPainter {
  final Offset position;
  final Color color;

  _TapRipplePainter({required this.position, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 40, paint);
  }

  @override
  bool shouldRepaint(_TapRipplePainter old) => old.position != position;
}

/// One lazily-built paragraph.
///
/// It renders as a single `Text` (3 spans when part of it is highlighted) and
/// resolves taps through the live `RenderParagraph`, rather than building a
/// `WidgetSpan` per word. That keeps a long paragraph cheap to build and lets
/// a tap map to the exact word the user touched.
///
/// The highlight it draws is derived from the playback controller's
/// chapter-wide range, clipped to this paragraph's own slice — so a word
/// spoken three paragraphs away produces the same value before and after the
/// change, and this widget does not rebuild.
class _ReaderParagraph extends StatefulWidget {
  const _ReaderParagraph({
    super.key,
    required this.paragraph,
    required this.source,
    required this.playback,
    required this.fontSize,
    required this.lineHeight,
    required this.textColor,
    required this.highlightColor,
    required this.onWordTap,
    required this.onWordLongPress,
  });

  final BookParagraph paragraph;
  final ParagraphModel source;
  final ReaderPlaybackController playback;
  final double fontSize;
  final double lineHeight;
  final Color textColor;
  final Color highlightColor;
  final void Function(WordModel word, int start, int end) onWordTap;
  final void Function(WordModel word) onWordLongPress;

  @override
  State<_ReaderParagraph> createState() => _ReaderParagraphState();
}

class _ReaderParagraphState extends State<_ReaderParagraph> {
  /// Resolves a tap against the exact layout on screen — same font, same
  /// width, same line breaks — which a separately built `TextPainter` can
  /// disagree with.
  final _textKey = GlobalKey();

  TextStyle get _style => TextStyle(
        fontSize: widget.fontSize,
        height: widget.lineHeight,
        color: widget.textColor,
        letterSpacing: 0.2,
      );

  /// The word under a tap, as its `WordModel` plus its chapter-wide
  /// `[start, end)` range. Null when the tap missed the text or landed on
  /// whitespace between words.
  ({WordModel word, int start, int end})? _wordAt(Offset localPosition) {
    final renderParagraph =
        _textKey.currentContext?.findRenderObject() as RenderParagraph?;
    if (renderParagraph == null) return null;

    final text = widget.paragraph.text;
    final position = renderParagraph.getPositionForOffset(localPosition);
    final index = position.offset;
    if (index < 0 || index >= text.length) return null;

    // Expand the character to the full whitespace-delimited word.
    var start = index;
    while (start > 0 && !_isWhitespace(text.codeUnitAt(start - 1))) {
      start--;
    }
    var end = index;
    while (end < text.length && !_isWhitespace(text.codeUnitAt(end))) {
      end++;
    }
    if (end <= start) return null;

    // The paragraph text is exactly its words joined by single spaces, so a
    // local character offset maps straight back onto the source word list.
    final word = _sourceWordAt(start);
    if (word == null) return null;

    final base = widget.paragraph.startOffset;
    return (word: word, start: base + start, end: base + end);
  }

  /// Finds which source word a local character offset falls in.
  WordModel? _sourceWordAt(int localOffset) {
    var cursor = 0;
    for (final word in widget.source.words) {
      final end = cursor + word.text.length;
      if (localOffset < end) return word;
      cursor = end + 1; // +1 for the joining space
    }
    return widget.source.words.isEmpty ? null : widget.source.words.last;
  }

  bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0xA0;

  /// The part of the controller's highlight that falls inside this paragraph,
  /// in paragraph-local offsets. Null when the highlight is elsewhere (or
  /// absent), which is the value that keeps unrelated paragraphs from
  /// rebuilding.
  ({int start, int end})? _localHighlightRange() {
    return widget.playback.highlightRange;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.playback,
      builder: (context, _) {
        final global = _localHighlightRange();

        // Clip the chapter-wide range to this paragraph; `null` (not a
        // zero-length range) when it doesn't overlap, so the common case
        // stays a plain Text.
        int? start;
        int? end;
        if (global != null) {
          final overlapStart = global.start < widget.paragraph.startOffset
              ? widget.paragraph.startOffset
              : (global.start > widget.paragraph.endOffset
                  ? widget.paragraph.endOffset
                  : global.start);
          final overlapEnd = global.end > widget.paragraph.endOffset
              ? widget.paragraph.endOffset
              : (global.end < widget.paragraph.startOffset
                  ? widget.paragraph.startOffset
                  : global.end);
          if (overlapEnd > overlapStart) {
            start = overlapStart - widget.paragraph.startOffset;
            end = overlapEnd - widget.paragraph.startOffset;
          }
        }

        final text = widget.paragraph.text;
        final Widget textWidget;
        if (start == null || end == null) {
          textWidget = Text(text, style: _style, key: _textKey);
        } else {
          textWidget = Text.rich(
            TextSpan(
              style: _style,
              children: [
                TextSpan(text: text.substring(0, start)),
                TextSpan(
                  text: text.substring(start, end),
                  style: _style.copyWith(
                    color: widget.highlightColor,
                    backgroundColor:
                        widget.highlightColor.withValues(alpha: 0.25),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: text.substring(end)),
              ],
            ),
            key: _textKey,
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final hit = _wordAt(details.localPosition);
            if (hit == null) return;
            widget.onWordTap(hit.word, hit.start, hit.end);
          },
          onLongPressStart: (details) {
            final hit = _wordAt(details.localPosition);
            if (hit == null) return;
            widget.onWordLongPress(hit.word);
          },
          child: textWidget,
        );
      },
    );
  }
}
