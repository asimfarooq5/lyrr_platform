import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/player_controller.dart';
import 'controllers/reader_controller.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

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
        title: 'LYRR Sync Engine POC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getDarkTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
