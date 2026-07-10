import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player;
  double _speed = 1.0;

  AudioPlayer get player => _player;
  double get speed => _speed;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  AudioService() : _player = AudioPlayer() {
    _player.setVolume(1.0);
  }

  Future<void> setAsset(String assetPath) async {
    try {
      await _player.setAudioSource(
        AudioSource.asset(assetPath),
        preload: true,
      );
      await _player.setVolume(1.0);
      await _player.setSpeed(_speed);
      debugPrint('Audio loaded: $assetPath');
    } catch (e) {
      debugPrint('Audio setAsset error: $e');
    }
  }

  Future<void> play() async {
    try {
      await _player.seek(_player.position);
      await _player.setVolume(1.0);
      await _player.play();
      debugPrint('Audio playing: ${_player.playing}');
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 3.0);
    await _player.setSpeed(_speed);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
