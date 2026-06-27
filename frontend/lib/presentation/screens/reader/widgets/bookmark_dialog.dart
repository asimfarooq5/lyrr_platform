/// Bookmark Dialog
/// 
/// Dialog for creating and editing bookmarks

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class BookmarkDialog extends StatefulWidget {
  final String wordId;
  final dynamic existingBookmark;

  const BookmarkDialog({
    super.key,
    required this.wordId,
    this.existingBookmark,
  });

  @override
  State<BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends State<BookmarkDialog> {
  late TextEditingController _noteController;
  String _selectedColor = '#FFD700';
  bool _isEditing = false;

  final List<Map<String, dynamic>> _colors = [
    {'color': '#FFD700', 'name': 'Yellow'},
    {'color': '#90EE90', 'name': 'Green'},
    {'color': '#87CEEB', 'name': 'Blue'},
    {'color': '#FFB6C1', 'name': 'Pink'},
    {'color': '#DDA0DD', 'name': 'Purple'},
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingBookmark != null;
    _noteController = TextEditingController(
      text: widget.existingBookmark?.note ?? '',
    );
    if (_isEditing) {
      _selectedColor = widget.existingBookmark!.color;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Bookmark' : 'Add Bookmark'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color selection
            Text(
              'Color',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((colorData) {
                final color = _hexToColor(colorData['color']);
                final isSelected = _selectedColor == colorData['color'];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = colorData['color'];
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.black, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // Note field
            Text(
              'Note (optional)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add a note about this bookmark...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: () {
              Navigator.pop(context, {'delete': true});
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'color': _selectedColor,
              'note': _noteController.text.isEmpty 
                  ? null 
                  : _noteController.text,
            });
          },
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }
}
