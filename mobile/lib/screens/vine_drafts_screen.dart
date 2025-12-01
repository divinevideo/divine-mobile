// ABOUTME: Screen for managing saved Vine drafts before publishing
// ABOUTME: Shows list of saved drafts with preview, edit, and delete options

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/pure/vine_preview_screen_pure.dart';
import 'package:openvine/theme/vine_theme.dart';

class VineDraftsScreen extends ConsumerStatefulWidget {
  const VineDraftsScreen({super.key});

  @override
  ConsumerState<VineDraftsScreen> createState() => _VineDraftsScreenState();
}

class _VineDraftsScreenState extends ConsumerState<VineDraftsScreen> {
  List<VineDraft> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final draftService = await ref.read(draftStorageServiceProvider.future);
      final drafts = await draftService.getAllDrafts();

      if (mounted) {
        setState(() {
          _drafts = drafts;
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
      title: const Text('Drafts'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
        onPressed: () {
          // Navigate back to user's profile
          final authService = ref.read(authServiceProvider);
          final npub = authService.currentNpub;
          if (npub != null) {
            context.go('/profile/$npub');
          } else {
            // Fallback to home if no user logged in
            context.go('/home/0');
          }
        },
      ),
      actions: [
        if (_drafts.isNotEmpty)
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
                    Text('Clear All Drafts'),
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
        : _drafts.isEmpty
        ? _buildEmptyState()
        : _buildDraftsList(),
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
          'No Drafts Yet',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your saved video drafts will appear here',
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            // Wait for navigation animation to complete before allowing camera FAB to push
            // This prevents navigation timing race condition that causes black screens
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          },
          icon: const Icon(Icons.videocam),
          label: const Text('Record a Video'),
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: VineTheme.whiteText,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildDraftsList() => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: _drafts.length,
    itemBuilder: (context, index) {
      final draft = _drafts[index];
      return _buildDraftCard(draft);
    },
  );

  Widget _buildDraftCard(VineDraft draft) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[700]!, width: 1),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _editDraft(draft),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Video thumbnail
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.play_circle_filled,
                color: VineTheme.vineGreen,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),

            // Draft info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.hasTitle ? draft.title : 'Untitled Vine',
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${draft.frameCount} frames • ${draft.selectedApproach}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    draft.displayDuration,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),

            // Action menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _editDraft(draft);
                  case 'delete':
                    _deleteDraft(draft);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _editDraft(VineDraft draft) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VinePreviewScreenPure(draftId: draft.id),
      ),
    );
  }

  void _deleteDraft(VineDraft draft) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Draft?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'This will permanently delete "${draft.hasTitle ? draft.title : 'Untitled Vine'}" from your drafts.',
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
              _confirmDeleteDraft(draft);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteDraft(VineDraft draft) async {
    try {
      final draftService = await ref.read(draftStorageServiceProvider.future);
      await draftService.deleteDraft(draft.id);

      setState(() {
        _drafts.remove(draft);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete draft: $e'),
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
          'Clear All Drafts?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'This will permanently delete all ${_drafts.length} draft(s). This action cannot be undone.',
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
              _clearAllDrafts();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllDrafts() async {
    try {
      final draftService = await ref.read(draftStorageServiceProvider.future);
      await draftService.clearAllDrafts();

      setState(() {
        _drafts.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All drafts cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear drafts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
