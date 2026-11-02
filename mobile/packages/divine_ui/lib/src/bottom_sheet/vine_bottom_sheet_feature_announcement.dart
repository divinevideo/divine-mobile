// ABOUTME: Bottom sheet that announces a new feature: illustration, "New"
// ABOUTME: badge, headline, subtitle, feature rows, and action buttons.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// One benefit listed in a [VineBottomSheetFeatureAnnouncement].
@immutable
class VineFeatureAnnouncementItem {
  /// Creates a [VineFeatureAnnouncementItem].
  const VineFeatureAnnouncementItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  /// Icon shown at the start of the row.
  final DivineIconName icon;

  /// Short title of the benefit.
  final String title;

  /// One line explaining what the user gets.
  final String description;
}

/// A bottom sheet that announces a new feature, for example the first time
/// the app opens after an update.
///
/// From top to bottom it shows a free-form [illustration], an optional
/// [badgeLabel] (such as "New"), a [title], an optional [subtitle], up to a
/// few [features] rows, a primary action and an optional secondary action.
///
/// Can be used as a widget directly or shown as a modal via
/// [VineBottomSheetFeatureAnnouncement.show].
///
/// ```dart
/// final navigator = Navigator.of(context);
/// await VineBottomSheetFeatureAnnouncement.show<void>(
///   context: context,
///   illustration: const DivineSticker(sticker: DivineStickerName.sparkle),
///   badgeLabel: 'New',
///   title: 'Captions',
///   subtitle: 'Read along, even with the sound off.',
///   features: const [
///     VineFeatureAnnouncementItem(
///       icon: DivineIconName.closedCaptioning,
///       title: 'Turn them on anytime',
///       description: 'Tap CC on any video that has captions.',
///     ),
///   ],
///   primaryButtonText: 'Got it',
///   onPrimaryPressed: () => navigator.pop(),
/// );
/// ```
class VineBottomSheetFeatureAnnouncement extends StatelessWidget {
  /// Creates a [VineBottomSheetFeatureAnnouncement].
  const VineBottomSheetFeatureAnnouncement({
    required this.illustration,
    required this.title,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    this.badgeLabel,
    this.subtitle,
    this.features = const [],
    this.secondaryButtonText,
    this.onSecondaryPressed,
    super.key,
  }) : assert(
         (secondaryButtonText == null) == (onSecondaryPressed == null),
         'secondaryButtonText and onSecondaryPressed must both be provided '
         'or both be null',
       );

  /// Artwork shown at the top. Treated as decorative and hidden from screen
  /// readers.
  final Widget illustration;

  /// Optional short label above the title, shown with a sparkle icon.
  final String? badgeLabel;

  /// Name of the feature.
  final String title;

  /// Optional one-line pitch below the title.
  final String? subtitle;

  /// Benefits listed below the title.
  final List<VineFeatureAnnouncementItem> features;

  /// Label for the primary action, usually the dismiss action.
  final String primaryButtonText;

  /// Callback for the primary action. The sheet does not close itself; pop it
  /// here when the action should dismiss it.
  final VoidCallback onPrimaryPressed;

  /// Optional label for a secondary action, such as trying the feature.
  final String? secondaryButtonText;

  /// Callback for the secondary action. The sheet does not close itself.
  final VoidCallback? onSecondaryPressed;

  /// Shows the announcement as a fixed modal bottom sheet.
  ///
  /// Completes with the value a callback pops, or null when the user taps the
  /// scrim or drags the sheet down, which calls neither callback. Read the
  /// [NavigatorState] before calling this, as the class example does: the
  /// caller's context can unmount while the sheet is open.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget illustration,
    required String title,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    String? badgeLabel,
    String? subtitle,
    List<VineFeatureAnnouncementItem> features = const [],
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
  }) {
    return VineBottomSheet.show<T>(
      context: context,
      scrollable: false,
      showHeaderDivider: false,
      body: VineBottomSheetFeatureAnnouncement(
        illustration: illustration,
        badgeLabel: badgeLabel,
        title: title,
        subtitle: subtitle,
        features: features,
        primaryButtonText: primaryButtonText,
        onPrimaryPressed: onPrimaryPressed,
        secondaryButtonText: secondaryButtonText,
        onSecondaryPressed: onSecondaryPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;

    return SingleChildScrollView(
      padding: .fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          ExcludeSemantics(child: illustration),
          const SizedBox(height: 32),
          if (badgeLabel != null) ...[
            _Badge(label: badgeLabel!),
            const SizedBox(height: 8),
          ],
          Semantics(
            header: true,
            child: Text(
              title,
              style: VineTheme.headlineLargeFont(color: colors.primaryText),
              textAlign: .center,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: VineTheme.bodyLargeFont(color: colors.onSurfaceVariant),
              textAlign: .center,
            ),
          ],
          if (features.isNotEmpty) ...[
            const SizedBox(height: 32),
            Padding(
              padding: const .symmetric(horizontal: 16),
              child: Column(
                spacing: 24,
                children: [
                  for (final feature in features) _FeatureRow(feature: feature),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          DivineButton(
            label: primaryButtonText,
            onPressed: onPrimaryPressed,
            expanded: true,
          ),
          if (secondaryButtonText != null) ...[
            const SizedBox(height: 16),
            DivineButton(
              label: secondaryButtonText!,
              onPressed: onSecondaryPressed,
              type: DivineButtonType.secondary,
              expanded: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.vineColors.accentPositive;

    return Row(
      mainAxisSize: .min,
      spacing: 4,
      children: [
        ExcludeSemantics(
          child: DivineIcon(
            icon: DivineIconName.sparkle,
            size: 16,
            color: color,
          ),
        ),
        Flexible(
          child: Text(
            label,
            style: VineTheme.labelLargeFont(color: color),
            textAlign: .center,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final VineFeatureAnnouncementItem feature;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;

    return MergeSemantics(
      child: Row(
        crossAxisAlignment: .start,
        spacing: 16,
        children: [
          ExcludeSemantics(
            child: DivineIcon(icon: feature.icon, color: colors.onSurface),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 4,
              children: [
                Text(
                  feature.title,
                  style: VineTheme.titleMediumFont(color: colors.primaryText),
                ),
                Text(
                  feature.description,
                  style: VineTheme.bodyMediumFont(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
