import 'dart:async';
import 'dart:convert';

// Hide Drift table class to avoid collision with ProfileStats domain model.
import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockEvent extends Mock implements Event {
  @override
  DateTime get createdAtDateTime =>
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000, isUtc: true);

  @override
  List<List<String>> get tags => const [];
}

class MockUserProfilesDao extends Mock implements UserProfilesDao {}

class MockHttpClient extends Mock implements Client {}

class MockProfileStatsDao extends Mock implements ProfileStatsDao {}

class MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class MockVanishedProfilesDao extends Mock implements VanishedProfilesDao {}

class MockIdentityEventsDao extends Mock implements IdentityEventsDao {}

/// Injected endpoints for the username tests.
///
/// Deliberately not the production hosts: these tests must prove the
/// repository uses the *injected* endpoints, which a production literal
/// cannot distinguish from the default. Distinct per backend so a call site
/// that reads the wrong one fails loudly.
const _testNameServer = 'https://names.test.example';
const _testKeycastNip05 = 'https://login.test.example/.well-known/nostr.json';

void main() {
  group('ProfileRepository', () {
    late MockNostrClient mockNostrClient;
    late ProfileRepository profileRepository;
    late MockEvent mockProfileEvent;
    late MockUserProfilesDao mockUserProfilesDao;
    late MockHttpClient mockHttpClient;

    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const otherPubkey =
        'b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2';
    const testEventId =
        'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';

    setUpAll(() {
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(
        UserProfile(
          pubkey: 'pubkey',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'eventId',
        ),
      );
      registerFallbackValue(Uri.parse('https://example.com'));
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(Duration.zero);
      registerFallbackValue(<List<String>>[]);
    });

    setUp(() {
      UserProfile? storedProfile;
      mockNostrClient = MockNostrClient();
      mockProfileEvent = MockEvent();
      mockUserProfilesDao = MockUserProfilesDao();
      mockHttpClient = MockHttpClient();
      profileRepository = ProfileRepository(
        nostrClient: mockNostrClient,
        userProfilesDao: mockUserProfilesDao,
        httpClient: mockHttpClient,
        nameServerBaseUrl: _testNameServer,
        keycastNip05Url: _testKeycastNip05,
      );

      // The publish seed falls back to the signing key when the caller
      // supplies no `currentProfile`, so this getter is on the save path.
      when(() => mockNostrClient.publicKey).thenReturn(testPubkey);

      // Default mock event setup
      when(() => mockProfileEvent.kind).thenReturn(0);
      when(() => mockProfileEvent.pubkey).thenReturn(testPubkey);
      when(() => mockProfileEvent.createdAt).thenReturn(1704067200);
      when(() => mockProfileEvent.id).thenReturn(testEventId);
      when(() => mockProfileEvent.content).thenReturn(
        jsonEncode({
          'display_name': 'Test User',
          'about': 'A test bio',
          'picture': 'https://example.com/avatar.png',
          'nip05': 'test@example.com',
        }),
      );

      when(
        () => mockNostrClient.fetchProfile(testPubkey),
      ).thenAnswer((_) async => mockProfileEvent);
      when(
        () => mockNostrClient.fetchProfile(
          testPubkey,
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => mockProfileEvent);

      // Default stub for parallel indexer queries.
      when(
        () => mockNostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => <Event>[]);

      when(
        () => mockNostrClient.sendProfileAwaitOk(
          profileContent: any(named: 'profileContent'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: mockProfileEvent));
      when(() => mockUserProfilesDao.getProfile(any())).thenAnswer((
        invocation,
      ) async {
        final pubkey = invocation.positionalArguments.first as String;
        if (storedProfile?.pubkey == pubkey) {
          return storedProfile;
        }
        return null;
      });
      when(() => mockUserProfilesDao.upsertProfile(any())).thenAnswer((
        invocation,
      ) async {
        storedProfile = invocation.positionalArguments.first as UserProfile;
      });
    });

    /// Helper to create a current profile with given content
    Future<UserProfile> createCurrentProfile(
      Map<String, dynamic> content,
    ) async {
      when(() => mockProfileEvent.content).thenReturn(jsonEncode(content));
      return (await profileRepository.fetchFreshProfile(pubkey: testPubkey))!;
    }

    /// Makes the relay report no Kind 0 for [testPubkey], so a publish that
    /// supplies no `currentProfile` resolves to an empty seed.
    void stubNoRelayProfile() {
      when(
        () => mockNostrClient.fetchProfile(testPubkey),
      ).thenAnswer((_) async => null);
      when(
        () => mockNostrClient.fetchProfile(
          testPubkey,
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => null);
    }

    group('getCachedProfile', () {
      test('returns cached profile when it exists', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        when(
          () => mockUserProfilesDao.getProfile(any()),
        ).thenAnswer((_) async => profile);

        final result = await profileRepository.getCachedProfile(
          pubkey: testPubkey,
        );

        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.displayName, equals('Test User'));

        verify(() => mockUserProfilesDao.getProfile(any())).called(1);
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });

      test('returns null when no cached profile exists', () async {
        final result = await profileRepository.getCachedProfile(
          pubkey: testPubkey,
        );

        expect(result, isNull);

        verify(() => mockUserProfilesDao.getProfile(any())).called(1);
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });
    });

    group('getCachedProfiles', () {
      test('returns the cached profiles in a single query', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => [profile]);

        final result = await profileRepository.getCachedProfiles(
          pubkeys: [testPubkey, 'uncached-pubkey'],
        );

        expect(result, equals([profile]));
        verify(
          () => mockUserProfilesDao.getProfilesByPubkeys([
            testPubkey,
            'uncached-pubkey',
          ]),
        ).called(1);
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });

      test('does not hit the database for an empty pubkey list', () async {
        final result = await profileRepository.getCachedProfiles(pubkeys: []);

        expect(result, isEmpty);
        verifyNever(() => mockUserProfilesDao.getProfilesByPubkeys(any()));
      });
    });

    group('cacheProfile', () {
      test('delegates to userProfilesDao.upsertProfile', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);

        await profileRepository.cacheProfile(profile);

        verify(() => mockUserProfilesDao.upsertProfile(profile)).called(1);
      });

      test('adds pubkey to known cached set', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);

        await profileRepository.cacheProfile(profile);

        expect(profileRepository.hasProfile(testPubkey), isTrue);
      });

      test('does not infer confirmed missing from relay absence', () async {
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);
        await profileRepository.fetchFreshProfile(pubkey: testPubkey);
        expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
      });
    });

    group('hasProfile', () {
      test('returns false for unknown pubkey', () {
        expect(profileRepository.hasProfile(testPubkey), isFalse);
      });

      test('returns true after caching a profile', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        await profileRepository.cacheProfile(profile);

        expect(profileRepository.hasProfile(testPubkey), isTrue);
      });

      test('returns true after fetching from relay', () async {
        await profileRepository.fetchFreshProfile(pubkey: testPubkey);

        expect(profileRepository.hasProfile(testPubkey), isTrue);
      });
    });

    group('loadKnownCachedPubkeys', () {
      test('populates known cached set from Drift', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => [profile]);

        await profileRepository.loadKnownCachedPubkeys();

        expect(profileRepository.hasProfile(testPubkey), isTrue);
      });
    });

    group('deleteCachedProfile', () {
      test('delegates to userProfilesDao.deleteProfile', () async {
        when(
          () => mockUserProfilesDao.deleteProfile(any()),
        ).thenAnswer((_) async => 1);

        final result = await profileRepository.deleteCachedProfile(
          pubkey: testPubkey,
        );

        expect(result, equals(1));
        verify(() => mockUserProfilesDao.deleteProfile(testPubkey)).called(1);
      });

      test('returns 0 when profile does not exist', () async {
        when(
          () => mockUserProfilesDao.deleteProfile(any()),
        ).thenAnswer((_) async => 0);

        final result = await profileRepository.deleteCachedProfile(
          pubkey: testPubkey,
        );

        expect(result, equals(0));
      });

      test(
        'removes pubkey from known cached set on successful delete',
        () async {
          final profile = UserProfile.fromNostrEvent(mockProfileEvent);
          await profileRepository.cacheProfile(profile);
          expect(profileRepository.hasProfile(testPubkey), isTrue);

          when(
            () => mockUserProfilesDao.deleteProfile(any()),
          ).thenAnswer((_) async => 1);

          await profileRepository.deleteCachedProfile(pubkey: testPubkey);

          expect(profileRepository.hasProfile(testPubkey), isFalse);
        },
      );

      test('keeps pubkey in known cached set when delete is a no-op', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        await profileRepository.cacheProfile(profile);
        expect(profileRepository.hasProfile(testPubkey), isTrue);

        when(
          () => mockUserProfilesDao.deleteProfile(any()),
        ).thenAnswer((_) async => 0);

        await profileRepository.deleteCachedProfile(pubkey: testPubkey);

        expect(profileRepository.hasProfile(testPubkey), isTrue);
      });

      test('does not mark pubkey as confirmed missing on delete', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        await profileRepository.cacheProfile(profile);
        when(
          () => mockUserProfilesDao.deleteProfile(any()),
        ).thenAnswer((_) async => 1);

        await profileRepository.deleteCachedProfile(pubkey: testPubkey);

        expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
      });
    });

    group('getAllCachedProfiles', () {
      test('returns all profiles from dao', () async {
        final profiles = [UserProfile.fromNostrEvent(mockProfileEvent)];
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => profiles);

        final result = await profileRepository.getAllCachedProfiles();

        expect(result, equals(profiles));
        verify(() => mockUserProfilesDao.getAllProfiles()).called(1);
      });

      test('returns empty list when no profiles cached', () async {
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => []);

        final result = await profileRepository.getAllCachedProfiles();

        expect(result, isEmpty);
      });
    });

    group('watchProfile', () {
      test('emits profile from DAO stream', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        when(
          () => mockUserProfilesDao.watchProfile(any()),
        ).thenAnswer((_) => Stream.value(profile));

        final stream = profileRepository.watchProfile(pubkey: testPubkey);

        await expectLater(stream, emits(equals(profile)));
        verify(() => mockUserProfilesDao.watchProfile(testPubkey)).called(1);
      });

      test('emits null when no cached profile exists', () async {
        when(
          () => mockUserProfilesDao.watchProfile(any()),
        ).thenAnswer((_) => Stream.value(null));

        final stream = profileRepository.watchProfile(pubkey: testPubkey);

        await expectLater(stream, emits(isNull));
      });

      test('emits updates when profile changes', () async {
        final profile1 = UserProfile.fromNostrEvent(mockProfileEvent);
        when(() => mockProfileEvent.content).thenReturn(
          jsonEncode({'display_name': 'Updated User', 'about': 'Updated bio'}),
        );
        final profile2 = UserProfile.fromNostrEvent(mockProfileEvent);

        when(
          () => mockUserProfilesDao.watchProfile(any()),
        ).thenAnswer((_) => Stream.fromIterable([profile1, profile2]));

        final stream = profileRepository.watchProfile(pubkey: testPubkey);

        await expectLater(
          stream,
          emitsInOrder([
            isA<UserProfile>().having(
              (p) => p.displayName,
              'displayName',
              equals('Test User'),
            ),
            isA<UserProfile>().having(
              (p) => p.displayName,
              'displayName',
              equals('Updated User'),
            ),
          ]),
        );
      });
    });

    group('watchProfileStats', () {
      late MockProfileStatsDao mockProfileStatsDao;
      late ProfileRepository profileRepository;

      setUp(() {
        mockProfileStatsDao = MockProfileStatsDao();
        profileRepository = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          profileStatsDao: mockProfileStatsDao,
        );
      });

      test('maps ProfileStatRow to ProfileStats domain model', () async {
        final row = ProfileStatRow(
          pubkey: testPubkey,
          videoCount: 5,
          followerCount: 100,
          followingCount: 50,
          totalViews: 1000,
          totalLikes: 200,
          cachedAt: DateTime(2026),
        );
        when(
          () => mockProfileStatsDao.watchStats(any()),
        ).thenAnswer((_) => Stream.value(row));

        final stream = profileRepository.watchProfileStats(pubkey: testPubkey);

        await expectLater(
          stream,
          emits(
            equals(
              ProfileStats(
                pubkey: testPubkey,
                videoCount: 5,
                totalLikes: 200,
                followers: 100,
                following: 50,
                totalViews: 1000,
                lastUpdated: DateTime(2026),
              ),
            ),
          ),
        );
      });

      test('emits null when no stats exist', () async {
        when(
          () => mockProfileStatsDao.watchStats(any()),
        ).thenAnswer((_) => Stream.value(null));

        final stream = profileRepository.watchProfileStats(pubkey: testPubkey);

        await expectLater(stream, emits(isNull));
      });

      test(
        'defaults engagement counts to zero but leaves follower counts null',
        () async {
          final row = ProfileStatRow(
            pubkey: testPubkey,
            cachedAt: DateTime(2026),
          );
          when(
            () => mockProfileStatsDao.watchStats(any()),
          ).thenAnswer((_) => Stream.value(row));

          final stream = profileRepository.watchProfileStats(
            pubkey: testPubkey,
          );

          await expectLater(
            stream,
            emits(
              isA<ProfileStats>()
                  .having((s) => s.videoCount, 'videoCount', equals(0))
                  .having((s) => s.totalLikes, 'totalLikes', equals(0))
                  // Follower counts stay null: FollowRepository owns them, and
                  // "not written yet" must stay distinguishable from a genuine
                  // zero so the profile header can show a placeholder instead
                  // of a wrong count.
                  .having((s) => s.followers, 'followers', isNull)
                  .having((s) => s.following, 'following', isNull)
                  .having((s) => s.totalViews, 'totalViews', equals(0)),
            ),
          );
        },
      );

      test('returns empty stream when ProfileStatsDao not injected', () async {
        final repoWithoutStats = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
        );

        final stream = repoWithoutStats.watchProfileStats(pubkey: testPubkey);

        await expectLater(stream, emitsDone);
      });
    });

    group('fetchFreshProfile', () {
      /// Stubs both relay and indexer to return nothing, so tests that
      /// only care about one layer can focus on that.
      void stubAllSourcesMiss() {
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);
      }

      test('fetches from relay and caches profile', () async {
        final result = await profileRepository.fetchFreshProfile(
          pubkey: testPubkey,
        );

        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.displayName, equals('Test User'));
        expect(result.about, equals('A test bio'));

        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        verify(() => mockUserProfilesDao.upsertProfile(result)).called(1);
      });

      test('returns null when all sources return no profile', () async {
        stubAllSourcesMiss();

        final result = await profileRepository.fetchFreshProfile(
          pubkey: testPubkey,
        );

        expect(result, isNull);

        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        verifyNever(() => mockUserProfilesDao.upsertProfile(any()));
      });

      test(
        'leaves missing indeterminate when all relay sources miss',
        () async {
          stubAllSourcesMiss();

          await profileRepository.fetchFreshProfile(pubkey: testPubkey);

          expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
        },
      );

      test(
        'rechecks sources after an indeterminate miss',
        () async {
          stubAllSourcesMiss();

          // First call hits all sources without treating absence as proof.
          final firstResult = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );
          expect(firstResult, isNull);
          expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);

          // Second call — explicit fetch should clear the stale marker
          // and try the sources again.
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => mockProfileEvent);

          final secondResult = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(secondResult, isNotNull);
          expect(secondResult!.pubkey, equals(testPubkey));
          expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
          verify(() => mockNostrClient.fetchProfile(testPubkey)).called(2);
          verify(() => mockUserProfilesDao.upsertProfile(any())).called(1);
        },
      );

      test('deduplicates concurrent calls for the same pubkey', () async {
        final results = await Future.wait([
          profileRepository.fetchFreshProfile(pubkey: testPubkey),
          profileRepository.fetchFreshProfile(pubkey: testPubkey),
          profileRepository.fetchFreshProfile(pubkey: testPubkey),
        ]);

        // All return the same profile
        for (final r in results) {
          expect(r?.pubkey, equals(testPubkey));
        }
        // Only one relay call
        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
      });

      group('with Funnelcake API', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;
        late MockProfileStatsDao mockProfileStatsDao;
        late ProfileRepository repoWithFunnelcake;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          mockProfileStatsDao = MockProfileStatsDao();
          when(
            () => mockProfileStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              videoCount: any(named: 'videoCount'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
              totalViews: any(named: 'totalViews'),
              totalLikes: any(named: 'totalLikes'),
            ),
          ).thenAnswer((_) async {});
          repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockProfileStatsDao,
          );
        });

        test('uses Funnelcake REST API first when available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'REST User',
                'name': 'restuser',
                'picture': 'https://example.com/pic.png',
              }),
            ),
          );

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('REST User'));
          verify(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).called(1);
          // Should NOT fall through to relay
          verifyNever(() => mockNostrClient.fetchProfile(testPubkey));
          verify(() => mockUserProfilesDao.upsertProfile(any())).called(1);
        });

        test('requires relay metadata when raw Kind 0 is requested', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'REST User',
                'name': 'restuser',
              }),
            ),
          );

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
            requireRawKind0: true,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Test User'));
          verify(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).called(1);
          verify(
            () => mockNostrClient.fetchProfile(testPubkey, useCache: false),
          ).called(1);
        });

        test(
          'does not return cached REST profile when raw Kind 0 is requested',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => UserProfileFound(
                profile: UserProfileData.fromJson(testPubkey, const {
                  'display_name': 'REST User',
                  'name': 'restuser',
                }),
              ),
            );
            when(
              () => mockNostrClient.fetchProfile(testPubkey, useCache: false),
            ).thenAnswer((_) async => null);
            when(() => mockUserProfilesDao.getProfile(testPubkey)).thenAnswer(
              (_) async => UserProfile(
                pubkey: testPubkey,
                displayName: 'Cached REST User',
                rawData: const {'display_name': 'Cached REST User'},
                createdAt: DateTime(2026),
                eventId: 'cached-rest-$testPubkey',
              ),
            );

            final result = await repoWithFunnelcake.fetchFreshProfile(
              pubkey: testPubkey,
              requireRawKind0: true,
            );

            expect(result, isNull);
          },
        );

        test(
          'does not repeat raw Kind 0 work after confirming it missing',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => UserProfileFound(
                profile: UserProfileData.fromJson(testPubkey, const {
                  'display_name': 'REST User',
                  'name': 'restuser',
                }),
              ),
            );
            when(
              () => mockNostrClient.fetchProfile(testPubkey, useCache: false),
            ).thenAnswer((_) async => null);

            final first = await repoWithFunnelcake.fetchFreshProfile(
              pubkey: testPubkey,
              requireRawKind0: true,
            );
            final second = await repoWithFunnelcake.fetchFreshProfile(
              pubkey: testPubkey,
              requireRawKind0: true,
            );

            expect(first, isNull);
            expect(second, isNull);
            verify(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).called(1);
            verify(
              () => mockNostrClient.fetchProfile(testPubkey, useCache: false),
            ).called(1);
          },
        );

        test('retries raw Kind 0 after the configured delay', () {
          fakeAsync((async) {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => UserProfileFound(
                profile: UserProfileData.fromJson(testPubkey, const {
                  'display_name': 'REST User',
                  'name': 'restuser',
                }),
              ),
            );

            var relayFetchCount = 0;
            when(
              () => mockNostrClient.fetchProfile(testPubkey, useCache: false),
            ).thenAnswer((_) async {
              relayFetchCount += 1;
              return relayFetchCount == 1 ? null : mockProfileEvent;
            });

            UserProfile? result;
            unawaited(
              repoWithFunnelcake
                  .fetchFreshProfile(
                    pubkey: testPubkey,
                    requireRawKind0: true,
                    rawKind0RetryDelays: const [Duration(milliseconds: 5)],
                  )
                  .then((profile) => result = profile),
            );

            async.flushMicrotasks();
            expect(result, isNull);
            expect(relayFetchCount, equals(1));

            async
              ..elapse(const Duration(milliseconds: 4))
              ..flushMicrotasks();
            expect(result, isNull);
            expect(relayFetchCount, equals(1));

            async
              ..elapse(const Duration(milliseconds: 1))
              ..flushMicrotasks();
            expect(result, isNotNull);
            expect(result!.displayName, equals('Test User'));
            expect(relayFetchCount, equals(2));
          });
        });

        test('falls back to relay when Funnelcake throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenThrow(Exception('API down'));

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Test User'));
          verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        });

        test(
          'falls back to relay when Funnelcake returns null (404)',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer((_) async => null);

            final result = await repoWithFunnelcake.fetchFreshProfile(
              pubkey: testPubkey,
            );

            expect(result, isNotNull);
            expect(result!.displayName, equals('Test User'));
            verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
          },
        );

        group('NIP-62 vanished accounts', () {
          late MockVanishedProfilesDao mockVanishedDao;
          late MockIdentityEventsDao mockIdentityDao;
          late ProfileRepository repoWithVanishDao;

          setUp(() {
            mockVanishedDao = MockVanishedProfilesDao();
            mockIdentityDao = MockIdentityEventsDao();

            when(
              () => mockVanishedDao.markVanished(any()),
            ).thenAnswer((_) async {});
            when(
              () => mockVanishedDao.clearVanished(any()),
            ).thenAnswer((_) async => 1);
            when(
              () => mockVanishedDao.getAllPubkeys(),
            ).thenAnswer((_) async => <String>[]);
            when(
              () => mockIdentityDao.deleteEvent(any()),
            ).thenAnswer((_) async => 1);
            when(
              () => mockUserProfilesDao.deleteProfile(any()),
            ).thenAnswer((_) async => 1);
            when(
              () => mockProfileStatsDao.deleteStats(any()),
            ).thenAnswer((_) async => 1);
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

            repoWithVanishDao = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
              profileStatsDao: mockProfileStatsDao,
              identityEventsDao: mockIdentityDao,
              vanishedProfilesDao: mockVanishedDao,
            );
          });

          test('evicts every local trace of a vanished account', () async {
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => const UserProfileVanished(pubkey: testPubkey),
            );

            final result = await repoWithVanishDao.fetchFreshProfile(
              pubkey: testPubkey,
            );

            expect(result, isNull);
            expect(repoWithVanishDao.isVanished(testPubkey), isTrue);
            verify(
              () => mockUserProfilesDao.deleteProfile(testPubkey),
            ).called(1);
            verify(() => mockProfileStatsDao.deleteStats(testPubkey)).called(1);
            verify(() => mockIdentityDao.deleteEvent(testPubkey)).called(1);
            verify(() => mockVanishedDao.markVanished(testPubkey)).called(1);
          });

          test('never caches stats for a vanished account', () async {
            // The counters ride in on the same response that says the account
            // is gone. Writing them would leave the profile screen showing
            // "4 Following / 4 Followers" for a deleted account.
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => const UserProfileVanished(pubkey: testPubkey),
            );

            await repoWithVanishDao.fetchFreshProfile(pubkey: testPubkey);

            verifyNever(
              () => mockProfileStatsDao.upsertStats(
                pubkey: any(named: 'pubkey'),
                followerCount: any(named: 'followerCount'),
                followingCount: any(named: 'followingCount'),
                videoCount: any(named: 'videoCount'),
                totalLikes: any(named: 'totalLikes'),
                totalViews: any(named: 'totalViews'),
              ),
            );
          });

          test('does not fall back to relays for a vanished account', () async {
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => const UserProfileVanished(pubkey: testPubkey),
            );

            await repoWithVanishDao.fetchFreshProfile(pubkey: testPubkey);

            verifyNever(() => mockNostrClient.fetchProfile(any()));
            verifyNever(
              () => mockNostrClient.queryEvents(
                any(),
                tempRelays: any(named: 'tempRelays'),
                useCache: any(named: 'useCache'),
              ),
            );
          });

          test(
            'does not fall back to relays even when requireRawKind0 is set',
            () async {
              // The NotPublished branch breaks to the relay path under this
              // flag. Vanish must not, or the relay copy resurrects what was
              // just deleted.
              when(
                () => mockFunnelcakeClient.getUserProfile(testPubkey),
              ).thenAnswer(
                (_) async => const UserProfileVanished(pubkey: testPubkey),
              );

              final result = await repoWithVanishDao.fetchFreshProfile(
                pubkey: testPubkey,
                requireRawKind0: true,
              );

              expect(result, isNull);
              verifyNever(() => mockNostrClient.fetchProfile(any()));
            },
          );

          test('cacheProfile is a no-op for a vanished account', () async {
            // One of two guards on the relay ingestion path. Events that reach
            // this repository stop here; events that EventRouter writes
            // straight to the DAO are stopped by UserProfilesDao itself.
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => const UserProfileVanished(pubkey: testPubkey),
            );
            await repoWithVanishDao.fetchFreshProfile(pubkey: testPubkey);

            await repoWithVanishDao.cacheProfile(
              UserProfile(
                pubkey: testPubkey,
                name: 'resurrected',
                createdAt: DateTime.now(),
                eventId: 'relay-copy',
                rawData: const {},
              ),
            );

            verifyNever(() => mockUserProfilesDao.upsertProfile(any()));
          });

          test('a vanished account costs one request for the whole '
              'session', () async {
            // Eviction leaves no cached row, so every cache-miss caller takes
            // the network branch. Three autoDispose providers re-instantiate
            // per widget; without the short-circuit an inbox scroll would
            // re-run the whole eviction once per row per rebuild.
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => const UserProfileVanished(pubkey: testPubkey),
            );
            await repoWithVanishDao.fetchFreshProfile(pubkey: testPubkey);

            for (var i = 0; i < 5; i++) {
              expect(
                await repoWithVanishDao.fetchFreshProfile(pubkey: testPubkey),
                isNull,
              );
            }
            await pumpEventQueue();

            verify(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).called(1);
            verify(() => mockVanishedDao.markVanished(testPubkey)).called(1);
            verify(
              () => mockUserProfilesDao.deleteProfile(testPubkey),
            ).called(1);
          });

          test('re-checks a vanish recorded in an earlier session and '
              'self-heals', () async {
            // Recovery from a wrong vanish classification must not be limited
            // to the session that recorded it — a restart hydrates the marker
            // from the durable table with no fetch behind it, and that
            // session's one re-check is what clears it.
            when(
              () => mockVanishedDao.getAllPubkeys(),
            ).thenAnswer((_) async => [testPubkey]);
            await repoWithVanishDao.loadVanishedPubkeys();
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => const UserProfileNotPublished(pubkey: testPubkey),
            );

            await repoWithVanishDao.fetchFreshProfile(pubkey: testPubkey);
            await pumpEventQueue();

            expect(repoWithVanishDao.isVanished(testPubkey), isFalse);
            verify(() => mockVanishedDao.clearVanished(testPubkey)).called(1);
          });

          test('clears a tombstone this instance never mirrored', () async {
            // Same self-heal as above, minus the hydration. The in-memory set
            // is per-instance and hydrates asynchronously, but the table is
            // shared by profileRepository and profileStatsRepository — so a
            // miss does not prove the row is absent. Gating the durable delete
            // on the mirror would strand the tombstone, and UserProfilesDao
            // would then silently drop every re-cache of the recovered account.
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => const UserProfileNotPublished(pubkey: testPubkey),
            );

            expect(repoWithVanishDao.isVanished(testPubkey), isFalse);

            await repoWithVanishDao.fetchFreshProfile(pubkey: testPubkey);
            await pumpEventQueue();

            verify(() => mockVanishedDao.clearVanished(testPubkey)).called(1);
          });

          group('watchVanishedPubkeys', () {
            test('mirrors the durable table', () async {
              when(
                () => mockVanishedDao.watchAllPubkeys(),
              ).thenAnswer((_) => Stream.value([testPubkey]));

              expect(
                await repoWithVanishDao.watchVanishedPubkeys().first,
                equals({testPubkey}),
              );
            });

            test(
              'follows later writes, so a consumer cannot go stale',
              () async {
                final controller = StreamController<List<String>>();
                addTearDown(controller.close);
                when(
                  () => mockVanishedDao.watchAllPubkeys(),
                ).thenAnswer((_) => controller.stream);

                // Subscribe before writing, then await: awaiting first would
                // deadlock, since nothing has been added yet.
                final settled = expectLater(
                  repoWithVanishDao.watchVanishedPubkeys(),
                  emitsInOrder([
                    <String>{},
                    {testPubkey},
                  ]),
                );

                controller
                  ..add([])
                  ..add([testPubkey]);

                await settled;
              },
            );

            test('emits an empty set when no dao is wired', () async {
              // Matches isVanished in the same configuration: a caller gets a
              // usable answer rather than an error.
              expect(
                await profileRepository.watchVanishedPubkeys().first,
                isEmpty,
              );
            });
          });

          test('loadVanishedPubkeys hydrates the in-memory set', () async {
            when(
              () => mockVanishedDao.getAllPubkeys(),
            ).thenAnswer((_) async => [testPubkey]);

            await repoWithVanishDao.loadVanishedPubkeys();

            expect(repoWithVanishDao.isVanished(testPubkey), isTrue);
          });

          test('a non-vanished account is not marked', () async {
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => const UserProfileNotPublished(pubkey: testPubkey),
            );

            await repoWithVanishDao.fetchFreshProfile(pubkey: testPubkey);

            expect(repoWithVanishDao.isVanished(testPubkey), isFalse);
            verifyNever(() => mockVanishedDao.markVanished(any()));
          });

          group('revalidateVanishOnce', () {
            test('discovers a vanish behind a cached profile', () async {
              // The cache-first read path short-circuits before any network
              // call, so this is the only thing that re-checks an account
              // cached before it asked to be deleted.
              final fetched = Completer<void>();
              when(
                () => mockFunnelcakeClient.getUserProfile(testPubkey),
              ).thenAnswer((_) async {
                fetched.complete();
                return const UserProfileVanished(pubkey: testPubkey);
              });

              repoWithVanishDao.revalidateVanishOnce(testPubkey);
              await fetched.future;
              await pumpEventQueue();

              expect(repoWithVanishDao.isVanished(testPubkey), isTrue);
              verify(() => mockVanishedDao.markVanished(testPubkey)).called(1);
              verify(
                () => mockUserProfilesDao.deleteProfile(testPubkey),
              ).called(1);
            });

            test('re-checks a pubkey at most once per session', () async {
              // The calling provider is autoDispose and re-runs every time a
              // row scrolls back into view; without the session set an inbox
              // scroll would fire one request per row per scroll.
              final fetched = Completer<void>();
              when(
                () => mockFunnelcakeClient.getUserProfile(testPubkey),
              ).thenAnswer((_) async {
                fetched.complete();
                return const UserProfileNotPublished(pubkey: testPubkey);
              });

              repoWithVanishDao.revalidateVanishOnce(testPubkey);
              await fetched.future;
              await pumpEventQueue();
              repoWithVanishDao.revalidateVanishOnce(testPubkey);
              await pumpEventQueue();

              verify(
                () => mockFunnelcakeClient.getUserProfile(testPubkey),
              ).called(1);
            });

            test(
              'still re-checks an already-vanished account, but only once',
              () async {
                // This is the only channel that can undo a wrong vanish
                // classification: fetchFreshProfile answers a vanished pubkey
                // from the durable marker, so nothing else reaches the
                // network for it.
                when(
                  () => mockVanishedDao.getAllPubkeys(),
                ).thenAnswer((_) async => [testPubkey]);
                await repoWithVanishDao.loadVanishedPubkeys();
                when(
                  () => mockFunnelcakeClient.getUserProfile(testPubkey),
                ).thenAnswer(
                  (_) async => const UserProfileVanished(pubkey: testPubkey),
                );

                repoWithVanishDao.revalidateVanishOnce(testPubkey);
                await pumpEventQueue();
                repoWithVanishDao.revalidateVanishOnce(testPubkey);
                await pumpEventQueue();

                verify(
                  () => mockFunnelcakeClient.getUserProfile(testPubkey),
                ).called(1);
              },
            );

            test('swallows a failed re-check', () async {
              // Fire-and-forget: an unhandled rejection here would surface as
              // an uncaught async error in the calling provider's zone.
              final fetched = Completer<void>();
              when(
                () => mockFunnelcakeClient.getUserProfile(testPubkey),
              ).thenAnswer((_) async {
                fetched.complete();
                throw StateError('relay exploded');
              });

              repoWithVanishDao.revalidateVanishOnce(testPubkey);
              await fetched.future;
              await pumpEventQueue();

              expect(repoWithVanishDao.isVanished(testPubkey), isFalse);
            });
          });
        });

        test('marks missing immediately when Funnelcake returns '
            'UserProfileNotPublished', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileNotPublished(
              pubkey: testPubkey,
              social: ProfileSocialData.fromJson(const {
                'follower_count': 12,
                'following_count': 7,
              }),
              stats: ProfileStatsData.fromJson(const {'video_count': 3}),
              engagement: ProfileEngagementData.fromJson(const {
                'total_reactions': 42,
                'total_loops': 12.6,
                'total_views': 99,
              }),
            ),
          );

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
          expect(repoWithFunnelcake.isConfirmedMissing(testPubkey), isTrue);
          // Should NOT fall through to relay or indexer
          verifyNever(() => mockNostrClient.fetchProfile(any()));
          verifyNever(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          );
          verify(
            () => mockProfileStatsDao.upsertStats(
              pubkey: testPubkey,
              // REST social counts are cached alongside the other stats so
              // the profile header can render them without waiting on any
              // relay work (#8197).
              followerCount: 12,
              followingCount: 7,
              videoCount: 3,
              totalLikes: 42,
              totalViews: 99,
            ),
          ).called(1);
        });

        test('uses rounded loops when unified views are unavailable', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileNotPublished(
              pubkey: testPubkey,
              engagement: ProfileEngagementData.fromJson(const {
                'total_loops': 12.6,
                'total_views': 0,
              }),
            ),
          );

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
          expect(repoWithFunnelcake.isConfirmedMissing(testPubkey), isTrue);
          verify(
            () => mockProfileStatsDao.upsertStats(
              pubkey: testPubkey,
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
              videoCount: any(named: 'videoCount'),
              totalLikes: any(named: 'totalLikes'),
              totalViews: 13,
            ),
          ).called(1);
        });

        test('does not cache an ambiguous 0/0 social response', () async {
          // `/api/users/{pubkey}/social` answers 200 for every pubkey and
          // funnelcake turns ClickHouse failures into `{0, 0}`, so a zero
          // body cannot be told apart from "never indexed" or "the summary
          // table is down". Writing it would overwrite a good baseline
          // with zeros (#8259 review).
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileNotPublished(
              pubkey: testPubkey,
              social: ProfileSocialData.fromJson(const {
                'follower_count': 0,
                'following_count': 0,
              }),
              stats: ProfileStatsData.fromJson(const {'video_count': 3}),
            ),
          );

          await repoWithFunnelcake.fetchFreshProfile(pubkey: testPubkey);

          // The other stats are still cached; the counts are withheld,
          // i.e. passed as null (the default), so the DAO leaves whatever
          // baseline is already on the row untouched.
          verify(
            () => mockProfileStatsDao.upsertStats(
              pubkey: testPubkey,
              videoCount: 3,
              totalLikes: any(named: 'totalLikes'),
              totalViews: any(named: 'totalViews'),
            ),
          ).called(1);
        });

        test('does not cache an ambiguous zero video count', () async {
          // `get_user_stats` maps both a miss and a ClickHouse failure to a
          // default, so funnelcake answers 200 with `video_count: 0` when the
          // summary table is down — the same ambiguity the social counts
          // already withhold. Writing it would overwrite a good baseline
          // with a zero (#8403).
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileNotPublished(
              pubkey: testPubkey,
              social: ProfileSocialData.fromJson(const {
                'follower_count': 1976,
                'following_count': 12,
              }),
              stats: ProfileStatsData.fromJson(const {'video_count': 0}),
            ),
          );

          await repoWithFunnelcake.fetchFreshProfile(pubkey: testPubkey);

          // The social counts are real and cached; the zero video count is
          // withheld, so the DAO keeps whatever baseline the row already has.
          verify(
            () => mockProfileStatsDao.upsertStats(
              pubkey: testPubkey,
              followerCount: 1976,
              followingCount: 12,
              totalLikes: any(named: 'totalLikes'),
              totalViews: any(named: 'totalViews'),
            ),
          ).called(1);
        });

        test('caches mixed social responses per field', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileNotPublished(
              pubkey: testPubkey,
              social: ProfileSocialData.fromJson(const {
                'follower_count': 1976,
                'following_count': 0,
              }),
            ),
          );

          await repoWithFunnelcake.fetchFreshProfile(pubkey: testPubkey);

          verify(
            () => mockProfileStatsDao.upsertStats(
              pubkey: testPubkey,
              followerCount: 1976,
              totalLikes: any(named: 'totalLikes'),
              totalViews: any(named: 'totalViews'),
              videoCount: any(named: 'videoCount'),
            ),
          ).called(1);
        });

        test('skips Funnelcake when not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Test User'));
          verifyNever(() => mockFunnelcakeClient.getUserProfile(any()));
          verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        });

        test('does not overwrite a newer locally-cached bio with stale '
            'Funnelcake data (regression: bio appears not to save)', () async {
          // Simulate: user just saved their bio. The local cache holds the
          // freshly-published profile (newer). Funnelcake returns a stale
          // profile carrying its original — older — Kind 0 timestamp
          // (profile.profile_updated). Newest-wins must keep the local copy:
          // no overwrite, and the newer local profile is returned (#3141,
          // follow-up to #3104).
          final freshlySavedProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Test User',
            about: 'My new bio',
            rawData: const {'display_name': 'Test User', 'about': 'My new bio'},
            createdAt: DateTime.utc(2024, 1, 2), // newer — just saved
            eventId: testEventId,
          );

          // Use a fresh DAO mock so we can control getProfile return values
          // without stub-ordering issues from the outer setUp.
          final freshDao = MockUserProfilesDao();
          when(
            () => freshDao.getProfile(any()),
          ).thenAnswer((_) async => freshlySavedProfile);
          when(() => freshDao.upsertProfile(any())).thenAnswer((_) async {});

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: freshDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockProfileStatsDao,
          );

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'Test User',
                'about': '', // stale — bio not yet indexed by Funnelcake
                'profile_updated': '2024-01-01T00:00:00Z', // older
              }),
            ),
          );

          final result = await repo.fetchFreshProfile(pubkey: testPubkey);

          // The stale Funnelcake profile must NOT overwrite the newer cache.
          verifyNever(
            () => freshDao.upsertProfile(
              any(
                that: isA<UserProfile>().having(
                  (p) => p.about,
                  'about',
                  equals(''),
                ),
              ),
            ),
          );

          // Funnelcake now carries the original Kind 0 timestamp, so the
          // relay fallback is no longer needed to protect a freshly-saved
          // bio — newest-wins resolves it directly.
          verifyNever(() => mockNostrClient.fetchProfile(any()));

          // The newer local profile is returned, not the stale Funnelcake
          // copy.
          expect(result, isNotNull);
          expect(result!.about, equals('My new bio'));
        });

        test('updates an older locally-cached profile when Funnelcake has a '
            'newer one (#3141)', () async {
          // The local cache holds an older profile. Funnelcake returns a
          // newer profile carrying a newer original Kind 0 timestamp.
          // Newest-wins must upsert the Funnelcake copy and return it.
          final olderLocalProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Old Name',
            about: 'Old bio',
            rawData: const {'display_name': 'Old Name', 'about': 'Old bio'},
            createdAt: DateTime.utc(2024), // older
            eventId: testEventId,
          );

          UserProfile? stored = olderLocalProfile;
          final freshDao = MockUserProfilesDao();
          when(
            () => freshDao.getProfile(any()),
          ).thenAnswer((_) async => stored);
          when(() => freshDao.upsertProfile(any())).thenAnswer((
            invocation,
          ) async {
            stored = invocation.positionalArguments.first as UserProfile;
          });

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: freshDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockProfileStatsDao,
          );

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'New Name',
                'about': 'New bio',
                'profile_updated': '2024-02-01T00:00:00Z', // newer
              }),
            ),
          );

          final result = await repo.fetchFreshProfile(pubkey: testPubkey);

          // The newer Funnelcake profile upgrades the cache.
          verify(
            () => freshDao.upsertProfile(
              any(
                that: isA<UserProfile>().having(
                  (p) => p.about,
                  'about',
                  equals('New bio'),
                ),
              ),
            ),
          ).called(1);

          // Resolved directly from Funnelcake; no relay fallback needed.
          verifyNever(() => mockNostrClient.fetchProfile(any()));

          expect(result, isNotNull);
          expect(result!.about, equals('New bio'));
          expect(result.displayName, equals('New Name'));
        });

        test('returns the richer local profile on a createdAt tie instead of '
            'the leaner Funnelcake copy (#3141)', () async {
          // Local cache and Funnelcake share the same Kind 0 timestamp.
          // _cacheProfileIfNewer keeps the local copy (not strictly newer),
          // so the return value must match the cache — the richer local
          // profile, not the leaner Funnelcake one that may omit fields.
          final localProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Local Name',
            about: 'Local bio',
            rawData: const {'display_name': 'Local Name', 'about': 'Local bio'},
            createdAt: DateTime.utc(2024, 3),
            eventId: testEventId,
          );

          final freshDao = MockUserProfilesDao();
          when(
            () => freshDao.getProfile(any()),
          ).thenAnswer((_) async => localProfile);
          when(() => freshDao.upsertProfile(any())).thenAnswer((_) async {});

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: freshDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockProfileStatsDao,
          );

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'Funnelcake Name',
                'about': 'Funnelcake bio',
                'profile_updated': '2024-03-01T00:00:00Z', // tie
              }),
            ),
          );

          final result = await repo.fetchFreshProfile(pubkey: testPubkey);

          // Tie is not strictly newer — the cache is untouched.
          verifyNever(() => freshDao.upsertProfile(any()));
          // Resolved directly from the cache; no relay fallback.
          verifyNever(() => mockNostrClient.fetchProfile(any()));
          // The returned profile is the richer local copy, not Funnelcake's.
          expect(result, isNotNull);
          expect(result!.about, equals('Local bio'));
          expect(result.displayName, equals('Local Name'));
        });

        test(
          'keeps the local cache and falls through to relay when a found '
          'Funnelcake profile carries no timestamp (defensive #3141)',
          () async {
            // Funnelcake returns a found profile but omits profile_updated, so
            // UserProfileData.createdAt is null. With a local profile already
            // cached, newest-wins cannot be applied, so the conservative path
            // must run: do NOT overwrite the cache with the timestamp-less
            // copy, and fall through to the relay/indexer path so a newer
            // Kind 0 can still win.
            final localProfile = UserProfile(
              pubkey: testPubkey,
              displayName: 'Local Name',
              about: 'Local bio',
              rawData: const {
                'display_name': 'Local Name',
                'about': 'Local bio',
              },
              createdAt: DateTime.utc(2024),
              eventId: testEventId,
            );

            final freshDao = MockUserProfilesDao();
            when(
              () => freshDao.getProfile(any()),
            ).thenAnswer((_) async => localProfile);
            when(() => freshDao.upsertProfile(any())).thenAnswer((_) async {});

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: freshDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
              profileStatsDao: mockProfileStatsDao,
            );

            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => UserProfileFound(
                profile: UserProfileData.fromJson(testPubkey, const {
                  'display_name': 'Funnelcake Name',
                  'about': 'Funnelcake bio',
                  // No profile_updated → createdAt stays null.
                }),
              ),
            );

            // Relays find nothing newer — the local cache is the fallback.
            when(
              () => mockNostrClient.fetchProfile(testPubkey),
            ).thenAnswer((_) async => null);

            final result = await repo.fetchFreshProfile(pubkey: testPubkey);

            // The timestamp-less Funnelcake copy must not overwrite the cache.
            verifyNever(() => freshDao.upsertProfile(any()));

            // The relay path must run so a newer Kind 0 can still win.
            verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);

            // Relays found nothing newer, so the local cache is returned.
            expect(result, isNotNull);
            expect(result!.about, equals('Local bio'));
          },
        );
      });

      group('indexer relay fallback', () {
        late MockEvent mockIndexerEvent;

        setUp(() {
          mockIndexerEvent = MockEvent();
          when(() => mockIndexerEvent.kind).thenReturn(0);
          when(() => mockIndexerEvent.pubkey).thenReturn(testPubkey);
          when(() => mockIndexerEvent.createdAt).thenReturn(1704067200);
          when(() => mockIndexerEvent.id).thenReturn('idx_$testEventId');
          when(() => mockIndexerEvent.content).thenReturn(
            jsonEncode({
              'display_name': 'Indexer User',
              'picture': 'https://example.com/indexer.png',
            }),
          );
        });

        test('falls back to indexer relays when relay misses', () async {
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [mockIndexerEvent]);

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Indexer User'));
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: false,
            ),
          ).called(1);
          verify(() => mockUserProfilesDao.upsertProfile(any())).called(1);
        });

        test('does not confirm missing from empty relay results', () async {
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
          expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
        });

        test('handles indexer relay timeout gracefully', () async {
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenThrow(Exception('Indexer timeout'));

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
          expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
        });

        test(
          'picks newest kind-0 event when indexer returns multiple events '
          'with older event first (regression: bio appears not to save)',
          () async {
            // Simulate: relay returns nothing, but indexer returns two kind-0
            // events for the same pubkey. The older event (stale, no bio) comes
            // first in the list. The fix must select the newest by createdAt.
            when(
              () => mockNostrClient.fetchProfile(testPubkey),
            ).thenAnswer((_) async => null);

            final olderEvent = MockEvent();
            when(() => olderEvent.kind).thenReturn(0);
            when(() => olderEvent.pubkey).thenReturn(testPubkey);
            when(() => olderEvent.createdAt).thenReturn(1704067200); // older
            when(() => olderEvent.id).thenReturn('old_$testEventId');
            when(() => olderEvent.content).thenReturn(
              jsonEncode({'display_name': 'Test User', 'about': ''}),
            );

            final newerEvent = MockEvent();
            when(() => newerEvent.kind).thenReturn(0);
            when(() => newerEvent.pubkey).thenReturn(testPubkey);
            when(() => newerEvent.createdAt).thenReturn(1704153600); // newer
            when(() => newerEvent.id).thenReturn('new_$testEventId');
            when(() => newerEvent.content).thenReturn(
              jsonEncode({
                'display_name': 'Test User',
                'about': 'My saved bio',
              }),
            );

            // Indexer returns older event first, then newer — relay ordering
            // is not guaranteed, so the repository must not trust list order.
            when(
              () => mockNostrClient.queryEvents(
                any(),
                tempRelays: any(named: 'tempRelays'),
                useCache: any(named: 'useCache'),
              ),
            ).thenAnswer((_) async => [olderEvent, newerEvent]);

            final result = await profileRepository.fetchFreshProfile(
              pubkey: testPubkey,
            );

            expect(result, isNotNull);
            expect(result!.about, equals('My saved bio'));
            verify(
              () => mockUserProfilesDao.upsertProfile(
                any(
                  that: isA<UserProfile>().having(
                    (p) => p.about,
                    'about',
                    equals('My saved bio'),
                  ),
                ),
              ),
            ).called(1);
          },
        );
      });

      group('parallel relay + indexer fetch', () {
        test('fires connected and indexer relays concurrently', () async {
          // Both sources miss — verify both are called
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
          verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: false,
            ),
          ).called(1);
        });

        test('handles connected relay exception gracefully', () async {
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenThrow(Exception('WebSocket error'));
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
        });

        test('handles uncaught Error without hanging', () async {
          // Throw an Error (not Exception) so it escapes
          // _fetchFromConnectedRelays' catch; the safe() wrapper's
          // on Object clause handles it.
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenThrow(StateError('unexpected'));
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
        });

        test('returns relay result when indexer is slower', () async {
          final relayCompleter = Completer<Event?>();
          final indexerCompleter = Completer<List<Event>>();
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) => relayCompleter.future);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) => indexerCompleter.future);

          final fetchFuture = profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );
          relayCompleter.complete(mockProfileEvent);

          final result = await fetchFuture.timeout(
            const Duration(milliseconds: 50),
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Test User'));

          indexerCompleter.complete(<Event>[]);
        });

        test('upgrades cached profile when slower indexer is newer', () async {
          final indexerCompleter = Completer<List<Event>>();
          // Connected relay returns older event (createdAt = 1704067200)
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => mockProfileEvent);
          // Indexer returns newer event (createdAt = 1704153600)
          final indexerEvent = MockEvent();
          when(() => indexerEvent.kind).thenReturn(0);
          when(() => indexerEvent.pubkey).thenReturn(testPubkey);
          when(() => indexerEvent.createdAt).thenReturn(1704153600);
          when(() => indexerEvent.id).thenReturn('idx_$testEventId');
          when(
            () => indexerEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Indexer Name'}));
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) => indexerCompleter.future);

          final fetchFuture = profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );
          final firstResult = await fetchFuture.timeout(
            const Duration(milliseconds: 50),
          );

          expect(firstResult, isNotNull);
          expect(firstResult!.displayName, equals('Test User'));
          verify(
            () => mockUserProfilesDao.upsertProfile(
              any(
                that: isA<UserProfile>().having(
                  (profile) => profile.displayName,
                  'displayName',
                  equals('Test User'),
                ),
              ),
            ),
          ).called(1);

          indexerCompleter.complete([indexerEvent]);
          await Future<void>.delayed(Duration.zero);

          verify(
            () => mockUserProfilesDao.upsertProfile(
              any(
                that: isA<UserProfile>().having(
                  (profile) => profile.displayName,
                  'displayName',
                  equals('Indexer Name'),
                ),
              ),
            ),
          ).called(1);
        });

        test(
          'keeps cached relay profile when slower indexer is older',
          () async {
            final indexerCompleter = Completer<List<Event>>();
            when(
              () => mockNostrClient.fetchProfile(testPubkey),
            ).thenAnswer((_) async => mockProfileEvent);
            final indexerEvent = MockEvent();
            when(() => indexerEvent.kind).thenReturn(0);
            when(() => indexerEvent.pubkey).thenReturn(testPubkey);
            when(() => indexerEvent.createdAt).thenReturn(1703977200);
            when(() => indexerEvent.id).thenReturn('idx_old_$testEventId');
            when(
              () => indexerEvent.content,
            ).thenReturn(jsonEncode({'display_name': 'Old Indexer'}));
            when(
              () => mockNostrClient.queryEvents(
                any(),
                tempRelays: any(named: 'tempRelays'),
                useCache: any(named: 'useCache'),
              ),
            ).thenAnswer((_) => indexerCompleter.future);

            final fetchFuture = profileRepository.fetchFreshProfile(
              pubkey: testPubkey,
            );
            final firstResult = await fetchFuture.timeout(
              const Duration(milliseconds: 50),
            );

            expect(firstResult, isNotNull);
            expect(firstResult!.displayName, equals('Test User'));

            indexerCompleter.complete([indexerEvent]);
            await Future<void>.delayed(Duration.zero);

            verifyNever(
              () => mockUserProfilesDao.upsertProfile(
                any(
                  that: isA<UserProfile>().having(
                    (profile) => profile.displayName,
                    'displayName',
                    equals('Old Indexer'),
                  ),
                ),
              ),
            );
          },
        );

        test('picks newer relay profile over older indexer profile', () async {
          // Connected relay returns newer event (createdAt = 1704153600)
          final newerRelayEvent = MockEvent();
          when(() => newerRelayEvent.kind).thenReturn(0);
          when(() => newerRelayEvent.pubkey).thenReturn(testPubkey);
          when(() => newerRelayEvent.createdAt).thenReturn(1704153600);
          when(() => newerRelayEvent.id).thenReturn('new_$testEventId');
          when(
            () => newerRelayEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Relay Name'}));
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => newerRelayEvent);
          // Indexer returns older event (createdAt = 1704067200)
          final indexerEvent = MockEvent();
          when(() => indexerEvent.kind).thenReturn(0);
          when(() => indexerEvent.pubkey).thenReturn(testPubkey);
          when(() => indexerEvent.createdAt).thenReturn(1704067200);
          when(() => indexerEvent.id).thenReturn('idx_$testEventId');
          when(
            () => indexerEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Old Indexer'}));
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [indexerEvent]);

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Relay Name'));
        });
      });
    });

    group('saveProfileEvent', () {
      test('sends all provided fields to nostrClient and caches and returns '
          'user profile', () async {
        // No pre-existing profile anywhere, so the publish composes from the
        // provided fields alone and the only cache write is the published one.
        stubNoRelayProfile();
        when(() => mockProfileEvent.content).thenReturn(
          jsonEncode({
            'display_name': 'New Name',
            'about': 'New bio',
            'nip05': '_@newuser.divine.video',
            'picture': 'https://example.com/new.png',
          }),
        );

        final profile = await profileRepository.saveProfileEvent(
          displayName: 'New Name',
          about: 'New bio',
          username: 'newuser',
          picture: 'https://example.com/new.png',
        );

        expect(profile.displayName, equals('New Name'));
        expect(profile.about, equals('New bio'));
        expect(profile.nip05, equals('_@newuser.divine.video'));
        expect(profile.picture, equals('https://example.com/new.png'));

        verify(
          () => mockNostrClient.sendProfileAwaitOk(
            profileContent: {
              'display_name': 'New Name',
              'about': 'New bio',
              'nip05': '_@newuser.divine.video',
              'picture': 'https://example.com/new.png',
            },
          ),
        ).called(1);
        verify(() => mockUserProfilesDao.upsertProfile(profile)).called(1);
      });

      test('constructs nip05 identifier from username', () async {
        await profileRepository.saveProfileEvent(
          displayName: 'Test',
          username: 'alice',
        );

        verify(
          () => mockNostrClient.sendProfileAwaitOk(
            profileContent: {
              'display_name': 'Test',
              'nip05': '_@alice.divine.video',
            },
          ),
        ).called(1);
      });

      test('normalizes username to lowercase in nip05', () async {
        await profileRepository.saveProfileEvent(
          displayName: 'Test',
          username: 'Alice',
        );

        verify(
          () => mockNostrClient.sendProfileAwaitOk(
            profileContent: {
              'display_name': 'Test',
              'nip05': '_@alice.divine.video',
            },
          ),
        ).called(1);
      });

      test('uses external nip05 directly when provided', () async {
        when(() => mockProfileEvent.content).thenReturn(
          jsonEncode({'display_name': 'Test', 'nip05': 'alice@example.com'}),
        );

        await profileRepository.saveProfileEvent(
          displayName: 'Test',
          nip05: 'alice@example.com',
        );

        verify(
          () => mockNostrClient.sendProfileAwaitOk(
            profileContent: {
              'display_name': 'Test',
              'nip05': 'alice@example.com',
            },
          ),
        ).called(1);
      });

      test('external nip05 takes precedence over username', () async {
        when(() => mockProfileEvent.content).thenReturn(
          jsonEncode({'display_name': 'Test', 'nip05': 'alice@example.com'}),
        );

        await profileRepository.saveProfileEvent(
          displayName: 'Test',
          username: 'alice',
          nip05: 'alice@example.com',
        );

        verify(
          () => mockNostrClient.sendProfileAwaitOk(
            profileContent: {
              'display_name': 'Test',
              'nip05': 'alice@example.com',
            },
          ),
        ).called(1);
      });

      test(
        'omits unset about/picture/banner keys instead of writing nulls',
        () async {
          // This test is about never emitting null values, which is only
          // observable when there is no seed to preserve. Nothing is cached
          // and the relay has nothing, so the seed resolves to null.
          stubNoRelayProfile();

          await profileRepository.saveProfileEvent(displayName: 'Only Name');

          verify(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {'display_name': 'Only Name'},
            ),
          ).called(1);
        },
      );

      test('preserves the existing nip05 when neither username nor nip05 is '
          'provided', () async {
        await profileRepository.saveProfileEvent(displayName: 'Only Name');

        final captured =
            verify(
                  () => mockNostrClient.sendProfileAwaitOk(
                    profileContent: captureAny(named: 'profileContent'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        // Not passing a nip05 means "leave it alone", not "delete it" —
        // clearNip05 is the explicit removal path. Before the publish seed was
        // resolved from the signer key, a caller that supplied no
        // currentProfile silently dropped it.
        expect(captured['nip05'], 'test@example.com');
      });

      test('includes banner when provided', () async {
        when(() => mockProfileEvent.content).thenReturn(
          jsonEncode({'display_name': 'Test User', 'banner': '0x33ccbf'}),
        );

        await profileRepository.saveProfileEvent(
          displayName: 'Test User',
          banner: '0x33ccbf',
        );

        verify(
          () => mockNostrClient.sendProfileAwaitOk(
            profileContent: {'display_name': 'Test User', 'banner': '0x33ccbf'},
          ),
        ).called(1);
      });

      test('includes website when provided', () async {
        await profileRepository.saveProfileEvent(
          displayName: 'Test User',
          website: 'https://example.com',
        );

        final captured =
            verify(
                  () => mockNostrClient.sendProfileAwaitOk(
                    profileContent: captureAny(named: 'profileContent'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(captured['website'], equals('https://example.com'));
      });

      test(
        'writes monetization links without dropping unrelated rawData',
        () async {
          final currentProfile = await createCurrentProfile({
            'display_name': 'Old Name',
            'custom_field': 'preserved',
            divineMonetizationLinksKey: [
              {
                'provider': 'venmo',
                'category': 'tip',
                'url': 'https://venmo.com/u/old',
                'enabled': true,
              },
            ],
          });

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            currentProfile: currentProfile,
            monetizationLinks: const [
              MonetizationLink(
                provider: MonetizationLinkProvider.patreon,
                category: MonetizationLinkCategory.subscription,
                url: 'https://www.patreon.com/alice',
                enabled: true,
              ),
            ],
          );

          final captured =
              verify(
                    () => mockNostrClient.sendProfileAwaitOk(
                      profileContent: captureAny(named: 'profileContent'),
                    ),
                  ).captured.single
                  as Map<String, dynamic>;
          expect(captured['display_name'], 'New Name');
          expect(captured['custom_field'], 'preserved');
          expect(captured[divineMonetizationLinksKey], [
            {
              'provider': 'patreon',
              'category': 'subscription',
              'url': 'https://www.patreon.com/alice',
              'enabled': true,
            },
          ]);
        },
      );

      test('removes monetization field when saved list is empty', () async {
        final currentProfile = await createCurrentProfile({
          'display_name': 'Old Name',
          divineMonetizationLinksKey: [
            {
              'provider': 'venmo',
              'category': 'tip',
              'url': 'https://venmo.com/u/old',
              'enabled': true,
            },
          ],
        });

        await profileRepository.saveProfileEvent(
          displayName: 'New Name',
          currentProfile: currentProfile,
          monetizationLinks: const [],
        );

        final captured =
            verify(
                  () => mockNostrClient.sendProfileAwaitOk(
                    profileContent: captureAny(named: 'profileContent'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(captured.containsKey(divineMonetizationLinksKey), isFalse);
      });

      test('does not publish disabled monetization links', () async {
        final currentProfile = await createCurrentProfile({
          'display_name': 'Old Name',
        });

        await profileRepository.saveProfileEvent(
          displayName: 'New Name',
          currentProfile: currentProfile,
          monetizationLinks: const [
            MonetizationLink(
              provider: MonetizationLinkProvider.venmo,
              category: MonetizationLinkCategory.tip,
              url: 'https://venmo.com/u/alice',
              enabled: false,
            ),
          ],
        );

        final captured =
            verify(
                  () => mockNostrClient.sendProfileAwaitOk(
                    profileContent: captureAny(named: 'profileContent'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(captured.containsKey(divineMonetizationLinksKey), isFalse);
      });

      test('removes website key when empty string is passed', () async {
        final currentProfile = await createCurrentProfile({
          'display_name': 'Old Name',
          'website': 'https://old.com',
        });

        await profileRepository.saveProfileEvent(
          displayName: 'New Name',
          website: '',
          currentProfile: currentProfile,
        );

        final captured =
            verify(
                  () => mockNostrClient.sendProfileAwaitOk(
                    profileContent: captureAny(named: 'profileContent'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(captured.containsKey('website'), isFalse);
      });

      test('throws ProfilePublishFailedException when no relay confirms '
          '(rejection or timeout)', () async {
        // Isolate the failure path from the seed read, which legitimately
        // caches whatever the relay reports.
        stubNoRelayProfile();
        when(
          () => mockNostrClient.sendProfileAwaitOk(
            profileContent: any(named: 'profileContent'),
          ),
        ).thenAnswer((_) async => const PublishFailed());

        await expectLater(
          profileRepository.saveProfileEvent(displayName: 'Test'),
          throwsA(isA<ProfilePublishFailedException>()),
        );
        verifyNever(() => mockUserProfilesDao.upsertProfile(any()));
      });

      test(
        'throws NoRelaysConnectedException when no relays are connected',
        () async {
          // Isolate the failure path from the seed read, which legitimately
          // caches whatever the relay reports.
          stubNoRelayProfile();
          when(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
            ),
          ).thenAnswer((_) async => const PublishNoRelays());

          await expectLater(
            profileRepository.saveProfileEvent(displayName: 'Test'),
            throwsA(isA<NoRelaysConnectedException>()),
          );
          verifyNever(() => mockUserProfilesDao.upsertProfile(any()));
        },
      );

      group('with no currentProfile', () {
        test('seeds from the signing key instead of publishing a stripped '
            'Kind 0', () async {
          final rawKind0 = Event(
            testPubkey,
            0,
            [
              ['i', 'github:alice', 'proof'],
            ],
            jsonEncode({
              'display_name': 'Old Name',
              'name': 'alice',
              'lud16': 'alice@getalby.com',
              'bot': false,
              'custom_client_key': 'keep-me',
            }),
            createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          );
          when(
            () => mockNostrClient.fetchProfile(
              testPubkey,
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => rawKind0);
          // A non-empty rawTags seed takes the tags-carrying overload.
          when(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => PublishSuccess(event: mockProfileEvent));

          // No currentProfile — previously this returned before any fetch and
          // published from an empty map, erasing everything below.
          await profileRepository.saveProfileEvent(displayName: 'New Name');

          final captured =
              verify(
                    () => mockNostrClient.sendProfileAwaitOk(
                      profileContent: captureAny(named: 'profileContent'),
                      tags: [
                        ['i', 'github:alice', 'proof'],
                      ],
                    ),
                  ).captured.single
                  as Map<String, dynamic>;
          expect(captured['display_name'], 'New Name');
          expect(captured['name'], 'alice');
          expect(captured['lud16'], 'alice@getalby.com');
          expect(captured['bot'], false);
          expect(captured['custom_client_key'], 'keep-me');
        });

        test(
          'does not consult the relay when the client has no signing key',
          () async {
            when(() => mockNostrClient.publicKey).thenReturn('');

            await profileRepository.saveProfileEvent(displayName: 'Only Name');

            verifyNever(
              () => mockNostrClient.fetchProfile(
                any(),
                useCache: any(named: 'useCache'),
              ),
            );
            verify(
              () => mockNostrClient.sendProfileAwaitOk(
                profileContent: {'display_name': 'Only Name'},
              ),
            ).called(1);
          },
        );

        test('a REST seed padded with empty-string placeholders does not '
            'outrank the raw Kind 0', () async {
          // Funnelcake models every metadata field as a non-nullable String, so
          // an absent Kind 0 key arrives as ''. Counting raw keys let that
          // padding win the richness comparison; counting meaningful keys does
          // not.
          final restSeed = UserProfile(
            pubkey: testPubkey,
            displayName: 'Wolf M. Iversen',
            rawData: const {
              'display_name': 'Wolf M. Iversen',
              'name': '',
              'about': '',
              'website': '',
              'lud16': '',
            },
            createdAt: DateTime(2026),
            eventId: 'rest-$testPubkey',
          );
          final rawKind0 = Event(
            testPubkey,
            0,
            const [],
            jsonEncode({
              'display_name': 'Wolf M. Iversen',
              'name': 'alice',
              'custom_client_key': 'keep-me',
            }),
            // Same second as the REST seed: funnelcake exposes the original
            // event timestamp, so the newer-than check cannot break the tie.
            createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          );
          when(
            () => mockNostrClient.fetchProfile(
              testPubkey,
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => rawKind0);

          await profileRepository.saveProfileEvent(
            displayName: 'Wolf M. Iversen',
            currentProfile: restSeed,
          );

          final captured =
              verify(
                    () => mockNostrClient.sendProfileAwaitOk(
                      profileContent: captureAny(named: 'profileContent'),
                    ),
                  ).captured.single
                  as Map<String, dynamic>;
          // Both are present only in the raw Kind 0. If the '' -padded REST
          // seed had won the comparison, both would be gone from the publish.
          expect(captured['name'], 'alice');
          expect(captured['custom_client_key'], 'keep-me');
        });
      });

      test(
        'a newer, sparser relay Kind 0 outranks a stale, richer local seed',
        () async {
          // A field removed on another client leaves the newest Kind 0 both
          // newer and sparser than our copy. Richness must not override
          // recency here, or the save re-publishes the deletion away.
          final staleLocalSeed = UserProfile(
            pubkey: testPubkey,
            displayName: 'Alice',
            name: 'alice',
            rawData: const {
              'display_name': 'Alice',
              'name': 'alice',
              'lud16': 'alice@getalby.com',
              'custom_client_key': 'deleted-elsewhere',
            },
            createdAt: DateTime(2026),
            eventId: 'cached-$testPubkey',
          );
          final newerSparserKind0 = Event(
            testPubkey,
            0,
            const [],
            jsonEncode({'display_name': 'Alice', 'name': 'alice'}),
            createdAt: DateTime(2026, 2).millisecondsSinceEpoch ~/ 1000,
          );
          when(
            () => mockNostrClient.fetchProfile(
              testPubkey,
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => newerSparserKind0);

          await profileRepository.saveProfileEvent(
            displayName: 'Alice',
            currentProfile: staleLocalSeed,
          );

          final captured =
              verify(
                    () => mockNostrClient.sendProfileAwaitOk(
                      profileContent: captureAny(named: 'profileContent'),
                    ),
                  ).captured.single
                  as Map<String, dynamic>;
          expect(captured.containsKey('lud16'), isFalse);
          expect(captured.containsKey('custom_client_key'), isFalse);
        },
      );

      group('with currentProfile', () {
        test('requires raw Kind 0 when resolving the publish seed', () async {
          final funnelcakeApiClient = MockFunnelcakeApiClient();
          final repository = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: funnelcakeApiClient,
          );
          when(() => funnelcakeApiClient.isAvailable).thenReturn(true);
          when(() => funnelcakeApiClient.getUserProfile(testPubkey)).thenAnswer(
            (_) async => UserProfileFound(
              profile: UserProfileData(
                pubkey: testPubkey,
                displayName: 'REST Name',
                createdAt: DateTime(2026, 1, 2),
              ),
            ),
          );

          final rawKind0 = Event(
            testPubkey,
            0,
            const [],
            jsonEncode({
              'display_name': 'Relay Name',
              'relay_only_field': 'preserved',
            }),
            createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          );
          when(
            () => mockNostrClient.fetchProfile(
              testPubkey,
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => rawKind0);

          await repository.saveProfileEvent(
            displayName: 'New Name',
            currentProfile: UserProfile(
              pubkey: testPubkey,
              displayName: 'Current Name',
              rawData: const {'display_name': 'Current Name'},
              createdAt: DateTime(2025),
              eventId: 'rest-$testPubkey',
            ),
          );

          final captured =
              verify(
                    () => mockNostrClient.sendProfileAwaitOk(
                      profileContent: captureAny(named: 'profileContent'),
                    ),
                  ).captured.single
                  as Map<String, dynamic>;
          expect(captured['display_name'], 'New Name');
          expect(captured['relay_only_field'], 'preserved');
        });

        test('preserves raw Kind 0 tags when republishing', () async {
          final rawTags = [
            ['i', 'github:alice', 'proof'],
            ['alt', 'profile metadata'],
          ];
          final currentProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Old Name',
            rawData: const {'display_name': 'Old Name'},
            rawTags: rawTags,
            createdAt: DateTime(2026),
            eventId: 'kind0-$testPubkey',
          );
          when(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => PublishSuccess(event: mockProfileEvent));

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            currentProfile: currentProfile,
          );

          final captured =
              verify(
                    () => mockNostrClient.sendProfileAwaitOk(
                      profileContent: captureAny(named: 'profileContent'),
                      tags: rawTags,
                    ),
                  ).captured.single
                  as Map<String, dynamic>;
          expect(captured['display_name'], 'New Name');
        });

        test('preserves raw Kind 0 tags from the relay seed', () async {
          final rawTags = [
            ['i', 'github:alice', 'proof'],
            ['alt', 'profile metadata'],
          ];
          final rawKind0 = Event(
            testPubkey,
            0,
            rawTags,
            jsonEncode({
              'display_name': 'Relay Name',
              'relay_only_field': 'preserved',
            }),
            createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          );
          when(
            () => mockNostrClient.fetchProfile(
              testPubkey,
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => rawKind0);
          when(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => PublishSuccess(event: mockProfileEvent));

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            currentProfile: UserProfile(
              pubkey: testPubkey,
              displayName: 'Current Name',
              rawData: const {'display_name': 'Current Name'},
              createdAt: DateTime(2025),
              eventId: 'current-$testPubkey',
            ),
          );

          final captured =
              verify(
                    () => mockNostrClient.sendProfileAwaitOk(
                      profileContent: captureAny(named: 'profileContent'),
                      tags: rawTags,
                    ),
                  ).captured.single
                  as Map<String, dynamic>;
          expect(captured['display_name'], 'New Name');
          expect(captured['relay_only_field'], 'preserved');
        });

        test('preserves unrelated fields from currentProfile', () async {
          final currentProfile = await createCurrentProfile({
            'display_name': 'Old Name',
            'website': 'https://old.com',
            'lud16': 'user@wallet.com',
            'custom_field': 'preserved',
          });

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            currentProfile: currentProfile,
          );

          verify(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {
                'display_name': 'New Name',
                'website': 'https://old.com',
                'lud16': 'user@wallet.com',
                'custom_field': 'preserved',
              },
            ),
          ).called(1);
        });

        test('new fields override existing fields', () async {
          final currentProfile = await createCurrentProfile({
            'display_name': 'Old Name',
            'nip05': 'old@example.com',
            'about': 'Old bio',
          });

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            username: 'newuser',
            about: 'New bio',
            currentProfile: currentProfile,
          );

          verify(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {
                'display_name': 'New Name',
                'nip05': '_@newuser.divine.video',
                'about': 'New bio',
              },
            ),
          ).called(1);
        });

        test(
          'clears about/picture/banner when null is explicitly passed',
          () async {
            // The editor surface fills its form fields from the current
            // profile and then sends them as-is. A user clearing their bio,
            // avatar, or banner shows up here as `about: null` /
            // `picture: null` / `banner: null`. The repository must remove
            // those keys from the seed so the cleared values reach the
            // relays.
            final currentProfile = await createCurrentProfile({
              'display_name': 'Old Name',
              'about': 'Old bio',
              'picture': 'https://example.com/old.png',
              'banner': '0xff0000',
            });

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              currentProfile: currentProfile,
            );

            verify(
              () => mockNostrClient.sendProfileAwaitOk(
                profileContent: {'display_name': 'New Name'},
              ),
            ).called(1);
          },
        );

        test(
          'preserves existing nip05 from rawData when clearNip05 is false',
          () async {
            final currentProfile = await createCurrentProfile({
              'display_name': 'Old Name',
              'nip05': 'alice@example.com',
            });

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              currentProfile: currentProfile,
            );

            verify(
              () => mockNostrClient.sendProfileAwaitOk(
                profileContent: {
                  'display_name': 'New Name',
                  'nip05': 'alice@example.com',
                },
              ),
            ).called(1);
          },
        );

        test('removes nip05 from rawData when clearNip05 is true', () async {
          final currentProfile = await createCurrentProfile({
            'display_name': 'Old Name',
            'nip05': 'alice@example.com',
            'about': 'Bio',
          });

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            about: 'Bio',
            clearNip05: true,
            currentProfile: currentProfile,
          );

          verify(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {'display_name': 'New Name', 'about': 'Bio'},
            ),
          ).called(1);
        });

        test('preserves nip05 from currentProfile.rawData when sourced from '
            'Funnelcake REST (post-#4175 fromUserProfileFound mirrors typed '
            'fields into rawData)', () async {
          // After #4175, fromUserProfileFound populates rawData from
          // typed REST fields. Construct a profile in that shape and
          // assert nip05 survives a profile edit unchanged.
          final funnelcakeProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Old Name',
            nip05: '_@ike.divine.video',
            rawData: const {
              'display_name': 'Old Name',
              'nip05': '_@ike.divine.video',
            },
            createdAt: DateTime.now(),
            eventId: 'rest-$testPubkey',
          );

          when(() => mockProfileEvent.content).thenReturn(
            jsonEncode({
              'display_name': 'New Name',
              'nip05': '_@ike.divine.video',
            }),
          );

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            currentProfile: funnelcakeProfile,
          );

          verify(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {
                'display_name': 'New Name',
                'nip05': '_@ike.divine.video',
              },
            ),
          ).called(1);
        });

        test('clearNip05 removes nip05 even when sourced from a '
            'post-#4175 Funnelcake profile', () async {
          final funnelcakeProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Old Name',
            nip05: '_@ike.divine.video',
            rawData: const {
              'display_name': 'Old Name',
              'nip05': '_@ike.divine.video',
            },
            createdAt: DateTime.now(),
            eventId: 'rest-$testPubkey',
          );

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            clearNip05: true,
            currentProfile: funnelcakeProfile,
          );

          verify(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {'display_name': 'New Name'},
            ),
          ).called(1);
        });

        test(
          'clearNip05 is a no-op when a new nip05 is also provided',
          () async {
            final currentProfile = await createCurrentProfile({
              'display_name': 'Old Name',
              'nip05': 'old@example.com',
            });

            when(() => mockProfileEvent.content).thenReturn(
              jsonEncode({
                'display_name': 'New Name',
                'nip05': 'new@example.com',
              }),
            );

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              nip05: 'new@example.com',
              clearNip05: true,
              currentProfile: currentProfile,
            );

            verify(
              () => mockNostrClient.sendProfileAwaitOk(
                profileContent: {
                  'display_name': 'New Name',
                  'nip05': 'new@example.com',
                },
              ),
            ).called(1);
          },
        );

        test(
          'preserves arbitrary unknown fields when seeded from a '
          'relay-fetched Kind 0 (the load-bearing invariant from #4175)',
          () async {
            // Sets up the relay seed path: fetchProfile returns a Kind 0
            // event whose content carries fields the typed UserProfile
            // model does not know about (custom client keys, NIP-39 i
            // tags, bot, future NIPs). Editing display_name must publish
            // an event with all those fields preserved byte-identical.
            final freshContent = {
              'display_name': 'Old Name',
              'about': 'Existing bio',
              'picture': 'https://example.com/p.png',
              'banner': '0x000000',
              'nip05': 'alice@example.com',
              'lud16': 'alice@strike.me',
              'lud06': 'lnurl1abc',
              'website': 'https://alice.example',
              'bot': true,
              'i': ['github:alice', 'twitter:alice'],
              'weird_future_field': {'nested': 'value'},
            };
            final freshEvent = MockEvent();
            when(() => freshEvent.kind).thenReturn(0);
            when(() => freshEvent.pubkey).thenReturn(testPubkey);
            when(() => freshEvent.id).thenReturn('relay-event-id');
            when(
              () => freshEvent.createdAt,
            ).thenReturn(DateTime.now().millisecondsSinceEpoch ~/ 1000);
            when(() => freshEvent.content).thenReturn(jsonEncode(freshContent));
            when(
              () => mockNostrClient.fetchProfile(
                testPubkey,
                useCache: any(named: 'useCache'),
              ),
            ).thenAnswer((_) async => freshEvent);

            // currentProfile from REST has sparse rawData — the relay seed
            // wins because it has more keys.
            final currentProfile = UserProfile(
              pubkey: testPubkey,
              displayName: 'Old Name',
              nip05: 'alice@example.com',
              rawData: const {
                'display_name': 'Old Name',
                'nip05': 'alice@example.com',
              },
              createdAt: DateTime.now().subtract(const Duration(hours: 1)),
              eventId: 'rest-$testPubkey',
            );

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              about: 'Existing bio',
              picture: 'https://example.com/p.png',
              banner: '0x000000',
              currentProfile: currentProfile,
            );

            final captured =
                verify(
                      () => mockNostrClient.sendProfileAwaitOk(
                        profileContent: captureAny(named: 'profileContent'),
                      ),
                    ).captured.single
                    as Map<String, dynamic>;

            // The user changed display_name only. Every other key should
            // be byte-identical with the relay seed.
            expect(captured['display_name'], equals('New Name'));
            for (final key in freshContent.keys) {
              if (key == 'display_name') continue;
              expect(
                captured[key],
                equals(freshContent[key]),
                reason: 'Field $key was modified by an unrelated edit',
              );
            }
            // No extra keys leaked in.
            expect(captured.keys.toSet(), equals(freshContent.keys.toSet()));
          },
        );

        test(
          'falls back to currentProfile when relay seed fetch fails',
          () async {
            // createCurrentProfile uses fetchProfile internally; build the
            // profile first, THEN stub fetchProfile to throw so only the
            // saveProfileEvent-time seed fetch fails.
            final currentProfile = await createCurrentProfile({
              'display_name': 'Old Name',
              'lud16': 'alice@strike.me',
              'website': 'https://alice.example',
            });
            when(
              () => mockNostrClient.fetchProfile(
                testPubkey,
                useCache: any(named: 'useCache'),
              ),
            ).thenThrow(Exception('relay down'));

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              currentProfile: currentProfile,
            );

            verify(
              () => mockNostrClient.sendProfileAwaitOk(
                profileContent: {
                  'display_name': 'New Name',
                  'lud16': 'alice@strike.me',
                  'website': 'https://alice.example',
                },
              ),
            ).called(1);
          },
        );
      });
    });

    group('searchUsers', () {
      test('returns empty list for empty query', () async {
        // Act
        final result = await profileRepository.searchUsers(query: '');

        // Assert
        expect(result, isEmpty);
        verifyNever(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        );
      });

      test('returns empty list for whitespace-only query', () async {
        // Act
        final result = await profileRepository.searchUsers(query: '   ');

        // Assert
        expect(result, isEmpty);
        verifyNever(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        );
      });

      test('returns profiles from NostrClient', () async {
        // Arrange
        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent]);

        // Act
        final result = await profileRepository.searchUsers(query: 'test');

        // Assert
        expect(result, hasLength(1));
        expect(result.first.pubkey, equals(testPubkey));
        expect(result.first.displayName, equals('Test User'));
        verify(() => mockNostrClient.queryUsers('test', limit: 200)).called(1);
      });

      test('uses custom limit when provided', () async {
        // Arrange
        when(
          () => mockNostrClient.queryUsers('test', limit: 10),
        ).thenAnswer((_) async => [mockProfileEvent]);

        // Act
        final result = await profileRepository.searchUsers(
          query: 'test',
          limit: 10,
        );

        // Assert
        expect(result, hasLength(1));
        verify(() => mockNostrClient.queryUsers('test', limit: 10)).called(1);
      });

      test('excludes pubkeys hidden by the block filter', () async {
        final blockedPubkey = 'e' * 64;
        final blockedEvent = MockEvent();
        when(() => blockedEvent.kind).thenReturn(0);
        when(() => blockedEvent.pubkey).thenReturn(blockedPubkey);
        when(() => blockedEvent.createdAt).thenReturn(1704067200);
        when(() => blockedEvent.id).thenReturn('f' * 64);
        when(
          () => blockedEvent.content,
        ).thenReturn(jsonEncode({'name': 'Blocked User'}));

        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent, blockedEvent]);

        final filteringRepository = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );

        final result = await filteringRepository.searchUsers(query: 'test');

        expect(result, hasLength(1));
        expect(result.first.pubkey, equals(testPubkey));
      });

      test('returns empty list when NostrClient returns empty list', () async {
        // Arrange
        when(
          () => mockNostrClient.queryUsers('unknown', limit: 200),
        ).thenAnswer((_) async => []);

        // Act
        final result = await profileRepository.searchUsers(query: 'unknown');

        // Assert
        expect(result, isEmpty);
      });

      test(
        'returns multiple profiles when NostrClient returns multiple events',
        () async {
          // Arrange
          final mockProfileEvent1 = MockEvent();
          final mockProfileEvent2 = MockEvent();
          const testPubkey1 =
              'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
              'c3d4e5f6a1b2c3d4e5f6a1b2';
          const testPubkey2 =
              'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
              'c3d4e5f6a1b2c3d4e5f6a1b2c3';
          const testEventId1 =
              'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
              'd3c4b5a6f1e2d3c4b5a6f1e2';
          const testEventId2 =
              'e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
              'd3c4b5a6f1e2d3c4b5a6f1e2d3';

          when(() => mockProfileEvent1.kind).thenReturn(0);
          when(() => mockProfileEvent1.pubkey).thenReturn(testPubkey1);
          when(() => mockProfileEvent1.createdAt).thenReturn(1704067200);
          when(() => mockProfileEvent1.id).thenReturn(testEventId1);
          when(() => mockProfileEvent1.content).thenReturn(
            jsonEncode({
              'display_name': 'Alice Wonder',
              'about': 'A test user',
            }),
          );

          when(() => mockProfileEvent2.kind).thenReturn(0);
          when(() => mockProfileEvent2.pubkey).thenReturn(testPubkey2);
          when(() => mockProfileEvent2.createdAt).thenReturn(1704067300);
          when(() => mockProfileEvent2.id).thenReturn(testEventId2);
          when(() => mockProfileEvent2.content).thenReturn(
            jsonEncode({
              'display_name': 'Alice Smith',
              'about': 'Another user',
            }),
          );

          when(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).thenAnswer((_) async => [mockProfileEvent1, mockProfileEvent2]);

          // Act
          final result = await profileRepository.searchUsers(query: 'alice');

          // Assert
          expect(result, hasLength(2));
          expect(result[0].displayName, equals('Alice Wonder'));
          expect(result[1].displayName, equals('Alice Smith'));
        },
      );

      test('enriches profiles missing picture from local cache', () async {
        // Arrange - search result has no picture
        final mockSearchEvent = MockEvent();
        const searchPubkey =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            'c3d4e5f6a1b2c3d4e5f6a1b2';
        const searchEventId =
            'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
            'd3c4b5a6f1e2d3c4b5a6f1e2';

        when(() => mockSearchEvent.kind).thenReturn(0);
        when(() => mockSearchEvent.pubkey).thenReturn(searchPubkey);
        when(() => mockSearchEvent.createdAt).thenReturn(1704067200);
        when(() => mockSearchEvent.id).thenReturn(searchEventId);
        when(
          () => mockSearchEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Alice'}));

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenAnswer((_) async => [mockSearchEvent]);

        // Cache has a profile with a picture
        when(() => mockUserProfilesDao.getProfile(searchPubkey)).thenAnswer(
          (_) async => UserProfile(
            pubkey: searchPubkey,
            displayName: 'Alice Cached',
            picture: 'https://example.com/alice.png',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: searchEventId,
          ),
        );

        // Act
        final result = await profileRepository.searchUsers(query: 'alice');

        // Assert - picture enriched from cache
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Alice'));
        expect(result.first.picture, equals('https://example.com/alice.png'));
      });

      test('does not overwrite existing picture with cached version', () async {
        // Arrange - search result already has a picture
        final mockSearchEvent = MockEvent();
        const searchPubkey =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            'c3d4e5f6a1b2c3d4e5f6a1b2';
        const searchEventId =
            'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
            'd3c4b5a6f1e2d3c4b5a6f1e2';

        when(() => mockSearchEvent.kind).thenReturn(0);
        when(() => mockSearchEvent.pubkey).thenReturn(searchPubkey);
        when(() => mockSearchEvent.createdAt).thenReturn(1704067200);
        when(() => mockSearchEvent.id).thenReturn(searchEventId);
        when(() => mockSearchEvent.content).thenReturn(
          jsonEncode({
            'display_name': 'Alice',
            'picture': 'https://example.com/fresh.png',
          }),
        );

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenAnswer((_) async => [mockSearchEvent]);

        // Cache has a different (stale) picture
        when(() => mockUserProfilesDao.getProfile(searchPubkey)).thenAnswer(
          (_) async => UserProfile(
            pubkey: searchPubkey,
            picture: 'https://example.com/stale.png',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: searchEventId,
          ),
        );

        // Act
        final result = await profileRepository.searchUsers(query: 'alice');

        // Assert - search result picture preserved, not overwritten
        expect(result, hasLength(1));
        expect(result.first.picture, equals('https://example.com/fresh.png'));
      });

      test('enriches multiple null fields from cache', () async {
        // Arrange - search result has minimal data
        final mockSearchEvent = MockEvent();
        const searchPubkey =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            'c3d4e5f6a1b2c3d4e5f6a1b2';
        const searchEventId =
            'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
            'd3c4b5a6f1e2d3c4b5a6f1e2';

        when(() => mockSearchEvent.kind).thenReturn(0);
        when(() => mockSearchEvent.pubkey).thenReturn(searchPubkey);
        when(() => mockSearchEvent.createdAt).thenReturn(1704067200);
        when(() => mockSearchEvent.id).thenReturn(searchEventId);
        when(
          () => mockSearchEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Alice'}));

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenAnswer((_) async => [mockSearchEvent]);

        // Cache has complete profile
        when(() => mockUserProfilesDao.getProfile(searchPubkey)).thenAnswer(
          (_) async => UserProfile(
            pubkey: searchPubkey,
            displayName: 'Alice Cached',
            about: 'Bio from cache',
            picture: 'https://example.com/alice.png',
            nip05: 'alice@example.com',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: searchEventId,
          ),
        );

        // Act
        final result = await profileRepository.searchUsers(query: 'alice');

        // Assert - null fields enriched, non-null preserved
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Alice'));
        expect(result.first.about, equals('Bio from cache'));
        expect(result.first.picture, equals('https://example.com/alice.png'));
        expect(result.first.nip05, equals('alice@example.com'));
      });

      test('uses profileSearchFilter when provided', () async {
        // Arrange
        final mockProfileEvent1 = MockEvent();
        final mockProfileEvent2 = MockEvent();
        const testPubkey1 =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            'c3d4e5f6a1b2c3d4e5f6a1b2';
        const testPubkey2 =
            'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            'c3d4e5f6a1b2c3d4e5f6a1b2c3';
        const testEventId1 =
            'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
            'd3c4b5a6f1e2d3c4b5a6f1e2';
        const testEventId2 =
            'e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
            'd3c4b5a6f1e2d3c4b5a6f1e2d3';

        when(() => mockProfileEvent1.kind).thenReturn(0);
        when(() => mockProfileEvent1.pubkey).thenReturn(testPubkey1);
        when(() => mockProfileEvent1.createdAt).thenReturn(1704067200);
        when(() => mockProfileEvent1.id).thenReturn(testEventId1);
        when(() => mockProfileEvent1.content).thenReturn(
          jsonEncode({'display_name': 'Bob Smith', 'about': 'First user'}),
        );

        when(() => mockProfileEvent2.kind).thenReturn(0);
        when(() => mockProfileEvent2.pubkey).thenReturn(testPubkey2);
        when(() => mockProfileEvent2.createdAt).thenReturn(1704067300);
        when(() => mockProfileEvent2.id).thenReturn(testEventId2);
        when(() => mockProfileEvent2.content).thenReturn(
          jsonEncode({'display_name': 'Alice Jones', 'about': 'Second user'}),
        );

        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent1, mockProfileEvent2]);

        // Track filter invocations
        var filterCalled = false;
        String? receivedQuery;
        List<UserProfile>? receivedProfiles;

        // Create repository with custom search filter that reverses the list
        final repoWithFilter = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          profileSearchFilter: (query, profiles) {
            filterCalled = true;
            receivedQuery = query;
            receivedProfiles = profiles;
            // Return reversed list to prove custom filter was used
            return profiles.reversed.toList();
          },
        );

        // Act
        final result = await repoWithFilter.searchUsers(query: 'test');

        // Assert
        expect(filterCalled, isTrue);
        expect(receivedQuery, equals('test'));
        expect(receivedProfiles, hasLength(2));
        // Verify the custom filter's reversal was applied
        expect(result, hasLength(2));
        expect(result[0].displayName, equals('Alice Jones'));
        expect(result[1].displayName, equals('Bob Smith'));
      });
    });

    group('searchUsersLocally', () {
      test('returns empty list when query is blank', () async {
        final result = await profileRepository.searchUsersLocally(query: '   ');

        expect(result, isEmpty);
        verifyNever(() => mockUserProfilesDao.getAllProfiles());
      });

      test('filters cached profiles and applies limit', () async {
        final cachedProfiles = [
          UserProfile(
            pubkey: testPubkey,
            displayName: 'Alice Example',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: testEventId,
          ),
          UserProfile(
            pubkey: otherPubkey,
            about: 'Talks about ALPHA builds',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'z' * 64,
          ),
          UserProfile(
            pubkey: 'c' * 64,
            displayName: 'Charlie',
            about: 'No match here',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'd' * 64,
          ),
        ];
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => cachedProfiles);

        final result = await profileRepository.searchUsersLocally(
          query: '  al  ',
          limit: 1,
        );

        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Alice Example'));
        verify(() => mockUserProfilesDao.getAllProfiles()).called(1);
      });

      test('uses custom profileSearchFilter when provided', () async {
        final cachedProfiles = [
          UserProfile(
            pubkey: testPubkey,
            displayName: 'Alice Example',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: testEventId,
          ),
          UserProfile(
            pubkey: otherPubkey,
            displayName: 'Bob Example',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'e' * 64,
          ),
        ];
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => cachedProfiles);

        var filterCalled = false;
        final repoWithFilter = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          profileSearchFilter: (query, profiles) {
            filterCalled = true;
            expect(query, equals('alice'));
            expect(profiles, same(cachedProfiles));
            return [profiles.last];
          },
        );

        final result = await repoWithFilter.searchUsersLocally(query: 'alice');

        expect(filterCalled, isTrue);
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Bob Example'));
      });

      test('countUsersLocally returns number of cached matches', () async {
        final cachedProfiles = [
          UserProfile(
            pubkey: testPubkey,
            displayName: 'Alice Example',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: testEventId,
          ),
          UserProfile(
            pubkey: otherPubkey,
            about: 'Alice in bio only',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'f' * 64,
          ),
        ];
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => cachedProfiles);

        final count = await profileRepository.countUsersLocally(query: 'alice');

        expect(count, equals(2));
      });
    });

    group('searchUsers with FunnelcakeApiClient', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test(
        'searchUsersFromApi excludes pubkeys hidden by the block filter',
        () async {
          final blockedPubkey = 'e' * 64;
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: blockedPubkey,
                displayName: 'Blocked User',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
              ProfileSearchResult(
                pubkey: 'd' * 64,
                displayName: 'Visible User',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          final filteringRepository = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: (pubkey) => pubkey == blockedPubkey,
          );

          final result = await filteringRepository.searchUsersFromApi(
            query: 'user',
          );

          expect(result, hasLength(1));
          expect(result.first.displayName, 'Visible User');
        },
      );

      test(
        'searchUsersFromApi uses Funnelcake only with server sorting',
        () async {
          // Arrange
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'ga',
              limit: 10,
              offset: any(named: 'offset'),
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'd' * 64,
                displayName: 'GaryVee',
                picture: 'https://example.com/garyvee.jpg',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Act
          final result = await repoWithFunnelcake.searchUsersFromApi(
            query: 'ga',
            limit: 10,
            sortBy: 'followers',
          );

          // Assert
          expect(result, hasLength(1));
          expect(result.first.displayName, 'GaryVee');
          expect(result.first.picture, 'https://example.com/garyvee.jpg');
          verify(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'ga',
              limit: 10,
              offset: any(named: 'offset'),
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
            ),
          ).called(1);
          verifyNever(
            () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
          );
        },
      );

      test(
        'searchUsersFromApi returns empty results when Funnelcake fails',
        () async {
          // Arrange
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'ga',
              limit: 10,
              offset: any(named: 'offset'),
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenThrow(Exception('REST API error'));

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Act
          final result = await repoWithFunnelcake.searchUsersFromApi(
            query: 'ga',
            limit: 10,
            sortBy: 'followers',
          );

          // Assert
          expect(result, isEmpty);
          verify(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'ga',
              limit: 10,
              offset: any(named: 'offset'),
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
            ),
          ).called(1);
          verifyNever(
            () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
          );
        },
      );

      test(
        'searchUsersFromApi returns empty when cache enrichment throws',
        () async {
          // Arrange: the REST call succeeds, then the cache lookup fails.
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'ga',
              limit: 10,
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'd' * 64,
                displayName: 'GaryVee',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );
          final throwingDao = MockUserProfilesDao();
          when(
            () => throwingDao.getProfile(any()),
          ).thenThrow(Exception('cache read failed'));

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: throwingDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Act & Assert: the enrichment failure is absorbed by the same
          // fallback that covers a failed REST call, per this method's
          // documented contract. Without the `await` on _enrichFromCache the
          // future escapes the `on Exception` and this call throws instead.
          await expectLater(
            repoWithFunnelcake.searchUsersFromApi(query: 'ga', limit: 10),
            completion(isEmpty),
          );
        },
      );

      test(
        'uses Funnelcake first then WebSocket when both available',
        () async {
          // Arrange
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'alice',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'a' * 64,
                displayName: 'Alice REST',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          final mockWsEvent = MockEvent();
          when(() => mockWsEvent.kind).thenReturn(0);
          when(() => mockWsEvent.pubkey).thenReturn('b' * 64);
          when(() => mockWsEvent.createdAt).thenReturn(1704067200);
          when(() => mockWsEvent.id).thenReturn('c' * 64);
          when(
            () => mockWsEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Alice WS'}));

          when(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).thenAnswer((_) async => [mockWsEvent]);

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Act
          final result = await repoWithFunnelcake.searchUsers(query: 'alice');

          // Assert - both results merged
          expect(result, hasLength(2));
          expect(result.any((p) => p.displayName == 'Alice REST'), isTrue);
          expect(result.any((p) => p.displayName == 'Alice WS'), isTrue);

          verify(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'alice',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).called(1);
          verify(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).called(1);
        },
      );

      test('skips Funnelcake when not available', () async {
        // Arrange
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        // Use 'test' as query so it matches 'Test User' display name
        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent]);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        // Act
        final result = await repoWithFunnelcake.searchUsers(query: 'test');

        // Assert
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Test User'));

        verifyNever(
          () => mockFunnelcakeClient.searchProfiles(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
          ),
        );
        verify(() => mockNostrClient.queryUsers('test', limit: 200)).called(1);
      });

      test('continues to WebSocket when Funnelcake fails', () async {
        // Arrange
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: 'test',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
          ),
        ).thenThrow(Exception('REST API error'));

        // Use 'test' as query so it matches 'Test User' display name
        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent]);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        // Act
        final result = await repoWithFunnelcake.searchUsers(query: 'test');

        // Assert - falls back to WebSocket results
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Test User'));
      });

      test('deduplicates results by pubkey (REST takes priority)', () async {
        // Arrange
        final samePubkey = 'd' * 64;

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: 'alice',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
          ),
        ).thenAnswer(
          (_) async => [
            ProfileSearchResult(
              pubkey: samePubkey,
              displayName: 'Alice REST',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            ),
          ],
        );

        final mockWsEvent = MockEvent();
        when(() => mockWsEvent.kind).thenReturn(0);
        when(() => mockWsEvent.pubkey).thenReturn(samePubkey);
        when(() => mockWsEvent.createdAt).thenReturn(1704067200);
        when(() => mockWsEvent.id).thenReturn('e' * 64);
        when(
          () => mockWsEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Alice WS'}));

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenAnswer((_) async => [mockWsEvent]);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        // Act
        final result = await repoWithFunnelcake.searchUsers(query: 'alice');

        // Assert - only one result, REST version preserved
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Alice REST'));
      });

      test('skips WebSocket on paginated request (offset > 0)', () async {
        // Arrange
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: 'alice',
            limit: any(named: 'limit'),
            offset: 50,
            sortBy: 'followers',
            hasVideos: true,
          ),
        ).thenAnswer(
          (_) async => [
            ProfileSearchResult(
              pubkey: 'a' * 64,
              displayName: 'Alice Page 2',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            ),
          ],
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        // Act
        final result = await repoWithFunnelcake.searchUsers(
          query: 'alice',
          offset: 50,
          sortBy: 'followers',
          hasVideos: true,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Alice Page 2'));

        // WebSocket should NOT have been called for offset > 0
        verifyNever(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        );
      });

      test('skips client-side filter when sortBy is set', () async {
        // Arrange
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: 'alice',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: 'followers',
            hasVideos: any(named: 'hasVideos'),
          ),
        ).thenAnswer(
          (_) async => [
            ProfileSearchResult(
              pubkey: 'a' * 64,
              displayName: 'Alice REST',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            ),
          ],
        );

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenAnswer((_) async => []);

        var filterCalled = false;
        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          profileSearchFilter: (query, profiles) {
            filterCalled = true;
            return profiles;
          },
        );

        // Act
        await repoWithFunnelcake.searchUsers(
          query: 'alice',
          sortBy: 'followers',
        );

        // Assert - filter should NOT be called when sortBy is set
        expect(filterCalled, isFalse);
      });

      test(
        'preserves Phase 1 REST results when Phase 2 WebSocket throws',
        () async {
          // Arrange
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'alice',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'a' * 64,
                displayName: 'Alice REST',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          // Phase 2 WebSocket throws
          when(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).thenThrow(StateError('WebSocket connection failed'));

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Act
          final result = await repoWithFunnelcake.searchUsers(query: 'alice');

          // Assert - Phase 1 results preserved despite Phase 2 failure
          expect(result, hasLength(1));
          expect(result.first.displayName, equals('Alice REST'));
        },
      );

      test('returns empty list when both phases fail', () async {
        // Arrange
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: 'alice',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
          ),
        ).thenThrow(Exception('REST API error'));

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenThrow(Exception('WebSocket error'));

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        // Act
        final result = await repoWithFunnelcake.searchUsers(query: 'alice');

        // Assert - empty list, no crash
        expect(result, isEmpty);
      });
    });

    group('server-sort fallback ranking', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;
      late ProfileRepository repoWithFunnelcake;

      const pk18Videos =
          'a18b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b18';
      const pk4Videos =
          'a04b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b04';
      const pk1Video =
          'a01b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b01';
      const pkCachedVine =
          'a99b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b99';

      List<ProfileSearchResult> resultsInServerOrder({int followerCount = 0}) =>
          [
            ProfileSearchResult(
              pubkey: pk1Video,
              displayName: 'Lauren One',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              followerCount: followerCount,
              videoCount: 1,
            ),
            ProfileSearchResult(
              pubkey: pk18Videos,
              displayName: 'Lauren Eighteen',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              followerCount: followerCount,
              videoCount: 18,
            ),
            ProfileSearchResult(
              pubkey: pk4Videos,
              displayName: 'Lauren Four',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              followerCount: followerCount,
              videoCount: 4,
            ),
          ];

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => []);
        when(
          () => mockNostrClient.queryUsers(
            any(),
            limit: any(named: 'limit'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => []);
      });

      void stubRestResults(List<ProfileSearchResult> results) {
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
          ),
        ).thenAnswer((_) async => results);
      }

      test('searchUsersProgressive ranks by video count when a followers sort '
          'is a no-op', () async {
        stubRestResults(resultsInServerOrder());

        final emissions = await repoWithFunnelcake
            .searchUsersProgressive(query: 'lauren', sortBy: 'followers')
            .toList();

        final pubkeys = emissions.last.profiles.map((p) => p.pubkey).toList();
        expect(pubkeys, [pk18Videos, pk4Videos, pk1Video]);
      });

      test(
        'searchUsersProgressive puts an exact name ahead of popularity',
        () async {
          stubRestResults([
            ProfileSearchResult(
              pubkey: pk18Videos,
              displayName: 'Alice Archive',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              followerCount: 10000,
              videoCount: 18,
            ),
            ProfileSearchResult(
              pubkey: pk1Video,
              name: 'alice',
              displayName: 'Exact Account',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              followerCount: 1,
              videoCount: 1,
            ),
          ]);

          final result = await repoWithFunnelcake
              .searchUsersProgressive(query: 'alice', sortBy: 'followers')
              .last;

          expect(result.profiles.first.pubkey, pk1Video);
        },
      );

      test(
        'searchUsersProgressive keeps an exact match ahead of followed '
        'partial matches',
        () async {
          ProfileSearchResult followed(String pubkey, String name) =>
              ProfileSearchResult(
                pubkey: pubkey,
                name: name,
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
                followerCount: 500,
                videoCount: 5,
              );
          stubRestResults([
            followed(pk18Videos, 'alice_b'),
            followed(pk4Videos, 'alice_c'),
            followed(pkCachedVine, 'alice_d'),
            ProfileSearchResult(
              pubkey: pk1Video,
              name: 'alice',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              followerCount: 1,
              videoCount: 1,
            ),
          ]);

          final result = await repoWithFunnelcake
              .searchUsersProgressive(
                query: 'alice',
                sortBy: 'followers',
                boostPubkeys: {pk18Videos, pk4Videos, pkCachedVine},
              )
              .last;

          expect(result.profiles.map((profile) => profile.pubkey), [
            pk1Video,
            pk18Videos,
            pk4Videos,
            pkCachedVine,
          ]);
        },
      );

      test(
        'searchUsersProgressive puts the account whose npub was pasted first',
        () async {
          const pkPasted =
              'b01b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b'
              '2c3d4e5f6a1b2c3d4e5f6a1b';
          stubRestResults([
            ProfileSearchResult(
              pubkey: pk18Videos,
              displayName: 'Popular Account',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              followerCount: 10000,
              videoCount: 18,
            ),
            ProfileSearchResult(
              pubkey: pkPasted,
              displayName: 'Pasted Account',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              followerCount: 1,
              videoCount: 1,
            ),
          ]);

          final result = await repoWithFunnelcake
              .searchUsersProgressive(
                query: Nip19.encodePubKey(pkPasted).toUpperCase(),
                sortBy: 'followers',
              )
              .last;

          expect(result.profiles.first.pubkey, pkPasted);
        },
      );

      test(
        'reports REST pagination independently of merged profile count',
        () async {
          stubRestResults(resultsInServerOrder());
          when(() => mockUserProfilesDao.getAllProfiles()).thenAnswer(
            (_) async => [
              UserProfile(
                pubkey: pkCachedVine,
                displayName: 'Lauren Cached',
                createdAt: DateTime(2026),
                eventId: 'cached',
                rawData: const {},
              ),
            ],
          );

          final result = await repoWithFunnelcake
              .searchUsersProgressive(
                query: 'lauren',
                limit: 3,
                offset: 10,
                sortBy: 'followers',
              )
              .last;

          expect(result.nextRestOffset, 13);
          expect(result.restHasMore, isTrue);
        },
      );

      test('searchUsersProgressive breaks a real follower-count tie by '
          'video count', () async {
        stubRestResults(resultsInServerOrder(followerCount: 100));

        final emissions = await repoWithFunnelcake
            .searchUsersProgressive(query: 'lauren', sortBy: 'followers')
            .toList();

        final pubkeys = emissions.last.profiles.map((p) => p.pubkey).toList();
        expect(pubkeys, [pk18Videos, pk4Videos, pk1Video]);
      });

      test('searchUsersProgressive ignores Kind 0 Vine metrics when ranking a '
          'mixed page', () async {
        final cachedVineProfile = UserProfile(
          pubkey: pkCachedVine,
          displayName: 'Lauren Cached Vine',
          rawData: const {'vine_followers': 999999, 'vine_loops': 5000000},
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          eventId: 'kind0-$pkCachedVine',
        );
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => [cachedVineProfile]);
        stubRestResults([
          ProfileSearchResult(
            pubkey: pk1Video,
            displayName: 'Lauren One',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            followerCount: 0,
            videoCount: 1,
          ),
          ProfileSearchResult(
            pubkey: pk18Videos,
            displayName: 'Lauren Eighteen',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            followerCount: 0,
            videoCount: 18,
          ),
        ]);

        final emissions = await repoWithFunnelcake
            .searchUsersProgressive(query: 'lauren', sortBy: 'followers')
            .toList();

        final pubkeys = emissions.last.profiles.map((p) => p.pubkey).toList();
        expect(pubkeys, [pk18Videos, pk1Video, pkCachedVine]);
      });

      test('searchUsers ranks mixed follower-signal pages without leaving the '
          'zero-follower remainder in server order', () async {
        stubRestResults([
          ProfileSearchResult(
            pubkey: pk1Video,
            displayName: 'Lauren One',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            followerCount: 0,
            videoCount: 1,
          ),
          ProfileSearchResult(
            pubkey: pk4Videos,
            displayName: 'Lauren Four',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            followerCount: 25,
            videoCount: 4,
          ),
          ProfileSearchResult(
            pubkey: pk18Videos,
            displayName: 'Lauren Eighteen',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            followerCount: 0,
            videoCount: 18,
          ),
        ]);

        final result = await repoWithFunnelcake.searchUsers(
          query: 'lauren',
          sortBy: 'followers',
        );

        expect(result.map((p) => p.pubkey).toList(), [
          pk4Videos,
          pk18Videos,
          pk1Video,
        ]);
      });

      test(
        'searchUsers ranks by video count when a followers sort is a no-op',
        () async {
          stubRestResults(resultsInServerOrder());

          final result = await repoWithFunnelcake.searchUsers(
            query: 'lauren',
            sortBy: 'followers',
          );

          expect(result.map((p) => p.pubkey).toList(), [
            pk18Videos,
            pk4Videos,
            pk1Video,
          ]);
        },
      );

      test('searchUsersFromApi ranks by video count when a followers sort is a '
          'no-op', () async {
        stubRestResults(resultsInServerOrder());

        final result = await repoWithFunnelcake.searchUsersFromApi(
          query: 'lauren',
          sortBy: 'followers',
        );

        expect(result.map((p) => p.pubkey).toList(), [
          pk18Videos,
          pk4Videos,
          pk1Video,
        ]);
      });
    });

    group('searchUsersProgressive', () {
      test('logs privacy-safe terminal source diagnostics', () async {
        await LogCaptureService().clearAllLogs();
        const privateName = 'Private Search Identity';
        const privatePicture = 'https://identity.example/avatar.jpg';
        final cachedProfile = UserProfile(
          pubkey: testPubkey,
          displayName: privateName,
          picture: privatePicture,
          rawData: const {
            'display_name': privateName,
            'picture': privatePicture,
          },
          createdAt: DateTime(2026),
          eventId: testEventId,
        );
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => [cachedProfile]);
        when(
          () => mockNostrClient.queryUsers(
            privateName,
            limit: 200,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => []);

        await profileRepository
            .searchUsersProgressive(query: privateName)
            .toList();

        final messages = LogCaptureService()
            .getRecentLogs()
            .map((entry) => entry.message)
            .toList();
        final summary = messages.singleWhere(
          (message) => message.startsWith('Search summary:'),
        );
        expect(summary, contains('total=1'));
        expect(summary, contains('local=success(count=1,latencyMs='));
        expect(summary, contains('api=skipped'));
        expect(summary, contains('relay=success(count=0,latencyMs='));
        expect(messages.join('\n'), isNot(contains(privateName)));
        expect(messages.join('\n'), isNot(contains(privatePicture)));
      });

      test('returns empty stream for empty query', () async {
        final results = await profileRepository
            .searchUsersProgressive(query: '')
            .toList();

        expect(results, isEmpty);
      });

      test('returns empty stream for whitespace-only query', () async {
        final results = await profileRepository
            .searchUsersProgressive(query: '   ')
            .toList();

        expect(results, isEmpty);
      });

      test(
        'applies search and block filters once to bounded local candidates',
        () async {
          final included = UserProfile(
            pubkey: testPubkey,
            displayName: 'Included',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: testEventId,
          );
          final blocked = UserProfile(
            pubkey: otherPubkey,
            displayName: 'Blocked',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'e' * 64,
          );
          final repository = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            localProfileSearch: (query, limit) async {
              expect(query, 'test');
              expect(limit, 200);
              return [included, blocked];
            },
            profileSearchFilter: (_, profiles) => profiles,
            blockFilter: (pubkey) => pubkey == otherPubkey,
          );

          final emissions = await repository
              .searchUsersProgressive(query: 'test')
              .toList();

          expect(emissions.first.profiles, [included]);
        },
      );

      test(
        'decodes a full npub query to hex for the bounded local search',
        () async {
          final npub = Nip19.encodePubKey(testPubkey);
          String? receivedTerm;
          final repository = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            localProfileSearch: (query, limit) async {
              receivedTerm = query;
              return [];
            },
          );

          await repository.searchUsersProgressive(query: npub).toList();

          expect(receivedTerm, testPubkey);
        },
      );

      test(
        'leaves an undecodable npub-length query untouched for local search',
        () async {
          // 63 chars, starts with npub1, but 'o' is outside the bech32
          // charset so it cannot decode.
          final invalid = 'npub1${'o' * 58}';
          String? receivedTerm;
          final repository = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            localProfileSearch: (query, limit) async {
              receivedTerm = query;
              return [];
            },
          );

          await repository.searchUsersProgressive(query: invalid).toList();

          expect(receivedTerm, invalid);
        },
      );

      test(
        'passes a non-npub query to the local identity lookup unchanged',
        () async {
          String? receivedQuery;
          final repository = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            localProfileSearch: (query, limit) async {
              receivedQuery = query;
              return [];
            },
          );

          await repository.searchUsersProgressive(query: 'npub1short').toList();

          expect(receivedQuery, 'npub1short');
        },
      );

      test('yields local results first then remote results', () async {
        // Arrange - local cache has a profile
        final cachedProfile = UserProfile(
          pubkey: testPubkey,
          displayName: 'Test User',
          rawData: const {'display_name': 'Test User'},
          createdAt: DateTime(2026),
          eventId: testEventId,
        );
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => [cachedProfile]);

        // Remote NIP-50 returns a different profile
        final mockRemoteEvent = MockEvent();
        when(() => mockRemoteEvent.kind).thenReturn(0);
        when(() => mockRemoteEvent.pubkey).thenReturn(otherPubkey);
        when(() => mockRemoteEvent.createdAt).thenReturn(1704067200);
        when(() => mockRemoteEvent.id).thenReturn('e' * 64);
        when(
          () => mockRemoteEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Test Remote'}));

        when(
          () => mockNostrClient.queryUsers(
            'test',
            limit: 200,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [mockRemoteEvent]);

        // Act
        final emissions = await profileRepository
            .searchUsersProgressive(query: 'test')
            .toList();

        // Assert - at least 2 emissions: local first, then merged
        expect(emissions.length, greaterThanOrEqualTo(2));

        // First emission: local results only
        expect(emissions.first.profiles, hasLength(1));
        expect(emissions.first.profiles.first.pubkey, equals(testPubkey));
        expect(
          emissions.first.sources[SearchSource.localCache],
          isA<SearchSourceSuccess>(),
        );
        expect(
          emissions.first.sources[SearchSource.funnelcakeApi],
          isA<SearchSourcePending>(),
        );
        expect(
          emissions.first.sources[SearchSource.nip50Relay],
          isA<SearchSourcePending>(),
        );
        expect(emissions.first.isComplete, isFalse);

        // Last emission: merged and enriched
        expect(emissions.last.profiles.length, greaterThanOrEqualTo(1));
        expect(emissions.last.isComplete, isTrue);
      });

      test('skips local phase when offset > 0', () async {
        // Arrange
        when(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) async => [mockProfileEvent]);

        // Act
        final emissions = await profileRepository
            .searchUsersProgressive(query: 'test', offset: 10)
            .toList();

        // Assert - only one emission (no local phase)
        expect(emissions, hasLength(1));
        expect(
          emissions.single.sources[SearchSource.localCache],
          isA<SearchSourceSkipped>(),
        );
        expect(
          emissions.single.sources[SearchSource.nip50Relay],
          isA<SearchSourceSkipped>(),
        );

        // NIP-50 should NOT be called for offset > 0
        verifyNever(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        );
      });

      test('yields single result when local cache is empty', () async {
        // Arrange - empty local cache
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => []);

        when(
          () => mockNostrClient.queryUsers(
            'test',
            limit: 200,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [mockProfileEvent]);

        // Act
        final emissions = await profileRepository
            .searchUsersProgressive(query: 'test')
            .toList();

        // Assert - no local emission (empty), just the final one
        expect(emissions, hasLength(1));
        expect(emissions.first.profiles, hasLength(1));
        expect(emissions.first.profiles.first.pubkey, equals(testPubkey));
      });

      group('with FunnelcakeApiClient', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
        });

        test('cancellation after delayed REST prevents relay work', () async {
          final rest = Completer<List<ProfileSearchResult>>();
          final token = SearchCancellationToken('test-search');
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => rest.future);
          final repository = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final resultFuture = repository
              .searchUsersProgressive(
                query: 'test',
                cancellationToken: token,
              )
              .toList();
          await Future<void>.delayed(Duration.zero);
          token.cancel();
          rest.complete([]);

          expect(await resultFuture, isEmpty);
          verifyNever(
            () => mockNostrClient.queryUsers(
              any(),
              limit: any(named: 'limit'),
              timeout: any(named: 'timeout'),
            ),
          );
        });

        test('yields progressively: local, then API+relay merged', () async {
          // Arrange - local cache
          final cachedProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Test Cached',
            rawData: const {'display_name': 'Test Cached'},
            createdAt: DateTime(2026),
            eventId: testEventId,
          );
          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => [cachedProfile]);

          // Funnelcake REST
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: otherPubkey,
                displayName: 'Test REST',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          // NIP-50
          when(
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => []);

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Act
          final emissions = await repoWithFunnelcake
              .searchUsersProgressive(query: 'test')
              .toList();

          // Assert
          expect(emissions.length, greaterThanOrEqualTo(2));

          // First emission: local only
          expect(emissions.first.profiles, hasLength(1));
          expect(
            emissions.first.profiles.first.displayName,
            equals('Test Cached'),
          );

          // Last emission: merged results
          expect(emissions.last.profiles.length, greaterThanOrEqualTo(1));
        });

        test('continues when REST fails and yields WS results', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenThrow(Exception('REST API error'));

          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);

          when(
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => [mockProfileEvent]);

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake
              .searchUsersProgressive(query: 'test')
              .last;

          expect(result.profiles, hasLength(1));
          expect(result.profiles.first.pubkey, equals(testPubkey));
          expect(
            result.sources[SearchSource.funnelcakeApi],
            isA<SearchSourceFailed>(),
          );
        });

        test('continues when WS fails and yields REST results', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'a' * 64,
                displayName: 'Test REST',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);

          when(
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
          ).thenThrow(StateError('WebSocket error'));

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake
              .searchUsersProgressive(query: 'test')
              .last;

          expect(result.profiles, hasLength(1));
          expect(result.profiles.first.displayName, equals('Test REST'));
          expect(
            result.sources[SearchSource.nip50Relay],
            isA<SearchSourceFailed>(),
          );
        });

        test('yields enriched results when WS adds new profiles', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'a' * 64,
                displayName: 'Test REST',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          final mockWsEvent = MockEvent();
          when(() => mockWsEvent.kind).thenReturn(0);
          when(() => mockWsEvent.pubkey).thenReturn('b' * 64);
          when(() => mockWsEvent.createdAt).thenReturn(1704067200);
          when(() => mockWsEvent.id).thenReturn('c' * 64);
          when(
            () => mockWsEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Test WS'}));

          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);

          when(
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => [mockWsEvent]);

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake
              .searchUsersProgressive(query: 'test')
              .last;

          // Both REST and WS results merged
          expect(result.profiles, hasLength(2));
        });

        test('uses custom profileSearchFilter when no server sort', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);

          final mockWsEvent = MockEvent();
          when(() => mockWsEvent.kind).thenReturn(0);
          when(() => mockWsEvent.pubkey).thenReturn('a' * 64);
          when(() => mockWsEvent.createdAt).thenReturn(1704067200);
          when(() => mockWsEvent.id).thenReturn('b' * 64);
          when(
            () => mockWsEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Alice Test'}));

          when(
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => [mockWsEvent]);

          var filterCalled = false;
          final repoWithFilter = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileSearchFilter: (query, profiles) {
              filterCalled = true;
              return profiles;
            },
          );

          await repoWithFilter.searchUsersProgressive(query: 'test').last;

          expect(filterCalled, isTrue);
        });

        test(
          'skips client-side filter on final yield when sortBy is set',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.searchProfiles(
                query: 'alice',
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                sortBy: 'followers',
                hasVideos: any(named: 'hasVideos'),
              ),
            ).thenAnswer(
              (_) async => [
                ProfileSearchResult(
                  pubkey: 'a' * 64,
                  displayName: 'Alice REST',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
                ),
              ],
            );

            when(
              () => mockNostrClient.queryUsers(
                'alice',
                limit: 200,
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer((_) async => []);

            when(
              () => mockUserProfilesDao.getAllProfiles(),
            ).thenAnswer((_) async => []);

            // Track filter calls with their context
            var finalYieldFilterCalled = false;
            final repoWithFunnelcake = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
              profileSearchFilter: (query, profiles) {
                // The filter may be called by searchUsersLocally (local phase),
                // but should NOT be called by _applyFilter when sortBy is set.
                // If called with non-empty profiles it means the final yield
                // is filtering — which it shouldn't with server sort.
                if (profiles.isNotEmpty) finalYieldFilterCalled = true;
                return profiles;
              },
            );

            // Act
            final result = await repoWithFunnelcake
                .searchUsersProgressive(query: 'alice', sortBy: 'followers')
                .last;

            // Assert - final yield preserves server order, filter not called
            // on non-empty results
            expect(result.profiles, hasLength(1));
            expect(result.profiles.first.displayName, equals('Alice REST'));
            expect(finalYieldFilterCalled, isFalse);
          },
        );
      });

      group('with boostPubkeys', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        // Three distinct 64-char hex pubkeys.
        final pubA = 'a' * 64;
        final pubB = 'b' * 64;
        final pubC = 'c' * 64;

        ProfileSearchResult restResult(String pubkey, String name) {
          return ProfileSearchResult(
            pubkey: pubkey,
            displayName: name,
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          );
        }

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);
          when(
            () => mockNostrClient.queryUsers(
              any(),
              limit: any(named: 'limit'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => []);
        });

        test(
          'promotes boosted pubkeys to the front on the initial page',
          () async {
            when(
              () => mockFunnelcakeClient.searchProfiles(
                query: 'liz',
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                sortBy: any(named: 'sortBy'),
                hasVideos: any(named: 'hasVideos'),
              ),
            ).thenAnswer(
              (_) async => [
                restResult(pubA, 'Zoe'),
                restResult(pubB, 'Liz'),
                restResult(pubC, 'Maya'),
              ],
            );

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(
                  query: 'liz',
                  sortBy: 'followers',
                  boostPubkeys: {pubB},
                )
                .last;

            expect(
              result.profiles.map((p) => p.displayName).toList(),
              equals(['Liz', 'Zoe', 'Maya']),
            );
          },
        );

        test(
          'preserves server-relative order within each boost group',
          () async {
            when(
              () => mockFunnelcakeClient.searchProfiles(
                query: 'test',
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                sortBy: any(named: 'sortBy'),
                hasVideos: any(named: 'hasVideos'),
              ),
            ).thenAnswer(
              (_) async => [
                restResult(pubA, 'A'), // boosted
                restResult(pubB, 'B'), // not boosted
                restResult(pubC, 'C'), // boosted
                restResult('d' * 64, 'D'), // not boosted
              ],
            );

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(
                  query: 'test',
                  sortBy: 'followers',
                  boostPubkeys: {pubA, pubC},
                )
                .last;

            expect(
              result.profiles.map((p) => p.displayName).toList(),
              equals(['A', 'C', 'B', 'D']),
            );
          },
        );

        test('is a no-op when the boost set is empty', () async {
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [restResult(pubA, 'Zoe'), restResult(pubB, 'Maya')],
          );

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo
              .searchUsersProgressive(
                query: 'test',
                sortBy: 'followers',
                boostPubkeys: const <String>{},
              )
              .last;

          expect(
            result.profiles.map((p) => p.displayName).toList(),
            equals(['Zoe', 'Maya']),
          );
        });

        test('is a no-op when boostPubkeys is null', () async {
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [restResult(pubA, 'Zoe'), restResult(pubB, 'Maya')],
          );

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo
              .searchUsersProgressive(query: 'test', sortBy: 'followers')
              .last;

          expect(
            result.profiles.map((p) => p.displayName).toList(),
            equals(['Zoe', 'Maya']),
          );
        });

        test('is a no-op when no result is in the boost set', () async {
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [restResult(pubA, 'Zoe'), restResult(pubB, 'Maya')],
          );

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo
              .searchUsersProgressive(
                query: 'test',
                sortBy: 'followers',
                boostPubkeys: {'f' * 64},
              )
              .last;

          expect(
            result.profiles.map((p) => p.displayName).toList(),
            equals(['Zoe', 'Maya']),
          );
        });
      });

      group('source provenance', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        });

        test('records success on every source when all succeed', () async {
          final cachedProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Cached',
            rawData: const {'display_name': 'Cached'},
            createdAt: DateTime(2026),
            eventId: testEventId,
          );
          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => [cachedProfile]);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'a' * 64,
                displayName: 'REST User',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          final wsEvent = MockEvent();
          when(() => wsEvent.kind).thenReturn(0);
          when(() => wsEvent.pubkey).thenReturn('b' * 64);
          when(() => wsEvent.createdAt).thenReturn(1704067200);
          when(() => wsEvent.id).thenReturn('c' * 64);
          when(
            () => wsEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'WS User'}));
          when(
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => [wsEvent]);

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.searchUsersProgressive(query: 'test').last;

          expect(
            result.sources[SearchSource.localCache],
            isA<SearchSourceSuccess>(),
          );
          expect(
            result.sources[SearchSource.funnelcakeApi],
            isA<SearchSourceSuccess>(),
          );
          expect(
            result.sources[SearchSource.nip50Relay],
            isA<SearchSourceSuccess>(),
          );
          expect(result.isComplete, isTrue);
        });

        test(
          'records SearchSourceFailed(other) when local cache throws',
          () async {
            when(
              () => mockUserProfilesDao.getAllProfiles(),
            ).thenThrow(StateError('db down'));
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
            when(
              () => mockNostrClient.queryUsers(
                'test',
                limit: 200,
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer((_) async => []);

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(query: 'test')
                .last;

            final localStatus = result.sources[SearchSource.localCache];
            expect(localStatus, isA<SearchSourceFailed>());
            expect(
              (localStatus! as SearchSourceFailed).reason,
              SearchSourceFailureReason.other,
            );
          },
        );

        test('records SearchSourceFailed(network) when REST throws', () async {
          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenThrow(Exception('connection refused'));
          when(
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => []);

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.searchUsersProgressive(query: 'test').last;

          final apiStatus = result.sources[SearchSource.funnelcakeApi];
          expect(apiStatus, isA<SearchSourceFailed>());
          expect(
            (apiStatus! as SearchSourceFailed).reason,
            SearchSourceFailureReason.network,
          );
        });

        test(
          'records SearchSourceFailed(timeout) when NIP-50 times out',
          () async {
            when(
              () => mockUserProfilesDao.getAllProfiles(),
            ).thenAnswer((_) async => []);
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
            when(
              () => mockNostrClient.queryUsers(
                'test',
                limit: 200,
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer((_) async {
              // Sleep past the 5 s NIP-50 timeout so .timeout() fires.
              await Future<void>.delayed(const Duration(seconds: 6));
              return <Event>[];
            });

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(query: 'test')
                .last;

            final relayStatus = result.sources[SearchSource.nip50Relay];
            expect(relayStatus, isA<SearchSourceFailed>());
            expect(
              (relayStatus! as SearchSourceFailed).reason,
              SearchSourceFailureReason.timeout,
            );
            verify(
              () => mockNostrClient.queryUsers(
                'test',
                limit: 200,
                timeout: const Duration(milliseconds: 4500),
              ),
            ).called(1);
          },
          timeout: const Timeout(Duration(seconds: 10)),
        );

        test(
          'records failures across all sources when everything fails',
          () async {
            when(
              () => mockUserProfilesDao.getAllProfiles(),
            ).thenAnswer((_) async => []);
            when(
              () => mockFunnelcakeClient.searchProfiles(
                query: 'test',
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                sortBy: any(named: 'sortBy'),
                hasVideos: any(named: 'hasVideos'),
              ),
            ).thenThrow(Exception('REST down'));
            when(
              () => mockNostrClient.queryUsers(
                'test',
                limit: 200,
                timeout: any(named: 'timeout'),
              ),
            ).thenThrow(StateError('WS down'));

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(query: 'test')
                .last;

            expect(result.profiles, isEmpty);
            expect(
              result.sources[SearchSource.localCache],
              isA<SearchSourceSuccess>(), // empty local is still "success"
            );
            expect(
              result.sources[SearchSource.funnelcakeApi],
              isA<SearchSourceFailed>(),
            );
            expect(
              result.sources[SearchSource.nip50Relay],
              isA<SearchSourceFailed>(),
            );
            expect(result.isComplete, isTrue);
          },
        );

        test(
          'records SearchSourceSkipped for funnelcake when unavailable',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
            when(
              () => mockUserProfilesDao.getAllProfiles(),
            ).thenAnswer((_) async => []);
            when(
              () => mockNostrClient.queryUsers(
                'test',
                limit: 200,
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer((_) async => []);

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(query: 'test')
                .last;

            expect(
              result.sources[SearchSource.funnelcakeApi],
              isA<SearchSourceSkipped>(),
            );
          },
        );
      });
    });

    group('exceptions', () {
      test('ProfilePublishFailedException has message and toString', () {
        const e = ProfilePublishFailedException('test');

        expect(e.message, equals('test'));
        expect(e.toString(), contains('test'));
      });

      test('ProfileRepositoryException handles null message', () {
        const e = ProfileRepositoryException();

        expect(e.message, isNull);
        expect(e.toString(), contains('ProfileRepositoryException'));
      });

      test('NoRelaysConnectedException has message and toString', () {
        const e = NoRelaysConnectedException('no relays');

        expect(e.message, equals('no relays'));
        expect(e.toString(), equals('NoRelaysConnectedException: no relays'));
      });
    });

    group('lookupUsernameByPubkey', () {
      const pubkey =
          '156dd13a1f8a488037fa1b43ad934a5e58644a1d6e1ad6697a02c2e93b8b013b';

      test('returns DivineUsernameFound when found', () async {
        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) => Future.value(
            Response(
              '{"ok":true,"found":true,"name":"Alice","canonical":"alice"}',
              200,
            ),
          ),
        );

        final result = await profileRepository.lookupUsernameByPubkey(
          pubkeyHex: pubkey,
        );

        expect(result, isA<DivineUsernameFound>());
        final found = result as DivineUsernameFound;
        expect(found.name, 'Alice');
        expect(found.canonical, 'alice');
      });

      test('returns DivineUsernameNotFound for a confirmed miss', () async {
        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) => Future.value(Response('{"ok":true,"found":false}', 200)),
        );

        final result = await profileRepository.lookupUsernameByPubkey(
          pubkeyHex: pubkey,
        );

        expect(result, isA<DivineUsernameNotFound>());
      });

      test('returns DivineUsernameUnknown for a 400 response', () async {
        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) => Future.value(
            Response('{"ok":false,"error":"Invalid pubkey format"}', 400),
          ),
        );

        final result = await profileRepository.lookupUsernameByPubkey(
          pubkeyHex: pubkey,
        );

        expect(result, isA<DivineUsernameUnknown>());
      });

      test('returns DivineUsernameUnknown on network exception', () async {
        when(() => mockHttpClient.get(any())).thenThrow(Exception('socket'));

        final result = await profileRepository.lookupUsernameByPubkey(
          pubkeyHex: pubkey,
        );

        expect(result, isA<DivineUsernameUnknown>());
      });

      test(
        'returns DivineUsernameUnknown on a wrong-shaped 200 body',
        () async {
          when(
            () => mockHttpClient.get(any()),
          ).thenAnswer((_) => Future.value(Response('123', 200)));

          final result = await profileRepository.lookupUsernameByPubkey(
            pubkeyHex: pubkey,
          );

          expect(result, isA<DivineUsernameUnknown>());
        },
      );
    });

    group('claimUsername', () {
      test('returns UsernameClaimSuccess when response is 200', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('body', 200)));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(usernameClaimResult, equals(const UsernameClaimSuccess()));
      });

      test('returns UsernameClaimSuccess when response is 201', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('body', 201)));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(usernameClaimResult, equals(const UsernameClaimSuccess()));
      });

      test('returns UsernameClaimReserved when response is 403', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('body', 403)));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(usernameClaimResult, equals(const UsernameClaimReserved()));
      });

      test('returns UsernameClaimTaken when response is 409', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('body', 409)));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(usernameClaimResult, equals(const UsernameClaimTaken()));
      });

      test('returns UsernameClaimError when response is unexpected', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('body', 500)));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(
          usernameClaimResult,
          isA<UsernameClaimError>().having(
            (e) => e.message,
            'message',
            'Unexpected response: 500',
          ),
        );
      });

      test('returns UsernameClaimNetworkError on network exception', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(ClientException('network exception'));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(usernameClaimResult, isA<UsernameClaimNetworkError>());
      });

      test(
        'returns UsernameClaimError when nip98 auth header is null',
        () async {
          when(
            () => mockNostrClient.createNip98AuthHeader(
              url: any(named: 'url'),
              method: any(named: 'method'),
              payload: any(named: 'payload'),
            ),
          ).thenAnswer((_) => Future.value());

          final usernameClaimResult = await profileRepository.claimUsername(
            username: 'username',
          );
          expect(
            usernameClaimResult,
            isA<UsernameClaimError>().having(
              (e) => e.message,
              'message',
              'Nip98 authorization failed',
            ),
          );

          verifyNever(() => mockHttpClient.post(any()));
        },
      );

      // The signer can throw rather than return null — a Keycast RPC error or
      // timeout does, on a fully keyed account. Nothing between here and the
      // signer catches, and this method's own handler is `on Exception`, so
      // without local containment the throw left claimUsername entirely.
      test('returns UsernameClaimError when the signer throws', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenThrow(StateError('no signer'));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );

        expect(
          usernameClaimResult,
          isA<UsernameClaimError>().having(
            (e) => e.message,
            'message',
            'Signing failed',
          ),
        );

        // The request never left the device, so no name was claimed.
        verifyNever(() => mockHttpClient.post(any()));
      });

      test(
        'sends lowercase username in payload for mixed-case input',
        () async {
          final expectedPayload = jsonEncode({'name': 'testuser'});
          when(
            () => mockNostrClient.createNip98AuthHeader(
              url: any(named: 'url'),
              method: any(named: 'method'),
              payload: any(named: 'payload'),
            ),
          ).thenAnswer((_) => Future.value('authHeader'));
          when(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) => Future.value(Response('body', 200)));

          final result = await profileRepository.claimUsername(
            username: 'TestUser',
          );

          expect(result, equals(const UsernameClaimSuccess()));
          verify(
            () => mockHttpClient.post(
              Uri.parse('$_testNameServer/api/username/claim'),
              headers: any(named: 'headers'),
              body: expectedPayload,
            ),
          ).called(1);
        },
      );

      test(
        'returns validation error for too-short username before request',
        () async {
          final result = await profileRepository.claimUsername(username: 'ab');

          expect(
            result,
            isA<UsernameClaimInvalidFormat>().having(
              (e) => e.failure,
              'failure',
              DivineUsernameValidationFailure.invalidLength,
            ),
          );
          verifyNever(
            () => mockNostrClient.createNip98AuthHeader(
              url: any(named: 'url'),
              method: any(named: 'method'),
              payload: any(named: 'payload'),
            ),
          );
          verifyNever(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          );
        },
      );

      test('returns server error message when claim returns 400 '
          'with JSON error body', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) => Future.value(
            Response('{"error": "Name server rejected claim"}', 400),
          ),
        );

        final result = await profileRepository.claimUsername(
          username: 'validuser',
        );

        expect(
          result,
          isA<UsernameClaimError>().having(
            (e) => e.message,
            'message',
            'Name server rejected claim',
          ),
        );
      });

      test('returns error with default message when server returns '
          'non-200 with unparseable body', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('not json at all', 400)));

        final result = await profileRepository.claimUsername(
          username: 'baduser',
        );

        expect(
          result,
          isA<UsernameClaimError>().having(
            (e) => e.message,
            'message',
            'Invalid username format',
          ),
        );
      });

      test(
        'returns UsernameClaimNetworkError when the POST exceeds the timeout',
        () {
          fakeAsync((async) {
            when(
              () => mockNostrClient.createNip98AuthHeader(
                url: any(named: 'url'),
                method: any(named: 'method'),
                payload: any(named: 'payload'),
              ),
            ).thenAnswer((_) => Future.value('authHeader'));
            when(
              () => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ),
            ).thenAnswer((_) async {
              // Simulates an unresponsive name server: never resolves within
              // the repository's _nameServerHttpTimeout (10s).
              await Future<void>.delayed(const Duration(minutes: 5));
              return Response('unused', 200);
            });

            UsernameClaimResult? result;
            unawaited(
              profileRepository
                  .claimUsername(username: 'username')
                  .then((r) => result = r),
            );

            // Below the 10s repository timeout — call still pending.
            async
              ..elapse(const Duration(seconds: 9))
              ..flushMicrotasks();
            expect(result, isNull);

            // Crosses the 10s repository timeout.
            async
              ..elapse(const Duration(seconds: 2))
              ..flushMicrotasks();
            expect(result, isA<UsernameClaimNetworkError>());
          });
        },
      );
    });

    group('UsernameClaimResult', () {
      test('UsernameClaimError toString returns formatted message', () {
        const error = UsernameClaimError('test error');
        expect(error.toString(), equals('UsernameClaimError(test error)'));
      });
    });

    group('checkUsernameAvailability', () {
      // Helper: stub name-server check endpoint
      void stubNameServerCheck(
        String username, {
        bool available = true,
        String? reason,
        String? code,
        int statusCode = 200,
      }) {
        when(
          () => mockHttpClient.get(
            Uri.parse('$_testNameServer/api/username/check/$username'),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'available': available,
              'reason': ?reason,
              'code': ?code,
            }),
            statusCode,
          ),
        );
      }

      // Helper: stub keycast NIP-05 endpoint
      void stubKeycastCheck(
        String username, {
        bool taken = false,
        int statusCode = 200,
      }) {
        when(
          () => mockHttpClient.get(
            Uri.parse(
              '$_testKeycastNip05'
              '?name=$username',
            ),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'names': taken ? {username: 'pubkey123'} : <String, dynamic>{},
            }),
            statusCode,
          ),
        );
      }

      test(
        'returns UsernameAvailable when both servers say available',
        () async {
          stubNameServerCheck('newuser');
          stubKeycastCheck('newuser');

          final result = await profileRepository.checkUsernameAvailability(
            username: 'newuser',
          );

          expect(result, equals(const UsernameAvailable()));
        },
      );

      test(
        'returns UsernameTaken when name-server says not available',
        () async {
          stubNameServerCheck('takenuser', available: false);

          final result = await profileRepository.checkUsernameAvailability(
            username: 'takenuser',
          );

          expect(result, equals(const UsernameTaken()));
        },
      );

      test('returns UsernameTaken when name-server says available but '
          'keycast has it', () async {
        stubNameServerCheck('keycastuser');
        stubKeycastCheck('keycastuser', taken: true);

        final result = await profileRepository.checkUsernameAvailability(
          username: 'keycastuser',
        );

        expect(result, equals(const UsernameTaken()));
      });

      test('returns UsernameAvailable when keycast is unreachable '
          'but name-server says available', () async {
        stubNameServerCheck('testuser');
        when(
          () => mockHttpClient.get(
            Uri.parse(
              '$_testKeycastNip05'
              '?name=testuser',
            ),
          ),
        ).thenThrow(Exception('Connection timeout'));

        final result = await profileRepository.checkUsernameAvailability(
          username: 'testuser',
        );

        // Keycast failure is non-blocking
        expect(result, equals(const UsernameAvailable()));
      });

      test('returns UsernameInvalidFormat for names with dots', () async {
        final result = await profileRepository.checkUsernameAvailability(
          username: 'mr.',
        );

        expect(result, isA<UsernameInvalidFormat>());
      });

      test('returns UsernameInvalidFormat for too-short names', () async {
        final result = await profileRepository.checkUsernameAvailability(
          username: 'ab',
        );

        expect(
          result,
          isA<UsernameInvalidFormat>().having(
            (e) => e.failure,
            'failure',
            DivineUsernameValidationFailure.invalidLength,
          ),
        );
        verifyNever(
          () => mockHttpClient.get(
            Uri.parse('$_testNameServer/api/username/check/ab'),
          ),
        );
      });

      test(
        'returns UsernameInvalidFormat for names with underscores',
        () async {
          final result = await profileRepository.checkUsernameAvailability(
            username: 'my_name',
          );

          expect(result, isA<UsernameInvalidFormat>());
        },
      );

      test(
        'returns UsernameInvalidFormat for names starting with hyphen',
        () async {
          final result = await profileRepository.checkUsernameAvailability(
            username: '-alice',
          );

          expect(result, isA<UsernameInvalidFormat>());
        },
      );

      test(
        'returns UsernameInvalidFormat for names ending with hyphen',
        () async {
          final result = await profileRepository.checkUsernameAvailability(
            username: 'alice-',
          );

          expect(result, isA<UsernameInvalidFormat>());
        },
      );

      test('returns UsernameCheckError when name-server returns 500', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('$_testNameServer/api/username/check/testuser'),
          ),
        ).thenAnswer((_) async => Response('Server error', 500));

        final result = await profileRepository.checkUsernameAvailability(
          username: 'testuser',
        );

        expect(
          result,
          isA<UsernameCheckError>().having(
            (e) => e.message,
            'message',
            'Server returned status 500',
          ),
        );
      });

      test('returns UsernameCheckError on network exception', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('$_testNameServer/api/username/check/testuser'),
          ),
        ).thenThrow(Exception('Connection timeout'));

        final result = await profileRepository.checkUsernameAvailability(
          username: 'testuser',
        );

        expect(
          result,
          isA<UsernameCheckError>().having(
            (e) => e.message,
            'message',
            'Network error: Exception: Connection timeout',
          ),
        );
      });

      test('normalizes username to lowercase', () async {
        stubNameServerCheck('alice');
        stubKeycastCheck('alice');

        final result = await profileRepository.checkUsernameAvailability(
          username: 'Alice',
        );

        expect(result, equals(const UsernameAvailable()));

        verify(
          () => mockHttpClient.get(
            Uri.parse('$_testNameServer/api/username/check/alice'),
          ),
        ).called(1);
      });

      // --- code field tests ---

      test('returns $UsernameReserved when code is reserved', () async {
        stubNameServerCheck(
          'admin',
          available: false,
          code: 'reserved',
          reason: 'Username is reserved',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'admin',
        );
        expect(result, isA<UsernameReserved>());
      });

      test('returns $UsernameBurned when code is burned', () async {
        stubNameServerCheck(
          'badname',
          available: false,
          code: 'burned',
          reason: 'Username has been burned',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'badname',
        );
        expect(result, isA<UsernameBurned>());
      });

      test('returns $UsernameTaken when code is taken', () async {
        stubNameServerCheck(
          'alice',
          available: false,
          code: 'taken',
          reason: 'Username is already taken',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'alice',
        );
        expect(result, isA<UsernameTaken>());
      });

      test(
        'returns $UsernameTaken when code is pending_confirmation',
        () async {
          stubNameServerCheck(
            'pending',
            available: false,
            code: 'pending_confirmation',
            reason: 'Username is pending confirmation',
          );
          final result = await profileRepository.checkUsernameAvailability(
            username: 'pending',
          );
          expect(result, isA<UsernameTaken>());
        },
      );

      test(
        'returns $UsernameInvalidFormat when code is invalid_format',
        () async {
          stubNameServerCheck(
            'bad..name',
            available: false,
            code: 'invalid_format',
            reason: 'Contains consecutive dots',
          );
          final result = await profileRepository.checkUsernameAvailability(
            username: 'bad..name',
          );
          expect(result, isA<UsernameInvalidFormat>());
        },
      );

      test('returns $UsernameInvalidFormat without a client failure '
          'when the server rejects the format', () async {
        stubNameServerCheck('bad', available: false, code: 'invalid_format');
        final result = await profileRepository.checkUsernameAvailability(
          username: 'bad',
        );
        expect(result, isA<UsernameInvalidFormat>());
        expect((result as UsernameInvalidFormat).failure, isNull);
      });

      test('returns $UsernameTaken when code field is missing', () async {
        stubNameServerCheck(
          'mystery',
          available: false,
          reason: 'Something unexpected',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'mystery',
        );
        expect(result, isA<UsernameTaken>());
      });

      test('returns UsernameAvailable when name is taken but pubkey matches '
          'current user (admin-assigned)', () async {
        // Simulate the name-server returning pubkey for an active name
        when(
          () => mockHttpClient.get(
            Uri.parse('$_testNameServer/api/username/check/vipuser'),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'ok': true,
              'available': false,
              'status': 'active',
              'pubkey': testPubkey,
              'reason': 'Username is already taken',
            }),
            200,
          ),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'vipuser',
          currentUserPubkey: testPubkey,
        );

        expect(result, equals(const UsernameAvailable()));
      });

      test('returns UsernameTaken when name is taken and pubkey does not match '
          'current user', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('$_testNameServer/api/username/check/vipuser'),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'ok': true,
              'available': false,
              'status': 'active',
              'pubkey': otherPubkey,
              'reason': 'Username is already taken',
            }),
            200,
          ),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'vipuser',
          currentUserPubkey: testPubkey,
        );

        expect(result, equals(const UsernameTaken()));
      });

      test('returns UsernameTaken when name is taken and no currentUserPubkey '
          'provided (backwards compatible)', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('$_testNameServer/api/username/check/vipuser'),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'ok': true,
              'available': false,
              'status': 'active',
              'pubkey': testPubkey,
              'reason': 'Username is already taken',
            }),
            200,
          ),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'vipuser',
        );

        expect(result, equals(const UsernameTaken()));
      });

      test('returns UsernameCheckError when the GET exceeds the timeout', () {
        fakeAsync((async) {
          when(
            () => mockHttpClient.get(
              Uri.parse('$_testNameServer/api/username/check/testuser'),
            ),
          ).thenAnswer((_) async {
            // Simulates an unresponsive name server: never resolves within
            // the repository's _nameServerHttpTimeout (10s).
            await Future<void>.delayed(const Duration(minutes: 5));
            return Response('unused', 200);
          });

          UsernameAvailabilityResult? result;
          unawaited(
            profileRepository
                .checkUsernameAvailability(username: 'testuser')
                .then((r) => result = r),
          );

          async
            ..elapse(const Duration(seconds: 9))
            ..flushMicrotasks();
          expect(result, isNull);

          async
            ..elapse(const Duration(seconds: 2))
            ..flushMicrotasks();
          expect(
            result,
            isA<UsernameCheckError>().having(
              (e) => e.message,
              'message',
              contains('TimeoutException'),
            ),
          );
        });
      });
    });

    group('UsernameAvailabilityResult', () {
      test('UsernameCheckError toString returns formatted message', () {
        const error = UsernameCheckError('test error');
        expect(error.toString(), equals('UsernameCheckError(test error)'));
      });
    });

    group('getUserProfileFromApi', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns UserProfileFound on success', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getUserProfile(testPubkey)).thenAnswer(
          (_) async => UserProfileFound(
            profile: UserProfileData.fromJson(testPubkey, const {
              'display_name': 'Test User',
              'picture': 'https://example.com/avatar.png',
            }),
          ),
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getUserProfileFromApi(
          pubkey: testPubkey,
        );

        expect(result, isA<UserProfileFound>());
        expect(
          (result! as UserProfileFound).profile.displayName,
          equals('Test User'),
        );
        verify(() => mockFunnelcakeClient.getUserProfile(testPubkey)).called(1);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getUserProfileFromApi(
          pubkey: testPubkey,
        );

        expect(result, isNull);
        verifyNever(() => mockFunnelcakeClient.getUserProfile(any()));
      });

      test('returns null when client is null', () async {
        final result = await profileRepository.getUserProfileFromApi(
          pubkey: testPubkey,
        );

        expect(result, isNull);
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getUserProfile(any())).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/users',
          ),
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repoWithFunnelcake.getUserProfileFromApi(pubkey: testPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('propagates FunnelcakeTimeoutException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getUserProfile(any()),
        ).thenThrow(const FunnelcakeTimeoutException());

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repoWithFunnelcake.getUserProfileFromApi(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getBulkProfilesFromApi', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns BulkProfilesResponse on success', () async {
        final testResponse = BulkProfilesResponse(
          profiles: {
            testPubkey: UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'Test User',
                'picture': 'https://example.com/avatar.png',
              }),
            ),
          },
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getBulkProfiles([testPubkey]),
        ).thenAnswer((_) async => testResponse);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getBulkProfilesFromApi([
          testPubkey,
        ]);

        expect(result, isNotNull);
        expect(result!.profiles, hasLength(1));
        expect(result.profiles[testPubkey], isNotNull);
        verify(
          () => mockFunnelcakeClient.getBulkProfiles([testPubkey]),
        ).called(1);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getBulkProfilesFromApi([
          testPubkey,
        ]);

        expect(result, isNull);
        verifyNever(() => mockFunnelcakeClient.getBulkProfiles(any()));
      });

      test('returns null when client is null', () async {
        final result = await profileRepository.getBulkProfilesFromApi([
          testPubkey,
        ]);

        expect(result, isNull);
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/users/bulk',
          ),
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repoWithFunnelcake.getBulkProfilesFromApi([testPubkey]),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('propagates FunnelcakeTimeoutException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getBulkProfiles(any()),
        ).thenThrow(const FunnelcakeTimeoutException());

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repoWithFunnelcake.getBulkProfilesFromApi([testPubkey]),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getSocialCounts', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns SocialCounts when client is available', () async {
        const expectedCounts = SocialCounts(
          pubkey: testPubkey,
          followerCount: 42,
          followingCount: 10,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getSocialCounts(testPubkey),
        ).thenAnswer((_) async => expectedCounts);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getSocialCounts(testPubkey);

        expect(result, isNotNull);
        expect(result!.followerCount, 42);
        expect(result.followingCount, 10);
        verify(
          () => mockFunnelcakeClient.getSocialCounts(testPubkey),
        ).called(1);
      });

      test('returns null when client is null', () async {
        final result = await profileRepository.getSocialCounts(testPubkey);

        expect(result, isNull);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getSocialCounts(testPubkey);

        expect(result, isNull);
        verifyNever(() => mockFunnelcakeClient.getSocialCounts(any()));
      });

      test('passes pubkey to client correctly', () async {
        // Uses the sibling otherPubkey constant defined in the parent group.
        const expectedCounts = SocialCounts(
          pubkey: otherPubkey,
          followerCount: 5,
          followingCount: 3,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getSocialCounts(otherPubkey),
        ).thenAnswer((_) async => expectedCounts);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getSocialCounts(otherPubkey);

        expect(result, isNotNull);
        verify(
          () => mockFunnelcakeClient.getSocialCounts(otherPubkey),
        ).called(1);
        verifyNever(() => mockFunnelcakeClient.getSocialCounts(testPubkey));
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getSocialCounts(any())).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/users/$testPubkey/social',
          ),
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repoWithFunnelcake.getSocialCounts(testPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });

    group('fetchBatchProfiles', () {
      const testPubkey2 =
          'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
      const testPubkey3 =
          'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';

      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();

        registerFallbackValue(<UserProfile>[]);
      });

      test('returns empty map for empty pubkeys', () async {
        final result = await profileRepository.fetchBatchProfiles(pubkeys: []);
        expect(result, isEmpty);
      });

      test('returns all from cache when all are cached', () async {
        final cached = UserProfile(
          pubkey: testPubkey,
          displayName: 'Cached',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'cached-event',
        );
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys([testPubkey]),
        ).thenAnswer((_) async => [cached]);

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('Cached'));
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });

      test('filters blocked profiles when all results are cached', () async {
        final blocked = UserProfile(
          pubkey: testPubkey,
          displayName: 'Blocked Cached',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'blocked-cached-event',
        );
        final allowed = UserProfile(
          pubkey: testPubkey2,
          displayName: 'Allowed Cached',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'allowed-cached-event',
        );
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys([
            testPubkey,
            testPubkey2,
          ]),
        ).thenAnswer((_) async => [blocked, allowed]);

        final repoWithBlockFilter = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          blockFilter: (pubkey) => pubkey == testPubkey,
        );

        final result = await repoWithBlockFilter.fetchBatchProfiles(
          pubkeys: [testPubkey, testPubkey2],
        );

        expect(result.containsKey(testPubkey), isFalse);
        expect(result[testPubkey2]?.displayName, equals('Allowed Cached'));
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });

      test(
        'returns uncached blocked profiles when the block filter is bypassed',
        () async {
          when(
            () => mockUserProfilesDao.getProfilesByPubkeys([testPubkey]),
          ).thenAnswer((_) async => []);
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getBulkProfiles([testPubkey]),
          ).thenAnswer(
            (_) async => BulkProfilesResponse(
              profiles: {
                testPubkey: UserProfileFound(
                  profile: UserProfileData.fromJson(testPubkey, const {
                    'display_name': 'Blocked API User',
                  }),
                ),
              },
            ),
          );
          when(
            () => mockUserProfilesDao.upsertProfiles(any()),
          ).thenAnswer((_) async {});

          final repoWithBlockFilter = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: (pubkey) => pubkey == testPubkey,
          );

          final result = await repoWithBlockFilter.fetchBatchProfiles(
            pubkeys: [testPubkey],
            ignoreBlockFilter: true,
          );

          expect(result[testPubkey]?.displayName, equals('Blocked API User'));
          verifyNever(() => mockNostrClient.fetchProfile(any()));
        },
      );

      test('fetches uncached from Funnelcake API', () async {
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
          (_) async => BulkProfilesResponse(
            profiles: {
              testPubkey: UserProfileFound(
                profile: UserProfileData.fromJson(testPubkey, const {
                  'display_name': 'API User',
                  'picture': 'https://example.com/pic.jpg',
                }),
              ),
            },
          ),
        );
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('API User'));
        verify(() => mockUserProfilesDao.upsertProfiles(any())).called(1);
      });

      test('falls back to relay for pubkeys not in cache or API', () async {
        final relayEvent = MockEvent();
        when(() => relayEvent.kind).thenReturn(0);
        when(() => relayEvent.pubkey).thenReturn(testPubkey);
        when(() => relayEvent.createdAt).thenReturn(1704067200);
        when(() => relayEvent.id).thenReturn(testEventId);
        when(
          () => relayEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Relay User'}));

        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => relayEvent);
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('Relay User'));
      });

      test('combines cache, API, and relay results', () async {
        final cachedProfile = UserProfile(
          pubkey: testPubkey,
          displayName: 'Cached',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'cached-event',
        );

        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => [cachedProfile]);
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
          (_) async => BulkProfilesResponse(
            profiles: {
              testPubkey2: UserProfileFound(
                profile: UserProfileData.fromJson(testPubkey2, const {
                  'display_name': 'API User',
                }),
              ),
            },
          ),
        );

        final relayEvent = MockEvent();
        when(() => relayEvent.kind).thenReturn(0);
        when(() => relayEvent.pubkey).thenReturn(testPubkey3);
        when(() => relayEvent.createdAt).thenReturn(1704067200);
        when(() => relayEvent.id).thenReturn(
          'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5',
        );
        when(
          () => relayEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Relay User'}));

        when(
          () => mockNostrClient.fetchProfile(testPubkey3),
        ).thenAnswer((_) async => relayEvent);
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.fetchBatchProfiles(
          pubkeys: [testPubkey, testPubkey2, testPubkey3],
        );

        expect(result, hasLength(3));
        expect(result[testPubkey]?.displayName, equals('Cached'));
        expect(result[testPubkey2]?.displayName, equals('API User'));
        expect(result[testPubkey3]?.displayName, equals('Relay User'));
      });

      test('handles API failure gracefully and falls back to relay', () async {
        final relayEvent = MockEvent();
        when(() => relayEvent.kind).thenReturn(0);
        when(() => relayEvent.pubkey).thenReturn(testPubkey);
        when(() => relayEvent.createdAt).thenReturn(1704067200);
        when(() => relayEvent.id).thenReturn(testEventId);
        when(
          () => relayEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Relay Fallback'}));

        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com',
          ),
        );
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => relayEvent);
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('Relay Fallback'));
      });

      test('handles relay failure gracefully with partial results', () async {
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenThrow(Exception('Relay error'));
        // Step 4 indexer fallback also calls queryEvents
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, isEmpty);
        expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
      });

      test(
        'handles uncaught relay Error gracefully with partial results',
        () async {
          final relayEvent = MockEvent();
          when(() => relayEvent.kind).thenReturn(0);
          when(() => relayEvent.pubkey).thenReturn(testPubkey2);
          when(() => relayEvent.createdAt).thenReturn(1704067200);
          when(() => relayEvent.id).thenReturn('relay_$testEventId');
          when(
            () => relayEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Relay User'}));

          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenThrow(StateError('Relay crashed'));
          when(
            () => mockNostrClient.fetchProfile(testPubkey2),
          ).thenAnswer((_) async => relayEvent);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);
          when(
            () => mockUserProfilesDao.upsertProfiles(any()),
          ).thenAnswer((_) async {});

          final result = await profileRepository.fetchBatchProfiles(
            pubkeys: [testPubkey, testPubkey2],
          );

          expect(result, hasLength(1));
          expect(result[testPubkey2]?.displayName, equals('Relay User'));
        },
      );

      test('falls back to indexer relay when step 3 returns nothing', () async {
        final indexerEvent = MockEvent();
        when(() => indexerEvent.kind).thenReturn(0);
        when(() => indexerEvent.pubkey).thenReturn(testPubkey);
        when(() => indexerEvent.createdAt).thenReturn(1704067200);
        when(() => indexerEvent.id).thenReturn(testEventId);
        when(
          () => indexerEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Indexer User'}));

        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        // Step 3 returns null (no result)
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => null);
        // Step 4 indexer fallback returns the profile
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [indexerEvent]);
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('Indexer User'));
      });

      test('handles indexer relay failure gracefully', () async {
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        // Step 3 returns null
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => null);
        // Step 4 indexer fallback throws
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenThrow(Exception('Indexer error'));

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, isEmpty);
        expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
      });

      test(
        'skips relay fallback for UserProfileNotPublished entries',
        () async {
          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
            (_) async => const BulkProfilesResponse(
              profiles: {
                testPubkey: UserProfileNotPublished(pubkey: testPubkey),
              },
            ),
          );

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake.fetchBatchProfiles(
            pubkeys: [testPubkey],
          );

          expect(result, isEmpty);
          expect(repoWithFunnelcake.isConfirmedMissing(testPubkey), isTrue);
          verifyNever(() => mockNostrClient.fetchProfile(any()));
          verifyNever(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          );
          verifyNever(() => mockUserProfilesDao.upsertProfiles(any()));
        },
      );

      test(
        'distinguishes confirmed absence from an omitted bulk result',
        () async {
          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
            (_) async => const BulkProfilesResponse(
              profiles: {
                testPubkey: UserProfileNotPublished(pubkey: testPubkey),
              },
            ),
          );
          when(
            () => mockNostrClient.fetchProfile(testPubkey2),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake.fetchBatchProfiles(
            pubkeys: [testPubkey, testPubkey2],
          );

          expect(result, isEmpty);
          expect(repoWithFunnelcake.isConfirmedMissing(testPubkey), isTrue);
          expect(repoWithFunnelcake.isConfirmedMissing(testPubkey2), isFalse);
        },
      );

      test(
        'processes real profiles alongside UserProfileNotPublished entries',
        () async {
          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
            (_) async => BulkProfilesResponse(
              profiles: {
                testPubkey: UserProfileFound(
                  profile: UserProfileData.fromJson(testPubkey, const {
                    'display_name': 'Real User',
                  }),
                ),
                testPubkey2: const UserProfileNotPublished(pubkey: testPubkey2),
              },
            ),
          );
          when(
            () => mockUserProfilesDao.upsertProfiles(any()),
          ).thenAnswer((_) async {});

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake.fetchBatchProfiles(
            pubkeys: [testPubkey, testPubkey2],
          );

          expect(result, hasLength(1));
          expect(result[testPubkey]?.displayName, equals('Real User'));
          expect(result.containsKey(testPubkey2), isFalse);
          verifyNever(() => mockNostrClient.fetchProfile(any()));
        },
      );

      test(
        'clears a stale confirmed-missing mark once a batch resolves the '
        'profile',
        () async {
          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockUserProfilesDao.upsertProfiles(any()),
          ).thenAnswer((_) async {});
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          var bulkCall = 0;
          when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer((
            _,
          ) async {
            bulkCall++;
            if (bulkCall == 1) {
              return const BulkProfilesResponse(
                profiles: {
                  testPubkey: UserProfileNotPublished(pubkey: testPubkey),
                },
              );
            }
            return BulkProfilesResponse(
              profiles: {
                testPubkey: UserProfileFound(
                  profile: UserProfileData.fromJson(testPubkey, const {
                    'display_name': 'Now Published',
                  }),
                ),
              },
            );
          });

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repoWithFunnelcake.fetchBatchProfiles(pubkeys: [testPubkey]);
          expect(repoWithFunnelcake.isConfirmedMissing(testPubkey), isTrue);

          final second = await repoWithFunnelcake.fetchBatchProfiles(
            pubkeys: [testPubkey],
          );

          // The batch just resolved and cached a profile for this pubkey, so
          // the earlier absence verdict no longer describes the latest fetch.
          expect(second[testPubkey]?.displayName, equals('Now Published'));
          expect(repoWithFunnelcake.isConfirmedMissing(testPubkey), isFalse);
        },
      );

      test('evicts a vanished entry and skips relay fallback', () async {
        // The batch path is a second way into the cache, so it has to evict
        // on its own, and has to drop the pubkey from `remaining` or the
        // relay fallback below refills what was just deleted.
        final mockVanishedDao = MockVanishedProfilesDao();
        when(
          () => mockVanishedDao.markVanished(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockUserProfilesDao.deleteProfile(any()),
        ).thenAnswer((_) async => 1);
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
          (_) async => const BulkProfilesResponse(
            profiles: {testPubkey: UserProfileVanished(pubkey: testPubkey)},
          ),
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          vanishedProfilesDao: mockVanishedDao,
        );

        final result = await repoWithFunnelcake.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, isEmpty);
        expect(repoWithFunnelcake.isVanished(testPubkey), isTrue);
        expect(repoWithFunnelcake.isConfirmedMissing(testPubkey), isTrue);
        verify(() => mockVanishedDao.markVanished(testPubkey)).called(1);
        verify(() => mockUserProfilesDao.deleteProfile(testPubkey)).called(1);
        verifyNever(() => mockNostrClient.fetchProfile(any()));
        verifyNever(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        );
        verifyNever(() => mockUserProfilesDao.upsertProfiles(any()));
      });

      test('drops a known-vanished pubkey before the bulk request', () async {
        // Eviction leaves no cached row, so without this the pubkey rides in
        // every bulk request an inbox or feed prefetch makes and re-runs the
        // eviction each time.
        final mockVanishedDao = MockVanishedProfilesDao();
        when(
          mockVanishedDao.getAllPubkeys,
        ).thenAnswer((_) async => [testPubkey]);
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          vanishedProfilesDao: mockVanishedDao,
        );
        await repoWithFunnelcake.loadVanishedPubkeys();

        final result = await repoWithFunnelcake.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, isEmpty);
        verifyNever(() => mockFunnelcakeClient.getBulkProfiles(any()));
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });

      test('does not batch-write when nothing was fetched', () async {
        final cached = UserProfile(
          pubkey: testPubkey,
          displayName: 'Cached',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'cached-event',
        );
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys([testPubkey]),
        ).thenAnswer((_) async => [cached]);

        await profileRepository.fetchBatchProfiles(pubkeys: [testPubkey]);

        verifyNever(() => mockUserProfilesDao.upsertProfiles(any()));
      });

      test('picks newest profile per pubkey across sources', () async {
        // Connected relay returns older profile
        final olderEvent = MockEvent();
        when(() => olderEvent.kind).thenReturn(0);
        when(() => olderEvent.pubkey).thenReturn(testPubkey);
        when(() => olderEvent.createdAt).thenReturn(1704067200);
        when(() => olderEvent.id).thenReturn(testEventId);
        when(
          () => olderEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Old Name'}));

        // Indexer returns newer profile for same pubkey
        final newerEvent = MockEvent();
        when(() => newerEvent.kind).thenReturn(0);
        when(() => newerEvent.pubkey).thenReturn(testPubkey);
        when(() => newerEvent.createdAt).thenReturn(1704153600);
        when(() => newerEvent.id).thenReturn('newer_$testEventId');
        when(
          () => newerEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'New Name'}));

        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => olderEvent);
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [newerEvent]);
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('New Name'));
      });
    });

    group('block filter', () {
      const blockedPubkey =
          'dddddddddddddddddddddddddddddddd'
          'dddddddddddddddddddddddddddddddd';

      test(
        'filters blocked users from searchUsersProgressive results',
        () async {
          final blockedProfile = UserProfile(
            pubkey: blockedPubkey,
            displayName: 'Blocked User',
            rawData: const {'display_name': 'Blocked User'},
            createdAt: DateTime(2026),
            eventId: 'evt_blocked',
          );
          final allowedProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Allowed User',
            rawData: const {'display_name': 'Allowed User'},
            createdAt: DateTime(2026),
            eventId: testEventId,
          );

          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => [blockedProfile, allowedProfile]);

          when(
            () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
          ).thenAnswer((_) async => []);

          final repoWithBlockFilter = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            blockFilter: (pubkey) => pubkey == blockedPubkey,
          );

          final emissions = await repoWithBlockFilter
              .searchUsersProgressive(query: 'user')
              .toList();

          // Every emission should exclude the blocked profile.
          for (final result in emissions) {
            expect(
              result.profiles.map((p) => p.pubkey),
              isNot(contains(blockedPubkey)),
            );
          }

          // The allowed profile should be present in the last emission.
          expect(emissions.last.profiles, hasLength(1));
          expect(emissions.last.profiles.first.pubkey, equals(testPubkey));
        },
      );

      test('returns all profiles when blockFilter is null', () async {
        final profile1 = UserProfile(
          pubkey: blockedPubkey,
          displayName: 'User One',
          rawData: const {'display_name': 'User One'},
          createdAt: DateTime(2026),
          eventId: 'evt_one',
        );
        final profile2 = UserProfile(
          pubkey: testPubkey,
          displayName: 'User Two',
          rawData: const {'display_name': 'User Two'},
          createdAt: DateTime(2026),
          eventId: testEventId,
        );

        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => [profile1, profile2]);

        when(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) async => []);

        // Default profileRepository has no blockFilter.
        final emissions = await profileRepository
            .searchUsersProgressive(query: 'user')
            .toList();

        expect(emissions.last.profiles, hasLength(2));
      });

      test('filters blocked users from searchUsersLocally results', () async {
        const blockedPubkey =
            'dddddddddddddddddddddddddddddddd'
            'dddddddddddddddddddddddddddddddd';
        final blockedProfile = UserProfile(
          pubkey: blockedPubkey,
          displayName: 'Blocked User',
          rawData: const {'display_name': 'Blocked User'},
          createdAt: DateTime(2026),
          eventId: 'evt_blocked_local',
        );
        final allowedProfile = UserProfile(
          pubkey: testPubkey,
          displayName: 'Allowed User',
          rawData: const {'display_name': 'Allowed User'},
          createdAt: DateTime(2026),
          eventId: testEventId,
        );

        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => [blockedProfile, allowedProfile]);

        final repoWithBlockFilter = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );

        final result = await repoWithBlockFilter.searchUsersLocally(
          query: 'user',
        );

        expect(result.map((p) => p.pubkey), isNot(contains(blockedPubkey)));
        expect(result, hasLength(1));
        expect(result.first.pubkey, equals(testPubkey));
      });

      test('fetchFreshProfile returns null for a blocked pubkey', () async {
        const blockedPubkey =
            'dddddddddddddddddddddddddddddddd'
            'dddddddddddddddddddddddddddddddd';

        final repoWithBlockFilter = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );

        final result = await repoWithBlockFilter.fetchFreshProfile(
          pubkey: blockedPubkey,
        );

        expect(result, isNull);
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });

      test(
        'fetchBatchProfiles excludes blocked pubkeys from map result',
        () async {
          const blockedPubkey =
              'dddddddddddddddddddddddddddddddd'
              'dddddddddddddddddddddddddddddddd';

          final blockedEvent = MockEvent();
          when(() => blockedEvent.kind).thenReturn(0);
          when(() => blockedEvent.pubkey).thenReturn(blockedPubkey);
          when(() => blockedEvent.createdAt).thenReturn(1704067200);
          when(() => blockedEvent.id).thenReturn(
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          );
          when(
            () => blockedEvent.content,
          ).thenReturn('{"display_name":"Blocked Batch User"}');

          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);

          when(
            () => mockNostrClient.fetchProfile(blockedPubkey),
          ).thenAnswer((_) async => blockedEvent);
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => mockProfileEvent);

          when(
            () => mockUserProfilesDao.upsertProfiles(any()),
          ).thenAnswer((_) async {});

          final repoWithBlockFilter = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            blockFilter: (pubkey) => pubkey == blockedPubkey,
          );

          final result = await repoWithBlockFilter.fetchBatchProfiles(
            pubkeys: [blockedPubkey, testPubkey],
          );

          expect(result.containsKey(blockedPubkey), isFalse);
          expect(result.containsKey(testPubkey), isTrue);
        },
      );
    });
  });
}
