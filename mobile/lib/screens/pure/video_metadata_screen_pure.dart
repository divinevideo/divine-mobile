// ABOUTME: Pure video metadata screen using revolutionary Riverpod architecture
// ABOUTME: Adds metadata to recorded videos before publishing without VideoManager dependencies

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/services/proofmode_session_service.dart' show ProofManifest;
import 'package:openvine/models/pending_upload.dart' show UploadStatus;
import 'package:openvine/widgets/proofmode_info_panel.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Pure video metadata screen using revolutionary single-controller Riverpod architecture
class VideoMetadataScreenPure extends ConsumerStatefulWidget {
  const VideoMetadataScreenPure({
    super.key,
    required this.videoFile,
    required this.duration,
    this.proofManifest,
  });

  final File videoFile;
  final Duration duration;
  final ProofManifest? proofManifest;

  @override
  ConsumerState<VideoMetadataScreenPure> createState() => _VideoMetadataScreenPureState();
}

class _VideoMetadataScreenPureState extends ConsumerState<VideoMetadataScreenPure> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  final List<String> _hashtags = [];
  bool _isExpiringPost = false;
  int _expirationHours = 24;
  bool _isPublishing = false;
  String _publishingStatus = '';
  double _uploadProgress = 0.0;
  String? _currentUploadId;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();

    // Set default title
    _titleController.text = 'Do it for the Vine!';

    Log.info('📝 VideoMetadataScreenPure: Initialized for file: ${widget.videoFile.path}',
        category: LogCategory.video);

    // Initialize video preview
    _initializeVideoPreview();
  }

  Future<void> _initializeVideoPreview() async {
    try {
      // Verify file exists before attempting to play
      if (!await widget.videoFile.exists()) {
        throw Exception('Video file does not exist: ${widget.videoFile.path}');
      }

      final fileSize = await widget.videoFile.length();
      Log.info('📝 Initializing video preview for file: ${widget.videoFile.path} (${fileSize} bytes)',
          category: LogCategory.video);

      _videoController = VideoPlayerController.file(widget.videoFile);

      // Add timeout to prevent hanging - video player should initialize quickly
      await _videoController!.initialize().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          throw Exception('Video player initialization timed out after 2 seconds');
        },
      );

      await _videoController!.setLooping(true);
      await _videoController!.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }

      Log.info('📝 Video preview initialized successfully',
          category: LogCategory.video);
    } catch (e) {
      Log.error('📝 Failed to initialize video preview: $e',
          category: LogCategory.video);

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
    _hashtagController.dispose();
    _videoController?.dispose();
    super.dispose();

    Log.info('📝 VideoMetadataScreenPure: Disposed',
        category: LogCategory.video);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        leading: IconButton(
          key: const Key('back-button'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Metadata',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _isPublishing ? null : _publishVideo,
            child: _isPublishing
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video preview
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _isVideoInitialized && _videoController != null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                        // Play/pause overlay
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.loop,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(widget.duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: VineTheme.vineGreen),
                          const SizedBox(height: 8),
                          Text(
                            'Loading preview...',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
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
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        errorBorder: OutlineInputBorder(
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
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe your video...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hashtag input
                    const Text(
                      'Add Hashtag',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hashtagController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'hashtag',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              filled: true,
                              fillColor: Colors.grey[900],
                              prefixText: '#',
                              prefixStyle: const TextStyle(color: VineTheme.vineGreen),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: _addHashtag,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _addHashtag(_hashtagController.text),
                          icon: const Icon(Icons.add, color: VineTheme.vineGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Hashtags display
                    if (_hashtags.isNotEmpty) ...[
                      const Text(
                        'Hashtags',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _hashtags.map((hashtag) => Chip(
                          label: Text('#$hashtag'),
                          labelStyle: const TextStyle(color: Colors.white),
                          backgroundColor: VineTheme.vineGreen,
                          deleteIcon: const Icon(Icons.close, color: Colors.white, size: 18),
                          onDeleted: () => _removeHashtag(hashtag),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Expiring post option
                    SwitchListTile(
                      title: const Text(
                        'Expiring Post',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _isExpiringPost ? 'Delete after ${_formatExpirationDuration()}' : 'Post will not expire',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      value: _isExpiringPost,
                      onChanged: (value) {
                        setState(() {
                          _isExpiringPost = value;
                        });
                      },
                      activeThumbColor: VineTheme.vineGreen,
                    ),

                    if (_isExpiringPost) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delete after:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildDurationButton('1 Day', 24),
                                _buildDurationButton('1 Week', 168),
                                _buildDurationButton('1 Month', 720),
                                _buildDurationButton('1 Year', 8760),
                                _buildDurationButton('1 Decade', 87600),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ProofMode info panel
                    if (widget.proofManifest != null) ...[
                      const SizedBox(height: 16),
                      ProofModeInfoPanel(manifest: widget.proofManifest!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
        // Publishing progress overlay
        if (_isPublishing)
          Container(
            color: Colors.black.withValues(alpha: 0.8),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress indicator - show deterministic if we have upload progress
                    _currentUploadId != null && _uploadProgress > 0
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(
                                  value: _uploadProgress,
                                  color: VineTheme.vineGreen,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '${(_uploadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          )
                        : const CircularProgressIndicator(
                            color: VineTheme.vineGreen,
                            strokeWidth: 3,
                          ),
                    const SizedBox(height: 24),
                    Text(
                      _publishingStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _addHashtag(String hashtag) {
    final trimmed = hashtag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_hashtags.contains(trimmed)) {
      setState(() {
        _hashtags.add(trimmed);
        _hashtagController.clear();
      });
    }
  }

  void _removeHashtag(String hashtag) {
    setState(() {
      _hashtags.remove(hashtag);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$twoDigitMinutes:$twoDigitSeconds';
  }

  String _formatExpirationDuration() {
    if (_expirationHours >= 87600) return '${(_expirationHours / 87600).round()} decade${_expirationHours >= 175200 ? 's' : ''}';
    if (_expirationHours >= 8760) return '${(_expirationHours / 8760).round()} year${_expirationHours >= 17520 ? 's' : ''}';
    if (_expirationHours >= 720) return '${(_expirationHours / 720).round()} month${_expirationHours >= 1440 ? 's' : ''}';
    if (_expirationHours >= 168) return '${(_expirationHours / 168).round()} week${_expirationHours >= 336 ? 's' : ''}';
    if (_expirationHours >= 24) return '${(_expirationHours / 24).round()} day${_expirationHours >= 48 ? 's' : ''}';
    return '$_expirationHours hour${_expirationHours != 1 ? 's' : ''}';
  }

  Widget _buildDurationButton(String label, int hours) {
    final isSelected = _expirationHours == hours;
    return GestureDetector(
      onTap: () {
        setState(() {
          _expirationHours = hours;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? VineTheme.vineGreen : Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? VineTheme.vineGreen : Colors.grey[700]!,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _publishVideo() async {
    setState(() {
      _isPublishing = true;
      _publishingStatus = 'Preparing to publish...';
    });

    try {
      Log.info('📝 VideoMetadataScreenPure: Publishing video: ${widget.videoFile.path}',
          category: LogCategory.video);

      // Get current user's pubkey
      final authService = ref.read(authServiceProvider);
      final pubkey = authService.currentPublicKeyHex;

      if (pubkey == null) {
        throw Exception('Not authenticated - cannot publish video');
      }

      // Get upload manager and video event publisher
      final uploadManager = ref.read(uploadManagerProvider);
      final videoEventPublisher = ref.read(videoEventPublisherProvider);

      // Ensure upload manager is initialized
      if (!uploadManager.isInitialized) {
        Log.info('📝 Initializing upload manager...',
            category: LogCategory.video);
        setState(() {
          _publishingStatus = 'Initializing upload system...';
        });
        await uploadManager.initialize();
      }

      // Start upload to Blossom
      Log.info('📝 Starting upload to Blossom server...',
          category: LogCategory.video);

      setState(() {
        _publishingStatus = 'Uploading video...';
      });

      final pendingUpload = await uploadManager.startUpload(
        videoFile: widget.videoFile,
        nostrPubkey: pubkey,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        hashtags: _hashtags.isEmpty ? null : _hashtags,
        videoDuration: widget.duration,
        proofManifest: widget.proofManifest,
      );

      Log.info('📝 Upload started, ID: ${pendingUpload.id}',
          category: LogCategory.video);

      // Track upload progress
      setState(() {
        _currentUploadId = pendingUpload.id;
      });

      // Poll for upload progress
      while (mounted && _currentUploadId != null) {
        final upload = uploadManager.getUpload(_currentUploadId!);
        if (upload == null) break;

        final progress = upload.uploadProgress ?? 0.0;
        if (mounted) {
          setState(() {
            _uploadProgress = progress;
            if (progress < 1.0) {
              _publishingStatus = 'Uploading video... ${(progress * 100).toInt()}%';
            }
          });
        }

        // If upload is complete or failed, stop polling
        if (upload.status == UploadStatus.readyToPublish ||
            upload.status == UploadStatus.failed ||
            upload.status == UploadStatus.processing) {
          break;
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Publish Nostr event
      Log.info('📝 Publishing Nostr event...',
          category: LogCategory.video);

      setState(() {
        _publishingStatus = 'Publishing to Nostr...';
      });

      final published = await videoEventPublisher.publishDirectUpload(
        pendingUpload,
        expirationTimestamp: _isExpiringPost
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000 + (_expirationHours * 3600)
            : null,
      );

      if (!published) {
        throw Exception('Failed to publish Nostr event');
      }

      Log.info('📝 Video publishing complete, returning to camera screen',
          category: LogCategory.video);

      // Mark recording as published to prevent auto-save on dispose
      ref.read(vineRecordingProvider.notifier).markAsPublished();

      if (mounted) {
        setState(() {
          _publishingStatus = 'Published successfully!';
        });

        // Show success message for longer so user can see it
        await Future.delayed(const Duration(milliseconds: 1200));

        if (mounted) {
          // Reset publishing state
          setState(() {
            _isPublishing = false;
            _publishingStatus = '';
            _uploadProgress = 0.0;
            _currentUploadId = null;
          });

          // Pop back to the root (main navigation screen)
          // This pops both metadata screen AND camera screen
          Navigator.of(context).popUntil((route) => route.isFirst);

          Log.info('📝 Published successfully, returned to main screen', category: LogCategory.video);
        }
      }
    } catch (e, stackTrace) {
      Log.error('📝 VideoMetadataScreenPure: Failed to publish video: $e',
          category: LogCategory.video);

      if (mounted) {
        setState(() {
          _isPublishing = false;
          _publishingStatus = '';
          _uploadProgress = 0.0;
          _currentUploadId = null;
        });

        // Get the current Blossom server for error message
        final blossomService = ref.read(blossomUploadServiceProvider);
        String serverName = 'Unknown server';
        try {
          final serverUrl = await blossomService.getBlossomServer();
          if (serverUrl != null && serverUrl.isNotEmpty) {
            // Extract domain from URL for display
            final uri = Uri.tryParse(serverUrl);
            serverName = uri?.host ?? serverUrl;
          }
        } catch (_) {
          // If we can't get the server name, just use the generic message
        }

        // Convert technical error to user-friendly message
        String userMessage;
        if (e.toString().contains('404') || e.toString().contains('not_found')) {
          userMessage = 'The Blossom media server ($serverName) is not working. You can choose another in your settings.';
        } else if (e.toString().contains('500')) {
          userMessage = 'The Blossom media server ($serverName) encountered an error. You can choose another in your settings.';
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          userMessage = 'Network error. Please check your connection and try again.';
        } else if (e.toString().contains('Not authenticated')) {
          userMessage = 'Please sign in to publish videos.';
        } else {
          userMessage = 'Failed to publish video. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                // Show technical details in a dialog
                final errorDetails = '''
Error: ${e.toString()}

Stack Trace:
${stackTrace.toString()}

Operation: Video Upload
Time: ${DateTime.now().toIso8601String()}
Video: ${widget.videoFile.path}
''';

                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: Row(
                      children: [
                        const Icon(Icons.bug_report, color: Colors.red),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Error Details',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Please share these details with support:',
                            style: TextStyle(
                              color: VineTheme.vineGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[700]!),
                            ),
                            child: SelectableText(
                              errorDetails,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: errorDetails));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error details copied to clipboard'),
                                backgroundColor: VineTheme.vineGreen,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, color: VineTheme.vineGreen),
                        label: const Text('Copy', style: TextStyle(color: VineTheme.vineGreen)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }
}