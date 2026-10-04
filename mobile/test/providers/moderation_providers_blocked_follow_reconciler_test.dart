// ABOUTME: Regression tests for the #6903 blocked-follow reconciler provider.
// ABOUTME: Blocking must republish kind 3 without the blocked account.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  const ourPubkey =
      '0edc2f474484769bc9bf6d471d180e4e280b0bcd719b6da791001beb730cff1b';
  const otherAccount =
      '00000000000000000000000000000000000000000000000000000000000000aa';
  const blockedFollow =
      'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
  const otherFollow =
      'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';

  late _MockNostrClient nostrClient;
  late _MockFollowRepository followRepository;
  late ContentBlocklistRepository blocklistRepository;
  late StreamController<List<String>> followingController;
  late List<String> followingPubkeys;
  late Completer<void> initializedCompleter;

  Future<ProviderContainer> createContainer({
    String signingPubkey = ourPubkey,
    bool followsInitialized = true,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    nostrClient = _MockNostrClient();
    when(() => nostrClient.publicKey).thenReturn(signingPubkey);
    when(
      () => nostrClient.subscribe(any()),
    ).thenAnswer((_) => const Stream<Event>.empty());

    followRepository = _MockFollowRepository();
    when(
      () => followRepository.followingPubkeys,
    ).thenAnswer((_) => followingPubkeys);
    when(
      () => followRepository.followingStream,
    ).thenAnswer((_) => followingController.stream);
    when(
      () => followRepository.isInitialized,
    ).thenAnswer((_) => followsInitialized);
    when(
      () => followRepository.initialized,
    ).thenAnswer((_) => initializedCompleter.future);
    when(
      () => followRepository.republishContactList(),
    ).thenAnswer((_) async {});

    blocklistRepository = ContentBlocklistRepository(prefs: prefs);
    addTearDown(blocklistRepository.dispose);
    // Adopting the identity is what scopes the persisted blocks to an
    // account; blockedPubkeysForAccount withholds everything until it runs.
    await blocklistRepository.syncMuteListsInBackground(nostrClient, ourPubkey);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        nostrServiceProvider.overrideWithValue(nostrClient),
        followRepositoryProvider.overrideWithValue(followRepository),
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    followingPubkeys = <String>[];
    followingController = StreamController<List<String>>.broadcast();
    initializedCompleter = Completer<void>()..complete();
  });

  tearDown(() async {
    await followingController.close();
  });

  group('blockedFollowReconcilerProvider', () {
    test('republishes when a followed account is blocked', () async {
      followingPubkeys = <String>[blockedFollow, otherFollow];
      final container = await createContainer();
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await pumpEventQueue();

      verify(() => followRepository.republishContactList()).called(1);
    });

    test(
      'does not republish when the blocked account is not followed',
      () async {
        followingPubkeys = <String>[otherFollow];
        final container = await createContainer();
        container.read(blockedFollowReconcilerProvider);

        await blocklistRepository.blockUser(
          blockedFollow,
          ourPubkey: ourPubkey,
        );
        await pumpEventQueue();

        verifyNever(() => followRepository.republishContactList());
      },
    );

    // The defect this exists for: blocking before the follow list has
    // finished loading — a fresh install, a new sign-in, a cleared cache —
    // leaves nothing to reconcile at block time. The list arriving later is
    // the second chance.
    test('heals a block made before the follow list loaded', () async {
      final container = await createContainer();
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await pumpEventQueue();
      verifyNever(() => followRepository.republishContactList());

      followingPubkeys = <String>[blockedFollow, otherFollow];
      followingController.add(followingPubkeys);
      await pumpEventQueue();

      verify(() => followRepository.republishContactList()).called(1);
    });

    // divine-web keeps whichever kind 3 carries more entries
    // (divinevideo/divine-web#551), so it can resurrect the entry we just
    // dropped. Without the bound the two clients trade publishes forever.
    test('republishes at most once per blocked pubkey per session', () async {
      followingPubkeys = <String>[blockedFollow];
      final container = await createContainer();
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await pumpEventQueue();

      followingController.add(followingPubkeys);
      await pumpEventQueue();
      followingController.add(followingPubkeys);
      await pumpEventQueue();

      verify(() => followRepository.republishContactList()).called(1);
    });

    test('retries on the next trigger when the republish fails', () async {
      followingPubkeys = <String>[blockedFollow];
      final container = await createContainer();
      container.read(blockedFollowReconcilerProvider);

      when(
        () => followRepository.republishContactList(),
      ).thenThrow(Exception('relay unreachable'));
      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await pumpEventQueue();

      when(
        () => followRepository.republishContactList(),
      ).thenAnswer((_) async {});
      followingController.add(followingPubkeys);
      await pumpEventQueue();

      verify(() => followRepository.republishContactList()).called(2);
    });

    // A keepAlive blocklist can still hold account A's blocks while the
    // session signs as B. Reconciling then would rewrite B's follow list
    // from A's data.
    test('does not republish when the signing account is not the one whose '
        'blocks are loaded', () async {
      followingPubkeys = <String>[blockedFollow];
      final container = await createContainer(signingPubkey: otherAccount);
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await pumpEventQueue();
      followingController.add(followingPubkeys);
      await pumpEventQueue();

      verifyNever(() => followRepository.republishContactList());
    });

    // FollowRepository.initialize() emits the LocalStorage snapshot on
    // followingStream seconds before the relay answers. That snapshot can
    // lag or truncate (#6109), and republishing from it would drop every
    // follow it is missing — on the write side, where no merge guard
    // catches it.
    test('does not republish before the relay load has landed', () async {
      followingPubkeys = <String>[blockedFollow, otherFollow];
      initializedCompleter = Completer<void>();
      final container = await createContainer(followsInitialized: false);
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await pumpEventQueue();
      followingController.add(followingPubkeys);
      await pumpEventQueue();

      verifyNever(() => followRepository.republishContactList());
    });

    // A launch where the relay list matches LocalStorage merges without
    // emitting, so both stream triggers stay silent. Initialization
    // completing is what settles a contradiction that was already on disk.
    test(
      'reconciles when initialization completes without an emission',
      () async {
        followingPubkeys = <String>[blockedFollow];
        initializedCompleter = Completer<void>();
        final container = await createContainer(followsInitialized: false);
        await blocklistRepository.blockUser(
          blockedFollow,
          ourPubkey: ourPubkey,
        );
        container.read(blockedFollowReconcilerProvider);

        when(() => followRepository.isInitialized).thenAnswer((_) => true);
        initializedCompleter.complete();
        await pumpEventQueue();

        verify(() => followRepository.republishContactList()).called(1);
      },
    );

    // Subscribing before the block keeps the startup reconcile a no-op, so
    // the only republish that can appear here is one a trigger caused.
    test('does not republish on an unblock', () async {
      followingPubkeys = <String>[blockedFollow];
      final container = await createContainer();
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await pumpEventQueue();

      await blocklistRepository.unblockUser(blockedFollow);
      await pumpEventQueue();

      verify(() => followRepository.republishContactList()).called(1);
    });

    // After unblock, the next follow/unfollow re-includes the pubkey in
    // kind 3. If `settled` still held it, a same-session re-block would
    // skip the republish and leave the public list intact.
    test('republishes again when the same account is re-blocked', () async {
      followingPubkeys = <String>[blockedFollow];
      final container = await createContainer();
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await pumpEventQueue();
      await blocklistRepository.unblockUser(blockedFollow);
      await pumpEventQueue();
      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await pumpEventQueue();

      verify(() => followRepository.republishContactList()).called(2);
    });
  });
}
