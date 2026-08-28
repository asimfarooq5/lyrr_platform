/// Audio Controls Widget
/// Kindle-style compact playback controls with TTS (Read Aloud) support

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
    return h > 0 ? '${h}h ${m}m' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Colors.black87;
    final bg = bgColor ?? Colors.white;
    final progress = totalDuration.inMilliseconds > 0
        ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Time elapsed
          Text(
            _formatDuration(currentPosition),
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.6)),
          ),
          const SizedBox(width: 8),
          
          // Progress bar
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: color.withOpacity(0.15),
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withOpacity(0.15),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
          ),
          const SizedBox(width: 8),
          
          // Time remaining
          Text(
            '-${_formatDuration(totalDuration - currentPosition)}',
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.6)),
          ),
          const SizedBox(width: 12),
          
          // Speed button
          GestureDetector(
            onTap: () {
              const speeds = [1.0, 1.25, 1.5, 1.75, 2.0, 0.75, 0.5];
              final currentIdx = speeds.indexOf(playbackSpeed);
              final nextSpeed = speeds[(currentIdx + 1) % speeds.length];
              onSpeedChange(nextSpeed);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${playbackSpeed}x',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Read Aloud (TTS) button
          GestureDetector(
            onTap: onTtsToggle,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isTtsMode ? const Color(0xFFef4444) : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isTtsPlaying ? Icons.record_voice_over : Icons.volume_up,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Play/Pause (audiobook)
          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
