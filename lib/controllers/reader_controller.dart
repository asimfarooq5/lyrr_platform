import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/paragraph.dart';
import '../models/sync_word.dart';
import '../services/book_repository.dart';
import '../services/sync_engine.dart';
import 'player_controller.dart';

abstract class ReaderItem {}

class ChapterHeaderItem extends ReaderItem {
  final Chapter chapter;
  final int chapterIndex;
  ChapterHeaderItem(this.chapter, this.chapterIndex);
}

class ParagraphItem extends ReaderItem {
  final Paragraph paragraph;
  final int chapterIndex;
  final int paragraphIndex;
  ParagraphItem(this.paragraph, this.chapterIndex, this.paragraphIndex);
}

class WordLocation {
  final int flatIndex;
  final int wordIndex;
  WordLocation(this.flatIndex, this.wordIndex);
}

enum ReaderThemeMode { light, dark, sepia }

class ReaderController extends ChangeNotifier {
  final BookRepository _bookRepository;

  Book? _book;
  SyncEngine? _syncEngine;
  String? _activeWordId;
  bool _isLoading = false;

  double _fontSize = 20.0;
  double _lineSpacing = 1.4;
  ReaderThemeMode _themeMode = ReaderThemeMode.dark;

  final List<ReaderItem> _flatItems = [];
  final Map<String, WordLocation> _wordLocations = {};
  final Map<String, SyncWord> _syncWordsMap = {};

  int? _lastScrolledFlatIndex;
  PlayerController? _playerController;

  ReaderController({BookRepository? bookRepository})
      : _bookRepository = bookRepository ?? BookRepository();

  Book? get book => _book;
  String? get activeWordId => _activeWordId;
  bool get isLoading => _isLoading;
  double get fontSize => _fontSize;
  double get lineSpacing => _lineSpacing;
  ReaderThemeMode get themeMode => _themeMode;
  List<ReaderItem> get flatItems => _flatItems;
  Map<String, WordLocation> get wordLocations => _wordLocations;

  void attachPlayerController(PlayerController playerController) {
    _playerController?.removeListener(_onPlayerPositionChanged);
    _playerController = playerController;
    _playerController?.addListener(_onPlayerPositionChanged);
  }

  void _onPlayerPositionChanged() {
    if (_playerController == null) return;
    _updatePosition(_playerController!.position);
  }

  Future<void> loadBookData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _book = await _bookRepository.loadBook();
      final syncData = await _bookRepository.loadSyncData();
      _syncEngine = SyncEngine(syncData);
      _syncWordsMap.clear();
      for (var sw in syncData) _syncWordsMap[sw.id] = sw;
      _flatItems.clear();
      _wordLocations.clear();
      int flatIndex = 0;
      for (int c = 0; c < _book!.chapters.length; c++) {
        final chapter = _book!.chapters[c];
        _flatItems.add(ChapterHeaderItem(chapter, c));
        flatIndex++;
        for (int p = 0; p < chapter.paragraphs.length; p++) {
          final paragraph = chapter.paragraphs[p];
          _flatItems.add(ParagraphItem(paragraph, c, p));
          for (int w = 0; w < paragraph.words.length; w++) {
            final word = paragraph.words[w];
            _wordLocations[word.id] = WordLocation(flatIndex, w);
          }
          flatIndex++;
        }
      }
    } catch (e) {
      debugPrint('Error loading book: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updatePosition(Duration position) {
    if (_syncEngine == null) return;
    final posInSeconds = position.inMilliseconds / 1000.0;
    final activeId = _syncEngine!.getActiveWordId(posInSeconds);
    if (activeId != _activeWordId) {
      _activeWordId = activeId;
      notifyListeners();
    }
  }

  void triggerAutoScroll(ItemScrollController scrollController, ItemPositionsListener positionsListener) {
    if (_activeWordId == null) return;
    final location = _wordLocations[_activeWordId];
    if (location == null) return;
    final targetFlatIndex = location.flatIndex;
    if (_lastScrolledFlatIndex == targetFlatIndex) return;
    final positions = positionsListener.itemPositions.value;
    bool isVisible = false;
    for (var pos in positions) {
      if (pos.index == targetFlatIndex && pos.itemLeadingEdge >= 0.05 && pos.itemTrailingEdge <= 0.95) {
        isVisible = true;
        break;
      }
    }
    if (!isVisible) {
      _lastScrolledFlatIndex = targetFlatIndex;
      scrollController.scrollTo(index: targetFlatIndex, duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic, alignment: 0.3);
    }
  }

  void seekToWord(String wordId) {
    final syncWord = _syncWordsMap[wordId];
    if (syncWord != null && _playerController != null) {
      _playerController!.seek(Duration(milliseconds: (syncWord.start * 1000).round()));
      _activeWordId = wordId;
      notifyListeners();
    }
  }

  void increaseFontSize() { _fontSize = (_fontSize + 2.0).clamp(12.0, 36.0); notifyListeners(); }
  void decreaseFontSize() { _fontSize = (_fontSize - 2.0).clamp(12.0, 36.0); notifyListeners(); }
  void setLineSpacing(double spacing) { _lineSpacing = spacing.clamp(1.0, 2.5); notifyListeners(); }
  void setThemeMode(ReaderThemeMode mode) { _themeMode = mode; notifyListeners(); }

  @override
  void dispose() {
    _playerController?.removeListener(_onPlayerPositionChanged);
    super.dispose();
  }
}
