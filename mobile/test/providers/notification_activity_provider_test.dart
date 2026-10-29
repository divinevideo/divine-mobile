import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/notification_activity_provider.dart';
import 'package:openvine/services/auth_service.dart';

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
  });
}
