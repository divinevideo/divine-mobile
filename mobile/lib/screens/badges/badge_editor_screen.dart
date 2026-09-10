// ABOUTME: Full-screen form for creating or editing a NIP-58 badge
// ABOUTME: definition, including Blossom artwork upload and a live preview.

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/badges/badge_editor_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/image_crop_launcher_provider.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_image_actions_sheet.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_image_picker.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Creates a new badge, or edits the badge at [coordinate].
class BadgeEditorScreen extends ConsumerWidget {
  /// Route name for creating a badge.
  static const createRouteName = 'badgeCreate';

  /// Route path for creating a badge.
  static const createPath = '/badges/new';

  /// Route name for editing a badge.
  static const editRouteName = 'badgeEdit';

  /// Route path for editing a badge.
  static const editPath = '/badges/b/:naddr/edit';

  /// Path that opens the editor for [coordinate].
  static String editPathFor(BadgeCoordinate coordinate) =>
      '/badges/b/${coordinate.toNaddr()}/edit';

  /// Creates the badge editor screen.
  const BadgeEditorScreen({this.coordinate, super.key});

  /// The badge being edited, or null when creating one.
  final BadgeCoordinate? coordinate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(badgeRepositoryProvider);
    final uploadService = ref.watch(blossomUploadServiceProvider);
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    return BlocProvider(
      // Re-create the cubit when the signer identity or its repositories flip,
      // so an account switch cannot publish through the previous account.
      key: ValueKey((repository, uploadService, pubkey, coordinate)),
      create: (_) => BadgeEditorCubit(
        repository: repository,
        uploadService: uploadService,
        pubkey: pubkey,
        coordinate: coordinate,
      )..load(),
      child: const BadgeEditorView(),
    );
  }
}

/// Form body of [BadgeEditorScreen].
class BadgeEditorView extends ConsumerStatefulWidget {
  /// Creates the badge editor view.
  @visibleForTesting
  const BadgeEditorView({super.key});

  @override
  ConsumerState<BadgeEditorView> createState() => _BadgeEditorViewState();
}

class _BadgeEditorViewState extends ConsumerState<BadgeEditorView> {
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Mirrors cubit-side field changes the user did not type.
  ///
  /// Covers the prefill when editing and the identifier derived from the name
  /// while creating; typing into a field never rewrites that same field.
  void _syncControllers(BadgeEditorState state) {
    if (_nameController.text != state.name) {
      _nameController.value = TextEditingValue(
        text: state.name,
        selection: TextSelection.collapsed(offset: state.name.length),
      );
    }
    if (_identifierController.text != state.identifier) {
      _identifierController.value = TextEditingValue(
        text: state.identifier,
        selection: TextSelection.collapsed(offset: state.identifier.length),
      );
    }
    if (_descriptionController.text != state.description) {
      _descriptionController.value = TextEditingValue(
        text: state.description,
        selection: TextSelection.collapsed(offset: state.description.length),
      );
    }
  }

  /// Opens the image-source sheet and runs whatever the user picked.
  ///
  /// Shares the profile picture's sheet so both surfaces offer the same
  /// sources with the same copy; the URL and colour rows are profile-only and
  /// are never offered here.
  Future<void> _changeArtwork() async {
    final cubit = context.read<BadgeEditorCubit>();
    final hasArtwork = cubit.state.imageUrl.isNotEmpty;

    final action = await showProfileImageActionsSheet(
      context,
      title: context.l10n.badgeEditorArtworkSheetTitle,
      clearLabel: context.l10n.badgeEditorArtworkRemove,
      actions: {
        ProfileImageAction.camera,
        ProfileImageAction.gallery,
        if (hasArtwork) ProfileImageAction.clear,
      },
    );
    if (action == null || !mounted) return;

    switch (action) {
      case ProfileImageAction.camera:
        await _pickArtwork(ImageSource.camera);
      case ProfileImageAction.gallery:
        await _pickArtwork(ImageSource.gallery);
      case ProfileImageAction.clear:
        cubit.artworkCleared();
      case ProfileImageAction.link:
      case ProfileImageAction.color:
        // Intentional no-op: neither row is in the `actions` set above, so
        // the sheet cannot return them.
        break;
    }
  }

  Future<void> _pickArtwork(ImageSource source) async {
    final cubit = context.read<BadgeEditorCubit>();
    final cropLauncher = ref.read(imageCropLauncherProvider);

    final picked = await pickProfileXFile(source, _picker, context);
    if (picked == null || !mounted) return;

    final selection = await resolveProfileImageSelection(picked);
    if (!mounted) return;
    if (selection == null) {
      showProfileImageSelectionFailed(context);
      return;
    }

    // Same 1:1 / 1024px crop the profile picture uses, so badge artwork and
    // avatars come out of the editor with identical geometry and encoding.
    const kind = ImageCropKind.avatar;
    final cropped = await cropLauncher(
      context,
      kind: kind,
      file: selection.file,
      bytes: selection.bytes,
    );
    if (cropped == null) return;

    await cubit.uploadArtwork(
      bytes: cropped,
      filename: kind.filename,
      mimeType: kind.mimeType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<BadgeEditorCubit, BadgeEditorState>(
      listenWhen: (previous, current) =>
          previous.name != current.name ||
          previous.identifier != current.identifier ||
          previous.description != current.description ||
          previous.status != current.status,
      listener: (context, state) {
        _syncControllers(state);
        if (state.status == BadgeEditorStatus.saved) {
          // Deep-linked straight into `/badges/new`, there is nothing to pop
          // back to; the dashboard is where the new badge now lives.
          context.safePop(result: true, fallback: BadgesScreen.path);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: DiVineAppBar(
            title: state.isEditing
                ? l10n.badgeEditorEditTitle
                : l10n.badgeEditorCreateTitle,
            showBackButton: true,
            onBackPressed: () => context.safePop(fallback: BadgesScreen.path),
          ),
          backgroundColor: context.vineColors.background,
          body: switch (state.status) {
            BadgeEditorStatus.initial ||
            BadgeEditorStatus.loading => const Center(
              child: BrandedLoadingIndicator(size: 60),
            ),
            BadgeEditorStatus.loadFailure => _EditorMessage(
              message: l10n.badgeEditorLoadError,
              onRetry: () => context.read<BadgeEditorCubit>().load(),
            ),
            _ => _BadgeEditorForm(
              state: state,
              nameController: _nameController,
              identifierController: _identifierController,
              descriptionController: _descriptionController,
              onChangeArtwork: _changeArtwork,
            ),
          },
        );
      },
    );
  }
}

class _BadgeEditorForm extends StatelessWidget {
  const _BadgeEditorForm({
    required this.state,
    required this.nameController,
    required this.identifierController,
    required this.descriptionController,
    required this.onChangeArtwork,
  });

  final BadgeEditorState state;
  final TextEditingController nameController;
  final TextEditingController identifierController;
  final TextEditingController descriptionController;
  final Future<void> Function() onChangeArtwork;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BadgeEditorCubit>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _ArtworkSection(state: state, onChangeArtwork: onChangeArtwork),
                DivineTextField(
                  labelText: l10n.badgeEditorNameLabel,
                  hintText: l10n.badgeEditorNameHint,
                  controller: nameController,
                  filled: true,
                  fillColor: context.vineColors.surfaceContainer,
                  primaryWhenFilled: true,
                  enabled: !state.isPublishing,
                  textInputAction: TextInputAction.next,
                  onChanged: cubit.nameChanged,
                ),
                _IdentifierField(
                  state: state,
                  controller: identifierController,
                  onChanged: cubit.identifierChanged,
                ),
                DivineTextField(
                  labelText: l10n.badgeEditorDescriptionLabel,
                  hintText: l10n.badgeEditorDescriptionHint,
                  controller: descriptionController,
                  filled: true,
                  fillColor: context.vineColors.surfaceContainer,
                  primaryWhenFilled: true,
                  enabled: !state.isPublishing,
                  minLines: 3,
                  maxLines: 6,
                  onChanged: cubit.descriptionChanged,
                ),
                if (state.status == BadgeEditorStatus.saveFailure)
                  Text(
                    l10n.badgeEditorSaveError,
                    style: VineTheme.bodySmallFont(color: VineTheme.error),
                  ),
                DivineButton(
                  label: l10n.badgeEditorSaveAction,
                  isLoading: state.status == BadgeEditorStatus.saving,
                  // Pressable without artwork or identifier on purpose:
                  // pressing it is what surfaces what is still missing.
                  onPressed: state.canSubmit && !state.isBusy
                      ? cubit.save
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The `d` identifier field, with the replace-an-existing-badge warning.
class _IdentifierField extends StatelessWidget {
  const _IdentifierField({
    required this.state,
    required this.controller,
    required this.onChanged,
  });

  final BadgeEditorState state;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isTaken = state.isIdentifierTaken;
    final isMissing = state.showIdentifierRequired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        DivineTextField(
          labelText: l10n.badgeEditorIdentifierLabel,
          // The warning replaces the explanation rather than stacking under
          // it: two lines of small print under one field read as noise.
          helperText: isTaken || isMissing
              ? null
              : l10n.badgeEditorIdentifierHelp,
          // The clause carrying the meaning is the second one, so a single
          // line cuts exactly the half worth reading — and every locale here
          // is longer than the English.
          helperMaxLines: 2,
          controller: controller,
          filled: true,
          fillColor: context.vineColors.surfaceContainer,
          primaryWhenFilled: true,
          // The identifier is the definition's address; changing it on an
          // existing badge would publish a second badge instead of replacing
          // this one.
          enabled: !state.isEditing && !state.isPublishing,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
        ),
        if (isTaken)
          Text(
            l10n.badgeEditorIdentifierTaken,
            style: VineTheme.bodySmallFont(color: VineTheme.error),
          )
        else if (isMissing)
          Text(
            l10n.badgeEditorIdentifierRequired,
            style: VineTheme.bodySmallFont(color: VineTheme.error),
          ),
      ],
    );
  }
}

class _ArtworkSection extends StatelessWidget {
  const _ArtworkSection({required this.state, required this.onChangeArtwork});

  final BadgeEditorState state;
  final Future<void> Function() onChangeArtwork;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasArtwork = state.imageUrl.isNotEmpty;
    final label = hasArtwork
        ? l10n.badgeEditorArtworkReplace
        : l10n.badgeEditorArtworkAdd;
    final onTap = state.isBusy ? null : onChangeArtwork;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          l10n.badgeEditorArtworkLabel,
          style: VineTheme.titleSmallFont(
            color: context.vineColors.primaryText,
          ),
        ),
        Row(
          spacing: 16,
          children: [
            // Tapping the artwork itself opens the same sheet, matching how
            // the profile picture behaves.
            Semantics(
              button: true,
              label: label,
              child: GestureDetector(
                onTap: onTap,
                child: _ArtworkPreview(
                  imageUrl: state.imageUrl,
                  isUploading:
                      state.artworkStatus == BadgeArtworkStatus.uploading,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  DivineButton(
                    label: label,
                    type: DivineButtonType.secondary,
                    size: DivineButtonSize.small,
                    onPressed: onTap,
                  ),
                  if (state.artworkStatus == BadgeArtworkStatus.failure)
                    Text(
                      l10n.badgeEditorArtworkError,
                      style: VineTheme.bodySmallFont(color: VineTheme.error),
                    )
                  else if (state.showArtworkRequired)
                    Text(
                      l10n.badgeEditorArtworkRequired,
                      style: VineTheme.bodySmallFont(color: VineTheme.error),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArtworkPreview extends StatelessWidget {
  const _ArtworkPreview({required this.imageUrl, required this.isUploading});

  final String imageUrl;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.vineColors.surfaceContainerHigh,
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Center(
        child: DivineIcon(
          icon: .image,
          color: context.vineColors.onSurfaceMuted,
        ),
      ),
    );

    return SizedBox(
      width: 88,
      height: 88,
      child: isUploading
          ? const Center(child: BrandedLoadingIndicator(size: 44))
          : imageUrl.isEmpty
          ? placeholder
          : ClipOval(
              child: VineCachedImage(
                imageUrl: imageUrl,
                errorWidget: (_, _, _) => placeholder,
              ),
            ),
    );
  }
}

class _EditorMessage extends StatelessWidget {
  const _EditorMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            DivineButton(label: context.l10n.commonRetry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
