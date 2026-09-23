/// Thin wrapper over `flutter_tts`.
///
/// This is the ONLY file in the reader feature that imports `flutter_tts`, so
/// swapping the TTS backend would touch nothing else. It exposes the engine in
/// domain terms (`speak` / `pause` / `stop` / rate / pitch) and translates the
/// plugin's raw callback API into plain Dart callbacks.

import 'dart:developer' as developer;

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_tts/flutter_tts.dart';

/// Outcome of [TtsService.initialize] — a device either has a usable engine in
/// the requested language or it does not, and the UI needs to say which.
sealed class TtsInitResult {
  const TtsInitResult();
}

class TtsInitSuccess extends TtsInitResult {
  const TtsInitSuccess();
}

/// No engine, or an engine with no installed languages.
class TtsInitUnavailable extends TtsInitResult {
  const TtsInitUnavailable();
}

/// Engine present, but the book's language is not installed.
class TtsInitUnsupportedLanguage extends TtsInitResult {
  const TtsInitUnsupportedLanguage(this.languageCode);
  final String languageCode;
}

/// Engine present, but initialization failed for another reason.
class TtsInitFailure extends TtsInitResult {
  const TtsInitFailure(this.message);
  final String message;
}

class TtsService {
  TtsService({FlutterTts? flutterTts}) : _tts = flutterTts ?? FlutterTts();

  final FlutterTts _tts;

  /// Used until the caller supplies the book's language.
  static const String defaultLanguage = 'en-US';

  /// flutter_tts's rate scale is `0.0`–`1.0`; its raw platform default is
  /// uncomfortably fast for continuous narration, so we start lower.
  static const double defaultSpeechRate = 0.5;
  static const double defaultPitch = 1.0;
  static const double defaultVolume = 1.0;

  /// Maps a book's two-letter language code to a BCP-47 tag.
  static String languageCodeFor(String? language) {
    switch (language?.toLowerCase()) {
      case 'fr':
        return 'fr-FR';
      case 'es':
        return 'es-ES';
      case 'de':
        return 'de-DE';
      case 'it':
        return 'it-IT';
      case 'pt':
        return 'pt-PT';
      case 'ru':
        return 'ru-RU';
      case 'ja':
        return 'ja-JP';
      case 'zh':
        return 'zh-CN';
      case 'ko':
        return 'ko-KR';
      case 'ar':
        return 'ar-SA';
      default:
        return defaultLanguage;
    }
  }

  /// Registers every native callback. Called once, from the controller's
  /// constructor body (not its initializer list — `this` must be fully
  /// constructed before its methods can be handed out as callbacks).
  void attachHandlers({
    required void Function() onStart,
    required void Function() onContinue,
    required void Function() onPause,
    required void Function() onCompletion,
    required void Function() onCancel,
    required void Function(String message) onError,
    void Function(String word, int startOffset, int endOffset)? onProgress,
  }) {
    _tts.setStartHandler(onStart);
    _tts.setContinueHandler(onContinue);
    _tts.setPauseHandler(onPause);
    _tts.setCompletionHandler(onCompletion);
    _tts.setCancelHandler(onCancel);
    _tts.setErrorHandler((dynamic message) => onError(message.toString()));

    // Word-boundary reporting is optional: playback works without it, and
    // making it required would misstate that as a hard dependency.
    if (onProgress != null) {
      _tts.setProgressHandler(
        (String text, int startOffset, int endOffset, String word) {
          onProgress(word, startOffset, endOffset);
        },
      );
    }
  }

  /// Verifies the engine is usable in [language] and configures it, without
  /// speaking anything. Must complete before [speak] is called.
  Future<TtsInitResult> initialize({String language = defaultLanguage}) async {
    try {
      final dynamic rawLanguages = await _tts.getLanguages;
      final languages = rawLanguages is List ? rawLanguages : const [];
      if (languages.isEmpty) return const TtsInitUnavailable();

      final isAvailable = await _tts.isLanguageAvailable(language);
      if (isAvailable != true) return TtsInitUnsupportedLanguage(language);

      await _tts.setLanguage(language);
      // Force QUEUE_FLUSH explicitly rather than relying on the plugin's
      // unstated default, so a long session can never leave the engine with
      // backlog to work through before a Play tap makes sound.
      await _tts.setQueueMode(0);
      await _tts.setSpeechRate(defaultSpeechRate);
      await _tts.setPitch(defaultPitch);

      // Android's TTS engine lives in its own system service process. If the
      // app was killed outright there is no shutdown call telling that
      // service its previous client is gone, so an utterance from a previous
      // session can survive and play on the first speak() of this one.
      // Stopping once here guarantees a clean engine start. There may be
      // nothing to stop, which is not an error.
      await _tts.stop();

      return const TtsInitSuccess();
    } on PlatformException catch (e) {
      return TtsInitFailure(e.message ?? e.code);
    } catch (e) {
      return TtsInitFailure(e.toString());
    }
  }

  /// Starts speaking [text], or resumes a paused utterance.
  ///
  /// Android has no native pause; the plugin implements it by remembering the
  /// word-boundary offset and slicing the text on the next `speak()`. That is
  /// why resuming means calling `speak()` again rather than a `resume()`.
  Future<bool> speak(String text) =>
      _runAndCheckSuccess(() => _tts.speak(text));

  Future<bool> pause() => _runAndCheckSuccess(() => _tts.pause());

  /// Stops playback entirely — a later [speak] starts from the beginning of
  /// whatever text it is given.
  Future<bool> stop() => _runAndCheckSuccess(() => _tts.stop());

  Future<bool> setSpeechRate(double rate) =>
      _runAndCheckSuccess(() => _tts.setSpeechRate(rate));

  Future<bool> setPitch(double pitch) =>
      _runAndCheckSuccess(() => _tts.setPitch(pitch));

  /// Sets narration volume on flutter_tts's own `0.0`–`1.0` scale (FRS §7).
  Future<bool> setVolume(double volume) =>
      _runAndCheckSuccess(() => _tts.setVolume(volume.clamp(0.0, 1.0)));

  /// Treats a `1` result as success and every other outcome — including a
  /// thrown exception — as `false`, so callers never have to wrap TTS calls
  /// in try/catch themselves.
  Future<bool> _runAndCheckSuccess(Future<dynamic> Function() action) async {
    try {
      final result = await action();
      return result == 1;
    } catch (error, stackTrace) {
      // Logged rather than silently swallowed: a discarded platform
      // exception is exactly what made an earlier chunking bug invisible.
      developer.log(
        'TtsService call failed: $error',
        name: 'TtsService',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
