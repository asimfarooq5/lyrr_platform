/// Downloads Screen
///
/// Lists books downloaded for offline access (FRS §9) and lets the user
/// remove a download to free up space.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/book_model.dart';
import '../../theme/app_theme.dart';
import '../reader/reader_screen.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  bool _isLoading = true;
  List<BookModel> _books = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    final books = await db.getDownloadedBooks();
    if (mounted) setState(() { _books = books; _isLoading = false; });
  }

  Future<void> _remove(BookModel book) async {
    final service = ref.read(downloadServiceProvider);
    await service.deleteDownload(book.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.download_done_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No offline books yet', style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 8),
                    const Text('Download a book from your Library to read it without internet'),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _books.length,
                    itemBuilder: (ctx, i) {
                      final book = _books[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 44, height: 64,
                              color: AppColors.primary.withOpacity(0.1),
                              child: book.resolvedCoverUrl != null
                                  ? Image.network(book.resolvedCoverUrl!, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.book, color: AppColors.primary))
                                  : const Icon(Icons.book, color: AppColors.primary),
                            ),
                          ),
                          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ReaderScreen(bookId: book.id),
                          )),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            tooltip: 'Remove download',
                            onPressed: () => _remove(book),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
