// ABOUTME: Regression tests for moderation label provider session readiness.
// ABOUTME: Ensures label subscriptions do not start on disposable Nostr clients.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _FakeFilter extends Fake implements Filter {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

void main() {
  const testPubkey =
      '0edc2f474484769bc9bf6d471d180e4e280b0bcd719b6da791001beb730cff1b';

  setUpAll(() {
    registerFallbackValue(<Filter>[_FakeFilter()]);
  });

  Future<ProviderContainer> createContainer({
    required NostrSessionReadiness readiness,
    required _MockNostrClient nostrClient,
    _MockFollowRepository? followRepository,
  }) async {
    SharedPreferences.setMockInitialValues({
      'divine_moderation_resolved_pubkey':
          ModerationLabelService.fallbackModerationPubkeyHex,
      'divine_moderation_resolved_at': DateTime.now().toIso8601String(),
    });
    final prefs = await SharedPreferences.getInstance();
    final authService = _MockAuthService();

    when(() => authService.currentIdentity).thenReturn(null);
    when(() => authService.currentPublicKeyHex).thenReturn(testPubkey);
    when(() => authService.isAuthenticated).thenReturn(true);

    return ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        nostrServiceProvider.overrideWithValue(nostrClient),
        nostrSessionProvider.overrideWith(() => _TestNostrSession(readiness)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (followRepository != null)
          followRepositoryProvider.overrideWithValue(followRepository),
      ],
    );
  }

  group('moderationLabelServiceProvider', () {
    test('does not query labelers before Nostr session is ready', () async {
      final nostrClient = _MockNostrClient();
      when(() => nostrClient.hasKeys).thenReturn(false);

      final container = await createContainer(
        readiness: const NostrSessionReadiness.identityKnown(
          pubkey: testPubkey,
        ),
        nostrClient: nostrClient,
      );
      addTearDown(container.dispose);

      container.read(moderationLabelServiceProvider);
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => nostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      );
    });

    test('subscribes labelers once active Nostr client is ready', () async {
      final nostrClient = _MockNostrClient();
      final followRepository = _MockFollowRepository();
      final followingController = StreamController<List<String>>.broadcast();
      final labelTail = StreamController<Event>.broadcast();
      addTearDown(followingController.close);
      addTearDown(labelTail.close);

      when(() => nostrClient.hasKeys).thenReturn(true);
      when(() => nostrClient.publicKey).thenReturn(testPubkey);
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: false, noRelays: false),
      );
      when(
        () => nostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => labelTail.stream);
      when(() => followRepository.followingPubkeys).thenReturn(const []);
      when(
        () => followRepository.followingStream,
      ).thenAnswer((_) => followingController.stream);

      final container = await createContainer(
        readiness: NostrSessionReadiness.nostrReady(
          pubkey: testPubkey,
          client: nostrClient,
        ),
        nostrClient: nostrClient,
        followRepository: followRepository,
      );
      addTearDown(container.dispose);

      container.read(moderationLabelServiceProvider);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => nostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).called(1);
    });

    test(
      'does not query when readiness holds a stale client instance',
      () async {
        final activeClient = _MockNostrClient();
        final staleReadyClient = _MockNostrClient();

        when(() => staleReadyClient.hasKeys).thenReturn(true);
        when(() => staleReadyClient.publicKey).thenReturn(testPubkey);

        final container = await createContainer(
          readiness: NostrSessionReadiness.nostrReady(
            pubkey: testPubkey,
            client: staleReadyClient,
          ),
          nostrClient: activeClient,
        );
        addTearDown(container.dispose);

        container.read(moderationLabelServiceProvider);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => activeClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        );
        verifyNever(
          () => staleReadyClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        );
      },
    );
  });
}
