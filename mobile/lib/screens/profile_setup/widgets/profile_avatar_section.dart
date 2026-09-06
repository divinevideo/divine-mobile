import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/camera_pick_error_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/camera_pick_error.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/image_crop_launcher_provider.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';
import 'package:openvine/screens/profile_setup/widgets/image_url_sheet.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_image_actions_sheet.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_image_picker.dart';
import 'package:openvine/utils/dead_image_hosts.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';

/// Diameter of the avatar in the edit-profile header.
const double avatarDiameter = 144;

class ProfileAvatarSection extends ConsumerStatefulWidget {
  const ProfileAvatarSection({required this.nameController, super.key});

  final TextEditingController nameController;

  @override
  ConsumerState<ProfileAvatarSection> createState() =>
      _ProfileAvatarSectionState();
}

class _ProfileAvatarSectionState extends ConsumerState<ProfileAvatarSection> {
  Uint8List? _selectedImageBytes;
  final TextEditingController _pictureController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_onNameChanged);
  }

  @override
  void didUpdateWidget(ProfileAvatarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nameController != widget.nameController) {
      oldWidget.nameController.removeListener(_onNameChanged);
      widget.nameController.addListener(_onNameChanged);
    }
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    widget.nameController.removeListener(_onNameChanged);
    _pictureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    return BlocListener<ProfileEditorBloc, ProfileEditorState>(
      // Pre-fill the manual image-URL sheet with the persisted picture once it
      // loads, matching the pre-decomposition seeding behaviour.
      listenWhen: (previous, current) =>
          previous.persistedPictureUrl != current.persistedPictureUrl,
      listener: (context, state) =>
          _pictureController.text = state.persistedPictureUrl ?? '',
      child: Center(
        child: SizedBox(
          height: avatarDiameter,
          width: avatarDiameter,
          child: BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
            buildWhen: (prev, curr) =>
                prev.pendingAvatarStatus != curr.pendingAvatarStatus ||
                prev.pendingPictureUrl != curr.pendingPictureUrl ||
                prev.persistedPictureUrl != curr.persistedPictureUrl ||
                prev.pictureCleared != curr.pictureCleared,
            builder: (context, editorState) {
              final isUploadingImage =
                  editorState.pendingAvatarStatus ==
                  PendingAvatarStatus.uploading;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    imageProvider: _buildProfilePictureProvider(editorState),
                    name: widget.nameController.text.trim(),
                    placeholderSeed: pubkey,
                    size: avatarDiameter,
                    semanticLabel:
                        context.l10n.profileSetupProfilePicturePreview,
                  ),
                  if (isUploadingImage)
                    Positioned(
                      top: 0,
                      left: 0,
                      width: avatarDiameter,
                      height: avatarDiameter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(56),
                          color: VineTheme.backgroundColor.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        child: const Center(
                          child: DivineCircularProgressIndicator(
                            color: VineTheme.vineGreen,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                  // Overhangs the avatar by 8px on both axes, as drawn.
                  Positioned(
                    right: -8,
                    bottom: -8,
                    child: DivineIconButton(
                      icon: DivineIconName.pencilSimple,
                      size: DivineIconButtonSize.small,
                      tooltip: context.l10n.profileSetupEditAvatarLabel,
                      semanticLabel: context.l10n.profileSetupEditAvatarLabel,
                      onPressed: isUploadingImage ? null : _openImageActions,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  ImageProvider<Object>? _buildProfilePictureProvider(
    ProfileEditorState editorState,
  ) {
    // Priority:
    //   1. Local pick preview (only relevant during upload — the bloc has
    //      no URL yet).
    //   2. Staged picture from bloc state (post-upload or manual URL).
    //   3. Persisted picture from bloc state (current kind 0 value).
    //   4. Placeholder.
    if (editorState.pendingAvatarStatus == PendingAvatarStatus.uploading) {
      if (_selectedImageBytes != null) return MemoryImage(_selectedImageBytes!);
    }

    final pending = editorState.pendingPictureUrl;
    if (pending != null &&
        pending.isNotEmpty &&
        isUsableNetworkImageUrl(pending)) {
      return NetworkImage(pending);
    }

    // Remove stages the absence of a picture, so the preview must stop falling
    // back to the persisted one — otherwise it shows what Save will not write.
    if (editorState.pictureCleared) return null;

    final persisted = editorState.persistedPictureUrl;
    if (persisted != null &&
        persisted.isNotEmpty &&
        isUsableNetworkImageUrl(persisted)) {
      return NetworkImage(persisted);
    }

    return null;
  }

  /// Opens the picker sheet and runs whichever source the user picked.
  Future<void> _openImageActions() async {
    final editorState = context.read<ProfileEditorBloc>().state;
    final hasPicture = editorState.effectivePictureUrl?.isNotEmpty ?? false;

    final action = await showProfileImageActionsSheet(
      context,
      clearLabel: context.l10n.profileSetupAvatarClearButton,
      actions: {
        ProfileImageAction.camera,
        ProfileImageAction.gallery,
        ProfileImageAction.link,
        if (hasPicture) ProfileImageAction.clear,
      },
    );
    if (action == null || !mounted) return;
    switch (action) {
      case ProfileImageAction.camera:
        await _pickImage(ImageSource.camera);
      case ProfileImageAction.gallery:
        await _pickImage(ImageSource.gallery);
      case ProfileImageAction.link:
        await _showImageUrlSheet(context);
      case ProfileImageAction.clear:
        setState(() => _selectedImageBytes = null);
        _pictureController.clear();
        context.read<ProfileEditorBloc>().add(const ProfilePictureCleared());
      case ProfileImageAction.color:
        // Banner-only; the avatar sheet never offers it.
        break;
    }
  }

  /// Platform-aware image selection with an interactive crop step.
  ///
  /// [resolveProfileImageSelection] validates the pick and resolves it to a
  /// file (native) or bytes (web), so an empty pick never reaches the Vine
  /// crop editor. The resulting cropped JPEG bytes are uploaded via
  /// `BlossomUploadService.uploadImageBytes`. The crop re-encode bounds the
  /// output dimensions and drops the original EXIF.
  Future<void> _pickImage(ImageSource source) async {
    try {
      Log.info(
        '🖼️ Attempting to pick image from ${source.name} on '
        '${kIsWeb ? "web" : defaultTargetPlatform.name}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      final picked = await pickProfileXFile(source, _picker, context);
      if (picked == null) {
        Log.info(
          '❌ No image selected',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
        return;
      }
      Log.info(
        '✅ Image picked: ${picked.name}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      final pubkey = ref.read(authServiceProvider).currentPublicKeyHex;
      if (pubkey == null) {
        Log.error(
          'Cannot upload avatar: no public key available',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
        return;
      }

      // An empty pick would blow up inside the crop editor's image providers,
      // so it is rejected here instead.
      final selection = await resolveProfileImageSelection(picked);
      if (!mounted) return;
      if (selection == null) {
        showProfileImageSelectionFailed(context);
        return;
      }

      final cropLauncher = ref.read(imageCropLauncherProvider);
      final cropped = await cropLauncher(
        context,
        kind: ImageCropKind.avatar,
        file: selection.file,
        bytes: selection.bytes,
      );

      if (cropped == null) {
        Log.info(
          '❌ Avatar crop cancelled',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
        return;
      }
      if (!mounted) return;

      setState(() {
        _selectedImageBytes = cropped;
        _pictureController.clear();
      });
      context.read<ProfileEditorBloc>().add(
        ProfilePictureUploadRequested(
          pubkey: pubkey,
          bytes: cropped,
          filename: ImageCropKind.avatar.filename,
          mimeType: ImageCropKind.avatar.mimeType,
        ),
      );
    } catch (e) {
      Log.error(
        'Error picking image: $e',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            source == ImageSource.gallery
                ? context.l10n.profileSetupImageSelectionFailed
                : context.l10n.cameraPickErrorMessage(cameraPickErrorFrom(e)),
            error: true,
            duration: const Duration(seconds: 5),
            actionLabel: context.l10n.profileSetupGotItButton,
            onActionPressed: () {},
          ),
        );
      }
    }
  }

  Future<void> _showImageUrlSheet(BuildContext context) async {
    final url = await showImageUrlSheet(
      context,
      initialUrl: _pictureController.text,
    );
    if (url == null || !context.mounted) return;

    _pictureController.text = url;
    // Stage the URL so the avatar previews it and Save can publish it. An
    // empty string clears any prior staged change.
    context.read<ProfileEditorBloc>().add(ProfilePictureUrlSet(url));
  }
}
