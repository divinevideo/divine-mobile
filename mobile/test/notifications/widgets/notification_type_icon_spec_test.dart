// ABOUTME: Locks the NotificationKind → (icon, accent pair) design contract
// ABOUTME: so a future reskin can't silently drift the row palette.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/notifications/widgets/notification_type_icon_spec.dart';

void main() {
  group('notificationTypeIconSpec', () {
    const dark = VineTheme.darkColors;

    test('like uses heart on accentPink', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.like,
        colors: dark,
      );
      expect(spec.icon, equals(DivineIconName.heart));
      expect(spec.background, equals(dark.accentChipPink.container));
      expect(spec.foreground, equals(dark.accentChipPink.onContainer));
    });

    test('likeComment shares the heart accent with like', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.likeComment,
        colors: dark,
      );
      expect(spec.icon, equals(DivineIconName.heart));
      expect(spec.background, equals(dark.accentChipPink.container));
      expect(spec.foreground, equals(dark.accentChipPink.onContainer));
    });

    test('follow uses user on accentLime', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.follow,
        colors: dark,
      );
      expect(spec.icon, equals(DivineIconName.user));
      expect(spec.background, equals(dark.accentChipLime.container));
      expect(spec.foreground, equals(dark.accentChipLime.onContainer));
    });

    test('comment uses chat on accentViolet', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.comment,
        colors: dark,
      );
      expect(spec.icon, equals(DivineIconName.chat));
      expect(spec.background, equals(dark.accentChipViolet.container));
      expect(spec.foreground, equals(dark.accentChipViolet.onContainer));
    });

    test('reply shares the chat accent with comment', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.reply,
        colors: dark,
      );
      expect(spec.icon, equals(DivineIconName.chat));
      expect(spec.background, equals(dark.accentChipViolet.container));
      expect(spec.foreground, equals(dark.accentChipViolet.onContainer));
    });

    test('mention shares the chat accent with comment', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.mention,
        colors: dark,
      );
      expect(spec.icon, equals(DivineIconName.chat));
      expect(spec.background, equals(dark.accentChipViolet.container));
      expect(spec.foreground, equals(dark.accentChipViolet.onContainer));
    });

    test('video-sourced mention uses video camera on mention accent', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.mention,
        colors: dark,
        isVideoSourcedMention: true,
      );
      expect(spec.icon, equals(DivineIconName.videoCamera));
      expect(spec.background, equals(dark.accentChipViolet.container));
      expect(spec.foreground, equals(dark.accentChipViolet.onContainer));
    });

    test('repost uses repeat on accentYellow', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.repost,
        colors: dark,
      );
      expect(spec.icon, equals(DivineIconName.repeat));
      expect(spec.background, equals(dark.accentChipYellow.container));
      expect(spec.foreground, equals(dark.accentChipYellow.onContainer));
    });

    test('newPost uses bellSimple on accentBlue', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.newPost,
        colors: dark,
      );
      expect(spec.icon, equals(DivineIconName.bellSimple));
      expect(spec.background, equals(dark.accentChipBlue.container));
      expect(spec.foreground, equals(dark.accentChipBlue.onContainer));
    });

    test('listAdd uses listPlus on accentYellow', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.listAdd,
        colors: dark,
      );
      expect(spec.icon, equals(DivineIconName.listPlus));
      expect(spec.background, equals(dark.accentChipYellow.container));
      expect(spec.foreground, equals(dark.accentChipYellow.onContainer));
    });

    test('official announcements use the logo in both appearances', () {
      for (final colors in [VineTheme.darkColors, VineTheme.lightColors]) {
        final spec = notificationTypeIconSpec(
          NotificationKind.announcement,
          colors: colors,
        );
        expect(spec.icon, DivineIconName.logo);
        expect(spec.background, colors.accentChipGreen.container);
        expect(spec.foreground, colors.accentChipGreen.onContainer);
      }
    });

    test('system uses logo on the primary accent', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.system,
        colors: dark,
      );
      expect(spec.icon, equals(DivineIconName.logo));
      expect(spec.background, equals(dark.accentChipGreen.container));
      expect(spec.foreground, equals(dark.accentChipGreen.onContainer));
      // Dark parity: the chip must still resolve to the constants the
      // switch arm carried before it moved onto the palette.
      expect(spec.background, equals(VineTheme.onPrimaryButton));
      expect(spec.foreground, equals(VineTheme.primary));
    });

    test('the system chip follows the light palette', () {
      // It used to be the one arm left on dark-only constants, so on a light
      // notification row it rendered as a near-black blob while every other
      // chip lightened.
      final spec = notificationTypeIconSpec(
        NotificationKind.system,
        colors: VineTheme.lightColors,
      );
      expect(
        spec.background,
        equals(VineTheme.lightColors.accentChipGreen.container),
      );
      expect(spec.background, isNot(VineTheme.onPrimaryButton));
      expect(spec.foreground, isNot(VineTheme.primary));
    });

    test('the dark palette keeps the pre-light-mode accent constants', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.like,
        colors: dark,
      );
      expect(spec.background, equals(VineTheme.accentPinkBackground));
      expect(spec.foreground, equals(VineTheme.accentPink));
    });

    test('accent chips follow the light palette', () {
      final spec = notificationTypeIconSpec(
        NotificationKind.follow,
        colors: VineTheme.lightColors,
      );
      expect(
        spec.background,
        equals(VineTheme.lightColors.accentChipLime.container),
      );
      expect(
        spec.foreground,
        equals(VineTheme.lightColors.accentChipLime.onContainer),
      );
      expect(spec.background, isNot(VineTheme.accentLimeBackground));
    });

    test('every NotificationKind is covered by the switch', () {
      for (final kind in NotificationKind.values) {
        // Throws if any enum case were missing — the switch is exhaustive
        // by construction, but this ensures the contract still holds when
        // a future enum case is added without updating the helper.
        expect(
          notificationTypeIconSpec(kind, colors: dark),
          isA<NotificationTypeIconSpec>(),
        );
      }
    });
  });
}
