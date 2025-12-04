// ABOUTME: Unit tests for UserProfilesDao with UserProfile domain model.
// ABOUTME: Tests upsertProfile for inserting and updating user profiles.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

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

    database = AppDatabase.test(tempDbPath);
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
  });
}
