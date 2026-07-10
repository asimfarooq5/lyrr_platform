import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_service.dart';

class PlayerController extends ChangeNotifier {
  final AudioService _audioService;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;

  PlayerController({AudioService? audioService})
      : _audioService = audioService ?? AudioService() {
    _init();
  }

  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  AudioService get audioService => _audioService;

  void _init() {
    _positionSub = _audioService.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _durationSub = _audioService.durationStream.listen((dur) {
      if (dur != null) { _duration = dur; notifyListeners(); }
    });
    _stateSub = _audioService.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
                   state.processingState == ProcessingState.buffering;
      notifyListeners();
    });
  }

  Future<void> loadAudio(String assetPath) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _audioService.setAsset(assetPath);
    } catch (e) {
      debugPrint('Error loading audio: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> play() async { await _audioService.play(); }
  Future<void> pause() async { await _audioService.pause(); }

  Future<void> togglePlayPause() async {
    if (_isPlaying) await pause(); else await play();
  }

  Future<void> seek(Duration targetPosition) async {
    var pos = targetPosition;
    if (pos < Duration.zero) pos = Duration.zero;
    if (pos > _duration) pos = _duration;
    await _audioService.seek(pos);
  }

  Future<void> skipForward(Duration offset) async { await seek(_position + offset); }
  Future<void> skipBackward(Duration offset) async { await seek(_position - offset); }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
