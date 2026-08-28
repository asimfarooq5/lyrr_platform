/// Reader Screen
/// Amazon Kindle-inspired reading experience with page-turning taps,
/// minimal chrome, progress bar, time remaining, and Aa settings

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/book_model.dart';
import '../../../data/models/user_data_model.dart';
import '../../../data/services/drm_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/word_span.dart';
import 'widgets/audio_controls.dart';
import 'widgets/bookmark_dialog.dart';
import 'widgets/note_dialog.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/chapter_list_drawer.dart';

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
  
  // TTS (Text-to-Speech)
  final FlutterTts _tts = FlutterTts();
  bool _isTtsPlaying = false;
  bool _isTtsMode = false;
  int _ttsParagraphIndex = 0;
  int _ttsWordIndex = 0;
  
  // UI State
  bool _isLoading = true;
  String? _error;
  int _currentChapterIndex = 0;
  String? _currentWordId;
  bool _showControls = false; // Kindle-style: hidden by default
  bool _isFullscreen = false;
  bool _showBookmarksDrawer = false;
  
  // Kindle Reading Settings
  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  double _margin = 24.0;
  ReadingMode _readingMode = ReadingMode.light;
  double _playbackSpeed = 1.0;
  bool _autoScroll = true;
  Color _highlightColor = AppColors.primary;
  bool _showTimeRemaining = true;
  bool _showPageNumber = true;
  
  // Reading speed tracking for time remaining (words per minute)
  double _readingSpeed = 250; // Average adult reading speed
  int _wordsReadThisSession = 0;
  DateTime _sessionStart = DateTime.now();
  
  // Scroll
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _wordKeys = {};
  double _scrollPercent = 0.0;
  double _previousScrollPercent = 0.0;
  
  // Tap feedback
  bool _showTapFeedback = false;
  Offset _tapPosition = Offset.zero;
  
  // Sync
  Timer? _syncTimer;
  Timer? _progressTimer;

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

  Color get _readingSubtextColor {
    if (_readingMode == ReadingMode.dark) return AppColors.textSecondaryDark;
    return AppColors.textSecondaryLight;
  }
  
  @override
  void initState() {
    super.initState();
    _loadBook();
    _setupAudioListeners();
    _setupTtsListeners();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _tts.stop();
    _scrollController.dispose();
    _syncTimer?.cancel();
    _progressTimer?.cancel();
    _saveProgress();
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
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _currentPosition = position;
      });
      _syncTextToAudio(position.inMilliseconds / 1000.0);
    });

    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  void _setupTtsListeners() {
    _tts.setCompletionHandler(() {
      _onTtsParagraphComplete();
    });

    _tts.setProgressHandler((String text, int startOffset, int endOffset, String word) {
      _onTtsWordProgress(word);
    });

    _tts.setErrorHandler((msg) {
      setState(() {
        _isTtsPlaying = false;
        _isTtsMode = false;
      });
    });
  }

  void _onTtsWordProgress(String word) {
    if (_chapters.isEmpty) return;
    final chapter = _chapters[_currentChapterIndex];
    if (_ttsParagraphIndex >= chapter.paragraphs.length) return;

    final paragraph = chapter.paragraphs[_ttsParagraphIndex];
    // Search forward from current position for matching word
    for (int i = _ttsWordIndex; i < paragraph.words.length; i++) {
      if (paragraph.words[i].text.toLowerCase() == word.toLowerCase()) {
        setState(() {
          _currentWordId = paragraph.words[i].id;
          _ttsWordIndex = i + 1;
        });
        if (_autoScroll) _scrollToWord(paragraph.words[i].id);
        return;
      }
    }
    // Fallback: try searching from beginning of paragraph
    for (int i = 0; i < _ttsWordIndex && i < paragraph.words.length; i++) {
      if (paragraph.words[i].text.toLowerCase() == word.toLowerCase()) {
        setState(() {
          _currentWordId = paragraph.words[i].id;
          _ttsWordIndex = i + 1;
        });
        if (_autoScroll) _scrollToWord(paragraph.words[i].id);
        return;
      }
    }
  }

  void _onTtsParagraphComplete() {
    if (_chapters.isEmpty) return;
    final chapter = _chapters[_currentChapterIndex];
    _ttsParagraphIndex++;

    if (_ttsParagraphIndex < chapter.paragraphs.length) {
      // Read next paragraph
      _ttsWordIndex = 0;
      final text = chapter.paragraphs[_ttsParagraphIndex].fullText;
      _tts.speak(text);
    } else if (_currentChapterIndex < _chapters.length - 1) {
      // Move to next chapter
      setState(() {
        _currentChapterIndex++;
        _ttsParagraphIndex = 0;
        _ttsWordIndex = 0;
      });
      if (mounted) _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
      final nextChapter = _chapters[_currentChapterIndex];
      if (nextChapter.paragraphs.isNotEmpty) {
        _tts.speak(nextChapter.paragraphs[0].fullText);
      }
    } else {
      // Finished reading the whole book
      setState(() {
        _isTtsPlaying = false;
        _isTtsMode = false;
        _ttsParagraphIndex = 0;
        _ttsWordIndex = 0;
        _currentWordId = null;
      });
    }
  }

  String _ttsLanguageCode(String? lang) {
    switch (lang?.toLowerCase()) {
      case 'fr': return 'fr-FR';
      case 'es': return 'es-ES';
      case 'de': return 'de-DE';
      case 'it': return 'it-IT';
      case 'pt': return 'pt-PT';
      case 'ru': return 'ru-RU';
      case 'ja': return 'ja-JP';
      case 'zh': return 'zh-CN';
      case 'ar': return 'ar-SA';
      default: return 'en-US';
    }
  }

  Future<void> _startTts() async {
    if (_chapters.isEmpty) return;

    // Pause audiobook if playing
    if (_isPlaying) {
      await _audioPlayer.pause();
    }

    // Find the first visible paragraph based on scroll position
    final chapter = _chapters[_currentChapterIndex];
    if (chapter.paragraphs.isEmpty) return;

    // Estimate which paragraph is visible based on scroll percent
    _ttsParagraphIndex = (_scrollPercent * chapter.paragraphs.length).floor().clamp(0, chapter.paragraphs.length - 1);
    _ttsWordIndex = 0;

    await _tts.setLanguage(_ttsLanguageCode(_book?.language));
    await _tts.setSpeechRate(_playbackSpeed);

    setState(() {
      _isTtsMode = true;
      _isTtsPlaying = true;
    });

    final text = chapter.paragraphs[_ttsParagraphIndex].fullText;
    await _tts.speak(text);
  }

  Future<void> _stopTts() async {
    await _tts.stop();
    setState(() {
      _isTtsPlaying = false;
      _isTtsMode = false;
      _ttsParagraphIndex = 0;
      _ttsWordIndex = 0;
      _currentWordId = null;
    });
  }

  Future<void> _toggleTts() async {
    if (_isTtsPlaying) {
      await _stopTts();
    } else {
      await _startTts();
    }
  }

  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final booksRepo = ref.read(booksRepositoryProvider);
      final userDataRepo = ref.read(userDataRepositoryProvider);
      final db = ref.read(databaseProvider);

      final bookData = await booksRepo.getBook(widget.bookId);
      if (bookData != null) {
        _book = BookModel.fromJson(bookData);
      }

      final chaptersData = await booksRepo.getBookContent(widget.bookId);
      _chapters = chaptersData.map((c) => ChapterModel.fromJson(c)).toList();

      final syncData = await booksRepo.getBookSync(widget.bookId);
      _syncData = syncData.map((s) => SyncWordModel.fromJson(s)).toList();

      final bookmarksData = await userDataRepo.getBookmarks(widget.bookId);
      _bookmarks = bookmarksData.map((b) => BookmarkModel.fromJson(b)).toList();

      final notesData = await userDataRepo.getNotes(widget.bookId);
      _notes = notesData.map((n) => NoteModel.fromJson(n)).toList();

      final progressData = await userDataRepo.getProgress(widget.bookId);
      if (progressData != null) {
        _progress = ReadingProgressModel.fromJson(progressData);
        _currentChapterIndex = _getChapterIndexForWord(_progress!.wordId);
      }

      await _loadAudio();

      setState(() {
        _isLoading = false;
      });

      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _saveProgress();
        _trackReadingSpeed();
      });
    } catch (e) {
      setState(() {
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
    try {
      final drmService = ref.read(drmServiceProvider);
      final license = await drmService.getLicense(widget.bookId);
      if (license?.downloadUrl != null) {
        await _audioPlayer.setUrl(license!.downloadUrl!);
      }
    } catch (e) {
      // Continue without audio
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

  void _syncTextToAudio(double positionSeconds) {
    if (_syncData.isEmpty) return;
    final word = _findWordAtPosition(positionSeconds);
    if (word != null && word.id != _currentWordId) {
      setState(() { _currentWordId = word.id; });
      if (_autoScroll) _scrollToWord(word.id);
    }
  }

  SyncWordModel? _findWordAtPosition(double position) {
    if (_syncData.isEmpty) return null;
    int left = 0, right = _syncData.length - 1;
    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final word = _syncData[mid];
      if (position >= word.start && position < word.end) return word;
      if (position < word.start) right = mid - 1;
      else left = mid + 1;
    }
    return null;
  }

  void _scrollToWord(String wordId) {
    final key = _wordKeys[wordId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  // Kindle tap zones: left=prev, center=toggle menu, right=next
  void _handleTap(TapUpDetails details) {
    HapticFeedback.lightImpact();
    
    setState(() {
      _tapPosition = details.localPosition;
      _showTapFeedback = true;
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _showTapFeedback = false);
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.localPosition.dx;

    if (tapX < screenWidth * 0.3) {
      _goToPreviousChapter();
    } else if (tapX > screenWidth * 0.7) {
      _goToNextChapter();
    } else {
      setState(() { _showControls = !_showControls; });
    }
  }

  void _goToPreviousChapter() {
    if (_currentChapterIndex > 0) {
      setState(() {
        _currentChapterIndex--;
      });
      // Delay scroll reset until after AnimatedSwitcher transition
      Future.delayed(AppAnimations.slow, () {
        if (mounted) _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
      });
    }
  }

  void _goToNextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      setState(() {
        _currentChapterIndex++;
      });
      Future.delayed(AppAnimations.slow, () {
        if (mounted) _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
      });
    }
  }

  Future<void> _togglePlayPause() async {
    // Stop TTS if it's playing
    if (_isTtsPlaying) {
      await _stopTts();
    }
    if (_isPlaying) await _audioPlayer.pause();
    else await _audioPlayer.play();
  }

  Future<void> _seekToWord(String wordId) async {
    try {
      final syncWord = _syncData.firstWhere((s) => s.id == wordId);
      await _audioPlayer.seek(Duration(milliseconds: (syncWord.start * 1000).round()));
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    if (_progress == null) return;
    final userDataRepo = ref.read(userDataRepositoryProvider);
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
      final syncService = ref.read(syncServiceProvider);
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
    if (_currentWordId == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BookmarkDialog(
        wordId: _currentWordId!,
        existingBookmark: _bookmarks.firstWhere(
          (b) => b.wordId == _currentWordId,
          orElse: () => null as BookmarkModel,
        ),
      ),
    );
    if (result != null) {
      final syncService = ref.read(syncServiceProvider);
      final user = ref.read(currentUserProvider);
      try {
        if (result['delete'] == true) {
          setState(() { _bookmarks.removeWhere((b) => b.wordId == _currentWordId); });
        } else {
          final bookmark = await syncService.createBookmark(
            userId: user!.id, bookId: widget.bookId, wordId: _currentWordId!,
            chapterId: _chapters[_currentChapterIndex].id,
            positionSeconds: _currentPosition.inMilliseconds / 1000.0,
            note: result['note'], color: result['color'],
          );
          setState(() {
            _bookmarks.removeWhere((b) => b.wordId == _currentWordId);
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
    if (_currentWordId == null) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => NoteDialog(
        wordId: _currentWordId!,
        existingNote: _notes.firstWhere(
          (n) => n.wordId == _currentWordId,
          orElse: () => null as NoteModel,
        ),
      ),
    );
    if (result != null) {
      final syncService = ref.read(syncServiceProvider);
      final user = ref.read(currentUserProvider);
      try {
        if (result.isEmpty) {
          setState(() { _notes.removeWhere((n) => n.wordId == _currentWordId); });
        } else {
          final note = await syncService.createNote(
            userId: user!.id, bookId: widget.bookId, wordId: _currentWordId!,
            content: result, chapterId: _chapters[_currentChapterIndex].id,
          );
          setState(() {
            _notes.removeWhere((n) => n.wordId == _currentWordId);
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
        autoScroll: _autoScroll,
        highlightColor: _highlightColor,
        readingMode: _readingMode,
        onFontSizeChanged: (v) => setState(() => _fontSize = v),
        onLineHeightChanged: (v) => setState(() => _lineHeight = v),
        onThemeChanged: (v) {
          setState(() {
            switch (v) {
              case 'light': _readingMode = ReadingMode.light; break;
              case 'sepia': _readingMode = ReadingMode.sepia; break;
              case 'dark': _readingMode = ReadingMode.dark; break;
              case 'green': _readingMode = ReadingMode.green; break;
            }
          });
        },
        onPlaybackSpeedChanged: (v) {
          setState(() => _playbackSpeed = v);
          _audioPlayer.setSpeed(v);
        },
        onAutoScrollChanged: (v) => setState(() => _autoScroll = v),
        onHighlightColorChanged: (v) => setState(() => _highlightColor = v),
        onReadingModeChanged: (mode) => setState(() => _readingMode = mode),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() { _isFullscreen = !_isFullscreen; });
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
      backgroundColor: Colors.transparent,
      endDrawer: ChapterListDrawer(
        chapters: _chapters,
        currentChapterIndex: _currentChapterIndex,
        bookmarks: _bookmarks,
        onChapterSelected: (index) {
          setState(() { _currentChapterIndex = index; });
          Future.delayed(AppAnimations.slow, () {
            if (mounted) _scrollController.animateTo(0,
                duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
          });
        },
      ),
      body: AnimatedContainer(
        duration: AppAnimations.slow,
        color: _readingBg,
        child: Column(
          children: [
            // Top bar with slide + fade animation
            AnimatedSlide(
              offset: _showControls ? Offset.zero : const Offset(0, -1),
              duration: AppAnimations.fast,
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: AppAnimations.fast,
                child: _buildTopBar(),
              ),
            ),
            
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
            
            // Bottom bar with slide + fade animation
            AnimatedSlide(
              offset: _showControls ? Offset.zero : const Offset(0, 1),
              duration: AppAnimations.fast,
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: AppAnimations.fast,
                child: _buildBottomBar(),
              ),
            ),
            
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
              // Table of Contents
              IconButton(
                icon: const Icon(Icons.list),
                tooltip: 'Table of Contents',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
              // Aa settings
              IconButton(
                icon: const Icon(Icons.text_fields),
                tooltip: 'Font & Theme settings',
                onPressed: _showAaSettings,
              ),
              // Bookmarks
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                tooltip: 'Bookmarks',
                onPressed: _addBookmark,
              ),
              // Notes
              IconButton(
                icon: const Icon(Icons.note_add_outlined),
                tooltip: 'Add note',
                onPressed: _addNote,
              ),
              // Fullscreen
              IconButton(
                icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
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
            // Audio controls
            AudioControls(
              isPlaying: _isPlaying,
              currentPosition: _currentPosition,
              totalDuration: _totalDuration,
              playbackSpeed: _playbackSpeed,
              isTtsPlaying: _isTtsPlaying,
              isTtsMode: _isTtsMode,
              onPlayPause: _togglePlayPause,
              onSeek: (position) => _audioPlayer.seek(position),
              onSpeedChange: (speed) {
                setState(() => _playbackSpeed = speed);
                _audioPlayer.setSpeed(speed);
                if (_isTtsPlaying) _tts.setSpeechRate(speed);
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

    return Stack(
      children: [
        // Main text
        SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: _margin, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chapter title with accent bar (Kindle-style)
              Row(
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
                      child: Text(chapter.title),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _fontSize * 1.5),
              
              // Paragraphs
              ...chapter.paragraphs.map((paragraph) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildParagraph(paragraph),
                );
              }),

              // End of chapter decorative marker
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

              // Kindle-style page info
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
              
              // Time remaining
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
          ),
        ),

        // Kindle tap zone indicators (briefly shown on tap)
        if (_showControls)
          Row(
            children: [
              // Left zone indicator
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 16),
                  child: _currentChapterIndex > 0
                      ? Icon(Icons.chevron_left, color: _readingSubtextColor.withOpacity(0.3), size: 40)
                      : null,
                ),
              ),
              // Center zone
              Expanded(child: Container()),
              // Right zone indicator
              Expanded(
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: _currentChapterIndex < _chapters.length - 1
                      ? Icon(Icons.chevron_right, color: _readingSubtextColor.withOpacity(0.3), size: 40)
                      : null,
                ),
              ),
            ],
          ),

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

  Widget _buildParagraph(ParagraphModel paragraph) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: _fontSize,
          height: _lineHeight,
          color: _readingTextColor,
          letterSpacing: 0.2,
        ),
        children: paragraph.words.map((word) {
          final isCurrentWord = word.id == _currentWordId;
          final hasBookmark = _bookmarks.any((b) => b.wordId == word.id);
          final hasNote = _notes.any((n) => n.wordId == word.id);

          _wordKeys.putIfAbsent(word.id, () => GlobalKey());

          final isLast = paragraph.words.last.id == word.id;
          final wordText = isLast ? word.text : '${word.text} ';
          final textStyle = TextStyle(
            fontSize: _fontSize,
            height: _lineHeight,
            color: _readingTextColor,
            letterSpacing: 0.2,
          );

          // Use WidgetSpan for decorated words (highlight/bookmark/note)
          if (isCurrentWord || hasBookmark || hasNote) {
            return WordWidget(
              word: word,
              isHighlighted: isCurrentWord,
              hasBookmark: hasBookmark,
              hasNote: hasNote,
              highlightColor: isCurrentWord ? _highlightColor : null,
              onTap: () => _seekToWord(word.id),
              textStyle: textStyle,
              text: wordText,
            );
          }

          // Use lightweight TextSpan for neutral words
          return WordSpan(
            text: wordText,
            wordData: word,
            style: textStyle,
          );
        }).toList(),
      ),
    );
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
