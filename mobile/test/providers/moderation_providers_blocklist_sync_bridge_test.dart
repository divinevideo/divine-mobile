// ABOUTME: Regression tests for blocklistSyncBridgeProvider (#11070).
// ABOUTME: A switched-in account's mute-list sync survives the bridge build.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeFilter extends Fake implements Filter {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

void main() {
  const outgoingPubkey =
      '0edc2f474484769bc9bf6d471d180e4e280b0bcd719b6da791001beb730cff1b';
  const incomingPubkey =
      'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';

  setUpAll(() {
    registerFallbackValue(<Filter>[_FakeFilter()]);
  });

  group('blocklistSyncBridgeProvider', () {
    late List<List<Filter>> incomingSubscriptions;

    // An in-place account switch signs the incoming container in before it
    // mounts, so the bridge can build with the session already ready while
    // the shared preferences still name the outgoing account as the
    // blocklist's owner.
    Future<ProviderContainer> buildSwitchedInContainer() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final outgoingClient = _MockNostrClient();
      when(
        () => outgoingClient.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());
      final outgoingRepository = ContentBlocklistRepository(prefs: prefs);
      await outgoingRepository.syncMuteListsInBackground(
        outgoingClient,
        outgoingPubkey,
      );
      await pumpEventQueue();
      outgoingRepository.dispose();

      incomingSubscriptions = <List<Filter>>[];
      final incomingClient = _MockNostrClient();
      when(() => incomingClient.hasKeys).thenReturn(true);
      when(() => incomingClient.publicKey).thenReturn(incomingPubkey);
      when(() => incomingClient.subscribe(any())).thenAnswer((invocation) {
        incomingSubscriptions.add(
          invocation.positionalArguments.first as List<Filter>,
        );
        return const Stream<Event>.empty();
      });

      final authService = _MockAuthService();
      // Skips the legacy kind 30000 cutover, which is not under test here.
      when(() => authService.isAuthenticated).thenReturn(false);
      when(() => authService.currentIdentity).thenReturn(
        PubkeyOnlyNostrIdentity(pubkey: incomingPubkey),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(authService),
          nostrSessionProvider.overrideWith(
            () => _TestNostrSession(
              NostrSessionReadiness.nostrReady(
                pubkey: incomingPubkey,
                client: incomingClient,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    bool subscribedTo(int kind) => incomingSubscriptions.any(
      (filters) =>
          filters.any((filter) => filter.kinds?.contains(kind) ?? false),
    );

    test(
      'starts the incoming account mute-list sync when it builds with a '
      'ready session',
      () async {
        final container = await buildSwitchedInContainer();

        container.read(blocklistSyncBridgeProvider);
        await pumpEventQueue();

        expect(subscribedTo(30000), isTrue);
        expect(subscribedTo(10000), isTrue);
      },
    );

    test(
      'notifies blocklistVersionProvider listeners when it adopts the '
      'incoming account',
      () async {
        final container = await buildSwitchedInContainer();
        final versions = <int>[];
        container.listen<int>(
          blocklistVersionProvider,
          (_, next) => versions.add(next),
        );

        container.read(blocklistSyncBridgeProvider);
        await pumpEventQueue();

        expect(versions, isNotEmpty);
      },
    );
  });
}
