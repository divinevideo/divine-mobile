// ABOUTME: "Show reactions" overlay for the playing feed video: after its first
// ABOUTME: loop, darkens the video with a scrim and shows its top comment.

import 'dart:math' as math;

import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/feed_top_comment/feed_top_comment_cubit.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_support.dart';
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
/// Account, block and relevant moderation revisions refresh the candidate while
/// preserving dismissal and loop progress for the same viewer/video.
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
  ({(String, String?) video, Object dependencies, int moderationRevision})?
  _cubitKey;

  @override
  Widget build(BuildContext context) {
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final likesRepository = ref.watch(likesRepositoryProvider);
    final moderationRepository = widget.enabled
        ? ref.watch(commentModerationRepositoryProvider)
        : null;
    final viewerPubkey = widget.enabled
        ? ref.watch(nostrSessionProvider.select((session) => session.pubkey))
        : null;
    final blocklistVersion = widget.enabled
        ? ref.watch(blocklistVersionProvider)
        : 0;
    final coordinate = widget.video.addressableId;
    if (moderationRepository != null &&
        coordinate != null &&
        coordinate.isNotEmpty) {
      ref.watch(commentModerationRevisionProvider(coordinate));
    }
    final known =
        moderationRepository == null || coordinate == null || coordinate.isEmpty
        ? const (moderation: CommentModeration.empty, revision: 0)
        : moderationRepository.knownModeration(rootAddressableId: coordinate);
    final applied = _cubit?.state;
    final needsRefresh =
        applied != null &&
        (applied.status == FeedTopCommentStatus.ready ||
            applied.status == FeedTopCommentStatus.empty) &&
        known.revision > applied.moderationRevision &&
        known.moderation != applied.appliedModeration;
    final moderationRevision = needsRefresh
        ? known.revision
        : (_cubitKey?.moderationRevision ?? known.revision);
    final viewerBlocks = viewerPubkey == null
        ? const <String>{}
        : ref
              .watch(contentBlocklistRepositoryProvider)
              .blockedPubkeysForAccount(viewerPubkey);
    final key = widget.enabled
        ? (
            video: (widget.video.id, viewerPubkey),
            dependencies: (
              widget.video.referenceKind,
              widget.video.addressableId,
              commentsRepository,
              likesRepository,
              moderationRepository,
              blocklistVersion,
            ),
            moderationRevision: moderationRevision,
          )
        : null;
    if (key != _cubitKey) {
      final visibility = _cubitKey?.video == key?.video ? _cubit?.state : null;
      _closeCubit();
      _cubitKey = key;
      if (moderationRepository != null) {
        _cubit = _createCubit(
          commentsRepository,
          likesRepository,
          moderationRepository,
          viewerPubkey,
          viewerBlocks,
          initialHasCompletedLoop: visibility?.hasCompletedLoop ?? false,
          initiallyDismissed: visibility?.isDismissed ?? false,
        );
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
    CommentModerationRepository moderationRepository,
    String? viewerPubkey,
    Set<String> viewerBlockedAuthors, {
    required bool initialHasCompletedLoop,
    required bool initiallyDismissed,
  }) {
    final video = widget.video;
    final cubit = FeedTopCommentCubit(
      commentsRepository: commentsRepository,
      likesRepository: likesRepository,
      commentModerationRepository: moderationRepository,
      viewerPubkey: viewerPubkey,
      viewerBlockedAuthors: viewerBlockedAuthors,
      initialHasCompletedLoop: initialHasCompletedLoop,
      initiallyDismissed: initiallyDismissed,
      rootEventId: video.id,
      rootEventKind: video.referenceKind,
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

class _FeedReactionsOverlayView extends ConsumerStatefulWidget {
  const _FeedReactionsOverlayView({required this.video});

  final VideoEvent video;

  @override
  ConsumerState<_FeedReactionsOverlayView> createState() =>
      _FeedReactionsOverlayViewState();
}

class _FeedReactionsOverlayViewState
    extends ConsumerState<_FeedReactionsOverlayView> {
  /// Whether the reaction has finished fading in. Until then it takes no
  /// taps, so a tap meant for the video is not spent on something unseen.
  bool _fadedIn = true;

  /// The top comment as the bubble shows it, so a screen reader hears a
  /// mention as a name rather than a `nostr:` code.
  String _spokenText = '';

  @override
  Widget build(BuildContext context) {
    final isVisible = context.select(
      (FeedTopCommentCubit cubit) => cubit.state.isOverlayVisible,
    );
    final comment = context.select(
      (FeedTopCommentCubit cubit) => cubit.state.topComment,
    );
    _spokenText = isVisible && comment != null
        ? _spokenComment(context, ref, comment.content.trim())
        : '';
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return BlocListener<FeedTopCommentCubit, FeedTopCommentState>(
      listenWhen: (previous, current) =>
          !previous.isOverlayVisible && current.isOverlayVisible,
      listener: (context, state) {
        if (!reduceMotion) {
          setState(() => _fadedIn = false);
          return;
        }
        // No fade to wait for: announce once the reaction is drawn.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _announce();
        });
      },
      child: IgnorePointer(
        ignoring: !isVisible || !_fadedIn,
        child: AnimatedOpacity(
          opacity: isVisible ? 1 : 0,
          duration: reduceMotion
              ? Duration.zero
              : FeedReactionsOverlayLayout.fadeDuration,
          // Also called when a fade-out ends, including one that cut a
          // fade-in short; only a reaction still showing is announced.
          onEnd: () {
            if (_fadedIn) return;
            setState(() => _fadedIn = true);
            if (context.read<FeedTopCommentCubit>().state.isOverlayVisible) {
              _announce();
            }
          },
          child: isVisible
              ? _ReactionContent(video: widget.video, spokenText: _spokenText)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// The reaction covers the video after a loop with no input from the
  /// viewer, so a screen reader is told what appeared.
  void _announce() => announceDetached(
    context,
    _spokenText,
    description: 'announce feed reaction',
    logName: 'FeedReactionsOverlay',
  );
}

/// [content] as plain text, with mentions resolved the way the bubble's
/// [LinkifiedText] shows them.
String _spokenComment(BuildContext context, WidgetRef ref, String content) {
  // Only the plain text is read; this style is never painted.
  final style = VineTheme.bodyMediumFont(
    color: FeedReactionsOverlayLayout.bubbleTextColor,
  );
  final spans = LinkifiedTextSpanBuilder(
    text: content,
    defaultStyle: style,
    linkStyle: style,
    profileLabelForHex: (hexPubkey) =>
        LinkifiedTextSupport.profileDisplayText(ref, hexPubkey),
    videoLabel: context.l10n.clickableTextViewVideoLink,
    allowWidgetSpans: false,
  ).build();
  final text = TextSpan(children: spans).toPlainText();
  // The builder gives every link its own tap recognizer.
  LinkifiedTextSupport.disposeSpans(spans);
  return text;
}

class _ReactionContent extends StatelessWidget {
  const _ReactionContent({required this.video, required this.spokenText});

  final VideoEvent video;

  /// The comment as the bubble shows it, read by screen readers.
  final String spokenText;

  @override
  Widget build(BuildContext context) {
    final top =
        MediaQuery.viewPaddingOf(context).top +
        FeedReactionsOverlayLayout.topBarHeight +
        FeedReactionsOverlayLayout.gapBelowTopBar;
    return LayoutBuilder(
      builder: (context, constraints) => _ReactionLayers(
        video: video,
        spokenText: spokenText,
        top: top,
        commentMaxLines: _commentLinesThatFit(
          context,
          height: constraints.maxHeight,
          top: top,
        ),
      ),
    );
  }
}

/// How many lines of the comment fit in [height] once [top], the bubble's
/// padding and tail, the author row and the solid strip below it are taken,
/// at the text scale the comment is drawn at: a short phone at a large text
/// size gets fewer than [FeedReactionsOverlayLayout.commentMaxLines].
int _commentLinesThatFit(
  BuildContext context, {
  required double height,
  required double top,
}) {
  final scaler = MediaQuery.textScalerOf(
    context,
  ).clamp(maxScaleFactor: FeedReactionsOverlayLayout.maxTextScale);
  final direction = Directionality.of(context);
  double lineHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textScaler: scaler,
      textDirection: direction,
    )..layout();
    final lineHeight = painter.height;
    painter.dispose();
    return lineHeight;
  }

  final commentLine = lineHeight(
    VineTheme.headlineLargeFont(
      color: FeedReactionsOverlayLayout.bubbleTextColor,
    ),
  );
  final authorRow = math.max(
    FeedReactionsOverlayLayout.authorAvatarSize,
    lineHeight(VineTheme.titleSmallFont(color: VineTheme.whiteText)),
  );
  final chrome =
      top +
      2 * FeedReactionsOverlayLayout.bubbleVerticalPadding +
      FeedReactionsOverlayLayout.tailHeight +
      FeedReactionsOverlayLayout.gapBelowBubble +
      authorRow +
      FeedReactionsOverlayLayout.solidBelowContent;
  return ((height - chrome) / commentLine).floor().clamp(
    1,
    FeedReactionsOverlayLayout.commentMaxLines,
  );
}

class _ReactionLayers extends StatelessWidget {
  const _ReactionLayers({
    required this.video,
    required this.spokenText,
    required this.top,
    required this.commentMaxLines,
  });

  final VideoEvent video;
  final String spokenText;
  final double top;
  final int commentMaxLines;

  @override
  Widget build(BuildContext context) {
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
                    child: _TopCommentContent(
                      video: video,
                      spokenText: spokenText,
                      commentMaxLines: commentMaxLines,
                    ),
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
  const _TopCommentContent({
    required this.video,
    required this.spokenText,
    required this.commentMaxLines,
  });

  final VideoEvent video;
  final String spokenText;
  final int commentMaxLines;

  @override
  Widget build(BuildContext context) {
    final comment = context.select(
      (FeedTopCommentCubit cubit) => cubit.state.topComment,
    );
    if (comment == null) return const SizedBox.shrink();
    final content = comment.content.trim();

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: FeedReactionsOverlayLayout.maxTextScale,
      // Label the complete comment once while its inline links keep their
      // separate actions. LinkifiedText silences only non-interactive runs.
      child: Semantics(
        button: true,
        label: spokenText,
        hint: context.l10n.feedReactionOpenComment,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openComment(context, comment),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: FeedReactionsOverlayLayout.gapBelowBubble,
            children: [
              _SpeechBubble(
                content: content,
                maxLines: commentMaxLines,
              ),
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
/// bottom edge near the start, towards the author row below.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.content, required this.maxLines});

  final String content;
  final int maxLines;

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
              child: _TopCommentText(content: content, maxLines: maxLines),
            ),
          ),
        ),
        // On the start side, so in a right-to-left locale the tail sits by the
        // bubble's right edge and is mirrored to point the same way.
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: FeedReactionsOverlayLayout.tailInset,
          ),
          child: ExcludeSemantics(
            child: SvgPicture.asset(
              FeedReactionsOverlayLayout.tailAsset,
              width: FeedReactionsOverlayLayout.tailWidth,
              height: FeedReactionsOverlayLayout.tailHeight,
              matchTextDirection: true,
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
  const _TopCommentText({required this.content, required this.maxLines});

  final String content;
  final int maxLines;

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
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      // Hug the longest line, so the bubble ends where the text does.
      textWidthBasis: TextWidthBasis.longestLine,
      excludeNonLinkSemantics: true,
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
        // The name beside it already says who wrote the comment.
        ExcludeSemantics(
          child: UserAvatar(
            size: FeedReactionsOverlayLayout.authorAvatarSize,
            imageUrl: profile?.picture,
            placeholderSeed: authorPubkey,
          ),
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

  /// The tail's offset from the bubble's start edge.
  static const double tailInset = 28;

  /// Narrowest bubble that still holds the tail under its straight edge:
  /// the tail's inset and width plus the bottom end corner's radius.
  static const double bubbleMinWidth = tailInset + tailWidth + bubbleRadius;

  /// Space between the bubble's tail and the author row.
  static const double gapBelowBubble = 8;

  /// Scrim behind the comment.
  static const Color scrim = VineTheme.scrim70;

  /// Solid scrim kept below the author row before the gradient starts.
  static const double solidBelowContent = 16;

  static const double authorAvatarSize = 24;

  static const fadeDuration = Duration(milliseconds: 250);

  /// Most lines of the comment shown; fewer when the item is too short.
  static const commentMaxLines = 6;

  /// Largest text scale the comment and its author grow to, as in the
  /// comments sheet: six headline lines past it no longer fit a phone screen.
  static const double maxTextScale = 1.5;
}
