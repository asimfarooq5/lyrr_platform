/// Library Tab
/// 
/// User's book library with reading progress

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/book_model.dart';
import '../../theme/app_theme.dart';
import '../reader/reader_screen.dart';

class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key});

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  bool _isLoading = true;
  List<BookModel> _books = [];
  String? _error;

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
        _error = 'Failed to load library';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Search library
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Filter library
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _books.isEmpty
                  ? _buildEmpty()
                  : _buildBookList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadLibrary,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your library is empty',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Discover books to start reading',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to discover tab
            },
            child: const Text('Browse Books'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList() {
    return RefreshIndicator(
      onRefresh: _loadLibrary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          return _BookCard(
            book: book,
            onTap: () => _openBook(book),
          );
        },
      ),
    );
  }

  void _openBook(BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(bookId: book.id),
      ),
    );
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
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 120,
                  color: AppColors.primary.withOpacity(0.1),
                  child: book.coverUrl != null
                      ? Image.network(
                          book.coverUrl!,
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
              const SizedBox(width: 16),
              
              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    
                    // Progress bar
                    if (book.progressPercent != null && book.progressPercent! > 0) ...[
                      LinearProgressIndicator(
                        value: book.progressPercent! / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${book.progressPercent!.toStringAsFixed(0)}% complete',
                        style: theme.textTheme.bodySmall,
                      ),
                    ] else ...[
                      Text(
                        'Not started',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Download indicator
              if (book.isDownloaded)
                const Icon(
                  Icons.offline_pin,
                  color: AppColors.success,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
