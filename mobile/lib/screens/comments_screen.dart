// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses Nostr Kind 1 events for comments with proper e/p tags for threading

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/comments_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({required this.videoEvent, super.key});
  final VideoEvent videoEvent;

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _commentController = TextEditingController();
  final _replyControllers = <String, TextEditingController>{};
  String? _replyingToCommentId;
  bool _isPosting = false;
  // Using Riverpod commentsProvider instead
  @override
  void initState() {
    super.initState();
    // Comments notifier is automatically initialized when watched
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _postComment({String? replyToId}) async {
    final controller = replyToId != null
        ? _replyControllers[replyToId]
        : _commentController;

    if (controller == null || controller.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final socialService = ref.read(socialServiceProvider);
      await socialService.postComment(
        content: controller.text.trim(),
        rootEventId: widget.videoEvent.id,
        rootEventAuthorPubkey: widget.videoEvent.pubkey,
        replyToEventId: replyToId,
      );

      controller.clear();
      if (replyToId != null) {
        setState(() => _replyingToCommentId = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        // Video in background (paused - autoplay disabled)
        VideoFeedItem(
          video: widget.videoEvent,
          index: 0, // Single video in comments screen
          disableAutoplay: true, // Don't start playing when opening comments
        ),

        // Comments overlay
        DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) => DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Comments header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Comments',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white24, height: 1),

                // Comments list
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final state = ref.watch(
                        commentsProvider(
                          widget.videoEvent.id,
                          widget.videoEvent.pubkey,
                        ),
                      );

                      if (state.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      if (state.error != null) {
                        return Center(
                          child: Text(
                            'Error loading comments: ${state.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (state.topLevelComments.isEmpty) {
                        // Check if this is a classic vine (recovered from archive)
                        final isClassicVine = widget.videoEvent.isOriginalVine;

                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isClassicVine) ...[
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade900.withValues(
                                      alpha: 0.3,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.shade700.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.history,
                                        color: Colors.orange.shade300,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Classic Vine',
                                        style: TextStyle(
                                          color: Colors.orange.shade300,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'We\'re still working on importing old comments from the archive. They\'re not ready yet.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              const Text(
                                'No comments yet.\nBe the first to comment!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: state.topLevelComments.length,
                        itemBuilder: (context, index) =>
                            _buildCommentThread(state.topLevelComments[index]),
                      );
                    },
                  ),
                ),

                // Comment input
                _buildCommentInput(),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildCommentThread(CommentNode node, {int depth = 0}) {
    final comment = node.comment;
    final isReplying = _replyingToCommentId == comment.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(left: depth * 24.0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      // Fetch profile for this comment author
                      final userProfileService = ref.watch(
                        userProfileServiceProvider,
                      );
                      final profile = userProfileService.getCachedProfile(
                        comment.authorPubkey,
                      );

                      // If profile not cached and not known missing, fetch it
                      if (profile == null &&
                          !userProfileService.shouldSkipProfileFetch(
                            comment.authorPubkey,
                          )) {
                        Future.microtask(() {
                          ref
                              .read(userProfileProvider.notifier)
                              .fetchProfile(comment.authorPubkey);
                        });
                      }

                      final display =
                          profile?.bestDisplayName ??
                          profile?.displayName ??
                          profile?.name ??
                          'Loading...';

                      return UserAvatar(name: display, size: 32);
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        // Fetch profile for display name
                        final userProfileService = ref.watch(
                          userProfileServiceProvider,
                        );
                        final profile = userProfileService.getCachedProfile(
                          comment.authorPubkey,
                        );

                        final display =
                            profile?.bestDisplayName ??
                            profile?.displayName ??
                            profile?.name ??
                            'Loading...';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                // Navigate to profile screen
                                context.goProfileGrid(comment.authorPubkey);
                              },
                              child: Text(
                                display,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white54,
                                ),
                              ),
                            ),
                            Text(
                              comment.relativeTime,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      comment.content,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_replyingToCommentId == comment.id) {
                                _replyingToCommentId = null;
                              } else {
                                _replyingToCommentId = comment.id;
                                _replyControllers[comment.id] ??=
                                    TextEditingController();
                              }
                            });
                          },
                          child: Text(
                            isReplying ? 'Cancel' : 'Reply',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isReplying) _buildReplyInput(comment.id),
            ],
          ),
        ),
        ...node.replies.map(
          (reply) => _buildCommentThread(reply, depth: depth + 1),
        ),
      ],
    );
  }

  Widget _buildReplyInput(String parentId) {
    final controller = _replyControllers[parentId]!;

    return Container(
      margin: const EdgeInsets.only(left: 44, top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enableInteractiveSelection: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            onPressed: _isPosting
                ? null
                : () => _postComment(replyToId: parentId),
            icon: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() => Container(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 8,
      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
    ),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      border: Border(top: BorderSide(color: Colors.grey[800]!)),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            enableInteractiveSelection: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Add a comment...',
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
            ),
            maxLines: null,
          ),
        ),
        IconButton(
          onPressed: _isPosting ? null : _postComment,
          icon: _isPosting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send, color: Colors.white),
        ),
      ],
    ),
  );
}
