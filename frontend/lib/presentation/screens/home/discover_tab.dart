/// Discover Tab
/// 
/// Browse and search for new books

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/book_model.dart';
import '../../theme/app_theme.dart';
import '../reader/reader_screen.dart';
import 'authors_screen.dart';

class DiscoverTab extends ConsumerStatefulWidget {
  const DiscoverTab({super.key});

  @override
  ConsumerState<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<DiscoverTab> {
  final _searchController = TextEditingController();
  bool _isLoading = true;
  List<BookModel> _books = [];
  /// Books added while their detail sheet was open, so the sheet's button
  /// switches to "In Your Library" without a restart.
  final Map<String, bool> _purchasedInSheet = {};
  List<BookModel> _featuredBooks = [];
  /// Books the reader is part-way through, most recently read first. Shown at
  /// the top of the store so getting back into a book is one tap — the thing
  /// readers reach for most, and the first rail a reader expects to see.
  List<BookModel> _continueReading = [];
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
      final featuredData = await repo.getBooks();
      _featuredBooks = featuredData.map((b) => BookModel.fromJson(b)).toList();

      // Load all books
      final allData = await repo.getBooks();
      _books = allData.map((b) => BookModel.fromJson(b)).toList();

      // Books in progress, newest first. Best-effort: the store is still
      // browsable if this fails, so a hiccup here must not blank the page.
      try {
        final library = await ref.read(userDataRepositoryProvider).getLibrary();
        _continueReading = library
            .map((b) => BookModel.fromJson(b as Map<String, dynamic>))
            .where((b) => (b.progressPercent ?? 0) > 0)
            .toList()
          ..sort((a, b) {
            final ad = a.lastReadAt, bd = b.lastReadAt;
            if (ad == null && bd == null) return 0;
            if (ad == null) return 1;
            if (bd == null) return -1;
            return bd.compareTo(ad);
          });
      } catch (_) {
        _continueReading = [];
      }

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

  /// Returns true when the book ends up in the reader's library.
  Future<bool> _purchaseBook(BookModel book) async {
    try {
      // Free books skip checkout entirely and are granted immediately.
      if (book.isFree) {
        final booksRepo = ref.read(booksRepositoryProvider);
        await booksRepo.purchaseBook(book.id);
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${book.title} added to your library')),
        );
        // Reload so the card and detail sheet stop offering it.
        unawaited(_loadBooks());
        return true;
      }

      final repo = ref.read(paymentsRepositoryProvider);

      // Show payment method sheet (pay-per-book, FRS §10)
      final method = await _showPaymentMethodSheet(book);
      if (method == null) return false;

      final payment = await repo.checkout(
        method: method,
        itemType: 'book',
        bookId: book.id,
      );

      // Mobile money needs confirmation
      if (payment.isPending) {
        final confirmed = await _confirmPaymentDialog(payment);
        if (confirmed == true) {
          await repo.confirmPayment(payment.id);
        }
      }

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${book.title} added to your library')),
      );
      // Reload so the card and detail sheet stop offering it.
      unawaited(_loadBooks());
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to purchase: ${e.toString().replaceAll('Exception: ', '')}')),
      );
      return false;
    }
  }

  /// Let the user choose how to pay for a single book.
  Future<String?> _showPaymentMethodSheet(BookModel book) async {
    final repo = ref.read(paymentsRepositoryProvider);
    final methods = await repo.getPaymentMethods();
    if (methods.isEmpty) return 'card';

    String? phone;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        String? choice = methods.first.id;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Buy "${book.title}" — ${book.formattedPrice}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Choose payment method',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    ...methods.map((m) => RadioListTile<String>(
                          value: m.id,
                          groupValue: choice,
                          onChanged: (v) => setSheetState(() => choice = v),
                          title: Text(m.name),
                        )),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, choice),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null) return null;

    // Mobile money requires a phone number
    if (selected != 'card') {
      phone = await _promptPhone(selected);
      if (phone == null) return null;
    }

    return selected;
  }

  Future<String?> _promptPhone(String methodName) async {
    final controller = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$methodName number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+2376XXXXXXXX',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Pay'),
          ),
        ],
      ),
    );
    controller.dispose();
    return (phone == null || phone.isEmpty) ? null : phone;
  }

  Future<bool?> _confirmPaymentDialog(dynamic payment) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm payment'),
        content: Text(
          'Your payment is awaiting approval on your mobile money wallet. '
          'Confirm to complete (sandbox mode).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store'),
        actions: [
          // Browse by author (FRS §5)
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Browse authors',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthorsScreen()),
            ),
          ),
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
          // Continue reading — first thing on the page when there is something
          // to go back to, so resuming takes one tap.
          if (_continueReading.isNotEmpty && _searchController.text.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text('Continue Reading', style: theme.textTheme.displaySmall),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 232,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _continueReading.length,
                  itemBuilder: (context, index) {
                    final book = _continueReading[index];
                    return _ContinueReadingCard(
                      book: book,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ReaderScreen(bookId: book.id),
                      )),
                    );
                  },
                ),
              ),
            ),
          ],
          // Featured section
          if (_featuredBooks.isNotEmpty && _searchController.text.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Bestsellers',
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
                _searchController.text.isEmpty ? 'Browse the Store' : 'Search Results',
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
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (_, controller) => _BookDetailsSheet(
            book: book,
            scrollController: controller,
            isPurchasedOverride: _purchasedInSheet[book.id],
            onPurchase: () async {
              final added = await _purchaseBook(book);
              if (!added) return;
              _purchasedInSheet[book.id] = true;
              // Close the sheet so the reader lands back on the store and can
              // actually see the confirmation — a snackbar raised while a modal
              // sheet is up sits behind it and never gets read.
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
            onReadSample: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ReaderScreen(bookId: book.id),
              ));
            },
          ),
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

/// A book the reader is part-way through: cover, title, and how far in they
/// are, so the shelf answers "where was I?" at a glance.
class _ContinueReadingCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;

  const _ContinueReadingCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (book.progressPercent ?? 0).clamp(0, 100).toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppColors.primary.withOpacity(0.1),
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
                    // Progress along the bottom of the cover.
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 4,
                        backgroundColor: Colors.black.withOpacity(0.35),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${percent.round()}% read',
              style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
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
                  child: book.resolvedCoverUrl != null
                      ? Image.network(
                          book.resolvedCoverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.book, color: AppColors.primary),
                          ),
                          loadingBuilder: (ctx, child, progress) =>
                              progress == null ? child : const Center(
                                child: SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
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
            const SizedBox(height: 2),
            _PriceTag(book: book),
          ],
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final BookModel book;
  const _PriceTag({required this.book});

  @override
  Widget build(BuildContext context) {
    return Text(
      book.isFree ? 'Free' : book.formattedPrice,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: book.isFree ? AppColors.secondary : AppColors.primary,
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
                child: book.resolvedCoverUrl != null
                    ? Image.network(
                        book.resolvedCoverUrl!,
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
          const SizedBox(height: 2),
          _PriceTag(book: book),
        ],
      ),
    );
  }
}

class _BookDetailsSheet extends StatelessWidget {
  final BookModel book;
  final ScrollController scrollController;
  final VoidCallback onPurchase;
  final VoidCallback? onReadSample;
  /// Overrides book.isPurchased so the sheet reflects a purchase made while it
  /// is open, without waiting for the list to reload.
  final bool? isPurchasedOverride;

  const _BookDetailsSheet({
    required this.book,
    required this.scrollController,
    required this.onPurchase,
    this.onReadSample,
    this.isPurchasedOverride,
  });

  bool get _owned => isPurchasedOverride ?? book.isPurchased;

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
                        child: book.resolvedCoverUrl != null
                            ? Image.network(
                                book.resolvedCoverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.book, color: AppColors.primary, size: 48),
                                ),
                                loadingBuilder: (ctx, child, progress) =>
                                    progress == null ? child : const Center(
                                      child: SizedBox(width: 24, height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
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
          
          // Purchase / sample buttons (Store, FRS §10/§11)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (!book.isPurchased && !book.isFree && onReadSample != null) ...[
                    OutlinedButton(
                      onPressed: onReadSample,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Read Sample'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton(
                    onPressed: _owned ? null : onPurchase,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: Text(
                      _owned
                          ? 'In Your Library'
                          : book.isFree
                              ? 'Add to Library — Free'
                              : 'Buy Now — ${book.formattedPrice}',
                    ),
                  ),
                ],
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
