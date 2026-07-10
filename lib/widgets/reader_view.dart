import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../controllers/reader_controller.dart';
import '../theme/app_theme.dart';
import 'highlighted_word.dart';

class ReaderView extends StatefulWidget {
  const ReaderView({super.key});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener = ItemPositionsListener.create();
  late ReaderController _readerController;

  @override
  void initState() {
    super.initState();
    _readerController = context.read<ReaderController>();
    _readerController.addListener(_onActiveWordChanged);
  }

  void _onActiveWordChanged() {
    if (!mounted) return;
    _readerController.triggerAutoScroll(_scrollController, _positionsListener);
  }

  @override
  void dispose() {
    _readerController.removeListener(_onActiveWordChanged);
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
      child: ScrollablePositionedList.builder(
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
            return _ParagraphWidget(item: item, fontSize: readerController.fontSize,
                lineSpacing: readerController.lineSpacing, colors: colors);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ParagraphWidget extends StatelessWidget {
  final ParagraphItem item;
  final double fontSize;
  final double lineSpacing;
  final ReaderColors colors;

  const _ParagraphWidget({required this.item, required this.fontSize, required this.lineSpacing, required this.colors});

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
          return HighlightedWord.build(
            id: word.id, text: word.text, isActive: isActive,
            fontSize: fontSize, lineSpacing: lineSpacing,
            textColor: colors.text, activeTextColor: colors.highlightedText,
            activeBgColor: colors.highlightedBackground,
            onTap: () => controller.seekToWord(word.id),
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
