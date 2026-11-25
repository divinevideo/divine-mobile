// ABOUTME: Presents owner-scoped video-share feedback above the root navigator.
import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/share_delivery/share_delivery_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shows the latest video share's delivery feedback above the root navigator.
///
/// Provides a [ShareDeliveryCubit] to [child]. The banner is a persistent
/// [SnackBar] built here around [DivineSnackbarContainer], rather than
/// [DivineSnackbarContainer.snackBar], because its content watches the cubit:
/// the text keeps following delivery after the banner is shown, and it
/// dismisses itself [dismissAfter] once no recipient is still pending.
class ShareDeliveryHost extends ConsumerStatefulWidget {
  const ShareDeliveryHost({required this.child, super.key});

  /// How long a banner with nothing left pending stays on screen.
  static const dismissAfter = Duration(seconds: 5);

  final Widget child;

  @override
  ConsumerState<ShareDeliveryHost> createState() => _ShareDeliveryHostState();
}

class _ShareDeliveryHostState extends ConsumerState<ShareDeliveryHost> {
  late final _delivery = ShareDeliveryCubit(
    currentOwner: () => ref.read(authServiceProvider).currentPublicKeyHex,
    watchDelivery: ({required ownerPubkey, required rumorId}) => ref
        .read(dmRepositoryProvider)
        .watchDeliveryState(ownerPubkey: ownerPubkey, rumorId: rumorId),
  );
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _banner;

  Timer? _expiry;
  bool _visible = false;

  @override
  void dispose() {
    _expiry?.cancel();
    unawaited(_delivery.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      currentEnvironmentProvider.select((env) => env.environment),
      (_, _) => _delivery.reset(),
    );
    ref.listen(nostrSessionProvider, (before, after) {
      if (before?.pubkey != after.pubkey ||
          after.phase == NostrSessionPhase.tearingDown) {
        _delivery.reset();
      }
    });
    return BlocProvider.value(
      value: _delivery,
      child: BlocListener<ShareDeliveryCubit, ShareDeliveryFeedback?>(
        listener: _showFeedback,
        child: widget.child,
      ),
    );
  }

  void _showFeedback(BuildContext context, ShareDeliveryFeedback? feedback) {
    final messenger = ScaffoldMessenger.of(context);
    if (_banner != null) {
      // The banner may still be behind someone else's snackbar. Its content
      // watches this cubit directly, so it can never display superseded text.
      if (_visible) {
        _announceIncomplete(context, feedback);
        _scheduleDismiss(messenger);
      }
      return;
    }
    if (feedback == null) return;
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    controller;
    controller = messenger.showSnackBar(
      SnackBar(
        persist: true,
        behavior: SnackBarBehavior.floating,
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        onVisible: () {
          if (!mounted || !identical(_banner, controller)) return;
          _visible = true;
          _announceIncomplete(context, _delivery.state);
          _scheduleDismiss(messenger);
        },
        content: BlocBuilder<ShareDeliveryCubit, ShareDeliveryFeedback?>(
          bloc: _delivery,
          builder: (context, current) {
            if (current == null ||
                current.owner !=
                    ref.read(authServiceProvider).currentPublicKeyHex) {
              return const SizedBox.shrink();
            }
            return _ShareDeliveryBanner(
              feedback: current,
              onViewChat: (chat) => _openChat(current.owner, chat),
            );
          },
        ),
      ),
    );
    _banner = controller;
    unawaited(
      controller.closed.then((_) {
        if (!identical(_banner, controller)) return;
        _expiry?.cancel();
        _banner = null;
        _visible = false;
      }),
    );
  }

  void _scheduleDismiss(ScaffoldMessengerState messenger) {
    _expiry?.cancel();
    final feedback = _delivery.state;
    final unresolved =
        feedback != null &&
        !feedback.overdue &&
        feedback.states.values.any(
          (s) => s == DmDeliveryState.queued || s == DmDeliveryState.held,
        );
    // The cubit publishes again once ShareDeliveryCubit.overdueAfter passes.
    if (unresolved) return;
    _expiry = Timer(
      feedback == null ? Duration.zero : ShareDeliveryHost.dismissAfter,
      () {
        if (mounted && _visible) messenger.removeCurrentSnackBar();
      },
    );
  }

  void _announceIncomplete(
    BuildContext context,
    ShareDeliveryFeedback? feedback,
  ) {
    if (feedback == null ||
        feedback.owner != ref.read(authServiceProvider).currentPublicKeyHex) {
      return;
    }
    final text = _describe(context.l10n, feedback);
    if (text.incomplete) {
      _runDetached(
        SemanticsService.sendAnnouncement(
          View.of(context),
          text.message,
          Directionality.of(context),
        ),
        'announce incomplete share delivery',
      );
    }
  }

  void _openChat(String owner, ShareDeliveryRecipient chat) {
    final host = NavigatorKeys.root.currentContext;
    if (!mounted ||
        host == null ||
        ref.read(authServiceProvider).currentPublicKeyHex != owner ||
        ref.read(isDmRestrictedProvider)) {
      return;
    }
    _runDetached(
      ConversationRouteData(
        id: chat.outcome.conversationId!,
        $extra: [chat.pubkey],
      ).push<void>(host),
      'open shared video chat',
    );
  }
}

void _runDetached(Future<void> operation, String description) => runDetached(
  operation,
  description,
  logName: 'ShareDeliveryHost',
  category: LogCategory.ui,
);

({String message, bool incomplete}) _describe(
  AppLocalizations l10n,
  ShareDeliveryFeedback feedback,
) {
  final lines = <String>[];
  final single = feedback.recipients.length == 1;
  for (final recipient in feedback.recipients) {
    final status = feedback.states[recipient.outcome.rumorId];
    final label = switch (status) {
      DmDeliveryState.accepted => l10n.shareSent,
      DmDeliveryState.failed => l10n.shareDeliveryFailed,
      DmDeliveryState.held when feedback.overdue => l10n.shareDeliveryHeld(
        recipient.name,
      ),
      DmDeliveryState.queued when feedback.overdue =>
        l10n.crosspostStatusQueued,
      DmDeliveryState.held ||
      DmDeliveryState.queued => l10n.dmPendingVideoSending,
      DmDeliveryState.cancelled ||
      null => l10n.shareCouldNotSendTo(recipient.name),
    };
    lines.add(
      single ||
              status == null ||
              status == DmDeliveryState.cancelled ||
              (status == DmDeliveryState.held && feedback.overdue)
          ? label
          : l10n.shareDeliveryForRecipient(recipient.name, label),
    );
  }
  final incomplete =
      feedback.recipients.any((r) => r.outcome.rumorId == null) ||
      feedback.states.values.any(
        (s) => s == DmDeliveryState.cancelled || s == DmDeliveryState.failed,
      );
  return (message: lines.join('\n'), incomplete: incomplete);
}

class _ShareDeliveryBanner extends StatelessWidget {
  const _ShareDeliveryBanner({
    required this.feedback,
    required this.onViewChat,
  });

  final ShareDeliveryFeedback feedback;
  final ValueChanged<ShareDeliveryRecipient> onViewChat;

  @override
  Widget build(BuildContext context) {
    final text = _describe(context.l10n, feedback);
    final chat = feedback.chat;
    return DivineSnackbarContainer(
      label: text.message,
      error: text.incomplete,
      actionLabel: chat == null ? null : context.l10n.dmReelReplyViewChat,
      onActionPressed: chat == null ? null : () => onViewChat(chat),
    );
  }
}
