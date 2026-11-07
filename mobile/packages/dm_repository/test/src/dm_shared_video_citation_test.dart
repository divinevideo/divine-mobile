// ABOUTME: Tests for DmSharedVideoCitation build (q tag + nostr URI) + parse.

import 'package:dm_repository/src/dm_shared_video_citation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';

void main() {
  // Deterministic 64-hex fixtures.
  final author = 'a' * 64;
  final eventId = 'b' * 64;
  const dTag = 'my-reel-123';
  const relay = 'wss://relay.example';

  group('DmSharedVideoCitation.build', () {
    test('addressable (34236) → coordinate q tag + naddr, no 4th element', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34236,
        authorPubkey: author,
        relayHint: relay,
        dTag: dTag,
      )!;

      expect(citation.qTag, equals(['q', '34236:$author:$dTag', relay]));
      expect(citation.qTag.length, equals(3)); // no 4th pubkey element
      expect(citation.nostrUri, startsWith('nostr:naddr1'));

      final decoded = NIP19Tlv.decodeNaddr(
        citation.nostrUri.substring('nostr:'.length),
      )!;
      expect(decoded.id, equals(dTag));
      expect(decoded.author, equals(author));
      expect(decoded.kind, equals(34236));
      expect(decoded.relays, contains(relay));
    });

    test('regular (22) → id q tag with 4th author element + nevent', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 22,
        authorPubkey: author,
        relayHint: relay,
        eventId: eventId,
      )!;

      expect(citation.qTag, equals(['q', eventId, relay, author]));
      expect(citation.qTag.length, equals(4)); // 4th element present
      expect(citation.nostrUri, startsWith('nostr:nevent1'));

      final decoded = NIP19Tlv.decodeNevent(
        citation.nostrUri.substring('nostr:'.length),
      )!;
      expect(decoded.id, equals(eventId));
      expect(decoded.author, equals(author));
      expect(decoded.relays, contains(relay));
    });

    test('empty relay hint falls back to the Divine default', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34236,
        authorPubkey: author,
        relayHint: '',
        dTag: dTag,
      )!;
      expect(citation.qTag[2], equals(DmShareConstants.defaultRelayHint));
    });

    test('returns null when addressable d-tag is missing', () {
      expect(
        DmSharedVideoCitation.build(
          videoKind: 34236,
          authorPubkey: author,
          relayHint: relay,
        ),
        isNull,
      );
    });

    test('addressable with no d-tag cites its event id instead', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34236,
        authorPubkey: author,
        relayHint: relay,
        eventId: eventId,
      )!;

      expect(citation.qTag, equals(['q', eventId, relay, author]));
      final decoded = NIP19Tlv.decodeNevent(
        citation.nostrUri.substring('nostr:'.length),
      )!;
      expect(decoded.id, equals(eventId));
      expect(decoded.author, equals(author));
    });

    test('addressable with an empty d-tag cites its event id instead', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34235,
        authorPubkey: author,
        relayHint: relay,
        dTag: '',
        eventId: eventId,
      )!;

      expect(citation.qTag, equals(['q', eventId, relay, author]));
      expect(citation.nostrUri, startsWith('nostr:nevent1'));
    });

    test('an event-id fallback parses back to the shared event', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34236,
        authorPubkey: author,
        relayHint: relay,
        eventId: eventId,
      )!;

      final ref = DmSharedVideoCitation.parse([citation.qTag]);

      expect(ref?.eventId, equals(eventId));
      expect(ref?.authorPubkey, equals(author));
    });

    test('returns null when regular event id is missing/invalid', () {
      expect(
        DmSharedVideoCitation.build(
          videoKind: 22,
          authorPubkey: author,
          relayHint: relay,
          eventId: 'not-hex',
        ),
        isNull,
      );
    });

    test('returns null when author pubkey is not 64-hex', () {
      expect(
        DmSharedVideoCitation.build(
          videoKind: 34236,
          authorPubkey: 'short',
          relayHint: relay,
          dTag: dTag,
        ),
        isNull,
      );
    });
  });

  group('DmSharedVideoCitation.parse', () {
    test('parses an addressable coordinate q tag', () {
      final ref = DmSharedVideoCitation.parse([
        ['p', author],
        ['q', '34236:$author:$dTag', relay],
      ]);
      expect(ref, isNotNull);
      expect(ref!.videoKind, equals(DmSharedVideoKind.addressableShortVideo));
      expect(ref.coordinateOrId, equals('34236:$author:$dTag'));
      expect(ref.relayHint, equals(relay));
      expect(ref.authorPubkey, equals(author));
      expect(ref.isAddressable, isTrue);
    });

    test('parses an addressable normal-video coordinate q tag', () {
      final ref = DmSharedVideoCitation.parse([
        ['q', '34235:$author:$dTag', relay],
      ]);
      expect(ref, isNotNull);
      expect(ref!.videoKind, equals(DmSharedVideoKind.addressableNormalVideo));
      expect(ref.coordinateOrId, equals('34235:$author:$dTag'));
      expect(ref.authorPubkey, equals(author));
      expect(ref.isAddressable, isTrue);
    });

    test('parses a regular event-id q tag with 4th author element', () {
      final ref = DmSharedVideoCitation.parse([
        ['q', eventId, relay, author],
      ]);
      expect(ref, isNotNull);
      expect(ref!.videoKind, equals(DmSharedVideoKind.shortVideo));
      expect(ref.coordinateOrId, equals(eventId));
      expect(ref.relayHint, equals(relay));
      expect(ref.authorPubkey, equals(author));
      expect(ref.isAddressable, isFalse);
    });

    test('does not parse a bare note q tag as a shared video', () {
      expect(
        DmSharedVideoCitation.parse([
          ['q', eventId, relay],
        ]),
        isNull,
      );
    });

    test('returns null when there is no q tag', () {
      expect(
        DmSharedVideoCitation.parse([
          ['p', author],
          ['e', eventId],
        ]),
        isNull,
      );
    });

    test('returns null for a malformed q value', () {
      expect(
        DmSharedVideoCitation.parse([
          ['q', 'not-a-coordinate-or-id'],
        ]),
        isNull,
      );
      expect(
        DmSharedVideoCitation.parse([
          ['q', '1:$author:$dTag'],
        ]),
        isNull,
      );
      expect(DmSharedVideoCitation.parse([]), isNull);
    });

    test('round-trips build → parse for addressable', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34236,
        authorPubkey: author,
        relayHint: relay,
        dTag: dTag,
      )!;
      final ref = DmSharedVideoCitation.parse([citation.qTag])!;
      expect(ref.coordinateOrId, equals('34236:$author:$dTag'));
      expect(ref.authorPubkey, equals(author));
      expect(ref.isAddressable, isTrue);
    });

    test('round-trips build → parse for addressable normal video', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34235,
        authorPubkey: author,
        relayHint: relay,
        dTag: dTag,
      )!;
      final ref = DmSharedVideoCitation.parse([citation.qTag])!;
      expect(ref.coordinateOrId, equals('34235:$author:$dTag'));
      expect(ref.videoKind, equals(DmSharedVideoKind.addressableNormalVideo));
      expect(ref.authorPubkey, equals(author));
      expect(ref.isAddressable, isTrue);
    });
  });

  // divine-web's `buildDmShareTags`, live 2026-03-09 → 2026-08-04, wrote
  // `['r', url]` first and unconditionally, then an optional `['title', …]`,
  // then either `['a', '34236:<pubkey>:<d>']` or `['e', <id>]` — and never put
  // the URL in the rumor content. See #6224.
  group('DmSharedVideoCitation.parse — legacy divine-web share', () {
    const shareUrl = 'https://divine.video/video/$dTag';

    List<List<String>> webShareTags({
      String? coordinate,
      String url = shareUrl,
      bool omitCoordinate = false,
    }) {
      final address = coordinate ?? '34236:$author:$dTag';
      return <List<String>>[
        ['p', 'b' * 64],
        ['r', url],
        ['title', 'My reel'],
        if (!omitCoordinate) ['a', address],
      ];
    }

    test('parses the r + a share shape into an addressable ref', () {
      final ref = DmSharedVideoCitation.parse(webShareTags())!;

      expect(ref.coordinateOrId, equals('34236:$author:$dTag'));
      expect(ref.videoKind, equals(DmSharedVideoKind.addressableShortVideo));
      expect(ref.authorPubkey, equals(author));
      expect(ref.dTag, equals(dTag));
    });

    test('parses the addressable normal-video (34235) coordinate', () {
      final ref = DmSharedVideoCitation.parse(
        webShareTags(coordinate: '34235:$author:$dTag'),
      )!;

      expect(ref.videoKind, equals(DmSharedVideoKind.addressableNormalVideo));
    });

    test('a `q` tag still wins when both shapes are present', () {
      final ref = DmSharedVideoCitation.parse([
        ...webShareTags(),
        ['q', '34236:$eventId:other-reel', relay],
      ])!;

      expect(ref.coordinateOrId, equals('34236:$eventId:other-reel'));
    });

    test('ignores a collaborator invite carrying the same coordinate', () {
      // The invite ships its own addressable `a` tag; without the marker guard
      // it would render as a shared-video card.
      expect(
        DmSharedVideoCitation.parse([
          ['divine', 'collab-invite'],
          ['r', shareUrl],
          ['a', '34236:$author:$dTag', relay, 'root'],
          ['role', 'Collaborator'],
        ]),
        isNull,
      );
    });

    test('requires a companion divine.video `r` tag', () {
      expect(
        DmSharedVideoCitation.parse([
          ['p', 'b' * 64],
          ['a', '34236:$author:$dTag'],
        ]),
        isNull,
      );
    });

    test('rejects an `r` tag pointing somewhere other than divine.video', () {
      expect(
        DmSharedVideoCitation.parse(
          webShareTags(url: 'https://example.com/video/$dTag'),
        ),
        isNull,
      );
    });

    test('rejects an `r` tag that merely embeds a divine.video URL', () {
      expect(
        DmSharedVideoCitation.parse(
          webShareTags(url: 'https://elsewhere.example/?next=$shareUrl'),
        ),
        isNull,
      );
    });

    test('accepts a share URL carrying an unescaped d-tag', () {
      // divine-web interpolated the `d` tag into the path with no
      // percent-encoding, so a relay-supplied d-tag puts characters the URL
      // grammar would otherwise end on straight into the `r` value.
      const dottedTag = 'my.vine.2024';
      final ref = DmSharedVideoCitation.parse(
        webShareTags(
          coordinate: '34236:$author:$dottedTag',
          url: 'https://divine.video/video/$dottedTag',
        ),
      )!;

      expect(ref.dTag, equals(dottedTag));
    });

    test('rejects a coordinate whose author is not 64-hex', () {
      // divine-web built the coordinate from unvalidated URL query params.
      expect(
        DmSharedVideoCitation.parse(
          webShareTags(coordinate: '34236:not-a-pubkey:$dTag'),
        ),
        isNull,
      );
    });

    test('rejects a coordinate with an empty d-tag', () {
      expect(
        DmSharedVideoCitation.parse(webShareTags(coordinate: '34236:$author:')),
        isNull,
      );
    });

    test('rejects a non-video kind in the coordinate', () {
      expect(
        DmSharedVideoCitation.parse(
          webShareTags(coordinate: '30023:$author:$dTag'),
        ),
        isNull,
      );
    });

    test('never treats an `e` tag as a citation, even beside an `r`', () {
      // NIP-17 reserves `e` for the reply parent, and DmRepository already
      // assigns any `e` tag to replyToId — parsing it here would render a
      // quoted preview instead of a share card and leave the actions dead.
      expect(
        DmSharedVideoCitation.parse([
          ['p', 'b' * 64],
          ['r', 'https://divine.video/video/$eventId'],
          ['e', eventId],
        ]),
        isNull,
      );
    });

    test('an `r` tag alone is not a citation', () {
      // Carries no event identity, so there is nothing to resolve or save.
      expect(
        DmSharedVideoCitation.parse(webShareTags(omitCoordinate: true)),
        isNull,
      );
    });
  });
}
