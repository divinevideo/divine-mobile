// ABOUTME: Chat message bubble widget for sent and received messages.
// ABOUTME: Supports message grouping with variable border radius,
// ABOUTME: conditional timestamp display, clickable URLs, long-press actions,
// ABOUTME: and inline video preview cards for divine.video links.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio, LogCategory;
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_target.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:openvine/screens/inbox/dm_display_text.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_support.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/markdown/markdown.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Matches a single line whose entire content is a straight-quoted
/// string — the shape `VideoSharingService` uses to embed the title in
/// the share-message body (`"<title>"`). The bubble drops this line so
/// the title isn't duplicated alongside the overlay-footer rendering.
final _quotedTitleRegex = RegExp(r'^".*"$');

/// Matches a line that is just a NIP-21 `nostr:` citation (or bare entity).
/// The share body carries a `nostr:naddr…`/`nevent…` reference for other
/// clients to resolve, but in-app it duplicates the tappable video card, so
/// the bubble drops it rather than rendering a redundant "View video" link.
final _nostrRefLineRegex = RegExp(
  r'^(?:nostr:)?(?:naddr|nevent|note|npub|nprofile)1[0-9a-z]+$',
  caseSensitive: false,
);

class _DmBubbleContent {
  const _DmBubbleContent({
    required this.videoTarget,
    required this.personalMessage,
    required this.textAfterUrl,
    required this.quotedReplyText,
  });

  factory _DmBubbleContent.parse(
    String boundedMessage, {
    required DmSharedVideoRef? sharedVideoRef,
    required DmSharedVideoRef? quotedVideoRef,
    required bool isTruncated,
  }) {
    // The prefix is deliberately bounded before this full-copy sanitizer and
    // every regex/split below. Sanitizing here also repairs malformed UTF-16
    // from JSON escapes before the string reaches Flutter's paragraph builder.
    final safeMessage = StringUtils.sanitizeUtf16(boundedMessage);
    // A URL the bound cut through is text until Show more reveals the rest.
    final videoMatch = firstCompleteDivineVideoUrlMatch(
      safeMessage,
      contentIsTruncated: isTruncated,
    );
    final videoTarget = resolveDmVideoTarget(
      content: safeMessage,
      sharedVideoRef: sharedVideoRef,
      contentIsTruncated: isTruncated,
    );

    final String? personalMessage;
    final String? textAfterUrl;
    if (videoMatch != null) {
      // The first-party share template is:
      //   [optional personal note]
      //   <blank line>
      //   "<video title>"
      //   <blank line>
      //   <URL>
      //   [optional trailing text]
      //
      // The quoted title duplicates the card footer, so it is stripped.
      // Everything else around the URL remains the sender's message.
      final afterLines = safeMessage
          .substring(videoMatch.end)
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .where((line) => !_nostrRefLineRegex.hasMatch(line))
          .toList();
      textAfterUrl = afterLines.isEmpty ? null : afterLines.join('\n');

      final beforeLines = safeMessage
          .substring(0, videoMatch.start)
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .where((line) => !_quotedTitleRegex.hasMatch(line))
          .where((line) => !_nostrRefLineRegex.hasMatch(line))
          .toList();
      personalMessage = beforeLines.isEmpty ? null : beforeLines.join('\n');
    } else if (videoTarget != null) {
      // Identity came from a structured citation rather than a body URL, so
      // this is not the share template: the body is only what the sender
      // typed. Strip the machine-readable citation, but keep quoted lines so
      // a sender's quoted comment is never mistaken for a template title.
      final lines = safeMessage
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .where((line) => !_nostrRefLineRegex.hasMatch(line))
          .toList();
      personalMessage = lines.isEmpty ? null : lines.join('\n');
      textAfterUrl = null;
    } else {
      personalMessage = null;
      textAfterUrl = null;
    }

    final hasQuotedVideo =
        quotedVideoRef != null && videoTarget?.stableId == null;
    final quotedReplyText = hasQuotedVideo
        ? safeMessage
              .split('\n')
              .where((line) => !_nostrRefLineRegex.hasMatch(line.trim()))
              .join('\n')
              .trim()
        : safeMessage;

    return _DmBubbleContent(
      videoTarget: videoTarget,
      personalMessage: personalMessage,
      textAfterUrl: textAfterUrl,
      quotedReplyText: quotedReplyText,
    );
  }

  final DmVideoTarget? videoTarget;
  final String? personalMessage;
  final String? textAfterUrl;
  final String quotedReplyText;
}

/// Width of the video share card thumbnail (also used to cap the
/// surrounding bubble's max width so the bubble doesn't grow wider
/// than the card when a personal note wraps below it).
const double _videoCardWidth = 248;

/// Height of the video share card thumbnail.
const double _videoCardHeight = 350;

/// Corner radius of the video share card thumbnail across all states
/// (resolved, loading, unavailable). Matches the Figma
/// `part/video thumbnail` component's radius/16.
const double _videoCardRadius = 16;

/// A single chat message bubble.
///
/// Text bubbles — sent (right-aligned): primaryAccessible background;
/// received (left-aligned): surfaceContainer background. Shared-video
/// bubbles use a neutral dark frame (neutral10) in both directions so the
/// thumbnail reads as a media card, matching the Figma
/// `part/video thumbnail` share bubble.
///
/// Grouping behaviour:
/// - Only the first message in a group shows a timestamp (inside the bubble,
///   above the message text).
/// - The last message in a group gets a small (4px) "tail" corner on the
///   sender's side (bottom-right for sent, bottom-left for received).
/// - Non-last messages have all 16px rounded corners.
///
/// URLs in message text are rendered as tappable links that open in an
/// external browser. Long-pressing the bubble triggers [onLongPress].
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    required this.message,
    required this.timestamp,
    required this.isSent,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.onLongPress,
    this.onDoubleTap,
    this.onTap,
    this.deliveryStatus = DmDeliveryStatus.delivered,
    this.retractionStatus = DmRetractionStatus.none,
    this.dmReplyContext,
    this.sharedVideoRef,
    this.quotedVideoRef,
    super.key,
  });

  final String message;
  final String timestamp;
  final bool isSent;

  /// Whether this is the first (topmost) message in a consecutive group
  /// from the same sender.  When true the timestamp is displayed.
  final bool isFirstInGroup;

  /// Whether this is the last (bottommost) message in a consecutive group
  /// from the same sender.  When true the tail corner is rendered.
  final bool isLastInGroup;

  /// Called when the user long-presses the bubble.
  final VoidCallback? onLongPress;

  /// Called when the user double-taps the bubble. Wired to double-tap-to-like,
  /// which adds a ❤️ reaction to the message. Null disables double-tap on the
  /// bubble (e.g. failed own sends). It is also suppressed internally on
  /// bubbles whose dominant content is itself a tap target (shared-video card,
  /// quoted-video reply) so the ancestor double-tap recognizer can't delay
  /// tap-to-open, and on truncated bubbles so their Show more / Show less
  /// links open on the first tap — see the wiring below. Screen readers
  /// never reach this — double-tap is the AT activation gesture — so the
  /// long-press picker stays the a11y path.
  final VoidCallback? onDoubleTap;

  /// Called when the user taps the bubble. Wired only for failed own sends
  /// (opens the resend/delete snackbar); null for every other bubble so a
  /// normal message keeps its default tap behaviour.
  final VoidCallback? onTap;

  /// Per-bubble delivery state. Only rendered for sent messages; received
  /// bubbles ignore it. Defaults to [DmDeliveryStatus.delivered] so test
  /// fixtures and call sites that don't track outgoing-queue state work
  /// without churn.
  final DmDeliveryStatus deliveryStatus;

  /// State of this own message's delete-for-everyone delivery.
  final DmRetractionStatus retractionStatus;

  /// Context for the in-player reply/reaction bar, used when this bubble's
  /// shared reel is tapped open. Null in non-DM call sites / tests.
  final DmReplyContext? dmReplyContext;

  /// Structured q-tag video reference parsed from the DM rumor, when present.
  /// Drives the message's OWN full share card. Mutually exclusive with
  /// [quotedVideoRef] — the call site passes one or the other.
  final DmSharedVideoRef? sharedVideoRef;

  /// Structured reference to the video this message *replies to*, when the
  /// message is a reply to a shared-reel DM. Renders a compact WhatsApp-style
  /// quoted preview above the reply text (distinct from the full [sharedVideoRef]
  /// card). Null for non-reply messages.
  final DmSharedVideoRef? quotedVideoRef;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late int _visibleCodeUnitLimit;
  late DmDisplayTextSlice _displaySlice;
  late _DmBubbleContent _content;

  String get timestamp => widget.timestamp;
  bool get isSent => widget.isSent;
  bool get isFirstInGroup => widget.isFirstInGroup;
  bool get isLastInGroup => widget.isLastInGroup;
  VoidCallback? get onLongPress => widget.onLongPress;
  VoidCallback? get onDoubleTap => widget.onDoubleTap;
  VoidCallback? get onTap => widget.onTap;
  DmDeliveryStatus get deliveryStatus => widget.deliveryStatus;
  DmRetractionStatus get retractionStatus => widget.retractionStatus;
  DmReplyContext? get dmReplyContext => widget.dmReplyContext;
  DmSharedVideoRef? get sharedVideoRef => widget.sharedVideoRef;
  DmSharedVideoRef? get quotedVideoRef => widget.quotedVideoRef;

  @override
  void initState() {
    super.initState();
    _visibleCodeUnitLimit = dmInitialDisplayCodeUnits;
    _refreshContent();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.sharedVideoRef != widget.sharedVideoRef ||
        oldWidget.quotedVideoRef != widget.quotedVideoRef) {
      _visibleCodeUnitLimit = dmInitialDisplayCodeUnits;
      _refreshContent();
    }
  }

  void _refreshContent() {
    _displaySlice = sliceDmDisplayText(
      widget.message,
      _visibleCodeUnitLimit,
    );
    _content = _DmBubbleContent.parse(
      _displaySlice.text,
      sharedVideoRef: widget.sharedVideoRef,
      quotedVideoRef: widget.quotedVideoRef,
      isTruncated: _displaySlice.hasMore,
    );
  }

  void _showMore() {
    setState(() {
      _visibleCodeUnitLimit =
          (_visibleCodeUnitLimit + dmDisplayIncrementCodeUnits).clamp(
            0,
            dmMaxDisplayCodeUnits,
          );
      _refreshContent();
    });
  }

  void _showLess() {
    setState(() {
      _visibleCodeUnitLimit = dmInitialDisplayCodeUnits;
      _refreshContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final videoStableId = _content.videoTarget?.stableId;
    final videoAuthorPubkey = _content.videoTarget?.authorPubkey;
    final videoKind = _content.videoTarget?.videoKind;
    final personalMessage = _content.personalMessage;
    final textAfterUrl = _content.textAfterUrl;

    // Video shares are always rendered as standalone blocks: the
    // thumbnail is too prominent to share a tail with an adjacent text
    // bubble from the same sender. Force first-and-last-in-group so
    // they get their own timestamp header, the tail corner on the
    // sender's side, and the full 8 px outer padding above and below.
    final hasVideo = videoStableId != null;
    final effectiveIsFirstInGroup = hasVideo || isFirstInGroup;
    final effectiveIsLastInGroup = hasVideo || isLastInGroup;

    // A reply that references a video (but doesn't itself render a full card)
    // shows a compact quoted preview above its text. Strip the trailing
    // machine-readable `nostr:` citation line the reply carries on the wire so
    // only the user's comment renders below the quote.
    final hasQuotedVideo = quotedVideoRef != null && !hasVideo;
    final quotedReplyText = _content.quotedReplyText;
    final hasExpansionControls =
        _displaySlice.hasMore ||
        _visibleCodeUnitLimit > dmInitialDisplayCodeUnits;

    // A hard-failed own send routes every tap to the outer resend/delete
    // affordance (long-press deliberately offers no resend — see
    // conversation_view.dart). The shared-video card and quoted-video frame
    // each own an unconditional tap-to-open recognizer that would otherwise
    // win the gesture arena over the card's dominant surface and swallow that
    // sole resend affordance, so their taps are disabled on a failed own send.
    final isFailedOwnSend = isSent && deliveryStatus == DmDeliveryStatus.failed;
    final isBlockedOwnSend =
        isSent && deliveryStatus == DmDeliveryStatus.blocked;
    final hasUnconfirmedRetraction =
        isSent && retractionStatus != DmRetractionStatus.none;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: effectiveIsFirstInGroup ? 8 : 2,
        bottom: effectiveIsLastInGroup ? 8 : 2,
      ),
      child: Align(
        alignment: isSent
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Semantics(
          hint: isSent
              ? context.l10n.dmMessageBubbleSentHint
              : context.l10n.dmMessageBubbleReceivedHint,
          // The tap affordance is otherwise invisible to assistive tech, so
          // key the button semantics off it. Two different sheets hang off
          // this one callback: any unconfirmed retraction — pending or
          // failed — opens the retraction sheet, whose action is Try again,
          // while every other wired case opens resend/delete. The hint has
          // to say which.
          button: onTap != null,
          onTapHint: onTap == null
              ? null
              : retractionStatus != DmRetractionStatus.none
              ? context.l10n.authTryAgain
              : context.l10n.dmMessageBubbleFailedTapHint,
          onLongPressHint: onLongPress != null
              ? context.l10n.dmMessageBubbleLongPressHint
              : null,
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            // Suppress double-tap-to-like on bubbles whose dominant content is
            // itself a tap target — the shared-video card and the quoted-video
            // reply both open the reel on tap. An ancestor onDoubleTap makes
            // its DoubleTapGestureRecognizer hold the gesture arena for
            // ~kDoubleTapTimeout after the first tap, so the inner onTap only
            // fires once that window elapses (~300 ms delay to tap-to-open).
            // A truncated bubble gives it up for the same reason: its Show
            // more / Show less links must open on the first tap. Plain text
            // bubbles keep double-tap-to-like.
            onDoubleTap: hasVideo || hasQuotedVideo || hasExpansionControls
                ? null
                : onDoubleTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  // Deliberately NOT dimmed for an unconfirmed retraction.
                  // `Opacity` here composites the text and its own fill toward
                  // the page together, so the ratio between them collapses:
                  // white on primaryAccessible measures 3.17:1 at full
                  // opacity and 1.94:1 at 0.55 over the light message list.
                  // Any dimming makes an already-marginal pair worse, so the
                  // state is carried by [_RetractionIndicator] and its
                  // semantics instead of by contrast.
                  child: Container(
                    // Video bubbles cap their max width at the thumbnail's
                    // own width (248) plus the symmetric 16 px padding so the
                    // bubble doesn't grow wider than the card when a personal
                    // message wraps below it. Text-only bubbles stay at the
                    // chat-typical 75 % of screen width.
                    constraints: BoxConstraints(
                      maxWidth: hasVideo
                          ? _videoCardWidth + 32
                          : MediaQuery.sizeOf(context).width * 0.75,
                    ),
                    // Both text and video bubbles use 16 px horizontal / 12 px
                    // vertical padding (Figma spacing/16 + spacing/12) so the
                    // thumbnail and text sit in the same frame rhythm.
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      // Shared-video bubbles sit on a neutral frame in both
                      // directions so the thumbnail reads as a media card rather
                      // than a bright accent pill — matching the Figma
                      // `part/video thumbnail` share bubble.
                      // Text bubbles keep the sent/received accent split.
                      color: hasVideo
                          ? context.vineColors.mediaCard
                          : isSent
                          ? VineTheme.primaryAccessible
                          : context.vineColors.surfaceContainer,
                      borderRadius: _borderRadiusFor(effectiveIsLastInGroup),
                    ),
                    child: Column(
                      crossAxisAlignment: isSent
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (effectiveIsFirstInGroup)
                          Padding(
                            // Video messages need a bigger breath between the
                            // date header and the thumbnail; text messages
                            // keep the tighter 4 px rhythm.
                            padding: EdgeInsets.only(bottom: hasVideo ? 12 : 4),
                            child: Text(
                              timestamp,
                              style: VineTheme.labelSmallFont(
                                color: context.vineColors.onSurfaceMuted,
                              ),
                            ),
                          ),
                        if (videoStableId != null) ...[
                          _VideoLinkPreview(
                            videoStableId: videoStableId,
                            authorPubkey: videoAuthorPubkey,
                            videoKind: videoKind,
                            isSent: isSent,
                            enableTap: !isFailedOwnSend,
                            dmReplyContext: dmReplyContext,
                          ),
                          // Optional personal note (text before the URL minus
                          // the quoted title) sits directly under the
                          // thumbnail, inside the same bubble pill.
                          if (personalMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _MessageText(
                                message: personalMessage,
                                isSent: isSent,
                                dmReplyContext: dmReplyContext,
                              ),
                            ),
                          if (textAfterUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _MessageText(
                                message: textAfterUrl,
                                isSent: isSent,
                                dmReplyContext: dmReplyContext,
                              ),
                            ),
                        ] else ...[
                          if (hasQuotedVideo)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: quotedReplyText.isEmpty ? 0 : 6,
                              ),
                              child: _QuotedVideoPreview(
                                quotedVideoRef: quotedVideoRef!,
                                isSent: isSent,
                                enableTap: !isFailedOwnSend,
                                dmReplyContext: dmReplyContext,
                              ),
                            ),
                          if (quotedReplyText.isNotEmpty)
                            _MessageText(
                              message: quotedReplyText,
                              isSent: isSent,
                              dmReplyContext: dmReplyContext,
                            ),
                        ],
                        if (hasExpansionControls)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _MessageExpansionControls(
                              isSent: isSent,
                              canShowMore:
                                  _displaySlice.hasMore &&
                                  _visibleCodeUnitLimit < dmMaxDisplayCodeUnits,
                              canShowLess:
                                  _visibleCodeUnitLimit >
                                  dmInitialDisplayCodeUnits,
                              reachedHardLimit:
                                  _displaySlice.hasMore &&
                                  _visibleCodeUnitLimit >=
                                      dmMaxDisplayCodeUnits,
                              onShowMore: _showMore,
                              onShowLess: _showLess,
                            ),
                          ),
                        // Sends are optimistic: pending / delivered / self-wrap
                        // states show nothing — the message just looks sent. Only a
                        // hard failure surfaces, as an in-bubble "Not delivered" row
                        // (the whole bubble is tappable to resend or delete).
                        if (isFailedOwnSend)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: _NotDeliveredIndicator(),
                          ),
                        if (isBlockedOwnSend)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: _BlockedDeliveryIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),
                if (hasUnconfirmedRetraction)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 6,
                      bottom: 8,
                    ),
                    child: _RetractionIndicator(status: retractionStatus),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BorderRadius _borderRadiusFor(bool lastInGroup) {
    if (!lastInGroup) {
      return BorderRadius.circular(16);
    }
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isSent ? 16 : 4),
      bottomRight: Radius.circular(isSent ? 4 : 16),
    );
  }
}

class _MessageExpansionControls extends StatelessWidget {
  const _MessageExpansionControls({
    required this.isSent,
    required this.canShowMore,
    required this.canShowLess,
    required this.reachedHardLimit,
    required this.onShowMore,
    required this.onShowLess,
  });

  final bool isSent;
  final bool canShowMore;
  final bool canShowLess;
  final bool reachedHardLimit;
  final VoidCallback onShowMore;
  final VoidCallback onShowLess;

  @override
  Widget build(BuildContext context) {
    // The sent bubble keeps the fixed primaryAccessible green, where the
    // accent green measures 1.4:1 — invisible. Mirror [_MessageText]'s link
    // rule: white on sent bubbles, the palette accent on received ones.
    final actionStyle = VineTheme.bodySmallFont(
      color: isSent ? VineTheme.whiteText : context.vineColors.accentPositive,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          children: [
            if (canShowMore)
              _MessageExpansionAction(
                label: context.l10n.profileShowMore,
                style: actionStyle,
                onTap: onShowMore,
              ),
            if (canShowLess)
              _MessageExpansionAction(
                label: context.l10n.profileShowLess,
                style: actionStyle,
                onTap: onShowLess,
              ),
          ],
        ),
        if (reachedHardLimit)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.l10n.dmMessageDisplayLimitReached,
              style: VineTheme.bodySmallFont(
                color: isSent
                    ? VineTheme.whiteText.withValues(alpha: 0.7)
                    : context.vineColors.onSurfaceMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageExpansionAction extends StatelessWidget {
  const _MessageExpansionAction({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          // 48 dp on both axes: the label alone is about 24 px tall, and a
          // two-character locale (ko, zh) draws it about 24 px wide.
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Text(label, style: style),
          ),
        ),
      ),
    );
  }
}

/// Compact status beside an own bubble whose retraction is not confirmed.
class _RetractionIndicator extends StatelessWidget {
  const _RetractionIndicator({required this.status});

  final DmRetractionStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      DmRetractionStatus.none => const SizedBox.shrink(),
      // The spinner is the only visual signal that a retraction is in flight,
      // so without a label the state is conveyed to sighted users alone.
      DmRetractionStatus.pending => SizedBox.square(
        dimension: 16,
        child: DivineCircularProgressIndicator(
          strokeWidth: 2,
          semanticsLabel: context.l10n.dmDeletePendingLabel,
        ),
      ),
      DmRetractionStatus.failed => Semantics(
        label: context.l10n.dmDeleteRefusedMessage,
        child: const DivineIcon(
          icon: DivineIconName.warningCircle,
          size: 18,
          color: VineTheme.error,
        ),
      ),
    };
  }
}

/// Renders message text with inline markdown (bold / italic / strike /
/// inline code / `[label](url)`) plus clickable URLs and Nostr
/// references.
///
/// Markdown parsing produces an AST; plain leaves are delegated to
/// [LinkifiedTextSpanBuilder] so URLs / @mentions / #hashtags / nostr
/// references inside, e.g., a `**bold**` run remain tappable.
class _MessageText extends ConsumerStatefulWidget {
  const _MessageText({
    required this.message,
    required this.isSent,
    this.dmReplyContext,
  });

  final String message;
  final bool isSent;
  final DmReplyContext? dmReplyContext;

  @override
  ConsumerState<_MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends ConsumerState<_MessageText> {
  final _markdownParser = MemoizedInlineMarkdownParser();
  List<InlineSpan> _currentSpans = const [];

  @override
  Widget build(BuildContext context) {
    // Sent bubbles keep the fixed primaryAccessible green in both appearance
    // modes, so their text stays white; received bubbles sit on the themed
    // surfaceContainer and follow the palette.
    final defaultStyle = VineTheme.bodyMediumFont(
      color: widget.isSent ? VineTheme.whiteText : context.vineColors.onSurface,
    );
    // The primary green reads cleanly on the received bubble; on the sent
    // bubble it would sit green-on-green, so links there stay white.
    final linkColor = widget.isSent
        ? VineTheme.whiteText
        : context.vineColors.accentPositive;
    final referenceStyle = defaultStyle.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );
    // The sent bubble keeps the fixed green, so a translucent white wash
    // reads there; the received bubble follows the palette and takes an
    // on-surface wash so the code chip stays visible in both modes.
    final codeBackground = widget.isSent
        ? VineTheme.whiteText.withValues(alpha: 0.18)
        : context.vineColors.onSurface.withValues(alpha: 0.10);
    final codeStyle = VineTheme.codeFont(color: defaultStyle.color);

    final ast = _markdownParser.parse(widget.message);
    // The heart budget spans the whole message: each markdown leaf below
    // builds its own linkifier, so a per-leaf cap would reset on every
    // emphasis boundary (`**x**<heart>` x N would paint N SVG widgets).
    var heartBudget = kDivineHeartMaxPainted;
    final builder = MarkdownTextSpanBuilder(
      defaultStyle: defaultStyle,
      codeStyle: codeStyle,
      codeBackgroundColor: codeBackground,
      linkStyle: referenceStyle,
      buildPlainSpans: (text, effectiveStyle) {
        final run = _buildLinkifiedPlain(
          text,
          effectiveStyle,
          referenceStyle,
          heartBudget,
        );
        heartBudget -= run.whereType<WidgetSpan>().length;
        return run;
      },
      onLinkTap: (rawUrl) => _openLink(context, rawUrl),
    );
    final spans = builder.build(ast);
    _replaceCurrentSpans(spans);

    if (spans.isEmpty) {
      return Text(widget.message, style: defaultStyle);
    }
    return Text.rich(TextSpan(children: spans));
  }

  /// Delegates plain markdown leaves to [LinkifiedTextSpanBuilder] so
  /// the linkifier's URL / @mention / #hashtag / nostr-ref pipeline
  /// runs inside markdown wrappers.
  ///
  /// [heartBudget] is the message-wide cap on painted brand hearts, shared
  /// across leaves by the caller.
  List<InlineSpan> _buildLinkifiedPlain(
    String text,
    TextStyle plainStyle,
    TextStyle linkStyle,
    int heartBudget,
  ) {
    if (text.isEmpty) return const [];
    // Apply the surrounding emphasis to linked / mentioned tokens too
    // so `**check @alice**` renders the mention in bold + reference
    // color.
    final emphasizedLink = linkStyle.copyWith(
      fontWeight: plainStyle.fontWeight,
      fontStyle: plainStyle.fontStyle,
      decoration:
          plainStyle.decoration == null ||
              plainStyle.decoration == TextDecoration.none
          ? linkStyle.decoration
          : TextDecoration.combine([
              linkStyle.decoration ?? TextDecoration.none,
              plainStyle.decoration!,
            ]),
    );
    return LinkifiedTextSpanBuilder(
      text: text,
      defaultStyle: plainStyle,
      linkStyle: emphasizedLink,
      mentionStyle: emphasizedLink,
      initialHeartBudget: heartBudget,
      videoLabel: Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      )?.clickableTextViewVideoLink,
      profileLabelForHex: _profileDisplayText,
      onHashtagTap: _navigateToHashtag,
      onProfileTap: _navigateToProfile,
      onVideoTap: _navigateToVideo,
      onMentionTap: _navigateToSearch,
      onUrlTap: (rawUrl) => _openLink(context, rawUrl),
    ).build();
  }

  String _profileDisplayText(String hexPubkey) {
    return LinkifiedTextSupport.profileDisplayText(ref, hexPubkey);
  }

  void _navigateToHashtag(String hashtag) {
    context.push(HashtagScreenRouter.pathForTag(hashtag));
  }

  void _navigateToProfile(String hexPubkey) {
    context.pushOtherProfile(hexPubkey);
  }

  void _navigateToVideo(String routeReference) {
    final dmReplyContext = widget.dmReplyContext;
    context.push(
      VideoDetailScreen.pathForId(routeReference),
      extra: dmReplyContext != null
          ? VideoDetailRouteExtra(dmReplyContext: dmReplyContext)
          : null,
    );
  }

  void _navigateToSearch(String username) {
    context.push(
      SearchResultsPage.pathForQuery(username, requestFocusOnMount: false),
    );
  }

  void _replaceCurrentSpans(List<InlineSpan> spans) {
    final previousSpans = _currentSpans;
    _currentSpans = spans;
    LinkifiedTextSupport.disposeSpans(previousSpans);
  }

  @override
  void dispose() {
    LinkifiedTextSupport.disposeSpans(_currentSpans);
    super.dispose();
  }

  Future<void> _openLink(BuildContext context, String link) =>
      openExternalLink(context, link);
}

/// Inline video preview card for `divine.video/video/{stableId}` links.
///
/// Creates a [VideoLinkPreviewCubit] via [BlocProvider] to resolve the video
/// and renders state via [BlocBuilder]. Falls back to a tappable link when
/// the video cannot be resolved.
class _VideoLinkPreview extends ConsumerWidget {
  const _VideoLinkPreview({
    required this.videoStableId,
    required this.isSent,
    required this.enableTap,
    this.authorPubkey,
    this.videoKind,
    this.dmReplyContext,
  });

  final String videoStableId;
  final bool isSent;

  /// Whether the resolved [_VideoCard] opens the reel on tap. False on a
  /// failed own send so the outer bubble's resend affordance owns the tap.
  final bool enableTap;
  final String? authorPubkey;
  final int? videoKind;
  final DmReplyContext? dmReplyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-key on the repository identity: videosRepositoryProvider yields a
    // fresh instance when filter/aspect/host preferences change, and a bare
    // ref.read inside create: would keep the stale one for the cubit's life.
    final videosRepository = ref.watch(videosRepositoryProvider);
    return BlocProvider(
      key: ValueKey(videosRepository),
      create: (_) => VideoLinkPreviewCubit(
        videoStableId: videoStableId,
        videosRepository: videosRepository,
        authorPubkey: authorPubkey,
        videoKind: videoKind,
      ),
      child: BlocBuilder<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        builder: (context, state) => switch (state) {
          VideoLinkPreviewLoading() => _buildLoadingPlaceholder(context),
          VideoLinkPreviewNotFound() => const _VideoUnavailableCard(),
          VideoLinkPreviewResolved(:final video) => _VideoCard(
            video: video,
            enableTap: enableTap,
            dmReplyContext: dmReplyContext,
          ),
        },
      ),
    );
  }

  static Widget _buildLoadingPlaceholder(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_videoCardRadius),
      child: Container(
        width: _videoCardWidth,
        height: _videoCardHeight,
        color: context.vineColors.card,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: DivineCircularProgressIndicator(
              strokeWidth: 2,
              color: context.vineColors.accentPositive,
            ),
          ),
        ),
      ),
    );
  }
}

/// Thumbnail width of the compact quoted-reply preview.
const double _quotedThumbWidth = 40;

/// Thumbnail height of the compact quoted-reply preview.
const double _quotedThumbHeight = 56;

/// Corner radius of the compact quoted-reply thumbnail.
const double _quotedThumbRadius = 6;

/// Fixed overall width of the compact quoted-reply preview. Pinning it keeps
/// the bubble from reflowing when the cited video resolves out of its loading
/// skeleton — the loading, resolved, and unavailable states all render at this
/// width, so there is no horizontal jump as the reel loads.
const double _quotedPreviewWidth = 200;

/// Diameter of the compact quoted-thumbnail play badge. Smaller than the shared
/// [VideoThumbnailWidget] default so it reads as a neat chip with margin on the
/// 40-wide thumb.
const double _quotedPlayBadgeSize = 22;

/// Play-glyph diameter inside the badge, inset from the badge edge so the
/// triangle keeps visible padding within the chip.
const double _quotedPlayGlyphSize = 11;

/// Compact WhatsApp-style quoted preview of the video a reply references.
///
/// Reuses the [VideoLinkPreviewCubit] resolve harness so it can render even
/// when the cited video was never seen locally, and swaps
/// the full [_VideoCard] for a small thumbnail + label strip rendered above the
/// reply text.
class _QuotedVideoPreview extends ConsumerWidget {
  const _QuotedVideoPreview({
    required this.quotedVideoRef,
    required this.isSent,
    required this.enableTap,
    this.dmReplyContext,
  });

  final DmSharedVideoRef quotedVideoRef;
  final bool isSent;

  /// Whether the resolved [_QuotedVideoCard] opens the cited reel on tap.
  /// False on a failed own send so the outer bubble's resend tap wins.
  final bool enableTap;
  final DmReplyContext? dmReplyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = resolveDmVideoTarget(
      content: '',
      sharedVideoRef: quotedVideoRef,
    );
    if (target == null) return const SizedBox.shrink();
    final videosRepository = ref.watch(videosRepositoryProvider);
    return BlocProvider(
      key: ValueKey(videosRepository),
      create: (_) => VideoLinkPreviewCubit(
        videoStableId: target.stableId,
        videosRepository: videosRepository,
        authorPubkey: target.authorPubkey,
        videoKind: target.videoKind,
      ),
      child: BlocBuilder<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        builder: (context, state) => switch (state) {
          VideoLinkPreviewLoading() => _QuotedVideoLoading(isSent: isSent),
          VideoLinkPreviewNotFound() => _QuotedVideoUnavailable(isSent: isSent),
          VideoLinkPreviewResolved(:final video) => _QuotedVideoCard(
            video: video,
            isSent: isSent,
            enableTap: enableTap,
            dmReplyContext: dmReplyContext,
          ),
        },
      ),
    );
  }
}

/// Accent-bar framed container that gives the quoted preview its WhatsApp-style
/// "reply" affordance, readable on both sent and received bubble colors.
class _QuotedVideoFrame extends StatelessWidget {
  const _QuotedVideoFrame({
    required this.isSent,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  final bool isSent;
  final Widget child;
  final VoidCallback? onTap;

  /// Screen-reader label for the tappable affordance. Only used when [onTap]
  /// is non-null (the resolved, openable card).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final accent = isSent
        ? VineTheme.whiteText
        : context.vineColors.accentPositive;
    final frame = SizedBox(
      width: _quotedPreviewWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSent
              ? VineTheme.whiteText.withValues(alpha: 0.14)
              : context.vineColors.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Padding(padding: const EdgeInsets.all(6), child: child),
      ),
    );
    if (onTap == null) return frame;
    // Co-locate the button semantics with the tap target so every tappable
    // frame is announced as a button — callers can't forget to wrap it.
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(onTap: onTap, child: frame),
    );
  }
}

/// Loading skeleton for the compact quoted preview. Mirrors the resolved
/// card's thumbnail + two-line label layout so the fixed-width frame reads as
/// content rather than an empty box while the cited reel resolves.
class _QuotedVideoLoading extends StatelessWidget {
  const _QuotedVideoLoading({required this.isSent});

  final bool isSent;

  @override
  Widget build(BuildContext context) {
    return _QuotedVideoFrame(
      isSent: isSent,
      child: Row(
        spacing: 8,
        children: [
          const _QuotedThumbPlaceholder(),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuotedSkeletonBar(widthFactor: 0.85, isSent: isSent),
                const SizedBox(height: 6),
                _QuotedSkeletonBar(widthFactor: 0.5, isSent: isSent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder sized to the compact thumbnail.
class _QuotedThumbPlaceholder extends StatelessWidget {
  const _QuotedThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _quotedThumbWidth,
      height: _quotedThumbHeight,
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(_quotedThumbRadius),
      ),
    );
  }
}

/// A single rounded skeleton bar for the quoted-preview loading state.
///
/// Sent bubbles keep the fixed green, so a translucent white fill reads
/// there; received bubbles follow the palette and take an on-surface wash.
class _QuotedSkeletonBar extends StatelessWidget {
  const _QuotedSkeletonBar({required this.widthFactor, required this.isSent});

  final double widthFactor;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: isSent
              ? VineTheme.whiteText.withValues(alpha: 0.12)
              : context.vineColors.onSurface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Resolved compact quoted preview: thumbnail + title/author, tappable to open
/// the referenced video.
class _QuotedVideoCard extends ConsumerWidget {
  const _QuotedVideoCard({
    required this.video,
    required this.isSent,
    required this.enableTap,
    this.dmReplyContext,
  });

  final VideoEvent video;
  final bool isSent;

  /// When false (a failed own send) the frame is rendered with no tap
  /// recognizer and no button semantics, so the outer bubble's resend tap
  /// wins and assistive tech stops announcing a dead "open video" action.
  final bool enableTap;
  final DmReplyContext? dmReplyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = video.title;
    final hasTitle = title != null && title.isNotEmpty;
    final profileAsync = ref.watch(userProfileReactiveProvider(video.pubkey));
    final authorName = switch (profileAsync) {
      AsyncData(:final value) when value != null => value.bestDisplayName,
      AsyncData() ||
      AsyncError() => UserProfile.defaultDisplayNameFor(video.pubkey),
      AsyncLoading() => null,
    };
    final primaryColor = isSent
        ? VineTheme.whiteText
        : context.vineColors.onSurface;
    final secondaryColor = isSent
        ? VineTheme.whiteText.withValues(alpha: 0.7)
        : context.vineColors.onSurfaceMuted;
    final primaryLabel = hasTitle ? title : (authorName ?? '');
    final showSecondary =
        hasTitle && authorName != null && authorName.isNotEmpty;

    return _QuotedVideoFrame(
      isSent: isSent,
      semanticLabel: enableTap
          ? context.l10n.dmMessageBubbleVideoReplyHint
          : null,
      onTap: enableTap
          ? () => context.push(
              VideoDetailScreen.pathForId(video.id),
              extra: VideoDetailRouteExtra(
                initialVideo: video,
                dmReplyContext: dmReplyContext,
              ),
            )
          : null,
      child: Row(
        spacing: 8,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_quotedThumbRadius),
            // VideoThumbnailWidget renders an AspectRatio internally, so it
            // must be externally bounded (like the full _VideoCard's SizedBox)
            // — its own width/height params only size the inner image. The
            // compact play badge is overlaid here (rather than via
            // showPlayIcon) so it stays visible on dark thumbnails.
            child: SizedBox(
              width: _quotedThumbWidth,
              height: _quotedThumbHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumbnailWidget(video: video),
                  const Center(child: _QuotedPlayBadge()),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.labelSmallFont(color: primaryColor),
                ),
                if (showSecondary)
                  Text(
                    authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodySmallFont(color: secondaryColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact play badge centered on the quoted-reply thumbnail. The translucent
/// dark disc reads on light thumbnails; the hairline light ring keeps the chip
/// visible on dark thumbnails, where a translucent-black disc would otherwise
/// vanish into the content.
class _QuotedPlayBadge extends StatelessWidget {
  const _QuotedPlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _quotedPlayBadgeSize,
      height: _quotedPlayBadgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(
          color: VineTheme.whiteText.withValues(alpha: 0.9),
          width: 1.5,
        ),
      ),
      child: const DivineIcon(
        icon: DivineIconName.play,
        color: VineTheme.primaryText,
        size: _quotedPlayGlyphSize,
      ),
    );
  }
}

/// Compact non-tappable chip shown when the referenced video can't be resolved.
class _QuotedVideoUnavailable extends StatelessWidget {
  const _QuotedVideoUnavailable({required this.isSent});

  final bool isSent;

  @override
  Widget build(BuildContext context) {
    final color = isSent
        ? VineTheme.whiteText
        : context.vineColors.onSurfaceMuted;
    return _QuotedVideoFrame(
      isSent: isSent,
      child: Row(
        spacing: 8,
        children: [
          DivineIcon(
            icon: DivineIconName.warningCircle,
            color: color,
            size: 16,
          ),
          Expanded(
            child: Text(
              context.l10n.notificationsVideoUnavailable,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.bodySmallFont(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-tappable placeholder shown when a shared video can't be resolved
/// (deleted, blocked, or unreachable). Deliberately has no tap target so a
/// dead reel can never open the player or a reply bar.
class _VideoUnavailableCard extends StatelessWidget {
  const _VideoUnavailableCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_videoCardRadius),
      child: Container(
        width: _videoCardWidth,
        height: _videoCardHeight,
        color: context.vineColors.card,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DivineIcon(
              icon: DivineIconName.warningCircle,
              color: context.vineColors.onSurfaceMuted,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.notificationsVideoUnavailable,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable 248×350 card showing a video thumbnail with the title and loop
/// count rendered inside a gradient overlay footer. Mirrors the
/// `part/video thumbnail` Figma component used elsewhere in the app.
class _VideoCard extends ConsumerWidget {
  const _VideoCard({
    required this.video,
    required this.enableTap,
    this.dmReplyContext,
  });

  final VideoEvent video;

  /// When false (a failed own send) the card registers no tap recognizer, so
  /// the outer bubble's resend/delete tap wins the gesture arena and assistive
  /// tech stops announcing a dead "open video" action.
  final bool enableTap;
  final DmReplyContext? dmReplyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = video.title;
    final loops = video.totalLoops;
    final hasTitle = title != null && title.isNotEmpty;
    final hasLoops = loops > 0;
    final profileAsync = ref.watch(userProfileReactiveProvider(video.pubkey));
    final authorName = switch (profileAsync) {
      AsyncData(:final value) when value != null => value.bestDisplayName,
      AsyncData() ||
      AsyncError() => UserProfile.defaultDisplayNameFor(video.pubkey),
      AsyncLoading() => null,
    };
    final hasAuthor = authorName != null && authorName.isNotEmpty;
    return GestureDetector(
      onTap: enableTap
          ? () => context.push(
              VideoDetailScreen.pathForId(video.id),
              extra: VideoDetailRouteExtra(
                initialVideo: video,
                dmReplyContext: dmReplyContext,
              ),
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_videoCardRadius),
        child: SizedBox(
          width: _videoCardWidth,
          height: _videoCardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoThumbnailWidget(video: video),
              if (hasAuthor || hasTitle || hasLoops)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    // Soft bottom-of-thumbnail fade matching the home
                    // feed video overlay: transparent → 50 %
                    // VineTheme.backgroundColor. Top padding is
                    // intentionally large so the gradient has room to
                    // ease in over the thumbnail before reaching the
                    // text — without it the fade would only span the
                    // single line of label height and look abrupt.
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          VineTheme.backgroundColor.withValues(alpha: 0),
                          VineTheme.backgroundColor.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasAuthor)
                            Text(
                              authorName,
                              // Mirrors the Explore > New grid creator
                              // style: titleTinyFont (Bricolage Grotesque
                              // 12 px / w800) with a subtle legibility
                              // shadow, no underline.
                              style:
                                  VineTheme.titleTinyFont(
                                    color: VineTheme.whiteText,
                                  ).copyWith(
                                    decoration: TextDecoration.none,
                                    shadows: const [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 2,
                                        color: VineTheme.scrim15,
                                      ),
                                    ],
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (hasTitle) ...[
                            if (hasAuthor) const SizedBox(height: 4),
                            Text(
                              title,
                              style: VineTheme.labelMediumFont(
                                color: VineTheme.whiteText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (hasLoops) ...[
                            if (hasAuthor || hasTitle)
                              const SizedBox(height: 4),
                            Text(
                              context.l10n.videoFeedLoopCountLine(
                                StringUtils.formatCompactNumber(loops),
                                loops,
                              ),
                              style: VineTheme.bodySmallFont(
                                color: VineTheme.whiteText,
                              ),
                            ),
                          ],
                        ],
                      ),
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

/// Small trailing icon at the bottom of a sent bubble that surfaces
/// The in-bubble "Not delivered" affordance for a hard-failed own send.
///
/// Sends are optimistic, so ordinary pending, delivered, and self-wrap-failed
/// states render as a plain sent message. The enclosing failed bubble is
/// tappable to resend or delete; a terminal blocked bubble uses the distinct
/// [_BlockedDeliveryIndicator].
class _NotDeliveredIndicator extends StatelessWidget {
  const _NotDeliveredIndicator();

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.dmStatusFailed;
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            size: 14,
            color: VineTheme.error,
          ),
          Text(label, style: VineTheme.labelSmallFont(color: VineTheme.error)),
        ],
      ),
    );
  }
}

/// The in-bubble terminal status for a send retained on a closed thread.
class _BlockedDeliveryIndicator extends StatelessWidget {
  const _BlockedDeliveryIndicator();

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.dmSendBlockedRetiredMessage;
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            size: 14,
            color: VineTheme.error,
          ),
          Flexible(
            child: Text(
              label,
              style: VineTheme.labelSmallFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
