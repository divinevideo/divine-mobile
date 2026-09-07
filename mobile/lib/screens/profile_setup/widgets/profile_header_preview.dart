import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/image_crop_launcher_provider.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';
import 'package:openvine/screens/profile_setup/widgets/banner_color_swatches.dart';
import 'package:openvine/screens/profile_setup/widgets/image_url_sheet.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_avatar_section.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_image_actions_sheet.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_image_picker.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:unified_logger/unified_logger.dart';

/// Height of the header block, from the app bar down to below the avatar.
const double _previewHeight = 334;

/// Distance from the top of the header to the top of the avatar.
const double _avatarTop = 134;

/// The edit-profile header: banner behind a centred, overlapping avatar.
///
/// Both images are edited from here — the banner through the pencil in its top
/// corner, the avatar through the pencil on its own corner. Neither has a
/// section elsewhere in the form.
class ProfileHeaderPreview extends StatelessWidget {
  /// Creates the edit-profile header.
  const ProfileHeaderPreview({required this.nameController, super.key});

  /// Feeds the avatar placeholder its initials while the name is being typed.
  final TextEditingController nameController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _previewHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: _BannerBackdrop()),
          const Positioned(top: 12, right: 12, child: _BannerEditButton()),
          Positioned(
            top: _avatarTop,
            left: 0,
            right: 0,
            child: ProfileAvatarSection(nameController: nameController),
          ),
        ],
      ),
    );
  }
}

/// Paints whichever banner is staged, through the same widget the profile
/// screen uses.
///
/// Delegating rather than re-implementing: the profile lays a scrim over the
/// banner and fades the empty state to `surface`, and a second hand-rolled
/// copy here drifted from it immediately.
class _BannerBackdrop extends StatelessWidget {
  const _BannerBackdrop();

  @override
  Widget build(BuildContext context) {
    final pendingUrl = context.select(
      (ProfileEditorBloc b) => b.state.pendingBannerUrl,
    );
    final pendingColor = context.select(
      (ProfileEditorBloc b) => b.state.pendingBannerColor,
    );
    final persistedBanner = context.select(
      (ProfileEditorBloc b) => b.state.persistedBanner,
    );
    // Clear stages the absence of a banner, so the preview must stop falling
    // back to the persisted value — otherwise it shows something Save will
    // not publish.
    final bannerCleared = context.select(
      (ProfileEditorBloc b) => b.state.bannerCleared,
    );
    final isUploading = context.select(
      (ProfileEditorBloc b) =>
          b.state.pendingBannerStatus == PendingBannerStatus.uploading,
    );

    final imageUrl = (pendingUrl != null && pendingUrl.isNotEmpty)
        ? pendingUrl
        : (!bannerCleared &&
              pendingColor == null &&
              persistedBanner != null &&
              persistedBanner.startsWith('http'))
        ? persistedBanner
        : null;

    final Key backdropKey;
    if (imageUrl != null) {
      backdropKey = const ValueKey('profile_banner_image_preview');
    } else if (pendingColor != null) {
      backdropKey = const ValueKey('profile_banner_color_preview');
    } else {
      backdropKey = const ValueKey('profile_banner_empty_preview');
    }

    return Stack(
      key: backdropKey,
      children: [
        Positioned.fill(
          child: ProfileBanner(
            height: _previewHeight,
            bannerUrl: imageUrl,
            profileColor: pendingColor,
          ),
        ),
        if (isUploading)
          Positioned.fill(
            child: ColoredBox(
              color: VineTheme.backgroundColor.withValues(alpha: 0.6),
              child: const Center(
                child: DivineCircularProgressIndicator(
                  color: VineTheme.vineGreen,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The pencil in the banner's top corner.
class _BannerEditButton extends ConsumerWidget {
  const _BannerEditButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUploading = context.select(
      (ProfileEditorBloc b) =>
          b.state.pendingBannerStatus == PendingBannerStatus.uploading,
    );

    return DivineIconButton(
      icon: DivineIconName.pencilSimple,
      size: DivineIconButtonSize.small,
      tooltip: context.l10n.profileSetupEditBannerLabel,
      semanticLabel: context.l10n.profileSetupEditBannerLabel,
      onPressed: isUploading ? null : () => _openBannerActions(context, ref),
    );
  }

  /// Runs the banner sheet, re-opening it whenever the colour picker is backed
  /// out of so the two read as one flow rather than two dead ends.
  Future<void> _openBannerActions(BuildContext context, WidgetRef ref) async {
    final editorBloc = context.read<ProfileEditorBloc>();

    var reopen = true;
    while (reopen) {
      reopen = false;
      if (!context.mounted) return;
      final state = editorBloc.state;
      final hasBanner =
          (state.pendingBannerUrl?.isNotEmpty ?? false) ||
          state.pendingBannerColor != null ||
          (!state.bannerCleared &&
              (state.persistedBanner?.isNotEmpty ?? false));

      final action = await showProfileImageActionsSheet(
        context,
        title: context.l10n.profileSetupChangeBannerTitle,
        colorValue: BannerSwatch.forColor(
          state.pendingBannerColor,
        )?.label(context.l10n),
        clearLabel: context.l10n.profileSetupBannerClearButton,
        actions: {
          ProfileImageAction.camera,
          ProfileImageAction.gallery,
          ProfileImageAction.link,
          ProfileImageAction.color,
          if (hasBanner) ProfileImageAction.clear,
        },
      );
      if (action == null || !context.mounted) return;

      switch (action) {
        case ProfileImageAction.camera:
          await _pickBannerImage(context, ref, editorBloc, ImageSource.camera);
        case ProfileImageAction.gallery:
          await _pickBannerImage(context, ref, editorBloc, ImageSource.gallery);
        case ProfileImageAction.link:
          await showBannerUrlSheet(context, editorBloc);
        case ProfileImageAction.color:
          final wentBack = await showBannerColorSheet(context, editorBloc);
          reopen = (wentBack ?? false) && context.mounted;
        case ProfileImageAction.clear:
          editorBloc.add(const ProfileBannerCleared());
      }
    }
  }

  Future<void> _pickBannerImage(
    BuildContext context,
    WidgetRef ref,
    ProfileEditorBloc editorBloc,
    ImageSource source,
  ) async {
    final pubkey = ref.read(authServiceProvider).currentPublicKeyHex;
    if (pubkey == null) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1500,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } catch (e) {
      Log.error(
        'Banner image_picker error: $e',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      return;
    }
    if (picked == null) return;

    // An empty pick would blow up inside the crop editor's image providers,
    // so it is rejected here instead.
    final selection = await resolveProfileImageSelection(picked);
    if (!context.mounted) return;
    if (selection == null) {
      showProfileImageSelectionFailed(context);
      return;
    }

    final cropLauncher = ref.read(imageCropLauncherProvider);
    final cropped = await cropLauncher(
      context,
      kind: ImageCropKind.banner,
      file: selection.file,
      bytes: selection.bytes,
    );

    // Picking and cropping are full screens the user can sit in for minutes,
    // and neither can be cancelled from here — by the time they return, the
    // profile editor may already be torn down.
    if (cropped == null || editorBloc.isClosed) return;

    editorBloc.add(
      ProfileBannerUploadRequested(
        pubkey: pubkey,
        bytes: cropped,
        filename: ImageCropKind.banner.filename,
        mimeType: ImageCropKind.banner.mimeType,
      ),
    );
  }
}
