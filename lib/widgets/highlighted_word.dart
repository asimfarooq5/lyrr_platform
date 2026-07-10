import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HighlightedWord {
  /// Builds a [TextSpan] representing a word.
  /// Highlights the word if [isActive] is true.
  static TextSpan build({
    required String id,
    required String text,
    required bool isActive,
    required double fontSize,
    required double lineSpacing,
    required Color textColor,
    required Color activeTextColor,
    required Color activeBgColor,
    required VoidCallback onTap,
  }) {
    return TextSpan(
      text: '$text ',
      style: TextStyle(
        fontSize: fontSize,
        height: lineSpacing,
        fontFamily: 'Serif',
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        color: isActive ? activeTextColor : textColor,
        backgroundColor: isActive ? activeBgColor : Colors.transparent,
      ),
      recognizer: TapGestureRecognizer()..onTap = onTap,
    );
  }
}
