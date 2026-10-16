// ABOUTME: Pins that every platform the verifier offers gets its own proof
// ABOUTME: instructions, since none of them are guessable.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/verify/verify_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:profile_repository/profile_repository.dart';

/// Everything `GET /platforms` can return, per the verifier's registry.
const _allPlatforms = [
  'github',
  'twitter',
  'mastodon',
  'telegram',
  'bluesky',
  'discord',
  'youtube',
  'tiktok',
];

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('verifyProofExplainer', () {
    test('gives every supported platform its own instructions', () {
      final seen = <String, String>{};
      for (final platform in _allPlatforms) {
        final text = verifyProofExplainer(l10n, platform);
        expect(
          text,
          isNot(equals(l10n.verifyConnectProofExplainer)),
          reason: '$platform fell through to the generic instructions',
        );
        expect(
          seen,
          isNot(containsValue(text)),
          reason: '$platform reuses the instructions of ${seen[text]}',
        );
        seen[text] = platform;
      }
    });

    test('names the surface each verifier actually reads', () {
      // The verifier reads a gist's first file, not a repo or profile README.
      expect(verifyProofExplainer(l10n, 'github'), contains('first file'));
      // TikTok checks the caption, YouTube the description.
      expect(verifyProofExplainer(l10n, 'tiktok'), contains('caption'));
      expect(verifyProofExplainer(l10n, 'youtube'), contains('description'));
      // Telegram links the channel, which is the thing people get wrong.
      expect(verifyProofExplainer(l10n, 'telegram'), contains('channel'));
      expect(
        verifyProofExplainer(l10n, 'telegram'),
        contains('not your Telegram account'),
      );
      // Mastodon cannot find the server without the instance in the handle.
      expect(verifyProofExplainer(l10n, 'mastodon'), contains('instance'));
    });

    test('falls back for a platform added after this shipped', () {
      expect(
        verifyProofExplainer(l10n, 'somethingnew'),
        equals(l10n.verifyConnectProofExplainer),
      );
    });

    test('is case-insensitive on the platform key', () {
      expect(
        verifyProofExplainer(l10n, 'GitHub'),
        equals(verifyProofExplainer(l10n, 'github')),
      );
    });
  });

  group('verifyPlatformLabel', () {
    test('names every supported platform', () {
      for (final platform in _allPlatforms) {
        expect(verifyPlatformLabel(platform), isNotEmpty);
      }
      expect(verifyPlatformLabel('twitter'), equals('Twitter / X'));
    });

    test('falls back to the raw key so a new platform still shows', () {
      expect(verifyPlatformLabel('somethingnew'), equals('somethingnew'));
    });
  });

  group('input hints', () {
    test('cover every platform that needs a proof post', () {
      for (final platform in _allPlatforms) {
        expect(
          verifyIdentityHint(platform),
          isNotEmpty,
          reason: '$platform has no example handle',
        );
        expect(
          verifyProofHint(platform),
          isNotEmpty,
          reason: '$platform has no example proof',
        );
      }
    });

    // The verifier's own form placeholders, so web and app ask for the same
    // thing. Only reserved example names, never a name a real person may own.
    test('identity hints match the verifier form', () {
      expect(verifyIdentityHint('github'), 'octocat');
      expect(verifyIdentityHint('twitter'), 'example');
      expect(verifyIdentityHint('mastodon'), 'mastodon.social/@example');
      expect(verifyIdentityHint('telegram'), 'mychannel');
      expect(verifyIdentityHint('bluesky'), 'example.bsky.social');
      expect(verifyIdentityHint('youtube'), 'UC… or @channelhandle');
      expect(verifyIdentityHint('tiktok'), 'username');
    });

    // The verifier's Discord placeholder is an English phrase, and the hints
    // are not translated, so it would reach every locale in English.
    test('Discord asks for the reserved name, not an English phrase', () {
      expect(verifyIdentityHint('discord'), 'example');
    });

    test('proof hints use the same example names', () {
      expect(
        verifyProofHint('github'),
        'https://gist.github.com/octocat/abc123…',
      );
      expect(verifyProofHint('twitter'), 'https://x.com/example/status/123…');
      expect(
        verifyProofHint('mastodon'),
        'https://mastodon.social/@example/123…',
      );
      expect(verifyProofHint('telegram'), 'https://t.me/mychannel/123');
      expect(
        verifyProofHint('bluesky'),
        'https://bsky.app/profile/example.bsky.social/post/123…',
      );
      expect(verifyProofHint('discord'), 'https://discord.com/channels/…');
      expect(
        verifyProofHint('youtube'),
        'https://www.youtube.com/watch?v=…',
      );
      expect(
        verifyProofHint('tiktok'),
        'https://www.tiktok.com/@example/video/123…',
      );
    });
  });

  group('example names in translated copy', () {
    test('no locale teaches a real-looking account name', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final t = lookupAppLocalizations(locale);
        for (final text in [
          t.verifyConnectProofExplainerMastodon,
          t.verifyHowItWorksYourSide,
        ]) {
          expect(
            text.toLowerCase(),
            isNot(contains('alice')),
            reason: '${locale.languageCode} uses a name a real person may own',
          );
          expect(
            text,
            contains('example'),
            reason: '${locale.languageCode} lost the reserved example name',
          );
        }
      }
    });
  });

  group('oauthPlatforms', () {
    test('the OAuth platform set matches what the verifier exposes', () {
      // Mirrors the switch in the verifier's /auth/:platform/start.
      expect(
        VerifierPlatform.oauthPlatforms,
        equals({'twitter', 'bluesky', 'youtube', 'tiktok'}),
      );
    });
  });

  group('verifyIdentityFieldLabel', () {
    test('asks for a channel where the verifier matches a channel', () {
      // A channel post's author is the channel, so the user's own handle is
      // the one answer that can never verify.
      for (final platform in ['telegram', 'youtube']) {
        expect(
          verifyIdentityFieldLabel(l10n, platform),
          equals(l10n.verifyChannelLabel),
          reason: '$platform verifies a channel, not an account',
        );
      }
    });

    test('asks for an account everywhere else', () {
      for (final platform in [
        'github',
        'twitter',
        'mastodon',
        'bluesky',
        'discord',
        'tiktok',
      ]) {
        expect(
          verifyIdentityFieldLabel(l10n, platform),
          equals(l10n.verifyIdentityLabel),
          reason: '$platform verifies an account handle',
        );
      }
    });
  });

  group('verifyPlatformOrder', () {
    test('covers every platform the verifier offers', () {
      expect(verifyPlatformOrder.toSet(), equals(_allPlatforms.toSet()));
    });

    test('leads with the one-tap platforms', () {
      expect(
        verifyPlatformOrder
            .take(VerifierPlatform.oauthPlatforms.length)
            .toSet(),
        equals(VerifierPlatform.oauthPlatforms),
      );
    });

    test('names each platform once', () {
      expect(
        verifyPlatformOrder.toSet(),
        hasLength(verifyPlatformOrder.length),
      );
    });
  });
}
