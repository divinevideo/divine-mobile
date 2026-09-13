// ABOUTME: Unit tests for DeepLinkService URL parsing and deep link handling
// ABOUTME: Tests video URLs, profile URLs, and unknown URL patterns

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

void main() {
  group('DeepLinkService URL Parsing', () {
    group('Video URL Parsing', () {
      test('parses valid video URL correctly', () {
        const videoId = 'abc123def456';
        const url = 'https://divine.video/video/$videoId';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoRef, equals(videoId));
        expect(result.npub, isNull);
      });

      test('parses video URL with 64-char hex ID', () {
        const videoId =
            'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
        const url = 'https://divine.video/video/$videoId';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoRef, equals(videoId));
      });

      test('parses video URL with note1 event reference', () {
        const videoId =
            'note1w3jhxaq69g8m70m7g6g8j2rf7x0s5h7k0d0l0m9d3c4s5u6v7w8q9xyz0p';
        const url = 'https://divine.video/video/$videoId';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoRef, equals(videoId));
      });

      test('parses video URL with nevent reference', () {
        const videoId =
            'nevent1qqsqzg69v7y6hn00qy352euf40x77qfrg4ncn27dauqjx3t83x4ummspz4mhxue69uhhyetvv9ujuetcv9khqmr99e3k7mgprpmhxue69uhhyetvv9ujumn0wd68ytnhd9hxgqgawaehxw309aex2mrp0yhxgetnwss82un9wfjkccte9ehx7um5wghx7un8qgswaehxw309aex2mrp0yh8xarj9e3k7mgzyq8';
        const url = 'https://divine.video/video/$videoId';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoRef, equals(videoId));
      });

      test('handles video URL with trailing slash', () {
        const videoId = 'abc123';
        const url = 'https://divine.video/video/$videoId/';

        final result = DeepLinkService.parseDeepLink(url);

        // Should still parse - trailing slash creates empty segment
        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects video URL without ID', () {
        const url = 'https://divine.video/video';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
        expect(result.videoRef, isNull);
      });

      test('rejects video URL with extra path segments', () {
        const url = 'https://divine.video/video/abc123/extra';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });
    });

    group('Profile URL Parsing', () {
      test('parses valid profile URL correctly', () {
        const npub = 'npub1abc123def456';
        const url = 'https://divine.video/profile/$npub';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.profile));
        expect(result.npub, equals(npub));
        expect(result.videoRef, isNull);
      });

      test('parses profile URL with real npub format', () {
        const npub =
            'npub1sn0wdenkukak0d9dfczzeacvhkrgz92ak56egt7vdgzn8pv2wfqqhrjdv9';
        const url = 'https://divine.video/profile/$npub';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.profile));
        expect(result.npub, equals(npub));
      });

      test('rejects profile URL without npub', () {
        const url = 'https://divine.video/profile';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
        expect(result.npub, isNull);
      });

      test('parses profile URL with video index', () {
        const npub = 'npub1abc123def456';
        const url = 'https://divine.video/profile/$npub/3';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.profile));
        expect(result.npub, equals(npub));
        expect(result.index, equals(3));
      });

      test('parses profile URL with non-numeric index as null', () {
        const npub = 'npub1abc123def456';
        const url = 'https://divine.video/profile/$npub/extra';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.profile));
        expect(result.npub, equals(npub));
        expect(result.index, isNull);
      });
    });

    group('Hashtag URL Parsing', () {
      test('parses /hashtag/{tag} correctly', () {
        final result = DeepLinkService.parseDeepLink(
          'https://divine.video/hashtag/vibes',
        );

        expect(result.type, equals(DeepLinkType.hashtag));
        expect(result.hashtag, equals('vibes'));
        expect(result.index, isNull);
      });

      test('parses /hashtag/{tag}/{index} with index', () {
        final result = DeepLinkService.parseDeepLink(
          'https://divine.video/hashtag/music/5',
        );

        expect(result.type, equals(DeepLinkType.hashtag));
        expect(result.hashtag, equals('music'));
        expect(result.index, equals(5));
      });

      test('rejects hashtag URL without tag', () {
        final result = DeepLinkService.parseDeepLink(
          'https://divine.video/hashtag',
        );

        expect(result.type, equals(DeepLinkType.unknown));
      });
    });

    group('Search URL Parsing', () {
      test('parses /search/{term} correctly', () {
        final result = DeepLinkService.parseDeepLink(
          'https://divine.video/search/flutter',
        );

        expect(result.type, equals(DeepLinkType.search));
        expect(result.searchTerm, equals('flutter'));
        expect(result.index, isNull);
      });

      test('parses /search/{term}/{index} with index', () {
        final result = DeepLinkService.parseDeepLink(
          'https://divine.video/search/dart/2',
        );

        expect(result.type, equals(DeepLinkType.search));
        expect(result.searchTerm, equals('dart'));
        expect(result.index, equals(2));
      });

      test('rejects search URL without term', () {
        final result = DeepLinkService.parseDeepLink(
          'https://divine.video/search',
        );

        expect(result.type, equals(DeepLinkType.unknown));
      });
    });

    group('List URL Parsing', () {
      const authorPubkey =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

      test('parses /list/{listId}', () {
        const url = 'https://divine.video/list/my-vines';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.list));
        expect(result.listPubkey, isNull);
        expect(result.listId, equals('my-vines'));
      });

      test('parses /list/{listId} on www host', () {
        const url = 'https://www.divine.video/list/my-vines';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.list));
        expect(result.listPubkey, isNull);
        expect(result.listId, equals('my-vines'));
      });

      test('parses /list/{pubkey}/{listId} with hex pubkey', () {
        const url = 'https://divine.video/list/$authorPubkey/my-vines';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.list));
        expect(result.listPubkey, equals(authorPubkey));
        expect(result.listId, equals('my-vines'));
        expect(result.videoRef, isNull);
        expect(result.npub, isNull);
      });

      test('normalizes uppercase hex pubkey to lowercase', () {
        final url =
            'https://divine.video/list/${authorPubkey.toUpperCase()}/my-vines';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.list));
        expect(result.listPubkey, equals(authorPubkey));
      });

      test('normalizes npub author to hex', () {
        final npub = NostrKeyUtils.encodePubKey(authorPubkey);
        final url = 'https://divine.video/list/$npub/my-vines';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.list));
        expect(result.listPubkey, equals(authorPubkey));
        expect(result.listId, equals('my-vines'));
      });

      test('normalizes nprofile author to hex', () {
        final nprofile = NIP19Tlv.encodeNprofile(
          Nprofile(
            pubkey: authorPubkey,
            relays: ['wss://relay.divine.video'],
          ),
        );
        final url = 'https://divine.video/list/$nprofile/my-vines';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.list));
        expect(result.listPubkey, equals(authorPubkey));
        expect(result.listId, equals('my-vines'));
      });

      test('decodes URL-encoded list identifiers', () {
        const url =
            'https://divine.video/list/$authorPubkey/my%20favorite%20vines';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.list));
        expect(result.listId, equals('my favorite vines'));
      });

      test('treats a two-segment list URL as a local list id', () {
        const url = 'https://divine.video/list/$authorPubkey';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.list));
        expect(result.listPubkey, isNull);
        expect(result.listId, equals(authorPubkey));
      });

      test('rejects a 2-segment list URL with an empty list id '
          '(trailing slash)', () {
        const url = 'https://divine.video/list/';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
        expect(result.listId, isNull);
      });

      test('rejects a 3-segment list URL with an empty list id '
          '(trailing slash)', () {
        // A trailing slash yields a 3rd, empty path segment, so this reaches
        // the parse branch with a valid pubkey and an empty list id — the
        // isEmpty half of the guard, distinct from the missing-segment case.
        const url = 'https://divine.video/list/$authorPubkey/';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
        expect(result.listId, isNull);
      });

      test('rejects bare /list path', () {
        const url = 'https://divine.video/list';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects list URL with an invalid author pubkey', () {
        const url = 'https://divine.video/list/not-a-pubkey/my-vines';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects list URL with extra path segments', () {
        const url = 'https://divine.video/list/$authorPubkey/my-vines/extra';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });
    });

    group('Signer Callback Parsing', () {
      test('parses NIP-46 callback from native signer apps', () {
        final result = DeepLinkService.parseDeepLink(
          'divine://nostrconnect?x-source=aegis&relay=wss://localrelay.link:28443',
        );

        expect(result.type, equals(DeepLinkType.signerCallback));
        expect(
          result.signerCallbackRelay,
          equals('wss://localrelay.link:28443'),
        );
      });

      DeepLink parseCallback(String relay) => DeepLinkService.parseDeepLink(
        'divine://nostrconnect?x-source=aegis&relay='
        '${Uri.encodeComponent(relay)}',
      );

      // A same-device signer runs its relay on loopback and hands us that
      // address; NIP-46 puts the signer in control of the relays. These are
      // the two Aegis returns, and dropping them would break the pairing the
      // callback exists to finish.
      for (final relay in const [
        'wss://127.0.0.1:28443',
        'ws://127.0.0.1:8081',
        'wss://localrelay.link:28443',
      ]) {
        test('keeps the callback relay hint $relay', () {
          final result = parseCallback(relay);

          expect(result.type, equals(DeepLinkType.signerCallback));
          expect(result.signerCallbackRelay, equals(relay));
        });
      }

      // Anything can open a deep link, so the hint must not point the device
      // at the user's LAN, and cleartext must not leave the device. Dropping
      // a hint leaves the callback itself intact — the handoff still
      // reconnects the relays the session advertised.
      for (final relay in const [
        'wss://192.168.1.10:28443',
        'wss://10.5.0.1:28443',
        'wss://169.254.1.1:28443',
        'wss://signer.local:28443',
        'ws://localrelay.link:28443',
        'http://localrelay.link:28443',
        // The emulator's alias for the developer's laptop, not this device.
        'ws://10.0.2.2:47777',
        'wss://10.0.2.2:47777',
        // Root-anchored respellings of the same private targets.
        'wss://127.0.0.1.',
        'wss://127.0.0.1..',
        'wss://192.168.1.10.',
        'wss://192.168.1.10..',
        'wss://signer.local.',
        'wss://signer.local..',
      ]) {
        test('drops the callback relay hint $relay', () {
          final result = parseCallback(relay);

          expect(result.type, equals(DeepLinkType.signerCallback));
          expect(result.signerCallbackRelay, isNull);
        });
      }

      test('hands on the address it checked, not the raw parameter', () {
        final result = parseCallback('  wss://localrelay.link:28443  ');

        // The policy validates a trimmed URL, so returning the raw one would
        // dial and store a string that was never the one admitted.
        expect(
          result.signerCallbackRelay,
          equals('wss://localrelay.link:28443'),
        );
      });
    });

    // The divine:// scheme splits three ways on the authority: `nostrconnect`
    // is the NIP-46 callback Divine mints, an empty authority addresses an
    // internal app route, and any other authority is untrusted input. These
    // cases pin all three (#6733/#7074).
    group('Custom-Scheme App Routes', () {
      test('routes the authority-less saved-videos link', () {
        final result = DeepLinkService.parseDeepLink(
          'divine:///saved-videos',
        );

        expect(result.type, equals(DeepLinkType.savedVideos));
      });

      test('rejects an authority-form saved-videos link', () {
        final result = DeepLinkService.parseDeepLink('divine://saved-videos');

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects a divine.video-host link', () {
        final result = DeepLinkService.parseDeepLink(
          'divine://divine.video/saved-videos',
        );

        expect(result.type, equals(DeepLinkType.unknown));
      });

      // Regression guard for #6733: an authority Divine never mints must not
      // inherit the signer-callback side effects (relay reconnection, and the
      // attacker-supplied relay that rides along with them).
      test('rejects an unrecognised authority instead of treating it as a '
          'callback', () {
        final result = DeepLinkService.parseDeepLink(
          'divine://attacker-controlled?relay=wss://evil.example',
        );

        expect(result.type, equals(DeepLinkType.unknown));
        expect(result.signerCallbackRelay, isNull);
      });

      test('rejects an unlisted app route instead of treating it as a '
          'callback', () {
        final result = DeepLinkService.parseDeepLink('divine:///settings');

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects a multi-segment app route', () {
        final result = DeepLinkService.parseDeepLink(
          'divine:///saved-videos/extra',
        );

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects the bare authority-less scheme', () {
        final result = DeepLinkService.parseDeepLink('divine:///');

        expect(result.type, equals(DeepLinkType.unknown));
      });
    });

    group('Unknown URL Patterns', () {
      test('ignores internal app route paths', () {
        const url = '/profile/npub1abc123def456';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects non-divine.video domain', () {
        const url = 'https://example.com/video/abc123';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects wrapped URL on non-divine host', () {
        const url =
            'https://slack-redir.net/link?url=https%3A%2F%2Fdivine.video%2Fprofile%2Fnpub1abc123def456';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects invalid path structure', () {
        const url = 'https://divine.video/unknown/path';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects root URL', () {
        const url = 'https://divine.video/';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('handles malformed URL gracefully', () {
        const url = 'not-a-valid-url';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('handles empty string gracefully', () {
        const url = '';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });
    });

    group('URL Scheme Handling', () {
      test('accepts http scheme', () {
        const videoId = 'abc123';
        const url = 'http://divine.video/video/$videoId';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoRef, equals(videoId));
      });

      test('accepts https scheme', () {
        const videoId = 'abc123';
        const url = 'https://divine.video/video/$videoId';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoRef, equals(videoId));
      });

      test('accepts www.divine.video host alias', () {
        const videoId = 'abc123';
        const url = 'https://www.divine.video/video/$videoId';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoRef, equals(videoId));
      });

      // Regression: an email verification link
      // (https://login.divine.video/verify-email?...) was previously
      // rejected with "Ignoring deep link from non-divine.video domain:
      // login.divine.video". Subdomains of divine.video are still part
      // of our deployment and must not be rejected at the host check.
      test('accepts login.divine.video subdomain', () {
        const videoId = 'abc123';
        const url = 'https://login.divine.video/video/$videoId';

        final result = DeepLinkService.parseDeepLink(url);

        expect(
          result.type,
          equals(DeepLinkType.video),
          reason:
              'Subdomains of divine.video must be accepted as Divine '
              'hosts. login.divine.video is the OAuth host used by '
              'verification deep links.',
        );
        expect(result.videoRef, equals(videoId));
      });

      test('accepts arbitrary subdomain of divine.video', () {
        const videoId = 'abc123';
        const url = 'https://staging.divine.video/video/$videoId';

        final result = DeepLinkService.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoRef, equals(videoId));
      });

      test('rejects lookalike domain (divine.video.evil.com)', () {
        const url = 'https://divine.video.evil.com/video/abc123';

        final result = DeepLinkService.parseDeepLink(url);

        expect(
          result.type,
          equals(DeepLinkType.unknown),
          reason:
              'Hosts that merely contain "divine.video" as a non-suffix '
              'must still be rejected.',
        );
      });

      test('rejects domain that ends with divine.video without separator '
          '(notdivine.video)', () {
        const url = 'https://notdivine.video/video/abc123';

        final result = DeepLinkService.parseDeepLink(url);

        expect(
          result.type,
          equals(DeepLinkType.unknown),
          reason:
              'Only divine.video and *.divine.video should be '
              'accepted; sibling domains must not match.',
        );
      });
    });

    group('DeepLink Data Class', () {
      test('creates video deep link with correct data', () {
        const deepLink = DeepLink(
          type: DeepLinkType.video,
          videoRef: 'test123',
        );

        expect(deepLink.type, equals(DeepLinkType.video));
        expect(deepLink.videoRef, equals('test123'));
        expect(deepLink.npub, isNull);
      });

      test('creates profile deep link with correct data', () {
        const deepLink = DeepLink(type: DeepLinkType.profile, npub: 'npub123');

        expect(deepLink.type, equals(DeepLinkType.profile));
        expect(deepLink.npub, equals('npub123'));
        expect(deepLink.videoRef, isNull);
      });

      test('creates unknown deep link with no data', () {
        const deepLink = DeepLink(type: DeepLinkType.unknown);

        expect(deepLink.type, equals(DeepLinkType.unknown));
        expect(deepLink.videoRef, isNull);
        expect(deepLink.npub, isNull);
      });

      test('creates hashtag deep link with index', () {
        const deepLink = DeepLink(
          type: DeepLinkType.hashtag,
          hashtag: 'art',
          index: 2,
        );

        expect(deepLink.type, equals(DeepLinkType.hashtag));
        expect(deepLink.hashtag, equals('art'));
        expect(deepLink.index, equals(2));
      });

      test('creates search deep link', () {
        const deepLink = DeepLink(
          type: DeepLinkType.search,
          searchTerm: 'test',
        );

        expect(deepLink.type, equals(DeepLinkType.search));
        expect(deepLink.searchTerm, equals('test'));
      });
    });

    group('$DeepLink toString', () {
      test('formats video deep link', () {
        const link = DeepLink(type: DeepLinkType.video, videoRef: 'abc');
        expect(link.toString(), equals('DeepLink(type: video, videoRef: abc)'));
      });

      test('formats list deep link with full untruncated pubkey', () {
        const pubkey =
            'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
        const link = DeepLink(
          type: DeepLinkType.list,
          listPubkey: pubkey,
          listId: 'my-vines',
        );
        expect(
          link.toString(),
          equals('DeepLink(type: list, listPubkey: $pubkey, listId: my-vines)'),
        );
      });

      test('formats profile deep link with index', () {
        const link = DeepLink(
          type: DeepLinkType.profile,
          npub: 'npub1x',
          index: 2,
        );
        expect(
          link.toString(),
          equals('DeepLink(type: profile, npub: npub1x, index: 2)'),
        );
      });

      test('formats saved videos deep link', () {
        const link = DeepLink(type: DeepLinkType.savedVideos);
        expect(link.toString(), equals('DeepLink(type: savedVideos)'));
      });

      test('formats hashtag deep link', () {
        const link = DeepLink(type: DeepLinkType.hashtag, hashtag: 'art');
        expect(
          link.toString(),
          equals('DeepLink(type: hashtag, hashtag: art)'),
        );
      });

      test('formats search deep link', () {
        const link = DeepLink(type: DeepLinkType.search, searchTerm: 'q');
        expect(
          link.toString(),
          equals('DeepLink(type: search, searchTerm: q)'),
        );
      });

      test('formats unknown deep link', () {
        const link = DeepLink(type: DeepLinkType.unknown);
        expect(link.toString(), equals('DeepLink(type: unknown)'));
      });
    });
  });
}
