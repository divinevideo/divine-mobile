// ABOUTME: Thumbnail widget for a single clip in the Clip Manager grid
// ABOUTME: Shows thumbnail image, duration badge, delete button, play icon

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';

class SegmentThumbnail extends StatelessWidget {
  const SegmentThumbnail({
    super.key,
    required this.clip,
    required this.onTap,
    required this.onDelete,
    this.isSelected = false,
  });

  final RecordingClip clip;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Colors.green, width: 2)
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail image or placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildThumbnail(),
            ),

            // Play icon overlay
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white70,
                size: 40,
              ),
            ),

            // Duration badge
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${clip.durationInSeconds.toStringAsFixed(1)}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Delete button
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (clip.thumbnailPath != null && File(clip.thumbnailPath!).existsSync()) {
      return Image.file(
        File(clip.thumbnailPath!),
        fit: BoxFit.cover,
      );
    }

    // Placeholder when no thumbnail
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(
          Icons.videocam,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}
