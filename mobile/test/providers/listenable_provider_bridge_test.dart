// ABOUTME: Tests the shared Listenable-to-Riverpod lifecycle bridge
// ABOUTME: Verifies listener registration, notification, and disposal cleanup

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/listenable_provider_bridge.dart';

class _RecordingListenable extends ChangeNotifier {
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

void main() {
  group('listenForProviderLifetime', () {
    test('registers once, forwards notifications, and removes on disposal', () {
      final source = _RecordingListenable();
      var notifications = 0;
      final provider = Provider.autoDispose<void>((ref) {
        listenForProviderLifetime(ref, source, () => notifications++);
      });
      final container = ProviderContainer();
      final subscription = container.listen(provider, (_, _) {});

      expect(source.addListenerCalls, equals(1));
      source.notifyListeners();
      expect(notifications, equals(1));

      subscription.close();
      container.dispose();
      expect(source.removeListenerCalls, equals(1));

      // Counting removeListener calls cannot tell a matching removal from a
      // mismatched one; only a post-dispose notification can.
      source.notifyListeners();
      expect(notifications, equals(1));
    });
  });
}
