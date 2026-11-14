// ABOUTME: Shows the result of an outgoing video DM send as a snackbar app-wide
// ABOUTME: Sends outlive their conversation screen, so the report lives at the root

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/video_dm_outbox.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reports each video DM send outcome wherever the user is in the app.
///
/// The outbox keeps sending after the conversation screen closes, so the
/// result cannot be shown by that screen. Resolves the messenger and
/// localization from [NavigatorKeys.root], since this widget is mounted above
/// the app's `MaterialApp`. An outcome with no root context is dropped.
///
/// Resubscribes when [videoDmOutboxProvider] hands out a new outbox (an
/// account switch).
class VideoDmSendOutcomeListener extends ConsumerStatefulWidget {
  const VideoDmSendOutcomeListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<VideoDmSendOutcomeListener> createState() =>
      _VideoDmSendOutcomeListenerState();
}

class _VideoDmSendOutcomeListenerState
    extends ConsumerState<VideoDmSendOutcomeListener> {
  StreamSubscription<VideoDmSendOutcome>? _subscription;
  VideoDmOutbox? _outbox;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _subscribeTo(VideoDmOutbox outbox) {
    if (identical(outbox, _outbox)) return;
    unawaited(_subscription?.cancel());
    _outbox = outbox;
    _subscription = outbox.outcomes.listen(_show);
  }

  void _show(VideoDmSendOutcome outcome) {
    final context = NavigatorKeys.root.currentContext;
    if (context == null || !context.mounted) return;
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (l10n == null || messenger == null) return;

    final (message, isError) = switch (outcome) {
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

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(DivineSnackbarContainer.snackBar(message, error: isError));
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
  Widget build(BuildContext context) {
    _subscribeTo(ref.watch(videoDmOutboxProvider));
    return widget.child;
  }
}
