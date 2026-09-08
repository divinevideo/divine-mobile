// ABOUTME: Unit tests for MyProfileBloc
// ABOUTME: Tests one-shot load, stream subscription, and NIP-05 extraction

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

/// Captures errors routed through [Bloc.onError] so a test can assert that a
/// bloc closed mid-flight records no error when its awaited work resumes.
class _ErrorCapturingObserver extends BlocObserver {
  final List<Object> errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  group(MyProfileBloc, () {
    late _MockProfileRepository mockProfileRepository;
    late StreamController<UserProfile?> profileStreamController;

    // Test data constants - using full 64-character hex pubkey as required
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    /// Helper to create a test UserProfile
    UserProfile createTestProfile({
      String pubkey = testPubkey,
      String? displayName = 'Test User',
      String? about = 'Test bio',
      String? picture = 'https://example.com/avatar.png',
      String? nip05,
      String eventId =
          'event123456789012345678901234567890123456789012345678901234567890',
    }) {
      return UserProfile(
        pubkey: pubkey,
        displayName: displayName,
        about: about,
        picture: picture,
        nip05: nip05,
        rawData: const {},
        createdAt: DateTime(2024),
        eventId: eventId,
      );
    }

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
    });

    MyProfileBloc createBloc({String pubkey = testPubkey}) =>
        MyProfileBloc(profileRepository: mockProfileRepository, pubkey: pubkey);

    _ErrorCapturingObserver captureBlocErrors() {
      final observer = _ErrorCapturingObserver();
      final previousObserver = Bloc.observer;
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = previousObserver);
      return observer;
    }

    test('initial state is $MyProfileInitial', () {
      final bloc = createBloc();
      expect(bloc.state, isA<MyProfileInitial>());
      expect(bloc.pubkey, equals(testPubkey));
      bloc.close();
    });

    group('$MyProfileState', () {
      test('$MyProfileInitial instances are equal', () {
        const state1 = MyProfileInitial();
        const state2 = MyProfileInitial();
        expect(state1, equals(state2));
      });

      test('$MyProfileLoading instances are equal with same profile', () {
        final profile = createTestProfile();
        final state1 = MyProfileLoading(profile: profile);
        final state2 = MyProfileLoading(profile: profile);
        expect(state1, equals(state2));
      });

      test('$MyProfileLoading instances differ with different profiles', () {
        final profile1 = createTestProfile(
          eventId:
              'event1234567890123456789012345678901234567890123456789012345678',
        );
        final profile2 = createTestProfile(
          eventId:
              'event2345678901234567890123456789012345678901234567890123456789',
        );
        final state1 = MyProfileLoading(profile: profile1);
        final state2 = MyProfileLoading(profile: profile2);
        expect(state1, isNot(equals(state2)));
      });

      test(
        '$MyProfileLoading instances differ with different extractedUsername',
        () {
          final profile = createTestProfile();
          final state1 = MyProfileLoading(
            profile: profile,
            extractedUsername: 'alice',
          );
          final state2 = MyProfileLoading(
            profile: profile,
            extractedUsername: 'bob',
          );
          expect(state1, isNot(equals(state2)));
        },
      );

      test(
        '$MyProfileLoaded instances are equal with same profile and flags',
        () {
          final profile = createTestProfile();
          final state1 = MyProfileLoaded(
            profile: profile,
            isFresh: true,
            extractedUsername: 'alice',
          );
          final state2 = MyProfileLoaded(
            profile: profile,
            isFresh: true,
            extractedUsername: 'alice',
          );
          expect(state1, equals(state2));
        },
      );

      test('$MyProfileLoaded instances differ with different isFresh', () {
        final profile = createTestProfile();
        final state1 = MyProfileLoaded(profile: profile, isFresh: true);
        final state2 = MyProfileLoaded(profile: profile, isFresh: false);
        expect(state1, isNot(equals(state2)));
      });

      test(
        '$MyProfileLoaded instances differ with different extractedUsername',
        () {
          final profile = createTestProfile();
          final state1 = MyProfileLoaded(
            profile: profile,
            isFresh: true,
            extractedUsername: 'alice',
          );
          final state2 = MyProfileLoaded(
            profile: profile,
            isFresh: true,
            extractedUsername: 'bob',
          );
          expect(state1, isNot(equals(state2)));
        },
      );

      test('$MyProfileError instances are equal with same errorType', () {
        const state1 = MyProfileError(errorType: MyProfileErrorType.notFound);
        const state2 = MyProfileError(errorType: MyProfileErrorType.notFound);
        expect(state1, equals(state2));
      });

      test('$MyProfileError instances differ with different errorType', () {
        const state1 = MyProfileError(errorType: MyProfileErrorType.notFound);
        const state2 = MyProfileError(
          errorType: MyProfileErrorType.networkError,
        );
        expect(state1, isNot(equals(state2)));
      });

      test('$MyProfileUpdated instances are equal with same profile', () {
        final profile = createTestProfile();
        final state1 = MyProfileUpdated(
          profile: profile,
          extractedUsername: 'alice',
        );
        final state2 = MyProfileUpdated(
          profile: profile,
          extractedUsername: 'alice',
        );
        expect(state1, equals(state2));
      });

      test('$MyProfileUpdated instances differ with different profiles', () {
        final profile1 = createTestProfile(
          eventId:
              'event1234567890123456789012345678901234567890123456789012345678',
        );
        final profile2 = createTestProfile(
          eventId:
              'event2345678901234567890123456789012345678901234567890123456789',
        );
        final state1 = MyProfileUpdated(profile: profile1);
        final state2 = MyProfileUpdated(profile: profile2);
        expect(state1, isNot(equals(state2)));
      });

      test(
        '$MyProfileUpdated instances differ with different extractedUsername',
        () {
          final profile = createTestProfile();
          final state1 = MyProfileUpdated(
            profile: profile,
            extractedUsername: 'alice',
          );
          final state2 = MyProfileUpdated(
            profile: profile,
            extractedUsername: 'bob',
          );
          expect(state1, isNot(equals(state2)));
        },
      );
    });

    group('$MyProfileEvent', () {
      test('$MyProfileLoadRequested instances are equal', () {
        const event1 = MyProfileLoadRequested();
        const event2 = MyProfileLoadRequested();
        expect(event1, equals(event2));
      });

      test('$MyProfileSubscriptionRequested instances are equal', () {
        const event1 = MyProfileSubscriptionRequested();
        const event2 = MyProfileSubscriptionRequested();
        expect(event1, equals(event2));
      });

      test('$MyProfileFetchRequested instances are equal', () {
        const event1 = MyProfileFetchRequested();
        const event2 = MyProfileFetchRequested();
        expect(event1, equals(event2));
      });

      test('$MyProfileRefreshRequested instances are equal', () {
        const event1 = MyProfileRefreshRequested();
        const event2 = MyProfileRefreshRequested();
        expect(event1, equals(event2));
      });
    });

    group('$MyProfileLoadRequested', () {
      group('with cached profile available', () {
        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading with cache, loaded fresh] '
          'when fresh fetch succeeds',
          setUp: () {
            final cachedProfile = createTestProfile(
              nip05: '_@alice.divine.video',
              eventId: 'cached12345678901234567890123456789012345678901234567890123456',
            );
            final freshProfile = createTestProfile(
              nip05: '_@alice.divine.video',
              eventId: 'fresh123456789012345678901234567890123456789012345678901234567',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => cachedProfile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>()
                .having(
                  (s) => s.profile?.eventId,
                  'profile.eventId',
                  'cached12345678901234567890123456789012345678901234567890123456',
                )
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  'alice',
                ),
            isA<MyProfileLoaded>()
                .having(
                  (s) => s.profile.eventId,
                  'profile.eventId',
                  'fresh123456789012345678901234567890123456789012345678901234567',
                )
                .having((s) => s.isFresh, 'isFresh', true)
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  'alice',
                ),
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

        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading with cache, loaded stale] '
          'when fresh fetch returns null',
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
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<MyProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', false),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading with cache, loaded stale] '
          'when fresh fetch throws',
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
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<MyProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', false),
          ],
        );
      });

      group('without cached profile', () {
        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading null, loaded fresh] '
          'when fresh fetch succeeds',
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
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
            isA<MyProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading null, error notFound] '
          'when fresh fetch is authoritatively missing',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.isConfirmedMissing(testPubkey),
            ).thenReturn(true);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
            isA<MyProfileError>().having(
              (s) => s.errorType,
              'errorType',
              MyProfileErrorType.notFound,
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading null, error networkError] '
          'when fresh fetch is indeterminate',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.isConfirmedMissing(testPubkey),
            ).thenReturn(false);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
            isA<MyProfileError>().having(
              (s) => s.errorType,
              'errorType',
              MyProfileErrorType.networkError,
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading null, error networkError] '
          'when fresh fetch throws',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenThrow(Exception('Network error'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
            isA<MyProfileError>().having(
              (s) => s.errorType,
              'errorType',
              MyProfileErrorType.networkError,
            ),
          ],
        );
      });

      group('NIP-05 username extraction', () {
        blocTest<MyProfileBloc, MyProfileState>(
          'extracts username from new subdomain format '
          '_@username.divine.video',
          setUp: () {
            final profile = createTestProfile(nip05: '_@alice.divine.video');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'alice',
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'alice',
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'extracts username from legacy format '
          'username@divine.video',
          setUp: () {
            final profile = createTestProfile(nip05: 'bob@divine.video');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'bob',
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'bob',
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'extracts username from legacy format '
          'username@openvine.co',
          setUp: () {
            final profile = createTestProfile(nip05: 'charlie@openvine.co');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'charlie',
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'charlie',
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'returns null extractedUsername for non-divine NIP-05',
          setUp: () {
            final profile = createTestProfile(nip05: 'user@example.com');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'returns null extractedUsername when NIP-05 is null',
          setUp: () {
            final profile = createTestProfile();
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'returns null extractedUsername when NIP-05 is empty',
          setUp: () {
            final profile = createTestProfile(nip05: '');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
          ],
        );
      });

      group('external NIP-05 extraction', () {
        blocTest<MyProfileBloc, MyProfileState>(
          'extracts external NIP-05 for non-divine domain',
          setUp: () {
            final profile = createTestProfile(nip05: 'alice@example.com');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>()
                .having(
                  (s) => s.externalNip05,
                  'externalNip05',
                  'alice@example.com',
                )
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  isNull,
                ),
            isA<MyProfileLoaded>()
                .having(
                  (s) => s.externalNip05,
                  'externalNip05',
                  'alice@example.com',
                )
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  isNull,
                ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'returns null externalNip05 for divine.video domain',
          setUp: () {
            final profile = createTestProfile(nip05: '_@alice.divine.video');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>()
                .having((s) => s.externalNip05, 'externalNip05', isNull)
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  'alice',
                ),
            isA<MyProfileLoaded>()
                .having((s) => s.externalNip05, 'externalNip05', isNull)
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  'alice',
                ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'returns null externalNip05 when NIP-05 is null',
          setUp: () {
            final profile = createTestProfile();
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.externalNip05,
              'externalNip05',
              isNull,
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.externalNip05,
              'externalNip05',
              isNull,
            ),
          ],
        );
      });
    });

    group('$MyProfileSubscriptionRequested', () {
      blocTest<MyProfileBloc, MyProfileState>(
        'emits [loading with cached profile, updated] when stream emits a profile',
        setUp: () {
          final cachedProfile = createTestProfile(
            displayName: 'Cached Name',
            eventId: 'cached12345678901234567890123456789012345678901234567890123456',
          );
          final streamProfile = createTestProfile(
            displayName: 'Stream Name',
            eventId: 'stream12345678901234567890123456789012345678901234567890123456',
          );
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => cachedProfile);
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.value(streamProfile));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          // Initial emit carries the cached profile so the real name is
          // shown immediately — no generated-name flash (#4181).
          isA<MyProfileLoading>().having(
            (s) => s.profile?.displayName,
            'profile.displayName',
            'Cached Name',
          ),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.pubkey,
            'profile.pubkey',
            testPubkey,
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).called(1);
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'emits [loading with null profile] when no cache and stream emits null',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.value(null));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          // No cache → loading with null profile; stream null → same
          // state deduplication means only one emit.
          isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).called(1);
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'emits [loading with cached, updated, updated] '
        'when stream emits multiple profiles',
        setUp: () {
          final cachedProfile = createTestProfile(
            displayName: 'Cached Name',
            eventId: 'cached12345678901234567890123456789012345678901234567890123456',
          );
          final oldName = createTestProfile(
            displayName: 'Old Name',
            eventId: 'oldnam12345678901234567890123456789012345678901234567890123456',
          );
          final newName = createTestProfile(
            displayName: 'New Name',
            eventId: 'fresh123456789012345678901234567890123456789012345678901234567',
          );
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => cachedProfile);
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.fromIterable([oldName, newName]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          isA<MyProfileLoading>().having(
            (s) => s.profile?.displayName,
            'profile.displayName',
            'Cached Name',
          ),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.displayName,
            'displayName',
            'Old Name',
          ),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.displayName,
            'displayName',
            'New Name',
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).called(1);
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'keeps the last displayed profile when the watched row is deleted',
        setUp: () {
          final controller = StreamController<UserProfile?>();
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => controller.stream);
          addTearDown(() {
            if (!controller.isClosed) {
              controller.close();
            }
          });
          profileStreamController = controller;
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyProfileSubscriptionRequested());
          await pumpEventQueue();
          profileStreamController.add(
            createTestProfile(displayName: 'Visible Profile'),
          );
          await pumpEventQueue();
          profileStreamController.add(null);
          await pumpEventQueue();
        },
        expect: () => [
          isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.displayName,
            'profile.displayName',
            'Visible Profile',
          ),
          isA<MyProfileLoading>().having(
            (s) => s.profile?.displayName,
            'profile.displayName',
            'Visible Profile',
          ),
        ],
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'extracts username from stream profile NIP-05',
        setUp: () {
          final profile = createTestProfile(nip05: '_@alice.divine.video');
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.value(profile));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
          isA<MyProfileUpdated>().having(
            (s) => s.extractedUsername,
            'extractedUsername',
            'alice',
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).called(1);
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(1);
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'extracts external NIP-05 from stream profile',
        setUp: () {
          final profile = createTestProfile(nip05: 'alice@example.com');
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.value(profile));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
          isA<MyProfileUpdated>()
              .having(
                (s) => s.externalNip05,
                'externalNip05',
                'alice@example.com',
              )
              .having((s) => s.extractedUsername, 'extractedUsername', isNull),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).called(1);
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(1);
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'cancels previous subscription when dispatched again',
        setUp: () {
          final profile1 = createTestProfile(
            displayName: 'First',
            eventId:
                'first12345678901234567890123456789012345678901234567890123456',
          );
          final profile2 = createTestProfile(
            displayName: 'Second',
            eventId:
                'second1234567890123456789012345678901234567890123456789012345',
          );
          var callCount = 0;
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) {
            callCount++;
            if (callCount == 1) return Stream.value(profile1);
            return Stream.value(profile2);
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyProfileSubscriptionRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const MyProfileSubscriptionRequested());
        },
        expect: () => [
          isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.displayName,
            'displayName',
            'First',
          ),
          isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.displayName,
            'displayName',
            'Second',
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(2);
        },
      );
    });

    group('$MyProfileRefreshRequested', () {
      const verifiedClaim = IdentityClaim(
        pubkey: testPubkey,
        platform: 'github',
        identity: 'octocat',
        proof: 'https://github.com/octocat',
      );
      late Completer<UserProfile?> refreshFetchCompleter;

      blocTest<MyProfileBloc, MyProfileState>(
        'emits notFound and completes when no profile exists',
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.isConfirmedMissing(testPubkey),
          ).thenReturn(true);
        },
        build: createBloc,
        act: (bloc) async {
          final completer = Completer<void>();
          bloc.add(MyProfileRefreshRequested(completer: completer));
          await completer.future;
        },
        expect: () => [
          isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
          isA<MyProfileError>().having(
            (s) => s.errorType,
            'errorType',
            MyProfileErrorType.notFound,
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).called(1);
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'keeps the current profile visible when refresh fails',
        seed: () => MyProfileUpdated(
          profile: createTestProfile(displayName: 'Visible Profile'),
        ),
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) async {
          final completer = Completer<void>();
          bloc.add(MyProfileRefreshRequested(completer: completer));
          await completer.future;
        },
        expect: () => [
          isA<MyProfileLoading>().having(
            (s) => s.profile?.displayName,
            'profile.displayName',
            'Visible Profile',
          ),
          isA<MyProfileLoaded>()
              .having(
                (s) => s.profile.displayName,
                'profile.displayName',
                'Visible Profile',
              )
              .having((s) => s.isFresh, 'isFresh', false),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'preserves verified claims while refresh revalidates',
        seed: () => MyProfileUpdated(
          profile: createTestProfile(displayName: 'Visible Profile'),
          verifiedClaims: const [verifiedClaim],
        ),
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) async {
          final completer = Completer<void>();
          bloc.add(MyProfileRefreshRequested(completer: completer));
          await completer.future;
        },
        expect: () => [
          isA<MyProfileLoading>()
              .having(
                (s) => s.profile?.displayName,
                'profile.displayName',
                'Visible Profile',
              )
              .having((s) => s.verifiedClaims, 'verifiedClaims', [
                verifiedClaim,
              ]),
          isA<MyProfileLoaded>()
              .having(
                (s) => s.profile.displayName,
                'profile.displayName',
                'Visible Profile',
              )
              .having((s) => s.verifiedClaims, 'verifiedClaims', [
                verifiedClaim,
              ]),
        ],
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'uses the latest watched profile when refresh returns no profile',
        setUp: () {
          final controller = StreamController<UserProfile?>();
          refreshFetchCompleter = Completer<UserProfile?>();
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer(
            (_) async => createTestProfile(displayName: 'Old Profile'),
          );
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => controller.stream);
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) => refreshFetchCompleter.future);
          addTearDown(() {
            if (!controller.isClosed) {
              controller.close();
            }
          });
          profileStreamController = controller;
          addTearDown(() {
            if (!refreshFetchCompleter.isCompleted) {
              refreshFetchCompleter.complete(null);
            }
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyProfileSubscriptionRequested());
          await pumpEventQueue();
          final completer = Completer<void>();
          bloc.add(MyProfileRefreshRequested(completer: completer));
          await pumpEventQueue();
          profileStreamController.add(
            createTestProfile(displayName: 'New Profile'),
          );
          await pumpEventQueue();
          refreshFetchCompleter.complete(null);
          await completer.future;
        },
        expect: () => [
          isA<MyProfileLoading>().having(
            (s) => s.profile?.displayName,
            'profile.displayName',
            'Old Profile',
          ),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.displayName,
            'profile.displayName',
            'New Profile',
          ),
          isA<MyProfileLoaded>()
              .having(
                (s) => s.profile.displayName,
                'profile.displayName',
                'New Profile',
              )
              .having((s) => s.isFresh, 'isFresh', false),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).called(1);
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'does not preserve a stale profile for a different pubkey',
        seed: () => MyProfileUpdated(
          profile: createTestProfile(
            pubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            displayName: 'Wrong User',
          ),
        ),
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.isConfirmedMissing(testPubkey),
          ).thenReturn(false);
        },
        build: createBloc,
        act: (bloc) async {
          final completer = Completer<void>();
          bloc.add(MyProfileRefreshRequested(completer: completer));
          await completer.future;
        },
        expect: () => [
          isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
          isA<MyProfileError>().having(
            (s) => s.errorType,
            'errorType',
            MyProfileErrorType.networkError,
          ),
        ],
      );
    });

    group('$MyProfileFetchRequested', () {
      blocTest<MyProfileBloc, MyProfileState>(
        'calls fetchFreshProfile and emits nothing',
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileFetchRequested()),
        expect: () => <MyProfileState>[],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.watchProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'reports error without emitting state when fetch throws',
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileFetchRequested()),
        expect: () => <MyProfileState>[],
        errors: () => [isA<Exception>()],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).called(1);
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'does not emit error when fetch returns null',
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileFetchRequested()),
        expect: () => <MyProfileState>[],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).called(1);
        },
      );
    });

    group('after close (lifecycle regression)', () {
      test(
        'records no error when closed before the fresh profile resolves on load',
        () async {
          final observer = captureBlocErrors();
          final freshCompleter = Completer<UserProfile?>();
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) => freshCompleter.future);

          final bloc = createBloc()..add(const MyProfileLoadRequested());

          await pumpEventQueue();
          await bloc.close();
          freshCompleter.complete(createTestProfile());
          await pumpEventQueue();

          expect(observer.errors, isEmpty);
        },
      );

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

          final bloc = createBloc()..add(const MyProfileLoadRequested());

          await pumpEventQueue();
          await bloc.close();
          freshCompleter.completeError(Exception('network error'));
          await pumpEventQueue();

          expect(observer.errors, isEmpty);
        },
      );

      test(
        'records no error when closed before the profile stream emits',
        () async {
          final observer = captureBlocErrors();
          final streamController = StreamController<UserProfile?>();
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => streamController.stream);

          final bloc = createBloc()
            ..add(const MyProfileSubscriptionRequested());

          await pumpEventQueue();
          await bloc.close();
          streamController.add(createTestProfile());
          await pumpEventQueue();
          await streamController.close();

          expect(observer.errors, isEmpty);
        },
      );
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

      MyProfileBloc createClaimsBloc() => MyProfileBloc(
        profileRepository: mockProfileRepository,
        pubkey: testPubkey,
        identityClaimsRepository: mockClaimsRepository,
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'renders the cached snapshot instantly, then the resolved claims',
        seed: () => MyProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
        ),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => const CachedVerifiedClaims(
              claims: [aliceClaim],
              isFresh: true,
            ),
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
          isA<MyProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
          isA<MyProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
        ],
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'keeps last-known-good claims when the verifier fails',
        seed: () => MyProfileUpdated(
          profile: createTestProfile(),
        ),
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
          isA<MyProfileUpdated>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
        ],
        errors: () => [isA<VerifierApiException>()],
      );

      late Completer<List<IdentityClaim>> staleResolve;
      blocTest<MyProfileBloc, MyProfileState>(
        'uses the newest verification result when requests overlap',
        seed: () => MyProfileUpdated(
          profile: createTestProfile(),
        ),
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
          isA<MyProfileUpdated>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [bobClaim],
          ),
        ],
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'keeps rendered chips when the instant-path intersection is empty '
        'and the verifier is unreachable',
        seed: () => MyProfileLoaded(
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
        expect: () => const <MyProfileState>[],
        errors: () => [isA<VerifierApiException>()],
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'passes the rendered claims to resolveClaims so a rate-limited '
        'outcome can preserve them',
        seed: () => MyProfileUpdated(
          profile: createTestProfile(),
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
        expect: () => const <MyProfileState>[],
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

      blocTest<MyProfileBloc, MyProfileState>(
        'carries rendered claims through profile stream ticks',
        seed: () => MyProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.value(createTestProfile()));
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
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          isA<MyProfileLoading>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
          isA<MyProfileUpdated>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
        ],
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'unions instant-path chips rendered-first instead of replacing',
        seed: () => MyProfileLoaded(
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
              claims: [bobClaim],
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
          ).thenAnswer((_) async => const [aliceClaim, bobClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        // Rendered-first union keeps chip order stable, so the
        // authoritative resolve emit is Equatable-suppressed afterwards.
        expect: () => [
          isA<MyProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
        ],
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'clears chips when the authoritative resolve confirms a negative',
        seed: () => MyProfileLoaded(
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
          isA<MyProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            isEmpty,
          ),
        ],
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'keeps chips and skips the resolve when the claims source read fails',
        seed: () => MyProfileLoaded(
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
        expect: () => const <MyProfileState>[],
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

      blocTest<MyProfileBloc, MyProfileState>(
        'does not double-render one identity when the cached casing differs',
        seed: () => MyProfileLoaded(
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
        expect: () => const <MyProfileState>[],
        errors: () => [isA<VerifierApiException>()],
      );

      late Completer<UserProfile?> cachedProfileGate;
      blocTest<MyProfileBloc, MyProfileState>(
        'reads claims after the cache await so a resolve landing mid-load '
        'is not clobbered',
        seed: () => MyProfileLoaded(
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
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
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
          bloc.add(const MyProfileLoadRequested());
          await pumpEventQueue();
          bloc.add(const VerifiedClaimsRequested());
          await pumpEventQueue();
          cachedProfileGate.complete(createTestProfile());
          await pumpEventQueue();
        },
        expect: () => [
          isA<MyProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
          isA<MyProfileLoading>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
          isA<MyProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
        ],
      );
    });
  });
}

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}
