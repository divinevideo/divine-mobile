// ABOUTME: Extensions for text editor types to provide icons and accessibility names.
// ABOUTME: Used by the text editor style bar and potentially other text editor widgets.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/utils/editor_text_fonts.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Extension on [TextFont] for text editor UI purposes.
extension TextEditorFont on TextFont {
  /// Returns the display name of this font, or `null` when it has no family
  /// name.
  ///
  /// An editor-catalogue font resolves to its published Google Fonts family
  /// name ("Shadows Into Light") rather than the squashed `fontFamily`
  /// identifier ("ShadowsIntoLight_regular"). Anything else falls back to its
  /// `fontFamily` with the "_regular" suffix removed and underscores converted
  /// to spaces.
  String? get _resolvedDisplayName {
    final googleFontName = googleFontFamilyName(this);
    if (googleFontName != null) return googleFontName;
    final fontFamily = this().fontFamily;
    if (fontFamily == null) return null;
    return fontFamily
        .replaceAll(RegExp(r'_regular$', caseSensitive: false), '')
        .replaceAll('_', ' ');
  }

  /// Returns the display name of this font.
  String get displayName => _resolvedDisplayName ?? 'Unknown';

  /// Returns the localized display name, using [l10n] for the unknown fallback.
  String localizedDisplayName(AppLocalizations l10n) =>
      _resolvedDisplayName ?? l10n.videoEditorFontUnknown;
}

/// Extension on [TextAlign] for text editor UI purposes.
extension TextEditorTextAlign on TextAlign {
  /// Returns the icon for this alignment.
  DivineIconName get icon => switch (this) {
    TextAlign.left || TextAlign.start => .textAlignLeft,
    TextAlign.right || TextAlign.end => .textAlignRight,
    _ => .textAlignCenter,
  };

  /// Returns the localized accessibility name for this alignment.
  String localizedAccessibilityName(AppLocalizations l10n) => switch (this) {
    TextAlign.left || TextAlign.start => l10n.textAlignLeft,
    TextAlign.right || TextAlign.end => l10n.textAlignRight,
    _ => l10n.textAlignCenter,
  };
}

/// Extension on [LayerBackgroundMode] for text editor UI purposes.
extension TextEditorBackgroundMode on LayerBackgroundMode {
  /// Returns the icon for this background mode.
  DivineIconName get icon => switch (this) {
    LayerBackgroundMode.onlyColor => .textBgNone,
    LayerBackgroundMode.backgroundAndColor => .textBgFill,
    LayerBackgroundMode.background => .textBgFill,
    LayerBackgroundMode.backgroundAndColorWithOpacity => .textBgTransparent,
  };

  /// Returns the localized accessibility name for this background mode.
  String localizedAccessibilityName(AppLocalizations l10n) => switch (this) {
    LayerBackgroundMode.onlyColor => l10n.textBackgroundNone,
    LayerBackgroundMode.backgroundAndColor => l10n.textBackgroundSolid,
    LayerBackgroundMode.background => l10n.textBackgroundHighlight,
    LayerBackgroundMode.backgroundAndColorWithOpacity =>
      l10n.textBackgroundTransparent,
  };
}
