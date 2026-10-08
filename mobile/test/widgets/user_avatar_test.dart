// ABOUTME: Tests for the UserAvatar placeholder helpers other surfaces reuse:
// ABOUTME: the seed-to-tone rule and the per-tone fill/figure palette.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/user_avatar.dart';

void main() {
  group('userAvatarToneForSeed', () {
    test('gives the same seed the same tone', () {
      final pubkey = 'a' * 64;
      expect(userAvatarToneForSeed(pubkey), userAvatarToneForSeed(pubkey));
    });

    test('spreads different seeds across more than one tone', () {
      final tones = {
        for (var i = 0; i < 16; i++) userAvatarToneForSeed('seed-$i'),
      };
      expect(tones.length, greaterThan(1));
      expect(tones, isNot(contains(UserAvatarPlaceholderTone.auto)));
    });

    test('lands an empty seed on the first tone', () {
      expect(userAvatarToneForSeed(''), UserAvatarPlaceholderTone.yellow);
    });
  });

  group('userAvatarPlaceholderColors', () {
    test('pairs each accent with a figure ink that is not white', () {
      for (final tone in UserAvatarPlaceholderTone.values) {
        final colors = userAvatarPlaceholderColors(tone);
        expect(colors.figure, isNot(VineTheme.whiteText), reason: '$tone');
        expect(colors.figure, isNot(colors.base), reason: '$tone');
      }
    });

    test('keeps the lime fill on the lime tone', () {
      expect(
        userAvatarPlaceholderColors(UserAvatarPlaceholderTone.lime).base,
        VineTheme.accentLime,
      );
    });
  });
}
