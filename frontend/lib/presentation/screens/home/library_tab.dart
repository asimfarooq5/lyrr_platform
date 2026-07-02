/// Library Tab
/// Grouped by type, author, and language

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/book_model.dart';
import '../../theme/app_theme.dart';
import '../reader/reader_screen.dart';

class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key});

  @override
  ConsumerState<LibraryTab> createState() => LibraryTabState();
}

class LibraryTabState extends ConsumerState<LibraryTab> {
  bool _isLoading = true;
  List<BookModel> _books = [];
  String? _error;
  String _viewMode = 'list'; // list, type, author, language

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(userDataRepositoryProvider);
      final items = await repo.getLibrary();
      setState(() {
        _books = items.map((item) => BookModel.fromJson(item)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load library: $e';
        _isLoading = false;
      });
    }
  }

  void refresh() => _loadLibrary();

  Map<String, List<BookModel>> get _byType => _groupBy((b) => b.bookType ?? 'fiction');
  Map<String, List<BookModel>> get _byAuthor => _groupBy((b) => b.author);
  Map<String, List<BookModel>> get _byLanguage => _groupBy((b) => b.language);

  Map<String, List<BookModel>> _groupBy(String Function(BookModel) keyFn) {
    final map = <String, List<BookModel>>{};
    for (final b in _books) {
      final key = keyFn(b);
      map.putIfAbsent(key, () => []).add(b);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final views = ['list', 'type', 'author', 'language'];
    final icons = [Icons.list, Icons.category, Icons.person, Icons.language];
    final labels = ['All', 'Type', 'Author', 'Language'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          ...List.generate(views.length, (i) => IconButton(
            icon: Icon(icons[i], color: _viewMode == views[i] ? AppColors.primary : null),
            tooltip: labels[i],
            onPressed: () => setState(() => _viewMode = views[i]),
          )),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(_error!, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadLibrary, child: const Text('Retry')),
                ]))
              : _books.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Your library is empty', style: theme.textTheme.displaySmall),
                      const SizedBox(height: 8),
                      Text('Discover books to start reading', style: theme.textTheme.bodyMedium),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadLibrary,
                      child: _viewMode == 'list'
                          ? ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _books.length,
                              itemBuilder: (ctx, i) => _BookCard(book: _books[i], onTap: () => _openBook(_books[i])),
                            )
                          : _buildGroupedView(),
                    ),
    );
  }

  Widget _buildGroupedView() {
    final Map<String, List<BookModel>> groups;
    final String label;
    switch (_viewMode) {
      case 'type': groups = _byType; label = 'Type'; break;
      case 'author': groups = _byAuthor; label = 'Author'; break;
      case 'language': groups = _byLanguage; label = 'Language'; break;
      default: return const SizedBox();
    }

    final sortedKeys = groups.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: sortedKeys.map((key) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(
              children: [
                Text(key[0].toUpperCase() + key.substring(1), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${groups[key]!.length}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),
          ...groups[key]!.map((book) => _BookCard(book: book, onTap: () => _openBook(book))),
        ],
      )).toList(),
    );
  }

  void _openBook(BookModel book) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(bookId: book.id)));
  }
}

class _BookCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;
  const _BookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 60, height: 90,
                  color: AppColors.primary.withOpacity(0.1),
                  child: book.resolvedCoverUrl != null
                      ? Image.network(book.resolvedCoverUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.book, color: AppColors.primary)))
                      : const Center(child: Icon(Icons.book, color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(book.author, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(book.bookType ?? 'fiction', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        const SizedBox(width: 8),
                        Text(book.language.toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                    if (book.progressPercent != null && book.progressPercent! > 0) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: book.progressPercent! / 100, backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary), borderRadius: BorderRadius.circular(4)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
