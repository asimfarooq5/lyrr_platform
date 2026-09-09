/// Audio Controls Widget
/// Floating "Audible-style" playback pill: big transport controls with
/// ±10s skip, a full-width scrub bar, and secondary speed/TTS controls.

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class AudioControls extends StatelessWidget {
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final double playbackSpeed;
  final bool isTtsPlaying;
  final bool isTtsMode;
  final VoidCallback onPlayPause;
  final Function(Duration) onSeek;
  final Function(double) onSpeedChange;
  final VoidCallback onTtsToggle;
  final Color? textColor;
  final Color? bgColor;

  const AudioControls({
    super.key,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.playbackSpeed,
    this.isTtsPlaying = false,
    this.isTtsMode = false,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSpeedChange,
    required this.onTtsToggle,
    this.textColor,
    this.bgColor,
  });

  String _formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _skip(Duration delta) {
    var next = currentPosition + delta;
    if (next < Duration.zero) next = Duration.zero;
    if (next > totalDuration) next = totalDuration;
    onSeek(next);
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalDuration.inMilliseconds > 0
        ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
        : 0.0;

    // A floating dark pill reads consistently over every reading theme
    // (light/sepia/dark/green backgrounds), so it stays fixed rather than
    // following textColor/bgColor.
    const fg = Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        decoration: BoxDecoration(
          color: const Color(0xE61A1425),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Secondary controls: speed + read-aloud toggle
            Row(
              children: [
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    const speeds = [1.0, 1.25, 1.5, 1.75, 2.0, 0.75, 0.5];
                    final currentIdx = speeds.indexOf(playbackSpeed);
                    final nextSpeed = speeds[(currentIdx + 1) % speeds.length];
                    onSpeedChange(nextSpeed);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${playbackSpeed}x',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onTtsToggle,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: isTtsMode ? const Color(0xFFef4444) : fg.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTtsPlaying ? Icons.record_voice_over : Icons.volume_up,
                      color: fg,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Scrub bar
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primaryLight,
                inactiveTrackColor: fg.withValues(alpha: 0.2),
                thumbColor: AppColors.primaryLight,
                overlayColor: AppColors.primaryLight.withValues(alpha: 0.15),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (value) {
                  onSeek(Duration(
                    milliseconds: (value * totalDuration.inMilliseconds).round(),
                  ));
                },
              ),
            ),

            // Elapsed / total
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(currentPosition),
                      style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.65))),
                  Text(_formatDuration(totalDuration),
                      style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.65))),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Transport: -10s, play/pause, +10s
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SkipButton(icon: Icons.replay_10, onTap: () => _skip(const Duration(seconds: -10))),
                const SizedBox(width: 28),
                GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 64, height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                _SkipButton(icon: Icons.forward_10, onTap: () => _skip(const Duration(seconds: 10))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SkipButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
