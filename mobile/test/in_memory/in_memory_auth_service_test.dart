import 'package:flutter_test/flutter_test.dart';

import 'in_memory_auth_service.dart';

void main() {
  group('dispose', () {
    test('waits for the auth state stream to close', () async {
      final authService = InMemoryAuthService();
      var streamClosed = false;
      final subscription = authService.authStateStream.listen(
        (_) {},
        onDone: () => streamClosed = true,
      );
      addTearDown(subscription.cancel);
      subscription.pause();

      var disposed = false;
      final disposal = authService.dispose().then((_) => disposed = true);
      await pumpEventQueue();
      expect(disposed, isFalse);
      expect(streamClosed, isFalse);

      subscription.resume();
      await disposal;
      expect(streamClosed, isTrue);
    });
  });
}
