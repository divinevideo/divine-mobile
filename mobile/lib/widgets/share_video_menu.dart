// ABOUTME: Comprehensive share menu for videos with content reporting, user sharing, and list management
// ABOUTME: Provides Apple-compliant reporting, NIP-51 list management, and social sharing features

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:share_plus/share_plus.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

// TODO(any): Move this to a reusable widget
Widget get _buildLoadingIndicator => Padding(
  padding: const EdgeInsets.all(12),
  child: Center(
    child: const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: VineTheme.secondaryText,
      ),
    ),
  ),
);

/// Comprehensive share menu for videos
class ShareVideoMenu extends ConsumerStatefulWidget {
  const ShareVideoMenu({required this.video, super.key, this.onDismiss});
  final VideoEvent video;
  final VoidCallback? onDismiss;

  @override
  ConsumerState<ShareVideoMenu> createState() => _ShareVideoMenuState();
}

class _ShareVideoMenuState extends ConsumerState<ShareVideoMenu> {
  @override
  Widget build(BuildContext context) => Material(
    color: VineTheme.backgroundColor,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),

          // Share options
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildVideoStatusSection(),
                  if (!_isUserOwnContent() &&
                      !widget.video.isOriginalContent) ...[
                    const SizedBox(height: 16),
                    _buildQuickAIReportButton(),
                  ],
                  const SizedBox(height: 24),
                  _buildShareSection(),
                  const SizedBox(height: 24),
                  _buildListSection(),
                  const SizedBox(height: 24),
                  _buildPublicListsSection(),
                  const SizedBox(height: 24),
                  _buildBookmarkSection(),
                  const SizedBox(height: 24),
                  _buildFollowSetSection(),
                  if (_isUserOwnContent()) ...[
                    const SizedBox(height: 24),
                    _buildDeleteSection(),
                  ],
                  const SizedBox(height: 24),
                  _buildReportSection(),
                  const SizedBox(height: 24),
                  _buildAdvancedSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey.shade800, width: 1)),
    ),
    child: Row(
      children: [
        const Icon(Icons.share, color: VineTheme.whiteText),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Video',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.video.title != null)
                Text(
                  widget.video.title!,
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close, color: VineTheme.secondaryText),
        ),
      ],
    ),
  );

  /// Build quick AI report button for one-tap reporting
  Widget _buildQuickAIReportButton() => Container(
    decoration: BoxDecoration(
      color: Colors.orange.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
    ),
    child: ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.psychology_alt, color: Colors.orange, size: 20),
      ),
      title: Text(
        'Report AI Content',
        style: TextStyle(
          color: VineTheme.whiteText,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Quick report suspected AI-generated content',
        style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.orange, size: 16),
      onTap: _quickReportAI,
    ),
  );

  /// Quick report for AI-generated content (kind 1984 event)
  Future<void> _quickReportAI() async {
    try {
      // Show loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Reporting AI content...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final reportService = await ref.read(
        contentReportingServiceProvider.future,
      );
      final result = await reportService.reportContent(
        eventId: widget.video.id,
        authorPubkey: widget.video.pubkey,
        reason: ContentFilterReason.aiGenerated,
        details: 'Suspected AI-generated content',
      );

      if (mounted) {
        context.pop(); // Close share menu

        if (result.success) {
          // Show success confirmation dialog using root navigator
          showDialog(
            context: context,
            useRootNavigator: true,
            builder: (context) => const _ReportConfirmationDialog(),
          );
        } else {
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Failed to report content: ${result.error}'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to submit AI report: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report AI content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build video status section showing what lists the video is in
  Widget _buildVideoStatusSection() => Consumer(
    builder: (context, ref, child) {
      final curatedListServiceAsync = ref.watch(curatedListsStateProvider);
      final curatedListService = ref
          .read(curatedListsStateProvider.notifier)
          .service;
      final bookmarkServiceAsync = ref.watch(bookmarkServiceProvider);

      return curatedListServiceAsync.when(
        data: (lists) {
          return bookmarkServiceAsync.when(
            data: (bookmarkService) {
              final listsContaining =
                  curatedListService?.getListsContainingVideo(
                    widget.video.id,
                  ) ??
                  [];
              final bookmarkStatus = bookmarkService.getVideoBookmarkSummary(
                widget.video.id,
              );

              final statusParts = <String>[];

              // Add curated lists status
              if (listsContaining.isNotEmpty) {
                if (listsContaining.length == 1) {
                  statusParts.add('In "${listsContaining.first.name}"');
                } else if (listsContaining.length <= 3) {
                  final names = listsContaining
                      .map((list) => '"${list.name}"')
                      .join(', ');
                  statusParts.add('In $names');
                } else {
                  statusParts.add('In ${listsContaining.length} lists');
                }
              }

              // Add bookmark status
              if (bookmarkStatus != 'Not bookmarked') {
                statusParts.add(bookmarkStatus);
              }

              if (statusParts.isEmpty) {
                return const SizedBox.shrink(); // Hide if no status to show
              }

              return Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: VineTheme.vineGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Video Status',
                          style: TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...statusParts.map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const SizedBox(width: 26), // Align with icon
                            Expanded(
                              child: Text(
                                '• $status',
                                style: const TextStyle(
                                  color: VineTheme.lightText,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (listsContaining.length > 3) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showAllListsDialog(listsContaining),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Text(
                            'View all lists →',
                            style: TextStyle(
                              color: VineTheme.vineGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => _buildLoadingIndicator,
            error: (_, __) => const SizedBox.shrink(),
          );
        },
        loading: () => _buildLoadingIndicator,
        error: (_, __) => const SizedBox.shrink(),
      );
    },
  );

  Widget _buildShareSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Share With',
        style: TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),

      // Send to user
      _buildActionTile(
        icon: Icons.person_add,
        title: 'Send to Viner',
        subtitle: 'Share privately with another user',
        onTap: _showSendToUserDialog,
      ),

      const SizedBox(height: 8),

      // External share (native share sheet includes copy option)
      _buildActionTile(
        icon: Icons.share,
        title: 'Share',
        subtitle: 'Share via other apps or copy link',
        onTap: _shareExternally,
      ),
    ],
  );

  Widget _buildListSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Lists',
        style: TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),

      // Dynamic part: show which lists contain this video (loaded async)
      Consumer(
        builder: (context, ref, child) {
          final listServiceAsync = ref.watch(curatedListsStateProvider);
          final listService = ref
              .read(curatedListsStateProvider.notifier)
              .service;

          return listServiceAsync.when(
            data: (lists) {
              final listsContainingVideo =
                  listService?.getListsContainingVideo(widget.video.id) ?? [];

              if (listsContainingVideo.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VineTheme.vineGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: VineTheme.vineGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.playlist_add_check,
                            color: VineTheme.vineGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'In ${listsContainingVideo.length} list${listsContainingVideo.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: VineTheme.vineGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...listsContainingVideo.map(
                        (list) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: InkWell(
                            onTap: () => _removeFromList(list.id),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.folder,
                                    color: VineTheme.secondaryText,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      list.name,
                                      style: const TextStyle(
                                        color: VineTheme.whiteText,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.remove_circle_outline,
                                    color: VineTheme.secondaryText,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => _buildLoadingIndicator,
            error: (_, __) => const SizedBox.shrink(),
          );
        },
      ),

      // Static buttons - always visible immediately
      _buildActionTile(
        icon: Icons.playlist_add,
        title: 'Add to List',
        subtitle: 'Add to your curated lists',
        onTap: _showSelectListDialog,
      ),

      const SizedBox(height: 8),

      _buildActionTile(
        icon: Icons.create_new_folder,
        title: 'Create New List',
        subtitle: 'Start a new curated collection',
        onTap: _showCreateListDialog,
      ),
    ],
  );

  /// Remove video from a specific list
  Future<void> _removeFromList(String listId) async {
    try {
      final listService = await ref
          .read(curatedListsStateProvider.notifier)
          .service;
      await listService?.removeVideoFromList(listId, widget.video.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from list'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to remove from list: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove from list'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Build public lists section showing other users' lists containing this video
  Widget _buildPublicListsSection() =>
      _PublicListsSection(videoId: widget.video.id);

  /// Build bookmark section for quick bookmarking
  Widget _buildBookmarkSection() => Consumer(
    builder: (context, ref, child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bookmarks',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Add to global bookmarks
          _buildActionTile(
            icon: Icons.bookmark_outline,
            title: 'Add to Bookmarks',
            subtitle: 'Save for later viewing',
            onTap: _addToGlobalBookmarks,
          ),

          const SizedBox(height: 8),

          // Add to bookmark set
          _buildActionTile(
            icon: Icons.bookmark_add,
            title: 'Add to Bookmark Set',
            subtitle: 'Organize in collections',
            onTap: _showBookmarkSetsDialog,
          ),
        ],
      );
    },
  );

  /// Build follow set section for adding authors to follow sets
  Widget _buildFollowSetSection() => Consumer(
    builder: (context, ref, child) {
      final socialService = ref.watch(socialServiceProvider);
      final followSets = socialService.followSets;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follow Sets',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Create new follow set with this author
          _buildActionTile(
            icon: Icons.group_add,
            title: 'Create Follow Set',
            subtitle: 'Start new collection with this creator',
            onTap: _showCreateFollowSetDialog,
          ),

          // Show existing follow sets if any
          if (followSets.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildActionTile(
              icon: Icons.people,
              title: 'Add to Follow Set',
              subtitle: '${followSets.length} follow sets available',
              onTap: _showSelectFollowSetDialog,
            ),
          ],
        ],
      );
    },
  );

  Widget _buildReportSection() => Consumer(
    builder: (context, ref, child) {
      final reportServiceAsync = ref.watch(contentReportingServiceProvider);

      return reportServiceAsync.when(
        data: (reportService) {
          final hasReported = reportService.hasBeenReported(widget.video.id);

          // Wrap in orange warning container
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(26), // 0.1 opacity
              border: Border.all(
                color: Colors.orange.withAlpha(77), // 0.3 opacity
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safety Actions',
                  style: TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: hasReported ? Icons.flag : Icons.flag_outlined,
                  title: hasReported ? 'Already Reported' : 'Report Content',
                  subtitle: hasReported
                      ? 'You have reported this content'
                      : 'Report for policy violations',
                  iconColor: hasReported ? Colors.red : Colors.orange,
                  onTap: hasReported ? null : _showReportDialog,
                ),
                // Add Block User action (only for other users' content)
                if (!_isUserOwnContent()) ...[
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final blocklistService = ref.watch(
                        contentBlocklistServiceProvider,
                      );
                      final isBlocked = blocklistService.isBlocked(
                        widget.video.pubkey,
                      );
                      return _buildActionTile(
                        icon: isBlocked ? Icons.block : Icons.block_outlined,
                        title: isBlocked
                            ? 'Unblock User'
                            : 'Block @${widget.video.pubkey.substring(0, 8)}',
                        subtitle: isBlocked
                            ? 'Show content from this user'
                            : 'Hide content from this user',
                        iconColor: Colors.orange,
                        onTap: () => _handleBlockUser(ref, isBlocked),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => _buildLoadingIndicator,
        error: (_, __) => const SizedBox.shrink(),
      );
    },
  );

  /// Build advanced section for developer/power-user features
  Widget _buildAdvancedSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Advanced',
        style: TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),

      // View Source
      _buildActionTile(
        icon: Icons.code,
        title: 'View Source',
        subtitle: 'View raw Nostr event JSON',
        onTap: _showViewSourceDialog,
      ),

      const SizedBox(height: 8),

      // Get Event ID
      _buildActionTile(
        icon: Icons.fingerprint,
        title: 'Copy Event ID',
        subtitle: 'Copy Nostr event ID to clipboard',
        onTap: _copyEventId,
      ),
    ],
  );

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? iconColor,
  }) => ListTile(
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor ?? VineTheme.whiteText, size: 20),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: VineTheme.whiteText,
        fontWeight: FontWeight.w500,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: VineTheme.secondaryText, fontSize: 12),
    ),
    onTap: onTap,
    enabled: onTap != null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  );

  // === BOOKMARK ACTIONS ===

  Future<void> _addToGlobalBookmarks() async {
    try {
      final bookmarkService = await ref.read(bookmarkServiceProvider.future);
      final success = await bookmarkService.addVideoToGlobalBookmarks(
        widget.video.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Added to bookmarks!' : 'Failed to add bookmark',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      Log.error(
        'Failed to add bookmark: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add bookmark'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showBookmarkSetsDialog() {
    showDialog(
      context: context,
      builder: (context) => _SelectBookmarkSetDialog(video: widget.video),
    );
  }

  // === FOLLOW SET ACTIONS ===

  void _showCreateFollowSetDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          _CreateFollowSetDialog(authorPubkey: widget.video.pubkey),
    );
  }

  void _showSelectFollowSetDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          _SelectFollowSetDialog(authorPubkey: widget.video.pubkey),
    );
  }

  void _showSendToUserDialog() {
    showDialog(
      context: context,
      builder: (context) => _SendToUserDialog(video: widget.video),
    );
  }

  Future<void> _shareExternally() async {
    try {
      final sharingService = ref.read(videoSharingServiceProvider);
      final shareText = sharingService.generateShareText(widget.video);

      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (e) {
      Log.error(
        'Failed to share externally: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }

  /// Show dialog with raw Nostr event JSON
  void _showViewSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => _ViewSourceDialog(video: widget.video),
    );
  }

  /// Copy event ID to clipboard
  Future<void> _copyEventId() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.video.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event ID copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      Log.error(
        'Failed to copy event ID: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }

  Future<void> _showCreateListDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CreateListDialog(video: widget.video),
    );

    // If list was created successfully, handle closing share menu and showing snackbar
    if (result != null && mounted) {
      context.pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created list "$result" and added video')),
      );
    }
  }

  void _showSelectListDialog() {
    showDialog(
      context: context,
      builder: (context) => _SelectListDialog(video: widget.video),
    );
  }

  void _handleBlockUser(WidgetRef ref, bool currentlyBlocked) {
    final blocklistService = ref.read(contentBlocklistServiceProvider);

    if (currentlyBlocked) {
      // Unblock without confirmation
      blocklistService.unblockUser(widget.video.pubkey);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User unblocked')));
      }
    } else {
      // Block with confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          title: const Text(
            'Block User?',
            style: TextStyle(color: VineTheme.whiteText),
          ),
          content: const Text(
            'You won\'t see their content in feeds. They won\'t be notified.',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                blocklistService.blockUser(widget.video.pubkey);
                context.pop();
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('User blocked')));
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Block'),
            ),
          ],
        ),
      );
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          ReportContentDialog(video: widget.video, isFromShareMenu: true),
    );
  }

  /// Check if this is the user's own content
  bool _isUserOwnContent() {
    try {
      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) return false;

      final userPubkey = authService.currentPublicKeyHex;
      if (userPubkey == null) return false;

      return widget.video.pubkey == userPubkey;
    } catch (e) {
      Log.error(
        'Error checking content ownership: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
      return false;
    }
  }

  /// Build delete section for user's own content
  Widget _buildDeleteSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Manage Content',
        style: TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),

      // Edit content option
      _buildActionTile(
        icon: Icons.edit,
        iconColor: VineTheme.vineGreen,
        title: 'Edit Video',
        subtitle: 'Update title, description, and hashtags',
        onTap: _showEditDialog,
      ),

      const SizedBox(height: 8),

      // Delete content option
      _buildActionTile(
        icon: Icons.delete_outline,
        iconColor: Colors.red,
        title: 'Delete Video',
        subtitle: 'Permanently remove this content',
        onTap: _showDeleteDialog,
      ),
    ],
  );

  /// Show edit dialog
  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => _EditVideoDialog(video: widget.video),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => _buildDeleteDialog(dialogContext),
    );
  }

  void _showAllListsDialog(List<CuratedList> lists) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.backgroundColor,
        title: const Text(
          'Video is in these lists:',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return ListTile(
                leading: Icon(
                  list.isPublic ? Icons.public : Icons.lock,
                  color: VineTheme.vineGreen,
                  size: 20,
                ),
                title: Text(
                  list.name,
                  style: const TextStyle(color: VineTheme.whiteText),
                ),
                subtitle: list.description != null
                    ? Text(
                        list.description!,
                        style: const TextStyle(color: VineTheme.lightText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: Text(
                  '${list.videoEventIds.length} videos',
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text('Close', style: TextStyle(color: VineTheme.vineGreen)),
          ),
        ],
      ),
    );
  }

  /// Build delete confirmation dialog
  Widget _buildDeleteDialog(BuildContext dialogContext) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: const Text(
      'Delete Video',
      style: TextStyle(color: VineTheme.whiteText),
    ),
    content: const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Are you sure you want to delete this video?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        SizedBox(height: 12),
        Text(
          'This will send a delete request (NIP-09) to all relays. Some relays may still retain the content.',
          style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => dialogContext.pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          dialogContext.pop();
          _deleteContent();
        },
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        child: const Text('Delete'),
      ),
    ],
  );

  /// Delete the user's content using NIP-09
  Future<void> _deleteContent() async {
    try {
      final deletionService = await ref.read(
        contentDeletionServiceProvider.future,
      );

      // Show loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Deleting content...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final result = await deletionService.quickDelete(
        video: widget.video,
        reason: DeleteReason.personalChoice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.success
                        ? 'Delete request sent successfully'
                        : 'Failed to delete content: ${result.error}',
                  ),
                ),
              ],
            ),
            backgroundColor: result.success ? VineTheme.vineGreen : Colors.red,
          ),
        );

        // Remove video from local feeds after successful deletion
        if (result.success) {
          final videoEventService = ref.read(videoEventServiceProvider);
          videoEventService.removeVideoFromAuthorList(
            widget.video.pubkey,
            widget.video.id,
          );
          Log.info(
            'Video removed from local feeds after deletion: ${widget.video.id}',
            name: 'ShareVideoMenu',
            category: LogCategory.ui,
          );

          // Close the share menu
          if (widget.onDismiss != null) {
            widget.onDismiss!();
          }
        }
      }
    } catch (e) {
      Log.error(
        'Failed to delete content: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Dialog for sending video to specific user
class _SendToUserDialog extends ConsumerStatefulWidget {
  const _SendToUserDialog({required this.video});
  final VideoEvent video;

  @override
  ConsumerState<_SendToUserDialog> createState() => _SendToUserDialogState();
}

class _SendToUserDialogState extends ConsumerState<_SendToUserDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSearching = false;
  List<ShareableUser> _searchResults = [];
  List<ShareableUser> _contacts = [];
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserContacts();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: const Text(
      'Send to Viner',
      style: TextStyle(color: VineTheme.whiteText),
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              hintText: 'Search by name, npub, or pubkey...',
              hintStyle: TextStyle(color: VineTheme.secondaryText),
              prefixIcon: Icon(Icons.search, color: VineTheme.secondaryText),
            ),
            onChanged: (value) {
              Log.info(
                '🔍 TextField onChanged fired with value: "$value"',
                name: 'ShareVideoMenu',
                category: LogCategory.ui,
              );
              _searchUsers(value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              hintText: 'Add a personal message (optional)',
              hintStyle: TextStyle(color: VineTheme.secondaryText),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          // Show contacts or search results
          if (!_contactsLoaded) ...[
            const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          ] else if (_searchController.text.isEmpty &&
              _contacts.isNotEmpty) ...[
            // Show user's contacts when not searching
            const Text(
              'Your Contacts',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _contacts.length,
                itemBuilder: (context, index) =>
                    _buildUserTile(_contacts[index]),
              ),
            ),
          ] else if (_searchController.text.isEmpty && _contacts.isEmpty) ...[
            // No contacts found
            const Center(
              child: Text(
                'No contacts found. Start following people to see them here.',
                style: TextStyle(color: VineTheme.secondaryText),
                textAlign: TextAlign.center,
              ),
            ),
          ] else if (_searchController.text.isNotEmpty) ...[
            // Show search results
            if (_isSearching) ...[
              const Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              ),
            ] else if (_searchResults.isNotEmpty) ...[
              const Text(
                'Search Results',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) =>
                      _buildUserTile(_searchResults[index]),
                ),
              ),
            ] else ...[
              const Center(
                child: Text(
                  'No users found. Try searching by name or public key.',
                  style: TextStyle(color: VineTheme.secondaryText),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
    ],
  );

  /// Load user's contacts from their follow list (NIP-02)
  Future<void> _loadUserContacts() async {
    try {
      final socialService = ref.read(socialServiceProvider);
      final userProfileService = ref.read(userProfileServiceProvider);

      // Get the user's follow list
      final followList = socialService.followingPubkeys;
      final contacts = <ShareableUser>[];

      // Convert follows to ShareableUser objects with profile data
      for (final pubkey in followList) {
        try {
          // Fetch profile if not cached
          if (!userProfileService.hasProfile(pubkey)) {
            userProfileService.fetchProfile(pubkey);
          }

          final profile = userProfileService.getCachedProfile(pubkey);
          contacts.add(
            ShareableUser(
              pubkey: pubkey,
              displayName: profile?.bestDisplayName,
              picture: profile?.picture,
            ),
          );
        } catch (e) {
          Log.error(
            'Error loading contact profile $pubkey: $e',
            name: 'ShareVideoMenu',
            category: LogCategory.ui,
          );
          // Still add the contact without profile data
          contacts.add(
            ShareableUser(pubkey: pubkey, displayName: null, picture: null),
          );
        }
      }

      if (mounted) {
        setState(() {
          _contacts = contacts;
          _contactsLoaded = true;
        });
      }
    } catch (e) {
      Log.error(
        'Error loading user contacts: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
      if (mounted) {
        setState(() {
          _contacts = [];
          _contactsLoaded = true;
        });
      }
    }
  }

  /// Build a user tile for contacts or search results
  Widget _buildUserTile(ShareableUser user) {
    // Get user profile to check for nip05
    final userProfileService = ref.read(userProfileServiceProvider);
    final profile = userProfileService.getCachedProfile(user.pubkey);

    // Display nip05 if available, otherwise npub (never show raw hex)
    // Use normalizeToNpub to convert hex to npub format
    final displayId =
        profile?.nip05 ?? normalizeToNpub(user.pubkey) ?? user.pubkey;

    return ListTile(
      leading: UserAvatar(
        imageUrl: user.picture,
        name: user.displayName,
        size: 40,
      ),
      title: Text(
        user.displayName ?? 'Anonymous',
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      subtitle: Text(
        displayId,
        style: const TextStyle(color: VineTheme.secondaryText),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _sendToUser(user),
      dense: true,
    );
  }

  Future<void> _searchUsers(String query) async {
    Log.info(
      '🔍 Search users called with query: "$query"',
      name: 'ShareVideoMenu',
      category: LogCategory.ui,
    );

    if (query.trim().isEmpty) {
      Log.debug(
        'Search query empty, clearing results',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final userProfileService = ref.read(userProfileServiceProvider);
      final searchResults = <ShareableUser>[];

      // Try to normalize the query as a public identifier (npub/nprofile/hex)
      // If it's not a valid public identifier, use the query as is (it's likely
      // a username or display name)
      final pubKey = normalizeToHex(query);

      Log.debug(
        'Normalized query to pubkey: $pubKey',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (pubKey != null) {
        if (!userProfileService.hasProfile(pubKey)) {
          try {
            await userProfileService.fetchProfile(pubKey);
          } catch (e) {
            Log.error(
              'Error fetching profile $pubKey: $e',
              name: 'ShareVideoMenu',
              category: LogCategory.ui,
            );
          }
        }

        final profile = userProfileService.getCachedProfile(pubKey);
        searchResults.add(
          ShareableUser(
            pubkey: pubKey,
            displayName: profile?.bestDisplayName,
            picture: profile?.picture,
          ),
        );
      } else {
        try {
          final users = await userProfileService.searchUsers(query);
          searchResults.addAll(
            users.map(
              (user) => ShareableUser(
                pubkey: user.pubkey,
                displayName: user.bestDisplayName,
                picture: user.picture,
              ),
            ),
          );
        } catch (e) {
          Log.error(
            'Error searching users: $e',
            name: 'ShareVideoMenu',
            category: LogCategory.ui,
          );
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = searchResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      Log.error(
        'Error searching users: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _sendToUser(ShareableUser user) async {
    try {
      final sharingService = ref.read(videoSharingServiceProvider);
      final result = await sharingService.shareVideoWithUser(
        video: widget.video,
        recipientPubkey: user.pubkey,
        personalMessage: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      if (mounted) {
        context.pop(); // Close dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Video sent to ${user.displayName ?? 'user'}'
                  : 'Failed to send video: ${result.error}',
            ),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to send video: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}

/// Dialog for creating new curated list
class _CreateListDialog extends ConsumerStatefulWidget {
  const _CreateListDialog({required this.video});
  final VideoEvent video;

  @override
  ConsumerState<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<_CreateListDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isPublic = true;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: const Text(
      'Create New List',
      style: TextStyle(color: VineTheme.whiteText),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          enableInteractiveSelection: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: const InputDecoration(
            labelText: 'List Name',
            labelStyle: TextStyle(color: VineTheme.secondaryText),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          enableInteractiveSelection: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            labelStyle: TextStyle(color: VineTheme.secondaryText),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text(
            'Public List',
            style: TextStyle(color: VineTheme.whiteText),
          ),
          subtitle: const Text(
            'Others can follow and see this list',
            style: TextStyle(color: VineTheme.secondaryText),
          ),
          value: _isPublic,
          onChanged: (value) => setState(() => _isPublic = value),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
      TextButton(onPressed: _createList, child: const Text('Create')),
    ],
  );

  Future<void> _createList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final listService = await ref
          .read(curatedListsStateProvider.notifier)
          .service;
      final newList = await listService?.createList(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isPublic: _isPublic,
      );

      if (newList != null && mounted) {
        // Add the video to the new list
        await listService?.addVideoToList(newList.id, widget.video.id);

        if (mounted) {
          // Close dialog and return the list name
          context.pop();
        }
      }
    } catch (e) {
      Log.error(
        'Failed to create list: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create list'),
            duration: Duration(seconds: 2),
          ),
        );
        // Return null to indicate failure
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

/// Dialog for selecting existing list
class _SelectListDialog extends StatelessWidget {
  const _SelectListDialog({required this.video});
  final VideoEvent video;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, child) {
      final listServiceAsync = ref.watch(curatedListsStateProvider);

      return listServiceAsync.when(
        data: (lists) {
          final availableLists = lists.toList();

          return AlertDialog(
            backgroundColor: VineTheme.cardBackground,
            title: const Text(
              'Add to List',
              style: TextStyle(color: VineTheme.whiteText),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: availableLists.length,
                itemBuilder: (context, index) {
                  final list = availableLists[index];
                  final isInList = list.videoEventIds.contains(video.id);

                  return ListTile(
                    leading: Icon(
                      isInList ? Icons.check_circle : Icons.playlist_play,
                      color: isInList
                          ? VineTheme.vineGreen
                          : VineTheme.whiteText,
                    ),
                    title: Text(
                      list.name,
                      style: const TextStyle(color: VineTheme.whiteText),
                    ),
                    subtitle: Text(
                      '${list.videoEventIds.length} videos',
                      style: const TextStyle(color: VineTheme.secondaryText),
                    ),
                    onTap: () => _toggleVideoInList(
                      context,
                      ref.read(curatedListsStateProvider.notifier).service!,
                      list,
                      isInList,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
        loading: () => _buildLoadingIndicator,
        error: (_, __) => const Center(child: Text('Error loading lists')),
      );
    },
  );

  Future<void> _toggleVideoInList(
    BuildContext context,
    CuratedListService listService,
    CuratedList list,
    bool isCurrentlyInList,
  ) async {
    try {
      bool success;
      if (isCurrentlyInList) {
        success = await listService.removeVideoFromList(list.id, video.id);
      } else {
        success = await listService.addVideoToList(list.id, video.id);
      }

      if (success && context.mounted) {
        final message = isCurrentlyInList
            ? 'Removed from ${list.name}'
            : 'Added to ${list.name}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to toggle video in list: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }
}

/// Dialog for reporting content
/// Public report content dialog that can be used from anywhere
class ReportContentDialog extends ConsumerStatefulWidget {
  const ReportContentDialog({
    super.key,
    required this.video,
    this.isFromShareMenu = false,
  });
  final VideoEvent video;
  final bool isFromShareMenu;

  @override
  ConsumerState<ReportContentDialog> createState() =>
      ReportContentDialogState();
}

class ReportContentDialogState extends ConsumerState<ReportContentDialog> {
  ContentFilterReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _blockUser = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: const Text(
      'Report Content',
      style: TextStyle(color: VineTheme.whiteText),
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Why are you reporting this content?',
            style: TextStyle(color: VineTheme.whiteText),
          ),
          const SizedBox(height: 8),
          const Text(
            'Divine will act on content reports within 24 hours by removing the content and ejecting the user who provided the offending content.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: RadioGroup<ContentFilterReason>(
                groupValue: _selectedReason,
                onChanged: (value) => setState(() => _selectedReason = value),
                child: Column(
                  children: ContentFilterReason.values
                      .map(
                        (reason) => RadioListTile<ContentFilterReason>(
                          title: Text(
                            _getReasonDisplayName(reason),
                            style: const TextStyle(color: VineTheme.whiteText),
                          ),
                          value: reason,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _detailsController,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              labelText: 'Additional details (optional)',
              labelStyle: TextStyle(color: VineTheme.secondaryText),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            title: const Text(
              'Block this user',
              style: TextStyle(color: VineTheme.whiteText),
            ),
            value: _blockUser,
            onChanged: (value) => setState(() => _blockUser = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
      TextButton(onPressed: _handleSubmitReport, child: const Text('Report')),
    ],
  );

  void _handleSubmitReport() {
    if (_selectedReason == null) {
      // Show error when no reason selected (Apple requires button to be visible)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason for reporting this content'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _submitReport();
  }

  String _getReasonDisplayName(ContentFilterReason reason) {
    switch (reason) {
      case ContentFilterReason.spam:
        return 'Spam or Unwanted Content';
      case ContentFilterReason.harassment:
        return 'Harassment, Bullying, or Threats';
      case ContentFilterReason.violence:
        return 'Violent or Extremist Content';
      case ContentFilterReason.sexualContent:
        return 'Sexual or Adult Content';
      case ContentFilterReason.copyright:
        return 'Copyright Violation';
      case ContentFilterReason.falseInformation:
        return 'False Information';
      case ContentFilterReason.csam:
        return 'Child Safety Violation';
      case ContentFilterReason.aiGenerated:
        return 'AI-Generated Content';
      case ContentFilterReason.other:
        return 'Other Policy Violation';
    }
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    try {
      final reportService = await ref.read(
        contentReportingServiceProvider.future,
      );
      final result = await reportService.reportContent(
        eventId: widget.video.id,
        authorPubkey: widget.video.pubkey,
        reason: _selectedReason!,
        details: _detailsController.text.trim().isEmpty
            ? _getReasonDisplayName(_selectedReason!)
            : _detailsController.text.trim(),
      );

      if (mounted) {
        context.pop(); // Close report dialog
        if (widget.isFromShareMenu) {
          context.pop(); // Close share menu (only if opened from share menu)
        }

        if (result.success) {
          // Block user if checkbox was checked - publish proper Nostr events
          if (_blockUser) {
            // 1. Report the USER (creates kind 1984 for user harassment/abuse)
            await reportService.reportUser(
              userPubkey: widget.video.pubkey,
              reason: _selectedReason!,
              details:
                  'User blocked for ${_getReasonDisplayName(_selectedReason!)}',
              relatedEventIds: [widget.video.id],
            );

            // 2. Add to mute list (publishes kind 10000 NIP-51 mute list)
            final muteService = await ref.read(muteServiceProvider.future);
            await muteService.muteUser(
              widget.video.pubkey,
              reason:
                  'Reported and blocked for ${_getReasonDisplayName(_selectedReason!)}',
            );

            // 3. Also add to local blocklist for immediate filtering
            final blocklistService = ref.read(contentBlocklistServiceProvider);
            blocklistService.blockUser(widget.video.pubkey);

            Log.info(
              'User blocked with Nostr events: kind 1984 user report + kind 10000 mute list: ${widget.video.pubkey}',
              name: 'ShareVideoMenu',
              category: LogCategory.ui,
            );
          }

          // Show success confirmation dialog using root navigator
          showDialog(
            context: context,
            useRootNavigator: true,
            builder: (context) => const _ReportConfirmationDialog(),
          );
        } else {
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to report content: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to submit report: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }
}

/// Dialog for creating new follow set with this video's author
class _CreateFollowSetDialog extends ConsumerStatefulWidget {
  const _CreateFollowSetDialog({required this.authorPubkey});
  final String authorPubkey;

  @override
  ConsumerState<_CreateFollowSetDialog> createState() =>
      _CreateFollowSetDialogState();
}

class _CreateFollowSetDialogState
    extends ConsumerState<_CreateFollowSetDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: const Text(
      'Create Follow Set',
      style: TextStyle(color: VineTheme.whiteText),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          enableInteractiveSelection: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: const InputDecoration(
            labelText: 'Follow Set Name',
            labelStyle: TextStyle(color: VineTheme.secondaryText),
            hintText: 'e.g., Content Creators, Musicians, etc.',
            hintStyle: TextStyle(color: VineTheme.secondaryText),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          enableInteractiveSelection: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            labelStyle: TextStyle(color: VineTheme.secondaryText),
          ),
          maxLines: 2,
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
      TextButton(onPressed: _createFollowSet, child: const Text('Create')),
    ],
  );

  Future<void> _createFollowSet() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final socialService = ref.read(socialServiceProvider);
      final newSet = await socialService.createFollowSet(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        initialPubkeys: [widget.authorPubkey],
      );

      if (newSet != null && mounted) {
        context.pop(); // Close dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created follow set "$name" and added creator'),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to create follow set: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

/// Dialog for selecting existing follow set to add author to
class _SelectFollowSetDialog extends StatelessWidget {
  const _SelectFollowSetDialog({required this.authorPubkey});
  final String authorPubkey;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, child) {
      final socialService = ref.watch(socialServiceProvider);
      final followSets = socialService.followSets;

      return AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Add to Follow Set',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: followSets.length,
            itemBuilder: (context, index) {
              final set = followSets[index];
              final isInSet = socialService.isInFollowSet(set.id, authorPubkey);

              return ListTile(
                leading: Icon(
                  isInSet ? Icons.check_circle : Icons.people,
                  color: isInSet ? VineTheme.vineGreen : VineTheme.whiteText,
                ),
                title: Text(
                  set.name,
                  style: const TextStyle(color: VineTheme.whiteText),
                ),
                subtitle: Text(
                  '${set.pubkeys.length} users${set.description != null ? ' • ${set.description}' : ''}',
                  style: const TextStyle(color: VineTheme.secondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _toggleAuthorInFollowSet(
                  context,
                  socialService,
                  set,
                  isInSet,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Done')),
        ],
      );
    },
  );

  Future<void> _toggleAuthorInFollowSet(
    BuildContext context,
    SocialService socialService,
    FollowSet set,
    bool isCurrentlyInSet,
  ) async {
    try {
      bool success;
      if (isCurrentlyInSet) {
        success = await socialService.removeFromFollowSet(set.id, authorPubkey);
      } else {
        success = await socialService.addToFollowSet(set.id, authorPubkey);
      }

      if (success && context.mounted) {
        final message = isCurrentlyInSet
            ? 'Removed from ${set.name}'
            : 'Added to ${set.name}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to toggle user in follow set: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }
}

/// Dialog for editing video metadata
class _EditVideoDialog extends ConsumerStatefulWidget {
  const _EditVideoDialog({required this.video});
  final VideoEvent video;

  @override
  ConsumerState<_EditVideoDialog> createState() => _EditVideoDialogState();
}

class _EditVideoDialogState extends ConsumerState<_EditVideoDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _hashtagsController;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.video.title ?? '');
    _descriptionController = TextEditingController(text: widget.video.content);

    // Convert hashtags list to comma-separated string
    final hashtagsText = widget.video.hashtags.join(', ');
    _hashtagsController = TextEditingController(text: hashtagsText);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: const Text(
      'Edit Video',
      style: TextStyle(color: VineTheme.whiteText),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            enabled: !_isUpdating,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              labelText: 'Title',
              labelStyle: TextStyle(color: VineTheme.secondaryText),
              hintText: 'Enter video title',
              hintStyle: TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            enabled: !_isUpdating,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(color: VineTheme.secondaryText),
              hintText: 'Enter video description',
              hintStyle: TextStyle(color: VineTheme.secondaryText),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hashtagsController,
            enabled: !_isUpdating,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              labelText: 'Hashtags',
              labelStyle: TextStyle(color: VineTheme.secondaryText),
              hintText: 'comma, separated, hashtags',
              hintStyle: TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Note: Only metadata can be edited. Video content cannot be changed.',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isUpdating ? null : () => context.pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _isUpdating ? null : _updateVideo,
        child: _isUpdating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VineTheme.vineGreen,
                ),
              )
            : const Text('Update'),
      ),
    ],
  );

  Future<void> _updateVideo() async {
    setState(() => _isUpdating = true);

    try {
      // Parse hashtags from comma-separated string
      final hashtagsText = _hashtagsController.text.trim();
      final hashtags = hashtagsText.isEmpty
          ? <String>[]
          : hashtagsText
                .split(',')
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList();

      // Get auth service to create and sign the updated event
      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // Create updated tags for the addressable event
      final tags = <List<String>>[];

      // Required 'd' tag - must use the same identifier
      tags.add(['d', widget.video.vineId ?? widget.video.id]);

      // Build imeta tag components (preserve existing media data)
      final imetaComponents = <String>[];
      if (widget.video.videoUrl != null) {
        imetaComponents.add('url ${widget.video.videoUrl!}');
      }
      imetaComponents.add('m video/mp4');

      if (widget.video.thumbnailUrl != null) {
        imetaComponents.add('image ${widget.video.thumbnailUrl!}');
      }

      if (widget.video.blurhash != null) {
        imetaComponents.add('blurhash ${widget.video.blurhash!}');
      }

      if (widget.video.dimensions != null) {
        imetaComponents.add('dim ${widget.video.dimensions!}');
      }

      if (widget.video.sha256 != null) {
        imetaComponents.add('x ${widget.video.sha256!}');
      }

      if (widget.video.fileSize != null) {
        imetaComponents.add('size ${widget.video.fileSize!}');
      }

      // Add the complete imeta tag
      if (imetaComponents.isNotEmpty) {
        tags.add(['imeta', ...imetaComponents]);
      }

      // Add updated metadata
      final title = _titleController.text.trim();
      if (title.isNotEmpty) {
        tags.add(['title', title]);
      }

      // Add hashtags
      for (final hashtag in hashtags) {
        tags.add(['t', hashtag]);
      }

      // Preserve other original tags that shouldn't be changed
      if (widget.video.publishedAt != null) {
        tags.add(['published_at', widget.video.publishedAt!]);
      }

      if (widget.video.duration != null) {
        tags.add(['duration', widget.video.duration.toString()]);
      }

      if (widget.video.altText != null) {
        tags.add(['alt', widget.video.altText!]);
      }

      // Add client tag
      tags.add(['client', 'diVine']);

      // Create and sign the updated event
      final content = _descriptionController.text.trim();
      final event = await authService.createAndSignEvent(
        kind: 34236, // Addressable short looping video (NIP-71)
        content: content,
        tags: tags,
      );

      if (event == null) {
        throw Exception('Failed to create updated event');
      }

      // Broadcast the updated event
      final nostrService = ref.read(nostrServiceProvider);
      await nostrService.broadcastEvent(event);

      if (mounted) {
        context.pop(); // Close edit dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video updated successfully'),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to update video: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        setState(() => _isUpdating = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }
}

/// Dialog for selecting bookmark set or creating new one
class _SelectBookmarkSetDialog extends StatelessWidget {
  const _SelectBookmarkSetDialog({required this.video});
  final VideoEvent video;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, child) {
      final bookmarkServiceAsync = ref.watch(bookmarkServiceProvider);

      return bookmarkServiceAsync.when(
        data: (bookmarkService) {
          final bookmarkSets = bookmarkService.bookmarkSets;

          return AlertDialog(
            backgroundColor: VineTheme.cardBackground,
            title: const Text(
              'Add to Bookmark Set',
              style: TextStyle(color: VineTheme.whiteText),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Create New Set button at top
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VineTheme.vineGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add, color: VineTheme.vineGreen),
                    ),
                    title: const Text(
                      'Create New Set',
                      style: TextStyle(
                        color: VineTheme.whiteText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Start a new bookmark collection',
                      style: TextStyle(color: VineTheme.secondaryText),
                    ),
                    onTap: () {
                      context.pop();
                      _showCreateBookmarkSetDialog(context, ref, video);
                    },
                  ),

                  // Divider if there are existing sets
                  if (bookmarkSets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade700),
                    const SizedBox(height: 8),
                  ],

                  // List of existing bookmark sets
                  if (bookmarkSets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No bookmark sets yet. Create your first one!',
                        style: TextStyle(color: VineTheme.secondaryText),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: bookmarkSets.length,
                        itemBuilder: (context, index) {
                          final set = bookmarkSets[index];
                          final isInSet = bookmarkService.isInBookmarkSet(
                            set.id,
                            video.id,
                            'e',
                          );

                          return ListTile(
                            leading: Icon(
                              isInSet
                                  ? Icons.check_circle
                                  : Icons.bookmark_border,
                              color: isInSet
                                  ? VineTheme.vineGreen
                                  : VineTheme.whiteText,
                            ),
                            title: Text(
                              set.name,
                              style: const TextStyle(
                                color: VineTheme.whiteText,
                              ),
                            ),
                            subtitle: Text(
                              '${set.items.length} videos${set.description != null ? ' • ${set.description}' : ''}',
                              style: const TextStyle(
                                color: VineTheme.secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _toggleVideoInBookmarkSet(
                              context,
                              ref,
                              bookmarkService,
                              set,
                              video,
                              isInSet,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
        loading: () => const AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          content: Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        ),
        error: (_, __) => const AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          title: Text('Error', style: TextStyle(color: VineTheme.whiteText)),
          content: Text(
            'Failed to load bookmark sets',
            style: TextStyle(color: VineTheme.whiteText),
          ),
        ),
      );
    },
  );

  static void _showCreateBookmarkSetDialog(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
  ) {
    showDialog(
      context: context,
      builder: (context) => _CreateBookmarkSetDialog(video: video),
    );
  }

  static Future<void> _toggleVideoInBookmarkSet(
    BuildContext context,
    WidgetRef ref,
    BookmarkService bookmarkService,
    BookmarkSet set,
    VideoEvent video,
    bool isCurrentlyInSet,
  ) async {
    try {
      bool success;
      final bookmarkItem = BookmarkItem(type: 'e', id: video.id);

      if (isCurrentlyInSet) {
        success = await bookmarkService.removeFromBookmarkSet(
          set.id,
          bookmarkItem,
        );
      } else {
        success = await bookmarkService.addToBookmarkSet(set.id, bookmarkItem);
      }

      if (success && context.mounted) {
        final message = isCurrentlyInSet
            ? 'Removed from "${set.name}"'
            : 'Added to "${set.name}"';

        // Close the bookmark sets dialog
        context.pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to toggle video in bookmark set: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }
}

/// Dialog for creating new bookmark set
class _CreateBookmarkSetDialog extends ConsumerStatefulWidget {
  const _CreateBookmarkSetDialog({required this.video});
  final VideoEvent video;

  @override
  ConsumerState<_CreateBookmarkSetDialog> createState() =>
      _CreateBookmarkSetDialogState();
}

class _CreateBookmarkSetDialogState
    extends ConsumerState<_CreateBookmarkSetDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: const Text(
      'Create Bookmark Set',
      style: TextStyle(color: VineTheme.whiteText),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          enableInteractiveSelection: true,
          autofocus: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: const InputDecoration(
            labelText: 'Set Name',
            labelStyle: TextStyle(color: VineTheme.secondaryText),
            hintText: 'e.g., Favorites, Watch Later, etc.',
            hintStyle: TextStyle(color: VineTheme.secondaryText),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          enableInteractiveSelection: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            labelStyle: TextStyle(color: VineTheme.secondaryText),
          ),
          maxLines: 2,
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
      TextButton(onPressed: _createBookmarkSet, child: const Text('Create')),
    ],
  );

  Future<void> _createBookmarkSet() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      // Don't close dialog - name is required
      return;
    }

    try {
      final bookmarkService = await ref.read(bookmarkServiceProvider.future);
      final newSet = await bookmarkService.createBookmarkSet(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (newSet != null && mounted) {
        // Add the video to the new set
        final bookmarkItem = BookmarkItem(type: 'e', id: widget.video.id);
        await bookmarkService.addToBookmarkSet(newSet.id, bookmarkItem);

        if (mounted) {
          context.pop(); // Close create dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created "$name" and added video'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to create bookmark set: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

/// Public helper to show edit dialog for a video from anywhere
void showEditDialogForVideo(BuildContext context, VideoEvent video) {
  showDialog(
    context: context,
    builder: (context) => _EditVideoDialog(video: video),
  );
}

/// Confirmation dialog shown after successfully reporting content
class _ReportConfirmationDialog extends StatelessWidget {
  const _ReportConfirmationDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: Row(
      children: [
        Icon(Icons.check_circle, color: VineTheme.vineGreen, size: 28),
        const SizedBox(width: 12),
        const Text(
          'Report Received',
          style: TextStyle(color: VineTheme.whiteText),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thank you for helping keep Divine safe.',
          style: TextStyle(color: VineTheme.whiteText, fontSize: 16),
        ),
        const SizedBox(height: 16),
        const Text(
          'Our team will review your report and take appropriate action.',
          style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: () async {
            final uri = Uri.parse('https://divine.video/safety');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VineTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VineTheme.vineGreen),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: VineTheme.vineGreen, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Learn More',
                        style: TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'divine.video/safety',
                        style: TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, color: VineTheme.vineGreen, size: 18),
              ],
            ),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => context.pop(),
        child: Text('Close', style: TextStyle(color: VineTheme.vineGreen)),
      ),
    ],
  );
}

/// Dialog for viewing raw Nostr event JSON
class _ViewSourceDialog extends ConsumerWidget {
  const _ViewSourceDialog({required this.video});
  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the raw Nostr event from the video
    final nostrService = ref.read(nostrServiceProvider);

    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Row(
        children: [
          const Icon(Icons.code, color: VineTheme.vineGreen),
          const SizedBox(width: 12),
          const Text(
            'Event Source',
            style: TextStyle(color: VineTheme.whiteText),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event ID
            Row(
              children: [
                const Text(
                  'Event ID: ',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    video.id,
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  color: VineTheme.vineGreen,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: video.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Event ID copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // JSON content
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VineTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: FutureBuilder<String>(
                  future: _getEventJson(nostrService),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: VineTheme.vineGreen,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'Error loading event: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }

                    return SingleChildScrollView(
                      child: SelectableText(
                        snapshot.data ?? 'No data',
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final json = await _getEventJson(nostrService);
            await Clipboard.setData(ClipboardData(text: json));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('JSON copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: const Text('Copy JSON'),
        ),
        TextButton(onPressed: () => context.pop(), child: const Text('Close')),
      ],
    );
  }

  Future<String> _getEventJson(dynamic nostrService) async {
    try {
      // Fetch the raw event from Nostr
      final event = await nostrService.fetchEventById(video.id);
      if (event == null) {
        return 'Event not found';
      }

      // Format as pretty-printed JSON
      return const JsonEncoder.withIndent('  ').convert(event.toJson());
    } catch (e) {
      return 'Error: $e';
    }
  }
}

/// Widget for displaying public lists containing a video using Riverpod streaming
/// Uses publicListsContainingVideoProvider for reactive updates as lists arrive
class _PublicListsSection extends ConsumerStatefulWidget {
  const _PublicListsSection({required this.videoId});
  final String videoId;

  @override
  ConsumerState<_PublicListsSection> createState() =>
      _PublicListsSectionState();
}

class _PublicListsSectionState extends ConsumerState<_PublicListsSection> {
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    // Start minimum time timer to avoid flashing "no lists" before query completes
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _minTimeElapsed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the Riverpod StreamProvider - automatically updates as lists stream in
    final listsAsync = ref.watch(
      publicListsContainingVideoProvider(widget.videoId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Public Lists',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        listsAsync.when(
          data: (lists) {
            if (lists.isNotEmpty) {
              // Show lists as they arrive via Riverpod streaming
              return Column(
                children: lists
                    .map((list) => _buildPublicListTile(list))
                    .toList(),
              );
            }
            // Empty list - check if minimum time has elapsed
            if (!_minTimeElapsed) {
              return _buildLoadingIndicator();
            }
            return _buildEmptyState();
          },
          loading: () => _buildLoadingIndicator(),
          error: (error, _) {
            Log.error(
              'Error loading public lists: $error',
              name: 'PublicListsSection',
              category: LogCategory.ui,
            );
            if (!_minTimeElapsed) {
              return _buildLoadingIndicator();
            }
            return _buildEmptyState();
          },
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VineTheme.secondaryText,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Checking public lists...',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        'Not yet in any lists...',
        style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
      ),
    );
  }

  Widget _buildPublicListTile(CuratedList list) {
    final listServiceAsync = ref.watch(curatedListsStateProvider);
    final listService = ref.read(curatedListsStateProvider.notifier).service;

    return listServiceAsync.when(
      data: (lists) {
        final isSubscribed = listService?.isSubscribedToList(list.id) ?? false;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSubscribed
                    ? VineTheme.vineGreen.withValues(alpha: 0.5)
                    : Colors.grey.shade800,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.video_library, color: VineTheme.vineGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.name,
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${list.videoEventIds.length} videos',
                        style: TextStyle(
                          color: VineTheme.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _toggleSubscription(list),
                  style: TextButton.styleFrom(
                    backgroundColor: isSubscribed
                        ? VineTheme.cardBackground
                        : VineTheme.vineGreen,
                    foregroundColor: isSubscribed
                        ? VineTheme.vineGreen
                        : VineTheme.backgroundColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: isSubscribed
                          ? BorderSide(color: VineTheme.vineGreen)
                          : BorderSide.none,
                    ),
                  ),
                  child: Text(
                    isSubscribed ? 'Subscribed' : 'Subscribe',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _toggleSubscription(CuratedList list) async {
    try {
      final listService = await ref
          .read(curatedListsStateProvider.notifier)
          .service;
      final isSubscribed = listService?.isSubscribedToList(list.id) ?? false;

      if (isSubscribed) {
        await listService?.unsubscribeFromList(list.id);
        Log.info(
          'Unsubscribed from list: ${list.name}',
          name: 'PublicListsSection',
          category: LogCategory.ui,
        );
      } else {
        await listService?.subscribeToList(list.id, list);
        Log.info(
          'Subscribed to list: ${list.name}',
          name: 'PublicListsSection',
          category: LogCategory.ui,
        );
      }

      if (mounted) setState(() {});
    } catch (e) {
      Log.error(
        'Failed to toggle subscription: $e',
        name: 'PublicListsSection',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update subscription: $e'),
            backgroundColor: VineTheme.likeRed,
          ),
        );
      }
    }
  }
}
