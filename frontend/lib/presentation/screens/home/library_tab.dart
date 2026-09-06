/// Library Tab
/// Grouped by type, author, and language

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/book_model.dart';
import '../../../data/services/download_service.dart';
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
  List<CollectionModel> _collections = [];
  String? _error;
  String _viewMode = 'list'; // list, type, author, language, collections

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _loadCollections();
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

  Future<void> _loadCollections() async {
    try {
      final repo = ref.read(collectionsRepositoryProvider);
      final collections = await repo.getCollections();
      if (mounted) setState(() => _collections = collections);
    } catch (_) {
      // Collections are supplementary; ignore failures here.
    }
  }

  Future<void> _createCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Summer Reading'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final repo = ref.read(collectionsRepositoryProvider);
      await repo.createCollection(name);
      _loadCollections();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create collection: $e')));
    }
  }

  void refresh() { _loadLibrary(); _loadCollections(); }

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
    final views = ['list', 'type', 'author', 'language', 'collections'];
    final icons = [Icons.list, Icons.category, Icons.person, Icons.language, Icons.collections_bookmark];
    final labels = ['All', 'Type', 'Author', 'Language', 'Collections'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          ...List.generate(views.length, (i) => IconButton(
            icon: Icon(icons[i], color: _viewMode == views[i] ? AppColors.primary : null),
            tooltip: labels[i],
            onPressed: () => setState(() => _viewMode = views[i]),
          )),
          if (_viewMode == 'collections')
            IconButton(icon: const Icon(Icons.add), tooltip: 'New Collection', onPressed: _createCollection),
        ],
      ),
      body: _viewMode == 'collections'
          ? _buildCollectionsView()
          : _isLoading
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
                                  itemBuilder: (ctx, i) => _BookCard(
                                    book: _books[i],
                                    onTap: () => _openBook(_books[i]),
                                    collections: _collections,
                                    onCollectionsChanged: _loadCollections,
                                  ),
                                )
                              : _buildGroupedView(),
                        ),
    );
  }

  Widget _buildCollectionsView() {
    if (_collections.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.collections_bookmark_outlined, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('No collections yet', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        const Text('Create a shelf to organize your books, Kindle-style'),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _createCollection, icon: const Icon(Icons.add), label: const Text('New Collection')),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadCollections,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _collections.map((c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                children: [
                  Text(c.name, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${c.books.length}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      await ref.read(collectionsRepositoryProvider).deleteCollection(c.id);
                      _loadCollections();
                    },
                  ),
                ],
              ),
            ),
            if (c.books.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('No books yet — add some from any book\'s "…" menu', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              )
            else
              ...c.books.map((b) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(width: 40, height: 56, color: AppColors.primary.withOpacity(0.1),
                      child: b.coverUrl != null
                          ? Image.network(b.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.book, color: AppColors.primary))
                          : const Icon(Icons.book, color: AppColors.primary)),
                  ),
                  title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(b.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(bookId: b.bookId))),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () async {
                      await ref.read(collectionsRepositoryProvider).removeBook(c.id, b.bookId);
                      _loadCollections();
                    },
                  ),
                ),
              )),
          ],
        )).toList(),
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
          ...groups[key]!.map((book) => _BookCard(
            book: book, onTap: () => _openBook(book),
            collections: _collections, onCollectionsChanged: _loadCollections,
          )),
        ],
      )).toList(),
    );
  }

  void _openBook(BookModel book) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(bookId: book.id)));
  }
}

class _BookCard extends ConsumerStatefulWidget {
  final BookModel book;
  final VoidCallback onTap;
  final List<CollectionModel> collections;
  final VoidCallback? onCollectionsChanged;
  const _BookCard({
    required this.book,
    required this.onTap,
    this.collections = const [],
    this.onCollectionsChanged,
  });

  @override
  ConsumerState<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends ConsumerState<_BookCard> {
  BookModel get book => widget.book;
  VoidCallback get onTap => widget.onTap;

  DownloadState _state = DownloadState.notDownloaded;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    final service = ref.read(downloadServiceProvider);
    final downloaded = await service.isDownloaded(book.id);
    if (mounted) setState(() => _state = downloaded ? DownloadState.downloaded : DownloadState.notDownloaded);
  }

  Future<void> _toggleDownload() async {
    final service = ref.read(downloadServiceProvider);
    if (_state == DownloadState.downloaded) {
      await service.deleteDownload(book.id);
      if (mounted) setState(() => _state = DownloadState.notDownloaded);
      return;
    }

    setState(() => _state = DownloadState.downloading);
    final sub = service.progressStream(book.id).listen((p) {
      if (mounted) setState(() { _progress = p.progress; _state = p.state; });
    });
    try {
      await service.downloadBook(book);
    } catch (e) {
      if (mounted) {
        setState(() => _state = DownloadState.failed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      sub.cancel();
    }
  }

  Widget _downloadIcon() {
    switch (_state) {
      case DownloadState.downloading:
        return SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, value: _progress > 0 ? _progress : null),
        );
      case DownloadState.downloaded:
        return const Icon(Icons.download_done, color: AppColors.primary);
      case DownloadState.failed:
        return const Icon(Icons.error_outline, color: AppColors.error);
      case DownloadState.notDownloaded:
        return const Icon(Icons.download_outlined, color: Colors.grey);
    }
  }

  Future<void> _addToCollection(String collectionId) async {
    try {
      await ref.read(collectionsRepositoryProvider).addBook(collectionId, book.id);
      widget.onCollectionsChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "${book.title}" to collection')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _createAndAddToCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(controller: controller, autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Summer Reading')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final collection = await ref.read(collectionsRepositoryProvider).createCollection(name);
    await _addToCollection(collection.id);
  }

  Future<void> _showAddToCollectionMenu() async {
    if (widget.collections.isEmpty) {
      await _createAndAddToCollection();
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ...widget.collections.map((c) => ListTile(
            leading: const Icon(Icons.collections_bookmark),
            title: Text(c.name),
            onTap: () => Navigator.pop(context, c.id),
          )),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New Collection…'),
            onTap: () => Navigator.pop(context, '__new__'),
          ),
        ]),
      ),
    );
    if (selected == null) return;
    if (selected == '__new__') {
      await _createAndAddToCollection();
      return;
    }
    await _addToCollection(selected);
  }

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
              IconButton(
                icon: const Icon(Icons.collections_bookmark_outlined, color: Colors.grey),
                tooltip: 'Add to collection',
                onPressed: _showAddToCollectionMenu,
              ),
              IconButton(
                icon: _downloadIcon(),
                tooltip: _state == DownloadState.downloaded ? 'Remove download' : 'Download for offline',
                onPressed: _state == DownloadState.downloading ? null : _toggleDownload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
