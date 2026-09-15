import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a [Stream] to a [Listenable] for GoRouter refreshes.
class RouterRefreshListenable implements Listenable {
  RouterRefreshListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => refresh());
  }

  final Set<VoidCallback> _listeners = <VoidCallback>{};
  late final StreamSubscription<dynamic> _subscription;
  bool _notificationScheduled = false;
  bool _disposed = false;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void refresh() {
    if (_disposed || _notificationScheduled) return;

    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      if (_disposed) return;

      for (final listener in List<VoidCallback>.of(_listeners)) {
        listener();
      }
    });
  }

  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    _listeners.clear();
    await _subscription.cancel();
  }
}
