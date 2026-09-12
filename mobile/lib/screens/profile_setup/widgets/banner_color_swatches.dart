import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/color_swatch_button.dart';
// The full HSV picker the text editor's custom-colour flow opens. Shared on
// purpose: both pickers offer the same "any colour you like" escape hatch.
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';

/// Side of a swatch.
const double _swatchSize = 48;

/// The banner colours the picker offers.
///
/// These are the Divine accents — the same six the design system already
/// carries — in the order the design lays them out. Order is load-bearing for
/// the `profile_banner_color_swatch_preset_<index>` keys used in tests.
enum BannerSwatch {
  /// `divine/accents/lime`.
  lime(VineTheme.accentLime),

  /// `divine/accents/yellow`.
  yellow(VineTheme.accentYellow),

  /// `divine/accents/violet`.
  violet(VineTheme.accentViolet),

  /// `divine/accents/pink`.
  pink(VineTheme.accentPink),

  /// `divine/accents/orange`.
  orange(VineTheme.accentOrange),

  /// `divine/accents/purple`.
  purple(VineTheme.accentPurple);

  const BannerSwatch(this.color);

  /// The colour painted on the swatch and staged as the banner.
  final Color color;

  /// The swatch whose colour is [color], or null when the banner carries a
  /// colour from outside this palette — an older profile saved before the
  /// palette settled, for instance.
  static BannerSwatch? forColor(Color? color) {
    if (color == null) return null;
    for (final swatch in BannerSwatch.values) {
      if (swatch.color == color) return swatch;
    }
    return null;
  }

  /// The localized name shown beside the swatch and in the select row.
  String label(AppLocalizations l10n) => switch (this) {
    BannerSwatch.lime => l10n.profileSetupBannerColorLime,
    BannerSwatch.yellow => l10n.profileSetupBannerColorYellow,
    BannerSwatch.violet => l10n.profileSetupBannerColorViolet,
    BannerSwatch.pink => l10n.profileSetupBannerColorPink,
    BannerSwatch.orange => l10n.profileSetupBannerColorOrange,
    BannerSwatch.purple => l10n.profileSetupBannerColorPurple,
  };
}

/// Opens the colour picker that the banner sheet's colour row leads to.
///
/// A second sheet rather than swatches inline, as drawn: the picker gets its
/// own surface with a back button, so the first sheet stays a short list.
///
/// Returns true when the user backed out through that button, which is the
/// caller's cue to re-open the sheet it came from. Dismissing the sheet by
/// dragging it away or picking a colour returns null.
///
/// Image and colour are mutually exclusive — picking a colour clears a staged
/// image at the bloc layer.
Future<bool?> showBannerColorSheet(
  BuildContext context,
  ProfileEditorBloc editorBloc,
) {
  return VineBottomSheet.show<bool>(
    context: context,
    scrollable: false,
    expanded: false,
    isScrollControlled: true,
    title: Text(
      context.l10n.profileSetupBannerColorPickerTitle,
      style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
    ),
    headerLeadingAction: DivineIconButton(
      icon: DivineIconName.caretLeft,
      type: DivineIconButtonType.secondary,
      size: DivineIconButtonSize.small,
      tooltip: context.l10n.commonBack,
      semanticLabel: context.l10n.commonBack,
      onPressed: () => Navigator.of(context).pop(true),
    ),
    children: [
      BlocProvider<ProfileEditorBloc>.value(
        value: editorBloc,
        child: const _BannerColorPicker(),
      ),
    ],
  );
}

/// The picker body: the selected colour's name over the swatch grid.
class _BannerColorPicker extends StatelessWidget {
  const _BannerColorPicker();

  @override
  Widget build(BuildContext context) {
    final staged = context.select(
      (ProfileEditorBloc b) => b.state.pendingBannerColor,
    );
    final selected = BannerSwatch.forColor(staged);
    // A colour with no swatch of its own came from the custom picker — or from
    // a profile saved before this palette settled. Either way it is the one in
    // use, so the custom swatch carries the selection.
    final isCustom = staged != null && selected == null;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        spacing: 16,
        children: [
          Text(
            switch ((selected, isCustom)) {
              (final BannerSwatch swatch, _) => swatch.label(context.l10n),
              (_, true) => context.l10n.profileSetupBannerColorCustom,
              _ => context.l10n.profileSetupBannerColorNone,
            },
            textAlign: TextAlign.center,
            style: VineTheme.bodyLargeFont(color: context.vineColors.onSurface),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // The two action swatches lead the grid: "no colour" because
                // the design puts it first, the picker beside it so the palette
                // that follows stays unbroken.
                _NoColorSwatch(isSelected: staged == null),
                _CustomColorSwatch(isSelected: isCustom, staged: staged),
                for (final swatch in BannerSwatch.values)
                  _BannerColorSwatch(
                    swatch: swatch,
                    isSelected: swatch == selected,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The swatch that stands for "no banner colour".
class _NoColorSwatch extends StatelessWidget {
  const _NoColorSwatch({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return _SwatchBox(
      swatchKey: const ValueKey('profile_banner_color_swatch_none'),
      label: context.l10n.profileSetupBannerColorNone,
      color: context.vineColors.surfaceContainer,
      isSelected: isSelected,
      onTap: () {
        context.read<ProfileEditorBloc>().add(const ProfileBannerCleared());
        Navigator.of(context).pop();
      },
      child: DivineIcon(
        icon: DivineIconName.prohibit,
        color: context.vineColors.onSurfaceVariant,
      ),
    );
  }
}

/// Opens the full picker, for a colour the palette does not carry.
class _CustomColorSwatch extends StatelessWidget {
  const _CustomColorSwatch({required this.isSelected, required this.staged});

  final bool isSelected;

  /// Seeds the picker so it opens on whatever is already staged.
  final Color? staged;

  @override
  Widget build(BuildContext context) {
    return _SwatchBox(
      swatchKey: const ValueKey('profile_banner_color_swatch_custom'),
      label: context.l10n.profileSetupBannerColorCustom,
      color: context.vineColors.surfaceContainer,
      isSelected: isSelected,
      onTap: () async {
        final editorBloc = context.read<ProfileEditorBloc>();
        final navigator = Navigator.of(context);
        final picked = await showFullColorPicker(
          context,
          initialColor: staged ?? VineTheme.primary,
        );
        if (picked == null) return;
        editorBloc.add(ProfileBannerColorSelected(picked));
        navigator.pop();
      },
      child: const DivineIcon(
        icon: DivineIconName.paintBrush,
        color: VineTheme.primary,
      ),
    );
  }
}

/// One colour from the palette.
class _BannerColorSwatch extends StatelessWidget {
  const _BannerColorSwatch({required this.swatch, required this.isSelected});

  final BannerSwatch swatch;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return _SwatchBox(
      swatchKey: ValueKey(
        'profile_banner_color_swatch_preset_${swatch.index}',
      ),
      label: swatch.label(context.l10n),
      color: swatch.color,
      isSelected: isSelected,
      onTap: () {
        context.read<ProfileEditorBloc>().add(
          ProfileBannerColorSelected(swatch.color),
        );
        Navigator.of(context).pop();
      },
    );
  }
}

/// Gives [ColorSwatchButton] the fixed box the grid lays out on.
class _SwatchBox extends StatelessWidget {
  const _SwatchBox({
    required this.swatchKey,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.child,
  });

  final Key swatchKey;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _swatchSize,
      child: ColorSwatchButton(
        key: swatchKey,
        color: color,
        isSelected: isSelected,
        onTap: onTap,
        semanticLabel: label,
        // Action swatches sit on the sheet's own colour, so they need the
        // outline to read as targets at all.
        borderColor: child == null ? null : context.vineColors.outlineMuted,
        borderWidth: 2,
        child: child,
      ),
    );
  }
}
