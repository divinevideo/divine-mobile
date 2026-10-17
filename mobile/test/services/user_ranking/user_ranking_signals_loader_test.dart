import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_ranking_providers.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:user_ranking/user_ranking.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockMyFollowersDao extends Mock implements MyFollowersDao {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this.initial);

  final NostrSessionReadiness initial;

  @override
  NostrSessionReadiness build() => initial;
}

String _key(int value) => value.toRadixString(16).padLeft(64, '0');

void main() {
  group('UserRankingSignalsLoader', () {
    final viewer = _key(1);
    final mutual = _key(2);
    final followed = _key(3);
    final stranger = _key(4);
    final blocked = _key(5);
    final now = DateTime.utc(2026, 10, 14);
    late AppDatabase database;
    late _MockDmRepository dms;
    late _MockFollowRepository follows;
    late _MockProfileRepository profiles;
    late UserRankingSignalsLoader loader;

    DmConversation conversation(
      String peer, {
      int timestamp = 100,
      bool isGroup = false,
      bool hasSent = true,
    }) => DmConversation(
      id: peer,
      participantPubkeys: [viewer, peer],
      isGroup: isGroup,
      createdAt: 1,
      lastMessageTimestamp: timestamp,
      currentUserHasSent: hasSent,
    );

    UserRankingSignalsLoader createLoader({bool withProfiles = true}) =>
        UserRankingSignalsLoader(
          dmRepository: dms,
          followRepository: follows,
          profileRepository: withProfiles ? profiles : null,
          myFollowersDao: database.myFollowersDao,
          profileStatsDao: database.profileStatsDao,
          nostrEventsDao: database.nostrEventsDao,
          nip05VerificationsDao: database.nip05VerificationsDao,
          currentUserPubkey: viewer,
          isBlocked: (pubkey) => pubkey == blocked,
          now: () => now,
        );

    Future<void> stats(String pubkey, DateTime cachedAt, {int? count}) =>
        database
            .into(database.profileStats)
            .insert(
              ProfileStatRow(
                pubkey: pubkey,
                cachedAt: cachedAt,
                videoCount: count,
              ),
            );

    setUp(() {
      database = AppDatabase.test(NativeDatabase.memory());
      dms = _MockDmRepository();
      follows = _MockFollowRepository();
      profiles = _MockProfileRepository();
      when(() => dms.watchAcceptedConversations()).thenAnswer(
        (_) => Stream.value([]),
      );
      when(() => follows.isFollowing(any())).thenReturn(false);
      when(() => follows.followingPubkeys).thenReturn([]);
      when(() => follows.syncMyFollowers()).thenAnswer((_) async {});
      when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
          .thenAnswer((_) async => []);
      when(() => profiles.refreshStatsForPubkeys(any()))
          .thenAnswer((_) async {});
      loader = createLoader();
    });

    test(
      'cached display names use one eligible local batch and no network',
      () async {
        when(() => profiles.getCachedProfiles(pubkeys: [mutual, stranger]))
            .thenAnswer(
              (_) async => [
                UserProfile(
                  pubkey: mutual,
                  rawData: const {},
                  displayName: 'Zulu',
                  name: 'ignored',
                  createdAt: now,
                  eventId: _key(90),
                ),
                UserProfile(
                  pubkey: stranger,
                  rawData: const {},
                  name: 'alice',
                  createdAt: now,
                  eventId: _key(91),
                ),
                UserProfile(
                  pubkey: blocked,
                  rawData: const {},
                  displayName: 'hidden',
                  createdAt: now,
                  eventId: _key(92),
                ),
              ],
            );
        expect(
          await loader.loadCachedDisplayNames([
            viewer,
            mutual,
            blocked,
            stranger,
            mutual,
          ]),
          {
            mutual: 'Zulu',
            stranger: 'alice',
          },
        );
        verify(() => profiles.getCachedProfiles(pubkeys: [mutual, stranger]))
            .called(1);
        verifyNoMoreInteractions(profiles);
        verifyZeroInteractions(dms);
        verifyZeroInteractions(follows);
      },
    );

    test(
      'snapshots follow membership once without per-candidate lookups',
      () async {
        when(() => follows.followingPubkeys).thenReturn([mutual, followed]);
        final result = await loader.load([mutual, followed, stranger]);
        expect(result[mutual]!.youFollow, isTrue);
        expect(result[stranger]!.youFollow, isFalse);
        verify(() => follows.followingPubkeys).called(1);
        verifyNever(() => follows.isFollowing(any()));
      },
    );

    test(
      'cached display names tolerate an unavailable profile repository',
      () async {
        expect(
          await createLoader(withProfiles: false)
              .loadCachedDisplayNames([mutual]),
          isEmpty,
        );
        verifyZeroInteractions(profiles);
      },
    );

    tearDown(() async => database.close());

    test('preserves invariant errors from parallel local reads', () async {
      when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
          .thenAnswer((_) async => throw StateError('profile invariant'));
      await expectLater(loader.load([followed]), throwsA(isA<StateError>()));
    });

    test(
      'rethrows the invariant error when an earlier read also failed',
      () async {
        final followers = _MockMyFollowersDao();
        when(
          () => followers.followerSubset(
            ownerPubkey: any(named: 'ownerPubkey'),
            candidates: any(named: 'candidates'),
          ),
        ).thenAnswer((_) async => throw Exception('database locked'));
        when(
          () => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
        ).thenAnswer((_) async => throw StateError('profile invariant'));
        final failing = UserRankingSignalsLoader(
          dmRepository: dms,
          followRepository: follows,
          profileRepository: profiles,
          myFollowersDao: followers,
          profileStatsDao: database.profileStatsDao,
          nostrEventsDao: database.nostrEventsDao,
          nip05VerificationsDao: database.nip05VerificationsDao,
          currentUserPubkey: viewer,
          now: () => now,
        );
        await expectLater(failing.load([followed]), throwsA(isA<StateError>()));
      },
    );

    test(
      'builds signals from local relationships, profiles and video cache',
      () async {
        when(() => dms.watchAcceptedConversations()).thenAnswer(
          (_) => Stream.value([conversation(mutual)]),
        );
        when(() => follows.followingPubkeys).thenReturn([mutual, followed]);
        await database.myFollowersDao.upsertAll(
          ownerPubkey: viewer,
          followers: [(pubkey: mutual, followedAt: null)],
          seenAt: 100,
        );
        // Another owner's relationship must not leak into this snapshot.
        await database.myFollowersDao.upsertAll(
          ownerPubkey: stranger,
          followers: [(pubkey: followed, followedAt: null)],
          seenAt: 100,
        );
        await stats(stranger, now.subtract(const Duration(days: 8)), count: 12);
        await database.nip05VerificationsDao.upsertVerification(
          pubkey: stranger,
          nip05: 'creator@example.test',
          status: 'verified',
        );
        when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
            .thenAnswer(
              (_) async => [
                UserProfile(
                  pubkey: stranger,
                  rawData: const {'video_count': 99},
                  createdAt: now,
                  eventId: _key(40),
                ),
                UserProfile(
                  pubkey: followed,
                  rawData: const {'video_count': 7},
                  createdAt: now,
                  eventId: _key(41),
                ),
              ],
            );
        for (final kind in [...NIP71VideoKinds.getAllVideoKinds(), 1, 22]) {
          await database.nostrEventsDao.upsertEvent(
            Event(
              stranger,
              kind,
              [
                ['d', 'video-$kind'],
              ],
              '',
              createdAt: kind == 34236 ? 200 : 999,
            )..sig = '0' * 128,
          );
        }

        final result = await loader.load([mutual, followed, stranger]);

        expect(
          result[mutual],
          UserRankingSignals(
            pubkey: mutual,
            youFollow: true,
            followsYou: true,
            lastInteractionAt: DateTime.fromMillisecondsSinceEpoch(
              100000,
              isUtc: true,
            ),
          ),
        );
        expect(
          result[followed],
          UserRankingSignals(
            pubkey: followed,
            youFollow: true,
            videoCount: 7,
          ),
        );
        expect(
          result[stranger],
          UserRankingSignals(
            pubkey: stranger,
            hasVerifiedNip05: true,
            videoCount: 12,
            lastPostedAt: DateTime.fromMillisecondsSinceEpoch(
              200000,
              isUtc: true,
            ),
          ),
        );
        verifyNever(
          () => profiles.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
        );
        verifyNever(() => profiles.refreshStatsForPubkeys(any()));
        verifyNever(() => follows.syncMyFollowers());
      },
    );

    test(
      'provider rebuilds for identity and repository swaps with block policy',
      () async {
        final blocklist = _MockContentBlocklistRepository();
        when(() => blocklist.shouldFilterFromFeeds(any()))
            .thenAnswer((call) => call.positionalArguments.single == blocked);
        when(() => blocklist.currentState).thenReturn(
          ContentPolicyState(
            currentUserPubkey: viewer,
            mutedPubkeys: const {},
            blockedPubkeys: {blocked},
            pubkeysBlockingUs: const {},
            pubkeysMutingUs: const {},
          ),
        );
        await database.myFollowersDao.upsertAll(
          ownerPubkey: viewer,
          followers: [(pubkey: mutual, followedAt: null)],
          seenAt: 100,
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            dmRepositoryProvider.overrideWithValue(dms),
            followRepositoryProvider.overrideWithValue(follows),
            profileRepositoryProvider.overrideWithValue(null),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(
                NostrSessionReadiness.identityKnown(pubkey: viewer),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.listen(userRankingSignalsLoaderProvider, (_, _) {});
        final first = container.read(userRankingSignalsLoaderProvider);
        final firstSignals = await first.load([
          viewer,
          mutual,
          stranger,
          blocked,
        ]);
        expect(firstSignals.keys, [mutual, stranger]);
        expect(firstSignals[mutual]!.followsYou, isTrue);

        container
            .read(nostrSessionProvider.notifier)
            .update(
              NostrSessionReadiness.identityKnown(pubkey: stranger),
            );
        when(() => blocklist.currentState).thenReturn(
          ContentPolicyState(
            currentUserPubkey: stranger,
            mutedPubkeys: const {},
            blockedPubkeys: {blocked},
            pubkeysBlockingUs: const {},
            pubkeysMutingUs: const {},
          ),
        );
        final second = container.read(userRankingSignalsLoaderProvider);
        expect(second, isNot(same(first)));
        final secondSignals = await second.load([
          viewer,
          mutual,
          stranger,
          blocked,
        ]);
        expect(secondSignals.keys, [viewer, mutual]);
        expect(secondSignals[mutual]!.followsYou, isNull);

        final replacement = _MockFollowRepository();
        when(() => replacement.followingPubkeys)
            .thenReturn([mutual, followed, stranger]);
        container.updateOverrides([
          databaseProvider.overrideWithValue(database),
          dmRepositoryProvider.overrideWithValue(dms),
          followRepositoryProvider.overrideWithValue(replacement),
          profileRepositoryProvider.overrideWithValue(profiles),
          contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          nostrSessionProvider.overrideWith(
            () => _TestNostrSession(
              NostrSessionReadiness.identityKnown(pubkey: stranger),
            ),
          ),
        ]);
        final third = container.read(userRankingSignalsLoaderProvider);
        expect(third, isNot(same(second)));
        expect((await third.load([mutual]))[mutual]!.youFollow, isTrue);
        verify(() => profiles.getCachedProfiles(pubkeys: [mutual])).called(1);
      },
    );

    test(
      'picker eligibility matches policy without copying its state per row',
      () async {
        final ownMute = _key(6);
        final reverseBlock = _key(7);
        final reverseMute = _key(8);
        final state = ContentPolicyState(
          currentUserPubkey: viewer,
          mutedPubkeys: {ownMute},
          blockedPubkeys: {blocked, viewer},
          pubkeysBlockingUs: {reverseBlock},
          pubkeysMutingUs: {reverseMute},
        );
        final blocklist = _MockContentBlocklistRepository();
        when(() => blocklist.currentState).thenReturn(state);
        when(() => blocklist.shouldFilterFromFeeds(any())).thenAnswer((call) {
          final key = call.positionalArguments.single as String;
          return state.blockedPubkeys.contains(key) ||
              state.mutedPubkeys.contains(key) ||
              state.pubkeysBlockingUs.contains(key) ||
              state.pubkeysMutingUs.contains(key);
        });
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            dmRepositoryProvider.overrideWithValue(dms),
            followRepositoryProvider.overrideWithValue(follows),
            profileRepositoryProvider.overrideWithValue(null),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(
                NostrSessionReadiness.identityKnown(pubkey: viewer),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final loader = container.read(userRankingSignalsLoaderProvider);
        final policy = ContentPolicyEngine.defaultRules();
        for (final key in [
          viewer,
          blocked,
          ownMute,
          reverseBlock,
          reverseMute,
          stranger,
        ]) {
          expect(
            loader.isEligible(key),
            key != viewer &&
                policy.evaluate(PolicyInput(pubkey: key), state) is! Block,
          );
        }
        verifyNever(() => blocklist.currentState);
      },
    );

    test(
      'own follow-list loader hides only accounts the viewer blocked',
      () async {
        final muter = _key(6);
        final blocker = _key(7);
        final blocklist = _MockContentBlocklistRepository();
        when(() => blocklist.shouldFilterFromFeeds(any())).thenAnswer(
          (call) => {
            muter,
            blocker,
            blocked,
          }.contains(call.positionalArguments.single),
        );
        when(() => blocklist.currentState).thenReturn(
          ContentPolicyState(
            currentUserPubkey: viewer,
            mutedPubkeys: const {},
            blockedPubkeys: {blocked},
            pubkeysBlockingUs: {blocker},
            pubkeysMutingUs: {muter},
          ),
        );
        when(
          () => blocklist.isBlocked(any()),
        ).thenAnswer((call) => call.positionalArguments.single == blocked);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            dmRepositoryProvider.overrideWithValue(dms),
            followRepositoryProvider.overrideWithValue(follows),
            profileRepositoryProvider.overrideWithValue(null),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(
                NostrSessionReadiness.identityKnown(pubkey: viewer),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final candidates = [muter, blocker, blocked, followed];

        final picker = container.read(userRankingSignalsLoaderProvider);
        expect((await picker.load(candidates)).keys, [followed]);

        final ownList = container.read(
          ownFollowListRankingSignalsLoaderProvider,
        );
        expect((await ownList.load(candidates)).keys, [
          muter,
          blocker,
          followed,
        ]);
      },
    );

    test(
      'fresh loads observe local changes without retaining a snapshot',
      () async {
        final first = await loader.load([stranger]);
        expect(first[stranger]!.videoCount, isNull);
        await stats(stranger, now, count: 8);
        expect((await loader.load([stranger]))[stranger]!.videoCount, 8);
        expect(first[stranger]!.videoCount, isNull);
      },
    );

    test(
      'eligibility excludes self and blocked without reading any stores',
      () {
        expect(loader.isEligible(viewer), isFalse);
        expect(loader.isEligible(blocked), isFalse);
        expect(loader.isEligible(mutual), isTrue);
        expect(loader.isEligible(stranger), isTrue);
        verifyZeroInteractions(dms);
        verifyZeroInteractions(follows);
        verifyZeroInteractions(profiles);
      },
    );

    test(
      'excludes self and blocked accounts, deduplicating candidates',
      () async {
        expect((await loader.load([viewer, blocked, mutual, mutual])).keys, [
          mutual,
        ]);
      },
    );

    test(
      'ignores groups and conversations where the viewer has never sent',
      () async {
        when(() => dms.watchAcceptedConversations()).thenAnswer(
          (_) => Stream.value([
            conversation(mutual, isGroup: true),
            conversation(followed, hasSent: false),
          ]),
        );
        final result = await loader.load([mutual, followed]);
        expect(
          result.values.map((s) => s.lastInteractionAt),
          everyElement(isNull),
        );
      },
    );

    test('uses newest interaction across one-to-one protocols', () async {
      when(() => dms.watchAcceptedConversations()).thenAnswer(
        (_) => Stream.value([
          conversation(mutual),
          conversation(mutual, timestamp: 200),
        ]),
      );
      expect(
        (await loader.load([mutual]))[mutual]!.lastInteractionAt,
        DateTime.fromMillisecondsSinceEpoch(200000, isUtc: true),
      );
    });

    test(
      'does not expand candidates with DM counterparts by default',
      () async {
        when(() => dms.watchAcceptedConversations()).thenAnswer(
          (_) => Stream.value([conversation(mutual)]),
        );
        expect((await loader.load([followed])).keys, [followed]);
      },
    );

    test(
      'opt-in expands qualifying DM counterparts from one snapshot only',
      () async {
        when(() => dms.watchAcceptedConversations()).thenAnswer(
          (_) => Stream.value([
            conversation(mutual),
            conversation(blocked),
            conversation(viewer),
            conversation(stranger, isGroup: true),
            conversation(_key(6), hasSent: false),
          ]),
        );
        final result = await loader.load([
          followed,
        ], includeDmCounterparts: true);
        expect(result.keys, [followed, mutual]);
        expect(result[mutual]!.lastInteractionAt, isNotNull);
        verify(() => dms.watchAcceptedConversations()).called(1);
      },
    );

    test(
      'DM expansion skips a retired moderation key the viewer replied to',
      () async {
        when(() => dms.watchAcceptedConversations()).thenAnswer(
          (_) => Stream.value([
            conversation(kLegacyModerationPubkeys.first),
            conversation(mutual),
          ]),
        );
        final result = await loader.load([], includeDmCounterparts: true);
        expect(result.keys, [mutual]);
      },
    );

    test(
      'empty device returns empty signals, including DM expansion',
      () async {
        expect(await loader.load([]), isEmpty);
        expect(await loader.load([], includeDmCounterparts: true), isEmpty);
        expect(await loader.load([stranger]), {
          stranger: UserRankingSignals(pubkey: stranger),
        });
        verifyNever(() => follows.syncMyFollowers());
        verifyNever(() => profiles.refreshStatsForPubkeys(any()));
      },
    );

    test(
      'a future-dated video does not count as posted just now',
      () async {
        final posted = now.subtract(const Duration(days: 1));
        final dates = [
          posted.millisecondsSinceEpoch ~/ 1000,
          now.add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
        ];
        for (final (index, createdAt) in dates.indexed) {
          await database.nostrEventsDao.upsertEvent(
            Event(
              stranger,
              34236,
              [
                ['d', 'video-$index'],
              ],
              '',
              createdAt: createdAt,
            )..sig = '0' * 128,
          );
        }

        final result = await loader.load([stranger]);

        expect(result[stranger]?.lastPostedAt, posted);
      },
    );

    test('only verified and unexpired NIP-05 rows contribute', () async {
      for (final entry in {
        mutual: 'pending',
        followed: 'failed',
        stranger: 'error',
      }.entries) {
        await database.nip05VerificationsDao.upsertVerification(
          pubkey: entry.key,
          nip05: 'creator@example.test',
          status: entry.value,
        );
      }
      final expired = _key(6);
      await database
          .into(database.nip05Verifications)
          .insert(
            Nip05VerificationRow(
              pubkey: expired,
              nip05: 'expired@example.test',
              status: 'verified',
              verifiedAt: DateTime.utc(2000),
              expiresAt: DateTime.utc(2001),
            ),
          );
      final result = await loader.load([mutual, followed, stranger, expired]);
      expect(
        result.values.map((s) => s.hasVerifiedNip05),
        everyElement(isFalse),
      );
    });

    test('works before profile repository is available', () async {
      await stats(stranger, now, count: 0);
      loader = createLoader(withProfiles: false);
      expect((await loader.load([stranger]))[stranger]!.videoCount, 0);
      loader.refreshInBackground([stranger]);
      await pumpEventQueue();
      verify(() => follows.syncMyFollowers()).called(1);
    });

    test(
      'refreshes only stale or missing stats within first 100 candidates',
      () async {
        final candidates = List.generate(102, (index) => _key(index + 10));
        for (var index = 0; index < 100; index++) {
          if (index == 1) continue; // missing
          await stats(
            candidates[index],
            now.subtract(Duration(days: index == 0 ? 8 : 7)),
          );
        }
        final refreshed = Completer<List<String>>();
        when(() => profiles.refreshStatsForPubkeys(any()))
            .thenAnswer((invocation) async {
              refreshed.complete(
                invocation.positionalArguments.first as List<String>,
              );
            });
        loader.refreshInBackground(candidates);
        expect(await refreshed.future, candidates.take(2));
        verify(() => follows.syncMyFollowers()).called(1);
      },
    );

    test(
      'stats refresh requests stale candidates without their ranked order',
      () async {
        final closest = _key(30);
        final next = _key(20);
        final refreshed = Completer<List<String>>();
        when(() => profiles.refreshStatsForPubkeys(any()))
            .thenAnswer((invocation) async {
              refreshed.complete(
                invocation.positionalArguments.first as List<String>,
              );
            });
        loader.refreshInBackground([closest, next]);
        expect(await refreshed.future, [next, closest]);
      },
    );

    test(
      'empty refresh still syncs followers without requesting stats',
      () async {
        loader.refreshInBackground([]);
        await pumpEventQueue();
        verify(() => follows.syncMyFollowers()).called(1);
        verifyNever(() => profiles.refreshStatsForPubkeys(any()));
      },
    );

    test(
      'observes detached failures independently and preserves loaded signals',
      () async {
        final capture = LogCaptureService();
        await capture.clearAllLogs();
        addTearDown(capture.clearAllLogs);
        final result = await loader.load([stranger]);
        final baseline = Map<String, UserRankingSignals>.of(result);
        when(() => follows.syncMyFollowers())
            .thenAnswer((_) async => throw StateError('sync failed'));
        when(() => profiles.refreshStatsForPubkeys(any()))
            .thenAnswer((_) async => throw StateError('stats failed'));
        loader.refreshInBackground([stranger]);
        await pumpEventQueue();
        verify(() => follows.syncMyFollowers()).called(1);
        verify(() => profiles.refreshStatsForPubkeys([stranger])).called(1);
        expect(result, baseline);
        final logs = capture
            .getRecentLogs()
            .where((entry) => entry.name == 'UserRankingSignalsLoader')
            .toList();
        expect(
          logs.map((entry) => entry.message),
          unorderedEquals([
            'Failed to refresh ranking followers: Bad state: sync failed',
            'Failed to refresh ranking profile stats: Bad state: stats failed',
          ]),
        );
        for (final entry in logs) {
          expect(entry.category, LogCategory.system);
          expect(entry.level, LogLevel.error);
          expect(entry.error, isNotNull);
          expect(entry.stackTrace, isNotNull);
        }
      },
    );
  });
}
