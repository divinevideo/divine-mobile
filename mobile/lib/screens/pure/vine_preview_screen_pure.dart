// ABOUTME: Pure vine preview screen using revolutionary Riverpod architecture
// ABOUTME: Reviews recorded videos before publishing without VideoManager dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

/// Pure vine preview screen using revolutionary single-controller Riverpod architecture
class VinePreviewScreenPure extends ConsumerStatefulWidget {
  const VinePreviewScreenPure({super.key, required this.draftId});

  final String draftId;

  @override
  ConsumerState<VinePreviewScreenPure> createState() =>
      _VinePreviewScreenPureState();
}

class _VinePreviewScreenPureState extends ConsumerState<VinePreviewScreenPure> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hashtagsController = TextEditingController();
  bool _isUploading = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  VineDraft? _currentDraft;
  // bool _isExpiringPost = false; // Unused - commenting out
  // int _expirationHours = 24; // Unused - commenting out

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);
      final drafts = await draftService.getAllDrafts();

      final draft = drafts.firstWhere(
        (d) => d.id == widget.draftId,
        orElse: () {
          Log.error(
            '🎬 Draft not found: ${widget.draftId}',
            category: LogCategory.video,
          );
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Draft not found'),
                backgroundColor: Colors.red,
              ),
            );
          }
          throw StateError('Draft ${widget.draftId} not found');
        },
      );

      if (mounted) {
        setState(() {
          _currentDraft = draft;
        });

        // Populate form with draft data
        _titleController.text = draft.title;
        _descriptionController.text = draft.description;
        _hashtagsController.text = draft.hashtags.join(' ');

        Log.info(
          '🎬 VinePreviewScreenPure: Loaded draft ${draft.id}',
          category: LogCategory.video,
        );

        // Initialize video preview
        _initializeVideoPreview();
      }
    } catch (e) {
      Log.error('🎬 Failed to load draft: $e', category: LogCategory.video);
    }
  }

  Future<void> _initializeVideoPreview() async {
    if (_currentDraft == null) return;

    try {
      // Verify file exists before attempting to play
      if (!await _currentDraft!.videoFile.exists()) {
        throw Exception(
          'Video file does not exist: ${_currentDraft!.videoFile.path}',
        );
      }

      final fileSize = await _currentDraft!.videoFile.length();
      Log.info(
        '🎬 Initializing video preview for file: ${_currentDraft!.videoFile.path} (${fileSize} bytes)',
        category: LogCategory.video,
      );

      _videoController = VideoPlayerController.file(_currentDraft!.videoFile);

      await _videoController!.initialize().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          throw Exception(
            'Video player initialization timed out after 2 seconds',
          );
        },
      );

      await _videoController!.setLooping(true);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }

      // Start playing after UI has rendered
      // Use addPostFrameCallback to ensure play() happens after frame is drawn
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_videoController != null && mounted) {
          await _videoController!.play();
          Log.info(
            '🎬 Video started playing (isPlaying: ${_videoController!.value.isPlaying})',
            category: LogCategory.video,
          );
        }
      });

      Log.info(
        '🎬 Video preview initialized successfully',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '🎬 Failed to initialize video preview: $e',
        category: LogCategory.video,
      );

      // Still allow the screen to be usable even if preview fails
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hashtagsController.dispose();
    _videoController?.dispose();
    super.dispose();

    Log.info('🎬 VinePreviewScreenPure: Disposed', category: LogCategory.video);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: IconButton(
          key: const Key('back-button'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Preview Video',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _saveDraft,
            child: const Text(
              'Save Draft',
              style: TextStyle(color: Colors.white),
            ),
          ),
          if (_currentDraft?.canRetry ?? false)
            // Show Retry button for failed drafts
            TextButton(
              key: const Key('retry-button'),
              onPressed: _isUploading ? null : _publishVideo,
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            )
          else
            // Show Publish button for draft status
            TextButton(
              onPressed:
                  (_isUploading || (_currentDraft?.isPublishing ?? false))
                  ? null
                  : _publishVideo,
              child: (_isUploading || (_currentDraft?.isPublishing ?? false))
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Publish',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Error banner for failed publishes
          if (_currentDraft?.publishStatus == PublishStatus.failed &&
              _currentDraft?.publishError != null)
            Container(
              width: double.infinity,
              color: Colors.red[900],
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentDraft!.publishError!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Text(
                    'Attempt ${_currentDraft!.publishAttempts}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Video preview section
          Expanded(
            flex: 3,
            child: Container(
              key: const Key('video-preview'),
              color: Colors.black,
              child: Center(
                child: _isVideoInitialized && _videoController != null
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : AspectRatio(
                        aspectRatio: 9 / 16, // Vertical video aspect ratio
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!_isVideoInitialized &&
                                    _videoController != null)
                                  const CircularProgressIndicator(
                                    color: Colors.white54,
                                  )
                                else
                                  const Icon(
                                    Icons.play_circle_filled,
                                    size: 64,
                                    color: Colors.white54,
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  _videoController != null
                                      ? 'Loading...'
                                      : 'Video Preview',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // Metadata input section
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title input
                    const Text(
                      'Title',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter video title...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description input
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe your video...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hashtags input
                    const Text(
                      'Hashtags',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _hashtagsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add hashtags...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_currentDraft == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      // Parse hashtags from space-separated string
      final hashtagText = _hashtagsController.text.trim();
      final hashtags = hashtagText.isEmpty
          ? <String>[]
          : hashtagText.split(' ').where((tag) => tag.isNotEmpty).toList();

      // Update existing draft instead of creating new one
      final updated = _currentDraft!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        hashtags: hashtags,
      );

      await draftService.saveDraft(updated);

      setState(() {
        _currentDraft = updated;
      });

      Log.info(
        '🎬 VinePreviewScreenPure: Updated draft ${updated.id}',
        category: LogCategory.video,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Log.error(
        '🎬 VinePreviewScreenPure: Failed to save draft: $e',
        category: LogCategory.video,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save draft: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _publishVideo() async {
    if (_currentDraft == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // Update draft status to "publishing"
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      final publishing = _currentDraft!.copyWith(
        publishStatus: PublishStatus.publishing,
      );
      await draftService.saveDraft(publishing);
      setState(() {
        _currentDraft = publishing;
      });

      Log.info(
        '🎬 VinePreviewScreenPure: Publishing video: ${_currentDraft!.videoFile.path}',
        category: LogCategory.video,
      );

      // TODO: Implement actual video upload service
      // For now, simulate success
      await Future.delayed(const Duration(milliseconds: 100));

      // Success: delete draft
      await draftService.deleteDraft(_currentDraft!.id);

      if (mounted) {
        // Navigate back to main feed after successful upload
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      Log.error(
        '🎬 VinePreviewScreenPure: Failed to publish video: $e',
        category: LogCategory.video,
      );

      // Failed: update draft with error
      try {
        final prefs = await SharedPreferences.getInstance();
        final draftService = DraftStorageService(prefs);

        final failed = _currentDraft!.copyWith(
          publishStatus: PublishStatus.failed,
          publishError: e.toString(),
          publishAttempts: _currentDraft!.publishAttempts + 1,
        );
        await draftService.saveDraft(failed);

        if (mounted) {
          setState(() {
            _currentDraft = failed;
            _isUploading = false;
          });
        }
      } catch (saveError) {
        Log.error(
          '🎬 VinePreviewScreenPure: Failed to save error state: $saveError',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }
}
