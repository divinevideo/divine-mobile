import 'dart:convert';

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';
import 'package:unique_names_generator/unique_names_generator.dart';

void main() {
  group('UserProfile', () {
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const testEventId =
        'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';
    final testCreatedAt = DateTime.utc(2024);

    group('constructor', () {
      test('creates profile with required fields', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.pubkey, equals(testPubkey));
        expect(profile.rawData, isEmpty);
        expect(profile.createdAt, equals(testCreatedAt));
        expect(profile.eventId, equals(testEventId));
      });

      test('creates profile with all fields', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'custom': 'data'},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'testname',
          displayName: 'Test User',
          about: 'Test bio',
          picture: 'https://example.com/avatar.png',
          banner: 'https://example.com/banner.png',
          website: 'https://example.com',
          nip05: 'test@example.com',
          lud16: 'test@wallet.com',
          lud06: 'lnurl1234',
        );

        expect(profile.name, equals('testname'));
        expect(profile.displayName, equals('Test User'));
        expect(profile.about, equals('Test bio'));
        expect(profile.picture, equals('https://example.com/avatar.png'));
        expect(profile.banner, equals('https://example.com/banner.png'));
        expect(profile.website, equals('https://example.com'));
        expect(profile.nip05, equals('test@example.com'));
        expect(profile.lud16, equals('test@wallet.com'));
        expect(profile.lud06, equals('lnurl1234'));
        expect(profile.createdAt.isUtc, isTrue);
      });
    });

    group('UTF-16 well-formedness at the display boundary (#7295)', () {
      // The bio is the field that had no sanitized display getter, so it
      // reached `TextPainter.layout` raw from the profile header's
      // expand/collapse measurement pass and threw
      // "string is not well-formed UTF-16" out of the paragraph builder.
      test('replaces lone surrogates in every free-text field', () {
        final lone = String.fromCharCode(0xDE00);
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'n$lone',
          displayName: 'd$lone',
          about: 'a$lone',
          picture: 'p$lone',
          banner: 'b$lone',
          website: 'w$lone',
          nip05: 'i$lone',
          lud16: 'l$lone',
          lud06: 'u$lone',
        );

        expect(profile.name, equals('n�'));
        expect(profile.displayName, equals('d�'));
        expect(profile.about, equals('a�'));
        expect(profile.picture, equals('p�'));
        expect(profile.banner, equals('b�'));
        expect(profile.website, equals('w�'));
        expect(profile.nip05, equals('i�'));
        expect(profile.lud16, equals('l�'));
        expect(profile.lud06, equals('u�'));
      });

      test('sanitizes a lone surrogate arriving via fromNostrEvent', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          [],
          jsonEncode({
            'about': 'truncated emoji${String.fromCharCode(0xD83D)}',
            'display_name': 'Bad${String.fromCharCode(0xD83D)}Name',
          }),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.about, equals('truncated emoji�'));
        expect(profile.displayName, equals('Bad�Name'));
      });

      test('sanitizes a lone surrogate arriving via fromJson', () {
        final profile = UserProfile.fromJson({
          'pubkey': testPubkey,
          'event_id': testEventId,
          'created_at': testCreatedAt.millisecondsSinceEpoch,
          'about': 'json${String.fromCharCode(0xDC00)}bio',
        });

        expect(profile.about, equals('json�bio'));
      });

      test('keeps copyWith output well-formed', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        ).copyWith(about: 'copy${String.fromCharCode(0xD83D)}bio');

        expect(profile.about, equals('copy�bio'));
      });

      // Only well-formedness is enforced here. Capping combining marks at
      // construction would rewrite the user's own bio when the profile editor
      // seeds from this model and republishes, so Zalgo stays display-only.
      test('preserves valid emoji and stacked diacritics verbatim', () {
        const bio = 'hi \u{1F600} o\u0300\u0301\u0302\u0303 done';
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          about: bio,
        );

        expect(profile.about, equals(bio));
      });

      // rawData carries the original kind-0 bytes for republishing and must
      // not be rewritten by the display-side normalization.
      test('leaves rawData untouched', () {
        final malformed = 'raw${String.fromCharCode(0xD83D)}';
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: {'about': malformed},
          createdAt: testCreatedAt,
          eventId: testEventId,
          about: malformed,
        );

        expect(profile.rawData['about'], equals(malformed));
        expect(profile.about, equals('raw�'));
      });
    });

    group('fromNostrEvent', () {
      test('parses valid kind 0 event', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          [],
          jsonEncode({
            'name': 'testname',
            'display_name': 'Test User',
            'about': 'Test bio',
            'picture': 'https://example.com/avatar.png',
            'banner': 'https://example.com/banner.png',
            'website': 'https://example.com',
            'nip05': 'test@example.com',
            'lud16': 'test@wallet.com',
            'lud06': 'lnurl1234',
          }),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.pubkey, equals(testPubkey));
        expect(profile.eventId, equals(testEventId));
        expect(profile.name, equals('testname'));
        expect(profile.displayName, equals('Test User'));
        expect(profile.about, equals('Test bio'));
        expect(profile.picture, equals('https://example.com/avatar.png'));
        expect(profile.banner, equals('https://example.com/banner.png'));
        expect(profile.website, equals('https://example.com'));
        expect(profile.nip05, equals('test@example.com'));
        expect(profile.lud16, equals('test@wallet.com'));
        expect(profile.lud06, equals('lnurl1234'));
      });

      test('handles displayName key variations', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          [],
          jsonEncode({'displayName': 'Alt Display Name'}),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.displayName, equals('Alt Display Name'));
      });

      test('prefers display_name over displayName', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          [],
          jsonEncode({
            'display_name': 'Preferred Name',
            'displayName': 'Alt Name',
          }),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.displayName, equals('Preferred Name'));
      });

      test('throws ArgumentError for non-kind-0 events', () {
        final event = Event(
          testPubkey,
          EventKind.textNote,
          [],
          'text note content',
          createdAt: 1704067200,
        );

        expect(
          () => UserProfile.fromNostrEvent(event),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('handles invalid JSON content', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          [],
          'invalid json {',
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.pubkey, equals(testPubkey));
        expect(profile.rawData, isEmpty);
        expect(profile.name, isNull);
        expect(profile.displayName, isNull);
        expect(profile.createdAt.isUtc, isTrue);
      });

      test('preserves rawData', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          [],
          jsonEncode({
            'name': 'Test',
            'custom_field': 'custom_value',
            'nested': {'key': 'value'},
          }),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.rawData['custom_field'], equals('custom_value'));
        expect(profile.rawData['nested'], equals({'key': 'value'}));
      });

      test('preserves event tags as rawTags', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          [
            ['i', 'github:octocat', 'abc123'],
            ['i', 'twitter:elonmusk', 'def456'],
            ['p', 'somepubkey'],
          ],
          jsonEncode({'name': 'alice'}),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.rawTags, hasLength(3));
        expect(
          profile.rawTags.first,
          equals(['i', 'github:octocat', 'abc123']),
        );
        expect(
          profile.rawTags[1],
          equals(['i', 'twitter:elonmusk', 'def456']),
        );
      });

      test('rawTags defaults to empty when JSON content is malformed', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          [
            ['i', 'github:octocat', 'abc'],
          ],
          'not-json',
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        // Malformed JSON falls through to the recovery branch which does not
        // re-emit tags; callers needing tags should source them from a
        // well-formed kind 0 event.
        expect(profile.rawTags, isEmpty);
      });

      test('rawTags is empty when the event has no tags', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          const [],
          jsonEncode({'name': 'alice'}),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.rawTags, isEmpty);
      });

      test('keeps tags out of rawData', () {
        // saveProfileEvent republishes rawData as the next kind 0's content,
        // so a Vine archive import's tag-only metadata must stay a tag.
        final content = {
          'name': 'exampleviner',
          'display_name': 'ExampleViner',
          'nip05': '_@exampleviner.divine.video',
        };
        final event = Event(
          testPubkey,
          EventKind.metadata,
          [
            ['i', 'vine:1111111111111111111'],
            ['vine_user_id', '1111111111111111111'],
            ['vine_username', 'ExampleViner'],
            ['vine_followers', '4213'],
            ['vine_loops', '99871'],
            ['vine_verified', 'true'],
            ['client', 'vine-archive-importer'],
          ],
          jsonEncode(content),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.rawData, equals(content));
      });
    });

    group('fromUserProfileFound', () {
      test(
        'mirrors typed REST fields into rawData so a profile round-trip '
        'through Funnelcake does not silently drop them on the next publish '
        '(#4175)',
        () {
          const result = UserProfileFound(
            profile: UserProfileData(
              pubkey: testPubkey,
              name: 'alice',
              displayName: 'Alice',
              about: 'A bio',
              picture: 'https://example.com/p.png',
              banner: 'https://example.com/b.png',
              website: 'https://alice.example',
              nip05: 'alice@example.com',
              lud16: 'alice@strike.me',
            ),
          );

          final profile = UserProfile.fromUserProfileFound(result);

          expect(profile.rawData, {
            'name': 'alice',
            'display_name': 'Alice',
            'about': 'A bio',
            'picture': 'https://example.com/p.png',
            'banner': 'https://example.com/b.png',
            'website': 'https://alice.example',
            'nip05': 'alice@example.com',
            'lud16': 'alice@strike.me',
          });
        },
      );

      test('omits null typed fields from rawData', () {
        const result = UserProfileFound(
          profile: UserProfileData(
            pubkey: testPubkey,
            displayName: 'Alice',
            // every other field null
          ),
        );

        final profile = UserProfile.fromUserProfileFound(result);

        expect(profile.rawData, equals({'display_name': 'Alice'}));
        expect(profile.rawData.containsKey('lud16'), isFalse);
        expect(profile.rawData.containsKey('website'), isFalse);
      });

      test('uses the original Kind 0 timestamp when Funnelcake provides '
          'one (#3141)', () {
        final original = DateTime.utc(2023, 11, 14, 22, 13, 20);
        final result = UserProfileFound(
          profile: UserProfileData(
            pubkey: testPubkey,
            displayName: 'Alice',
            createdAt: original,
          ),
        );

        final profile = UserProfile.fromUserProfileFound(result);

        expect(profile.createdAt, equals(original));
      });

      test('falls back to DateTime.now() when no timestamp is provided', () {
        const result = UserProfileFound(
          profile: UserProfileData(pubkey: testPubkey, displayName: 'Alice'),
        );

        final before = DateTime.now();
        final profile = UserProfile.fromUserProfileFound(result);
        final after = DateTime.now();

        expect(
          profile.createdAt.isBefore(before),
          isFalse,
          reason: 'synthetic timestamp should be >= before',
        );
        expect(
          profile.createdAt.isAfter(after),
          isFalse,
          reason: 'synthetic timestamp should be <= after',
        );
      });
    });

    group('fromJson', () {
      test('parses JSON correctly', () {
        final json = {
          'pubkey': testPubkey,
          'name': 'testname',
          'display_name': 'Test User',
          'about': 'Test bio',
          'picture': 'https://example.com/avatar.png',
          'banner': 'https://example.com/banner.png',
          'website': 'https://example.com',
          'nip05': 'test@example.com',
          'lud16': 'test@wallet.com',
          'lud06': 'lnurl1234',
          'raw_data': {'custom': 'data'},
          'created_at': testCreatedAt.millisecondsSinceEpoch,
          'event_id': testEventId,
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.pubkey, equals(testPubkey));
        expect(profile.name, equals('testname'));
        expect(profile.displayName, equals('Test User'));
        expect(profile.about, equals('Test bio'));
        expect(profile.picture, equals('https://example.com/avatar.png'));
        expect(profile.rawData, equals({'custom': 'data'}));
        expect(profile.createdAt, equals(testCreatedAt));
        expect(profile.eventId, equals(testEventId));
      });

      test('handles missing raw_data', () {
        final json = {
          'pubkey': testPubkey,
          'created_at': testCreatedAt.millisecondsSinceEpoch,
          'event_id': testEventId,
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.rawData, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          name: 'testname',
          displayName: 'Test User',
          about: 'Test bio',
          picture: 'https://example.com/avatar.png',
          banner: 'https://example.com/banner.png',
          website: 'https://example.com',
          nip05: 'test@example.com',
          lud16: 'test@wallet.com',
          lud06: 'lnurl1234',
          rawData: const {'custom': 'data'},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final json = profile.toJson();

        expect(json['pubkey'], equals(testPubkey));
        expect(json['name'], equals('testname'));
        expect(json['display_name'], equals('Test User'));
        expect(json['about'], equals('Test bio'));
        expect(json['picture'], equals('https://example.com/avatar.png'));
        expect(json['banner'], equals('https://example.com/banner.png'));
        expect(json['website'], equals('https://example.com'));
        expect(json['nip05'], equals('test@example.com'));
        expect(json['lud16'], equals('test@wallet.com'));
        expect(json['lud06'], equals('lnurl1234'));
        expect(json['raw_data'], equals({'custom': 'data'}));
        expect(
          json['created_at'],
          equals(testCreatedAt.millisecondsSinceEpoch),
        );
        expect(json['event_id'], equals(testEventId));
      });

      test('round-trips correctly', () {
        final original = UserProfile(
          pubkey: testPubkey,
          name: 'testname',
          displayName: 'Test User',
          about: 'Test bio',
          picture: 'https://example.com/avatar.png',
          rawData: const {'custom': 'data'},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final json = original.toJson();
        final restored = UserProfile.fromJson(json);

        expect(restored.pubkey, equals(original.pubkey));
        expect(restored.name, equals(original.name));
        expect(restored.displayName, equals(original.displayName));
        expect(restored.about, equals(original.about));
        expect(restored.picture, equals(original.picture));
        expect(restored.rawData, equals(original.rawData));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.eventId, equals(original.eventId));
      });
    });

    group('bestDisplayName', () {
      test('returns displayName when available', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: 'Display Name',
          name: 'username',
        );

        expect(profile.bestDisplayName, equals('Display Name'));
      });

      test('falls back to name when displayName is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'username',
        );

        expect(profile.bestDisplayName, equals('username'));
      });

      test('falls back to name when displayName is empty', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: '',
          name: 'username',
        );

        expect(profile.bestDisplayName, equals('username'));
      });

      test('falls back to generated name when no names available', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.bestDisplayName, equals('Integral Cicada 66'));
      });

      test('returns generated name for short pubkey', () {
        const shortPubkey = 'short123';
        final profile = UserProfile(
          pubkey: shortPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.bestDisplayName, equals('Olympic Rodent 91'));
      });

      test('generated name is deterministic for same pubkey', () {
        final profile1 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );
        final profile2 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: DateTime(2025),
          eventId:
              'different_event_id_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        );

        expect(profile1.bestDisplayName, equals(profile2.bestDisplayName));
      });

      test('strips zalgo combining marks from displayName', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: 'A\u0300\u0301\u0302\u0303\u0304',
          name: 'username',
        );

        expect(profile.bestDisplayName, equals('A\u0300\u0301'));
      });

      test('strips zalgo combining marks from name fallback', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'B\u0300\u0301\u0302\u0303',
        );

        expect(profile.bestDisplayName, equals('B\u0300\u0301'));
      });

      test('replaces unpaired surrogates in displayName', () {
        // A lone surrogate in a display name crashes Flutter's
        // paragraph builder if it reaches a Text widget (#6111).
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: String.fromCharCodes([0x68, 0x69, 0xD83D]),
        );

        expect(profile.bestDisplayName, equals('hi\uFFFD'));
      });
    });

    group('betterDisplayName', () {
      test('strips zalgo from displayName', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: 'X\u0300\u0301\u0302\u0303',
        );

        expect(profile.betterDisplayName(null), equals('X\u0300\u0301'));
      });

      test('strips zalgo from name fallback', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'Y\u0300\u0301\u0302\u0303',
        );

        expect(profile.betterDisplayName(null), equals('Y\u0300\u0301'));
      });
    });

    group('generatedNameFor', () {
      test('returns pinned output for testPubkey', () {
        expect(
          UserProfile.generatedNameFor(testPubkey),
          equals('Integral Cicada 66'),
        );
      });

      test('returns pinned output for issue #2979 example pubkey', () {
        // Hex pubkey from the issue report (npub1488afm…).
        // Full npub: npub1488afme74urmveua85xkkyxc83c
        // 608qtgg2ncmth4f2npvjgw8lqehxguh
        const issuePubkey =
            '89ef92b9ebe6dc1e4ea398f6477f227e95429627b0a33dc89b640e137b256be5';
        expect(
          UserProfile.generatedNameFor(issuePubkey),
          equals('Possible Mandrill 76'),
        );
      });

      test('output matches expected format', () {
        final name = UserProfile.generatedNameFor(testPubkey);
        // Format: "Adjective Animal N" where N is 1–99.
        expect(name, matches(RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+ \d{1,2}$')));
      });

      test('is deterministic across calls', () {
        const pubkey =
            'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';
        final first = UserProfile.generatedNameFor(pubkey);
        final second = UserProfile.generatedNameFor(pubkey);
        expect(first, equals(second));
      });

      test('different pubkeys produce different names', () {
        const pubkeyA =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const pubkeyB =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        expect(
          UserProfile.generatedNameFor(pubkeyA),
          isNot(equals(UserProfile.generatedNameFor(pubkeyB))),
        );
      });

      test('word list sizes are stable', () {
        // Guard against silent changes from unique_names_generator updates.
        // If these fail, the package changed its dictionaries and every
        // anonymous user's generated name may have shifted.
        expect(adjectives.length, equals(1202));
        expect(animals.length, equals(354));
      });

      test('handles single-character pubkey', () {
        final name = UserProfile.generatedNameFor('a');
        expect(name, matches(RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+ \d{1,2}$')));
      });

      test('handles numeric-only pubkey', () {
        final name = UserProfile.generatedNameFor('1234567890');
        expect(name, matches(RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+ \d{1,2}$')));
      });
    });

    group('handle', () {
      test('returns @nip05 when nip05 is available', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'alice@example.com',
          name: 'alice',
        );

        expect(profile.handle, equals('@alice@example.com'));
      });

      test('falls back to @name when nip05 is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'alice',
        );

        expect(profile.handle, equals('@alice'));
      });

      test('falls back to @name when nip05 is empty', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '',
          name: 'alice',
        );

        expect(profile.handle, equals('@alice'));
      });

      test('returns empty string when neither nip05 nor name is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.handle, isEmpty);
      });

      test('strips .divine.video suffix for subdomain format', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '_@rabble.divine.video',
        );

        expect(profile.handle, equals('@rabble'));
      });

      test('strips divine.video suffix for legacy format', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'rabble@divine.video',
        );

        expect(profile.handle, equals('@rabble'));
      });

      // An unpaired surrogate reaches the paragraph builder through every
      // surface that renders a handle and throws during layout, so the
      // getter sanitizes like its [bestDisplayName] sibling.
      test('replaces an unpaired UTF-16 surrogate in name', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'ca${String.fromCharCode(0xD83D)}sey',
        );

        expect(profile.handle, equals('@ca�sey'));
      });

      test('replaces an unpaired UTF-16 surrogate in nip05', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'ca${String.fromCharCode(0xDE00)}sey@example.com',
        );

        expect(profile.handle, equals('@ca�sey@example.com'));
      });

      test('keeps a valid surrogate pair intact', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'casey 😀',
        );

        expect(profile.handle, equals('@casey 😀'));
      });
    });

    group('computed properties', () {
      test('shortPubkey returns full pubkey', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.shortPubkey, equals(testPubkey));
      });

      test('hasBasicInfo returns true when name is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'testname',
        );

        expect(profile.hasBasicInfo, isTrue);
      });

      test('hasBasicInfo returns true when displayName is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: 'Display Name',
        );

        expect(profile.hasBasicInfo, isTrue);
      });

      test('hasBasicInfo returns true when picture is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          picture: 'https://example.com/avatar.png',
        );

        expect(profile.hasBasicInfo, isTrue);
      });

      test('hasBasicInfo returns false when nothing is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasBasicInfo, isFalse);
      });

      test('hasAvatar returns true when picture is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          picture: 'https://example.com/avatar.png',
        );

        expect(profile.hasAvatar, isTrue);
      });

      test('hasAvatar returns false when picture is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasAvatar, isFalse);
      });

      test('hasAvatar returns false when picture is empty', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          picture: '',
        );

        expect(profile.hasAvatar, isFalse);
      });

      test('hasBio returns true when about is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          about: 'Test bio',
        );

        expect(profile.hasBio, isTrue);
      });

      test('hasBio returns false when about is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasBio, isFalse);
      });

      test('hasNip05 returns true when nip05 is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'test@example.com',
        );

        expect(profile.hasNip05, isTrue);
      });

      test('hasNip05 returns false when nip05 is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasNip05, isFalse);
      });

      test('hasLightning returns true when lud16 is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          lud16: 'test@wallet.com',
        );

        expect(profile.hasLightning, isTrue);
      });

      test('hasLightning returns true when lud06 is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          lud06: 'lnurl1234',
        );

        expect(profile.hasLightning, isTrue);
      });

      test('hasLightning returns false when neither is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasLightning, isFalse);
      });

      test('lightningAddress prefers lud16', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          lud16: 'test@wallet.com',
          lud06: 'lnurl1234',
        );

        expect(profile.lightningAddress, equals('test@wallet.com'));
      });

      test('lightningAddress falls back to lud06', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          lud06: 'lnurl1234',
        );

        expect(profile.lightningAddress, equals('lnurl1234'));
      });

      test('lightningAddress returns null when neither is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.lightningAddress, isNull);
      });
    });

    group('location', () {
      test('returns value from rawData', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'location': 'New York'},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.location, equals('New York'));
      });
    });

    group('displayNip05', () {
      test('returns @user.divine.video for subdomain format', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '_@alice.divine.video',
        );

        expect(profile.displayNip05, equals('@alice.divine.video'));
      });

      test('normalises legacy user@divine.video to @user.divine.video', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'heybob@divine.video',
        );

        expect(profile.displayNip05, equals('@heybob.divine.video'));
      });

      test('normalises legacy user@openvine.co to @user.divine.video', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'charlie@openvine.co',
        );

        expect(profile.displayNip05, equals('@charlie.divine.video'));
      });

      test('preserves external NIP-05 unchanged', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'alice@example.com',
        );

        expect(profile.displayNip05, equals('alice@example.com'));
      });

      test('returns null when nip05 is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.displayNip05, isNull);
      });

      test('returns null when nip05 is empty', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '',
        );

        expect(profile.displayNip05, isNull);
      });

      test('replaces an unpaired UTF-16 surrogate in an external nip05', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'al${String.fromCharCode(0xDE00)}ice@example.com',
        );

        expect(profile.displayNip05, equals('al�ice@example.com'));
      });
    });

    group('shortDisplayNip05', () {
      test('returns @user (no suffix) for subdomain format', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '_@alice.divine.video',
        );

        expect(profile.shortDisplayNip05, equals('@alice'));
      });

      test('returns @user (no suffix) for legacy user@divine.video', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'heybob@divine.video',
        );

        expect(profile.shortDisplayNip05, equals('@heybob'));
      });

      test('returns @user (no suffix) for legacy user@openvine.co', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'charlie@openvine.co',
        );

        expect(profile.shortDisplayNip05, equals('@charlie'));
      });

      test('preserves external NIP-05 unchanged', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'alice@example.com',
        );

        expect(profile.shortDisplayNip05, equals('alice@example.com'));
      });

      test('returns null when nip05 is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.shortDisplayNip05, isNull);
      });

      test('returns null when nip05 is empty', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '',
        );

        expect(profile.shortDisplayNip05, isNull);
      });

      test('replaces an unpaired UTF-16 surrogate in an external nip05', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'al${String.fromCharCode(0xD83D)}ice@example.com',
        );

        expect(profile.shortDisplayNip05, equals('al�ice@example.com'));
      });
    });

    group('divineUsername', () {
      test('extracts username from subdomain format _@user.divine.video', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '_@alice.divine.video',
        );

        expect(profile.divineUsername, equals('alice'));
      });

      test('extracts username from legacy format user@divine.video', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'bob@divine.video',
        );

        expect(profile.divineUsername, equals('bob'));
      });

      test('extracts username from legacy format user@openvine.co', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'charlie@openvine.co',
        );

        expect(profile.divineUsername, equals('charlie'));
      });

      test('returns null for non-divine NIP-05', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'user@example.com',
        );

        expect(profile.divineUsername, isNull);
      });

      test('returns null when nip05 is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.divineUsername, isNull);
      });

      test('returns null when nip05 is empty', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '',
        );

        expect(profile.divineUsername, isNull);
      });
    });

    group('hasExternalNip05', () {
      test('returns false for subdomain format _@user.divine.video', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '_@alice.divine.video',
        );

        expect(profile.hasExternalNip05, isFalse);
      });

      test('returns false for legacy format user@divine.video', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'bob@divine.video',
        );

        expect(profile.hasExternalNip05, isFalse);
      });

      test('returns false for legacy format user@openvine.co', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'charlie@openvine.co',
        );

        expect(profile.hasExternalNip05, isFalse);
      });

      test('returns true for external NIP-05 user@example.com', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'alice@example.com',
        );

        expect(profile.hasExternalNip05, isTrue);
      });

      test('returns true for root user _@example.com', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '_@example.com',
        );

        expect(profile.hasExternalNip05, isTrue);
      });

      test('returns false when nip05 is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasExternalNip05, isFalse);
      });

      test('returns false when nip05 is empty', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '',
        );

        expect(profile.hasExternalNip05, isFalse);
      });
    });

    group('externalNip05', () {
      test('returns raw nip05 for external identifier', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'alice@example.com',
        );

        expect(profile.externalNip05, equals('alice@example.com'));
      });

      test('returns null for divine.video nip05', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '_@alice.divine.video',
        );

        expect(profile.externalNip05, isNull);
      });

      test('returns null when nip05 is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.externalNip05, isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'original',
          displayName: 'Original Name',
        );

        final copy = original.copyWith(
          displayName: 'Updated Name',
          about: 'New bio',
        );

        expect(copy.pubkey, equals(testPubkey));
        expect(copy.name, equals('original'));
        expect(copy.displayName, equals('Updated Name'));
        expect(copy.about, equals('New bio'));
        expect(copy.createdAt, equals(testCreatedAt));
        expect(copy.eventId, equals(testEventId));
      });

      test('preserves original values when not specified', () {
        final original = UserProfile(
          pubkey: testPubkey,
          rawData: const {'custom': 'data'},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'testname',
          displayName: 'Test User',
          about: 'Test bio',
          picture: 'https://example.com/avatar.png',
        );

        final copy = original.copyWith(name: 'newname');

        expect(copy.name, equals('newname'));
        expect(copy.displayName, equals('Test User'));
        expect(copy.about, equals('Test bio'));
        expect(copy.picture, equals('https://example.com/avatar.png'));
        expect(copy.rawData, equals({'custom': 'data'}));
      });
    });

    group('equality', () {
      test('profiles with same pubkey and eventId are equal', () {
        final profile1 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'name1',
        );

        final profile2 = UserProfile(
          pubkey: testPubkey,
          rawData: const {'other': 'data'},
          createdAt: DateTime(2025),
          eventId: testEventId,
          name: 'name2',
        );

        expect(profile1, equals(profile2));
      });

      test('profiles with different pubkeys are not equal', () {
        final profile1 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final profile2 = UserProfile(
          pubkey: 'different_pubkey',
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile1, isNot(equals(profile2)));
      });

      test('profiles with different eventIds are not equal', () {
        final profile1 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final profile2 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: 'different_event_id',
        );

        expect(profile1, isNot(equals(profile2)));
      });

      test('hashCode is consistent with equality', () {
        final profile1 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final profile2 = UserProfile(
          pubkey: testPubkey,
          rawData: const {'different': 'data'},
          createdAt: DateTime(2025),
          eventId: testEventId,
        );

        expect(profile1.hashCode, equals(profile2.hashCode));
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: 'Test User',
          picture: 'https://example.com/avatar.png',
        );

        final result = profile.toString();

        expect(result, contains('UserProfile'));
        expect(result, contains(testPubkey));
        expect(result, contains('Test User'));
        expect(result, contains('hasAvatar: true'));
      });
    });
  });
}
