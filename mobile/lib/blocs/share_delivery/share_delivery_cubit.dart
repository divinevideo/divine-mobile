// ABOUTME: Tracks recipient-route confirmation after the share sheet closes.
import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/video_sharing_service.dart';

typedef ShareDeliveryRecipient = ({
  String name,
  String pubkey,
  ShareResult outcome,
});

/// Delivery feedback for the latest video share, as the banner renders it.
class ShareDeliveryFeedback {
  /// Copies [recipients], so a caller cannot change feedback already emitted.
  ShareDeliveryFeedback(
    this.owner,
    List<ShareDeliveryRecipient> recipients,
    this.states, {
    this.overdue = false,
  }) : recipients = List.unmodifiable(recipients);

  /// Public key of the account that sent the share.
  final String owner;

  /// Every recipient the share was addressed to, refused ones included.
  final List<ShareDeliveryRecipient> recipients;

  /// Delivery state of each queued recipient, keyed by its rumor id.
  ///
  /// A recipient refused before queueing has no rumor id and so no entry.
  final Map<String, DmDeliveryState> states;

  /// Whether [ShareDeliveryCubit.overdueAfter] passed while a recipient was
  /// still queued or held.
  final bool overdue;

  /// The one queued recipient whose conversation "View chat" opens, or null
  /// when the share queued none or several.
  ShareDeliveryRecipient? get chat {
    final queued = recipients.where(
      (r) => r.outcome.delivery == ShareDelivery.queued,
    );
    return queued.length == 1 ? queued.single : null;
  }
}

typedef WatchShareDelivery = Stream<DmDeliveryState> Function({
  required String ownerPubkey,
  required String rumorId,
});

bool _isPending(DmDeliveryState state) =>
    state == DmDeliveryState.queued || state == DmDeliveryState.held;

bool _isSettled(DmDeliveryState state) =>
    state == DmDeliveryState.accepted || state == DmDeliveryState.cancelled;

/// The latest send owns the banner. Its transport and older sends continue in
/// the repository even when another send takes over the visible feedback.
class ShareDeliveryCubit extends Cubit<ShareDeliveryFeedback?>
    with CloseGuardedEmit<ShareDeliveryFeedback?> {
  ShareDeliveryCubit({required this.watchDelivery, required this.currentOwner})
    : super(null);

  /// How long a recipient may stay queued or held before the feedback is
  /// marked [ShareDeliveryFeedback.overdue].
  static const overdueAfter = Duration(seconds: 20);

  final WatchShareDelivery watchDelivery;
  final String? Function() currentOwner;
  final _subscriptions = <StreamSubscription<DmDeliveryState>>[];
  Timer? _timer;
  int _generation = 0;

  void track({
    required String ownerPubkey,
    required List<ShareDeliveryRecipient> recipients,
  }) {
    if (isClosed || ownerPubkey != currentOwner()) return;
    final tracked = List<ShareDeliveryRecipient>.unmodifiable(recipients);
    final states = <String, DmDeliveryState>{
      for (final r in tracked) ?r.outcome.rumorId: DmDeliveryState.queued,
    };
    // Nothing here can be confirmed, so the current feedback keeps its owner.
    if (states.isEmpty) return;
    _stop();
    final generation = _generation;
    var overdue = false;
    void update() {
      if (isClosed || generation != _generation) return;
      if (ownerPubkey != currentOwner()) {
        reset();
        return;
      }
      if (!states.values.any(_isPending)) {
        _timer?.cancel();
      } else if (!overdue && !(_timer?.isActive ?? false)) {
        _timer = Timer(overdueAfter, () {
          overdue = true;
          update();
        });
      }
      emitIfOpen(
        ShareDeliveryFeedback(
          ownerPubkey,
          tracked,
          Map.unmodifiable(states),
          overdue: overdue,
        ),
      );
      if (states.values.every(_isSettled)) _stop();
    }

    update();
    for (final id in states.keys.toList()) {
      void changed(DmDeliveryState value) {
        if (states[id] == value) return;
        states[id] = value;
        update();
      }

      _subscriptions.add(
        watchDelivery(ownerPubkey: ownerPubkey, rumorId: id).listen(
          changed,
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            changed(DmDeliveryState.failed);
          },
        ),
      );
    }
  }

  void reset() {
    _stop();
    emitIfOpen(null);
  }

  void _stop() {
    _generation++;
    _timer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  @override
  Future<void> close() {
    _stop();
    return super.close();
  }
}
