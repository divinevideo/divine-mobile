import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/mentions/mention_search.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

UserProfile _profile(String pubkey, String name) => UserProfile(
  pubkey: pubkey,
  displayName: name,
  rawData: const {},
  createdAt: DateTime.utc(2026),
  eventId: 'e' * 64,
);

void main() {
  final cachedMatch = 'a' * 64;
  final uncached = 'b' * 64;
  final cachedOther = 'c' * 64;
  final candidates = [cachedMatch, uncached, cachedOther];
  late _MockProfileRepository profiles;

  setUp(() {
    profiles = _MockProfileRepository();
    when(
      () => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
    ).thenAnswer(
      (_) async => [
        _profile(cachedMatch, 'Alice'),
        _profile(cachedOther, 'Bob'),
      ],
    );
  });

  group('mentionSearchLocal', () {
    test('marks only the candidates it matched as seen', () async {
      final local = await mentionSearchLocal(
        lowercaseQuery: 'al',
        candidates: candidates,
        profileRepository: profiles,
      );
      expect(local.matches.map((match) => match.pubkey), [cachedMatch]);
      expect(local.seen, {cachedMatch});
    });
  });

  group('mentionSearchRemote', () {
    test('backfills candidates the cache did not match, once each', () async {
      when(
        () => profiles.searchUsersFromApi(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          sortBy: any(named: 'sortBy'),
          hasVideos: any(named: 'hasVideos'),
        ),
      ).thenAnswer(
        (_) async => [
          _profile(cachedMatch, 'Alice'),
          _profile(uncached, 'Alicia'),
          _profile(cachedOther, 'Alfred'),
        ],
      );
      final local = await mentionSearchLocal(
        lowercaseQuery: 'al',
        candidates: candidates,
        profileRepository: profiles,
      );
      final merged = await mentionSearchRemote(
        lowercaseQuery: 'al',
        profileRepository: profiles,
        previousMatches: local.matches,
        previouslySeen: local.seen,
      );
      expect(merged.map((match) => match.pubkey), [
        cachedMatch,
        uncached,
        cachedOther,
      ]);
    });
  });
}
