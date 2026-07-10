import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = context.watch<PlayerController>();

    final isPlaying = playerController.isPlaying;
    final isLoading = playerController.isLoading;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.replay_10_rounded),
          iconSize: 36,
          color: Colors.grey[300],
          onPressed: () => playerController.skipBackward(const Duration(seconds: 10)),
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: isLoading ? null : () => playerController.togglePlayPause(),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withAlpha(102),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          icon: const Icon(Icons.forward_10_rounded),
          iconSize: 36,
          color: Colors.grey[300],
          onPressed: () => playerController.skipForward(const Duration(seconds: 10)),
        ),
      ],
    );
  }
}
