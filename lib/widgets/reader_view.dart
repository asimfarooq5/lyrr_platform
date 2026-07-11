import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../controllers/reader_controller.dart';
import '../theme/app_theme.dart';
import 'highlighted_word.dart';
import '../features/reader/widgets/highlight_menu.dart';
import '../data/models/highlight.dart' show highlightColorValues;

class ReaderView extends StatefulWidget {
  const ReaderView({super.key});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> with SingleTickerProviderStateMixin {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener = ItemPositionsListener.create();
  late ReaderController _readerController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final Map<String, String> _highlightColors = {};
  bool _showHighlightMenu = false;
  String _selectedText = '';

  @override
  void initState() {
    super.initState();
    _readerController = context.read<ReaderController>();
    _readerController.addListener(_onActiveWordChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  void _onActiveWordChanged() {
    if (!mounted) return;
    _readerController.triggerAutoScroll(_scrollController, _positionsListener);
  }

  void _onHighlightColorSelected(String color) {
    setState(() => _showHighlightMenu = false);
  }

  @override
  void dispose() {
    _readerController.removeListener(_onActiveWordChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readerController = context.watch<ReaderController>();
    final colors = ReaderColors.of(readerController.themeMode);
    final flatItems = readerController.flatItems;

    if (readerController.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (flatItems.isEmpty) {
      return Center(child: Text('No book content loaded.', style: TextStyle(color: colors.textSecondary)));
    }

    return Container(
      color: colors.background,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return ScrollablePositionedList.builder(
                itemCount: flatItems.length,
                itemScrollController: _scrollController,
                itemPositionsListener: _positionsListener,
                padding: const EdgeInsets.only(top: 24.0, bottom: 200.0),
                itemBuilder: (context, index) {
                  final item = flatItems[index];
                  if (item is ChapterHeaderItem) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (item.chapterIndex > 0) Divider(color: colors.dividerColor, height: 48, thickness: 1),
                        Text(item.chapter.title,
                            style: TextStyle(fontSize: readerController.fontSize * 1.35,
                                fontWeight: FontWeight.bold, color: colors.text, fontFamily: 'Serif', letterSpacing: -0.5)),
                      ]),
                    );
                  } else if (item is ParagraphItem) {
                    return _ParagraphWidget(
                      item: item, fontSize: readerController.fontSize,
                      lineSpacing: readerController.lineSpacing, colors: colors,
                      highlightColors: _highlightColors, pulseValue: _pulseAnimation.value,
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
          if (_showHighlightMenu)
            Positioned(
              bottom: 220, left: 0, right: 0,
              child: Center(
                child: HighlightMenu(selectedText: _selectedText, onHighlight: _onHighlightColorSelected),
              ),
            ),
        ],
      ),
    );
  }
}

class _ParagraphWidget extends StatelessWidget {
  final ParagraphItem item;
  final double fontSize;
  final double lineSpacing;
  final ReaderColors colors;
  final Map<String, String> highlightColors;
  final double pulseValue;

  const _ParagraphWidget({
    required this.item, required this.fontSize, required this.lineSpacing,
    required this.colors, required this.highlightColors, required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ReaderController, String?>(
      selector: (_, controller) {
        for (var word in item.paragraph.words) {
          if (word.id == controller.activeWordId) return word.id;
        }
        return null;
      },
      builder: (context, activeWordIdInParagraph, _) {
        final controller = context.read<ReaderController>();
        final spans = item.paragraph.words.map((word) {
          final isActive = word.id == activeWordIdInParagraph;
          final highlightColor = highlightColors[word.id];
          return HighlightedWord.build(
            id: word.id, text: word.text, isActive: isActive,
            fontSize: fontSize, lineSpacing: lineSpacing,
            textColor: colors.text, activeTextColor: colors.highlightedText,
            activeBgColor: highlightColor != null
                ? (highlightColorValues[highlightColor] ?? colors.highlightedBackground)
                : colors.highlightedBackground,
            onTap: () => controller.seekToWord(word.id),
            pulseScale: isActive ? pulseValue : 0.0,
          );
        }).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: RichText(text: TextSpan(children: spans)),
        );
      },
    );
  }
}
