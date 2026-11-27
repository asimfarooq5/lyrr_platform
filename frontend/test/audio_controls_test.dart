import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyrr/presentation/screens/reader/widgets/audio_controls.dart';

void main() {
  group('AudioControls Widget Tests', () {
    testWidgets('renders docked mini-player bar with chapter title and play button', (tester) async {
      var playPauseTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioControls(
              isPlaying: false,
              currentPosition: const Duration(minutes: 2, seconds: 15),
              totalDuration: const Duration(minutes: 10),
              playbackSpeed: 1.0,
              bookTitle: 'The Great Adventure',
              chapterTitle: 'Chapter 1: The Beginning',
              authorName: 'Arthur Conan',
              onPlayPause: () => playPauseTapped = true,
              onSeek: (_) {},
              onSpeedChange: (_) {},
              onTtsToggle: () {},
            ),
          ),
        ),
      );

      // Verify mini-player displays title and duration
      expect(find.text('Chapter 1: The Beginning'), findsOneWidget);
      expect(find.textContaining('02:15 / 10:00'), findsOneWidget);
      expect(find.text('Studio Narration'), findsOneWidget);

      // Tap play button
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      expect(playPauseTapped, isTrue);
    });

    testWidgets('renders AI Voice badge when in TTS mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioControls(
              isPlaying: true,
              isTtsMode: true,
              isTtsPlaying: true,
              currentPosition: Duration.zero,
              totalDuration: Duration.zero,
              playbackSpeed: 1.0,
              bookTitle: 'Test Book',
              chapterTitle: 'Chapter 2',
              onPlayPause: () {},
              onSeek: (_) {},
              onSpeedChange: (_) {},
              onTtsToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('AI Voice'), findsOneWidget);
      expect(find.textContaining('Narrating text'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('displays active sleep timer badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioControls(
              isPlaying: true,
              currentPosition: const Duration(seconds: 30),
              totalDuration: const Duration(minutes: 5),
              playbackSpeed: 1.0,
              sleepTimerRemaining: const Duration(minutes: 24, seconds: 10),
              onPlayPause: () {},
              onSeek: (_) {},
              onSpeedChange: (_) {},
              onTtsToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('24m'), findsOneWidget);
      expect(find.byIcon(Icons.bedtime), findsOneWidget);
    });
  });
}
