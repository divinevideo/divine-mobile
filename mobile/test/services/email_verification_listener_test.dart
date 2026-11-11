// ABOUTME: Tests for EmailVerificationListener
// ABOUTME: Verifies that deep links navigate to the verification screen

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/router/providers/deep_link_listeners.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/email_verification_listener.dart';

import 'package:unified_logger/unified_logger.dart';

import '../helpers/go_router.dart';

void main() {
  group(EmailVerificationListener, () {
    late MockGoRouter mockRouter;
    late ProviderContainer container;
    late EmailVerificationListener listener;

    setUp(() {
      mockRouter = MockGoRouter();

      container = ProviderContainer(
        overrides: [goRouterProvider.overrideWith((ref) => mockRouter)],
      );

      listener = container.read(emailVerificationListenerProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'navigates to verification screen when URI contains a token',
      () async {
        const token = 'test-verification-token-abc123';
        when(() => mockRouter.go(any())).thenReturn(null);

        await listener.handleUri(
          Uri.parse('https://login.divine.video/verify-email?token=$token'),
        );

        verify(() => mockRouter.go('/verify-email?token=$token')).called(1);
      },
    );

    test('ignores URIs with wrong host', () async {
      await listener.handleUri(
        Uri.parse('https://evil.com/verify-email?token=stolen-token'),
      );

      verifyNever(() => mockRouter.go(any()));
    });

    test('ignores URIs with wrong path', () async {
      await listener.handleUri(
        Uri.parse('https://login.divine.video/other-path?token=some-token'),
      );

      verifyNever(() => mockRouter.go(any()));
    });

    test('ignores URIs without token parameter', () async {
      await listener.handleUri(
        Uri.parse('https://login.divine.video/verify-email'),
      );

      verifyNever(() => mockRouter.go(any()));
    });

    group('logging (#10385)', () {
      test('does not log the nsec of a link it only inspects', () async {
        // NIP-19's published test vector; it controls no real account.
        const nsec =
            'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
        await LogCaptureService().clearAllLogs();

        await listener.handleUri(
          Uri.parse('https://divine.video/profile/$nsec'),
        );

        final logged = [
          for (final entry in LogCaptureService().getRecentLogs())
            entry.message,
        ].join('\n');
        expect(logged, contains('Callback from '));
        expect(logged.toLowerCase(), isNot(contains('nsec1')));
      });

      // NIP-46 callbacks reach this line too, and have no path.
      test('logs a path-less signer callback as the link it is', () async {
        await LogCaptureService().clearAllLogs();

        await listener.handleUri(
          Uri.parse('divine://nostrconnect?relay=wss://relay.example.com'),
        );

        final logged = [
          for (final entry in LogCaptureService().getRecentLogs())
            entry.message,
        ].join('\n');
        expect(logged, contains('Callback from divine://nostrconnect'));
        expect(logged, isNot(contains('[invalid-uri]')));
      });

      test('does not log the verification token it navigates with', () async {
        const token = 'test-verification-token-abc123';
        when(() => mockRouter.go(any())).thenReturn(null);
        await LogCaptureService().clearAllLogs();

        await listener.handleUri(
          Uri.parse('https://login.divine.video/verify-email?token=$token'),
        );

        final logged = [
          for (final entry in LogCaptureService().getRecentLogs())
            entry.message,
        ].join('\n');
        expect(logged, contains('Email verification callback detected'));
        expect(logged, isNot(contains(token)));
      });
    });
  });
}
