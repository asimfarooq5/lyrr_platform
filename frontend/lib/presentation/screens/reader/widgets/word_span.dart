/// Word Span Widget
/// 
/// Individual word with highlighting, bookmark, and note indicators

import 'package:flutter/material.dart';
import 'package:lyrr/data/models/book_model.dart';

class WordSpan extends TextSpan {
  final WordModel wordData;
  final bool isHighlighted;
  final bool hasBookmark;
  final bool hasNote;
  final Color? highlightColor;
  final VoidCallback onTap;

  WordSpan({
    required this.wordData,
    required this.isHighlighted,
    required this.hasBookmark,
    required this.hasNote,
    this.highlightColor,
    required this.onTap,
    super.text,
  }) : super(
    style: TextStyle(
      backgroundColor: isHighlighted 
          ? (highlightColor ?? const Color(0xFF6B4EFF)).withValues(alpha: 0.3)
          : null,
      fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
      decoration: hasBookmark || hasNote
          ? TextDecoration.underline
          : TextDecoration.none,
      decorationColor: hasBookmark 
          ? const Color(0xFFFFD700)
          : hasNote 
              ? const Color(0xFF6B4EFF)
              : null,
      decorationThickness: 2,
    ),
  );
}

/// Word widget for use in RichText
class WordWidget extends WidgetSpan {
  final WordModel word;
  final bool isHighlighted;
  final bool hasBookmark;
  final bool hasNote;
  final Color? highlightColor;
  final VoidCallback onTap;

  WordWidget({
    required this.word,
    required this.isHighlighted,
    required this.hasBookmark,
    required this.hasNote,
    this.highlightColor,
    required this.onTap,
  }) : super(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: isHighlighted 
              ? (highlightColor ?? const Color(0xFF6B4EFF)).withOpacity(0.3)
              : null,
          border: hasBookmark || hasNote
              ? Border(
                  bottom: BorderSide(
                    color: hasBookmark 
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF6B4EFF),
                    width: 2,
                  ),
                )
              : null,
        ),
        child: Text(
          word.text,
          style: TextStyle(
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    ),
  );
}
