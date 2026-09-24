// ABOUTME: Pins the ProfileReader read/write split — the compile-time
// ABOUTME: boundary that keeps signing off the ungated profile provider.

import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockHttpClient extends Mock implements Client {}

const _pubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

/// A standalone [ProfileReader] that implements the interface **without**
/// extending [ProfileRepository].
///
/// This is the guard: adding any member to [ProfileReader] stops this class
/// from compiling, so the whole suite goes red. That is deliberate — the
/// interface is a security boundary (see `profile_reader.dart`), and widening
/// it must be a conscious act, not a drive-by. If you are here because this
/// failed to compile, confirm the new member is signer-free before adding it
/// below.
class _ExhaustiveReader implements ProfileReader {
  @override
  Future<UserProfile?> getCachedProfile({required String pubkey}) async => null;

  // Widened consciously: this is a batch Drift read — signer-free and
  // relay-optional, the same invariant as getCachedProfile.
  @override
  Future<List<UserProfile>> getCachedProfiles({
    required List<String> pubkeys,
  }) async => const [];

  @override
  Stream<UserProfile?> watchProfile({required String pubkey}) =>
      const Stream.empty();

  @override
  Stream<ProfileStats?> watchProfileStats({required String pubkey}) =>
      const Stream.empty();

  // Widened consciously: a one-shot Drift read of the stats cache —
  // signer-free and relay-optional, the same invariant as getCachedProfile.
  @override
  Future<ProfileStats?> getCachedProfileStats({required String pubkey}) async =>
      null;

  @override
  Future<UserProfile?> fetchFreshProfile({
    required String pubkey,
    bool requireRawKind0 = false,
    List<Duration> rawKind0RetryDelays = const [],
  }) async => null;

  // Widened consciously: this reads session-local fetch classification only.
  @override
  bool isConfirmedMissing(String pubkey) => false;

  @override
  Future<Map<String, UserProfile>> fetchBatchProfiles({
    required List<String> pubkeys,
    bool ignoreBlockFilter = false,
  }) async => {};

  // Widened consciously: this is a public unauthenticated HTTP read, so it
  // needs neither the active signer nor a relay-ready client.
  @override
  Future<DivineUsernameLookup> lookupUsernameByPubkey({
    required String pubkeyHex,
  }) async => const DivineUsernameUnknown();

  @override
  Future<List<List<String>>?> cachedIdentityTags(String pubkey) async => null;

  @override
  Future<List<List<String>>> freshIdentityTags({
    required String pubkey,
    required List<List<String>> kind0Tags,
  }) async => const [];
}

void main() {
  group(ProfileReader, () {
    late _MockUserProfilesDao userProfilesDao;
    late ProfileRepository repository;

    setUp(() {
      userProfilesDao = _MockUserProfilesDao();
      repository = ProfileRepository(
        nostrClient: _MockNostrClient(),
        userProfilesDao: userProfilesDao,
        httpClient: _MockHttpClient(),
      );
    });

    test('is implemented by $ProfileRepository', () {
      expect(repository, isA<ProfileReader>());
    });

    test('reads the Drift cache through the interface handle', () async {
      final cached = UserProfile(
        pubkey: _pubkey,
        name: 'real-name',
        rawData: const {},
        createdAt: DateTime.utc(2026),
        eventId: 'event-id',
      );
      when(
        () => userProfilesDao.getProfile(_pubkey),
      ).thenAnswer((_) async => cached);

      // Deliberately typed as the interface: this is the handle the
      // identity-known provider hands to display code.
      final ProfileReader reader = repository;

      expect(await reader.getCachedProfile(pubkey: _pubkey), cached);
    });

    test(
      'reads the Drift cache in batch through the interface handle',
      () async {
        final cached = UserProfile(
          pubkey: _pubkey,
          name: 'real-name',
          rawData: const {},
          createdAt: DateTime.utc(2026),
          eventId: 'event-id',
        );
        when(
          () => userProfilesDao.getProfilesByPubkeys([_pubkey]),
        ).thenAnswer((_) async => [cached]);

        final ProfileReader reader = repository;

        expect(await reader.getCachedProfiles(pubkeys: [_pubkey]), [cached]);
      },
    );

    test('filters blocked profiles from batch cache reads', () async {
      final blocked = UserProfile(
        pubkey: _pubkey,
        name: 'blocked-name',
        rawData: const {},
        createdAt: DateTime.utc(2026),
        eventId: 'event-id',
      );
      when(
        () => userProfilesDao.getProfilesByPubkeys([_pubkey]),
      ).thenAnswer((_) async => [blocked]);
      repository = ProfileRepository(
        nostrClient: _MockNostrClient(),
        userProfilesDao: userProfilesDao,
        httpClient: _MockHttpClient(),
        blockFilter: (pubkey) => pubkey == _pubkey,
      );

      final ProfileReader reader = repository;

      expect(await reader.getCachedProfiles(pubkeys: [_pubkey]), isEmpty);
    });

    test('the interface can be implemented without signer or relay client', () {
      // _ExhaustiveReader satisfies the contract with neither. If this stops
      // compiling, the widened interface needs an explicit signer-safety
      // review before this test implementation is updated.
      expect(_ExhaustiveReader(), isA<ProfileReader>());
    });
  });
}
