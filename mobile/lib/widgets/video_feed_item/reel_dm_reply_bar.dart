// ABOUTME: In-player reply/reaction bar shown when a reel is opened from a DM.
// ABOUTME: Text replies thread under the reel; quick emojis are cap-at-one
// ABOUTME: reactions (throttled). Reuses the DM reaction stack + composer style.

import 'dart:async';
import 'dart:math' as math;

import 'package:analytics/analytics.dart';
import 'package:collection/collection.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show DmReactionPublishStatus;
import 'package:openvine/blocs/dm/dm_thread_writability.dart';
import 'package:openvine/blocs/dm/inline_reel_reply/inline_reel_reply_cubit.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/conversation/widgets/full_reaction_emoji_picker_sheet.dart';
import 'package:openvine/screens/inbox/conversation/widgets/reaction_picker_overlay.dart'
    show kDefaultDmReactionEmojis;

/// Constants for the reel reply bar.
abstract class ReelReplyConstants {
  /// Minimum gap between reaction publishes; rapid taps coalesce to the last.
  static const reactionThrottle = Duration(seconds: 1);

  /// Quick-reaction emoji set (shared with the DM thread picker).
  static const List<String> quickEmojis = kDefaultDmReactionEmojis;

  /// Analytics screen name for in-player DM reel engagement.
  static const analyticsScreen = 'dm_reel_player';
}

/// Host that provides the reply + reactions cubits keyed on their
/// identity-flippable Riverpod dependencies (per `state_management.md`), then
/// renders the bar. Scoped to the player route — NOT the conversation tree.
class ReelDmReplyBarHost extends ConsumerWidget {
  /// Construct the host for [dmReplyContext].
  const ReelDmReplyBarHost({required this.dmReplyContext, super.key});

  /// The DM the reel was opened from.
  final DmReplyContext dmReplyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(blocklistVersionProvider);
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
    final writability = resolveDmThreadWritability(
      participantPubkeys: dmReplyContext.participantPubkeys,
      isBlockedByUs: blocklistRepository.isBlocked,
    );
    if (writability != DmThreadWritability.writable) {
      return const SizedBox.shrink();
    }

    final dmRepository = ref.watch(dmRepositoryProvider);
    final reactionsRepository = ref.watch(dmReactionsRepositoryProvider);
    final ownerPubkey =
        ref.watch(authServiceProvider).currentPublicKeyHex ?? '';

    return MultiBlocProvider(
      // Record key over the captured deps: a new signer / account flips
      // identity, recreating both cubits with the fresh dependencies.
      key: ValueKey((
        dmRepository,
        reactionsRepository,
        ownerPubkey,
        dmReplyContext.conversationId,
      )),
      providers: [
        BlocProvider<InlineReelReplyCubit>(
          create: (_) => InlineReelReplyCubit(
            dmRepository: dmRepository,
            replyContext: dmReplyContext,
          ),
        ),
        BlocProvider<ConversationReactionsCubit>(
          create: (_) =>
              ConversationReactionsCubit(
                reactionsRepository: reactionsRepository,
                ownerPubkey: ownerPubkey,
              )..add(
                ConversationReactionsStarted(
                  conversationId: dmReplyContext.conversationId,
                ),
              ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final bridge = ReelReplyBridge.maybeOf(context);
          return _ReelDmReplyBar(
            dmReplyContext: dmReplyContext,
            ownerPubkey: ownerPubkey,
            screenAnalytics: ref.read(screenAnalyticsServiceProvider),
            // The player owns pausing + the full-screen reaction overlay; the
            // bar just emits the signals, staying decoupled from its State.
            onComposerFocusChanged: bridge?.setComposerFocused,
            onReaction: bridge?.playReaction,
          );
        },
      ),
    );
  }
}

/// Inherited bridge so the bar can drive player-owned behavior (pause on
/// compose, the full-screen reaction overlay) without coupling to the player's
/// private State type.
class ReelReplyBridge extends InheritedWidget {
  /// Construct the bridge.
  const ReelReplyBridge({
    required this.setComposerFocused,
    required this.playReaction,
    required super.child,
    super.key,
  });

  /// Called with `true` when the reply composer gains focus, `false` on blur.
  final ValueChanged<bool> setComposerFocused;

  /// Plays the full-screen center reaction animation for the given emoji.
  final ValueChanged<String> playReaction;

  /// The nearest bridge, or null when none is in scope.
  static ReelReplyBridge? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReelReplyBridge>();

  @override
  bool updateShouldNotify(ReelReplyBridge oldWidget) =>
      setComposerFocused != oldWidget.setComposerFocused ||
      playReaction != oldWidget.playReaction;
}

class _ReelDmReplyBar extends StatefulWidget {
  const _ReelDmReplyBar({
    required this.dmReplyContext,
    required this.ownerPubkey,
    required this.screenAnalytics,
    this.onComposerFocusChanged,
    this.onReaction,
  });

  final DmReplyContext dmReplyContext;
  final String ownerPubkey;

  /// Shared screen-analytics service, resolved by the host so this plain
  /// [StatefulWidget] does not reach into Riverpod for its dependencies.
  final ScreenAnalyticsService screenAnalytics;

  final ValueChanged<bool>? onComposerFocusChanged;

  /// Triggers the player's full-screen reaction overlay for the given emoji.
  final ValueChanged<String>? onReaction;

  @override
  State<_ReelDmReplyBar> createState() => _ReelDmReplyBarState();
}

class _ReelDmReplyBarState extends State<_ReelDmReplyBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  /// Snapshot of submit-time text so a failed send can restore the draft.
  String _pendingDraft = '';

  // Reaction throttle state (presentation-only; the cubit owns the wire).
  Timer? _throttleTimer;
  String? _coalescedEmoji;
  String? _lastDispatchedEmoji;

  /// Optimistically-selected emoji, highlighted immediately on tap.
  String? _optimisticEmoji;

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _retrySnackBarController;

  /// Whether the retry snackbar reached the front of the messenger's queue.
  ///
  /// `close()` asserts the controller it belongs to is that front entry, so one
  /// still waiting behind another snackbar must be left alone.
  bool _retrySnackBarVisible = false;

  /// Captured while mounted so the deferred close in [dispose] can check the
  /// messenger is still alive without a lookup on a defunct element.
  ScaffoldMessengerState? _messenger;

  DmReplyContext get _ctx => widget.dmReplyContext;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
    widget.screenAnalytics.trackInteraction(
      ReelReplyConstants.analyticsScreen,
      'dm_reel_opened',
      params: {'is_group': _ctx.isGroup ? 1 : 0},
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _closeRetrySnackBar(deferred: true);
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _handleFocusChanged() {
    widget.onComposerFocusChanged?.call(_focusNode.hasFocus);
  }

  void _handleSubmit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final cubit = context.read<InlineReelReplyCubit>();
    if (cubit.state.status == InlineReelReplyStatus.sending) return;
    _pendingDraft = text;
    cubit.submit(text);
    _controller.clear();
    _focusNode.unfocus();
  }

  /// The current account's active reaction emoji on the reel, if any.
  String? get _activeEmoji {
    if (_optimisticEmoji != null) return _optimisticEmoji;
    final list = context
        .read<ConversationReactionsCubit>()
        .state
        .reactionsByMessageId[_ctx.sharedReelMessageId];
    return list
        ?.firstWhereOrNull((r) => r.reactorPubkey == widget.ownerPubkey)
        ?.emoji;
  }

  void _onEmojiTap(String emoji, {bool fromPicker = false}) {
    // No-op when the active reaction already matches (set, not toggle).
    if (_activeEmoji == emoji) return;
    setState(() => _optimisticEmoji = emoji);

    if (_throttleTimer?.isActive ?? false) {
      _coalescedEmoji = emoji; // collapse rapid taps to the latest emoji
      return;
    }
    _dispatchReaction(emoji, fromPicker: fromPicker);
    _startThrottle();
  }

  void _reconcileOptimisticReaction(ConversationReactionsState state) {
    final emoji = _optimisticEmoji;
    if (emoji == null) return;

    final key = ReactionPublishKey(
      messageId: _ctx.sharedReelMessageId,
      emoji: emoji,
    );
    final localStatus = state.pending[key];
    final persisted = state.reactionsByMessageId[_ctx.sharedReelMessageId]
        ?.firstWhereOrNull((r) => r.reactorPubkey == widget.ownerPubkey);

    if (localStatus == ReactionPublishLocalStatus.failed) {
      _announce(context.l10n.dmReelReplyFailed);
      setState(() {
        _optimisticEmoji = null;
        _lastDispatchedEmoji = null;
      });
    } else if (persisted?.emoji == emoji &&
        (persisted?.publishStatus == DmReactionPublishStatus.sent ||
            persisted?.publishStatus == DmReactionPublishStatus.received)) {
      _announce(context.l10n.dmReelReactionSentAnnouncement(emoji));
      setState(() => _optimisticEmoji = null);
    }
  }

  void _startThrottle() {
    _throttleTimer?.cancel();
    _throttleTimer = Timer(ReelReplyConstants.reactionThrottle, () {
      final pending = _coalescedEmoji;
      _coalescedEmoji = null;
      if (pending != null && pending != _lastDispatchedEmoji) {
        _dispatchReaction(pending);
        _startThrottle();
      }
    });
  }

  void _dispatchReaction(String emoji, {bool fromPicker = false}) {
    _lastDispatchedEmoji = emoji;
    context.read<ConversationReactionsCubit>().add(
      ConversationReactionSet(
        conversationId: _ctx.conversationId,
        messageId: _ctx.sharedReelMessageId,
        messageAuthorPubkey: _ctx.messageAuthorPubkey,
        emoji: emoji,
      ),
    );
    if (!MediaQuery.of(context).disableAnimations) {
      widget.onReaction?.call(emoji);
    }
    widget.screenAnalytics.trackInteraction(
      ReelReplyConstants.analyticsScreen,
      'dm_reel_emoji_sent',
      params: {
        'is_group': _ctx.isGroup ? 1 : 0,
        'emoji': emoji,
        'source': fromPicker ? 'picker' : 'quick',
      },
    );
  }

  Future<void> _onMoreTap() async {
    final emoji = await FullReactionEmojiPickerSheet.show(context: context);
    if (emoji != null && mounted) {
      _onEmojiTap(emoji, fromPicker: true);
    }
  }

  void _openChat(
    GoRouter router, {
    required String conversationPath,
    required List<String> participantPubkeys,
  }) {
    router.push(conversationPath, extra: participantPubkeys);
  }

  void _onReplyOutcome(InlineReelReplyState state) {
    final draft = _pendingDraft;
    _pendingDraft = '';

    // Captured while the bar is still mounted. Snackbars are hosted by the root
    // ScaffoldMessenger, above the Navigator, so their actions can fire after
    // the player route is gone and this element is defunct.
    final cubit = context.read<InlineReelReplyCubit>();

    switch (state.status) {
      case InlineReelReplyStatus.failure:
        // The parked rows are captured HERE, bound to the send that failed.
        // This snackbar can outlive that send — queued behind another, it is
        // never dismissed by a later success, which can only close a visible
        // one — and by then `state.queuedRumorIds` describes some other send.
        _showReplyFailed(draft, cubit, state.queuedRumorIds);
      case InlineReelReplyStatus.tooLong:
        _showReplyTooLong(draft);
      case InlineReelReplyStatus.unverifiable:
        _showReplyUnverified();
      case InlineReelReplyStatus.success:
        _showReplySent();
      case InlineReelReplyStatus.initial:
      case InlineReelReplyStatus.sending:
        return;
    }
    cubit.acknowledge();
  }

  void _showReplyTooLong(String draft) {
    if (draft.isNotEmpty && _controller.text.isEmpty) {
      _controller.text = draft;
      _controller.selection = TextSelection.collapsed(offset: draft.length);
    }
    _announce(context.l10n.dmSendTooLongMessage);
    _closeRetrySnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.dmSendTooLongMessage),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showReplyFailed(
    String draft,
    InlineReelReplyCubit cubit,
    List<String> parkedRumorIds,
  ) {
    // Restore the draft so the user can retry without retyping.
    if (draft.isNotEmpty && _controller.text.isEmpty) {
      _controller.text = draft;
      _controller.selection = TextSelection.collapsed(offset: draft.length);
    }
    _announce(context.l10n.dmReelReplyFailed);
    _showRetrySnackBar(
      (markVisible) => SnackBar(
        content: Text(context.l10n.dmReelReplyFailed),
        behavior: SnackBarBehavior.floating,
        onVisible: markVisible,
        action: SnackBarAction(
          label: context.l10n.dmSendFailedRetry,
          onPressed: () {
            // `mounted` also guards `_controller`, which dispose() tears
            // down along with the rest of this State.
            if (draft.isEmpty || !mounted || cubit.isClosed) return;
            _pendingDraft = draft;
            // `retry`, never `submit`: it re-drives the durable row the
            // failed send parked, instead of minting a second rumor the
            // recipient renders as a second message (#7316). The draft is
            // only its fallback, for a send that parked no row at all.
            cubit.retry(queuedRumorIds: parkedRumorIds, content: draft);
            _controller.clear();
          },
        ),
      ),
    );
  }

  /// A retry whose parked row had already gone: delivery is unknown.
  ///
  /// Deliberately offers no Retry. The row is consumed, so a further retry
  /// would fall through to a fresh send and mint the duplicate #7316 closed —
  /// which is also why the outstanding retry snackbar has to be dismissed
  /// here rather than left holding a now-duplicating action. "View chat" is
  /// the honest affordance: it shows the user what actually landed.
  void _showReplyUnverified() {
    _announce(context.l10n.dmReelReplyUnverified);
    _closeRetrySnackBar();
    _showChatSnackBar(context.l10n.dmReelReplyUnverified);
  }

  void _showReplySent() {
    _announce(context.l10n.dmReelReplySentAnnouncement);
    widget.screenAnalytics.trackInteraction(
      ReelReplyConstants.analyticsScreen,
      'dm_reel_reply_sent',
      params: {'is_group': _ctx.isGroup ? 1 : 0},
    );
    _closeRetrySnackBar();
    _showChatSnackBar(context.l10n.shareSent);
  }

  void _showChatSnackBar(String message) {
    final router = GoRouter.maybeOf(context);
    final conversationPath = ConversationPage.pathForId(_ctx.conversationId);
    final participantPubkeys = List<String>.of(_ctx.participantPubkeys);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: router == null
            ? null
            : SnackBarAction(
                label: context.l10n.dmReelReplyViewChat,
                onPressed: () => _openChat(
                  router,
                  conversationPath: conversationPath,
                  participantPubkeys: participantPubkeys,
                ),
              ),
      ),
    );
  }

  void _showRetrySnackBar(
    SnackBar Function(VoidCallback markVisible) buildSnackBar,
  ) {
    _closeRetrySnackBar();
    late ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
    controller = ScaffoldMessenger.of(context).showSnackBar(
      buildSnackBar(() {
        if (_retrySnackBarController == controller) {
          _retrySnackBarVisible = true;
        }
      }),
    );
    _retrySnackBarController = controller;
    _retrySnackBarVisible = false;
    unawaited(
      controller.closed.then((_) {
        if (_retrySnackBarController == controller) {
          _retrySnackBarController = null;
          _retrySnackBarVisible = false;
        }
      }),
    );
  }

  /// Dismisses the retry snackbar so its now-inert CTA leaves with the bar.
  ///
  /// Left alone while it is still queued behind another snackbar: `close()`
  /// asserts it is the front of the messenger's queue, and without the assert
  /// it dismisses whichever snackbar *is* in front. The action is harmless
  /// either way — it checks `mounted` before touching anything.
  ///
  /// From [dispose] the close must be [deferred]. Under `accessibleNavigation`
  /// the messenger skips the exit animation and rebuilds synchronously, which
  /// the framework forbids while it holds the state lock to unmount us.
  void _closeRetrySnackBar({bool deferred = false}) {
    final controller = _retrySnackBarController;
    if (controller == null || !_retrySnackBarVisible) return;
    _retrySnackBarController = null;
    _retrySnackBarVisible = false;
    if (!deferred) {
      controller.close();
      return;
    }
    final messenger = _messenger;
    scheduleMicrotask(() {
      if (messenger?.mounted ?? false) controller.close();
    });
  }

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  String get _composerHint {
    if (_ctx.isOwnMessage) return context.l10n.dmReelReplyComposerHintSelf;
    if (_ctx.hintName.isEmpty) {
      return context.l10n.dmReelReplyComposerSemanticLabel;
    }
    return context.l10n.dmReelReplyComposerHint(_ctx.hintName);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<InlineReelReplyCubit, InlineReelReplyState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status &&
              (curr.status == InlineReelReplyStatus.success ||
                  curr.status == InlineReelReplyStatus.failure ||
                  curr.status == InlineReelReplyStatus.tooLong ||
                  curr.status == InlineReelReplyStatus.unverifiable),
          listener: (context, state) => _onReplyOutcome(state),
        ),
        BlocListener<ConversationReactionsCubit, ConversationReactionsState>(
          listenWhen: (prev, curr) =>
              prev.pending != curr.pending ||
              prev.reactionsByMessageId[_ctx.sharedReelMessageId] !=
                  curr.reactionsByMessageId[_ctx.sharedReelMessageId],
          listener: (context, state) => _reconcileOptimisticReaction(state),
        ),
      ],
      child: ColoredBox(
        color: context.vineColors.surface,
        child: Padding(
          // Same keyboard-inset math as InlineCommentComposerBar: the bar
          // lives in the body so it rides above the keyboard.
          padding: EdgeInsets.only(
            bottom: math.max(
              0,
              MediaQuery.viewPaddingOf(context).bottom -
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ComposerPill(
                  controller: _controller,
                  focusNode: _focusNode,
                  hasText: _hasText,
                  hint: _composerHint,
                  semanticLabel: context.l10n.dmReelReplyComposerSemanticLabel,
                  onSubmit: _handleSubmit,
                ),
                const SizedBox(height: 8),
                _QuickReactionRow(
                  emojis: ReelReplyConstants.quickEmojis,
                  activeEmoji: _activeEmojiForHighlight(),
                  moreLabel: context.l10n.dmReactionAddCustomA11yLabel,
                  onEmojiTap: _onEmojiTap,
                  onMoreTap: _onMoreTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Active emoji for the highlight ring — reads the cubit reactively so the
  /// ring follows the persisted reaction, with the optimistic value layered on.
  String? _activeEmojiForHighlight() {
    final persisted = context.select(
      (ConversationReactionsCubit c) => c
          .state
          .reactionsByMessageId[_ctx.sharedReelMessageId]
          ?.firstWhereOrNull((r) => r.reactorPubkey == widget.ownerPubkey)
          ?.emoji,
    );
    return _optimisticEmoji ?? persisted;
  }
}

/// Pill text field mirroring [InlineCommentComposerBar]'s composer geometry.
class _ComposerPill extends StatelessWidget {
  const _ComposerPill({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.hint,
    required this.semanticLabel,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final String hint;
  final String semanticLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.iconButton,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 16,
                  end: 8,
                  top: 12,
                  bottom: 12,
                ),
                child: Semantics(
                  identifier: 'reel_dm_reply_field',
                  textField: true,
                  label: semanticLabel,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSubmit(),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    cursorColor: VineTheme.tabIndicatorGreen,
                    style: VineTheme.bodyLargeFont(
                      color: context.vineColors.primaryText,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: VineTheme.bodyLargeFont(
                        color: context.vineColors.onSurfaceMuted,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
              ),
            ),
            if (hasText) _SendButton(onPressed: onSubmit),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4, bottom: 4),
      child: Semantics(
        identifier: 'reel_dm_reply_send_button',
        button: true,
        label: context.l10n.videoOverlayCommentBarSendLabel,
        child: SizedBox.square(
          dimension: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.primary,
              borderRadius: BorderRadius.circular(16.667),
            ),
            child: IconButton(
              onPressed: onPressed,
              padding: EdgeInsets.zero,
              icon: const DivineIcon(
                icon: DivineIconName.arrowUp,
                color: VineTheme.onPrimaryButton,
                size: 26.667,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal quick-reaction row of emoji buttons + a "+" picker.
class _QuickReactionRow extends StatelessWidget {
  const _QuickReactionRow({
    required this.emojis,
    required this.activeEmoji,
    required this.moreLabel,
    required this.onEmojiTap,
    required this.onMoreTap,
  });

  final List<String> emojis;
  final String? activeEmoji;
  final String moreLabel;
  final ValueChanged<String> onEmojiTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final emoji in emojis)
          _ReactionEmojiButton(
            emoji: emoji,
            isActive: emoji == activeEmoji,
            onTap: () => onEmojiTap(emoji),
          ),
        _MorePickerButton(label: moreLabel, onTap: onMoreTap),
      ],
    );
  }
}

class _ReactionEmojiButton extends StatefulWidget {
  const _ReactionEmojiButton({
    required this.emoji,
    required this.isActive,
    required this.onTap,
  });

  final String emoji;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_ReactionEmojiButton> createState() => _ReactionEmojiButtonState();
}

class _ReactionEmojiButtonState extends State<_ReactionEmojiButton>
    with SingleTickerProviderStateMixin {
  static const Duration _bounceDuration = Duration(milliseconds: 550);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _bounceDuration,
  );

  /// Soft bounce: an unhurried lift, a gentle dip just below rest, then a
  /// smooth settle. All-sine curves keep it springy without any snap.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.25,
      ).chain(CurveTween(curve: Curves.easeOutSine)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.25,
        end: 0.97,
      ).chain(CurveTween(curve: Curves.easeInOutSine)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.97,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutSine)),
      weight: 30,
    ),
  ]).animate(_controller);

  void _handleTap() {
    if (!MediaQuery.of(context).disableAnimations) {
      _controller.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.isActive,
      label: widget.emoji,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: DivineHeartText(
                widget.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MorePickerButton extends StatelessWidget {
  const _MorePickerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 48×48 tap target with a 40px visible circle + 22px glyph so the "+" reads
    // at the same weight as the bare ~28px emoji glyphs beside it.
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.vineColors.iconButton,
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: DivineIcon(
                    icon: DivineIconName.plus,
                    color: context.vineColors.onSurfaceMuted,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
