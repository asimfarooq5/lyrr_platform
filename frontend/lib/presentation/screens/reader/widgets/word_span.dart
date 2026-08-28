/// Word Span Widget
/// 
/// Individual word with highlighting, bookmark, note indicators, and tap handling
/// Uses lightweight TextSpan for neutral words and WidgetSpan for decorated words

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:lyrr/data/models/book_model.dart';
import '../../../theme/app_theme.dart';

/// Lightweight TextSpan for neutral words (no highlight, no bookmark, no note)
class WordSpan extends TextSpan {
  final WordModel wordData;

  WordSpan({
    required this.wordData,
    required super.text,
    super.style,
  }) : super(
    recognizer: TapGestureRecognizer()..onTap = () {},
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordSpan &&
          runtimeType == other.runtimeType &&
          wordData.id == other.wordData.id &&
          text == other.text;

  @override
  int get hashCode => Object.hash(wordData.id, text);
}

/// WidgetSpan for words that need visual decoration (highlight, bookmark, note)
class WordWidget extends WidgetSpan {
  final WordModel word;
  final bool isHighlighted;
  final bool hasBookmark;
  final bool hasNote;
  final Color? highlightColor;
  final VoidCallback onTap;
  final TextStyle textStyle;
  final String? text;

  WordWidget({
    required this.word,
    required this.isHighlighted,
    required this.hasBookmark,
    required this.hasNote,
    this.highlightColor,
    required this.onTap,
    required this.textStyle,
    this.text,
  }) : super(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: _WordHighlightWidget(
      word: word,
      isHighlighted: isHighlighted,
      hasBookmark: hasBookmark,
      hasNote: hasNote,
      highlightColor: highlightColor,
      onTap: onTap,
      textStyle: textStyle,
      text: text,
    ),
  );
}

class _WordHighlightWidget extends StatefulWidget {
  final WordModel word;
  final bool isHighlighted;
  final bool hasBookmark;
  final bool hasNote;
  final Color? highlightColor;
  final VoidCallback onTap;
  final TextStyle textStyle;
  final String? text;

  const _WordHighlightWidget({
    required this.word,
    required this.isHighlighted,
    required this.hasBookmark,
    required this.hasNote,
    this.highlightColor,
    required this.onTap,
    required this.textStyle,
    this.text,
  });

  @override
  State<_WordHighlightWidget> createState() => _WordHighlightWidgetState();
}

class _WordHighlightWidgetState extends State<_WordHighlightWidget> {
  bool _wasHighlighted = false;

  @override
  void didUpdateWidget(_WordHighlightWidget old) {
    super.didUpdateWidget(old);
    _wasHighlighted = old.isHighlighted;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.highlightColor ?? AppColors.primary;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: widget.isHighlighted ? AppAnimations.highlightScale : 1.0,
        duration: AppAnimations.highlight,
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Highlight background with rounded corners
              ClipRRect(
                borderRadius: BorderRadius.circular(AppAnimations.highlightRadius),
                child: AnimatedContainer(
                  duration: AppAnimations.highlight,
                  curve: Curves.easeOut,
                  color: widget.isHighlighted
                      ? color.withValues(alpha: 0.35)
                      : Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    child: AnimatedDefaultTextStyle(
                      duration: AppAnimations.highlight,
                      style: widget.textStyle.copyWith(
                        fontWeight: widget.isHighlighted
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      child: Text(
                        widget.text ?? widget.word.text,
                      ),
                    ),
                  ),
                ),
              ),
              // Dot indicator for bookmarks (gold, 4px above text)
              if (widget.hasBookmark)
                Positioned(
                  top: -4,
                  left: 2,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              // Dot indicator for notes (purple, 4px above text)
              if (widget.hasNote && !widget.hasBookmark)
                Positioned(
                  top: -4,
                  left: 2,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B4EFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
