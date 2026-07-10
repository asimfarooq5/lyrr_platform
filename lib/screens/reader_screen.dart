import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';
import '../controllers/reader_controller.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/player_controls.dart';
import '../widgets/progress_bar.dart';
import '../widgets/reader_view.dart';
import '../data/models/bookmark.dart';
import '../data/datasources/local/hive_database.dart';
import '../data/models/reading_progress.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late PlayerController _playerController;
  late ReaderController _readerController;
  bool _isBookmarked = false;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    _playerController = context.read<PlayerController>();
    _readerController = context.read<ReaderController>();
    _readerController.attachPlayerController(_playerController);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeReader());
  }

  Future<void> _initializeReader() async {
    try {
      // Load book data first
      if (_readerController.book == null || _readerController.flatItems.isEmpty) {
        await _readerController.loadBookData();
        debugPrint('Book loaded: ${_readerController.book != null}');
        if (_readerController.flatItems.isNotEmpty) {
          debugPrint('Items count: ${_readerController.flatItems.length}');
        }
      }

      if (!mounted) return;

      // Load audio
      await _playerController.loadAudio(AppConstants.audioPath);
      debugPrint('Audio loaded');

      // Restore progress
      await _restoreReadingProgress();

      setState(() => _initFailed = false);
    } catch (e) {
      debugPrint('Reader init failed: $e');
      if (mounted) setState(() => _initFailed = true);
    }
  }

  Future<void> _restoreReadingProgress() async {
    final book = _readerController.book;
    if (book == null) return;

    final savedProgress = HiveDatabase.progressBox.get(
      book.metadata.id.toString(),
    );
    if (savedProgress == null || savedProgress.positionSeconds <= 0) return;

    await _playerController.seek(
      Duration(milliseconds: (savedProgress.positionSeconds * 1000).round()),
    );
  }

  @override
  void dispose() {
    _saveReadingProgress();
    _playerController.pause();
    super.dispose();
  }

  void _saveReadingProgress() {
    if (_readerController.book == null) return;
    final progress = _playerController.position.inMilliseconds / 1000;
    final total = _playerController.duration.inMilliseconds / 1000;
    final pct = total > 0 ? progress / total : 0.0;

    final rp = ReadingProgress(
      bookId: _readerController.book!.metadata.id.toString(),
      chapterId: '',
      paragraphIndex: 0,
      wordIndex: 0,
      positionSeconds: progress,
      progress: pct,
    );
    HiveDatabase.progressBox.put(rp.bookId, rp);
  }

  void _toggleBookmark() {
    if (_readerController.book == null || _readerController.activeWordId == null) return;
    if (_isBookmarked) return;

    final wordLocation = _readerController.wordLocations[_readerController.activeWordId];
    final bookmark = Bookmark(
      bookId: _readerController.book!.metadata.id.toString(),
      chapterId: '',
      paragraphIndex: wordLocation?.flatIndex ?? 0,
      wordIndex: wordLocation?.wordIndex ?? 0,
      previewText: 'At word: ${_readerController.activeWordId}',
    );
    HiveDatabase.bookmarksBox.put(bookmark.id, bookmark);
    setState(() => _isBookmarked = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmark added'), duration: Duration(seconds: 1)),
    );
  }

  void _showChapterNav() {
    final book = _readerController.book;
    if (book == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.only(top: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF161823),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Text('Chapters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                Text('${book.chapters.length} chapters', style: TextStyle(color: Colors.grey[400])),
              ]),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: book.chapters.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                itemBuilder: (context, index) {
                  final chapter = book.chapters[index];
                  return ListTile(
                    leading: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                    ),
                    title: Text(chapter.title, style: const TextStyle(color: Colors.white)),
                    onTap: () { Navigator.pop(context); /* TODO: scroll */ },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final controller = context.watch<ReaderController>();
            final colors = ReaderColors.of(controller.themeMode);

            return Container(
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Reader Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: Icon(Icons.close, color: colors.textSecondary), onPressed: () => Navigator.pop(context)),
                  ]),
                  const SizedBox(height: 12),
                  Divider(color: colors.dividerColor, height: 1),
                  const SizedBox(height: 24),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Speed', style: TextStyle(color: colors.text)),
                    Row(children: [0.5, 1.0, 1.5, 2.0].map((s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => _playerController.setSpeed(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _playerController.audioService.speed == s
                                ? Theme.of(context).colorScheme.primary : colors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.dividerColor),
                          ),
                          child: Text('${s}x', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )).toList()),
                  ]),
                  const SizedBox(height: 20),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Font Size', style: TextStyle(color: colors.text)),
                    Row(children: [
                      IconButton(icon: Icon(Icons.remove_circle_outline, color: colors.text), onPressed: () { controller.decreaseFontSize(); setModalState(() {}); }),
                      Text('${controller.fontSize.toInt()} px', style: TextStyle(fontWeight: FontWeight.bold, color: colors.text)),
                      IconButton(icon: Icon(Icons.add_circle_outline, color: colors.text), onPressed: () { controller.increaseFontSize(); setModalState(() {}); }),
                    ]),
                  ]),
                  const SizedBox(height: 20),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Line Spacing', style: TextStyle(color: colors.text)),
                    Row(children: [
                      _spacingBtn(context, controller, 1.2, 'Narrow', colors),
                      const SizedBox(width: 8),
                      _spacingBtn(context, controller, 1.5, 'Normal', colors),
                      const SizedBox(width: 8),
                      _spacingBtn(context, controller, 1.8, 'Wide', colors),
                    ]),
                  ]),
                  const SizedBox(height: 28),

                  Text('Color Theme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.text)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _themeTile(context, controller, ReaderThemeMode.light, 'Light', AppTheme.lightBg, AppTheme.lightTextPrimary),
                    _themeTile(context, controller, ReaderThemeMode.sepia, 'Sepia', AppTheme.sepiaBg, AppTheme.sepiaTextPrimary),
                    _themeTile(context, controller, ReaderThemeMode.dark, 'Dark', AppTheme.darkBg, AppTheme.darkTextPrimary),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _spacingBtn(BuildContext context, ReaderController controller, double spacing, String label, ReaderColors colors) {
    final isSelected = (controller.lineSpacing - spacing).abs() < 0.05;
    return GestureDetector(
      onTap: () => controller.setLineSpacing(spacing),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : colors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : colors.dividerColor),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : colors.text, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _themeTile(BuildContext context, ReaderController controller, ReaderThemeMode mode, String label, Color bg, Color fg) {
    final isSelected = controller.themeMode == mode;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => controller.setThemeMode(mode),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.28,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryColor : Colors.grey[800]!, width: isSelected ? 2 : 1),
        ),
        child: Column(children: [
          Text('Aa', style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Serif')),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: fg.withOpacity(0.8), fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readerController = context.watch<ReaderController>();

    if (_initFailed) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0C10),
        appBar: AppBar(backgroundColor: const Color(0xFF0B0C10), elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context))),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load book', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: () { setState(() => _initFailed = false); _initializeReader(); },
              child: const Text('Retry')),
          ]),
        ),
      );
    }

    final colors = ReaderColors.of(readerController.themeMode);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.text), onPressed: () => Navigator.pop(context)),
        title: Text(readerController.book?.metadata.title ?? 'Reader',
            style: TextStyle(color: colors.text, fontFamily: 'Serif', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? const Color(0xFF6366F1) : colors.text), onPressed: _toggleBookmark),
          IconButton(icon: Icon(Icons.list_alt_rounded, color: colors.text), onPressed: _showChapterNav),
          IconButton(icon: Icon(Icons.text_fields_rounded, color: colors.text), onPressed: () => _showSettingsBottomSheet(context)),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ReaderView()),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: colors.cardBackground.withOpacity(0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.dividerColor.withOpacity(0.5), width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                ProgressBar(),
                SizedBox(height: 8),
                PlayerControls(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
