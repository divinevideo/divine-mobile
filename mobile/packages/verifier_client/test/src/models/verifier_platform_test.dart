// ABOUTME: VerifierPlatform tests — parsing, defaults and OAuth capability.

import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

void main() {
  group(VerifierPlatform, () {
    test('parses label and supported from the platform entry', () {
      final platform = VerifierPlatform.fromJson('github', const {
        'label': 'GitHub',
        'supported': true,
      });

      expect(platform.key, equals('github'));
      expect(platform.label, equals('GitHub'));
      expect(platform.supported, isTrue);
    });

    test('falls back to the key and unsupported on a bare entry', () {
      final platform = VerifierPlatform.fromJson(
        'mystery',
        const <String, dynamic>{},
      );

      expect(platform.label, equals('mystery'));
      expect(platform.supported, isFalse);
    });

    test('reads oauth when the verifier reports it', () {
      final on = VerifierPlatform.fromJson('bluesky', const {
        'label': 'Bluesky',
        'supported': true,
        'oauth': true,
      });
      final off = VerifierPlatform.fromJson('twitter', const {
        'label': 'Twitter / X',
        'supported': true,
        'oauth': false,
      });

      expect(on.oauth, isTrue);
      expect(off.oauth, isFalse);
    });

    test('leaves oauth unknown when the entry has none', () {
      final platform = VerifierPlatform.fromJson('github', const {
        'label': 'GitHub',
        'supported': true,
      });

      expect(platform.oauth, isNull);
    });

    test('treats an oauth value that is not a bool as unknown', () {
      for (final value in <Object?>['false', 0, 1, 'true', null, <String>[]]) {
        final platform = VerifierPlatform.fromJson('twitter', {
          'label': 'Twitter / X',
          'supported': true,
          'oauth': value,
        });

        expect(platform.oauth, isNull, reason: 'oauth: $value');
      }
    });

    test('offers sign-in only where the verifier has it on', () {
      const off = VerifierPlatform(
        key: 'twitter',
        label: 'Twitter / X',
        supported: true,
        oauth: false,
      );
      const on = VerifierPlatform(
        key: 'bluesky',
        label: 'Bluesky',
        supported: true,
        oauth: true,
      );

      expect(off.supportsOAuth, isFalse);
      expect(on.supportsOAuth, isTrue);
    });

    test('never offers sign-in for a platform the app has no flow for', () {
      // The app can only start the sign-ins in oauthPlatforms, so a verifier
      // reporting one elsewhere still leaves the proof post as the way in.
      const platform = VerifierPlatform(
        key: 'github',
        label: 'GitHub',
        supported: true,
        oauth: true,
      );

      expect(platform.supportsOAuth, isFalse);
    });

    test('never offers sign-in for a platform the verifier does not '
        'support', () {
      // A verifier older than the flag reports TikTok unsupported exactly
      // when its sign-in is off, and an unsupported platform can't link.
      for (final oauth in [null, true]) {
        final platform = VerifierPlatform(
          key: 'tiktok',
          label: 'TikTok',
          supported: false,
          oauth: oauth,
        );

        expect(platform.supportsOAuth, isFalse, reason: 'oauth: $oauth');
      }
    });

    test('reports OAuth capability per platform when the verifier says '
        'nothing', () {
      const oauth = VerifierPlatform(
        key: 'twitter',
        label: 'Twitter / X',
        supported: true,
      );
      const proofOnly = VerifierPlatform(
        key: 'mastodon',
        label: 'Mastodon',
        supported: true,
      );

      expect(oauth.supportsOAuth, isTrue);
      expect(proofOnly.supportsOAuth, isFalse);
    });

    test('compares by value', () {
      const a = VerifierPlatform(
        key: 'github',
        label: 'GitHub',
        supported: true,
      );
      const b = VerifierPlatform(
        key: 'github',
        label: 'GitHub',
        supported: true,
      );
      const c = VerifierPlatform(
        key: 'github',
        label: 'GitHub',
        supported: false,
      );
      const d = VerifierPlatform(
        key: 'github',
        label: 'GitHub',
        supported: true,
        oauth: false,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });
  });
}
