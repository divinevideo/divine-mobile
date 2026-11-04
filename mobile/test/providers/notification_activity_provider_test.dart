import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/notification_activity_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _Session extends NostrSession {
  @override
  NostrSessionReadiness build() => const NostrSessionReadiness.signedOut();
}

void main() {
  group('notification activity lifecycle', () {
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    late _MockAuthService auth;
    late _MockNostrClient client;
    late ProviderContainer container;
    late List<NotificationActivityUpdate> sent;

    setUp(() {
      auth = _MockAuthService();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(owner);
      when(() => auth.authStateStream)
          .thenAnswer((_) => const Stream<AuthState>.empty());
      client = _MockNostrClient();
      when(() => client.hasKeys).thenReturn(true);
      when(() => client.publicKey).thenReturn(owner);
      sent = [];
      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          currentEnvironmentProvider.overrideWithValue(
            EnvironmentConfig.production,
          ),
          nostrSessionProvider.overrideWith(_Session.new),
          notificationActivitySendProvider.overrideWithValue(
            (_, update, _) async => sent.add(update),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    void ready() => container
        .read(nostrSessionProvider.notifier)
        .update(
          NostrSessionReadiness.nostrReady(pubkey: owner, client: client),
        );

    testWidgets('restored ready account reports current foreground once', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      container.read(notificationActivitySyncProvider);
      await tester.pump();
      expect(sent, isEmpty);
      ready();
      await tester.pump();
      expect(sent.single.state, NotificationActivityState.foreground);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(sent, hasLength(1));
      container.dispose();
      await tester.pump();
    });

    testWidgets('background startup waits for a real resumed transition', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      ready();
      container.read(notificationActivitySyncProvider);
      await tester.pump();
      expect(sent, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(sent.single.state, NotificationActivityState.foreground);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(sent.map((update) => update.state), [
        NotificationActivityState.foreground,
        NotificationActivityState.background,
      ]);
      container.dispose();
      await tester.pump();
    });

    testWidgets(
      'a ready client belonging to another owner cannot report activity',
      (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        container.read(notificationActivitySyncProvider);
        when(() => client.publicKey).thenReturn('b' * 64);
        ready();
        await tester.pump();
        expect(sent, isEmpty);
        container.dispose();
        await tester.pump();
      },
    );

    testWidgets(
      'a session ready for another account cannot report activity',
      (tester) async {
        // Mid-switch: auth names the new account while the session is still
        // ready for the previous one.
        const previous =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        container.read(notificationActivitySyncProvider);
        when(() => client.publicKey).thenReturn(previous);
        container
            .read(nostrSessionProvider.notifier)
            .update(
              NostrSessionReadiness.nostrReady(
                pubkey: previous,
                client: client,
              ),
            );
        await tester.pump();
        expect(sent, isEmpty);
        container.dispose();
        await tester.pump();
      },
    );
  });

  group('notificationActivitySendProvider', () {
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const update = NotificationActivityUpdate(
      sessionId: 'c8da3021-9bd3-48fb-81e6-4b709a5b86f3',
      sequence: 1,
      visit: 1,
      state: NotificationActivityState.foreground,
    );

    test('signs the clock-skew retry without user interaction', () async {
      final auth = _MockAuthService();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(owner);
      var passive = 0;
      var interactive = 0;
      Event signed(Invocation invocation) => Event(
        owner,
        27235,
        invocation.namedArguments[#tags]! as List<List<String>>,
        '',
        createdAt: invocation.namedArguments[#createdAt] as int?,
      );
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
          allowUserInteraction: false,
        ),
      ).thenAnswer((invocation) async {
        passive++;
        return signed(invocation);
      });
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        interactive++;
        return signed(invocation);
      });
      final nip98 = Nip98AuthService(authService: auth);
      addTearDown(nip98.dispose);
      final requests = <http.Request>[];
      final container = ProviderContainer(
        overrides: [
          nip98AuthServiceProvider.overrideWithValue(nip98),
          currentEnvironmentProvider.overrideWithValue(
            EnvironmentConfig.production,
          ),
          appVersionProvider.overrideWithValue('1.0.0'),
          instrumentedHttpClientFactoryProvider.overrideWithValue(
            () => MockClient((request) async {
              requests.add(request);
              if (requests.length == 1) {
                return http.Response(
                  '{"error":"Auth failed: event timestamp is in the future"}',
                  401,
                  headers: {'date': 'Thu, 29 Oct 2026 19:00:00 GMT'},
                );
              }
              return http.Response('', 204);
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(notificationActivitySendProvider)(
        owner,
        update,
        () => true,
      );

      expect(requests, hasLength(2));
      expect(passive, 2);
      expect(interactive, 0);
    });
  });
}
