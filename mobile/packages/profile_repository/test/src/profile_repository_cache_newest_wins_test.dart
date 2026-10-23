// ABOUTME: Verifies ProfileRepository.cacheProfile is protected by the DAO's
// ABOUTME: newest-wins guard so a stale or blank kind-0 cannot blank a good
// ABOUTME: cached profile for the same pubkey.

import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockHttpClient extends Mock implements Client {}

void main() {
  group('ProfileRepository.cacheProfile newest-wins', () {
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    late AppDatabase db;
    late ProfileRepository repository;

    UserProfile profile({
      required String eventId,
      required DateTime createdAt,
      String? name,
      String? picture,
    }) => UserProfile(
      pubkey: testPubkey,
      eventId: eventId,
      name: name,
      picture: picture,
      rawData: const {},
      createdAt: createdAt,
    );

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      repository = ProfileRepository(
        nostrClient: _MockNostrClient(),
        userProfilesDao: db.userProfilesDao,
        httpClient: _MockHttpClient(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'raw profile completes equal-time REST cache and cannot be degraded',
      () async {
        final timestamp = DateTime.utc(2026);
        final projection = UserProfile(
          pubkey: testPubkey,
          eventId: 'rest-$testPubkey',
          name: 'Alice',
          picture: 'https://example.com/alice.jpg',
          createdAt: timestamp,
          rawData: const {},
        );
        final raw = UserProfile(
          pubkey: testPubkey,
          eventId: 'd' * 64,
          name: 'Alice',
          picture: 'https://example.com/alice.jpg',
          createdAt: timestamp,
          rawData: const {'custom': 'complete'},
        );
        await repository.cacheProfile(projection);
        await repository.cacheProfile(raw);
        expect(
          (await repository.getCachedProfile(pubkey: testPubkey))!.rawData,
          raw.rawData,
        );
        await repository.cacheProfile(
          projection.copyWith(about: 'REST richer'),
        );
        expect(
          (await repository.getCachedProfile(pubkey: testPubkey))!.eventId,
          raw.eventId,
        );
      },
    );

    test(
      'keeps the newer cached row when an older profile is cached',
      () async {
        await repository.cacheProfile(
          profile(
            eventId: 'new',
            name: 'Alice',
            picture: 'https://example.com/alice.jpg',
            createdAt: DateTime.utc(2024, 1, 2),
          ),
        );

        await repository.cacheProfile(
          profile(
            eventId: 'old',
            name: 'Old Alice',
            createdAt: DateTime.utc(2024),
          ),
        );

        final cached = await repository.getCachedProfile(pubkey: testPubkey);
        expect(cached, isNotNull);
        expect(cached!.name, equals('Alice'));
        expect(cached.picture, equals('https://example.com/alice.jpg'));
        expect(cached.eventId, equals('new'));
      },
    );

    test(
      'keeps name and picture when an older blank profile is cached',
      () async {
        await repository.cacheProfile(
          profile(
            eventId: 'good',
            name: 'Alice',
            picture: 'https://example.com/alice.jpg',
            createdAt: DateTime.utc(2024, 1, 2),
          ),
        );

        await repository.cacheProfile(
          profile(eventId: 'blank', createdAt: DateTime.utc(2024)),
        );

        final cached = await repository.getCachedProfile(pubkey: testPubkey);
        expect(cached, isNotNull);
        expect(cached!.name, equals('Alice'));
        expect(cached.picture, equals('https://example.com/alice.jpg'));
      },
    );
  });
}
