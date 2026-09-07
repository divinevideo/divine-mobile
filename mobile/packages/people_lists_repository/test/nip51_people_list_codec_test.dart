// ABOUTME: Tests for Nip51PeopleListCodec encoding and decoding.
// ABOUTME: Covers kind 30000 follow-set tags, block-list filtering, pubkeys.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/src/nip51_people_list_codec.dart';
import 'package:test/test.dart';

void main() {
  group(Nip51PeopleListCodec, () {
    const ownerPubkey =
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
    const memberPubkeyA =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const memberPubkeyB =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

    group('encode', () {
      test('edits members over the complete source event', () {
        final list = UserList(
          id: 'punk-friends',
          name: 'Punk Friends',
          pubkeys: const [memberPubkeyA, memberPubkeyB],
          createdAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
        );
        const ciphertext = 'nip44-ciphertext-written-by-another-client';

        final payload = Nip51PeopleListCodec.encode(
          list,
          sourceTags: const [
            ['d', 'punk-friends', 'extra-position'],
            ['alt', 'Follow set'],
            ['p', memberPubkeyA, 'wss://relay.example', 'friend'],
            ['p', memberPubkeyA, 'wss://backup.example'],
            ['t', 'nostr'],
          ],
          sourceContent: ciphertext,
        );

        expect(payload.tags, const [
          ['d', 'punk-friends', 'extra-position'],
          ['alt', 'Follow set'],
          ['p', memberPubkeyA, 'wss://relay.example', 'friend'],
          ['p', memberPubkeyA, 'wss://backup.example'],
          ['t', 'nostr'],
          ['p', memberPubkeyB],
        ]);
        expect(payload.content, ciphertext);
      });

      test('removes every source tag for a removed member', () {
        final list = UserList(
          id: 'punk-friends',
          name: 'Punk Friends',
          pubkeys: const [memberPubkeyB],
          createdAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
        );

        final payload = Nip51PeopleListCodec.encode(
          list,
          sourceTags: const [
            ['d', 'punk-friends'],
            ['p', memberPubkeyA, 'wss://relay.example'],
            ['p', memberPubkeyA, 'wss://backup.example'],
            ['p', memberPubkeyB, 'wss://relay.example'],
          ],
          sourceContent: '',
        );

        expect(payload.tags, const [
          ['d', 'punk-friends'],
          ['p', memberPubkeyB, 'wss://relay.example'],
        ]);
      });

      test('rejects a source for a different addressable list', () {
        final list = UserList(
          id: 'punk-friends',
          name: 'Punk Friends',
          pubkeys: const [memberPubkeyA],
          createdAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
        );

        expect(
          () => Nip51PeopleListCodec.encode(
            list,
            sourceTags: const [
              ['d', 'some-other-list'],
              ['p', memberPubkeyA],
            ],
            sourceContent: '',
          ),
          throwsArgumentError,
        );
      });

      test('creates a kind 30000 follow set with all optional tags', () {
        final list = UserList(
          id: 'punk-friends',
          name: 'Punk Friends',
          description: 'people from the early crew',
          imageUrl: 'https://example.com/list.png',
          pubkeys: const [memberPubkeyA, memberPubkeyB],
          createdAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
        );

        final payload = Nip51PeopleListCodec.encode(list);

        expect(payload.kind, equals(30000));
        expect(payload.content, isEmpty);
        expect(
          payload.tags,
          containsAll(<List<String>>[
            const ['d', 'punk-friends'],
            const ['title', 'Punk Friends'],
            const ['description', 'people from the early crew'],
            const ['image', 'https://example.com/list.png'],
          ]),
        );
        final pTagValues = payload.tags
            .where((tag) => tag.isNotEmpty && tag.first == 'p')
            .map((tag) => tag[1])
            .toList();
        expect(pTagValues, equals(list.pubkeys));
      });

      test('omits description and image when empty or whitespace', () {
        final list = UserList(
          id: 'no-extras',
          name: 'No Extras',
          description: '   ',
          imageUrl: '',
          pubkeys: const [memberPubkeyA],
          createdAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
        );

        final payload = Nip51PeopleListCodec.encode(list);

        final tagNames = payload.tags.map((tag) => tag.first).toList();
        expect(tagNames, isNot(contains('description')));
        expect(tagNames, isNot(contains('image')));
      });

      test('emits exactly one p tag per full pubkey', () {
        final list = UserList(
          id: 'two-members',
          name: 'Two Members',
          pubkeys: const [memberPubkeyA, memberPubkeyB],
          createdAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
        );

        final payload = Nip51PeopleListCodec.encode(list);
        final pTags = payload.tags
            .where((tag) => tag.isNotEmpty && tag.first == 'p')
            .toList();

        expect(pTags, hasLength(2));
        expect(pTags[0][1], equals(memberPubkeyA));
        expect(pTags[1][1], equals(memberPubkeyB));
      });
    });

    group('decode', () {
      test('parses a kind 30000 event into a UserList', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'punk-friends'],
            ['title', 'Punk Friends'],
            ['description', 'people from the early crew'],
            ['image', 'https://example.com/list.png'],
            ['p', memberPubkeyA],
            ['p', memberPubkeyB],
          ],
          '',
          createdAt: 1710000000,
        );

        final decoded = Nip51PeopleListCodec.decode(event);

        expect(decoded, isNotNull);
        expect(decoded!.id, equals('punk-friends'));
        expect(decoded.name, equals('Punk Friends'));
        expect(decoded.description, equals('people from the early crew'));
        expect(decoded.imageUrl, equals('https://example.com/list.png'));
        expect(decoded.pubkeys, equals([memberPubkeyA, memberPubkeyB]));
        expect(
          decoded.createdAt,
          equals(
            DateTime.fromMillisecondsSinceEpoch(1710000000 * 1000, isUtc: true),
          ),
        );
      });

      test('prefers title over d when both are present', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'punk-friends'],
            ['title', 'Punk Friends'],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        expect(
          Nip51PeopleListCodec.decode(event)!.name,
          equals('Punk Friends'),
        );
      });

      test('falls back to d when title is missing', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'punk-friends'],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        expect(
          Nip51PeopleListCodec.decode(event)!.name,
          equals('punk-friends'),
        );
      });

      test('returns null when d tag is missing', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['title', 'Nameless'],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        expect(Nip51PeopleListCodec.decode(event), isNull);
      });

      test('returns null for the app block-list kind 30000 event', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'block'],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        expect(Nip51PeopleListCodec.decode(event), isNull);
      });

      test('returns null for the app notify-list kind 30000 event', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'notify'],
            ['title', 'Notify'],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        expect(Nip51PeopleListCodec.decode(event), isNull);
      });

      test('decodeReservedMembers reads members of the notify list', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'notify'],
            ['p', memberPubkeyA],
            ['p', memberPubkeyB],
          ],
          '',
          createdAt: 1710000000,
        );

        expect(
          Nip51PeopleListCodec.decodeReservedMembers(event, dTag: 'notify'),
          equals([memberPubkeyA, memberPubkeyB]),
        );
      });

      test('decodeReservedMembers distinguishes empty from absent', () {
        final emptyList = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'notify'],
          ],
          '',
          createdAt: 1710000000,
        );
        final otherList = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'block'],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        expect(
          Nip51PeopleListCodec.decodeReservedMembers(emptyList, dTag: 'notify'),
          isEmpty,
        );
        expect(
          Nip51PeopleListCodec.decodeReservedMembers(otherList, dTag: 'notify'),
          isNull,
        );
      });

      test('encodeReserved round-trips through decodeReservedMembers', () {
        final payload = Nip51PeopleListCodec.encodeReserved(
          dTag: Nip51PeopleListCodec.notifyDTag,
          title: 'Notify',
          pubkeys: [memberPubkeyA, memberPubkeyB],
        );
        final event = Event(
          ownerPubkey,
          payload.kind,
          payload.tags,
          payload.content,
          createdAt: 1710000000,
        );

        expect(
          Nip51PeopleListCodec.decodeReservedMembers(
            event,
            dTag: Nip51PeopleListCodec.notifyDTag,
          ),
          equals([memberPubkeyA, memberPubkeyB]),
        );
        // Must stay invisible to the user-facing list collection.
        expect(Nip51PeopleListCodec.decode(event), isNull);
      });

      test('returns null for non kind 30000 events', () {
        final event = Event(
          ownerPubkey,
          30001,
          const [
            ['d', 'punk-friends'],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        expect(Nip51PeopleListCodec.decode(event), isNull);
      });

      test('preserves full 64-char pubkeys without truncating', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'full-pubkeys'],
            ['p', memberPubkeyA],
            ['p', memberPubkeyB],
          ],
          '',
          createdAt: 1710000000,
        );

        final decoded = Nip51PeopleListCodec.decode(event)!;

        expect(decoded.pubkeys[0], equals(memberPubkeyA));
        expect(decoded.pubkeys[0], hasLength(64));
        expect(decoded.pubkeys[1], equals(memberPubkeyB));
        expect(decoded.pubkeys[1], hasLength(64));
      });

      test('skips p tags with empty pubkey values', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'mixed-p-tags'],
            ['p', ''],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        final decoded = Nip51PeopleListCodec.decode(event)!;
        expect(decoded.pubkeys, equals([memberPubkeyA]));
      });

      test('populates nostrEventId from the event id when non-empty', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'with-id'],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        final decoded = Nip51PeopleListCodec.decode(event)!;
        expect(decoded.nostrEventId, equals(event.id));
        expect(decoded.nostrEventId, isNotEmpty);
      });

      test('sets updatedAt to a UTC DateTime derived from createdAt', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'utc-check'],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        final decoded = Nip51PeopleListCodec.decode(event)!;

        expect(decoded.updatedAt.isUtc, isTrue);
        expect(
          decoded.updatedAt,
          equals(
            DateTime.fromMillisecondsSinceEpoch(1710000000 * 1000, isUtc: true),
          ),
        );
      });

      test('sets createdAt to a UTC DateTime derived from createdAt', () {
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'utc-created'],
            ['p', memberPubkeyA],
          ],
          '',
          createdAt: 1710000000,
        );

        final decoded = Nip51PeopleListCodec.decode(event)!;

        expect(decoded.createdAt.isUtc, isTrue);
      });

      test('returns a UserList with empty pubkeys when no p tags present', () {
        // The codec itself does not filter by membership — empty
        // member lists decode to a `UserList` with `pubkeys: []`.
        // Callers (e.g. public search) are responsible for rejecting
        // these when empty lists are not a meaningful result.
        final event = Event(
          ownerPubkey,
          30000,
          const [
            ['d', 'no-members'],
            ['title', 'No Members'],
          ],
          '',
          createdAt: 1710000000,
        );

        final decoded = Nip51PeopleListCodec.decode(event);

        expect(decoded, isNotNull);
        expect(decoded!.pubkeys, isEmpty);
      });
    });
  });
}
