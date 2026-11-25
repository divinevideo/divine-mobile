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

class ShareDeliveryHost extends ConsumerStatefulWidget {
  const ShareDeliveryHost({required this.child, super.key});
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
            return _content(context, current);
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
    if (unresolved) return; // The cubit publishes again at the 20-second limit.
    _expiry = Timer(
      feedback == null ? Duration.zero : const Duration(seconds: 5),
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
    final text = _text(context, feedback);
    if (text.incomplete) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          text.message,
          Directionality.of(context),
        ),
      );
    }
  }

  ({String message, bool incomplete}) _text(
    BuildContext context,
    ShareDeliveryFeedback feedback,
  ) {
    final l10n = context.l10n;
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

  Widget _content(BuildContext context, ShareDeliveryFeedback feedback) {
    final text = _text(context, feedback);
    final chat = feedback.chat;
    return DivineSnackbarContainer(
      label: text.message,
      error: text.incomplete,
      actionLabel: chat == null ? null : context.l10n.dmReelReplyViewChat,
      onActionPressed: chat == null
          ? null
          : () {
              final host = NavigatorKeys.root.currentContext;
              if (!mounted ||
                  host == null ||
                  ref.read(authServiceProvider).currentPublicKeyHex !=
                      feedback.owner ||
                  ref.read(isDmRestrictedProvider)) {
                return;
              }
              unawaited(
                ConversationRouteData(
                  id: chat.outcome.conversationId!,
                  $extra: [chat.pubkey],
                ).push<void>(host),
              );
            },
    );
  }
}
