// ABOUTME: Maps NotificationKind to the (icon, background, foreground)
// ABOUTME: triple used by the leading 32×32 type indicator on every row.
//
// Single source of truth for the design contract. Adding a new
// NotificationKind is a compile error here — and a regression test in
// notification_type_icon_spec_test.dart locks the mapping so it can't
// silently drift again.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:models/models.dart';

/// Triple (icon, background, foreground) consumed by [NotificationTypeIcon].
class NotificationTypeIconSpec {
  const NotificationTypeIconSpec({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final DivineIconName icon;
  final Color background;
  final Color foreground;
}

/// Returns the spec for [type] used by both row widgets.
///
/// [colors] is the resolved palette of the active appearance mode, so the
/// accent chips follow light mode instead of staying on the dark tints.
NotificationTypeIconSpec notificationTypeIconSpec(
  NotificationKind type, {
  required VineThemeColors colors,
  bool isVideoSourcedMention = false,
}) {
  if (type == NotificationKind.mention && isVideoSourcedMention) {
    return NotificationTypeIconSpec(
      icon: DivineIconName.videoCamera,
      background: colors.accentChipViolet.container,
      foreground: colors.accentChipViolet.onContainer,
    );
  }
  return switch (type) {
    NotificationKind.like ||
    NotificationKind.likeComment => NotificationTypeIconSpec(
      icon: DivineIconName.heart,
      background: colors.accentChipPink.container,
      foreground: colors.accentChipPink.onContainer,
    ),
    NotificationKind.follow => NotificationTypeIconSpec(
      icon: DivineIconName.user,
      background: colors.accentChipLime.container,
      foreground: colors.accentChipLime.onContainer,
    ),
    NotificationKind.comment ||
    NotificationKind.reply ||
    NotificationKind.mention => NotificationTypeIconSpec(
      icon: DivineIconName.chat,
      background: colors.accentChipViolet.container,
      foreground: colors.accentChipViolet.onContainer,
    ),
    NotificationKind.repost => NotificationTypeIconSpec(
      icon: DivineIconName.repeat,
      background: colors.accentChipYellow.container,
      foreground: colors.accentChipYellow.onContainer,
    ),
    NotificationKind.newPost => NotificationTypeIconSpec(
      icon: DivineIconName.bellSimple,
      background: colors.accentChipBlue.container,
      foreground: colors.accentChipBlue.onContainer,
    ),
    NotificationKind.listAdd => NotificationTypeIconSpec(
      icon: DivineIconName.listPlus,
      background: colors.accentChipYellow.container,
      foreground: colors.accentChipYellow.onContainer,
    ),
    NotificationKind.announcement ||
    NotificationKind.system => NotificationTypeIconSpec(
      icon: DivineIconName.logo,
      background: colors.accentChipGreen.container,
      foreground: colors.accentChipGreen.onContainer,
    ),
  };
}
