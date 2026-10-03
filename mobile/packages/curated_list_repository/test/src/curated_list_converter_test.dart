import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, NIP44V2;
import 'package:test/test.dart';

/// 64-char hex pubkey for test events.
const _testPubkey =
    'aabbccddaabbccddaabbccddaabbccdd'
    'aabbccddaabbccddaabbccddaabbccdd';
final String _sealedPayload = base64Encode([
  2,
  ...List<int>.filled(32, 0),
  ...NIP44V2.pad('private items'),
  ...List<int>.filled(32, 0),
]);

/// Creates a kind 30005 Nostr event with the given [tags] and [content].
Event _makeEvent({
  List<List<String>> tags = const [],
  String content = '',
  int? createdAt,
}) {
  return Event(
    _testPubkey,
    30005,
    tags.map(List<String>.from).toList(),
    content,
    createdAt: createdAt ?? 1718400000,
  );
}

void main() {
  group(CuratedListConverter, () {
    group('latestRevisions', () {
      test('keeps authors separate and ignores events without a d-tag', () {
        final older = _makeEvent(
          tags: [
            ['d', 'shared'],
          ],
          createdAt: 1,
        );
        final newer = _makeEvent(
          tags: [
            ['d', 'shared'],
          ],
          createdAt: 2,
        );
        final foreign = Event(
          'b' * 64,
          30005,
          [
            ['d', 'shared'],
          ],
          '',
          createdAt: 1,
        );
        final results = CuratedListConverter.latestRevisions([
          _makeEvent(),
          older,
          foreign,
          newer,
          older,
        ]);
        expect(results, [newer, foreign]);
      });

      test('equal timestamps select the lowest event ID in either order', () {
        final first = _makeEvent(
          tags: [
            ['d', 'shared'],
          ],
          content: 'one',
        );
        final second = _makeEvent(
          tags: [
            ['d', 'shared'],
          ],
          content: 'two',
        );
        final winner = first.id.compareTo(second.id) < 0 ? first : second;
        expect(CuratedListConverter.latestRevisions([first, second]), [winner]);
        expect(CuratedListConverter.latestRevisions([second, first]), [winner]);
      });
    });

    group('fromEvent', () {
      test('returns null when d-tag is missing', () {
        final event = _makeEvent(
          tags: [
            ['title', 'No D Tag'],
          ],
        );

        expect(CuratedListConverter.fromEvent(event), isNull);
      });

      test('parses minimal event with only d-tag', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event);

        expect(list, isNotNull);
        expect(list!.id, equals('my-list'));
        expect(list.pubkey, equals(_testPubkey));
        expect(list.name, equals('Untitled List'));
        expect(list.videoEventIds, isEmpty);
        expect(list.isPublic, isTrue);
        expect(list.playOrder, equals(PlayOrder.chronological));
      });

      test('normalizes Nostr timestamps to UTC', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
          createdAt: 1718400000,
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.createdAt.isUtc, isTrue);
        expect(list.updatedAt.isUtc, isTrue);
      });

      test('uses title tag for name', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['title', 'My Favorites'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.name, equals('My Favorites'));
      });

      test('falls back to content first line when title is absent', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
          content: 'Content Title\nMore content here',
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.name, equals('Content Title'));
      });

      test('parses description and image tags', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['title', 'Test'],
            ['description', 'A great list of videos'],
            ['image', 'https://example.com/cover.jpg'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.description, equals('A great list of videos'));
        expect(list.imageUrl, equals('https://example.com/cover.jpg'));
      });

      test('falls back to content for description when tag is absent', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['title', 'Test'],
          ],
          content: 'Fallback description',
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.description, equals('Fallback description'));
      });

      test('does not expose sealed content as name or description', () {
        final event = _makeEvent(
          tags: [
            ['d', 'private-list'],
          ],
          content: _sealedPayload,
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.name, equals('Untitled List'));
        expect(list.description, isNull);
        expect(list.isPublic, isFalse);
      });

      test('uses public metadata when sealed content is unreadable', () {
        final event = _makeEvent(
          tags: [
            ['d', 'private-list'],
            ['title', 'Private List'],
            ['description', 'Private description'],
          ],
          content: _sealedPayload,
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.name, equals('Private List'));
        expect(list.description, equals('Private description'));
        expect(list.isPublic, isFalse);
      });

      test('parses e-tags as video event IDs', () {
        const id1 =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const id2 =
            '2222222222222222222222222222222222222222222222222222222222222222';

        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['e', id1],
            ['e', id2],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.videoEventIds, equals([id1, id2]));
      });

      test('parses a-tags with NIP-71 video kinds', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['a', '34235:pubkey123:horizontal-video'],
            ['a', '34236:pubkey456:vertical-video'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.videoEventIds, hasLength(2));
        expect(
          list.videoEventIds,
          contains('34235:pubkey123:horizontal-video'),
        );
        expect(list.videoEventIds, contains('34236:pubkey456:vertical-video'));
      });

      test('ignores a-tags with non-video kinds', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['a', '30023:pubkey123:some-article'],
            ['a', '34236:pubkey456:actual-video'],
            ['a', '34237:pubkey789:not-a-nip71-video'],
            ['a', '1:pubkey789:text-note'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.videoEventIds, hasLength(1));
        expect(
          list.videoEventIds.first,
          equals('34236:pubkey456:actual-video'),
        );
      });

      test('parses collaborative settings', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['collaborative', 'true'],
            ['collaborator', 'pubkey_alice'],
            ['collaborator', 'pubkey_bob'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.isCollaborative, isTrue);
        expect(
          list.allowedCollaborators,
          equals(['pubkey_alice', 'pubkey_bob']),
        );
      });

      test('parses t-tags and thumbnail', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['t', 'music'],
            ['t', 'dance'],
            ['thumbnail', 'thumb-event-id'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.tags, equals(['music', 'dance']));
        expect(list.thumbnailEventId, equals('thumb-event-id'));
      });

      test('parses playorder tag', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['playorder', 'reverse'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.playOrder, equals(PlayOrder.reverse));
      });

      test('defaults playorder to chronological when absent', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.playOrder, equals(PlayOrder.chronological));
      });

      test('skips tags with insufficient elements', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['title'], // missing value
            ['e'], // missing value
            ['a'], // missing value
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.name, equals('Untitled List'));
        expect(list.videoEventIds, isEmpty);
      });

      test('skips empty tags', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            [], // empty tag
          ],
        );

        final list = CuratedListConverter.fromEvent(event);

        expect(list, isNotNull);
        expect(list!.id, equals('my-list'));
      });
    });

    group('toEventTags', () {
      final now = DateTime(2025, 6, 15);

      test('includes d-tag and title', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'My List',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['d', 'my-list'])));
        expect(tags, contains(equals(['title', 'My List'])));
      });

      test('does not inline a client tag', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags.any((tag) => tag.first == 'client'), isFalse);
      });

      test('includes description when present', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          description: 'A description',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['description', 'A description'])));
      });

      test('excludes description when null', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);
        final descTags = tags.where((t) => t[0] == 'description');

        expect(descTags, isEmpty);
      });

      test('excludes description when empty', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          description: '',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);
        final descTags = tags.where((t) => t[0] == 'description');

        expect(descTags, isEmpty);
      });

      test('includes image when present', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          imageUrl: 'https://example.com/img.jpg',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(
          tags,
          contains(equals(['image', 'https://example.com/img.jpg'])),
        );
      });

      test('includes t-tags for each tag', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          tags: const ['music', 'dance'],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['t', 'music'])));
        expect(tags, contains(equals(['t', 'dance'])));
      });

      test('includes collaborative and collaborator tags', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          isCollaborative: true,
          allowedCollaborators: const ['alice', 'bob'],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['collaborative', 'true'])));
        expect(tags, contains(equals(['collaborator', 'alice'])));
        expect(tags, contains(equals(['collaborator', 'bob'])));
      });

      test('excludes collaborative tags when not collaborative', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);
        final collabTags = tags.where((t) => t[0] == 'collaborative');
        final collabPubkeys = tags.where((t) => t[0] == 'collaborator');

        expect(collabTags, isEmpty);
        expect(collabPubkeys, isEmpty);
      });

      test('includes thumbnail when present', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          thumbnailEventId: 'thumb-id',
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['thumbnail', 'thumb-id'])));
      });

      test('includes playorder tag', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          playOrder: PlayOrder.shuffle,
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['playorder', 'shuffle'])));
      });

      test('includes e-tags for video event IDs', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const ['video-1', 'video-2'],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['e', 'video-1'])));
        expect(tags, contains(equals(['e', 'video-2'])));
      });

      test('includes a-tags for addressable video references', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [
            '34235:pubkey123:horizontal-video',
            '34236:pubkey456:vertical-video',
          ],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(
          tags,
          contains(equals(['a', '34235:pubkey123:horizontal-video'])),
        );
        expect(tags, contains(equals(['a', '34236:pubkey456:vertical-video'])));
        expect(
          tags.where((tag) => tag.first == 'e').map((tag) => tag[1]),
          isNot(
            containsAll([
              '34235:pubkey123:horizontal-video',
              '34236:pubkey456:vertical-video',
            ]),
          ),
        );
      });

      test('keeps non-video addressable references as e-tags', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [
            '30023:pubkey123:some-article',
            '34237:pubkey789:not-a-nip71-video',
            '34236::missing-pubkey',
            '34236:pubkey456:',
          ],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['e', '30023:pubkey123:some-article'])));
        expect(
          tags,
          contains(equals(['e', '34237:pubkey789:not-a-nip71-video'])),
        );
        expect(tags, contains(equals(['e', '34236::missing-pubkey'])));
        expect(tags, contains(equals(['e', '34236:pubkey456:'])));
      });
    });

    group('private items', () {
      final now = DateTime(2025, 6, 15);

      CuratedList listWith(List<String> videoEventIds) => CuratedList(
        id: 'my-list',
        name: 'My List',
        description: 'A description',
        videoEventIds: videoEventIds,
        createdAt: now,
        updatedAt: now,
      );

      test('toItemTags returns only the video references', () {
        final tags = CuratedListConverter.toItemTags(
          listWith(const ['abc123', '34236:pubkey456:clip']),
        );

        expect(tags, [
          ['e', 'abc123'],
          ['a', '34236:pubkey456:clip'],
        ]);
      });

      test('toPublicMetadataTags omits the video references', () {
        final tags = CuratedListConverter.toPublicMetadataTags(
          listWith(const ['abc123', '34236:pubkey456:clip']),
        );

        expect(tags, contains(equals(['d', 'my-list'])));
        expect(tags, contains(equals(['title', 'My List'])));
        expect(
          tags.any((tag) => tag.first == 'e' || tag.first == 'a'),
          isFalse,
        );
      });

      test('toPrivateMetadataTags omits an item-derived thumbnail', () {
        final tags = CuratedListConverter.toPrivateMetadataTags(
          listWith(const ['abc123']).copyWith(thumbnailEventId: 'abc123'),
        );

        expect(tags, contains(equals(['d', 'my-list'])));
        expect(tags.any((tag) => tag.first == 'thumbnail'), isFalse);
      });

      test('only exact NIP-44 envelopes are classified as sealed', () {
        expect(CuratedListConverter.isNip44Payload(_sealedPayload), isTrue);
        expect(
          CuratedListConverter.isNip44Payload('sealed:private items'),
          isFalse,
        );
        expect(
          CuratedListConverter.isNip44Payload(base64Encode(List.filled(99, 1))),
          isFalse,
        );
      });

      test('recognizes the legacy NIP-04 encrypted shape', () {
        expect(
          CuratedListConverter.isEncryptedItemPayload(
            'Y2lwaGVydGV4dA==?iv=aW5pdGlhbGl6YXRpb252ZWN0b3I=',
          ),
          isTrue,
        );
      });

      test('toEventTags is the metadata tags followed by the item tags', () {
        final list = listWith(const ['abc123', '34236:pubkey456:clip']);

        expect(CuratedListConverter.toEventTags(list), [
          ...CuratedListConverter.toPublicMetadataTags(list),
          ...CuratedListConverter.toItemTags(list),
        ]);
      });

      test(
        'fromEvent merges decrypted item tags and marks the list private',
        () {
          // What a private list looks like on a relay: metadata in public tags,
          // items only in the encrypted content.
          final event = _makeEvent(
            tags: [
              ['d', 'my-list'],
              ['title', 'My List'],
            ],
            content: 'ArbitraryNip44Ciphertext==',
          );

          final list = CuratedListConverter.fromEvent(
            event,
            privateTags: const [
              ['e', 'abc123'],
              ['a', '34236:pubkey456:clip'],
            ],
          );

          expect(list, isNotNull);
          expect(list!.isPublic, isFalse);
          expect(list.videoEventIds, ['abc123', '34236:pubkey456:clip']);
        },
      );

      test('fromEvent does not name a list after undecrypted content', () {
        // Without a title the parser falls back to the first line of content.
        // For a private list that content is ciphertext, and naming the list
        // after it would put base64 in the app bar.
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
          content: 'ArbitraryNip44Ciphertext==',
        );

        final list = CuratedListConverter.fromEvent(
          event,
          privateTags: const [
            ['e', 'abc123'],
          ],
        );

        expect(list!.name, 'Untitled List');
        expect(list.description, isNull);
      });

      test(
        'fromEvent still reads content as a description for public lists',
        () {
          final event = _makeEvent(
            tags: [
              ['d', 'my-list'],
              ['title', 'My List'],
              ['e', 'abc123'],
            ],
            content: 'A description',
          );

          final list = CuratedListConverter.fromEvent(event);

          expect(list!.isPublic, isTrue);
          expect(list.description, 'A description');
          expect(list.videoEventIds, ['abc123']);
        },
      );
    });

    group('private item size limit', () {
      final now = DateTime(2026, 9);

      CuratedList privateListWith(int videoCount) => CuratedList(
        id: 'my-list',
        name: 'My List',
        isPublic: false,
        videoEventIds: [
          for (var i = 0; i < videoCount; i++) i.toString().padLeft(64, '0'),
        ],
        createdAt: now,
        updatedAt: now,
      );

      test('a small private list fits', () {
        expect(
          CuratedListConverter.privateItemPayloadFits(privateListWith(3)),
          isTrue,
        );
      });

      test('a private list past the u16 ceiling does not fit', () {
        // A private list is sealed with ONE NIP-44 encryption, so its plaintext
        // cannot exceed the u16 maximum (#7331).
        final tooBig = privateListWith(1000);
        final plaintextBytes = utf8
            .encode(jsonEncode(CuratedListConverter.toItemTags(tooBig)))
            .length;

        expect(plaintextBytes, greaterThan(NIP44V2.maxU16PlaintextSize));
        expect(CuratedListConverter.privateItemPayloadFits(tooBig), isFalse);
      });

      test('adding to a full private list would exceed the limit', () {
        expect(
          CuratedListConverter.wouldExceedPrivateItemLimit(
            privateListWith(1000),
            'a' * 64,
          ),
          isTrue,
        );
      });

      test('adding to a small private list would not', () {
        expect(
          CuratedListConverter.wouldExceedPrivateItemLimit(
            privateListWith(3),
            'a' * 64,
          ),
          isFalse,
        );
      });

      test('a public list is never limited — its items are not sealed', () {
        final publicList = CuratedList(
          id: 'my-list',
          name: 'My List',
          videoEventIds: [
            for (var i = 0; i < 1000; i++) i.toString().padLeft(64, '0'),
          ],
          createdAt: now,
          updatedAt: now,
        );

        expect(
          CuratedListConverter.wouldExceedPrivateItemLimit(
            publicList,
            'a' * 64,
          ),
          isFalse,
        );
      });

      test('re-adding an item already present cannot exceed anything', () {
        final list = privateListWith(1000);

        expect(
          CuratedListConverter.wouldExceedPrivateItemLimit(
            list,
            list.videoEventIds.first,
          ),
          isFalse,
        );
      });
    });

    group('extractDTag', () {
      test('returns null when no d-tag is present', () {
        final event = _makeEvent(
          tags: [
            ['title', 'No D Tag'],
          ],
        );

        expect(CuratedListConverter.extractDTag(event), isNull);
      });

      test('returns d-tag value', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list-id'],
            ['title', 'Something'],
          ],
        );

        expect(CuratedListConverter.extractDTag(event), equals('my-list-id'));
      });

      test('returns first d-tag when multiple exist', () {
        final event = _makeEvent(
          tags: [
            ['d', 'first'],
            ['d', 'second'],
          ],
        );

        expect(CuratedListConverter.extractDTag(event), equals('first'));
      });
    });
  });
}
