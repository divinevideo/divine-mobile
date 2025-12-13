// ABOUTME: Main screen for managing recorded video clips before editing
// ABOUTME: Displays thumbnail grid with reorder, delete, and preview functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/clip_manager/segment_thumbnail.dart';
import 'package:openvine/widgets/clip_manager/segment_preview_modal.dart';

class ClipManagerScreen extends ConsumerStatefulWidget {
  const ClipManagerScreen({
    super.key,
    this.onRecordMore,
    this.onNext,
    this.onDiscard,
  });

  final VoidCallback? onRecordMore;
  final VoidCallback? onNext;
  final VoidCallback? onDiscard;

  @override
  ConsumerState<ClipManagerScreen> createState() => _ClipManagerScreenState();
}

class _ClipManagerScreenState extends ConsumerState<ClipManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clipManagerProvider);
    final notifier = ref.read(clipManagerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onDiscard ?? () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${state.totalDuration.inMilliseconds / 1000}s / 6.3s',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: state.hasClips ? (widget.onNext ?? () {}) : null,
            child: Text(
              'Next',
              style: TextStyle(
                color: state.hasClips ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              Expanded(
                child: state.hasClips
                    ? _buildClipGrid(state, notifier)
                    : _buildEmptyState(),
              ),

              // Record more button
              if (state.canRecordMore) _buildRecordMoreButton(state),

              const SizedBox(height: 16),
            ],
          ),

          // Preview modal
          if (state.previewingClip != null)
            SegmentPreviewModal(
              clip: state.previewingClip!,
              onClose: () => notifier.clearPreview(),
            ),
        ],
      ),
    );
  }

  Widget _buildClipGrid(dynamic state, ClipManagerNotifier notifier) {
    final clips = state.sortedClips as List<RecordingClip>;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ReorderableGridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 9 / 16,
        ),
        itemCount: clips.length,
        itemBuilder: (context, index) {
          final clip = clips[index];
          return ReorderableGridDragStartListener(
            key: ValueKey(clip.id),
            index: index,
            child: SegmentThumbnail(
              clip: clip,
              onTap: () => notifier.setPreviewingClip(clip.id),
              onDelete: () => _confirmDelete(clip, notifier),
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          final clips = state.sortedClips as List<RecordingClip>;
          final ids = clips.map((c) => c.id).toList();
          final item = ids.removeAt(oldIndex);
          if (newIndex > oldIndex) newIndex--;
          ids.insert(newIndex, item);
          notifier.reorderClips(ids);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off,
            color: Colors.grey,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No clips',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: widget.onRecordMore,
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordMoreButton(dynamic state) {
    final remaining = state.remainingDuration as Duration;
    final seconds = remaining.inMilliseconds / 1000;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white30),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: widget.onRecordMore,
          icon: const Icon(Icons.add),
          label: Text('Record (${seconds.toStringAsFixed(1)}s left)'),
        ),
      ),
    );
  }

  void _confirmDelete(RecordingClip clip, ClipManagerNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete clip?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteClip(clip.id);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple ReorderableGridView implementation
class ReorderableGridView extends StatelessWidget {
  const ReorderableGridView.builder({
    super.key,
    required this.gridDelegate,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
  });

  final SliverGridDelegate gridDelegate;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final void Function(int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      onReorder: onReorder,
    );
  }
}

class ReorderableGridDragStartListener extends StatelessWidget {
  const ReorderableGridDragStartListener({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: child,
    );
  }
}
