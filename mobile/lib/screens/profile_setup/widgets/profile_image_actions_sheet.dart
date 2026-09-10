import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_image_picker.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';

/// Where a profile image comes from.
enum ProfileImageAction {
  /// Shoot a new photo with the device camera.
  camera,

  /// Pick an existing photo from the gallery.
  gallery,

  /// Type or paste a URL pointing at an image.
  link,

  /// Replace the image with a flat colour. Banner only.
  color,

  /// Drop the image entirely. Both sheets offer this, under their own copy —
  /// see `clearLabel`.
  clear,
}

/// Shows the image-source picker from the `changeAvatar-actions` and
/// `changeBanner-actions` frames.
///
/// Returns the chosen source, or `null` when the sheet is dismissed without a
/// choice.
///
/// [actions] narrows the offered rows. The banner sheet adds
/// [ProfileImageAction.color], which the avatar has no equivalent for.
///
/// [title] is shown in the header. The avatar sheet passes none — its frame is
/// a bare drag handle — while the banner sheet is titled "Change banner".
///
/// [ProfileImageAction.clear] is dropped from [actions] when there is nothing
/// staged or persisted to clear, so the row never offers a no-op. Its row is
/// captioned [clearLabel], since the two sheets remove different things.
///
/// [colorValue] names the colour currently staged, which fills the colour
/// input the way the design draws it once a swatch has been picked. Null
/// leaves the input showing its label as a placeholder.
///
/// The camera row is omitted on desktop, where no camera picker exists.
Future<ProfileImageAction?> showProfileImageActionsSheet(
  BuildContext context, {
  String? title,
  String? colorValue,
  String? clearLabel,
  Set<ProfileImageAction> actions = const {
    ProfileImageAction.camera,
    ProfileImageAction.gallery,
    ProfileImageAction.link,
  },
}) {
  assert(
    !actions.contains(ProfileImageAction.clear) || clearLabel != null,
    'Offering ProfileImageAction.clear requires a clearLabel',
  );
  // Drops the keyboard before the sheet slides up. Aimed at whatever actually
  // holds focus rather than at this context's scope, so it works no matter
  // which field the user was in when they reached for the pencil.
  FocusManager.instance.primaryFocus?.unfocus();
  return VineBottomSheet.show<ProfileImageAction>(
    context: context,
    scrollable: false,
    expanded: false,
    isScrollControlled: true,
    title: title == null
        ? null
        : Text(
            title,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
    showHeaderDivider: title != null,
    children: [
      if (actions.contains(ProfileImageAction.camera) &&
          !isDesktopImagePickerPlatform())
        _ImageActionRow(
          icon: DivineIconName.cameraPlus,
          label: context.l10n.profileSetupImageTakePhoto,
          action: ProfileImageAction.camera,
        ),
      if (actions.contains(ProfileImageAction.gallery))
        _ImageActionRow(
          icon: DivineIconName.imagesSquare,
          label: context.l10n.profileSetupImageUploadFromCameraRoll,
          action: ProfileImageAction.gallery,
        ),
      if (actions.contains(ProfileImageAction.link))
        _ImageActionRow(
          icon: DivineIconName.linkSimple,
          label: context.l10n.profileSetupImagePasteLink,
          action: ProfileImageAction.link,
        ),
      if (actions.contains(ProfileImageAction.clear))
        _ImageActionRow(
          icon: DivineIconName.trash,
          label: clearLabel!,
          action: ProfileImageAction.clear,
        ),
      // Not a row but a form card: the design gives the colour its own input,
      // matching the cards on the screen behind the sheet.
      if (actions.contains(ProfileImageAction.color))
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: ProfileSelectRow(
            label: context.l10n.profileSetupBannerChangeColor,
            value: colorValue,
            trailingColor: VineTheme.primary,
            onTap: () => Navigator.of(context).pop(ProfileImageAction.color),
          ),
        ),
      const SizedBox(height: 16),
    ],
  );
}

class _ImageActionRow extends StatelessWidget {
  const _ImageActionRow({
    required this.icon,
    required this.label,
    required this.action,
  });

  final DivineIconName icon;
  final String label;
  final ProfileImageAction action;

  @override
  Widget build(BuildContext context) {
    // The sheet paints its own background, which would otherwise swallow the
    // row's ink splash — ListTile draws onto the nearest Material ancestor.
    return Material(
      type: MaterialType.transparency,
      child: DivineListTile(
        icon: icon,
        title: label,
        // Acts in place — a caret would promise a screen that never opens.
        trailingIcon: null,
        onTap: () => Navigator.of(context).pop(action),
      ),
    );
  }
}
