// ABOUTME: Video editor screen for adding text overlays and sound to recorded videos
// ABOUTME: Dark-themed interface with video preview, text editing, and sound selection

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/widgets/text_overlay/text_overlay_editor.dart';
import 'package:openvine/widgets/text_overlay/draggable_text_overlay.dart';
import 'package:openvine/widgets/sound_picker/sound_picker_modal.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_export_service.dart';
import 'package:openvine/services/text_overlay_renderer.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

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
  AudioPlayer? _audioPlayer;
  String? _currentSoundId;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _audioPlayer = AudioPlayer();
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
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  /// Load and play the selected sound, synced with video
  Future<void> _loadAndPlaySound(String? soundId) async {
    if (soundId == _currentSoundId) return;
    _currentSoundId = soundId;

    // Stop current audio
    await _audioPlayer?.stop();

    if (soundId == null) {
      // No sound selected - unmute video
      await _videoController?.setVolume(1.0);
      return;
    }

    // Mute video's original audio when playing selected sound
    await _videoController?.setVolume(0.0);

    // Get the sound's asset path
    final soundService = await ref.read(soundLibraryServiceProvider.future);
    final sound = soundService.getSoundById(soundId);

    if (sound == null) {
      Log.warning(
        'Sound not found: $soundId',
        category: LogCategory.video,
      );
      return;
    }

    try {
      String filePath;

      // Load the audio - handle both asset paths and file paths
      if (sound.assetPath.startsWith('/') || sound.assetPath.startsWith('file://')) {
        // Custom sound - file path
        filePath = sound.assetPath.replaceFirst('file://', '');
      } else {
        // Bundled asset - copy to temp file for reliable playback on desktop
        final tempDir = await getTemporaryDirectory();
        final extension = sound.assetPath.split('.').last;
        filePath = '${tempDir.path}/editor_${sound.id}.$extension';

        final tempFile = File(filePath);
        if (!await tempFile.exists()) {
          final assetData = await rootBundle.load(sound.assetPath);
          await tempFile.writeAsBytes(assetData.buffer.asUint8List());
        }
      }

      await _audioPlayer?.setFilePath(filePath);

      // Set looping to match video
      await _audioPlayer?.setLoopMode(LoopMode.one);

      // Play the audio
      await _audioPlayer?.play();

      Log.info(
        'Playing sound: ${sound.title}',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        'Failed to play sound: $e',
        category: LogCategory.video,
      );
      // Unmute video on error
      await _videoController?.setVolume(1.0);
    }
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

  void _handleAddSound() async {
    // Pause video and audio while selecting sound
    await _videoController?.pause();
    await _audioPlayer?.pause();

    // Wait for sounds to load
    final soundServiceAsync = await ref.read(soundLibraryServiceProvider.future);

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SoundPickerModal(
          sounds: soundServiceAsync.sounds,
          selectedSoundId:
              ref.read(videoEditorProvider(widget.videoPath)).selectedSoundId,
          onSoundSelected: (soundId) {
            ref
                .read(videoEditorProvider(widget.videoPath).notifier)
                .selectSound(soundId);
            // Play the selected sound in preview
            _loadAndPlaySound(soundId);
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    // Resume video after returning from sound picker
    if (mounted) {
      await _videoController?.play();
      // Audio will resume via _loadAndPlaySound if a sound is selected
    }
  }

  Future<void> _handleDone() async {
    // Stop audio preview before processing
    await _audioPlayer?.stop();

    try {
      Log.info(
        '📹 VideoEditorScreen: Creating draft for video: ${widget.videoPath}',
        category: LogCategory.video,
      );

      // Get the current editor state for text overlays
      final editorState = ref.read(videoEditorProvider(widget.videoPath));
      String finalVideoPath = widget.videoPath;

      // Apply text overlays if any exist
      if (editorState.textOverlays.isNotEmpty && _isVideoInitialized && _videoController != null) {
        Log.info(
          '📹 Burning ${editorState.textOverlays.length} text overlays into video',
          category: LogCategory.video,
        );

        // Use the actual video resolution for rendering overlays
        final videoSize = _videoController!.value.size;

        // Render text overlays to PNG
        final renderer = TextOverlayRenderer();
        final overlayImage = await renderer.renderOverlays(
          editorState.textOverlays,
          videoSize,
        );

        // Apply overlay to video using FFmpeg
        final exportService = VideoExportService();
        finalVideoPath = await exportService.applyTextOverlay(
          widget.videoPath,
          overlayImage,
        );

        Log.info(
          '📹 Text overlays burned into video: $finalVideoPath',
          category: LogCategory.video,
        );
      }

      // Apply sound overlay if one is selected
      if (editorState.selectedSoundId != null) {
        Log.info(
          '📹 Mixing sound: ${editorState.selectedSoundId}',
          category: LogCategory.video,
        );

        // Look up the sound's asset path from the sound library
        final soundService = await ref.read(soundLibraryServiceProvider.future);
        final sound = soundService.getSoundById(editorState.selectedSoundId!);

        if (sound != null) {
          final exportService = VideoExportService();
          final previousPath = finalVideoPath;
          finalVideoPath = await exportService.mixAudio(
            finalVideoPath,
            sound.assetPath,
          );

          // Clean up previous temp file if it was a temp file (not original)
          if (previousPath != widget.videoPath) {
            try {
              await File(previousPath).delete();
            } catch (e) {
              Log.warning(
                'Failed to delete temp file: $previousPath',
                category: LogCategory.video,
              );
            }
          }

          Log.info(
            '📹 Sound mixed into video: $finalVideoPath',
            category: LogCategory.video,
          );
        } else {
          Log.warning(
            '📹 Sound not found: ${editorState.selectedSoundId}',
            category: LogCategory.video,
          );
        }
      }

      // Create draft storage service
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      // Get the aspect ratio from recording state
      final recordingState = ref.read(vineRecordingProvider);
      final aspectRatio = recordingState.aspectRatio;

      // Create a draft for the edited video (with overlays burned in)
      final draft = VineDraft.create(
        videoFile: File(finalVideoPath),
        title: '',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'video',
        aspectRatio: aspectRatio,
      );

      await draftService.saveDraft(draft);

      Log.info(
        '📹 Created draft with ID: ${draft.id}',
        category: LogCategory.video,
      );

      if (mounted) {
        // Navigate to metadata screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoMetadataScreenPure(draftId: draft.id),
          ),
        );
      }

      // Call original callback if exists
      widget.onExport?.call();
    } catch (e) {
      Log.error(
        'Failed to create draft: $e',
        category: LogCategory.video,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleBack() {
    // Stop audio preview when going back
    _audioPlayer?.stop();

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
    final soundServiceAsync = ref.watch(soundLibraryServiceProvider);
    final soundService = soundServiceAsync.value;

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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Use actual rendered size, not native video resolution
                            final renderedSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoPlayer(_videoController!),
                                // Text overlays
                                ...editorState.textOverlays.map((overlay) {
                                  return DraggableTextOverlay(
                                    overlay: overlay,
                                    videoSize: renderedSize,
                                    onPositionChanged: (position) =>
                                        _updateTextOverlayPosition(
                                      overlay.id,
                                      position,
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
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
                    'Sound: ${soundService?.getSoundById(editorState.selectedSoundId!)?.title ?? 'Loading...'}',
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
