/// Word Action Sheet
///
/// Kindle-style popup shown when a word is tapped: dictionary definition
/// plus highlight / note / play-from-here actions.

import 'package:flutter/material.dart';
import '../../../../data/models/book_model.dart';
import '../../../theme/app_theme.dart';

class WordActionSheet extends StatefulWidget {
  final WordModel word;
  final String language;
  final bool hasBookmark;
  final bool hasNote;
  final VoidCallback onHighlight;
  final VoidCallback onNote;
  final VoidCallback onPlayFromHere;
  final Future<DictionaryEntry> Function(String word, String language) defineWord;

  const WordActionSheet({
    super.key,
    required this.word,
    required this.language,
    required this.hasBookmark,
    required this.hasNote,
    required this.onHighlight,
    required this.onNote,
    required this.onPlayFromHere,
    required this.defineWord,
  });

  @override
  State<WordActionSheet> createState() => _WordActionSheetState();
}

class _WordActionSheetState extends State<WordActionSheet> {
  Future<DictionaryEntry>? _definitionFuture;

  void _lookup() {
    setState(() {
      _definitionFuture = widget.defineWord(widget.word.text, widget.language);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(widget.word.text, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (_definitionFuture == null)
              OutlinedButton.icon(
                onPressed: _lookup,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Define'),
              )
            else
              FutureBuilder<DictionaryEntry>(
                future: _definitionFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Looking up definition…'),
                      ]),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('No definition found.', style: TextStyle(color: Colors.grey[600])),
                    );
                  }
                  final entry = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.phonetic != null)
                          Text(entry.phonetic!, style: TextStyle(color: AppColors.primary, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 8),
                        ...entry.meanings.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.partOfSpeech, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              ...m.definitions.map((d) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('• $d', style: theme.textTheme.bodyMedium),
                              )),
                            ],
                          ),
                        )),
                      ],
                    ),
                  );
                },
              ),

            const Divider(height: 24),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: Icon(widget.hasBookmark ? Icons.bookmark : Icons.bookmark_border, size: 18),
                  label: Text(widget.hasBookmark ? 'Edit Highlight' : 'Highlight'),
                  onPressed: widget.onHighlight,
                ),
                ActionChip(
                  avatar: Icon(widget.hasNote ? Icons.edit_note : Icons.note_add_outlined, size: 18),
                  label: Text(widget.hasNote ? 'Edit Note' : 'Add Note'),
                  onPressed: widget.onNote,
                ),
                ActionChip(
                  avatar: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Play from here'),
                  onPressed: widget.onPlayFromHere,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
