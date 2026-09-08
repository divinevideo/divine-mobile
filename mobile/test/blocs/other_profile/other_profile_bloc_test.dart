// ABOUTME: Unit tests for OtherProfileBloc
// ABOUTME: Tests cache+fresh pattern for viewing another user's profile

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/other_profile/other_profile_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

/// Captures errors routed through [Bloc.onError] so a test can assert that a
/// bloc closed mid-flight records no error when its awaited work completes.
class _ErrorCapturingObserver extends BlocObserver {
  final List<Object> errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  group('OtherProfileBloc', () {
    late _MockProfileRepository mockProfileRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockFollowRepository mockFollowRepository;

    // Test data constants - using full 64-character hex pubkey as required
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const testCurrentUserPubkey =
        'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b200';
    const testDisplayName = 'Test User';
    const testAbout = 'Test bio';
    const testPicture = 'https://example.com/avatar.png';

    /// Helper to create a test UserProfile
    UserProfile createTestProfile({
      String pubkey = testPubkey,
      String? displayName = testDisplayName,
      String eventId =
          'event123456789012345678901234567890123456789012345678901234567890',
    }) {
      return UserProfile(
        pubkey: pubkey,
        displayName: displayName,
        about: testAbout,
        picture: testPicture,
        rawData: const {},
        createdAt: DateTime(2024),
        eventId: eventId,
      );
    }

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockFollowRepository = _MockFollowRepository();

      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
      when(
        () => mockFollowRepository.toggleFollow(any()),
      ).thenAnswer((_) async {});
      // Default: not a deleted account. The vanish group below overrides this.
      when(() => mockProfileRepository.isVanished(any())).thenReturn(false);
    });

    OtherProfileBloc createBloc({String pubkey = testPubkey}) =>
        OtherProfileBloc(
          profileRepository: mockProfileRepository,
          pubkey: pubkey,
          contentBlocklistRepository: mockBlocklistRepository,
          currentUserPubkey: testCurrentUserPubkey,
          followRepository: mockFollowRepository,
        );

    // Every other follow surface reads MyFollowingBloc, which filters blocked
    // pubkeys. This getter feeds the profile ⋯ sheet's "Unfollow <name>" row,
    // so if it disagrees the app offers to unfollow an account it elsewhere
    // says you do not follow. #6903 stopped severing the follow locally, which
    // makes that disagreement reachable from every block entry point.
    test('reports a blocked account as not followed', () {
      when(() => mockFollowRepository.isFollowing(testPubkey)).thenReturn(true);
      when(
        () => mockBlocklistRepository.canUnblock(testPubkey),
      ).thenReturn(true);
      when(
        () => mockBlocklistRepository.isBlocked(testPubkey),
      ).thenReturn(true);

      final bloc = createBloc();
      expect(bloc.isBlocked, isTrue);
      expect(bloc.isFollowing, isFalse);
      bloc.close();
    });

    test('reports an unblocked account as followed', () {
      when(() => mockFollowRepository.isFollowing(testPubkey)).thenReturn(true);
      when(
        () => mockBlocklistRepository.canUnblock(testPubkey),
      ).thenReturn(false);
      when(
        () => mockBlocklistRepository.isBlocked(testPubkey),
      ).thenReturn(false);

      final bloc = createBloc();
      expect(bloc.isFollowing, isTrue);
      bloc.close();
    });

    test('offers Unblock for an imported mute', () {
      when(
        () => mockBlocklistRepository.canUnblock(testPubkey),
      ).thenReturn(true);

      final bloc = createBloc();
      expect(bloc.isBlocked, isTrue);
      bloc.close();
    });

    test('still reports an imported mute as followed', () {
      when(() => mockFollowRepository.isFollowing(testPubkey)).thenReturn(true);
      when(
        () => mockBlocklistRepository.canUnblock(testPubkey),
      ).thenReturn(true);
      when(
        () => mockBlocklistRepository.isBlocked(testPubkey),
      ).thenReturn(false);

      final bloc = createBloc();
      // A mute severs nothing: MyFollowingBloc still lists the account and
      // the kind 3 we publish still carries it, so the profile sheet has to
      // keep offering `Unfollow` rather than hiding the row.
      expect(bloc.isBlocked, isTrue);
      expect(bloc.isFollowing, isTrue);
      bloc.close();
    });

    test('initial state is OtherProfileInitial', () {
      final bloc = createBloc();
      expect(bloc.state, isA<OtherProfileInitial>());
      expect(bloc.pubkey, equals(testPubkey));
      bloc.close();
    });

    group('vanished accounts', () {
      blocTest<OtherProfileBloc, OtherProfileState>(
        'emits notFound instead of the stale cache when the account vanished',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          // The fetch evicts the cache and returns null, same as a network
          // miss — only isVanished distinguishes them.
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.isVanished(testPubkey),
          ).thenReturn(true);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
        expect: () => [
          isA<OtherProfileError>().having(
            (s) => s.errorType,
            'errorType',
            OtherProfileErrorType.notFound,
          ),
        ],
        verify: (_) {
          // A known-vanished pubkey short-circuits before the cache read and
          // before any network call.
          verifyNever(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          );
        },
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'still falls back to the cache when the fetch merely failed',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.isVanished(testPubkey),
          ).thenReturn(false);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
        // Identical setup to the test above apart from isVanished. This is
        // what fails if the gate is widened to every null fetch.
        expect: () => [
          isA<OtherProfileLoading>(),
          isA<OtherProfileLoaded>().having((s) => s.isFresh, 'isFresh', false),
        ],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'discovers the vanish mid-fetch and does not use the stale cache',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          var fetched = false;
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async {
            fetched = true;
            return null;
          });
          when(
            () => mockProfileRepository.isVanished(testPubkey),
          ).thenAnswer((_) => fetched);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
        expect: () => [
          isA<OtherProfileLoading>(),
          isA<OtherProfileError>().having(
            (s) => s.errorType,
            'errorType',
            OtherProfileErrorType.notFound,
          ),
        ],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'refresh drops the stale profile from the error state',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.isVanished(testPubkey),
          ).thenReturn(true);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
        // other_profile_screen extracts `profile` out of the error state and
        // renders it, so carrying it here would keep the deleted account on
        // screen through every pull-to-refresh.
        expect: () => [
          isA<OtherProfileError>()
              .having(
                (s) => s.errorType,
                'errorType',
                OtherProfileErrorType.notFound,
              )
              .having((s) => s.profile, 'profile', isNull),
        ],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'a throwing fetch on a vanished account does not restore the cache',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          var fetched = false;
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async {
            fetched = true;
            throw Exception('relay unreachable');
          });
          when(
            () => mockProfileRepository.isVanished(testPubkey),
          ).thenAnswer((_) => fetched);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
        expect: () => [
          isA<OtherProfileLoading>(),
          isA<OtherProfileError>().having(
            (s) => s.errorType,
            'errorType',
            OtherProfileErrorType.notFound,
          ),
        ],
      );
    });

    group('OtherProfileLoadRequested', () {
      group('with cached profile available', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with cache, loaded fresh] when fresh fetch succeeds',
          setUp: () {
            final cachedProfile = createTestProfile(
              eventId:
                  'cached12345678901234567890123456789012345678901234567890123456',
            );
            final freshProfile = createTestProfile(
              eventId:
                  'fresh123456789012345678901234567890123456789012345678901234567',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => cachedProfile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile?.eventId,
              'profile.eventId',
              'cached12345678901234567890123456789012345678901234567890123456',
            ),
            isA<OtherProfileLoaded>()
                .having(
                  (s) => s.profile.eventId,
                  'profile.eventId',
                  'fresh123456789012345678901234567890123456789012345678901234567',
                )
                .having((s) => s.isFresh, 'isFresh', true),
          ],
          verify: (_) {
            verify(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).called(1);
            verify(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).called(1);
          },
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with cache, loaded stale] when fresh fetch returns null',
          setUp: () {
            final cachedProfile = createTestProfile();
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => cachedProfile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', false),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with cache, loaded stale] when fresh fetch throws',
          setUp: () {
            final cachedProfile = createTestProfile();
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => cachedProfile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenThrow(Exception('Network error'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', false),
          ],
        );
      });

      group('without cached profile', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, loaded fresh] when fresh fetch succeeds',
          setUp: () {
            final freshProfile = createTestProfile();
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, error notFound] when fresh fetch returns null',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileError>().having(
              (s) => s.errorType,
              'errorType',
              OtherProfileErrorType.notFound,
            ),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, error networkError] when fresh fetch throws',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenThrow(Exception('Network error'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileError>().having(
              (s) => s.errorType,
              'errorType',
              OtherProfileErrorType.networkError,
            ),
          ],
        );
      });
    });

    group('OtherProfileRefreshRequested', () {
      group('from initial state', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, loaded fresh] when refresh succeeds',
          setUp: () {
            final freshProfile = createTestProfile();
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, error notFound] when refresh returns null',
          setUp: () {
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileError>()
                .having(
                  (s) => s.errorType,
                  'errorType',
                  OtherProfileErrorType.notFound,
                )
                .having((s) => s.profile, 'profile', isNull),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, error networkError] when refresh throws',
          setUp: () {
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenThrow(Exception('Network error'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileError>()
                .having(
                  (s) => s.errorType,
                  'errorType',
                  OtherProfileErrorType.networkError,
                )
                .having((s) => s.profile, 'profile', isNull),
          ],
        );
      });

      group('from loaded state', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with current, loaded fresh] when refresh succeeds',
          setUp: () {
            final cachedProfile = createTestProfile(
              eventId:
                  'cached12345678901234567890123456789012345678901234567890123456',
            );
            final freshProfile = createTestProfile(
              eventId:
                  'fresh123456789012345678901234567890123456789012345678901234567',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => cachedProfile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          seed: () => OtherProfileLoaded(
            profile: createTestProfile(
              eventId:
                  'seed1234567890123456789012345678901234567890123456789012345678',
            ),
            isFresh: true,
          ),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile?.eventId,
              'profile.eventId',
              'seed1234567890123456789012345678901234567890123456789012345678',
            ),
            isA<OtherProfileLoaded>()
                .having(
                  (s) => s.profile.eventId,
                  'profile.eventId',
                  'fresh123456789012345678901234567890123456789012345678901234567',
                )
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with current, error with current] when refresh '
          'returns null',
          setUp: () {
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          seed: () =>
              OtherProfileLoaded(profile: createTestProfile(), isFresh: true),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<OtherProfileError>()
                .having(
                  (s) => s.errorType,
                  'errorType',
                  OtherProfileErrorType.notFound,
                )
                .having((s) => s.profile, 'profile', isNotNull),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with current, loaded stale] when refresh throws',
          setUp: () {
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenThrow(Exception('Network error'));
          },
          build: createBloc,
          seed: () =>
              OtherProfileLoaded(profile: createTestProfile(), isFresh: true),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', false),
          ],
        );
      });

      group('from loading state', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits loaded fresh when refresh succeeds',
          setUp: () {
            final freshProfile = createTestProfile(
              eventId:
                  'fresh123456789012345678901234567890123456789012345678901234567',
            );
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          seed: () => OtherProfileLoading(
            profile: createTestProfile(
              eventId:
                  'loading12345678901234567890123456789012345678901234567890123456',
            ),
          ),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoaded>()
                .having(
                  (s) => s.profile.eventId,
                  'profile.eventId',
                  'fresh123456789012345678901234567890123456789012345678901234567',
                )
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );
      });

      group('from error state', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'preserves profile from error state during refresh',
          setUp: () {
            final freshProfile = createTestProfile(
              eventId:
                  'fresh123456789012345678901234567890123456789012345678901234567',
            );
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          seed: () => OtherProfileError(
            errorType: OtherProfileErrorType.networkError,
            profile: createTestProfile(
              eventId:
                  'error123456789012345678901234567890123456789012345678901234567',
            ),
          ),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile?.eventId,
              'profile.eventId',
              'error123456789012345678901234567890123456789012345678901234567',
            ),
            isA<OtherProfileLoaded>()
                .having(
                  (s) => s.profile.eventId,
                  'profile.eventId',
                  'fresh123456789012345678901234567890123456789012345678901234567',
                )
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'recovers from error state without profile when refresh succeeds',
          setUp: () {
            final freshProfile = createTestProfile();
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          seed: () => const OtherProfileError(
            errorType: OtherProfileErrorType.networkError,
          ),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );
      });
    });

    group('OtherProfileBlockRequested', () {
      setUp(() {
        when(
          () => mockBlocklistRepository.blockUser(
            any(),
            ourPubkey: any(named: 'ourPubkey'),
          ),
        ).thenAnswer((_) async => true);
      });

      blocTest<OtherProfileBloc, OtherProfileState>(
        'calls blockUser with correct arguments',
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileBlockRequested()),
        verify: (_) {
          verify(
            () => mockBlocklistRepository.blockUser(
              testPubkey,
              ourPubkey: testCurrentUserPubkey,
            ),
          ).called(1);
        },
      );

      // #6903 moved severing the follow to the publish boundary:
      // FollowRepository omits blocked accounts from the kind 3 it
      // publishes. Unfollowing here as well would drop the follow locally,
      // so unblocking could not restore it — and only two of the four block
      // entry points would behave that way.
      blocTest<OtherProfileBloc, OtherProfileState>(
        'leaves the local follow state alone when blocking',
        setUp: () {
          when(
            () => mockFollowRepository.isFollowing(testPubkey),
          ).thenReturn(true);
          when(
            () => mockBlocklistRepository.canUnblock(testPubkey),
          ).thenReturn(true);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileBlockRequested()),
        verify: (_) {
          // Not mutating the follow list is the whole point: the omission
          // happens when FollowRepository publishes, so unblocking restores
          // the follow instead of costing it permanently.
          verifyNever(() => mockFollowRepository.toggleFollow(any()));
          verifyNever(() => mockFollowRepository.unfollow(any()));
        },
      );
    });

    group('OtherProfileUnblockRequested', () {
      setUp(() {
        when(
          () => mockBlocklistRepository.unblockUser(any()),
        ).thenAnswer((_) async => true);
      });

      blocTest<OtherProfileBloc, OtherProfileState>(
        'calls unblockUser with correct pubkey',
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileUnblockRequested()),
        verify: (_) {
          verify(
            () => mockBlocklistRepository.unblockUser(testPubkey),
          ).called(1);
        },
      );
    });

    group('after close (lifecycle, regression for #4393)', () {
      // Installs an observer that records every error routed through
      // [Bloc.onError] for the running test, restoring the previous observer
      // on teardown. A closed bloc that resumes an awaited handler must not
      // surface any error.
      _ErrorCapturingObserver captureBlocErrors() {
        final observer = _ErrorCapturingObserver();
        final previousObserver = Bloc.observer;
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = previousObserver);
        return observer;
      }

      test('records no error when closed before the fresh profile resolves '
          'on load', () async {
        final observer = captureBlocErrors();
        final freshCompleter = Completer<UserProfile?>();
        when(
          () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
        ).thenAnswer((_) async => createTestProfile());
        when(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).thenAnswer((_) => freshCompleter.future);

        final bloc = createBloc()..add(const OtherProfileLoadRequested());

        // Let the handler emit loading and park on fetchFreshProfile.
        await pumpEventQueue();
        // The profile screen is disposed while the fetch is in flight.
        await bloc.close();
        // The awaited fetch now resolves after close.
        freshCompleter.complete(createTestProfile());
        await pumpEventQueue();

        expect(observer.errors, isEmpty);
      });

      test(
        'records no error when closed before the fresh fetch throws on load',
        () async {
          final observer = captureBlocErrors();
          final freshCompleter = Completer<UserProfile?>();
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) => freshCompleter.future);

          final bloc = createBloc()..add(const OtherProfileLoadRequested());

          await pumpEventQueue();
          await bloc.close();
          // The fetch fails after close: the catch block must not add
          // VerifiedClaimsRequested to the now-closed bloc.
          freshCompleter.completeError(Exception('network error'));
          await pumpEventQueue();

          expect(observer.errors, isEmpty);
        },
      );

      test('records no error when closed before the fresh profile resolves '
          'on refresh', () async {
        final observer = captureBlocErrors();
        final freshCompleter = Completer<UserProfile?>();
        when(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).thenAnswer((_) => freshCompleter.future);

        final bloc = createBloc()..add(const OtherProfileRefreshRequested());

        await pumpEventQueue();
        await bloc.close();
        freshCompleter.complete(createTestProfile());
        await pumpEventQueue();

        expect(observer.errors, isEmpty);
      });

      test(
        'records no error when closed before a seeded refresh fetch throws',
        () async {
          // Drive the bloc to a loaded state first so the refresh catch
          // block takes the branch that re-adds VerifiedClaimsRequested.
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          final bloc = createBloc()..add(const OtherProfileLoadRequested());
          await pumpEventQueue();

          final observer = captureBlocErrors();
          final refreshCompleter = Completer<UserProfile?>();
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) => refreshCompleter.future);

          bloc.add(const OtherProfileRefreshRequested());
          await pumpEventQueue();
          await bloc.close();
          refreshCompleter.completeError(Exception('network error'));
          await pumpEventQueue();

          expect(observer.errors, isEmpty);
        },
      );
    });

    group('OtherProfileState', () {
      test('OtherProfileInitial instances are equal', () {
        const state1 = OtherProfileInitial();
        const state2 = OtherProfileInitial();
        expect(state1, equals(state2));
      });

      test('OtherProfileLoading instances are equal with same profile', () {
        final profile = createTestProfile();
        final state1 = OtherProfileLoading(profile: profile);
        final state2 = OtherProfileLoading(profile: profile);
        expect(state1, equals(state2));
      });

      test('OtherProfileLoading instances differ with different profiles', () {
        final profile1 = createTestProfile(
          eventId:
              'event1234567890123456789012345678901234567890123456789012345678',
        );
        final profile2 = createTestProfile(
          eventId:
              'event2345678901234567890123456789012345678901234567890123456789',
        );
        final state1 = OtherProfileLoading(profile: profile1);
        final state2 = OtherProfileLoading(profile: profile2);
        expect(state1, isNot(equals(state2)));
      });

      test(
        'OtherProfileLoaded instances are equal with same profile and flag',
        () {
          final profile = createTestProfile();
          final state1 = OtherProfileLoaded(profile: profile, isFresh: true);
          final state2 = OtherProfileLoaded(profile: profile, isFresh: true);
          expect(state1, equals(state2));
        },
      );

      test('OtherProfileLoaded instances differ with different isFresh', () {
        final profile = createTestProfile();
        final state1 = OtherProfileLoaded(profile: profile, isFresh: true);
        final state2 = OtherProfileLoaded(profile: profile, isFresh: false);
        expect(state1, isNot(equals(state2)));
      });

      test('OtherProfileError instances are equal with same errorType', () {
        const state1 = OtherProfileError(
          errorType: OtherProfileErrorType.notFound,
        );
        const state2 = OtherProfileError(
          errorType: OtherProfileErrorType.notFound,
        );
        expect(state1, equals(state2));
      });

      test('OtherProfileError instances differ with different errorType', () {
        const state1 = OtherProfileError(
          errorType: OtherProfileErrorType.notFound,
        );
        const state2 = OtherProfileError(
          errorType: OtherProfileErrorType.networkError,
        );
        expect(state1, isNot(equals(state2)));
      });
    });

    group('OtherProfileEvent', () {
      test('OtherProfileLoadRequested instances are equal', () {
        const event1 = OtherProfileLoadRequested();
        const event2 = OtherProfileLoadRequested();
        expect(event1, equals(event2));
      });

      test('OtherProfileRefreshRequested instances are equal', () {
        const event1 = OtherProfileRefreshRequested();
        const event2 = OtherProfileRefreshRequested();
        expect(event1, equals(event2));
      });

      test('OtherProfileBlockRequested instances are equal', () {
        const event1 = OtherProfileBlockRequested();
        const event2 = OtherProfileBlockRequested();
        expect(event1, equals(event2));
      });

      test('OtherProfileUnblockRequested instances are equal', () {
        const event1 = OtherProfileUnblockRequested();
        const event2 = OtherProfileUnblockRequested();
        expect(event1, equals(event2));
      });
    });

    group('VerifiedClaimsRequested (SWR cache, #3936)', () {
      late _MockIdentityClaimsRepository mockClaimsRepository;

      const identityTags = [
        ['i', 'github:alice', 'proof-a'],
      ];
      const aliceClaim = IdentityClaim(
        pubkey: testPubkey,
        platform: 'github',
        identity: 'alice',
        proof: 'proof-a',
      );
      const bobClaim = IdentityClaim(
        pubkey: testPubkey,
        platform: 'telegram',
        identity: 'bob',
        proof: 'proof-b',
      );

      setUp(() {
        mockClaimsRepository = _MockIdentityClaimsRepository();
        registerFallbackValue(<List<String>>[]);
        registerFallbackValue(const <IdentityClaim>[]);
        registerFallbackValue(
          const CachedVerifiedClaims(claims: [], isFresh: false),
        );
        when(
          () => mockProfileRepository.cachedIdentityTags(testPubkey),
        ).thenAnswer((_) async => identityTags);
        when(
          () => mockProfileRepository.freshIdentityTags(
            pubkey: testPubkey,
            kind0Tags: any(named: 'kind0Tags'),
          ),
        ).thenAnswer((_) async => identityTags);
      });

      OtherProfileBloc createClaimsBloc() => OtherProfileBloc(
        profileRepository: mockProfileRepository,
        pubkey: testPubkey,
        contentBlocklistRepository: mockBlocklistRepository,
        currentUserPubkey: testCurrentUserPubkey,
        followRepository: mockFollowRepository,
        identityClaimsRepository: mockClaimsRepository,
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'renders the cached snapshot instantly, then the resolved claims',
        seed: () =>
            OtherProfileLoaded(profile: createTestProfile(), isFresh: true),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                const CachedVerifiedClaims(claims: [aliceClaim], isFresh: true),
          );
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenAnswer((_) async => const [aliceClaim, bobClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        // Instant chips from the cached snapshot, then whatever the
        // repository's stale-while-revalidate resolveClaims returns. The
        // skip-or-verify decision itself lives in (and is tested at) the
        // repository, not the bloc.
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
        ],
        verify: (_) {
          verify(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).called(1);
        },
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'keeps last-known-good claims when the verifier fails',
        seed: () =>
            OtherProfileLoaded(profile: createTestProfile(), isFresh: true),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => const CachedVerifiedClaims(
              claims: [aliceClaim],
              isFresh: false,
            ),
          );
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenThrow(const VerifierApiException(503, 'down'));
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
        ],
        errors: () => [isA<VerifierApiException>()],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'degrades to the network path when the cache read throws',
        seed: () =>
            OtherProfileLoaded(profile: createTestProfile(), isFresh: true),
        setUp: () {
          when(
            () => mockProfileRepository.cachedIdentityTags(testPubkey),
          ).thenThrow(Exception('db corrupt'));
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenAnswer((_) async => const [aliceClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      late Completer<List<IdentityClaim>> staleResolve;
      blocTest<OtherProfileBloc, OtherProfileState>(
        'uses the newest verification result when requests overlap',
        seed: () =>
            OtherProfileLoaded(profile: createTestProfile(), isFresh: true),
        setUp: () {
          staleResolve = Completer<List<IdentityClaim>>();
          var resolveCall = 0;
          addTearDown(() {
            if (!staleResolve.isCompleted) {
              staleResolve.complete(const [aliceClaim]);
            }
          });
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenAnswer((_) {
            resolveCall += 1;
            if (resolveCall == 1) return staleResolve.future;
            return Future.value(const [bobClaim]);
          });
        },
        build: createClaimsBloc,
        act: (bloc) async {
          bloc.add(const VerifiedClaimsRequested());
          await pumpEventQueue();
          bloc.add(const VerifiedClaimsRequested());
          await pumpEventQueue();
          staleResolve.complete(const [aliceClaim]);
          await pumpEventQueue();
        },
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [bobClaim],
          ),
        ],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'carries claims through refresh instead of dropping them',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: testPubkey,
              requireRawKind0: any(named: 'requireRawKind0'),
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                const CachedVerifiedClaims(claims: [aliceClaim], isFresh: true),
          );
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenAnswer((_) async => const [aliceClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
        expect: () => [
          isA<OtherProfileLoading>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
          isA<OtherProfileLoaded>()
              .having((s) => s.isFresh, 'isFresh', true)
              .having((s) => s.verifiedClaims, 'verifiedClaims', [aliceClaim]),
        ],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'keeps rendered chips when the instant-path intersection is empty '
        'and the verifier is unreachable',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => const CachedVerifiedClaims(claims: [], isFresh: false),
          );
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenThrow(const VerifierApiException(503, 'down'));
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        // An empty snapshot intersection is not a confirmed negative, so
        // the non-authoritative instant path must not clear visible chips.
        expect: () => const <OtherProfileState>[],
        errors: () => [isA<VerifierApiException>()],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'unions instant-path chips rendered-first instead of replacing',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                const CachedVerifiedClaims(claims: [bobClaim], isFresh: false),
          );
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenAnswer((_) async => const [aliceClaim, bobClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        // Rendered-first union keeps chip order stable, so the
        // authoritative resolve emit is Equatable-suppressed afterwards.
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
        ],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'does not double-render one identity when the cached casing differs',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => const CachedVerifiedClaims(
              claims: [
                IdentityClaim(
                  pubkey: testPubkey,
                  platform: 'GitHub',
                  identity: 'Alice',
                  proof: 'rotated-proof',
                ),
              ],
              isFresh: false,
            ),
          );
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenThrow(const VerifierApiException(503, 'down'));
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        // The cached claim is the same platform:identity under different
        // casing/proof — the union must not produce a second chip.
        expect: () => const <OtherProfileState>[],
        errors: () => [isA<VerifierApiException>()],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'clears chips when the authoritative resolve confirms a negative',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenAnswer((_) async => const <IdentityClaim>[]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            isEmpty,
          ),
        ],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'keeps chips and skips the resolve when the claims source read fails',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.freshIdentityTags(
              pubkey: testPubkey,
              kind0Tags: any(named: 'kind0Tags'),
            ),
          ).thenThrow(Exception('db closed'));
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        // Resolving against the kind-0 fallback could authoritatively
        // clear kind-10011 chips, so the degraded tick keeps
        // last-known-good and does not consult the verifier at all.
        expect: () => const <OtherProfileState>[],
        errors: () => [isA<Exception>()],
        verify: (_) {
          verifyNever(
            () => mockClaimsRepository.resolveClaims(
              pubkey: any(named: 'pubkey'),
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          );
        },
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'carries claims through reload instead of dropping them',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: testPubkey,
              requireRawKind0: any(named: 'requireRawKind0'),
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                const CachedVerifiedClaims(claims: [aliceClaim], isFresh: true),
          );
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenAnswer((_) async => const [aliceClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
        expect: () => [
          isA<OtherProfileLoading>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
        ],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'passes the rendered claims to resolveClaims so a rate-limited '
        'outcome can preserve them',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenAnswer((_) async => const [aliceClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        expect: () => const <OtherProfileState>[],
        verify: (_) {
          verify(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: null,
              renderedClaims: const [aliceClaim],
            ),
          ).called(1);
        },
      );

      late Completer<UserProfile?> cachedProfileGate;
      blocTest<OtherProfileBloc, OtherProfileState>(
        'reads claims after the cache await so a resolve landing mid-load '
        'is not clobbered',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          cachedProfileGate = Completer<UserProfile?>();
          addTearDown(() {
            if (!cachedProfileGate.isCompleted) {
              cachedProfileGate.complete(null);
            }
          });
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) => cachedProfileGate.future);
          when(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: testPubkey,
              requireRawKind0: any(named: 'requireRawKind0'),
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockClaimsRepository.resolveClaims(
              pubkey: testPubkey,
              freshTags: any(named: 'freshTags'),
              cached: any(named: 'cached'),
              renderedClaims: any(named: 'renderedClaims'),
            ),
          ).thenAnswer((_) async => const [aliceClaim, bobClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) async {
          bloc.add(const OtherProfileLoadRequested());
          await pumpEventQueue();
          bloc.add(const VerifiedClaimsRequested());
          await pumpEventQueue();
          cachedProfileGate.complete(createTestProfile());
          await pumpEventQueue();
        },
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
          isA<OtherProfileLoading>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
        ],
      );
    });

    group('monetization self-heal (#6329)', () {
      UserProfile relayProfileWithLinks() => UserProfile(
        pubkey: testPubkey,
        displayName: testDisplayName,
        about: testAbout,
        picture: testPicture,
        createdAt: DateTime(2026),
        eventId:
            'relayevent0123456789012345678901234567890123456789012345678901',
        rawData: {
          divineMonetizationLinksKey: [
            const MonetizationLink(
              provider: MonetizationLinkProvider.cashApp,
              category: MonetizationLinkCategory.tip,
              url: r'https://cash.app/$creator',
              enabled: true,
            ).toJson(),
          ],
        },
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'asks the repository to retry raw Kind 0 when monetization is on',
        build: () {
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer(
            (_) async => createTestProfile(eventId: 'rest-$testPubkey'),
          );
          when(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
              requireRawKind0: any(named: 'requireRawKind0'),
              rawKind0RetryDelays: any(named: 'rawKind0RetryDelays'),
            ),
          ).thenAnswer((_) async => relayProfileWithLinks());
          return OtherProfileBloc(
            profileRepository: mockProfileRepository,
            pubkey: testPubkey,
            contentBlocklistRepository: mockBlocklistRepository,
            currentUserPubkey: testCurrentUserPubkey,
            followRepository: mockFollowRepository,
            requireRawKind0: true,
            rawKind0RetryDelays: const [Duration(milliseconds: 1)],
          );
        },
        act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
        verify: (bloc) {
          final state = bloc.state;
          expect(state, isA<OtherProfileLoaded>());
          final profile = (state as OtherProfileLoaded).profile;
          expect(profile.isRestProjection, isFalse);
          expect(profile.enabledMonetizationLinks, isNotEmpty);
          verify(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: testPubkey,
              requireRawKind0: true,
              rawKind0RetryDelays: const [Duration(milliseconds: 1)],
            ),
          ).called(1);
        },
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'does not re-fetch when the monetization flag is off',
        build: () {
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer(
            (_) async => createTestProfile(eventId: 'rest-$testPubkey'),
          );
          when(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
              requireRawKind0: any(named: 'requireRawKind0'),
              rawKind0RetryDelays: any(named: 'rawKind0RetryDelays'),
            ),
          ).thenAnswer((_) async => null);
          return OtherProfileBloc(
            profileRepository: mockProfileRepository,
            pubkey: testPubkey,
            contentBlocklistRepository: mockBlocklistRepository,
            currentUserPubkey: testCurrentUserPubkey,
            followRepository: mockFollowRepository,
            rawKind0RetryDelays: const [Duration(milliseconds: 1)],
          );
        },
        act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
        verify: (_) {
          // Omitting requireRawKind0 matches the default (false) call only.
          verify(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).called(1); // only the initial load; no self-heal retries
        },
      );
    });
  });
}

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}
