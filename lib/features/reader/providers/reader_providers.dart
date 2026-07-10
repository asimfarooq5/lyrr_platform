import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/constants.dart';
import '../../../models/sync_word.dart';
import '../../../data/repositories/sync_engine.dart';
import '../../../services/book_repository.dart';
import 'audio_service.dart';

// Audio service singleton
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Audio playback position (updated by notifier)
final audioPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

// Audio duration
final audioDurationProvider = StateProvider<Duration>((ref) => Duration.zero);

// Is playing
final isPlayingProvider = StateProvider<bool>((ref) => false);

// Is loading
final isLoadingProvider = StateProvider<bool>((ref) => false);

// Playback speed
final playbackSpeedProvider = StateProvider<double>((ref) => 1.0);

// Book data loading
final bookDataProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, bookId) async {
  final repo = BookRepository();
  final book = await repo.loadBook();
  final syncData = await repo.loadSyncData();
  return {'book': book, 'syncData': syncData};
});

// Sync engine family (one per book)
final syncEngineProvider = Provider.family<SyncEngine?, String>((ref, bookId) {
  final bookData = ref.watch(bookDataProvider(bookId));
  final data = bookData.valueOrNull;
  if (data == null) return null;
  final syncData = data['syncData'] as List<SyncWord>?;
  if (syncData == null) return null;
  return SyncEngine(syncData);
});

// Active word ID (derived from position + sync engine)
final activeWordIdProvider = Provider.family<String?, String>((ref, bookId) {
  final position = ref.watch(audioPositionProvider);
  final engine = ref.watch(syncEngineProvider(bookId));
  if (engine == null) return null;
  return engine.getActiveWordId(position.inMilliseconds / 1000.0);
});

// Reader settings
class ReaderSettings {
  final double fontSize;
  final double lineSpacing;
  final ReaderThemeMode themeMode;

  const ReaderSettings({
    this.fontSize = 20.0,
    this.lineSpacing = 1.4,
    this.themeMode = ReaderThemeMode.dark,
  });

  ReaderSettings copyWith({
    double? fontSize,
    double? lineSpacing,
    ReaderThemeMode? themeMode,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  ReaderSettingsNotifier() : super(const ReaderSettings());

  void increaseFontSize() {
    state = state.copyWith(fontSize: (state.fontSize + 2).clamp(12.0, 36.0));
  }

  void decreaseFontSize() {
    state = state.copyWith(fontSize: (state.fontSize - 2).clamp(12.0, 36.0));
  }

  void setLineSpacing(double spacing) {
    state = state.copyWith(lineSpacing: spacing.clamp(1.0, 2.5));
  }

  void setThemeMode(ReaderThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }
}

final readerSettingsProvider = StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
  return ReaderSettingsNotifier();
});

// Audio initialization
final audioInitProvider = FutureProvider.family<void, String>((ref, bookId) async {
  final audioService = ref.watch(audioServiceProvider);
  await audioService.setAsset(AppConstants.audioPath);
});

// Audio position subscription (manages the stream subscription)
final audioPositionSubscriptionProvider = Provider.autoDispose<StreamSubscription<Duration>>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final sub = audioService.positionStream.listen((pos) {
    ref.read(audioPositionProvider.notifier).state = pos;
  });
  ref.onDispose(() => sub.cancel());
  return sub;
});

final audioDurationSubscriptionProvider = Provider.autoDispose<StreamSubscription<Duration?>>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final sub = audioService.durationStream.listen((dur) {
    if (dur != null) ref.read(audioDurationProvider.notifier).state = dur;
  });
  ref.onDispose(() => sub.cancel());
  return sub;
});

final audioStateSubscriptionProvider = Provider.autoDispose<StreamSubscription<PlayerState>>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final sub = audioService.playerStateStream.listen((state) {
    ref.read(isPlayingProvider.notifier).state = state.playing;
    final isLoading = state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering;
    ref.read(isLoadingProvider.notifier).state = isLoading;
  });
  ref.onDispose(() => sub.cancel());
  return sub;
});

// Combine all subscriptions
final audioSubscriptionsProvider = Provider.autoDispose<void>((ref) {
  ref.watch(audioPositionSubscriptionProvider);
  ref.watch(audioDurationSubscriptionProvider);
  ref.watch(audioStateSubscriptionProvider);
});
