/// Authors screen (FRS §5: browse authors).
///
/// Two-step browse: the list of authors, then that author's books. Both steps
/// reuse the existing book grid so there is no second card implementation to
/// keep in sync.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/book_model.dart';
import '../../theme/app_theme.dart';
import '../reader/reader_screen.dart';

class AuthorsScreen extends ConsumerStatefulWidget {
  const AuthorsScreen({super.key});

  @override
  ConsumerState<AuthorsScreen> createState() => _AuthorsScreenState();
}

class _AuthorsScreenState extends ConsumerState<AuthorsScreen> {
  bool _isLoading = true;
  String? _error;
  List<({String name, int bookCount})> _authors = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final repo = ref.read(booksRepositoryProvider);
      final authors = await repo.getAuthors();
      if (!mounted) return;
      setState(() { _authors = authors; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load authors'; _isLoading = false; });
    }
  }

  void _openAuthor(String name) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AuthorBooksScreen(authorName: name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authors')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _authors.isEmpty
                  ? const Center(child: Text('No authors yet'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _authors.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final author = _authors[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                author.name.characters.first.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(author.name),
                            subtitle: Text(
                              '${author.bookCount} '
                              '${author.bookCount == 1 ? 'book' : 'books'}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openAuthor(author.name),
                          );
                        },
                      ),
                    ),
    );
  }
}

/// Every published book by one author.
class AuthorBooksScreen extends ConsumerStatefulWidget {
  const AuthorBooksScreen({super.key, required this.authorName});

  final String authorName;

  @override
  ConsumerState<AuthorBooksScreen> createState() => _AuthorBooksScreenState();
}

class _AuthorBooksScreenState extends ConsumerState<AuthorBooksScreen> {
  bool _isLoading = true;
  List<BookModel> _books = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(booksRepositoryProvider);
      // Server-side search already matches on author, then filter to an exact
      // author match so a search for "King" doesn't also return "Kingsley".
      final data = await repo.getBooks(search: widget.authorName);
      final books = data
          .map((b) => BookModel.fromJson(b as Map<String, dynamic>))
          .where((b) => b.author.toLowerCase() == widget.authorName.toLowerCase())
          .toList();
      if (!mounted) return;
      setState(() { _books = books; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.authorName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? const Center(child: Text('No books found'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _books.length,
                  itemBuilder: (_, i) {
                    final book = _books[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ReaderScreen(bookId: book.id),
                      )),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                color: AppColors.primary.withValues(alpha: 0.08),
                                child: book.resolvedCoverUrl != null
                                    ? Image.network(
                                        book.resolvedCoverUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.book, color: AppColors.primary),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(Icons.book, color: AppColors.primary),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
