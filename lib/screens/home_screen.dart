import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/reader_controller.dart';
import '../widgets/book_cover.dart';
import '../widgets/loading_indicator.dart';
import '../utils/duration_extensions.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReaderController>().loadBookData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final readerController = context.watch<ReaderController>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // deep slate
              Color(0xFF0B0C10), // black
            ],
          ),
        ),
        child: SafeArea(
          child: readerController.isLoading || readerController.book == null
              ? const LoadingIndicator(message: 'Initializing Sample Book...')
              : Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          BookCover(
                            metadata: readerController.book!.metadata,
                            height: 320,
                            width: 240,
                          ),
                          const SizedBox(height: 32),
                          Text(
                            readerController.book!.metadata.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'by ${readerController.book!.metadata.author}',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMetaBadge(
                                icon: Icons.audiotrack_rounded,
                                label: Duration(seconds: readerController.book!.metadata.duration).toFormattedString(),
                              ),
                              const SizedBox(width: 16),
                              _buildMetaBadge(
                                icon: Icons.translate_rounded,
                                label: readerController.book!.metadata.language.toUpperCase(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 48),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const ReaderScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1), // indigo
                                    Color(0xFF06B6D4), // cyan
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withAlpha(102),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.menu_book_rounded, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text(
                                    'Start Reading & Listening',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMetaBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF06B6D4)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
