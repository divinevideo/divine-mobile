// ABOUTME: Flushes durable account state at startup, foreground and reconnect.
// ABOUTME: Coalesces overlapping triggers and stops callbacks after disposal.

import 'dart:async';

class AccountSyncLifecycle {
  AccountSyncLifecycle({
    required List<Future<void> Function()> flushers,
    required Stream<bool> connectivity,
  }) : _flushers = flushers {
    _subscription = connectivity.distinct().listen((connected) {
      if (connected) unawaited(flush());
    });
    unawaited(flush());
  }

  final List<Future<void> Function()> _flushers;
  StreamSubscription<bool>? _subscription;
  Future<void>? _inFlight;
  bool _closed = false;
  bool _rerunRequested = false;

  Future<void> flush() {
    if (_closed) return Future<void>.value();
    final inFlight = _inFlight;
    if (inFlight != null) {
      _rerunRequested = true;
      return inFlight;
    }
    return _inFlight = _drain().whenComplete(() {
      _inFlight = null;
      _rerunRequested = false;
    });
  }

  Future<void> _drain() async {
    await _flush();
    // A foreground/reconnect edge during an unavailable transport must retry
    // once after it settles. Bound the trailing pass so status chatter cannot
    // turn this into a permanent sync loop.
    if (!_closed && _rerunRequested) {
      _rerunRequested = false;
      await _flush();
    }
  }

  Future<void> _flush() => Future.wait(
    _flushers.map((flusher) async {
      if (_closed) return;
      try {
        await flusher();
      } on Object {
        // Each repository retains its own durable retry intent. Independent
        // protocols start together, including when one relay query stalls.
      }
    }),
  );

  void close() {
    _closed = true;
    unawaited(_subscription?.cancel());
  }
}
