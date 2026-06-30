/// Reader Screen
/// 
/// Main reading interface with synchronized audio playback,
/// bookmarks, notes, and all enterprise features

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
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
  
  // UI State
  bool _isLoading = true;
  String? _error;
  int _currentChapterIndex = 0;
  String? _currentWordId;
  bool _showControls = true;
  bool _isFullscreen = false;
  
  // Settings
  double _fontSize = 18.0;
  double _lineHeight = 1.6;
  String _theme = 'system';
  double _playbackSpeed = 1.0;
  bool _autoScroll = true;
  Color _highlightColor = AppColors.primary;
  
  // Scroll
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _wordKeys = {};
  
  // Sync
  Timer? _syncTimer;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _loadBook();
    _setupAudioListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    _syncTimer?.cancel();
    _progressTimer?.cancel();
    _saveProgress();
    super.dispose();
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

  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final booksRepo = ref.read(booksRepositoryProvider);
      final userDataRepo = ref.read(userDataRepositoryProvider);
      final db = ref.read(databaseProvider);

      // Load book details
      final bookData = await booksRepo.getBook(widget.bookId);
      if (bookData != null) {
        _book = BookModel.fromJson(bookData);
      }

      // Load chapters
      final chaptersData = await booksRepo.getBookContent(widget.bookId);
      _chapters = chaptersData.map((c) => ChapterModel.fromJson(c)).toList();

      // Load sync data
      final syncData = await booksRepo.getBookSync(widget.bookId);
      _syncData = syncData.map((s) => SyncWordModel.fromJson(s)).toList();

      // Load bookmarks and notes
      final bookmarksData = await userDataRepo.getBookmarks(widget.bookId);
      _bookmarks = bookmarksData.map((b) => BookmarkModel.fromJson(b)).toList();

      final notesData = await userDataRepo.getNotes(widget.bookId);
      _notes = notesData.map((n) => NoteModel.fromJson(n)).toList();

      // Load progress
      final progressData = await userDataRepo.getProgress(widget.bookId);
      if (progressData != null) {
        _progress = ReadingProgressModel.fromJson(progressData);
        _currentChapterIndex = _getChapterIndexForWord(_progress!.wordId);
      }

      // Load audio
      await _loadAudio();

      setState(() {
        _isLoading = false;
      });

      // Start progress tracking
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _saveProgress();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load book: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAudio() async {
    try {
      // Get DRM license
      final drmService = ref.read(drmServiceProvider);
      final license = await drmService.getLicense(widget.bookId);
      
      if (license?.downloadUrl != null) {
        await _audioPlayer.setUrl(license!.downloadUrl!);
      }
    } catch (e) {
      // Audio loading failed, continue without audio
    }
  }

  int _getChapterIndexForWord(String? wordId) {
    if (wordId == null || _chapters.isEmpty) return 0;
    
    for (int i = 0; i < _chapters.length; i++) {
      final words = _chapters[i].allWords;
      if (words.any((w) => w.id == wordId)) {
        return i;
      }
    }
    return 0;
  }

  void _syncTextToAudio(double positionSeconds) {
    if (_syncData.isEmpty) return;

    // Binary search for current word
    final word = _findWordAtPosition(positionSeconds);
    if (word != null && word.id != _currentWordId) {
      setState(() {
        _currentWordId = word.id;
      });

      if (_autoScroll) {
        _scrollToWord(word.id);
      }
    }
  }

  SyncWordModel? _findWordAtPosition(double position) {
    if (_syncData.isEmpty) return null;

    int left = 0;
    int right = _syncData.length - 1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final word = _syncData[mid];

      if (position >= word.start && position < word.end) {
        return word;
      } else if (position < word.start) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    return null;
  }

  void _scrollToWord(String wordId) {
    final key = _wordKeys[wordId];
    if (key != null) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> _seekToWord(String wordId) async {
    final syncWord = _syncData.firstWhere(
      (s) => s.id == wordId,
      orElse: () => null as SyncWordModel,
    );
    
    if (syncWord != null) {
      await _audioPlayer.seek(Duration(
        milliseconds: (syncWord.start * 1000).round(),
      ));
    }
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
      // Save locally for later sync
      final syncService = ref.read(syncServiceProvider);
      await syncService.updateProgress(updatedProgress);
    }
  }

  double _calculateProgressPercent() {
    if (_chapters.isEmpty) return 0.0;
    
    final totalWords = _chapters.fold<int>(
      0, 
      (sum, ch) => sum + ch.allWords.length,
    );
    
    if (totalWords == 0) return 0.0;
    
    int wordsBeforeCurrentChapter = 0;
    for (int i = 0; i < _currentChapterIndex; i++) {
      wordsBeforeCurrentChapter += _chapters[i].allWords.length;
    }
    
    final currentChapterWords = _chapters[_currentChapterIndex].allWords;
    int currentWordIndex = 0;
    
    if (_currentWordId != null) {
      currentWordIndex = currentChapterWords.indexWhere(
        (w) => w.id == _currentWordId,
      );
      if (currentWordIndex < 0) currentWordIndex = 0;
    }
    
    final totalReadWords = wordsBeforeCurrentChapter + currentWordIndex;
    return (totalReadWords / totalWords * 100).clamp(0.0, 100.0);
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
      final userDataRepo = ref.read(userDataRepositoryProvider);
      final syncService = ref.read(syncServiceProvider);
      final user = ref.read(currentUserProvider);

      try {
        if (result['delete'] == true) {
          // Delete bookmark
          final existing = _bookmarks.firstWhere(
            (b) => b.wordId == _currentWordId,
            orElse: () => null as BookmarkModel,
          );
          if (existing != null) {
            // TODO: Delete via API
            setState(() {
              _bookmarks.removeWhere((b) => b.id == existing.id);
            });
          }
        } else {
          // Create/update bookmark
          final bookmark = await syncService.createBookmark(
            userId: user!.id,
            bookId: widget.bookId,
            wordId: _currentWordId!,
            chapterId: _chapters[_currentChapterIndex].id,
            positionSeconds: _currentPosition.inMilliseconds / 1000.0,
            note: result['note'],
            color: result['color'],
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
          // Delete note
          setState(() {
            _notes.removeWhere((n) => n.wordId == _currentWordId);
          });
        } else {
          // Create/update note
          final note = await syncService.createNote(
            userId: user!.id,
            bookId: widget.bookId,
            wordId: _currentWordId!,
            content: result,
            chapterId: _chapters[_currentChapterIndex].id,
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

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        theme: _theme,
        playbackSpeed: _playbackSpeed,
        autoScroll: _autoScroll,
        highlightColor: _highlightColor,
        onFontSizeChanged: (value) => setState(() => _fontSize = value),
        onLineHeightChanged: (value) => setState(() => _lineHeight = value),
        onThemeChanged: (value) => setState(() => _theme = value),
        onPlaybackSpeedChanged: (value) {
          setState(() => _playbackSpeed = value);
          _audioPlayer.setSpeed(value);
        },
        onAutoScrollChanged: (value) => setState(() => _autoScroll = value),
        onHighlightColorChanged: (value) => setState(() => _highlightColor = value),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              ElevatedButton(
                onPressed: _loadBook,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _theme == 'dark' ? Colors.black : Colors.white,
      appBar: _isFullscreen
          ? null
          : AppBar(
              title: Text(_book?.title ?? 'Reader'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  onPressed: _addBookmark,
                ),
                IconButton(
                  icon: const Icon(Icons.note_add_outlined),
                  onPressed: _addNote,
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: _showSettings,
                ),
                IconButton(
                  icon: Icon(_isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen),
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
      body: Column(
        children: [
          // Text content
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: _buildContent(),
            ),
          ),
          
          // Audio controls
          if (_showControls) ...[
            AudioControls(
              isPlaying: _isPlaying,
              currentPosition: _currentPosition,
              totalDuration: _totalDuration,
              playbackSpeed: _playbackSpeed,
              onPlayPause: _togglePlayPause,
              onSeek: (position) => _audioPlayer.seek(position),
              onSpeedChange: (speed) {
                setState(() => _playbackSpeed = speed);
                _audioPlayer.setSpeed(speed);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_chapters.isEmpty) {
      return const Center(child: Text('No content available'));
    }

    final chapter = _chapters[_currentChapterIndex];

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chapter title
          Text(
            chapter.title,
            style: TextStyle(
              fontSize: _fontSize * 1.5,
              fontWeight: FontWeight.bold,
              color: _theme == 'dark' ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          
          // Paragraphs
          ...chapter.paragraphs.map((paragraph) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildParagraph(paragraph),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildParagraph(ParagraphModel paragraph) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: _fontSize,
          height: _lineHeight,
          color: _theme == 'dark' ? Colors.white : Colors.black,
        ),
        children: paragraph.words.map((word) {
          final isCurrentWord = word.id == _currentWordId;
          final hasBookmark = _bookmarks.any((b) => b.wordId == word.id);
          final hasNote = _notes.any((n) => n.wordId == word.id);

          // Create key for this word if not exists
          _wordKeys.putIfAbsent(word.id, () => GlobalKey());

          return WordSpan(
            wordData: word,
            isHighlighted: isCurrentWord,
            hasBookmark: hasBookmark,
            hasNote: hasNote,
            highlightColor: isCurrentWord ? _highlightColor : null,
            onTap: () => _seekToWord(word.id),
          );
        }).toList(),
      ),
    );
  }
}
