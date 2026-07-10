import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/player_controller.dart';
import 'controllers/reader_controller.dart';
import 'theme/app_theme.dart';
import 'features/library/screens/library_screen.dart';

class LyrrApp extends StatelessWidget {
  const LyrrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerController()),
        ChangeNotifierProvider(create: (_) => ReaderController()),
      ],
      child: MaterialApp(
        title: 'LYRR',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getDarkTheme(),
        home: const LibraryScreen(),
      ),
    );
  }
}
