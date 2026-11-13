// ABOUTME: Unit tests for resolveDmVideoTarget and DmVideoTarget.
// ABOUTME: Covers legacy Divine URL and structured NIP-18 q-reference resolution.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_target.dart';

void main() {
  const author =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const eventId =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';

  group('resolveDmVideoTarget', () {
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
      expect(target.routeId, eventId);
      // A hex route is also looked up as a d tag, so the author travels with it.
      expect(target.routeAuthor, author);
      expect(
        target.canonicalUrl,
        'https://divine.video/video/$eventId?author=$author',
      );
    });

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
        'https://divine.video/video/skate-loop?author=$author',
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
        equals('https://divine.video/video/$dTag?author=$author'),
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
