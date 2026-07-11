import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HighlightedWord {
  /// Builds a [TextSpan] representing a word.
  /// [pulseScale] (0.0-1.0) adds a subtle grow effect on the active word.
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
    double pulseScale = 0.0,
  }) {
    final displaySize = isActive ? fontSize * (1.0 + pulseScale * 0.06) : fontSize;
    return TextSpan(
      text: '$text ',
      style: TextStyle(
        fontSize: displaySize,
        height: lineSpacing,
        fontFamily: 'Serif',
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        color: isActive ? activeTextColor : textColor,
        backgroundColor: isActive
            ? activeBgColor.withValues(alpha: 0.7 + pulseScale * 0.3)
            : Colors.transparent,
      ),
      recognizer: TapGestureRecognizer()..onTap = onTap,
    );
  }
}
