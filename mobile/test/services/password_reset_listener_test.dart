// ABOUTME: Tests for PasswordResetListener
// ABOUTME: Verifies that deep links navigate to the reset password screen

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/router/providers/deep_link_listeners.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/password_reset_listener.dart';

import 'package:unified_logger/unified_logger.dart';

import '../helpers/go_router.dart';

void main() {
  group(PasswordResetListener, () {
    late MockGoRouter mockRouter;
    late ProviderContainer container;
    late PasswordResetListener listener;

    setUp(() {
      mockRouter = MockGoRouter();

      container = ProviderContainer(
        overrides: [goRouterProvider.overrideWith((ref) => mockRouter)],
      );

      listener = container.read(passwordResetListenerProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'navigates to reset password screen when URI contains a token',
      () async {
        const token = 'test-reset-token-abc123';
        when(() => mockRouter.go(any())).thenReturn(null);

        await listener.handleUri(
          Uri.parse('https://login.divine.video/reset-password?token=$token'),
        );

        verify(
          () =>
              mockRouter.go('${WelcomeScreen.resetPasswordPath}?token=$token'),
        ).called(1);
      },
    );

    test('ignores URIs with wrong host', () async {
      await listener.handleUri(
        Uri.parse('https://evil.com/reset-password?token=stolen-token'),
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
      when(() => mockRouter.go(any())).thenReturn(null);

      await listener.handleUri(
        Uri.parse('https://login.divine.video/reset-password'),
      );

      verifyNever(() => mockRouter.go(any()));
    });

    test(
      'forwards email query param when present',
      () async {
        const token = 'test-reset-token-abc123';
        const email = 'user@example.com';
        when(() => mockRouter.go(any())).thenReturn(null);

        await listener.handleUri(
          Uri.parse(
            'https://login.divine.video/reset-password'
            '?token=$token&email=${Uri.encodeQueryComponent(email)}',
          ),
        );

        verify(
          () => mockRouter.go(
            '${WelcomeScreen.resetPasswordPath}'
            '?token=$token&email=${Uri.encodeQueryComponent(email)}',
          ),
        ).called(1);
      },
    );

    test(
      'omits email query param when absent',
      () async {
        const token = 'test-reset-token-abc123';
        when(() => mockRouter.go(any())).thenReturn(null);

        await listener.handleUri(
          Uri.parse(
            'https://login.divine.video/reset-password?token=$token',
          ),
        );

        verify(
          () => mockRouter.go(
            '${WelcomeScreen.resetPasswordPath}?token=$token',
          ),
        ).called(1);
      },
    );

    test(
      'URL-encodes email special characters',
      () async {
        const token = 'T';
        const email = 'test+alias@example.com';
        when(() => mockRouter.go(any())).thenReturn(null);

        await listener.handleUri(
          Uri.parse(
            'https://login.divine.video/reset-password'
            '?token=$token&email=${Uri.encodeQueryComponent(email)}',
          ),
        );

        verify(
          () => mockRouter.go(
            '${WelcomeScreen.resetPasswordPath}'
            '?token=$token&email=test%2Balias%40example.com',
          ),
        ).called(1);
      },
    );

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
        expect(logged, contains('callback from '));
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
        expect(logged, contains('callback from divine://nostrconnect'));
        expect(logged, isNot(contains('[invalid-uri]')));
      });
    });
  });
}
