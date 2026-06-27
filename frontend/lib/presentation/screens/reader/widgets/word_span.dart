/// Word Span Widget
/// 
/// Individual word with highlighting, bookmark, and note indicators

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../data/models/book_model.dart';

class WordSpan extends InlineSpan {
  final WordModel word;
  final bool isHighlighted;
  final bool hasBookmark;
  final bool hasNote;
  final Color? highlightColor;
  final VoidCallback onTap;

  WordSpan({
    Key? key,
    required this.word,
    required this.isHighlighted,
    required this.hasBookmark,
    required this.hasNote,
    this.highlightColor,
    required this.onTap,
  }) : super(
    style: TextStyle(
      backgroundColor: isHighlighted 
          ? (highlightColor ?? const Color(0xFF6B4EFF)).withOpacity(0.3)
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

  @override
  void build(
    ParagraphBuilder builder, {
    double textScaleFactor = 1.0,
    List<PlaceholderDimensions>? dimensions,
  }) {
    builder.pushStyle(style!.getTextStyle(textScaleFactor: textScaleFactor));
    
    // Add word text with trailing space
    builder.addText('${word.text} ');
    
    builder.pop();
  }

  @override
  bool visitChildren(InlineSpanVisitor visitor) => true;

  @override
  InlineSpan? getSpanForPosition(TextPosition position) => this;

  @override
  InlineSpan? getSpanForPositionVisitor(
    TextPosition position, 
    Accumulator offset,
  ) {
    return this;
  }

  @override
  void computeToPlainText(
    StringBuffer buffer, {
    bool includePlaceholders = true,
    bool includeSemanticsLabels = true,
  }) {
    buffer.write('${word.text} ');
  }

  @override
  void computeSemanticsInformation(
    List<InlineSpanSemanticsInformation> collector,
  ) {
    collector.add(InlineSpanSemanticsInformation('${word.text} '));
  }

  @override
  int? codeUnitAt(int index) => null;

  @override
  RenderComparison compareTo(InlineSpan other) => RenderComparison.identical;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordSpan &&
        other.word.id == word.id &&
        other.isHighlighted == isHighlighted &&
        other.hasBookmark == hasBookmark &&
        other.hasNote == hasNote;
  }

  @override
  int get hashCode => Object.hash(
    word.id,
    isHighlighted,
    hasBookmark,
    hasNote,
  );

  @override
  String toStringShort() => 'WordSpan(${word.text})';

  @override
  List<DiagnosticsNode> debugDescribeChildren() => [];

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('word', word.text));
    properties.add(StringProperty('id', word.id));
    properties.add(FlagProperty('highlighted', value: isHighlighted, ifTrue: 'highlighted'));
    properties.add(FlagProperty('bookmark', value: hasBookmark, ifTrue: 'has bookmark'));
    properties.add(FlagProperty('note', value: hasNote, ifTrue: 'has note'));
  }
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
