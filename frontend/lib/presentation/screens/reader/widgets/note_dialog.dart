/// Note Dialog
/// 
/// Dialog for creating and editing notes

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class NoteDialog extends StatefulWidget {
  final String wordId;
  final dynamic existingNote;

  const NoteDialog({
    super.key,
    required this.wordId,
    this.existingNote,
  });

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late TextEditingController _contentController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingNote != null;
    _contentController = TextEditingController(
      text: widget.existingNote?.content ?? '',
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Note' : 'Add Note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your note',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Write your thoughts here...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: () {
              Navigator.pop(context, ''); // Empty string signals delete
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
            Navigator.pop(context, _contentController.text);
          },
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
