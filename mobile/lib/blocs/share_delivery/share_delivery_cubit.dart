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

class ShareDeliveryFeedback {
  const ShareDeliveryFeedback(
    this.owner,
    this.recipients,
    this.states, {
    this.overdue = false,
  });

  final String owner;
  final List<ShareDeliveryRecipient> recipients;
  final Map<String, DmDeliveryState> states;
  final bool overdue;

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

/// The latest send owns the banner. Its transport and older sends continue in
/// the repository even when another send takes over the visible feedback.
class ShareDeliveryCubit extends Cubit<ShareDeliveryFeedback?>
    with CloseGuardedEmit<ShareDeliveryFeedback?> {
  ShareDeliveryCubit({required this.watchDelivery, required this.currentOwner})
    : super(null);

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
    _stop();
    final generation = _generation;
    final states = <String, DmDeliveryState>{
      for (final r in recipients) ?r.outcome.rumorId: DmDeliveryState.queued,
    };
    if (states.isEmpty) return;
    var overdue = false;
    void update() {
      if (isClosed || generation != _generation) return;
      if (ownerPubkey != currentOwner()) {
        reset();
        return;
      }
      emitIfOpen(
        ShareDeliveryFeedback(
          ownerPubkey,
          recipients,
          Map.unmodifiable(states),
          overdue: overdue,
        ),
      );
      if (states.values.every(
        (s) => s == DmDeliveryState.accepted || s == DmDeliveryState.cancelled,
      )) {
        _stop();
      }
    }

    update();
    _timer = Timer(const Duration(seconds: 20), () {
      overdue = true;
      update();
    });
    for (final id in states.keys.toList()) {
      void changed(DmDeliveryState value) {
        if (states[id] == value) return;
        states[id] = value;
        update();
      }

      _subscriptions.add(
        watchDelivery(ownerPubkey: ownerPubkey, rumorId: id).listen(
          changed,
          onError: (Object _, StackTrace _) => changed(DmDeliveryState.failed),
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
