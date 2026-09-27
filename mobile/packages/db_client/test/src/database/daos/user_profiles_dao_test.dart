// ABOUTME: Unit tests for UserProfilesDao with UserProfile domain model.
// ABOUTME: Tests upsertProfile for inserting and updating user profiles.

import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';

void main() {
  late AppDatabase database;
  late DbClient dbClient;
  late AppDbClient appDbClient;
  late UserProfilesDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const testPubkey2 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  /// Helper to create a UserProfile for testing.
  UserProfile createProfile({
    String pubkey = testPubkey,
    String eventId = 'event1',
    String? name,
    String? displayName,
    String? about,
    String? picture,
    String? banner,
    String? website,
    String? nip05,
    String? lud16,
    String? lud06,
    DateTime? createdAt,
    Map<String, dynamic>? rawData,
  }) {
    return UserProfile(
      pubkey: pubkey,
      eventId: eventId,
      name: name,
      displayName: displayName,
      about: about,
      picture: picture,
      banner: banner,
      website: website,
      nip05: nip05,
      lud16: lud16,
      lud06: lud06,
      createdAt: createdAt ?? DateTime.now(),
      rawData: rawData ?? {},
    );
  }

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dbClient = DbClient(generatedDatabase: database);
    appDbClient = AppDbClient(dbClient, database);
    dao = database.userProfilesDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('UserProfilesDao', () {
    group('upsertProfile', () {
      test('inserts a new profile', () async {
        final profile = createProfile(
          name: 'Alice',
          displayName: 'Alice in Wonderland',
          about: 'Curiouser and curiouser!',
        );

        await dao.upsertProfile(profile);

        final result = await appDbClient.getProfile(testPubkey);
        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.name, equals('Alice'));
        expect(result.displayName, equals('Alice in Wonderland'));
        expect(result.about, equals('Curiouser and curiouser!'));
      });

      test('updates existing profile with same pubkey', () async {
        final originalProfile = createProfile(
          name: 'Bob',
          displayName: 'Bobby',
        );
        await dao.upsertProfile(originalProfile);

        final updatedProfile = createProfile(
          name: 'Robert',
          displayName: 'Rob',
          eventId: 'event2',
        );
        await dao.upsertProfile(updatedProfile);

        final result = await appDbClient.getProfile(testPubkey);
        expect(result, isNotNull);
        expect(result!.name, equals('Robert'));
        expect(result.displayName, equals('Rob'));
        expect(result.eventId, equals('event2'));

        // Verify only one profile exists
        final allProfiles = await appDbClient.getAllProfiles();
        expect(allProfiles.length, equals(1));
      });

      test('stores all profile fields', () async {
        final profile = createProfile(
          name: 'test_name',
          displayName: 'Test Display Name',
          about: 'Test about',
          picture: 'https://example.com/pic.jpg',
          banner: 'https://example.com/banner.jpg',
          website: 'https://example.com',
          nip05: 'test@example.com',
          lud16: 'test@ln.example.com',
          lud06: 'lnurl1test',
        );

        await dao.upsertProfile(profile);

        final result = await appDbClient.getProfile(testPubkey);
        expect(result, isNotNull);
        expect(result!.name, equals('test_name'));
        expect(result.displayName, equals('Test Display Name'));
        expect(result.about, equals('Test about'));
        expect(result.picture, equals('https://example.com/pic.jpg'));
        expect(result.banner, equals('https://example.com/banner.jpg'));
        expect(result.website, equals('https://example.com'));
        expect(result.nip05, equals('test@example.com'));
        expect(result.lud16, equals('test@ln.example.com'));
        expect(result.lud06, equals('lnurl1test'));
      });

      test('stores rawData as JSON', () async {
        final profile = createProfile(
          rawData: {'custom_field': 'value', 'number': 42},
        );

        await dao.upsertProfile(profile);

        final result = await appDbClient.getProfile(testPubkey);
        expect(result, isNotNull);
        expect(result!.rawData, isNotNull);
        expect(result.rawData, contains('custom_field'));
      });

      test('handles null optional fields', () async {
        final profile = createProfile();

        await dao.upsertProfile(profile);

        final result = await appDbClient.getProfile(testPubkey);
        expect(result, isNotNull);
        expect(result!.name, isNull);
        expect(result.displayName, isNull);
        expect(result.about, isNull);
        expect(result.picture, isNull);
        expect(result.banner, isNull);
        expect(result.website, isNull);
        expect(result.nip05, isNull);
        expect(result.lud16, isNull);
        expect(result.lud06, isNull);
      });

      test('handles multiple different profiles', () async {
        final profile1 = createProfile(name: 'Alice');
        final profile2 = createProfile(pubkey: testPubkey2, name: 'Bob');

        await dao.upsertProfile(profile1);
        await dao.upsertProfile(profile2);

        final result1 = await appDbClient.getProfile(testPubkey);
        final result2 = await appDbClient.getProfile(testPubkey2);

        expect(result1, isNotNull);
        expect(result1!.name, equals('Alice'));

        expect(result2, isNotNull);
        expect(result2!.name, equals('Bob'));

        final allProfiles = await appDbClient.getAllProfiles();
        expect(allProfiles.length, equals(2));
      });

      test('updates lastFetched timestamp', () async {
        final profile = createProfile();

        final before = DateTime.now().subtract(const Duration(seconds: 1));
        await dao.upsertProfile(profile);
        final after = DateTime.now().add(const Duration(seconds: 1));

        final result = await appDbClient.getProfile(testPubkey);
        expect(result, isNotNull);
        expect(result!.lastFetched.isAfter(before), isTrue);
        expect(result.lastFetched.isBefore(after), isTrue);
      });
    });

    group('upsertProfile newest-wins', () {
      test(
        'older kind-0 does not overwrite a newer richer cached row',
        () async {
          await dao.upsertProfile(
            createProfile(
              eventId: 'new',
              name: 'Alice',
              displayName: 'Alice in Wonderland',
              picture: 'https://example.com/alice.jpg',
              createdAt: DateTime.utc(2024, 1, 2),
            ),
          );

          // A stale kind-0 arriving late on a background subscription.
          await dao.upsertProfile(
            createProfile(
              eventId: 'old',
              name: 'Old Alice',
              displayName: 'Old',
              createdAt: DateTime.utc(2024),
            ),
          );

          final result = await dao.getProfile(testPubkey);
          expect(result, isNotNull);
          expect(result!.name, equals('Alice'));
          expect(result.displayName, equals('Alice in Wonderland'));
          expect(result.picture, equals('https://example.com/alice.jpg'));
          expect(result.eventId, equals('new'));
        },
      );

      test('older blank kind-0 leaves name and picture intact', () async {
        await dao.upsertProfile(
          createProfile(
            eventId: 'good',
            name: 'Alice',
            picture: 'https://example.com/alice.jpg',
            createdAt: DateTime.utc(2024, 1, 2),
          ),
        );

        // Blank placeholder profile (identicon + name-from-pubkey) that is
        // older than the good cached row must not blank it.
        await dao.upsertProfile(
          createProfile(eventId: 'blank', createdAt: DateTime.utc(2024)),
        );

        final result = await dao.getProfile(testPubkey);
        expect(result, isNotNull);
        expect(result!.name, equals('Alice'));
        expect(result.picture, equals('https://example.com/alice.jpg'));
        expect(result.eventId, equals('good'));
      });

      test(
        'newer kind-0 applies, including a legitimate field clear',
        () async {
          await dao.upsertProfile(
            createProfile(
              eventId: 'old',
              name: 'Alice',
              picture: 'https://example.com/alice.jpg',
              about: 'the original bio',
              createdAt: DateTime.utc(2024),
            ),
          );

          // The user deliberately removed their picture in a newer event.
          // A field clear in a NEWER event is a real edit and must apply.
          await dao.upsertProfile(
            createProfile(
              eventId: 'new',
              name: 'Alice',
              about: 'the original bio',
              createdAt: DateTime.utc(2024, 1, 2),
            ),
          );

          final result = await dao.getProfile(testPubkey);
          expect(result, isNotNull);
          expect(result!.eventId, equals('new'));
          expect(result.picture, isNull);
          expect(result.name, equals('Alice'));
        },
      );

      test('equal-createdAt richer profile wins', () async {
        final sameTime = DateTime.utc(2024, 6);
        await dao.upsertProfile(
          createProfile(eventId: 'sparse', name: 'Alice', createdAt: sameTime),
        );

        await dao.upsertProfile(
          createProfile(
            eventId: 'rich',
            name: 'Alice',
            displayName: 'Alice in Wonderland',
            picture: 'https://example.com/alice.jpg',
            createdAt: sameTime,
          ),
        );

        final result = await dao.getProfile(testPubkey);
        expect(result, isNotNull);
        expect(result!.eventId, equals('rich'));
        expect(result.displayName, equals('Alice in Wonderland'));
        expect(result.picture, equals('https://example.com/alice.jpg'));
      });

      test('equal-createdAt blank profile does not win', () async {
        final sameTime = DateTime.utc(2024, 6);
        await dao.upsertProfile(
          createProfile(
            eventId: 'rich',
            name: 'Alice',
            displayName: 'Alice in Wonderland',
            picture: 'https://example.com/alice.jpg',
            createdAt: sameTime,
          ),
        );

        await dao.upsertProfile(
          createProfile(eventId: 'blank', createdAt: sameTime),
        );

        final result = await dao.getProfile(testPubkey);
        expect(result, isNotNull);
        expect(result!.eventId, equals('rich'));
        expect(result.name, equals('Alice'));
        expect(result.picture, equals('https://example.com/alice.jpg'));
      });

      test(
        'stale blank kind-0 through EventRouter conversion keeps good row',
        () async {
          // Mirrors EventRouter._handleProfileEvent: build a kind-0 event,
          // convert with UserProfile.fromNostrEvent, then upsert. A good
          // profile arrives first, then a stale blank kind-0 fans in on a
          // background feed subscription — the good row must survive.
          UserProfile fromKind0(
            Map<String, dynamic> content,
            DateTime createdAt,
          ) => UserProfile.fromNostrEvent(
            Event(
              testPubkey,
              0,
              const <List<String>>[],
              jsonEncode(content),
              createdAt: createdAt.millisecondsSinceEpoch ~/ 1000,
            ),
          );

          await dao.upsertProfile(
            fromKind0(
              {'name': 'Alice', 'picture': 'https://example.com/alice.jpg'},
              DateTime.utc(2024, 1, 2),
            ),
          );

          await dao.upsertProfile(
            fromKind0(<String, dynamic>{}, DateTime.utc(2024)),
          );

          final result = await dao.getProfile(testPubkey);
          expect(result, isNotNull);
          expect(result!.name, equals('Alice'));
          expect(result.picture, equals('https://example.com/alice.jpg'));
        },
      );
    });

    group('getProfilesByPubkeys', () {
      test('returns empty list for empty input', () async {
        final results = await dao.getProfilesByPubkeys([]);
        expect(results, isEmpty);
      });

      test('returns matching profiles', () async {
        await dao.upsertProfile(createProfile(name: 'Alice'));
        await dao.upsertProfile(
          createProfile(pubkey: testPubkey2, name: 'Bob'),
        );

        final results = await dao.getProfilesByPubkeys([
          testPubkey,
          testPubkey2,
        ]);
        expect(results, hasLength(2));

        final names = results.map((p) => p.name).toSet();
        expect(names, containsAll(['Alice', 'Bob']));
      });

      test('omits pubkeys not in database', () async {
        await dao.upsertProfile(createProfile(name: 'Alice'));

        final results = await dao.getProfilesByPubkeys([
          testPubkey,
          testPubkey2,
        ]);
        expect(results, hasLength(1));
        expect(results.first.name, equals('Alice'));
      });

      test('returns domain models with all fields', () async {
        await dao.upsertProfile(
          createProfile(
            name: 'test_name',
            displayName: 'Test Display Name',
            about: 'Test about',
            picture: 'https://example.com/pic.jpg',
            nip05: 'test@example.com',
          ),
        );

        final results = await dao.getProfilesByPubkeys([testPubkey]);
        expect(results, hasLength(1));

        final profile = results.first;
        expect(profile.pubkey, equals(testPubkey));
        expect(profile.name, equals('test_name'));
        expect(profile.displayName, equals('Test Display Name'));
        expect(profile.about, equals('Test about'));
        expect(profile.picture, equals('https://example.com/pic.jpg'));
        expect(profile.nip05, equals('test@example.com'));
      });
    });

    group('enforceRowCap', () {
      /// Inserts a profile row with an explicit `last_fetched`, bypassing
      /// [UserProfilesDao.upsertProfile] (which always stamps `DateTime.now()`
      /// and so cannot produce the distinct, ordered timestamps this cap
      /// needs to test eviction order).
      Future<void> insertWithLastFetched(
        String pubkey,
        DateTime lastFetched,
      ) {
        return database
            .into(database.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                pubkey: pubkey,
                createdAt: lastFetched,
                eventId: 'event-$pubkey',
                lastFetched: lastFetched,
              ),
              mode: InsertMode.insertOrReplace,
            );
      }

      const newestPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      test('does nothing when the table is within the cap', () async {
        await insertWithLastFetched(testPubkey, DateTime.now());
        await insertWithLastFetched(testPubkey2, DateTime.now());

        final deleted = await dao.enforceRowCap();

        expect(deleted, equals(0));
        expect(await dao.getAllProfiles(), hasLength(2));
      });

      test(
        'evicts the oldest-by-last_fetched rows beyond the cap',
        () async {
          final now = DateTime.now();
          await insertWithLastFetched(
            testPubkey,
            now.subtract(const Duration(days: 2)),
          );
          await insertWithLastFetched(
            testPubkey2,
            now.subtract(const Duration(days: 1)),
          );
          await insertWithLastFetched(newestPubkey, now);

          final deleted = await dao.enforceRowCap(maxRows: 2);

          expect(deleted, equals(1));
          final remaining = await dao.getAllProfiles();
          expect(
            remaining.map((p) => p.pubkey),
            containsAll([testPubkey2, newestPubkey]),
          );
          expect(
            remaining.map((p) => p.pubkey),
            isNot(contains(testPubkey)),
          );
        },
      );

      test('a profile refreshed after being written stays out of the '
          'eviction set', () async {
        final now = DateTime.now();
        await insertWithLastFetched(
          testPubkey,
          now.subtract(const Duration(days: 5)),
        );
        await insertWithLastFetched(
          testPubkey2,
          now.subtract(const Duration(days: 4)),
        );
        // testPubkey is re-fetched most recently, so its refreshed
        // last_fetched should protect it even though it was originally the
        // oldest row.
        await insertWithLastFetched(testPubkey, now);

        final deleted = await dao.enforceRowCap(maxRows: 1);

        expect(deleted, equals(1));
        final remaining = await dao.getAllProfiles();
        expect(remaining.map((p) => p.pubkey), equals([testPubkey]));
      });
    });

    group('searchProfilesByIdentity', () {
      test(
        'ranks exact identity matches first and excludes biography text',
        () async {
          await dao.upsertProfiles([
            createProfile(
              name: 'alice',
              displayName: 'Exact',
              about: 'unrelated',
            ),
            createProfile(
              pubkey: testPubkey2,
              eventId: 'event2',
              name: 'alice-fan',
              displayName: 'Prefix',
            ),
            createProfile(
              pubkey: 'a' * 64,
              eventId: 'event3',
              name: 'other',
              about: 'alice appears only here',
            ),
          ]);

          // A generous bound so the biography-only row is excluded by the
          // WHERE clause, not merely truncated past the limit.
          final results = await dao.searchProfilesByIdentity(
            'ALICE',
            limit: 10,
          );

          expect(results.map((profile) => profile.displayName), [
            'Exact',
            'Prefix',
          ]);
          expect(
            results.any((profile) => profile.name == 'other'),
            isFalse,
            reason: 'a biography-only match must not be returned',
          );
        },
      );

      test('matches a public key only when the whole key is given', () async {
        await dao.upsertProfiles([
          createProfile(name: 'someone'),
          createProfile(
            pubkey: testPubkey2,
            eventId: 'event2',
            name: 'other',
          ),
        ]);

        final whole = await dao.searchProfilesByIdentity(
          testPubkey2.toUpperCase(),
          limit: 10,
        );
        final prefix = await dao.searchProfilesByIdentity('fedc', limit: 10);

        expect(whole.map((profile) => profile.pubkey), [testPubkey2]);
        expect(prefix, isEmpty);
      });

      test('does not match a hex substring inside a public key', () async {
        await dao.upsertProfiles([
          createProfile(name: 'someone'),
          createProfile(
            pubkey: testPubkey2,
            eventId: 'event2',
            name: 'other',
          ),
        ]);

        final results = await dao.searchProfilesByIdentity('3210', limit: 10);

        expect(results, isEmpty);
      });

      test('honors the requested bound', () async {
        await dao.upsertProfiles([
          createProfile(name: 'match-one'),
          createProfile(
            pubkey: testPubkey2,
            eventId: 'event2',
            name: 'match-two',
          ),
        ]);

        final results = await dao.searchProfilesByIdentity('match', limit: 1);

        expect(results, hasLength(1));
      });
    });

    group('upsertProfiles', () {
      test('does nothing for empty list', () async {
        await dao.upsertProfiles([]);

        final allProfiles = await dao.getAllProfiles();
        expect(allProfiles, isEmpty);
      });

      test('inserts multiple profiles in batch', () async {
        final profiles = [
          createProfile(name: 'Alice'),
          createProfile(pubkey: testPubkey2, name: 'Bob'),
        ];

        await dao.upsertProfiles(profiles);

        final allProfiles = await dao.getAllProfiles();
        expect(allProfiles, hasLength(2));

        final names = allProfiles.map((p) => p.name).toSet();
        expect(names, containsAll(['Alice', 'Bob']));
      });

      test('updates existing profiles on conflict', () async {
        await dao.upsertProfile(
          createProfile(name: 'Alice', displayName: 'Old'),
        );

        await dao.upsertProfiles([
          createProfile(name: 'Alice', displayName: 'New', eventId: 'event2'),
        ]);

        final allProfiles = await dao.getAllProfiles();
        expect(allProfiles, hasLength(1));
        expect(allProfiles.first.displayName, equals('New'));
        expect(allProfiles.first.eventId, equals('event2'));
      });

      test('handles mix of inserts and updates', () async {
        await dao.upsertProfile(createProfile(name: 'Original'));

        await dao.upsertProfiles([
          createProfile(name: 'Updated', eventId: 'event2'),
          createProfile(pubkey: testPubkey2, name: 'New'),
        ]);

        final allProfiles = await dao.getAllProfiles();
        expect(allProfiles, hasLength(2));

        final byPubkey = {for (final p in allProfiles) p.pubkey: p};
        expect(byPubkey[testPubkey]!.name, equals('Updated'));
        expect(byPubkey[testPubkey2]!.name, equals('New'));
      });
    });

    group('vanished pubkeys', () {
      test('upsertProfile does not re-create an evicted profile', () async {
        // The scenario the guard exists for: a relay still serving the
        // deleted account's kind 0 routes it straight to this DAO.
        await database.vanishedProfilesDao.markVanished(testPubkey);

        await dao.upsertProfile(createProfile(name: 'Deleted'));

        expect(await dao.getProfile(testPubkey), isNull);
      });

      test('upsertProfile removes nothing it did not write', () async {
        await dao.upsertProfile(createProfile(name: 'Alice'));
        await database.vanishedProfilesDao.markVanished(testPubkey2);

        await dao.upsertProfile(
          createProfile(pubkey: testPubkey2, name: 'Deleted'),
        );

        expect((await dao.getProfile(testPubkey))!.name, equals('Alice'));
        expect(await dao.getProfile(testPubkey2), isNull);
      });

      test('upsertProfiles drops only the vanished pubkeys', () async {
        await database.vanishedProfilesDao.markVanished(testPubkey2);

        await dao.upsertProfiles([
          createProfile(name: 'Alice'),
          createProfile(pubkey: testPubkey2, name: 'Deleted'),
        ]);

        final allProfiles = await dao.getAllProfiles();
        expect(allProfiles.map((p) => p.pubkey), equals([testPubkey]));
      });

      test('writes resume once the vanish is cleared', () async {
        // Self-heal: a wrong vanish classification must not lock the pubkey
        // out of the cache for the life of the install.
        await database.vanishedProfilesDao.markVanished(testPubkey);
        await dao.upsertProfile(createProfile(name: 'Blocked'));

        await database.vanishedProfilesDao.clearVanished(testPubkey);
        await dao.upsertProfile(createProfile(name: 'Allowed'));

        expect((await dao.getProfile(testPubkey))!.name, equals('Allowed'));
      });
    });

    group('watchProfile', () {
      test(
        'emits when content advances under an unchanged synthetic eventId',
        () async {
          // Funnelcake REST profiles carry a content-independent synthetic
          // eventId (`rest-<pubkey>`), so a newer profile version reuses the
          // same eventId. Dedup on (pubkey, eventId) alone would drop the
          // update; watchProfile must still surface it.
          const syntheticId = 'rest-$testPubkey';
          await dao.upsertProfile(
            createProfile(
              eventId: syntheticId,
              name: 'Old',
              createdAt: DateTime(2024),
            ),
          );

          final names = <String?>[];
          final sub = dao
              .watchProfile(testPubkey)
              .listen((p) => names.add(p?.name));
          addTearDown(sub.cancel);
          await pumpEventQueue();

          await dao.upsertProfile(
            createProfile(
              eventId: syntheticId,
              name: 'New',
              createdAt: DateTime(2024, 1, 2),
            ),
          );
          await pumpEventQueue();

          expect(names, ['Old', 'New']);
        },
      );

      test('collapses identical and unrelated-write re-emissions', () async {
        await dao.upsertProfile(
          createProfile(eventId: 'e1', name: 'A', createdAt: DateTime(2024)),
        );

        final eventIds = <String?>[];
        final sub = dao
            .watchProfile(testPubkey)
            .listen((p) => eventIds.add(p?.eventId));
        addTearDown(sub.cancel);
        await pumpEventQueue();

        // Identical re-write of the same version -> no new emission.
        await dao.upsertProfile(
          createProfile(eventId: 'e1', name: 'A', createdAt: DateTime(2024)),
        );
        // Unrelated profile write -> Drift re-runs this watcher, but the value
        // for testPubkey is unchanged -> the guard drops it.
        await dao.upsertProfile(
          createProfile(pubkey: testPubkey2, eventId: 'other'),
        );
        await pumpEventQueue();

        // Genuine update -> emits.
        await dao.upsertProfile(
          createProfile(
            eventId: 'e2',
            name: 'A2',
            createdAt: DateTime(2024, 1, 2),
          ),
        );
        await pumpEventQueue();

        expect(eventIds, ['e1', 'e2']);
      });
    });
  });
}
