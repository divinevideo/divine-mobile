// ABOUTME: Shows the result of an outgoing video DM send as a snackbar app-wide
// ABOUTME: Sends outlive their conversation screen, so the report lives at the root

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/services/video_dm_outbox.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reports each video DM send outcome wherever the user is in the app.
///
/// The outbox keeps sending after the conversation screen closes, so the
/// result cannot be shown by that screen. Resolves the messenger and
/// localization from [NavigatorKeys.root], since this widget is mounted above
/// the app's `MaterialApp`. An outcome with no root context is dropped, with a
/// log line.
///
/// Resubscribes when [videoDmOutboxProvider] hands out a new outbox (an
/// account switch).
class VideoDmSendOutcomeListener extends ConsumerStatefulWidget {
  const VideoDmSendOutcomeListener({
    required this.child,
    this.resolveChatName,
    super.key,
  });

  /// Optional name reader for hosts with their own conversation presentation.
  final Future<String> Function(BuildContext, VideoDmSendOutcome)?
  resolveChatName;

  final Widget child;

  @override
  ConsumerState<VideoDmSendOutcomeListener> createState() =>
      _VideoDmSendOutcomeListenerState();
}

class _VideoDmSendOutcomeListenerState
    extends ConsumerState<VideoDmSendOutcomeListener> {
  StreamSubscription<VideoDmSendOutcome>? _subscription;
  VideoDmOutbox? _outbox;
  Future<void> _notifications = Future.value();
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual<VideoDmOutbox>(
      videoDmOutboxProvider,
      (_, outbox) => _subscribeTo(outbox),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _subscribeTo(VideoDmOutbox outbox) {
    if (identical(outbox, _outbox)) return;
    unawaited(_subscription?.cancel());
    _outbox = outbox;
    final generation = ++_generation;
    _notifications = Future.value();
    _subscription = outbox.outcomes.listen((outcome) {
      final notification = _notifications.then(
        (_) => _show(outcome, generation),
      );
      // A failed presentation must not poison later outcomes.
      _notifications = notification.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      runDetached(
        notification,
        'show video DM outcome',
        logName: 'VideoDmSendOutcomeListener',
        category: LogCategory.ui,
      );
    });
  }

  bool _isVisible(BuildContext context, String conversationId) =>
      GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.path ==
      ConversationRouteData(id: conversationId).location;

  Future<String> _chatName(
    BuildContext context,
    VideoDmSendOutcome outcome,
  ) async {
    final pubkey = outcome.recipientPubkey;
    final vanished = await ref.read(
      profileVanishedSnapshotProvider(pubkey).future,
    );
    if (!mounted || !context.mounted) return '';
    final moderation = ref.read(moderationPresentationProvider(pubkey));
    final substitute = dmPeerNameWithoutProfile(
      context,
      isVanished: vanished,
      moderation: moderation,
    );
    if (substitute != null) return substitute;
    // Use cached identity first; a notification must not hold other outcomes
    // behind a network profile lookup. The inbox uses the same generated name.
    final profile = await ref
        .read(profileReadRepositoryProvider)
        ?.getCachedProfile(pubkey: pubkey);
    if (!mounted || !context.mounted) return '';
    return dmPeerDisplayName(
      context,
      pubkeyHex: pubkey,
      isVanished: vanished,
      moderation: moderation,
      profile: profile,
    );
  }

  Future<void> _show(VideoDmSendOutcome outcome, int generation) async {
    if (!mounted || generation != _generation) return;
    final context = NavigatorKeys.root.currentContext;
    final l10n = context == null || !context.mounted
        ? null
        : Localizations.of<AppLocalizations>(context, AppLocalizations);
    final messenger = context == null || l10n == null
        ? null
        : ScaffoldMessenger.maybeOf(context);
    if (context == null || l10n == null || messenger == null) {
      Log.warning(
        'Video DM send outcome ${outcome.status.name} '
        '(${outcome.sentCount} of ${outcome.total} sent) not shown: '
        'no root messenger',
        name: 'VideoDmSendOutcomeListener',
        category: LogCategory.ui,
      );
      return;
    }

    String chatName;
    try {
      chatName = await (widget.resolveChatName ?? _chatName)(context, outcome);
    } catch (error) {
      Log.warning(
        'Could not resolve video DM chat name (${error.runtimeType})',
        name: 'VideoDmSendOutcomeListener',
        category: LogCategory.ui,
      );
      chatName = UserProfile.defaultDisplayNameFor(outcome.recipientPubkey);
    }
    if (!mounted || !context.mounted || generation != _generation) {
      return;
    }
    final (resultMessage, isError) = switch (outcome) {
      VideoDmSendOutcome(isPartial: true) => (
        l10n.dmClipsPartlySent(outcome.sentCount, outcome.total),
        true,
      ),
      VideoDmSendOutcome(status: VideoDmOutcomeStatus.sent) => (
        l10n.dmVideoSent,
        false,
      ),
      VideoDmSendOutcome(status: VideoDmOutcomeStatus.tooLarge) => (
        l10n.dmVideoTooLarge('$videoDmMaxMegabytes'),
        true,
      ),
      VideoDmSendOutcome(status: VideoDmOutcomeStatus.clipNotVerified) => (
        l10n.dmClipSendNotVerified,
        true,
      ),
      VideoDmSendOutcome(status: VideoDmOutcomeStatus.failed) => (
        l10n.dmVideoSendFailed,
        true,
      ),
    };

    // The name is the peer's own text: isolate it so its bidi controls cannot
    // reorder the result that follows it.
    final message = l10n.dmVideoOutcomeInChat(
      '\u2068$chatName\u2069',
      resultMessage,
    );
    if (!_isVisible(context, outcome.conversationId)) {
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(message, error: isError),
      );
    }
    // Per `accessibility.md`, async visible state changes announce
    // explicitly; Material's default SnackBar semantics are weaker.
    runDetached(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
      'announce DM video send outcome',
      logName: 'VideoDmSendOutcomeListener',
      category: LogCategory.ui,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
