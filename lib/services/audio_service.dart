import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  double _speed = 1.0;

  AudioPlayer get player => _player;
  double get speed => _speed;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> setAsset(String assetPath) async {
    try {
      debugPrint('Loading audio: $assetPath');
      await _player.setAsset(assetPath);
      await _player.setVolume(1.0);
      debugPrint('Audio loaded. Duration: ${_player.duration}');
    } catch (e, s) {
      debugPrint('Audio error: $e\n$s');
    }
  }

  Future<void> play() async {
    try {
      await _player.setVolume(1.0);
      await _player.seek(_player.position);
      await _player.play();
      debugPrint('Playing: ${_player.playing}');
    } catch (e) {
      debugPrint('Play error: $e');
    }
  }

  Future<void> pause() async => await _player.pause();
  Future<void> seek(Duration p) async => await _player.seek(p);

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 3.0);
    await _player.setSpeed(_speed);
  }

  Future<void> dispose() async => await _player.dispose();
}
