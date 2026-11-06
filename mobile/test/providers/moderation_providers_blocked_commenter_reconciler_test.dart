// ABOUTME: Tests for the #5044 blocked-commenter reconciler provider.
// ABOUTME: Blocking someone must auto-hide their comments on our videos.

import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockCommentModerationRepository extends Mock
    implements CommentModerationRepository {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this.initial);

  final NostrSessionReadiness initial;

  @override
  NostrSessionReadiness build() => initial;
}

void main() {
  const ourPubkey =
      '0edc2f474484769bc9bf6d471d180e4e280b0bcd719b6da791001beb730cff1b';
  const harasser =
      'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
  const otherHarasser =
      'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';

  late _MockNostrClient nostrClient;
  late _MockCommentModerationRepository moderationRepository;
  late ContentBlocklistRepository blocklistRepository;

  setUpAll(() {
    registerFallbackValue(const <String>[]);
  });

  late SharedPreferences prefs;

  Future<ProviderContainer> createContainer({
    bool sessionReady = true,
    Map<String, Object> storedPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(storedPrefs);
    prefs = await SharedPreferences.getInstance();

    nostrClient = _MockNostrClient();
    when(() => nostrClient.publicKey).thenReturn(ourPubkey);
    when(() => nostrClient.hasKeys).thenReturn(true);
    when(
      () => nostrClient.subscribe(any()),
    ).thenAnswer((_) => const Stream<Event>.empty());

    moderationRepository = _MockCommentModerationRepository();
    when(
      () => moderationRepository.updateAutoHiddenAuthors(
        add: any(named: 'add'),
        remove: any(named: 'remove'),
      ),
    ).thenAnswer((_) async {});

    blocklistRepository = ContentBlocklistRepository(prefs: prefs);
    addTearDown(blocklistRepository.dispose);
    // Adopting the identity scopes the persisted blocks to this account.
    await blocklistRepository.syncMuteListsInBackground(nostrClient, ourPubkey);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        nostrServiceProvider.overrideWithValue(nostrClient),
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
        commentModerationRepositoryProvider.overrideWithValue(
          moderationRepository,
        ),
        nostrSessionProvider.overrideWith(
          () => _TestNostrSession(
            sessionReady
                ? NostrSessionReadiness.nostrReady(
                    pubkey: ourPubkey,
                    client: nostrClient,
                  )
                : const NostrSessionReadiness.identityKnown(pubkey: ourPubkey),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// The `add` and `remove` sets of every update, in order.
  List<(Set<String>, Set<String>)> updates() {
    final captured = verify(
      () => moderationRepository.updateAutoHiddenAuthors(
        add: captureAny(named: 'add'),
        remove: captureAny(named: 'remove'),
      ),
    ).captured;
    return [
      for (var i = 0; i < captured.length; i += 2)
        (
          (captured[i] as Iterable<String>).toSet(),
          (captured[i + 1] as Iterable<String>).toSet(),
        ),
    ];
  }

  void expectUpdate(
    (Set<String>, Set<String>) update, {
    Set<String> add = const {},
    Set<String> remove = const {},
  }) {
    expect(update.$1, equals(add), reason: 'add');
    expect(update.$2, equals(remove), reason: 'remove');
  }

  group('blockedCommenterReconcilerProvider', () {
    test('publishes earlier blocks once the session can sign', () async {
      final container = await createContainer();
      await blocklistRepository.blockUser(harasser, ourPubkey: ourPubkey);

      container.read(blockedCommenterReconcilerProvider);
      await pumpEventQueue();

      final all = updates();
      expect(all, hasLength(1));
      expectUpdate(all.single, add: {harasser});
    });

    test('publishes nothing for an account without blocks', () async {
      final container = await createContainer();

      container.read(blockedCommenterReconcilerProvider);
      await pumpEventQueue();

      verifyNever(
        () => moderationRepository.updateAutoHiddenAuthors(
          add: any(named: 'add'),
          remove: any(named: 'remove'),
        ),
      );
    });

    test('adds a fresh block', () async {
      final container = await createContainer();
      container.read(blockedCommenterReconcilerProvider);
      await pumpEventQueue();

      await blocklistRepository.blockUser(harasser, ourPubkey: ourPubkey);
      await pumpEventQueue();

      expectUpdate(updates().last, add: {harasser});
    });

    test('removes a fresh unblock', () async {
      final container = await createContainer();
      await blocklistRepository.blockUser(harasser, ourPubkey: ourPubkey);
      container.read(blockedCommenterReconcilerProvider);
      await pumpEventQueue();

      await blocklistRepository.unblockUser(harasser);
      await pumpEventQueue();

      expectUpdate(updates().last, remove: {harasser});
    });

    test('retries an unblock whose publish failed', () async {
      final container = await createContainer();
      await blocklistRepository.blockUser(harasser, ourPubkey: ourPubkey);
      container.read(blockedCommenterReconcilerProvider);
      await pumpEventQueue();
      when(
        () => moderationRepository.updateAutoHiddenAuthors(
          add: any(named: 'add'),
          remove: any(named: 'remove'),
        ),
      ).thenThrow(const CommentModerationFailedException('offline'));
      await blocklistRepository.unblockUser(harasser);
      await pumpEventQueue();
      when(
        () => moderationRepository.updateAutoHiddenAuthors(
          add: any(named: 'add'),
          remove: any(named: 'remove'),
        ),
      ).thenAnswer((_) async {});

      await blocklistRepository.blockUser(otherHarasser, ourPubkey: ourPubkey);
      await pumpEventQueue();

      expectUpdate(
        updates().last,
        add: {otherHarasser},
        remove: {harasser},
      );
    });

    group('with an unblock whose publish failed', () {
      /// Blocks and then unblocks the harasser while publishing fails.
      Future<ProviderContainer> failUnblock() async {
        final container = await createContainer();
        await blocklistRepository.blockUser(harasser, ourPubkey: ourPubkey);
        container.read(blockedCommenterReconcilerProvider);
        await pumpEventQueue();
        when(
          () => moderationRepository.updateAutoHiddenAuthors(
            add: any(named: 'add'),
            remove: any(named: 'remove'),
          ),
        ).thenThrow(const CommentModerationFailedException('offline'));
        await blocklistRepository.unblockUser(harasser);
        await pumpEventQueue();
        return container;
      }

      void publishingWorks() => when(
        () => moderationRepository.updateAutoHiddenAuthors(
          add: any(named: 'add'),
          remove: any(named: 'remove'),
        ),
      ).thenAnswer((_) async {});

      test('removes it after a restart', () async {
        final first = await failUnblock();
        final stored = {
          for (final key in prefs.getKeys()) key: prefs.get(key)!,
        };
        first.dispose();

        // The next launch, with what the last one left on disk.
        final container = await createContainer(storedPrefs: stored);
        container.read(blockedCommenterReconcilerProvider);
        await pumpEventQueue();

        expectUpdate(updates().single, remove: {harasser});
        expect(
          prefs.getStringList('$hiddenCommenterRemovalsPrefsPrefix$ourPubkey'),
          isNull,
        );
      });

      test('removes it when the app returns', () async {
        final container = await failUnblock();
        publishingWorks();
        clearInteractions(moderationRepository);

        container.read(appForegroundProvider.notifier).setForeground(false);
        container.read(appForegroundProvider.notifier).setForeground(true);
        await pumpEventQueue();

        expectUpdate(updates().single, remove: {harasser});
      });

      test('forgets it when the account is blocked again', () async {
        await failUnblock();
        publishingWorks();

        await blocklistRepository.blockUser(harasser, ourPubkey: ourPubkey);
        await pumpEventQueue();

        expectUpdate(updates().last, add: {harasser});
        expect(
          prefs.getStringList('$hiddenCommenterRemovalsPrefsPrefix$ourPubkey'),
          isNull,
        );
      });
    });

    test('waits until the session can sign', () async {
      final container = await createContainer(sessionReady: false);
      await blocklistRepository.blockUser(harasser, ourPubkey: ourPubkey);
      container.read(blockedCommenterReconcilerProvider);
      await pumpEventQueue();
      verifyNever(
        () => moderationRepository.updateAutoHiddenAuthors(
          add: any(named: 'add'),
          remove: any(named: 'remove'),
        ),
      );

      container
          .read(nostrSessionProvider.notifier)
          .update(
            NostrSessionReadiness.nostrReady(
              pubkey: ourPubkey,
              client: nostrClient,
            ),
          );
      await pumpEventQueue();

      final all = updates();
      expect(all, hasLength(1));
      expectUpdate(all.single, add: {harasser});
    });
  });
}
