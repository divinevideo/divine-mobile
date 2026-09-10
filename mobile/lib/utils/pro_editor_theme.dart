// ABOUTME: Rebuilds the app's theme as the material_ui ThemeData that
// ABOUTME: pro_image_editor's own chrome needs since its 14.0.0 migration

import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as material_ui;

/// The app's current theme, expressed for pro_image_editor.
///
/// pro_image_editor 14.0.0 moved off `package:flutter/material.dart` onto the
/// standalone `material_ui` package, whose `ThemeData` is a different type from
/// the SDK's even though it holds the same values. Its editors still take a
/// theme, so the values are carried across by hand here rather than migrating
/// the app off the SDK's Material library.
///
/// Only pro_image_editor's own chrome reads this. The app's widgets inside an
/// editor — layer widgets, sticker and detached-clip views — keep resolving the
/// real app theme, because the `Theme` the editor wraps them in is
/// `material_ui`'s and does not shadow the SDK's. That is also why
/// [ThemeExtension]s such as `VineThemeColors` are not copied over: nothing
/// downstream of this theme looks for them.
material_ui.ThemeData proEditorTheme(BuildContext context) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  return material_ui.ThemeData(
    brightness: theme.brightness,
    scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
    colorScheme: material_ui.ColorScheme(
      brightness: colors.brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      error: colors.error,
      onError: colors.onError,
      surface: colors.surface,
      onSurface: colors.onSurface,
    ),
  );
}
