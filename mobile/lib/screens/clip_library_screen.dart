// ABOUTME: Screen for browsing and managing saved video clips
// ABOUTME: Shows grid of clip thumbnails with preview, delete, and import options

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:video_player/video_player.dart';

class ClipLibraryScreen extends ConsumerStatefulWidget {
  const ClipLibraryScreen({
    super.key,
    this.selectionMode = false,
    this.onClipSelected,
  });

  /// When true, tapping a clip calls onClipSelected instead of previewing
  final bool selectionMode;

  /// Called when a clip is selected in selection mode
  final void Function(SavedClip clip)? onClipSelected;

  @override
  ConsumerState<ClipLibraryScreen> createState() => _ClipLibraryScreenState();
}

class _ClipLibraryScreenState extends ConsumerState<ClipLibraryScreen> {
  List<SavedClip> _clips = [];
  bool _isLoading = true;
  String? _selectedClipId;

  @override
  void initState() {
    super.initState();
    _loadClips();
  }

  Future<void> _loadClips() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final clipService = await ref.read(clipLibraryServiceProvider.future);
      final clips = await clipService.getAllClips();

      if (mounted) {
        setState(() {
          _clips = clips;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: VineTheme.vineGreen,
          foregroundColor: VineTheme.whiteText,
          title: Text(widget.selectionMode ? 'Select Clip' : 'Clips'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
            onPressed: () {
              if (widget.selectionMode) {
                Navigator.of(context).pop();
              } else {
                final authService = ref.read(authServiceProvider);
                final npub = authService.currentNpub;
                if (npub != null) {
                  context.go('/profile/$npub');
                } else {
                  context.go('/home/0');
                }
              }
            },
          ),
          actions: [
            if (_clips.isNotEmpty && !widget.selectionMode)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: VineTheme.whiteText),
                onSelected: (value) {
                  if (value == 'clear_all') {
                    _showClearAllConfirmation();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Clear All Clips'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              )
            : _clips.isEmpty
                ? _buildEmptyState()
                : _buildClipsGrid(),
      );

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
                border: Border.all(color: Colors.grey[600]!, width: 2),
              ),
              child: const Icon(
                Icons.video_library_outlined,
                size: 60,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Clips Yet',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your recorded video clips will appear here',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                context.pushCamera();
              },
              icon: const Icon(Icons.videocam),
              label: const Text('Record a Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.whiteText,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildClipsGrid() => GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1.0,
        ),
        itemCount: _clips.length,
        itemBuilder: (context, index) {
          final clip = _clips[index];
          return ClipThumbnailCard(
            clip: clip,
            isSelected: _selectedClipId == clip.id,
            onTap: () => _handleClipTap(clip),
            onLongPress: () => _showClipOptions(clip),
          );
        },
      );

  void _handleClipTap(SavedClip clip) {
    if (widget.selectionMode) {
      widget.onClipSelected?.call(clip);
      Navigator.of(context).pop();
    } else {
      _showClipPreview(clip);
    }
  }

  void _showClipPreview(SavedClip clip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipPreviewSheet(
        clip: clip,
        onDelete: () {
          Navigator.of(context).pop();
          _deleteClip(clip);
        },
      ),
    );
  }

  void _showClipOptions(SavedClip clip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle, color: VineTheme.vineGreen),
              title: const Text(
                'Preview',
                style: TextStyle(color: VineTheme.whiteText),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showClipPreview(clip);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _confirmDeleteClip(clip);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteClip(SavedClip clip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Clip?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'This will permanently delete this ${clip.durationInSeconds.toStringAsFixed(1)}s clip.',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteClip(clip);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClip(SavedClip clip) async {
    try {
      final clipService = await ref.read(clipLibraryServiceProvider.future);
      await clipService.deleteClip(clip.id);

      // Delete video file
      final videoFile = File(clip.filePath);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }

      // Delete thumbnail if exists
      if (clip.thumbnailPath != null) {
        final thumbFile = File(clip.thumbnailPath!);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }

      setState(() {
        _clips.removeWhere((c) => c.id == clip.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clip deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete clip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClearAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Clear All Clips?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'This will permanently delete all ${_clips.length} clip(s). This action cannot be undone.',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllClips();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllClips() async {
    try {
      final clipService = await ref.read(clipLibraryServiceProvider.future);

      // Delete all video and thumbnail files
      for (final clip in _clips) {
        try {
          final videoFile = File(clip.filePath);
          if (await videoFile.exists()) {
            await videoFile.delete();
          }
          if (clip.thumbnailPath != null) {
            final thumbFile = File(clip.thumbnailPath!);
            if (await thumbFile.exists()) {
              await thumbFile.delete();
            }
          }
        } catch (_) {
          // Continue even if individual file deletion fails
        }
      }

      await clipService.clearAllClips();

      setState(() {
        _clips.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All clips cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear clips: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Thumbnail card for a single clip in the grid
class ClipThumbnailCard extends StatelessWidget {
  const ClipThumbnailCard({
    super.key,
    required this.clip,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
  });

  final SavedClip clip;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? VineTheme.vineGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail or placeholder
              if (clip.thumbnailPath != null && File(clip.thumbnailPath!).existsSync())
                Image.file(
                  File(clip.thumbnailPath!),
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.videocam,
                    color: Colors.grey,
                    size: 32,
                  ),
                ),
              // Duration badge
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${clip.durationInSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Aspect ratio indicator
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    clip.aspectRatio == 'vertical' ? Icons.crop_portrait : Icons.crop_square,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview sheet for playing a clip
class ClipPreviewSheet extends StatefulWidget {
  const ClipPreviewSheet({
    super.key,
    required this.clip,
    required this.onDelete,
  });

  final SavedClip clip;
  final VoidCallback onDelete;

  @override
  State<ClipPreviewSheet> createState() => _ClipPreviewSheetState();
}

class _ClipPreviewSheetState extends State<ClipPreviewSheet> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final file = File(widget.clip.filePath);
    if (!await file.exists()) {
      return;
    }

    _controller = VideoPlayerController.file(file);
    await _controller!.initialize();
    await _controller!.setLooping(true);
    await _controller!.play();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Video preview
          Expanded(
            child: _isInitialized && _controller != null
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: VineTheme.vineGreen),
                  ),
          ),
          // Info and actions
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.clip.durationInSeconds.toStringAsFixed(1)}s clip',
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.clip.displayDuration,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
