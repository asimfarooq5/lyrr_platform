/// Audio Controls Widget
/// 
/// Playback controls for synchronized audio

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../theme/app_theme.dart';

class AudioControls extends StatelessWidget {
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final double playbackSpeed;
  final VoidCallback onPlayPause;
  final Function(Duration) onSeek;
  final Function(double) onSpeedChange;

  const AudioControls({
    super.key,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.playbackSpeed,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSpeedChange,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = totalDuration.inMilliseconds > 0
        ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.grey[300],
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withOpacity(0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (value) {
                  final position = Duration(
                    milliseconds: (value * totalDuration.inMilliseconds).round(),
                  );
                  onSeek(position);
                },
              ),
            ),
            
            // Time display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(currentPosition),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    _formatDuration(totalDuration),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Speed button
                _SpeedButton(
                  speed: playbackSpeed,
                  onSpeedChange: onSpeedChange,
                ),
                
                const SizedBox(width: 32),
                
                // Play/Pause button
                IconButton(
                  iconSize: 56,
                  icon: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  onPressed: onPlayPause,
                ),
                
                const SizedBox(width: 32),
                
                // Placeholder for additional controls
                const SizedBox(width: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final double speed;
  final Function(double) onSpeedChange;

  const _SpeedButton({
    required this.speed,
    required this.onSpeedChange,
  });

  static const List<double> speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      initialValue: speed,
      onSelected: onSpeedChange,
      itemBuilder: (context) => speeds.map((s) {
        return PopupMenuItem(
          value: s,
          child: Text('${s}x'),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${speed}x',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
