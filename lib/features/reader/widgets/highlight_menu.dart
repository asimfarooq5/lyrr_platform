import 'package:flutter/material.dart';

class HighlightMenu extends StatelessWidget {
  final String selectedText;
  final void Function(String color) onHighlight;

  const HighlightMenu({
    super.key,
    required this.selectedText,
    required this.onHighlight,
  });

  static const colors = [
    HighlightColor(name: 'Yellow', value: Color(0xFFFFF176), tag: 'yellow'),
    HighlightColor(name: 'Green', value: Color(0xFFA5D6A7), tag: 'green'),
    HighlightColor(name: 'Blue', value: Color(0xFF90CAF9), tag: 'blue'),
    HighlightColor(name: 'Pink', value: Color(0xFFF48FB1), tag: 'pink'),
    HighlightColor(name: 'Orange', value: Color(0xFFFFCC80), tag: 'orange'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...colors.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onHighlight(c.tag),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.value,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 16, thickness: 1, color: Colors.white24),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(
              Icons.chrome_reader_mode_outlined,
              color: Colors.white70,
              size: 18,
            ),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class HighlightColor {
  final String name;
  final Color value;
  final String tag;

  const HighlightColor({
    required this.name,
    required this.value,
    required this.tag,
  });
}
