/// Settings Sheet
/// 
/// Bottom sheet for reader settings

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class SettingsSheet extends StatelessWidget {
  final double fontSize;
  final double lineHeight;
  final String theme;
  final double playbackSpeed;
  final bool autoScroll;
  final Color highlightColor;
  final Function(double) onFontSizeChanged;
  final Function(double) onLineHeightChanged;
  final Function(String) onThemeChanged;
  final Function(double) onPlaybackSpeedChanged;
  final Function(bool) onAutoScrollChanged;
  final Function(Color) onHighlightColorChanged;

  const SettingsSheet({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.theme,
    required this.playbackSpeed,
    required this.autoScroll,
    required this.highlightColor,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onThemeChanged,
    required this.onPlaybackSpeedChanged,
    required this.onAutoScrollChanged,
    required this.onHighlightColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Reader Settings',
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: 24),
            
            // Font size
            _buildSettingRow(
              context,
              'Font Size',
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: fontSize > 12 
                        ? () => onFontSizeChanged(fontSize - 1)
                        : null,
                  ),
                  Text('${fontSize.toInt()}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: fontSize < 32 
                        ? () => onFontSizeChanged(fontSize + 1)
                        : null,
                  ),
                ],
              ),
            ),
            
            // Line height
            _buildSettingRow(
              context,
              'Line Spacing',
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: lineHeight > 1.2 
                        ? () => onLineHeightChanged(lineHeight - 0.1)
                        : null,
                  ),
                  Text(lineHeight.toStringAsFixed(1)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: lineHeight < 2.5 
                        ? () => onLineHeightChanged(lineHeight + 0.1)
                        : null,
                  ),
                ],
              ),
            ),
            
            // Theme
            _buildSettingRow(
              context,
              'Theme',
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'light',
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode),
                  ),
                  ButtonSegment(
                    value: 'system',
                    label: Text('Auto'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                ],
                selected: {theme},
                onSelectionChanged: (selected) {
                  onThemeChanged(selected.first);
                },
              ),
            ),
            
            // Highlight color
            _buildSettingRow(
              context,
              'Highlight Color',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ColorOption(
                    color: const Color(0xFF6B4EFF),
                    isSelected: highlightColor == const Color(0xFF6B4EFF),
                    onTap: () => onHighlightColorChanged(const Color(0xFF6B4EFF)),
                  ),
                  _ColorOption(
                    color: const Color(0xFFFF6B6B),
                    isSelected: highlightColor == const Color(0xFFFF6B6B),
                    onTap: () => onHighlightColorChanged(const Color(0xFFFF6B6B)),
                  ),
                  _ColorOption(
                    color: const Color(0xFF00D9C0),
                    isSelected: highlightColor == const Color(0xFF00D9C0),
                    onTap: () => onHighlightColorChanged(const Color(0xFF00D9C0)),
                  ),
                  _ColorOption(
                    color: const Color(0xFFFFD700),
                    isSelected: highlightColor == const Color(0xFFFFD700),
                    onTap: () => onHighlightColorChanged(const Color(0xFFFFD700)),
                  ),
                ],
              ),
            ),
            
            // Auto scroll
            _buildSettingRow(
              context,
              'Auto-scroll',
              Switch(
                value: autoScroll,
                onChanged: onAutoScrollChanged,
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(BuildContext context, String label, Widget control) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          control,
        ],
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: 3)
              : null,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 4,
            ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }
}
