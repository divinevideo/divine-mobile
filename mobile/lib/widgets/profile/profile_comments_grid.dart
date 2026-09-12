// ABOUTME: Grid widget displaying a user's comments on their profile.
// ABOUTME: Shows video replies as a 3-column thumbnail grid at top,
// ABOUTME: followed by text comments as a list below.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_comments/profile_comments_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/profile/profile_tab_empty_state.dart';
import 'package:openvine/widgets/profile/profile_tab_error_state.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_more_sliver.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_state.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';

/// Grid widget displaying a user's comments (video replies + text).
///
/// Requires [ProfileCommentsBloc] to be provided in the widget tree.
class ProfileCommentsGrid extends StatefulWidget {
  const ProfileCommentsGrid({required this.isOwnProfile, super.key});

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  @override
  State<ProfileCommentsGrid> createState() => _ProfileCommentsGridState();
}

class _ProfileCommentsGridState extends State<ProfileCommentsGrid>
    with ScrollPaginationMixin {
  /// Resolved from [PrimaryScrollController] provided by [NestedScrollView].
  ScrollController? _primaryScrollController;

  @override
  ScrollController get paginationScrollController => _primaryScrollController!;

  @override
  bool canLoadMore() {
    final bloc = context.read<ProfileCommentsBloc>();
    return bloc.state.hasMoreContent && !bloc.state.isLoadingMore;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ProfileCommentsBloc>().add(
      const ProfileCommentsLoadMoreRequested(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = PrimaryScrollController.of(context);
    if (_primaryScrollController != primary) {
      if (_primaryScrollController != null) disposePagination();
      _primaryScrollController = primary;
      initPagination();
    }
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCommentsBloc, ProfileCommentsState>(
      builder: (context, state) {
        if (state.status == ProfileCommentsStatus.initial ||
            state.status == ProfileCommentsStatus.loading) {
          return const ProfileTabLoadingState();
        }

        if (state.status == ProfileCommentsStatus.failure) {
          return ProfileTabErrorState(
            message: context.l10n.profileErrorLoadingComments,
          );
        }

        if (state.videoReplies.isEmpty && state.textComments.isEmpty) {
          return ProfileTabEmptyState(
            title: widget.isOwnProfile
                ? context.l10n.profileNoCommentsOwnTitle
                : context.l10n.profileNoCommentsOtherTitle,
            subtitle: widget.isOwnProfile
                ? context.l10n.profileCommentsOwnEmpty
                : context.l10n.profileCommentsOtherEmpty,
          );
        }

        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            if (state.videoReplies.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: context.l10n.profileVideoRepliesSection,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= state.videoReplies.length) {
                      return const SizedBox.shrink();
                    }
                    return _VideoReplyTile(
                      comment: state.videoReplies[index],
                      index: index,
                    );
                  }, childCount: state.videoReplies.length),
                ),
              ),
            ],
            if (state.textComments.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: context.l10n.profileCommentsSection,
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= state.textComments.length) {
                    return const SizedBox.shrink();
                  }
                  return _ProfileCommentCard(
                    comment: state.textComments[index],
                  );
                }, childCount: state.textComments.length),
              ),
            ],
            if (state.isLoadingMore) const ProfileTabLoadingMoreSliver(),
          ],
        );
      },
    );
  }
}

/// Section header label for video replies and text comments.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.vineColors.secondaryText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Thumbnail tile for a video reply in the grid.
class _VideoReplyTile extends StatelessWidget {
  const _VideoReplyTile({required this.comment, required this.index});

  final Comment comment;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // The tile renders only a thumbnail and a play glyph, so without this
      // it is a focusable, tappable node with an empty name (#6951).
      label: context.l10n.profileVideoThumbnailLabel(index + 1),
      button: true,
      child: GestureDetector(
        onTap: () =>
            context.push(VideoDetailScreen.pathForId(comment.rootEventId)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: DecoratedBox(
            decoration: BoxDecoration(color: context.vineColors.card),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProfileTabThumbnail(
                  thumbnailUrl: comment.thumbnailUrl,
                  blurhash: comment.videoBlurhash,
                ),
                // Play icon overlay
                Center(
                  child: DivineIcon(
                    icon: DivineIconName.playCircle,
                    color: context.vineColors.primaryText,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card widget for a text comment in the list.
class _ProfileCommentCard extends StatelessWidget {
  const _ProfileCommentCard({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final baseStyle = VineTheme.bodyMediumFont(
      color: context.vineColors.primaryText,
    );

    // No `label:` on purpose. Unlike the thumbnail tiles, this card renders
    // the comment text, and Semantics(label:) is prepended to the child's
    // label rather than replacing it — adding one here would make a screen
    // reader read the comment twice. `button: true` supplies the missing
    // role; the text supplies the name.
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () =>
            context.push(VideoDetailScreen.pathForId(comment.rootEventId)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinkifiedText(
                      text: comment.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: baseStyle,
                      linkStyle: baseStyle.copyWith(
                        color: VineTheme.info,
                        fontWeight: FontWeight.w600,
                      ),
                      mentionStyle: baseStyle.copyWith(
                        color: VineTheme.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LocalizedTimeFormatter.formatRelativeVerbose(
                        context.l10n,
                        comment.createdAt.millisecondsSinceEpoch ~/ 1000,
                      ),
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DivineIcon(
                icon: DivineIconName.caretRight,
                color: context.vineColors.onSurfaceMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
