// ABOUTME: List item widget for sound selection with play/pause preview
// ABOUTME: Dark theme design with selection indicator and duration display

import 'package:flutter/material.dart';
import 'package:openvine/models/vine_sound.dart';

class SoundListItem extends StatelessWidget {
  const SoundListItem({
    required this.sound,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
    super.key,
  });

  final VineSound sound;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
        ),
        onPressed: onPlayPause,
      ),
      title: Text(
        sound.title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        sound.artist ?? 'Unknown Artist',
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${sound.durationInSeconds.round()}s',
            style: const TextStyle(color: Colors.grey),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.check_circle,
              color: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}
