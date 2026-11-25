// ABOUTME: Tests for ShareSheetBloc
// ABOUTME: Verifies contact loading, recipient selection, send-with-message,
// ABOUTME: copy-link, and share-via action flows

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:file/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:user_ranking/user_ranking.dart';

class _MockVideoSharingService extends Mock implements VideoSharingService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockRankingSignalsLoader extends Mock
    implements UserRankingSignalsLoader {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockFile extends Mock implements File {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

  group(ShareSheetBloc, () {
    late _MockVideoSharingService mockSharingService;
    late _MockProfileRepository mockProfileRepository;
    late _MockFollowRepository mockFollowRepository;
    late _MockRankingSignalsLoader mockRankingSignalsLoader;
    late VideoEvent testVideo;

    const testRecipient = ShareableUser(
      pubkey:
          'aaaa456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      displayName: 'Alice',
      picture: 'https://example.com/alice.png',
    );

    const currentUserPubkey =
        'facade00facade00facade00facade00facade00facade00facade00facade00';

    const viewerAsRecipient = ShareableUser(
      pubkey: currentUserPubkey,
      displayName: 'Me',
      picture: 'https://example.com/me.png',
    );

    setUp(() {
      mockSharingService = _MockVideoSharingService();
      when(() => mockSharingService.shortenExternalUrl(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as String,
      );
      mockProfileRepository = _MockProfileRepository();
      mockFollowRepository = _MockFollowRepository();
      mockRankingSignalsLoader = _MockRankingSignalsLoader();
      when(() => mockRankingSignalsLoader.isEligible(any())).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.first != currentUserPubkey,
      );
      when(
        () => mockRankingSignalsLoader.load(
          any(),
          includeDmCounterparts: true,
        ),
      ).thenAnswer((invocation) async {
        final keys = invocation.positionalArguments.first as Iterable<String>;
        return {
          for (final (index, key) in keys.indexed)
            if (key != currentUserPubkey)
              key: UserRankingSignals(
                pubkey: key,
                lastInteractionAt: DateTime.utc(2026).subtract(
                  Duration(days: index),
                ),
              ),
        };
      });

      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );

      // Default stubs
      when(() => mockSharingService.recentlySharedWith).thenReturn([]);
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => <String, UserProfile>{});
      when(
        () => mockProfileRepository.getCachedProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => <UserProfile>[]);
    });

    ShareSheetBloc createBloc({
      FollowRepository? followRepository,
      BaseCacheManager? cacheManager,
      bool Function()? isOwnerCurrent,
    }) => ShareSheetBloc(
      video: testVideo,
      videoSharingService: mockSharingService,
      profileRepository: mockProfileRepository,
      followRepository: followRepository ?? mockFollowRepository,
      rankingSignalsLoader: mockRankingSignalsLoader,
      currentUserPubkey: currentUserPubkey,
      cacheManager: cacheManager,
      isOwnerCurrent: isOwnerCurrent,
    );

    test('initial state is correct', () async {
      final bloc = createBloc();
      expect(bloc.state.status, equals(ShareSheetStatus.initial));
      expect(bloc.state.contacts, isEmpty);
      expect(bloc.state.selectedRecipients, isEmpty);
      expect(bloc.state.isSending, isFalse);
      expect(bloc.state.actionResult, isNull);
      await bloc.close();
    });

    // -----------------------------------------------------------------------
    // Contact loading
    // -----------------------------------------------------------------------

    group('contact ranking', () {
      final alice = 'a' * 64;
      final bob = 'b' * 64;
      final carol = 'c' * 64;
      final dave = 'd' * 64;

      UserProfile profile(String key, String name) => UserProfile(
        pubkey: key,
        createdAt: DateTime.utc(2026),
        eventId: 'e' * 64,
        rawData: const {},
        name: name,
      );

      void signals(Map<String, UserRankingSignals> snapshot) {
        when(
          () => mockRankingSignalsLoader.load(
            any(),
            includeDmCounterparts: true,
          ),
        ).thenAnswer((_) async => snapshot);
      }

      TypeMatcher<ShareSheetState> readyWith(List<String> keys) =>
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.map((c) => c.pubkey), 'contacts', keys);

      setUp(() {
        when(() => mockFollowRepository.followingPubkeys)
            .thenReturn([alice, bob, carol, dave]);
        when(
          () => mockProfileRepository.getCachedProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer(
          (_) async => [
            profile(alice, 'Alice'),
            profile(bob, 'Bob'),
            profile(carol, 'Carol'),
            profile(dave, 'Dave'),
          ],
        );
      });

      blocTest<ShareSheetBloc, ShareSheetState>(
        'contacts are ordered by last DM, then score',
        setUp: () => signals({
          alice: UserRankingSignals(pubkey: alice, followsYou: true),
          bob: UserRankingSignals(
            pubkey: bob,
            lastInteractionAt: DateTime.utc(2026, 1, 2),
          ),
          carol: UserRankingSignals(
            pubkey: carol,
            lastInteractionAt: DateTime.utc(2026, 1, 3),
          ),
          dave: UserRankingSignals(pubkey: dave, youFollow: true),
        }),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          readyWith([carol, bob, dave, alice]),
        ],
        verify: (bloc) {
          verify(
            () => mockRankingSignalsLoader.load(
              [alice, bob, carol, dave],
              includeDmCounterparts: true,
            ),
          ).called(1);
          verify(
            () => mockRankingSignalsLoader.refreshInBackground(
              [carol, bob, dave, alice],
            ),
          ).called(1);
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'looks up uncached contacts in key order, not closeness order',
        setUp: () {
          signals({
            alice: UserRankingSignals(pubkey: alice, followsYou: true),
            bob: UserRankingSignals(
              pubkey: bob,
              lastInteractionAt: DateTime.utc(2026, 1, 2),
            ),
            carol: UserRankingSignals(
              pubkey: carol,
              lastInteractionAt: DateTime.utc(2026, 1, 3),
            ),
            dave: UserRankingSignals(pubkey: dave, youFollow: true),
          });
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <UserProfile>[]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        verify: (bloc) {
          verify(
            () => mockRankingSignalsLoader.refreshInBackground(
              [carol, bob, dave, alice],
            ),
          ).called(1);
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: [alice, bob, carol, dave],
            ),
          ).called(1);
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'ties use cached names',
        setUp: () {
          signals({
            alice: UserRankingSignals(pubkey: alice),
            bob: UserRankingSignals(pubkey: bob),
          });
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => [
              profile(alice, 'Zebra'),
              profile(bob, 'Alpha'),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          readyWith([bob, alice]),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'ties use pubkeys for absent names',
        setUp: () {
          signals({
            alice: UserRankingSignals(pubkey: alice),
            bob: UserRankingSignals(pubkey: bob),
          });
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => [profile(bob, 'A')]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          readyWith([bob, alice]),
          readyWith([bob]),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'an account with no follows still includes a DM-only counterpart',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          signals({
            bob: UserRankingSignals(
              pubkey: bob,
              lastInteractionAt: DateTime.utc(2026),
            ),
          });
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          readyWith([bob]),
        ],
        verify: (_) {
          verify(
            () => mockRankingSignalsLoader.load(
              <String>{},
              includeDmCounterparts: true,
            ),
          ).called(1);
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'recent shares stay first and unfollowed DM counterparts appear once',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn([alice]);
          when(() => mockSharingService.recentlySharedWith).thenReturn([
            ShareableUser(pubkey: alice, displayName: 'Recent Alice'),
          ]);
          signals({
            alice: UserRankingSignals(pubkey: alice),
            bob: UserRankingSignals(
              pubkey: bob,
              lastInteractionAt: DateTime.utc(2026, 1, 3),
            ),
          });
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          readyWith([alice, bob]).having(
            (s) => s.contacts.first.displayName,
            'recent identity',
            'Recent Alice',
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'successful signal keys exclude blocked recent shares and self',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([
            viewerAsRecipient,
            ShareableUser(pubkey: bob, displayName: 'Blocked'),
          ]);
          when(() => mockFollowRepository.followingPubkeys)
              .thenReturn([currentUserPubkey, alice, bob]);
          signals({alice: UserRankingSignals(pubkey: alice)});
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          readyWith([alice]),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'successful empty signals never restore excluded recent shares',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([
            ShareableUser(pubkey: bob, displayName: 'Blocked'),
          ]);
          signals({});
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          readyWith([]),
        ],
      );

      for (final source in ['follows', 'recents']) {
        for (final snapshotFails in [false, true]) {
          final retired = kLegacyModerationPubkeys.first;
          final failure = Exception('local signal read failed');
          blocTest<ShareSheetBloc, ShareSheetState>(
            'excludes retired moderation $source when signals '
            '${snapshotFails ? 'fail' : 'load'}',
            setUp: () {
              when(() => mockFollowRepository.followingPubkeys).thenReturn([
                alice,
                if (source == 'follows') retired,
              ]);
              when(() => mockSharingService.recentlySharedWith).thenReturn([
                if (source == 'recents')
                  ShareableUser(pubkey: retired, displayName: 'Retired'),
              ]);
              when(
                () => mockProfileRepository.getCachedProfiles(
                  pubkeys: any(named: 'pubkeys'),
                ),
              ).thenAnswer(
                (_) async => [
                  profile(alice, 'Alice'),
                  profile(retired, 'Retired'),
                ],
              );
              if (snapshotFails) {
                when(
                  () => mockRankingSignalsLoader.load(
                    any(),
                    includeDmCounterparts: true,
                  ),
                ).thenThrow(failure);
              }
            },
            build: createBloc,
            act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
            expect: () => [
              const ShareSheetState(status: ShareSheetStatus.loading),
              readyWith([alice]),
            ],
            errors: () => [if (snapshotFails) failure],
          );
        }
      }

      final fallbackFailure = Exception('local signal read failed');
      blocTest<ShareSheetBloc, ShareSheetState>(
        'throwing loader fallback excludes blocked recent shares and followed contacts',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([
            ShareableUser(pubkey: bob, displayName: 'Blocked recent'),
            ShareableUser(pubkey: dave, displayName: 'Eligible recent'),
          ]);
          when(() => mockFollowRepository.followingPubkeys)
              .thenReturn([alice, carol]);
          when(
            () => mockRankingSignalsLoader.load(
              any(),
              includeDmCounterparts: true,
            ),
          ).thenThrow(fallbackFailure);
          when(() => mockRankingSignalsLoader.isEligible(alice))
              .thenReturn(false);
          when(() => mockRankingSignalsLoader.isEligible(bob))
              .thenReturn(false);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          readyWith([dave, carol]),
        ],
        errors: () => [fallbackFailure],
        verify: (bloc) {
          verify(
            () => mockProfileRepository.getCachedProfiles(pubkeys: [carol]),
          ).called(1);
          verify(
            () => mockRankingSignalsLoader.refreshInBackground([dave, carol]),
          ).called(1);
        },
      );

      for (final error in [
        Exception('local read failed'),
        StateError('invariant'),
        RangeError('index'),
      ]) {
        blocTest<ShareSheetBloc, ShareSheetState>(
          'ranking load $error falls back to old order and adds classified error',
          setUp: () {
            when(() => mockSharingService.recentlySharedWith).thenReturn([
              ShareableUser(pubkey: dave, displayName: 'Recent Dave'),
            ]);
            when(
              () => mockRankingSignalsLoader.load(
                any(),
                includeDmCounterparts: true,
              ),
            ).thenThrow(error);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
          expect: () => [
            const ShareSheetState(status: ShareSheetStatus.loading),
            readyWith([dave, alice, bob, carol]),
          ],
          errors: () => [
            if (error is StateError || error is RangeError)
              isA<Reportable<Object>>().having(
                (e) => e.unwrap(),
                'unwrap',
                same(error),
              )
            else
              same(error),
          ],
        );
      }

      test(
        'hydration keeps existing order and a picked contact stays first',
        () async {
          final hydration = Completer<Map<String, UserProfile>>();
          when(() => mockFollowRepository.followingPubkeys)
              .thenReturn([alice, bob]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => [profile(alice, 'Alpha')]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => hydration.future);
          signals({
            alice: UserRankingSignals(pubkey: alice),
            bob: UserRankingSignals(pubkey: bob),
          });
          final bloc = createBloc();
          when(() => mockRankingSignalsLoader.refreshInBackground(any()))
              .thenAnswer((_) {
                expect(bloc.state.status, ShareSheetStatus.ready);
                expect(bloc.state.contacts.map((c) => c.pubkey), [alice, bob]);
                verifyNever(
                  () => mockProfileRepository.fetchBatchProfiles(
                    pubkeys: any(named: 'pubkeys'),
                  ),
                );
              });
          bloc.add(const ShareSheetContactsLoadRequested());
          await bloc.stream.firstWhere(
            (s) => s.status == ShareSheetStatus.ready,
          );
          expect(bloc.state.contacts.map((c) => c.pubkey), [alice, bob]);
          bloc.add(
            ShareSheetRecipientToggled(
              ShareableUser(pubkey: carol, displayName: 'Picked Carol'),
            ),
          );
          await pumpEventQueue();
          expect(bloc.state.contacts.map((c) => c.pubkey), [carol, alice, bob]);
          hydration.complete({bob: profile(bob, 'Zebra')});
          await pumpEventQueue();
          expect(bloc.state.contacts.map((c) => c.pubkey), [carol, alice, bob]);
          expect(bloc.state.contacts[2].displayName, 'Zebra');
          expect(bloc.state.selectedRecipients.single.pubkey, carol);
          await bloc.close();
        },
      );
    });

    group('excludes the current user (#8351)', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'omits the viewer from contacts when their contact list self-follows',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn([
            currentUserPubkey,
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => [
              UserProfile(
                pubkey: currentUserPubkey,
                createdAt: DateTime.now(),
                eventId: 'event-self',
                rawData: const {},
                name: 'Me',
              ),
              UserProfile(
                pubkey:
                    'bbbb456789abcdef0123456789abcdef0123456789abcdef'
                    '0123456789abcdef',
                createdAt: DateTime.now(),
                eventId: 'event-bob',
                rawData: const {},
                name: 'Bob',
              ),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        verify: (bloc) {
          expect(
            bloc.state.contacts.map((c) => c.pubkey),
            isNot(contains(currentUserPubkey)),
          );
          expect(bloc.state.contacts, isNotEmpty);
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'omits the viewer from the recently-shared-with row',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenReturn([viewerAsRecipient, testRecipient]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        verify: (bloc) {
          expect(
            bloc.state.contacts.map((c) => c.pubkey),
            [testRecipient.pubkey],
          );
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'ignores a Find People selection that resolves to the viewer',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetRecipientToggled(viewerAsRecipient)),
        expect: () => <ShareSheetState>[],
      );
    });

    group('ShareSheetContactsLoadRequested', () {
      const profiledFollow =
          'cccc456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const unprofiledFollow =
          'dddd456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits [loading, ready] with empty contacts when no follows or recents',
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          const ShareSheetState(status: ShareSheetStatus.ready),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits contacts from recent users and follow list',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenReturn([testRecipient]);
          when(() => mockFollowRepository.followingPubkeys).thenReturn([
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having(
                (s) => s.contacts.first.pubkey,
                'first contact pubkey',
                testRecipient.pubkey,
              ),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1)
              .having(
                (s) => s.contacts.first.pubkey,
                'first contact pubkey',
                testRecipient.pubkey,
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits ready with empty contacts on error',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenThrow(Exception('network failure'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          const ShareSheetState(status: ShareSheetStatus.ready),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'loads without follow repository when null',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenReturn([testRecipient]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'renders cached profiles immediately, then re-emits after hydration',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow, unprofiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => [
              UserProfile(
                pubkey: profiledFollow,
                createdAt: DateTime.now(),
                eventId: 'event-$profiledFollow',
                rawData: const {},
                name: 'CachedAlice',
              ),
            ],
          );
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => {
              unprofiledFollow: UserProfile(
                pubkey: unprofiledFollow,
                createdAt: DateTime.now(),
                eventId: 'event-$unprofiledFollow',
                rawData: const {},
                name: 'HydratedBob',
              ),
            },
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          // Cache-first render: the Drift-cached name shows now; the uncached
          // follow is present as a pending, non-interactive skeleton row rather
          // than blocking the whole row.
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having(
                (s) => s.contacts[0].displayName,
                'first contact name',
                'CachedAlice',
              )
              .having(
                (s) => s.contacts[1].displayName,
                'second contact name',
                isNull,
              ),
          // Hydration re-emit: misses filled in from the network batch.
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having(
                (s) => s.contacts[0].displayName,
                'first contact name',
                'CachedAlice',
              )
              .having(
                (s) => s.contacts[1].displayName,
                'second contact name',
                'HydratedBob',
              ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: [profiledFollow, unprofiledFollow],
            ),
          ).called(1);
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: [unprofiledFollow],
            ),
          ).called(1);
        },
      );

      late Completer<List<UserProfile>> cacheRead;
      late Completer<Map<String, UserProfile>> hydration;

      blocTest<ShareSheetBloc, ShareSheetState>(
        'preserves a find-people recipient picked during the cache read',
        setUp: () {
          cacheRead = Completer<List<UserProfile>>();
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => cacheRead.future);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <String, UserProfile>{});
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ShareSheetContactsLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const ShareSheetRecipientToggled(
              ShareableUser(
                pubkey: 'zzzz56789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                displayName: 'Picked Stranger',
              ),
            ),
          );
          await pumpEventQueue();
          cacheRead.complete([
            UserProfile(
              pubkey: profiledFollow,
              createdAt: DateTime.now(),
              eventId: 'event-$profiledFollow',
              rawData: const {},
              name: 'CachedAlice',
            ),
          ]);
          await pumpEventQueue();
        },
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.loading)
              .having(
                (s) => s.contacts.first.displayName,
                'picked first while loading',
                'Picked Stranger',
              )
              .having((s) => s.selectedRecipients.length, 'selected', 1),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having(
                (s) => s.contacts.map((c) => c.displayName).toList(),
                'row contents',
                ['Picked Stranger', 'CachedAlice'],
              )
              .having((s) => s.selectedRecipients.length, 'selected', 1),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'preserves a find-people-added recipient through the hydration re-emit',
        setUp: () {
          hydration = Completer<Map<String, UserProfile>>();
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <UserProfile>[]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => hydration.future);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ShareSheetContactsLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const ShareSheetRecipientToggled(
              ShareableUser(
                pubkey: 'zzzz56789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                displayName: 'Picked Stranger',
              ),
            ),
          );
          await pumpEventQueue();
          hydration.complete({
            profiledFollow: UserProfile(
              pubkey: profiledFollow,
              createdAt: DateTime.now(),
              eventId: 'event-$profiledFollow',
              rawData: const {},
              name: 'HydratedAlice',
            ),
          });
        },
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>().having(
            (s) => s.status,
            'status',
            ShareSheetStatus.ready,
          ),
          // The toggle prepends the pick while retaining the pending row.
          isA<ShareSheetState>()
              .having(
                (s) => s.contacts.first.displayName,
                'picked prepended',
                'Picked Stranger',
              )
              .having((s) => s.selectedRecipients.length, 'selected', 1),
          // Hydration re-emit must not drop them from the row or the selection.
          isA<ShareSheetState>()
              .having(
                (s) => s.contacts.first.displayName,
                'picked still first',
                'Picked Stranger',
              )
              .having((s) => s.selectedRecipients.length, 'selected', 1)
              .having(
                (s) => s.contacts.map((c) => c.displayName).toList(),
                'row contents',
                ['Picked Stranger', 'HydratedAlice'],
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'keeps a deselected find-people recipient visible through hydration',
        setUp: () {
          hydration = Completer<Map<String, UserProfile>>();
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <UserProfile>[]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => hydration.future);
        },
        build: createBloc,
        act: (bloc) async {
          const picked = ShareableUser(
            pubkey: 'zzzz56789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            displayName: 'Picked Stranger',
          );
          bloc.add(const ShareSheetContactsLoadRequested());
          await pumpEventQueue();
          bloc.add(const ShareSheetRecipientToggled(picked));
          await pumpEventQueue();
          bloc.add(const ShareSheetRecipientToggled(picked));
          await pumpEventQueue();
          hydration.complete({
            profiledFollow: UserProfile(
              pubkey: profiledFollow,
              createdAt: DateTime.now(),
              eventId: 'event-$profiledFollow',
              rawData: const {},
              name: 'HydratedAlice',
            ),
          });
        },
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>().having(
            (s) => s.status,
            'status',
            ShareSheetStatus.ready,
          ),
          isA<ShareSheetState>()
              .having(
                (s) => s.contacts.first.displayName,
                'picked prepended',
                'Picked Stranger',
              )
              .having((s) => s.selectedRecipients.length, 'selected', 1),
          isA<ShareSheetState>()
              .having(
                (s) => s.contacts.first.displayName,
                'picked remains visible',
                'Picked Stranger',
              )
              .having((s) => s.selectedRecipients, 'selected', isEmpty),
          isA<ShareSheetState>()
              .having((s) => s.selectedRecipients, 'selected', isEmpty)
              .having(
                (s) => s.contacts.map((c) => c.displayName).toList(),
                'row contents',
                ['Picked Stranger', 'HydratedAlice'],
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'preserves find-people row order through hydration',
        setUp: () {
          hydration = Completer<Map<String, UserProfile>>();
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <UserProfile>[]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => hydration.future);
        },
        build: createBloc,
        act: (bloc) async {
          const firstPicked = ShareableUser(
            pubkey: 'yyyy56789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            displayName: 'Picked First',
          );
          const secondPicked = ShareableUser(
            pubkey: 'zzzz56789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            displayName: 'Picked Second',
          );
          bloc.add(const ShareSheetContactsLoadRequested());
          await pumpEventQueue();
          bloc.add(const ShareSheetRecipientToggled(firstPicked));
          await pumpEventQueue();
          bloc.add(const ShareSheetRecipientToggled(secondPicked));
          await pumpEventQueue();
          hydration.complete({
            profiledFollow: UserProfile(
              pubkey: profiledFollow,
              createdAt: DateTime.now(),
              eventId: 'event-$profiledFollow',
              rawData: const {},
              name: 'HydratedAlice',
            ),
          });
        },
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>().having(
            (s) => s.status,
            'status',
            ShareSheetStatus.ready,
          ),
          isA<ShareSheetState>().having(
            (s) => s.contacts.map((c) => c.displayName).toList(),
            'row contents',
            ['Picked First', null],
          ),
          isA<ShareSheetState>().having(
            (s) => s.contacts.map((c) => c.displayName).toList(),
            'row contents',
            ['Picked Second', 'Picked First', null],
          ),
          isA<ShareSheetState>().having(
            (s) => s.contacts.map((c) => c.displayName).toList(),
            'row contents',
            ['Picked Second', 'Picked First', 'HydratedAlice'],
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'keeps the cache-first render when background hydration fails',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow, unprofiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => [
              UserProfile(
                pubkey: profiledFollow,
                createdAt: DateTime.now(),
                eventId: 'event-$profiledFollow',
                rawData: const {},
                name: 'CachedAlice',
              ),
            ],
          );
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenThrow(Exception('relay storm down'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          // The failure must not erase what was already on screen.
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having(
                (s) => s.contacts[0].displayName,
                'first contact name',
                'CachedAlice',
              )
              .having(
                (s) => s.contacts[1].displayName,
                'second contact name',
                isNull,
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'drops unresolved cache misses after hydration returns no profile',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([unprofiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <UserProfile>[]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <String, UserProfile>{});
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1)
              .having(
                (s) => s.contacts[0].displayName,
                'contact name',
                isNull,
              ),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts, 'contacts', isEmpty),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: [unprofiledFollow],
            ),
          ).called(1);
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'loads follow profiles via one fetchBatchProfiles call, no per-pubkey '
        'storm',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow, unprofiledFollow]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => {
              profiledFollow: UserProfile(
                pubkey: profiledFollow,
                createdAt: DateTime.now(),
                eventId: 'event-$profiledFollow',
                rawData: const {},
                name: 'Bob',
              ),
            },
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2),
          // The hydration re-emit lands when it changes what is on screen.
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1)
              .having((s) => s.contacts[0].displayName, 'hydrated name', 'Bob'),
        ],
        verify: (_) {
          // Exactly one network batch covering both follows, in order — the
          // per-pubkey getCachedProfile/fetchFreshProfile storm is gone.
          final captured = verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: captureAny(named: 'pubkeys'),
            ),
          ).captured;
          expect(captured, hasLength(1));
          expect(captured.single, [profiledFollow, unprofiledFollow]);
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );
    });

    group('contact deduplication', () {
      const duplicatePubkey =
          'aaaa456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      blocTest<ShareSheetBloc, ShareSheetState>(
        'deduplicates contacts when pubkey appears in both recents and follows',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([
            const ShareableUser(
              pubkey: duplicatePubkey,
              displayName: 'Alice (recent)',
            ),
          ]);
          when(() => mockFollowRepository.followingPubkeys).thenReturn([
            duplicatePubkey,
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having(
                (s) => s.contacts.first.displayName,
                'first is from recents',
                'Alice (recent)',
              )
              .having(
                (s) =>
                    s.contacts.where((c) => c.pubkey == duplicatePubkey).length,
                'no duplicate pubkey',
                1,
              ),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1)
              .having(
                (s) => s.contacts.first.displayName,
                'first is from recents',
                'Alice (recent)',
              )
              .having(
                (s) =>
                    s.contacts.where((c) => c.pubkey == duplicatePubkey).length,
                'no duplicate pubkey',
                1,
              ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Recipient selection
    // -----------------------------------------------------------------------

    group('ShareSheetRecipientToggled', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'ignores a Find People selection of a retired moderation account',
        build: createBloc,
        act: (bloc) => bloc.add(
          ShareSheetRecipientToggled(
            ShareableUser(
              pubkey: kLegacyModerationPubkeys.first,
              displayName: 'Retired',
            ),
          ),
        ),
        expect: () => <ShareSheetState>[],
      );

      const otherRecipient = ShareableUser(
        pubkey:
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        displayName: 'Bob',
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'adds an unselected contact to the selection without reordering '
        'contacts',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          contacts: [otherRecipient, testRecipient],
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetRecipientToggled(testRecipient)),
        expect: () => [
          isA<ShareSheetState>()
              .having(
                (s) => s.selectedRecipients.map((r) => r.pubkey),
                'selected pubkeys',
                [testRecipient.pubkey],
              )
              .having(
                (s) => s.contacts.first.pubkey,
                'first contact unchanged',
                otherRecipient.pubkey,
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'accumulates multiple selected recipients in tap order',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          contacts: [testRecipient, otherRecipient],
        ),
        build: createBloc,
        act: (bloc) => bloc
          ..add(const ShareSheetRecipientToggled(testRecipient))
          ..add(const ShareSheetRecipientToggled(otherRecipient)),
        skip: 1,
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.selectedRecipients.map((r) => r.pubkey),
            'selected pubkeys',
            [testRecipient.pubkey, otherRecipient.pubkey],
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'removes an already-selected recipient, keeping the others',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          contacts: [testRecipient, otherRecipient],
          selectedRecipients: [testRecipient, otherRecipient],
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetRecipientToggled(testRecipient)),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.selectedRecipients.map((r) => r.pubkey),
            'selected pubkeys',
            [otherRecipient.pubkey],
          ),
        ],
      );

      final longContactRow = List.generate(
        40,
        (index) => ShareableUser(
          pubkey: (index + 1).toRadixString(16).padLeft(64, '0'),
          displayName: 'Contact $index',
        ),
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'new Find People pick appears first in a long contact row',
        seed: () => ShareSheetState(
          status: ShareSheetStatus.ready,
          contacts: longContactRow,
          selectedRecipients: [longContactRow[10]],
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetRecipientToggled(testRecipient)),
        expect: () => [
          isA<ShareSheetState>()
              .having((s) => s.contacts.map((c) => c.pubkey), 'contacts', [
                testRecipient.pubkey,
                ...longContactRow.map((c) => c.pubkey),
              ])
              .having(
                (s) => s.selectedRecipients.map((c) => c.pubkey),
                'selection',
                [longContactRow[10].pubkey, testRecipient.pubkey],
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'prepends a Find People pick without reordering existing contacts',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          contacts: [otherRecipient],
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetRecipientToggled(testRecipient)),
        expect: () => [
          isA<ShareSheetState>()
              .having(
                (s) => s.selectedRecipients.map((r) => r.pubkey),
                'selected pubkeys',
                [testRecipient.pubkey],
              )
              .having((s) => s.contacts.map((c) => c.pubkey), 'contacts', [
                testRecipient.pubkey,
                otherRecipient.pubkey,
              ]),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Send with message
    // -----------------------------------------------------------------------

    group('ShareSheetSendRequested', () {
      const otherRecipient = ShareableUser(
        pubkey:
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        displayName: 'Bob',
      );

      void stubMultiSend(Map<String, ShareResult> results) {
        when(
          () => mockSharingService.shareVideoWithMultipleUsers(
            video: any(named: 'video'),
            recipientPubkeys: any(named: 'recipientPubkeys'),
            personalMessage: any(named: 'personalMessage'),
          ),
        ).thenAnswer((_) async => results);
      }

      test(
        'a pending batch cannot confirm twice or report to a new account',
        () async {
          var ownerCurrent = true;
          final sheet = createBloc(isOwnerCurrent: () => ownerCurrent);
          addTearDown(sheet.close);
          final selected = sheet.stream.firstWhere(
            (s) => s.selectedRecipients.isNotEmpty,
          );
          sheet.add(const ShareSheetRecipientToggled(testRecipient));
          await selected;
          final started = Completer<void>();
          final commit = Completer<Map<String, ShareResult>>();
          when(
            () => mockSharingService.shareVideoWithMultipleUsers(
              video: any(named: 'video'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
              personalMessage: any(named: 'personalMessage'),
            ),
          ).thenAnswer((_) {
            started.complete();
            return commit.future;
          });
          sheet.add(const ShareSheetSendRequested(message: 'original note'));
          await started.future;
          expect(sheet.state.isSending, isTrue);
          expect(sheet.state.actionResult, isNull);
          sheet.add(const ShareSheetSendRequested(message: 'duplicate tap'));
          await pumpEventQueue();
          ownerCurrent = false;
          final changed = sheet.stream.firstWhere(
            (s) => s.actionResult != null,
          );
          commit.complete({
            testRecipient.pubkey: const ShareResult.queued('rumor', 'chat'),
          });
          expect((await changed).actionResult, isA<ShareSheetAccountChanged>());
          verify(
            () => mockSharingService.shareVideoWithMultipleUsers(
              video: testVideo,
              recipientPubkeys: [testRecipient.pubkey],
              personalMessage: 'original note',
            ),
          ).called(1);
          verifyNever(
            () => mockSharingService.shareVideoWithMultipleUsers(
              video: testVideo,
              recipientPubkeys: [testRecipient.pubkey],
              personalMessage: 'duplicate tap',
            ),
          );
        },
      );

      const twoSelected = ShareSheetState(
        status: ShareSheetStatus.ready,
        selectedRecipients: [testRecipient, otherRecipient],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'returns owner, rumor and conversation for each queued recipient',
        setUp: () => stubMultiSend({
          testRecipient.pubkey: const ShareResult.queued('rumor-a', 'chat-a'),
          otherRecipient.pubkey: const ShareResult.queued('rumor-b', 'chat-b'),
        }),
        seed: () => twoSelected,
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested(message: 'yo')),
        expect: () => [
          isA<ShareSheetState>().having((s) => s.isSending, 'is sending', true),
          isA<ShareSheetState>()
              .having((s) => s.selectedRecipients, 'selection cleared', isEmpty)
              .having(
                (s) => s.actionResult,
                'durable results',
                isA<ShareSheetEnqueueResult>()
                    .having((r) => r.ownerPubkey, 'owner', currentUserPubkey)
                    .having(
                      (r) => r.recipients.map(
                        (p) => (
                          p.name,
                          p.outcome.rumorId,
                          p.outcome.conversationId,
                        ),
                      ),
                      'recipients',
                      [
                        ('Alice', 'rumor-a', 'chat-a'),
                        ('Bob', 'rumor-b', 'chat-b'),
                      ],
                    ),
              ),
        ],
        verify: (_) {
          verify(
            () => mockSharingService.shareVideoWithMultipleUsers(
              video: testVideo,
              recipientPubkeys: [testRecipient.pubkey, otherRecipient.pubkey],
              personalMessage: 'yo',
            ),
          ).called(1);
        },
      );

      for (final missing in [false, true]) {
        blocTest<ShareSheetBloc, ShareSheetState>(
          'names both recipients when one is queued and the other is ${missing ? 'missing' : 'refused'}',
          setUp: () => stubMultiSend({
            testRecipient.pubkey: const ShareResult.queued('rumor-a', 'chat-a'),
            if (!missing)
              otherRecipient.pubkey: const ShareResult.failure('blocked'),
          }),
          seed: () => twoSelected,
          build: createBloc,
          act: (bloc) => bloc.add(const ShareSheetSendRequested()),
          expect: () => [
            isA<ShareSheetState>().having(
              (s) => s.isSending,
              'is sending',
              true,
            ),
            isA<ShareSheetState>()
                .having(
                  (s) => s.selectedRecipients,
                  'selection cleared',
                  isEmpty,
                )
                .having(
                  (s) => s.actionResult,
                  'attempted recipients',
                  isA<ShareSheetEnqueueResult>().having(
                    (r) =>
                        r.recipients.map((p) => (p.name, p.outcome.delivery)),
                    'results',
                    [
                      ('Alice', ShareDelivery.queued),
                      ('Bob', ShareDelivery.notSent),
                    ],
                  ),
                ),
          ],
        );
      }

      blocTest<ShareSheetBloc, ShareSheetState>(
        'keeps every selected recipient when zero rows are queued',
        setUp: () => stubMultiSend({
          testRecipient.pubkey: const ShareResult.failure('refused'),
          otherRecipient.pubkey: const ShareResult.failure('refused'),
        }),
        seed: () => twoSelected,
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        expect: () => [
          isA<ShareSheetState>().having((s) => s.isSending, 'is sending', true),
          isA<ShareSheetState>()
              .having(
                (s) => s.selectedRecipients,
                'selection',
                twoSelected.selectedRecipients,
              )
              .having(
                (s) => s.actionResult,
                'refusals',
                isA<ShareSheetEnqueueResult>().having(
                  (r) => r.recipients.map((p) => p.outcome.delivery),
                  'results',
                  [ShareDelivery.notSent, ShareDelivery.notSent],
                ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'sends null personalMessage when message is whitespace only',
        setUp: () => stubMultiSend({
          testRecipient.pubkey: const ShareResult.queued('rumor-a', 'chat-a'),
        }),
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipients: [testRecipient],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested(message: '   ')),
        verify: (_) {
          final captured = verify(
            () => mockSharingService.shareVideoWithMultipleUsers(
              video: any(named: 'video'),
              recipientPubkeys: captureAny(named: 'recipientPubkeys'),
              personalMessage: captureAny(named: 'personalMessage'),
            ),
          ).captured;
          expect(captured[0], equals([testRecipient.pubkey]));
          expect(captured[1], isNull, reason: 'whitespace trimmed to null');
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits failure when the sharing service throws an exception',
        setUp: () {
          when(
            () => mockSharingService.shareVideoWithMultipleUsers(
              video: any(named: 'video'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
              personalMessage: any(named: 'personalMessage'),
            ),
          ).thenThrow(Exception('Unexpected error'));
        },
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipients: [testRecipient],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.isSending,
            'isSending',
            isTrue,
          ),
          isA<ShareSheetState>()
              .having((s) => s.isSending, 'isSending', isFalse)
              .having((s) => s.selectedRecipients, 'selection preserved', [
                testRecipient,
              ])
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSendFailure>(),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'does nothing when no recipient selected',
        seed: () => const ShareSheetState(status: ShareSheetStatus.ready),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        expect: () => <ShareSheetState>[],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'does nothing when already sending',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipients: [testRecipient],
          isSending: true,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        expect: () => <ShareSheetState>[],
      );
    });

    // -----------------------------------------------------------------------
    // Copy link
    // -----------------------------------------------------------------------

    group('ShareSheetCopyLinkRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'external copy emits a prepared short URL',
        setUp: () {
          when(() => mockSharingService.generateShareUrl(any()))
              .thenReturn('https://divine.video/video/synthetic');
          when(() => mockSharingService.shortenExternalUrl(any()))
              .thenAnswer((_) async => 'https://divine.video/l/Abc12345');
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyLinkRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (state) => state.actionResult,
            'copied URL',
            isA<ShareSheetCopiedToClipboard>().having(
              (result) => result.text,
              'text',
              'https://divine.video/l/Abc12345',
            ),
          ),
        ],
      );
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetCopiedToClipboard with generated URL',
        setUp: () {
          when(
            () => mockSharingService.generateShareUrl(any()),
          ).thenReturn('https://divine.video/video/test-id');
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyLinkRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetCopiedToClipboard>()
                .having(
                  (r) => r.text,
                  'text',
                  'https://divine.video/video/test-id',
                )
                .having((r) => r.kind, 'kind', ShareSheetCopiedKind.postLink),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetActionFailure when generateShareUrl throws',
        setUp: () {
          when(
            () => mockSharingService.generateShareUrl(any()),
          ).thenThrow(Exception('url error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyLinkRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetActionFailure>(),
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Share via
    // -----------------------------------------------------------------------

    group('ShareSheetShareViaRequested', () {
      late _MockCacheManager mockCacheManager;

      setUp(() {
        mockCacheManager = _MockCacheManager();
      });

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetShareViaTriggered with shareUrl and thumbnailPath',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: 'Test Video',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ));
          final mockFile = _MockFile();
          when(() => mockFile.path).thenReturn('/tmp/cached_thumb');
          // Stub copy to return a file at the destination path.
          when(() => mockFile.copy(any())).thenAnswer((inv) async {
            final dest = inv.positionalArguments[0] as String;
            final copied = _MockFile();
            when(() => copied.path).thenReturn(dest);
            return copied;
          });
          when(
            () => mockCacheManager.getSingleFile(any()),
          ).thenAnswer((_) async => mockFile);
        },
        build: () => createBloc(cacheManager: mockCacheManager),
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>()
                .having(
                  (r) => r.shareUrl,
                  'shareUrl',
                  'https://divine.video/video/test-id',
                )
                .having(
                  (r) => r.thumbnailPath,
                  'thumbnailPath',
                  endsWith('divine_share_thumb.jpg'),
                )
                .having((r) => r.title, 'title', 'Test Video')
                .having((r) => r.subject, 'subject', 'Test Video'),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits with null thumbnailPath when thumbnail download fails',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: 'Test Video',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ));
          when(
            () => mockCacheManager.getSingleFile(any()),
          ).thenThrow(Exception('network error'));
        },
        build: () => createBloc(cacheManager: mockCacheManager),
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>()
                .having(
                  (r) => r.shareUrl,
                  'shareUrl',
                  'https://divine.video/video/test-id',
                )
                .having((r) => r.thumbnailPath, 'thumbnailPath', isNull),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits with null thumbnailPath when no thumbnailUrl available',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: null,
            thumbnailUrl: null,
          ));
        },
        build: () => createBloc(cacheManager: mockCacheManager),
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>()
                .having((r) => r.thumbnailPath, 'thumbnailPath', isNull)
                .having((r) => r.title, 'title', isNull),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits with null thumbnailPath when no cache manager provided',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: 'Test Video',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>().having(
              (r) => r.thumbnailPath,
              'thumbnailPath',
              isNull,
            ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetActionFailure when generateShareData throws',
        setUp: () {
          when(
            () => mockSharingService.generateShareData(any()),
          ).thenThrow(Exception('share error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetActionFailure>(),
          ),
        ],
      );
    });
  });
}
