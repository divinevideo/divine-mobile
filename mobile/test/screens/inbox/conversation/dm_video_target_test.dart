// ABOUTME: Unit tests for resolveDmVideoTarget and DmVideoTarget.
// ABOUTME: Covers legacy Divine URL and structured NIP-18 q-reference resolution.

import 'dart:convert';

import 'package:bech32/bech32.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nip19/tlv_util.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_target.dart';

void main() {
  const author =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const eventId =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';

  group('resolveDmVideoTarget', () {
    test('opens and copies a complete naddr without a citation', () {
      final reference = NIP19Tlv.encodeNaddr(
        Naddr(id: 'folder/clip:1', author: author, kind: 34235),
      );
      final url = 'https://divine.video/video/$reference';
      final target = resolveDmVideoTarget(content: 'watch $url');
      expect(target!.stableId, 'folder/clip:1');
      expect(target.authorPubkey, author);
      expect(target.videoKind, 34235);
      expect(target.routeId, reference);
      expect(target.canonicalUrl, url);
    });

    test(
      'the embedded naddr author wins over a conflicting query and citation',
      () {
        final url = divineVideoShareUrl(
          'clip',
          authorPubkey: author,
          kind: 34236,
        );
        final target = resolveDmVideoTarget(
          content: '$url?author=${'b' * 64}',
          sharedVideoRef: DmSharedVideoRef(
            coordinateOrId: '34236:${'b' * 64}:clip',
            videoKind: DmSharedVideoKind.addressableShortVideo,
          ),
        );
        expect(target!.authorPubkey, author);
        expect(target.stableId, 'clip');
        expect(target.videoKind, 34236);
        expect(target.routeId, Uri.parse(url).pathSegments.last);
      },
    );

    group('a reference that repeats a field', () {
      // Decoders disagree on a repeated entry: this one keeps the last,
      // nostr-tools (divine.video) the first. Copying the sender's raw string
      // would open another video in a browser than the card previews.
      String crafted(String hrp, void Function(List<int> buf) write) {
        final buf = <int>[];
        write(buf);
        return Bech32Encoder().convert(
          Bech32(hrp, Nip19.convertBits(buf, 8, 5, true)),
          2000,
        );
      }

      test('copies and routes the naddr it previews', () {
        final reference = crafted('naddr', (buf) {
          TLVUtil.writeTLVEntry(buf, TLVType.defaultType, utf8.encode('clip'));
          TLVUtil.writeTLVEntry(buf, TLVType.author, List.filled(32, 0xaa));
          TLVUtil.writeTLVEntry(buf, TLVType.author, List.filled(32, 0xbb));
          TLVUtil.writeTLVEntry(buf, TLVType.kind, [0, 0, 0x85, 0xbc]);
        });
        final target = resolveDmVideoTarget(
          content: 'https://divine.video/video/$reference',
        );

        final previewed = NIP19Tlv.encodeNaddr(
          Naddr(id: 'clip', author: 'bb' * 32, kind: 34236),
        );
        expect(target!.authorPubkey, 'bb' * 32);
        expect(target.routeId, previewed);
        expect(target.canonicalUrl, 'https://divine.video/video/$previewed');
      });

      test('copies and routes the nevent it previews', () {
        final reference = crafted('nevent', (buf) {
          TLVUtil.writeTLVEntry(buf, TLVType.defaultType, List.filled(32, 1));
          TLVUtil.writeTLVEntry(buf, TLVType.defaultType, List.filled(32, 2));
        });
        final target = resolveDmVideoTarget(
          content: 'https://divine.video/video/$reference',
        );

        final previewed = NIP19Tlv.encodeNevent(Nevent(id: '02' * 32));
        expect(target!.stableId, '02' * 32);
        expect(target.routeId, previewed);
        expect(target.canonicalUrl, 'https://divine.video/video/$previewed');
      });
    });

    group('a NIP-19 link that cannot name a video', () {
      String link(String reference) => 'https://divine.video/video/$reference';

      test('resolves nothing for an naddr of a non-addressable kind', () {
        for (final kind in [22, 30023]) {
          final reference = NIP19Tlv.encodeNaddr(
            Naddr(id: 'clip', author: author, kind: kind),
          );
          expect(resolveDmVideoTarget(content: link(reference)), isNull);
        }
      });

      test('resolves nothing for an naddr whose author is not a key', () {
        final reference = NIP19Tlv.encodeNaddr(
          Naddr(id: 'clip', author: 'ab' * 16, kind: 34236),
        );
        expect(resolveDmVideoTarget(content: link(reference)), isNull);
      });

      test('resolves nothing for an nevent whose id is not an event id', () {
        final reference = NIP19Tlv.encodeNevent(Nevent(id: 'ab' * 16));
        expect(resolveDmVideoTarget(content: link(reference)), isNull);
      });
    });

    group('an nevent link without an author', () {
      final url = divineVideoShareUrl(eventId, kind: 22);

      test('takes the author of a regular citation of the same event', () {
        final target = resolveDmVideoTarget(
          content: url,
          sharedVideoRef: const DmSharedVideoRef(
            coordinateOrId: eventId,
            videoKind: DmSharedVideoKind.shortVideo,
            authorPubkey: author,
          ),
        );
        expect(target!.authorPubkey, author);
      });

      test('ignores a regular citation of another event', () {
        final target = resolveDmVideoTarget(
          content: url,
          sharedVideoRef: DmSharedVideoRef(
            coordinateOrId: 'cc' * 32,
            videoKind: DmSharedVideoKind.shortVideo,
            authorPubkey: author,
          ),
        );
        expect(target!.authorPubkey, isNull);
      });

      test('ignores an addressable citation whose d tag is the event id', () {
        final target = resolveDmVideoTarget(
          content: url,
          sharedVideoRef: const DmSharedVideoRef(
            coordinateOrId: '34236:$author:$eventId',
            videoKind: DmSharedVideoKind.addressableShortVideo,
          ),
        );
        expect(target!.authorPubkey, isNull);
      });
    });

    test('opens an nevent as an exact event rather than a d tag', () {
      final url = divineVideoShareUrl(eventId, kind: 22);
      final target = resolveDmVideoTarget(content: url);
      expect(target!.stableId, eventId);
      expect(target.videoKind, 22);
      expect(target.canonicalUrl, url);
    });

    test(
      'rejects a broken or truncated naddr instead of looking it up as a d tag',
      () {
        expect(
          resolveDmVideoTarget(
            content: 'https://divine.video/video/naddr1broken',
          ),
          isNull,
        );
        final url = divineVideoShareUrl(
          'clip',
          authorPubkey: author,
          kind: 34236,
        );
        expect(
          resolveDmVideoTarget(content: url, contentIsTruncated: true),
          isNull,
        );
      },
    );

    test('resolves a canonical Divine URL', () {
      final target = resolveDmVideoTarget(
        content: 'watch https://divine.video/video/skate-loop',
      );

      expect(target, isNotNull);
      expect(target!.stableId, 'skate-loop');
      expect(target.authorPubkey, isNull);
      expect(target.videoKind, isNull);
      expect(target.routeId, 'skate-loop');
      expect(target.routeAuthor, isNull);
      expect(
        target.canonicalUrl,
        'https://divine.video/video/skate-loop',
      );
    });

    test('resolves a regular-event structured reference', () {
      final target = resolveDmVideoTarget(
        content: 'watch this',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: eventId,
          videoKind: DmSharedVideoKind.shortVideo,
          authorPubkey: author,
        ),
      );

      expect(target, isNotNull);
      expect(target!.stableId, eventId);
      expect(target.authorPubkey, author);
      expect(target.videoKind, 22);
      expect(target.routeId, NIP19Tlv.encodeNevent(Nevent(id: eventId)));
      // A hex route is also looked up as a d tag, so the author travels with it.
      expect(target.routeAuthor, author);
      expect(
        target.canonicalUrl,
        divineVideoShareUrl(eventId, authorPubkey: author, kind: 22),
      );
    });

    test(
      'keeps a hex d-tag URL a d-tag lookup when a regular citation names '
      'another event',
      () {
        // An earlier app linked a regular video by its d tag and cited it by
        // its event id; the d tag here is hex, so it reads like an event id.
        final dTag = 'b' * 64;
        final target = resolveDmVideoTarget(
          content: 'https://divine.video/video/$dTag?author=$author',
          sharedVideoRef: const DmSharedVideoRef(
            coordinateOrId: eventId,
            videoKind: DmSharedVideoKind.shortVideo,
            authorPubkey: author,
          ),
        );

        expect(target!.routeId, dTag);
        expect(target.routeAuthor, author);
        expect(
          target.canonicalUrl,
          'https://divine.video/video/$dTag?author=$author',
        );
      },
    );

    test('resolves an addressable structured reference', () {
      final target = resolveDmVideoTarget(
        content: 'watch this',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: '34236:$author:skate-loop',
          videoKind: DmSharedVideoKind.addressableShortVideo,
        ),
      );

      expect(target, isNotNull);
      expect(target!.stableId, 'skate-loop');
      expect(target.authorPubkey, author);
      expect(target.videoKind, 34236);
      // The bare d tag names no author, and another account's video can
      // share it, so an author-named share resolves by its coordinate alone.
      expect(target.routeId, '34236:$author:skate-loop');
      expect(target.routeAuthor, isNull);
      // The copied link names the author too (#10929).
      expect(
        target.canonicalUrl,
        divineVideoShareUrl('skate-loop', authorPubkey: author, kind: null),
      );
    });

    test('reads the author a shared link names', () {
      final target = resolveDmVideoTarget(
        content: 'watch https://divine.video/video/skate-loop?author=$author',
      );

      expect(target, isNotNull);
      expect(target!.stableId, 'skate-loop');
      expect(target.authorPubkey, author);
      // No kind to build a coordinate from, so the lookup is held to the
      // author instead.
      expect(target.routeId, 'skate-loop');
      expect(target.routeAuthor, author);
      expect(
        target.canonicalUrl,
        'https://divine.video/video/skate-loop?author=$author',
      );
    });

    test('lets a citation of the same video keep its own author', () {
      const linkAuthor =
          '5566778855667788556677885566778855667788556677885566778855667788';
      final target = resolveDmVideoTarget(
        content: 'https://divine.video/video/skate-loop?author=$linkAuthor',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: '34236:$author:skate-loop',
          videoKind: DmSharedVideoKind.addressableShortVideo,
        ),
      );

      expect(target!.authorPubkey, author);
      expect(target.routeId, '34236:$author:skate-loop');
    });

    test(
      'keeps structured routing metadata when it names the URL d tag',
      () {
        final target = resolveDmVideoTarget(
          content: 'https://divine.video/video/skate-loop',
          sharedVideoRef: const DmSharedVideoRef(
            coordinateOrId: '34236:$author:skate-loop',
            videoKind: DmSharedVideoKind.addressableShortVideo,
          ),
        );

        expect(target, isNotNull);
        expect(target!.stableId, 'skate-loop');
        expect(target.authorPubkey, author);
        expect(target.videoKind, 34236);
        expect(target.routeId, '34236:$author:skate-loop');
      },
    );

    test(
      'drops structured routing metadata that names a different d tag '
      'from the URL',
      () {
        // Pairing the URL's d tag with another video's author builds a
        // coordinate that names neither video.
        final target = resolveDmVideoTarget(
          content: 'https://divine.video/video/url-stable-id',
          sharedVideoRef: const DmSharedVideoRef(
            coordinateOrId: '34236:$author:structured-stable-id',
            videoKind: DmSharedVideoKind.addressableShortVideo,
          ),
        );

        expect(target, isNotNull);
        expect(target!.stableId, 'url-stable-id');
        expect(target.authorPubkey, isNull);
        expect(target.videoKind, isNull);
        expect(target.routeId, 'url-stable-id');
      },
    );

    test('routes a citation whose author is not a hex pubkey like an '
        'unattributed link', () {
      // Divine's clients always write a hex author; another client's npub or
      // truncated key would build a coordinate no lookup can parse.
      final target = resolveDmVideoTarget(
        content: 'watch this',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: '34236:npub1notahexpubkey:skate-loop',
          videoKind: DmSharedVideoKind.addressableShortVideo,
        ),
      );

      expect(target, isNotNull);
      expect(target!.stableId, 'skate-loop');
      expect(target.routeId, 'skate-loop');
      expect(target.routeAuthor, isNull);
    });

    test('rejects a malformed addressable reference without a URL', () {
      final target = resolveDmVideoTarget(
        content: 'watch this',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: '34236:$author',
          videoKind: DmSharedVideoKind.addressableShortVideo,
        ),
      );

      expect(target, isNull);
    });

    test('falls back to a URL when the structured reference is malformed', () {
      final target = resolveDmVideoTarget(
        content: 'https://divine.video/video/url-stable-id',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: '34236:$author',
          videoKind: DmSharedVideoKind.addressableShortVideo,
        ),
      );

      expect(target, isNotNull);
      expect(target!.stableId, 'url-stable-id');
      expect(target.authorPubkey, isNull);
      expect(target.videoKind, isNull);
    });
  });

  // divine-web never wrote the share URL into the rumor content and allowed
  // sending a share with an empty draft, so the citation is the only identity
  // these messages carry. See #6224.
  group('resolveDmVideoTarget — truncated content', () {
    const url = 'https://divine.video/video/abc123';

    test('ignores a URL that runs to the end of a truncated prefix', () {
      final target = resolveDmVideoTarget(
        content: 'note\n$url',
        contentIsTruncated: true,
      );

      expect(target, isNull);
    });

    test('keeps a URL followed by more text inside a truncated prefix', () {
      final target = resolveDmVideoTarget(
        content: 'note\n$url\nmore',
        contentIsTruncated: true,
      );

      expect(target?.stableId, 'abc123');
    });

    test('keeps a trailing URL when the content is complete', () {
      final target = resolveDmVideoTarget(content: 'note\n$url');

      expect(target?.stableId, 'abc123');
    });

    // #10929: the id ends at `?`, so a cut inside the author query would
    // otherwise resolve the bare d tag, unscoped.
    test('ignores a URL whose author query the prefix cut through', () {
      for (final cut in ['?', '?auth', '?author=', '?author=${'e' * 63}']) {
        expect(
          resolveDmVideoTarget(
            content: 'note\n$url$cut',
            contentIsTruncated: true,
          ),
          isNull,
          reason: cut,
        );
      }
    });

    test('keeps a URL whose author query is complete in the prefix', () {
      final target = resolveDmVideoTarget(
        content: 'note\n$url?author=$author\nmore',
        contentIsTruncated: true,
      );

      expect(target?.stableId, 'abc123');
      expect(target?.routeAuthor, author);
    });

    test('falls back to the citation when the URL is cut', () {
      final target = resolveDmVideoTarget(
        content: 'note\nhttps://divine.video/video/ab',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: 'abc123',
          videoKind: DmSharedVideoKind.shortVideo,
          relayHint: 'wss://relay.example',
          authorPubkey: author,
        ),
        contentIsTruncated: true,
      );

      expect(target?.stableId, 'abc123');
    });
  });

  group('resolveDmVideoTarget — legacy divine-web share', () {
    const dTag = 'my-reel-123';

    DmSharedVideoRef webRef() => const DmSharedVideoRef(
      coordinateOrId: '34236:$author:$dTag',
      videoKind: DmSharedVideoKind.addressableShortVideo,
      authorPubkey: author,
    );

    test('resolves from the citation alone when content is empty', () {
      final target = resolveDmVideoTarget(
        content: '',
        sharedVideoRef: webRef(),
      );

      expect(target, isNotNull);
      expect(target!.stableId, equals(dTag));
      expect(target.authorPubkey, equals(author));
      expect(target.videoKind, equals(34236));
      expect(target.routeId, equals('34236:$author:$dTag'));
      expect(
        target.canonicalUrl,
        equals(divineVideoShareUrl(dTag, authorPubkey: author, kind: null)),
      );
    });

    test('a typed comment does not displace the citation identity', () {
      // The comment carries no URL, so the citation must remain the only
      // source of identity — not fall back to regex-matching the body.
      final target = resolveDmVideoTarget(
        content: 'check this out https://example.com/video/decoy',
        sharedVideoRef: webRef(),
      );

      expect(target, isNotNull);
      expect(target!.stableId, equals(dTag));
      expect(target.authorPubkey, equals(author));
      expect(target.videoKind, equals(34236));
    });
  });
}
