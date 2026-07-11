import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_session/audio_session.dart';
import 'data/datasources/local/hive_database.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
    debugPrint('Audio session configured');
  } catch (e) {
    debugPrint('Audio session error: $e');
  }

  await HiveDatabase.init();
  runApp(
    const ProviderScope(
      child: LyrrApp(),
    ),
  );
}
