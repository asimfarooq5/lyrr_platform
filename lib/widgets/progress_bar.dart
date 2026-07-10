import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';
import '../utils/duration_extensions.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = context.watch<PlayerController>();

    final position = playerController.position;
    final duration = playerController.duration;

    final posSeconds = position.inSeconds.toDouble();
    final durSeconds = duration.inSeconds.toDouble();

    // Clamp values to prevent layout/range errors
    final sliderValue = durSeconds > 0 ? posSeconds.clamp(0.0, durSeconds) : 0.0;
    final maxSliderValue = durSeconds > 0 ? durSeconds : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Colors.grey[800],
              thumbColor: Theme.of(context).colorScheme.primary,
              overlayColor: Theme.of(context).colorScheme.primary.withAlpha(51),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: sliderValue,
              max: maxSliderValue,
              onChanged: (value) {
                playerController.seek(Duration(seconds: value.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  position.toFormattedString(),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  duration.toFormattedString(),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
