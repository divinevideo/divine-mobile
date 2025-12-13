// ABOUTME: Video editor screen for adding text overlays and sound to recorded videos
// ABOUTME: Dark-themed interface with video preview, text editing, and sound selection

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/widgets/text_overlay/text_overlay_editor.dart';
import 'package:openvine/widgets/text_overlay/draggable_text_overlay.dart';
import 'package:openvine/widgets/sound_picker/sound_picker_modal.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({
    super.key,
    required this.videoPath,
    this.onExport,
    this.onBack,
  });

  final String videoPath;
  final VoidCallback? onExport;
  final VoidCallback? onBack;

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  Size _videoSize = const Size(16, 9); // Default aspect ratio

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.file(File(widget.videoPath));
    await controller.initialize();
    await controller.setLooping(true);
    await controller.play();

    if (mounted) {
      setState(() {
        _videoController = controller;
        _isVideoInitialized = true;
        _videoSize = controller.value.size;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _handleAddText() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TextOverlayEditor(
        onSave: (overlay) {
          ref.read(videoEditorProvider(widget.videoPath).notifier).addTextOverlay(overlay);
          Navigator.of(context).pop();
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _handleAddSound() {
    final soundService = ref.read(soundLibraryServiceProvider);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SoundPickerModal(
          sounds: soundService.sounds,
          selectedSoundId: ref.read(videoEditorProvider(widget.videoPath)).selectedSoundId,
          onSoundSelected: (soundId) {
            ref.read(videoEditorProvider(widget.videoPath).notifier).selectSound(soundId);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _handleDone() {
    widget.onExport?.call();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _updateTextOverlayPosition(String id, Offset normalizedPosition) {
    final state = ref.read(videoEditorProvider(widget.videoPath));
    final overlay = state.textOverlays.firstWhere((o) => o.id == id);
    final updatedOverlay = overlay.copyWith(normalizedPosition: normalizedPosition);
    ref.read(videoEditorProvider(widget.videoPath).notifier).updateTextOverlay(id, updatedOverlay);
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(videoEditorProvider(widget.videoPath));
    final soundService = ref.watch(soundLibraryServiceProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBack,
        ),
        title: const Text(
          'Edit Video',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _handleDone,
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video preview area
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: _isVideoInitialized && _videoController != null
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            VideoPlayer(_videoController!),
                            // Text overlays
                            ...editorState.textOverlays.map((overlay) {
                              return DraggableTextOverlay(
                                overlay: overlay,
                                videoSize: _videoSize,
                                onPositionChanged: (position) => _updateTextOverlayPosition(
                                  overlay.id,
                                  position,
                                ),
                              );
                            }),
                          ],
                        ),
                      )
                    : const CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),

          // Selected sound indicator
          if (editorState.selectedSoundId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[900],
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Sound: ${soundService.getSoundById(editorState.selectedSoundId!)?.title ?? 'Unknown'}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),

          // Bottom action buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleAddText,
                    icon: const Icon(Icons.text_fields),
                    label: const Text('Add Text'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleAddSound,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Add Sound'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
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
