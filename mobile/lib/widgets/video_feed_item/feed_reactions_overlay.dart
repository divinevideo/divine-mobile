// ABOUTME: "Show reactions" overlay for the playing feed video: after its first
// ABOUTME: loop, darkens the video with a scrim and shows its top comment.

import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:openvine/blocs/feed_top_comment/feed_top_comment_cubit.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:provider/provider.dart' as inherited_provider;

/// Owns the [FeedTopCommentCubit] of one feed item and shares it with
/// [child], so the overlay and the captions read the same state.
///
/// The cubit exists only while [enabled], which the feed sets for its active
/// item while reactions mode is on. It loads the top comment as soon as it is
/// created and is closed once [enabled] turns off or the item goes away;
/// meanwhile [child] reads `null`. The tree under [child] keeps its shape
/// either way, so flipping [enabled] does not remount the item.
class FeedTopCommentHost extends ConsumerStatefulWidget {
  const FeedTopCommentHost({
    required this.enabled,
    required this.video,
    required this.loopCompletions,
    required this.child,
    super.key,
  });

  final bool enabled;
  final VideoEvent video;

  /// Fires each time [video] finishes a loop.
  final Stream<void> loopCompletions;

  final Widget child;

  @override
  ConsumerState<FeedTopCommentHost> createState() => _FeedTopCommentHostState();
}

class _FeedTopCommentHostState extends ConsumerState<FeedTopCommentHost> {
  FeedTopCommentCubit? _cubit;

  /// What [_cubit] was created for; a change replaces it.
  Object? _cubitKey;

  @override
  Widget build(BuildContext context) {
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final likesRepository = ref.watch(likesRepositoryProvider);
    final key = widget.enabled
        ? (widget.video.id, commentsRepository, likesRepository)
        : null;
    if (key != _cubitKey) {
      _closeCubit();
      _cubitKey = key;
      if (key != null) {
        _cubit = _createCubit(commentsRepository, likesRepository);
      }
    }
    return inherited_provider.Provider<FeedTopCommentCubit?>.value(
      value: _cubit,
      child: widget.child,
    );
  }

  FeedTopCommentCubit _createCubit(
    CommentsRepository commentsRepository,
    LikesRepository likesRepository,
  ) {
    final video = widget.video;
    final cubit = FeedTopCommentCubit(
      commentsRepository: commentsRepository,
      likesRepository: likesRepository,
      rootEventId: video.id,
      rootEventKind: NIP71VideoKinds.addressableShortVideo,
      rootAuthorPubkey: video.pubkey,
      rootAddressableId: video.addressableId,
      loopCompletions: widget.loopCompletions,
    );
    runDetached(
      cubit.load(),
      'load feed top comment',
      logName: 'FeedTopCommentHost',
      category: LogCategory.ui,
    );
    return cubit;
  }

  void _closeCubit() {
    final cubit = _cubit;
    if (cubit == null) return;
    _cubit = null;
    runDetached(
      cubit.close(),
      'close feed top comment',
      logName: 'FeedTopCommentHost',
      category: LogCategory.ui,
    );
  }

  @override
  void dispose() {
    _closeCubit();
    super.dispose();
  }
}

/// Hides [child] while the top-comment overlay is up, keeping its state, so
/// captions disappear behind a reaction without being turned off.
class HiddenWhileTopCommentShown extends StatelessWidget {
  const HiddenWhileTopCommentShown({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<FeedTopCommentCubit?>();
    if (cubit == null) return child;
    return BlocSelector<FeedTopCommentCubit, FeedTopCommentState, bool>(
      bloc: cubit,
      selector: (state) => state.isOverlayVisible,
      builder: (context, isShown) =>
          Visibility(visible: !isShown, maintainState: true, child: child),
    );
  }
}

/// Lays a scrim over the playing video and shows its top comment on it, once
/// [FeedTopCommentState.isOverlayVisible].
///
/// Tapping the scrim dismisses it; tapping the comment opens the
/// comments sheet at that comment.
class FeedReactionsOverlay extends StatelessWidget {
  const FeedReactionsOverlay({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<FeedTopCommentCubit?>();
    if (cubit == null) return const SizedBox.shrink();
    return BlocProvider<FeedTopCommentCubit>.value(
      value: cubit,
      child: _FeedReactionsOverlayView(video: video),
    );
  }
}

class _FeedReactionsOverlayView extends StatelessWidget {
  const _FeedReactionsOverlayView({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final isVisible = context.select(
      (FeedTopCommentCubit cubit) => cubit.state.isOverlayVisible,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // The reaction covers the video after a loop with no input from the
    // viewer, so a screen reader is told what appeared.
    return BlocListener<FeedTopCommentCubit, FeedTopCommentState>(
      listenWhen: (previous, current) =>
          !previous.isOverlayVisible && current.isOverlayVisible,
      listener: (context, state) => announceDetached(
        context,
        state.topComment!.content.trim(),
        description: 'announce feed reaction',
        logName: 'FeedReactionsOverlay',
      ),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          opacity: isVisible ? 1 : 0,
          duration: reduceMotion
              ? Duration.zero
              : FeedReactionsOverlayLayout.fadeDuration,
          child: isVisible
              ? _ReactionContent(video: video)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ReactionContent extends StatelessWidget {
  const _ReactionContent({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final top =
        MediaQuery.viewPaddingOf(context).top +
        FeedReactionsOverlayLayout.topBarHeight +
        FeedReactionsOverlayLayout.gapBelowTopBar;
    return Stack(
      children: [
        // The scrim paints nothing hit-testable, so every tap outside the
        // comment reaches this layer and dismisses the reaction.
        Positioned.fill(
          child: Semantics(
            button: true,
            label: context.l10n.feedReactionDismiss,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.read<FeedTopCommentCubit>().dismiss(),
            ),
          ),
        ),
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Solid from the top of the screen to the end of the comment,
              // so it grows with the comment's real height.
              Stack(
                children: [
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: FeedReactionsOverlayLayout.scrim,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      FeedReactionsOverlayLayout.sidePadding,
                      top,
                      FeedReactionsOverlayLayout.sidePadding,
                      FeedReactionsOverlayLayout.solidBelowContent,
                    ),
                    child: _TopCommentContent(video: video),
                  ),
                ],
              ),
              // Then fades out to nothing at the bottom of the screen.
              const Expanded(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          FeedReactionsOverlayLayout.scrim,
                          VineTheme.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopCommentContent extends StatelessWidget {
  const _TopCommentContent({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final comment = context.select(
      (FeedTopCommentCubit cubit) => cubit.state.topComment,
    );
    if (comment == null) return const SizedBox.shrink();

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: FeedReactionsOverlayLayout.maxTextScale,
      child: Semantics(
        button: true,
        hint: context.l10n.feedReactionOpenComment,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openComment(context, comment),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: FeedReactionsOverlayLayout.gapBelowBubble,
            children: [
              _SpeechBubble(content: comment.content.trim()),
              _TopCommentAuthor(authorPubkey: comment.authorPubkey),
            ],
          ),
        ),
      ),
    );
  }

  void _openComment(BuildContext context, Comment comment) {
    context.read<FeedTopCommentCubit>().dismiss();
    final interactionsBloc = context.read<VideoInteractionsBloc?>();
    runDetached(
      CommentsScreen.show(
        context,
        video,
        initialCommentCount: interactionsBloc?.state.commentCount,
        focusCommentId: comment.id,
        onCommentCountChanged: interactionsBloc == null
            ? null
            : (count) {
                if (!interactionsBloc.isClosed) {
                  interactionsBloc.add(
                    VideoInteractionsCommentCountUpdated(count),
                  );
                }
              },
      ),
      'present comments screen from reaction',
      logName: 'FeedReactionsOverlay',
      category: LogCategory.ui,
    );
  }
}

/// White speech bubble holding the top comment, its tail hanging from the
/// bottom edge near the left, towards the author row below.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // As wide as the comment needs, up to the full width, and never so
        // narrow that the tail no longer fits under the body.
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: FeedReactionsOverlayLayout.bubbleMinWidth,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: FeedReactionsOverlayLayout.bubbleColor,
              borderRadius: BorderRadius.circular(
                FeedReactionsOverlayLayout.bubbleRadius,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FeedReactionsOverlayLayout.bubbleHorizontalPadding,
                vertical: FeedReactionsOverlayLayout.bubbleVerticalPadding,
              ),
              child: _TopCommentText(content: content),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: FeedReactionsOverlayLayout.tailInset,
          ),
          child: ExcludeSemantics(
            child: SvgPicture.asset(
              FeedReactionsOverlayLayout.tailAsset,
              width: FeedReactionsOverlayLayout.tailWidth,
              height: FeedReactionsOverlayLayout.tailHeight,
            ),
          ),
        ),
      ],
    );
  }
}

/// The top comment's text, with mentions, links and hashtags rendered as
/// the comments sheet renders them, at headline size.
///
/// Tapping a mention or link follows it, as in the sheet; a tap anywhere else
/// reaches the surrounding detector and opens the sheet.
class _TopCommentText extends StatelessWidget {
  const _TopCommentText({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final baseStyle = VineTheme.headlineLargeFont(
      color: FeedReactionsOverlayLayout.bubbleTextColor,
    );
    // The bubble is white whatever the appearance, so the sheet's link colour
    // for a light surface is fixed rather than adaptive.
    final linkColor = VineTheme.lightColors.link;
    return LinkifiedText(
      text: content,
      style: baseStyle,
      linkStyle: baseStyle.copyWith(
        color: linkColor,
        fontWeight: FontWeight.w500,
        decoration: TextDecoration.underline,
        decorationColor: linkColor,
      ),
      mentionStyle: baseStyle.copyWith(
        color: linkColor,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: linkColor,
      ),
      maxLines: FeedReactionsOverlayLayout.commentMaxLines,
      overflow: TextOverflow.ellipsis,
      // Hug the longest line, so the bubble ends where the text does.
      textWidthBasis: TextWidthBasis.longestLine,
    );
  }
}

/// Who posted the top comment: a small avatar and their name, as the
/// comments sheet shows a comment's author.
class _TopCommentAuthor extends ConsumerWidget {
  const _TopCommentAuthor({required this.authorPubkey});

  final String authorPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(authorPubkey)).value;
    final nameStyle = VineTheme.titleSmallFont(color: VineTheme.whiteText);
    // As wide as its content, so the comment's tap area ends where the
    // bubble and name do and a tap beside them reaches the scrim.
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        UserAvatar(
          size: FeedReactionsOverlayLayout.authorAvatarSize,
          imageUrl: profile?.picture,
          placeholderSeed: authorPubkey,
        ),
        Flexible(
          child: profile == null
              ? Text(
                  UserProfile.generatedNameFor(authorPubkey),
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : UserName.fromUserProfile(
                  profile,
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ],
    );
  }
}

/// Layout constants of [FeedReactionsOverlay], from the reactions design.
abstract final class FeedReactionsOverlayLayout {
  /// Height of the home feed's top bar below the status bar: its 48 px row
  /// plus 16 px padding above and below.
  static const double topBarHeight = 80;

  /// Space between the top bar and the speech bubble.
  static const double gapBelowTopBar = 13;

  static const double sidePadding = 16;

  /// The speech bubble around the comment; white like its tail asset.
  static const Color bubbleColor = VineTheme.whiteText;
  static const Color bubbleTextColor = VineTheme.primaryDarkGreen;
  static const double bubbleRadius = 24;
  static const double bubbleHorizontalPadding = 20;
  static const double bubbleVerticalPadding = 16;

  /// The bubble's tail, from the design.
  static const tailAsset = 'assets/reactions/bubble_tail.svg';
  static const double tailWidth = 22;
  static const double tailHeight = 16;

  /// The tail's offset from the bubble's left edge.
  static const double tailInset = 28;

  /// Narrowest bubble that still holds the tail under its straight edge:
  /// the tail's inset and width plus the bottom-right corner's radius.
  static const double bubbleMinWidth = tailInset + tailWidth + bubbleRadius;

  /// Space between the bubble's tail and the author row.
  static const double gapBelowBubble = 8;

  /// Scrim behind the comment.
  static const Color scrim = VineTheme.scrim70;

  /// Solid scrim kept below the author row before the gradient starts.
  static const double solidBelowContent = 16;

  static const double authorAvatarSize = 24;

  static const fadeDuration = Duration(milliseconds: 250);

  static const commentMaxLines = 6;

  /// Largest text scale the comment and its author grow to, as in the
  /// comments sheet: six headline lines past it no longer fit a phone screen.
  static const double maxTextScale = 1.5;
}
