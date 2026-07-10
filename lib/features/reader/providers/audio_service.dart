import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  double _speed = 1.0;
  double get speed => _speed;

  Future<void> setAsset(String assetPath) async {
    await _player.setAsset(assetPath);
    await _player.setSpeed(_speed);
  }

  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
    await _player.setSpeed(_speed);
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 3.0);
    await _player.setSpeed(_speed);
  }

  Future<void> play() async => await _player.play();
  Future<void> pause() async => await _player.pause();
  Future<void> seek(Duration position) async => await _player.seek(position);
  Future<void> dispose() async => await _player.dispose();
}
