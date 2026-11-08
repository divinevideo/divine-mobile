// ABOUTME: Tests relay URL admission, identity and Divine-host classification.
// ABOUTME: Also pins the notification REST base resolved from relays.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/relay_url_utils.dart';

void main() {
  group('isLoopbackHost', () {
    test('accepts canonical loopback names and addresses', () {
      expect(isLoopbackHost('localhost'), isTrue);
      expect(isLoopbackHost('127.0.0.1'), isTrue);
      expect(isLoopbackHost('10.0.2.2'), isTrue);
      expect(isLoopbackHost('::1'), isTrue);
    });

    test('is case-insensitive', () {
      expect(isLoopbackHost('LOCALHOST'), isTrue);
      expect(isLoopbackHost('LocalHost'), isTrue);
    });

    test('rejects non-loopback hosts', () {
      expect(isLoopbackHost('relay.example.com'), isFalse);
      expect(isLoopbackHost('attacker.example.com'), isFalse);
      expect(isLoopbackHost(''), isFalse);
    });

    test('rejects suffix-match attacks on loopback hostname', () {
      expect(isLoopbackHost('localhost.attacker.example.com'), isFalse);
      expect(isLoopbackHost('mylocalhost'), isFalse);
    });
  });

  group('isRelayUrlAllowed', () {
    test('accepts wss:// for any host', () {
      expect(isRelayUrlAllowed('wss://relay.divine.video'), isTrue);
      expect(isRelayUrlAllowed('wss://relay.example.com:8443'), isTrue);
      expect(isRelayUrlAllowed('wss://relay.divine.video/path'), isTrue);
    });

    test('accepts ws:// for loopback hosts only', () {
      expect(isRelayUrlAllowed('ws://localhost:47777'), isTrue);
      expect(isRelayUrlAllowed('ws://127.0.0.1:8080'), isTrue);
      expect(isRelayUrlAllowed('ws://10.0.2.2:47777'), isTrue);
      expect(isRelayUrlAllowed('ws://[::1]:8080'), isTrue);
    });

    test('rejects https:// (relays are WebSocket-only)', () {
      // NIP-65 only ever advertises WS endpoints, and `normalizeRelayUrl`
      // only accepts WS — so an https:// URL is not a
      // usable relay regardless of host. The capability service derives
      // its NIP-11 fetch URL from the WS form internally.
      expect(isRelayUrlAllowed('https://relay.divine.video'), isFalse);
      expect(isRelayUrlAllowed('https://relay.example.com'), isFalse);
      expect(isRelayUrlAllowed('https://localhost:47777'), isFalse);
    });

    test('rejects http:// (relays are WebSocket-only)', () {
      expect(isRelayUrlAllowed('http://attacker.example.com'), isFalse);
      expect(isRelayUrlAllowed('http://relay.example.com'), isFalse);
      // Loopback http:// is also rejected — relays speak WS, not HTTP.
      expect(isRelayUrlAllowed('http://localhost:47777'), isFalse);
      expect(isRelayUrlAllowed('http://10.0.2.2:8787'), isFalse);
    });

    test('rejects ws:// to non-loopback hosts', () {
      expect(isRelayUrlAllowed('ws://attacker.example.com'), isFalse);
      expect(isRelayUrlAllowed('ws://relay.example.com:8443'), isFalse);
      // Suffix-match attack: must check exact host equality.
      expect(isRelayUrlAllowed('ws://localhost.attacker.com'), isFalse);
    });

    test('is case-insensitive on scheme and host', () {
      expect(isRelayUrlAllowed('WSS://relay.example.com'), isTrue);
      expect(isRelayUrlAllowed('WS://Localhost:8080'), isTrue);
    });

    test('trims surrounding whitespace', () {
      expect(isRelayUrlAllowed('  wss://relay.example.com  '), isTrue);
      expect(isRelayUrlAllowed('\tws://attacker.example.com\n'), isFalse);
    });

    test('rejects unsupported and missing schemes', () {
      expect(isRelayUrlAllowed('ftp://relay.example.com'), isFalse);
      expect(isRelayUrlAllowed('relay.example.com'), isFalse);
      expect(isRelayUrlAllowed('bunker://pubkey'), isFalse);
    });

    test('rejects malformed and empty input', () {
      expect(isRelayUrlAllowed(''), isFalse);
      expect(isRelayUrlAllowed('wss://'), isFalse);
      expect(isRelayUrlAllowed('not a url'), isFalse);
    });

    test('rejects mis-nested scheme prefixes (#3362 review follow-up)', () {
      // `wss://http://x` parses with host=`http` and path=`//x`; without
      // the path-starts-with-`//` guard, the predicate would accept it
      // (scheme=wss) and the URL would route to the wrong host
      // downstream. The guard also covers `wss://wss://x` (smuggled
      // double-prefix) and `wss://https://x` (cleartext under wss
      // wrapper).
      expect(isRelayUrlAllowed('wss://http://attacker.example.com'), isFalse);
      expect(isRelayUrlAllowed('wss://https://attacker.example.com'), isFalse);
      expect(isRelayUrlAllowed('wss://wss://relay.example.com'), isFalse);
      expect(isRelayUrlAllowed('wss://WSS://relay.example.com'), isFalse);
      expect(isRelayUrlAllowed('ws://http://attacker.example.com'), isFalse);
    });

    test('canonical loopback set (#3362 drift sentinel)', () {
      // Mirrored in:
      //  - mobile/packages/nostr_sdk/test/unit/nostr_remote_signer_info_test.dart
      //  - mobile/packages/nostr_client/test/src/relay_manager_test.dart
      // and `mobile/android/app/src/main/res/xml/network_security_config.xml`.
      // Diverging this set without updating the others is a security
      // regression.
      expect(isRelayUrlAllowed('ws://localhost:1'), isTrue);
      expect(isRelayUrlAllowed('ws://127.0.0.1:1'), isTrue);
      expect(isRelayUrlAllowed('ws://10.0.2.2:1'), isTrue);
      expect(isRelayUrlAllowed('ws://[::1]:1'), isTrue);
      expect(isRelayUrlAllowed('ws://example.com'), isFalse);
    });
  });

  group('normalizeRelayUrlForComparison', () {
    test('matches relay manager identity normalization', () {
      expect(
        normalizeRelayUrlForComparison('  relay.example.com/path/  '),
        'wss://relay.example.com/path',
      );
      expect(
        normalizeRelayUrlForComparison('WSS://relay.example.com/'),
        'wss://relay.example.com',
      );
      expect(
        normalizeRelayUrlForComparison('ws://localhost:47777/'),
        'ws://localhost:47777',
      );
    });

    test('rejects URLs the relay manager rejects', () {
      expect(normalizeRelayUrlForComparison(''), isNull);
      expect(
        normalizeRelayUrlForComparison('https://relay.example.com'),
        isNull,
      );
      expect(normalizeRelayUrlForComparison('ws://relay.example.com'), isNull);
      expect(
        normalizeRelayUrlForComparison('wss://http://attacker.example.com'),
        isNull,
      );
    });
  });

  group('relayWsToHttpBase', () {
    test('keeps generic relay host conversion unchanged', () {
      expect(
        relayWsToHttpBase('wss://relay.divine.video'),
        'https://relay.divine.video',
      );
    });
  });

  group('resolvePinnedApiBaseUrlFromRelays', () {
    test('resolves relay.divine.video to its HTTP base for notifications', () {
      expect(
        resolvePinnedApiBaseUrlFromRelays(
          configuredRelays: const ['wss://relay.divine.video'],
          fallbackBaseUrl: 'https://fallback.example.com',
        ),
        'https://relay.divine.video',
      );
    });

    test('returns fallback when divine relay is absent', () {
      expect(
        resolvePinnedApiBaseUrlFromRelays(
          configuredRelays: const ['wss://relay.damus.io'],
          fallbackBaseUrl: 'https://relay.staging.divine.video',
        ),
        'https://relay.staging.divine.video',
      );
    });
  });

  group('resolvePinnedApiBaseUrlFromRelays', () {
    test(
      'keeps staging notifications on the staging relay when production relay is persisted',
      () {
        expect(
          resolvePinnedApiBaseUrlFromRelays(
            configuredRelays: const [
              'wss://relay.staging.divine.video',
              'wss://relay.divine.video',
            ],
            fallbackBaseUrl: 'https://relay.staging.divine.video',
          ),
          'https://relay.staging.divine.video',
        );
      },
    );
  });

  group('isDivineHostedRelayUrl', () {
    test('accepts every Divine-operated relay host', () {
      expect(isDivineHostedRelayUrl('wss://relay.divine.video'), isTrue);
      expect(
        isDivineHostedRelayUrl('wss://relay.staging.divine.video'),
        isTrue,
      );
      expect(isDivineHostedRelayUrl('wss://relay.poc.dvines.org'), isTrue);
    });

    test('accepts loopback relays (local environment)', () {
      expect(isDivineHostedRelayUrl('ws://10.0.2.2:47777'), isTrue);
      expect(isDivineHostedRelayUrl('ws://localhost:47777'), isTrue);
    });

    test('rejects non-Divine relays', () {
      expect(isDivineHostedRelayUrl('wss://purplepag.es'), isFalse);
      expect(isDivineHostedRelayUrl('wss://relay.nos.social'), isFalse);
      expect(isDivineHostedRelayUrl('wss://relay.example.com'), isFalse);
    });

    test('rejects suffix-match attacks on a Divine host', () {
      expect(
        isDivineHostedRelayUrl('wss://relay.divine.video.attacker.example'),
        isFalse,
      );
    });

    test('rejects malformed URLs', () {
      expect(isDivineHostedRelayUrl(''), isFalse);
      expect(isDivineHostedRelayUrl('http://example.com'), isFalse);
    });
  });

  group('usesUserChosenRelay', () {
    const defaultRelayUrls = [
      'wss://purplepag.es',
      'wss://relay.nos.social',
      'wss://relay.damus.io',
      'wss://nos.lol',
    ];

    test('false when every relay is Divine-hosted', () {
      expect(
        usesUserChosenRelay(
          const [
            'wss://relay.divine.video',
            'wss://relay.staging.divine.video',
          ],
          defaultRelayUrls: defaultRelayUrls,
        ),
        isFalse,
      );
    });

    test('false for a fresh account seeded with app default relays', () {
      // Divine relay + auto-seeded indexer/fallback relays — none user-chosen.
      expect(
        usesUserChosenRelay(
          const [
            'wss://relay.divine.video',
            'wss://purplepag.es',
            'wss://relay.nos.social',
            'wss://nos.lol',
          ],
          defaultRelayUrls: defaultRelayUrls,
        ),
        isFalse,
      );
    });

    test('true when a relay outside Divine and the defaults is configured', () {
      expect(
        usesUserChosenRelay(
          const [
            'wss://relay.divine.video',
            'wss://my-personal-relay.example',
          ],
          defaultRelayUrls: defaultRelayUrls,
        ),
        isTrue,
      );
    });

    test('false for an empty relay set', () {
      expect(
        usesUserChosenRelay(const [], defaultRelayUrls: defaultRelayUrls),
        isFalse,
      );
    });
  });
}
