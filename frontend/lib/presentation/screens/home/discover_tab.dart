/// Discover Tab
/// 
/// Browse and search for new books

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/book_model.dart';
import '../../theme/app_theme.dart';
import '../reader/reader_screen.dart';

class DiscoverTab extends ConsumerStatefulWidget {
  const DiscoverTab({super.key});

  @override
  ConsumerState<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<DiscoverTab> {
  final _searchController = TextEditingController();
  bool _isLoading = true;
  List<BookModel> _books = [];
  List<BookModel> _featuredBooks = [];
  String? _error;
  String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(booksRepositoryProvider);
      
      // Load featured books
      final featuredData = await repo.getBooks(featuredOnly: true);
      _featuredBooks = featuredData.map((b) => BookModel.fromJson(b)).toList();

      // Load all books
      final allData = await repo.getBooks();
      _books = allData.map((b) => BookModel.fromJson(b)).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load books';
        _isLoading = false;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _loadBooks();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(booksRepositoryProvider);
      final data = await repo.getBooks(search: query);
      
      setState(() {
        _books = data.map((b) => BookModel.fromJson(b)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Search failed';
        _isLoading = false;
      });
    }
  }

  Future<void> _purchaseBook(BookModel book) async {
    try {
      final repo = ref.read(booksRepositoryProvider);
      await repo.purchaseBook(book.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${book.title} added to your library')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to purchase: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          // Language filter
          PopupMenuButton<String?>(
            icon: const Icon(Icons.language),
            onSelected: (lang) {
              setState(() {
                _selectedLanguage = lang;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Languages'),
              ),
              ...['en', 'es', 'fr', 'de', 'it', 'pt', 'zh', 'ja', 'ko', 'ar']
                  .map((lang) => PopupMenuItem(
                        value: lang,
                        child: Text(_getLanguageName(lang)),
                      )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search books, authors...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadBooks();
                        },
                      )
                    : null,
              ),
              onSubmitted: _search,
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _buildContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_error!),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBooks,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadBooks,
      child: CustomScrollView(
        slivers: [
          // Featured section
          if (_featuredBooks.isNotEmpty && _searchController.text.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Featured',
                  style: theme.textTheme.displaySmall,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _featuredBooks.length,
                  itemBuilder: (context, index) {
                    return _FeaturedBookCard(
                      book: _featuredBooks[index],
                      onTap: () => _showBookDetails(_featuredBooks[index]),
                    );
                  },
                ),
              ),
            ),
          ],
          
          // All books section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                _searchController.text.isEmpty ? 'All Books' : 'Search Results',
                style: theme.textTheme.displaySmall,
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = _books[index];
                  return _BookGridCard(
                    book: book,
                    onTap: () => _showBookDetails(book),
                  );
                },
                childCount: _books.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookDetails(BookModel book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => _BookDetailsSheet(
          book: book,
          scrollController: controller,
          onPurchase: () => _purchaseBook(book),
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    const names = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
    };
    return names[code] ?? code;
  }
}

class _FeaturedBookCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;

  const _FeaturedBookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: AppColors.primary.withOpacity(0.1),
                  child: book.coverUrl != null
                      ? Image.network(
                          book.coverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : const Center(
                          child: Icon(Icons.book, color: AppColors.primary),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              book.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              book.author,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookGridCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;

  const _BookGridCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: AppColors.primary.withOpacity(0.1),
                child: book.coverUrl != null
                    ? Image.network(
                        book.coverUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : const Center(
                        child: Icon(Icons.book, color: AppColors.primary),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            book.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            book.author,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BookDetailsSheet extends StatelessWidget {
  final BookModel book;
  final ScrollController scrollController;
  final VoidCallback onPurchase;

  const _BookDetailsSheet({
    required this.book,
    required this.scrollController,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 160,
                        height: 240,
                        color: AppColors.primary.withOpacity(0.1),
                        child: book.coverUrl != null
                            ? Image.network(
                                book.coverUrl!,
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Icon(Icons.book, 
                                  color: AppColors.primary, 
                                  size: 48,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    book.title,
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Author
                  Text(
                    book.author,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Metadata
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (book.duration != null)
                        _buildMetadataChip(
                          Icons.timer,
                          book.formattedDuration,
                        ),
                      if (book.language != null)
                        _buildMetadataChip(
                          Icons.language,
                          book.language.toUpperCase(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Description
                  if (book.description != null) ...[
                    Text(
                      'About this book',
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Features
                  Text(
                    'Features',
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFeatureChip('Synchronized Audio'),
                      _buildFeatureChip('Offline Mode'),
                      _buildFeatureChip('Bookmarks & Notes'),
                      if (book.drmEnabled)
                        _buildFeatureChip('DRM Protected'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Purchase button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: onPurchase,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('Add to Library'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      side: BorderSide.none,
    );
  }
}
