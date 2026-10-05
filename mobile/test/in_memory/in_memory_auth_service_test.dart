import 'package:flutter_test/flutter_test.dart';

import 'in_memory_auth_service.dart';

void main() {
  test('dispose waits for the auth state stream to close', () async {
    final authService = InMemoryAuthService();
    final streamDone = expectLater(authService.authStateStream, emitsDone);

    await authService.dispose();
    await streamDone;
  });
}
