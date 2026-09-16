// ABOUTME: Counts ChangeNotifier addListener/removeListener calls on a test
// ABOUTME: double, shared by provider tests that assert single-subscription behavior

import 'package:flutter/foundation.dart';

/// Mix into a [ChangeNotifier] test double to count subscribe/unsubscribe
/// calls, so a test can assert a provider subscribes once and unsubscribes
/// on disposal rather than resubscribing on every notification.
mixin ListenerCallRecorder on ChangeNotifier {
  int addListenerCalls = 0;
  int removeListenerCalls = 0;

  @override
  void addListener(VoidCallback listener) {
    addListenerCalls++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeListenerCalls++;
    super.removeListener(listener);
  }
}
