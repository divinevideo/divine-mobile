import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/features/challenges/challenge_link.dart';
import 'package:openvine/features/challenges/challenge_test_build.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/services/deep_link_service.dart';

void main() {
  final owner = 'ab' * 32;
  String address(int kind) => NIP19Tlv.encodeNaddr(
    Naddr(
      id: 'synthetic:challenge',
      author: owner,
      kind: kind,
      relays: ['wss://relay.example.test'],
    ),
  );
  group('challenge_link', () {
    test('preserves full coordinate and relay hints through links', () {
      final naddr = address(31923);
      final link = ChallengeLink.parse(naddr)!;
      expect(link.coordinate, '31923:$owner:synthetic:challenge');
      expect(link.relays, ['wss://relay.example.test']);
      for (final uri in [
        'https://divine.video/challenges/$naddr',
        'https://www.divine.video/challenges/$naddr',
        'divine:///challenges/$naddr',
      ]) {
        final parsed = DeepLinkService.parseDeepLink(uri);
        expect(
          parsed.type,
          challengesTestEnabled ? DeepLinkType.challenge : DeepLinkType.unknown,
        );
        expect(
          deepLinkRouterPath(parsed),
          challengesTestEnabled ? '/challenges/$naddr' : null,
        );
      }
      expect(
        customSchemeToRouterPath(Uri.parse('divine:///challenges/$naddr')),
        challengesTestEnabled ? '/challenges/$naddr' : null,
      );
    });
    test('production manifest does not claim challenge HTTPS paths', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, isNot(contains('/challenges')));
    });
    test('does not route other addressable kinds or damaged naddr', () {
      expect(ChallengeLink.parse(address(30023)), isNull);
      expect(ChallengeLink.parse('${address(31923)}x'), isNull);
      for (final invalid in [address(30023), '${address(31923)}x', 'invalid']) {
        expect(
          customSchemeToRouterPath(Uri.parse('divine:///challenges/$invalid')),
          isNull,
        );
      }
      expect(
        DeepLinkService.parseDeepLink(
          'https://divine.video/challenges/${address(30023)}',
        ).type,
        DeepLinkType.unknown,
      );
    });
  });
}
