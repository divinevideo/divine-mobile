// ABOUTME: Reopens a live subscription after every relay refuses it, on a
// ABOUTME: capped, doubling delay, instead of leaving it dead for the session.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:nostr_client/src/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Keeps a live subscription open across refusals from every relay.
///
/// [NostrClient.subscribe] ends its stream with a
/// [RelaySubscriptionRefusedException] once every relay serving it has sent
/// `CLOSED`. Most refusals lift with time — a rate limit, a subscription cap, a
/// relay's own query failure — so this opens the subscription again after a
/// delay that doubles from [initialDelay] up to [maxDelay], and starts from
/// [initialDelay] again once an opening has stayed up for [maxDelay] (#9006).
/// Events do not reset it: every reopen replays the relay's stored events, so
/// a relay that sends them and then refuses would otherwise be asked again
/// every [initialDelay] for the whole session. Any other error, or the
/// stream ending without one, goes to `onError` or simply ends it, as before.
///
/// `onRefused` gets the refusal's NIP-01 category (`rate-limited`, `error`,
/// ...), never the relay's text, which can carry the user's IP address.
class RefusalRetryingSubscription {
  /// Creates a subscription that [open]s the stream when [start]ed.
  RefusalRetryingSubscription({
    required Stream<Event> Function() open,
    required void Function(Event event) onEvent,
    void Function(String reasonCategory, Duration retryIn)? onRefused,
    void Function(Object error)? onError,
    this.initialDelay = defaultInitialDelay,
    this.maxDelay = defaultMaxDelay,
  }) : _open = open,
       _onEvent = onEvent,
       _onRefused = onRefused,
       _onError = onError;

  /// The delay before the first reopen after a refusal.
  static const Duration defaultInitialDelay = Duration(seconds: 2);

  /// The longest delay between reopens.
  static const Duration defaultMaxDelay = Duration(minutes: 1);

  /// The delay before the first reopen after a refusal.
  final Duration initialDelay;

  /// The longest delay between reopens.
  final Duration maxDelay;

  final Stream<Event> Function() _open;
  final void Function(Event event) _onEvent;
  final void Function(String reasonCategory, Duration retryIn)? _onRefused;
  final void Function(Object error)? _onError;

  StreamSubscription<Event>? _subscription;
  Timer? _reopen;
  Duration? _lastDelay;
  DateTime? _openedAt;

  /// Opens the subscription, replacing any that is still open.
  void start() {
    unawaited(_subscription?.cancel());
    _openedAt = clock.now();
    _subscription = _open().listen(
      _onEvent,
      onError: (Object error) {
        if (error is RelaySubscriptionRefusedException) {
          _scheduleReopen(error);
        } else {
          _onError?.call(error);
        }
      },
    );
  }

  void _scheduleReopen(RelaySubscriptionRefusedException refusal) {
    final last = _lastDelay;
    final openedAt = _openedAt;
    final stayedUp =
        openedAt != null && clock.now().difference(openedAt) >= maxDelay;
    final doubled = last == null || stayedUp ? initialDelay : last * 2;
    final delay = doubled > maxDelay ? maxDelay : doubled;
    _lastDelay = delay;
    _onRefused?.call(relayRefusalCategoryForDiagnostics(refusal.reason), delay);
    _reopen?.cancel();
    _reopen = Timer(delay, () {
      _reopen = null;
      // The first open's throw reaches start()'s caller; a reopen has none.
      try {
        start();
      } on Object catch (error) {
        _onError?.call(error);
      }
    });
  }

  /// Stops listening and drops any pending reopen.
  Future<void> cancel() {
    _reopen?.cancel();
    _reopen = null;
    final cancelled = _subscription?.cancel() ?? Future<void>.value();
    _subscription = null;
    return cancelled;
  }
}
