import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> setAsset(String assetPath) async {
    await _player.setAudioSource(AudioSource.asset(assetPath));
  }

  Future<void> play() async { await _player.play(); }
  Future<void> pause() async { await _player.pause(); }
  Future<void> seek(Duration position) async { await _player.seek(position); }

  Future<void> dispose() async { await _player.dispose(); }
}
