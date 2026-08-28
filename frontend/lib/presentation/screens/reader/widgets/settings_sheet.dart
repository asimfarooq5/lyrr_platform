/// Settings Sheet
/// Kindle Aa-style bottom sheet with font, theme, and reading settings

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../reader_screen.dart';

class SettingsSheet extends StatelessWidget {
  final double fontSize;
  final double lineHeight;
  final String theme;
  final double playbackSpeed;
  final bool autoScroll;
  final Color highlightColor;
  final ReadingMode readingMode;
  final Function(double) onFontSizeChanged;
  final Function(double) onLineHeightChanged;
  final Function(String) onThemeChanged;
  final Function(double) onPlaybackSpeedChanged;
  final Function(bool) onAutoScrollChanged;
  final Function(Color) onHighlightColorChanged;
  final Function(ReadingMode) onReadingModeChanged;

  const SettingsSheet({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.theme,
    required this.playbackSpeed,
    required this.autoScroll,
    required this.highlightColor,
    this.readingMode = ReadingMode.light,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onThemeChanged,
    required this.onPlaybackSpeedChanged,
    required this.onAutoScrollChanged,
    required this.onHighlightColorChanged,
    required this.onReadingModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: themeData.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Kindle-style tab headers
            DefaultTabController(
              length: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.primary,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Font'),
                      Tab(text: 'Page'),
                      Tab(text: 'Reading'),
                      Tab(text: 'Audio'),
                    ],
                  ),
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      children: [
                        _FontTab(fontSize: fontSize, lineHeight: lineHeight,
                            onFontSizeChanged: onFontSizeChanged, onLineHeightChanged: onLineHeightChanged),
                        _PageTab(autoScroll: autoScroll, readingMode: readingMode,
                            onAutoScrollChanged: onAutoScrollChanged, onReadingModeChanged: onReadingModeChanged),
                        _ReadingTab(highlightColor: highlightColor,
                            onHighlightColorChanged: onHighlightColorChanged),
                        _AudioTab(playbackSpeed: playbackSpeed,
                            onPlaybackSpeedChanged: onPlaybackSpeedChanged),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontTab extends StatelessWidget {
  final double fontSize;
  final double lineHeight;
  final Function(double) onFontSizeChanged;
  final Function(double) onLineHeightChanged;

  const _FontTab({
    required this.fontSize, required this.lineHeight,
    required this.onFontSizeChanged, required this.onLineHeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Font size with Aa preview
          Row(
            children: [
              const Text('A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: 12, max: 32,
                  divisions: 20,
                  activeColor: AppColors.primary,
                  onChanged: onFontSizeChanged,
                ),
              ),
              Text('A', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Preset sizes (Kindle-style quick select)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [12, 16, 20, 24, 28, 32].map((size) {
              final isSelected = fontSize == size.toDouble();
              return GestureDetector(
                onTap: () => onFontSizeChanged(size.toDouble()),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? null : Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        fontSize: size / 2.5 + 8,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          
          // Line height
          Row(
            children: [
              const Icon(Icons.format_line_spacing, size: 20, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: lineHeight,
                  min: 1.0, max: 2.5,
                  divisions: 15,
                  activeColor: AppColors.primary,
                  onChanged: onLineHeightChanged,
                ),
              ),
              Text(lineHeight.toStringAsFixed(1), style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          
          // Line height labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tight', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              Text('Relaxed', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageTab extends StatelessWidget {
  final bool autoScroll;
  final ReadingMode readingMode;
  final Function(bool) onAutoScrollChanged;
  final Function(ReadingMode) onReadingModeChanged;

  const _PageTab({
    required this.autoScroll, required this.readingMode,
    required this.onAutoScrollChanged, required this.onReadingModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kindle reading modes - like Paperwhite settings
          Text('Reading Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ModeCircle(
                label: 'Light',
                color: AppColors.readingLight,
                isSelected: readingMode == ReadingMode.light,
                onTap: () => onReadingModeChanged(ReadingMode.light),
              ),
              _ModeCircle(
                label: 'Sepia',
                color: AppColors.readingSepia,
                isSelected: readingMode == ReadingMode.sepia,
                onTap: () => onReadingModeChanged(ReadingMode.sepia),
              ),
              _ModeCircle(
                label: 'Dark',
                color: AppColors.readingDark,
                isSelected: readingMode == ReadingMode.dark,
                onTap: () => onReadingModeChanged(ReadingMode.dark),
              ),
              _ModeCircle(
                label: 'Green',
                color: const Color(0xFFC7EDCC),
                isSelected: readingMode == ReadingMode.green,
                onTap: () => onReadingModeChanged(ReadingMode.green),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Page layout
          Text('Page Layout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Auto-scroll'),
            subtitle: const Text('Automatically scroll with audio'),
            value: autoScroll,
            onChanged: onAutoScrollChanged,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _ModeCircle extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCircle({
    required this.label, required this.color,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey[300]!,
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: AppColors.primary, size: 20)
                : null,
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _ReadingTab extends StatelessWidget {
  final Color highlightColor;
  final Function(Color) onHighlightColorChanged;

  const _ReadingTab({
    required this.highlightColor,
    required this.onHighlightColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Highlight Color', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _HighlightOption(
                color: AppColors.primary, label: 'Default',
                isSelected: highlightColor == AppColors.primary,
                onTap: () => onHighlightColorChanged(AppColors.primary),
              ),
              _HighlightOption(
                color: AppColors.secondary, label: 'Rose',
                isSelected: highlightColor == AppColors.secondary,
                onTap: () => onHighlightColorChanged(AppColors.secondary),
              ),
              _HighlightOption(
                color: const Color(0xFFFFD700), label: 'Gold',
                isSelected: highlightColor == const Color(0xFFFFD700),
                onTap: () => onHighlightColorChanged(const Color(0xFFFFD700)),
              ),
              _HighlightOption(
                color: const Color(0xFF00D9C0), label: 'Teal',
                isSelected: highlightColor == const Color(0xFF00D9C0),
                onTap: () => onHighlightColorChanged(const Color(0xFF00D9C0)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 3, height: 40,
                  decoration: BoxDecoration(
                    color: highlightColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Highlighted text', style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        backgroundColor: highlightColor.withOpacity(0.2),
                      )),
                      const SizedBox(height: 4),
                      const Text('appears like this', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightOption extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _HighlightOption({
    required this.color, required this.label,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _AudioTab extends StatelessWidget {
  final double playbackSpeed;
  final Function(double) onPlaybackSpeedChanged;

  const _AudioTab({
    required this.playbackSpeed,
    required this.onPlaybackSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Playback Speed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 16),
          
          // Speed slider
          Row(
            children: [
              const Text('🐢', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Slider(
                  value: playbackSpeed,
                  min: 0.5, max: 2.0,
                  divisions: 6,
                  activeColor: AppColors.primary,
                  label: '${playbackSpeed}x',
                  onChanged: onPlaybackSpeedChanged,
                ),
              ),
              const Text('🐇', style: TextStyle(fontSize: 18)),
            ],
          ),
          
          // Speed preset buttons
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              final isSelected = playbackSpeed == speed;
              return GestureDetector(
                onTap: () => onPlaybackSpeedChanged(speed),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? null : Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    '${speed}x',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
