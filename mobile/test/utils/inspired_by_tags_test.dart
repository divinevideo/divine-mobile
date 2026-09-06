// ABOUTME: Tests the shared inspired-by p-tag builder and creator resolution
// ABOUTME: used by the direct-upload and edit-video publish paths.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/inspired_by_tags.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

void main() {
  const creatorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const otherPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const selfPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('buildInspiredByPTag', () {
    test('builds the inspired-by-marked p tag with the default relay', () {
      expect(
        buildInspiredByPTag(creatorPubkey),
        equals([
          'p',
          creatorPubkey,
          inspiredByPTagRelayHint,
          inspiredByPTagMarker,
        ]),
      );
    });

    test('uses the provided relay hint when non-empty', () {
      expect(
        buildInspiredByPTag(creatorPubkey, relayHint: 'wss://other.relay'),
        equals(['p', creatorPubkey, 'wss://other.relay', 'inspired-by']),
      );
    });

    test('falls back to the default relay when the hint is empty', () {
      expect(
        buildInspiredByPTag(creatorPubkey, relayHint: ''),
        equals([
          'p',
          creatorPubkey,
          inspiredByPTagRelayHint,
          inspiredByPTagMarker,
        ]),
      );
    });
  });

  group('resolveInspiredByCreatorHexes', () {
    test('resolves the creator from a well-formed addressable id', () {
      expect(
        resolveInspiredByCreatorHexes(
          addressableId: '34236:$creatorPubkey:some-d-tag',
        ),
        equals({creatorPubkey}),
      );
    });

    test('skips a malformed addressable id', () {
      expect(resolveInspiredByCreatorHexes(addressableId: '34236:'), isEmpty);
      expect(
        resolveInspiredByCreatorHexes(addressableId: 'not-a-coordinate'),
        isEmpty,
      );
      expect(
        resolveInspiredByCreatorHexes(addressableId: '34236:short-hex:d'),
        isEmpty,
      );
    });

    test('resolves the creator from a valid npub', () {
      final npub = NostrKeyUtils.encodePubKey(creatorPubkey);
      expect(
        resolveInspiredByCreatorHexes(npubs: [npub]),
        equals({creatorPubkey}),
      );
    });

    test('skips an undecodable npub', () {
      expect(
        resolveInspiredByCreatorHexes(
          npubs: const ['npub1notavalidbech32string'],
        ),
        isEmpty,
      );
      expect(resolveInspiredByCreatorHexes(npubs: const ['']), isEmpty);
      expect(resolveInspiredByCreatorHexes(), isEmpty);
    });

    test('resolves two distinct creators when both sources are present', () {
      final npub = NostrKeyUtils.encodePubKey(otherPubkey);
      expect(
        resolveInspiredByCreatorHexes(
          addressableId: '34236:$creatorPubkey:some-d-tag',
          npubs: [npub],
        ),
        equals({creatorPubkey, otherPubkey}),
      );
    });

    test('dedupes when both sources reference the same creator', () {
      final npub = NostrKeyUtils.encodePubKey(creatorPubkey);
      expect(
        resolveInspiredByCreatorHexes(
          addressableId: '34236:$creatorPubkey:some-d-tag',
          npubs: [npub],
        ),
        equals({creatorPubkey}),
      );
    });
  });

  group('withInspiredByContentReference', () {
    test('names only the first creator, whatever the rest are', () {
      // The reader's regex matches a single trailing reference, so a second
      // name in the content would break attribution for every client.
      final content = withInspiredByContentReference('a caption', const [
        'npub1first',
        'npub1second',
      ]);

      expect(content, equals('a caption\n\nInspired by nostr:npub1first'));
      expect(content, isNot(contains('npub1second')));
    });

    test('drops the leading blank line when there is no caption', () {
      expect(
        withInspiredByContentReference('', const ['npub1only']),
        equals('Inspired by nostr:npub1only'),
      );
    });

    test('leaves the caption untouched with no creators', () {
      expect(
        withInspiredByContentReference('a caption', const []),
        equals('a caption'),
      );
    });

    test('skips blank entries rather than crediting an empty reference', () {
      expect(
        withInspiredByContentReference('hi', const ['', '  ', 'npub1real']),
        equals('hi\n\nInspired by nostr:npub1real'),
      );
      expect(
        withInspiredByContentReference('hi', const ['', '  ']),
        equals('hi'),
      );
    });
  });

  group('buildInspiredByPTags', () {
    test('emits an inspired-by p tag for the resolved creator', () {
      expect(
        buildInspiredByPTags(
          existingTags: const [],
          addressableId: '34236:$creatorPubkey:some-d-tag',
          selfPubkey: selfPubkey,
        ),
        equals([buildInspiredByPTag(creatorPubkey)]),
      );
    });

    test("skips the publisher's own pubkey", () {
      expect(
        buildInspiredByPTags(
          existingTags: const [],
          addressableId: '34236:$selfPubkey:some-d-tag',
          selfPubkey: selfPubkey,
        ),
        isEmpty,
      );
    });

    test('skips a creator already carried by any existing p tag', () {
      expect(
        buildInspiredByPTags(
          existingTags: const [
            ['p', creatorPubkey, 'wss://relay.divine.video', 'collaborator'],
          ],
          addressableId: '34236:$creatorPubkey:some-d-tag',
          selfPubkey: selfPubkey,
        ),
        isEmpty,
      );
    });

    test('emits both creators on co-occurring video and person sources', () {
      final npub = NostrKeyUtils.encodePubKey(otherPubkey);
      final tags = buildInspiredByPTags(
        existingTags: const [],
        addressableId: '34236:$creatorPubkey:some-d-tag',
        npubs: [npub],
        selfPubkey: selfPubkey,
      );
      expect(tags, hasLength(2));
      expect(tags, anyElement(equals(buildInspiredByPTag(creatorPubkey))));
      expect(tags, anyElement(equals(buildInspiredByPTag(otherPubkey))));
    });
  });
}
