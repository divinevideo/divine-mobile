// ABOUTME: Adds an audio file from the device to My Sounds, privately or
// ABOUTME: shared publicly as a reusable sound with a credit.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent, UserProfile;
import 'package:openvine/blocs/add_sound/add_sound_cubit.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/sound_upload_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/widgets/audio/public_audio_credit_editor.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Full-screen flow that adds an audio file to My Sounds without starting a
/// video.
///
/// Reached from the library's Add sound action. The picked file is copied
/// whole into library storage and kept private by default; "Share publicly"
/// publishes it as a reusable Kind 1063 with a credit before it lands in My
/// Sounds. It never routes through the editor's catalog/trimming picker:
/// trimming is a creation-time concern, not a library one.
class AddSoundPage extends ConsumerWidget {
  const AddSoundPage({super.key});

  static const routeName = 'add-sound';
  static const String path = RoutePaths.addSound;

  /// Path segment under the Library's sounds route.
  static const String subpath = RoutePaths.addSoundSubpath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubkey = ref.watch(currentAccountIdProvider);
    final savedSoundsBloc = context.read<SavedSoundsBloc>();
    // The cubit's readers run after awaits that can outlive this widget, so
    // they go through the container rather than a ref tied to its element.
    final container = ProviderScope.containerOf(context, listen: false);
    return BlocProvider<AddSoundCubit>(
      // A sound is credited to, and saved for, whoever is signed in when the
      // flow opens; an account switch starts over.
      key: ValueKey(pubkey),
      create: (_) {
        final profile = pubkey == null
            ? null
            : ref.read(userProfileReactiveProvider(pubkey)).value;
        return AddSoundCubit(
          importService: ref.read(localAudioImportServiceProvider),
          pickFile: ref.read(audioImportFilePickerProvider)(
            context.l10n.audioPickerTypeGroup,
          ),
          saveSound: savedSoundsBloc.saveSound,
          reclaimAudio: ref.read(audioImportReclaimerProvider),
          viewerAccountId: () => container.read(currentAccountIdProvider),
          publisher: () => container.read(localAudioEventPublisherProvider),
          publisherName:
              profile?.bestDisplayName ??
              (pubkey == null ? '' : UserProfile.defaultDisplayNameFor(pubkey)),
          publisherPubkey: pubkey,
        );
      },
      child: const AddSoundView(),
    );
  }
}

/// View: renders the pick → name or credit → save flow from [AddSoundCubit].
class AddSoundView extends ConsumerStatefulWidget {
  @visibleForTesting
  const AddSoundView({super.key});

  @override
  ConsumerState<AddSoundView> createState() => _AddSoundViewState();
}

class _AddSoundViewState extends ConsumerState<AddSoundView> {
  static const _logName = 'AddSoundPage';

  final TextEditingController _nameController = TextEditingController();
  late final AudioPlaybackService _audioService;
  String? _loadedPath;
  bool _playing = false;
  int _previewSession = 0;

  @override
  void initState() {
    super.initState();
    _audioService = ref.read(audioPlaybackServiceProvider);
  }

  @override
  void dispose() {
    _previewSession++;
    _nameController.dispose();
    // Stop on navigation so a preview cannot outlive this route.
    unawaited(_audioService.stop());
    super.dispose();
  }

  Future<void> _stopPreview() async {
    if (!_playing) return;
    _previewSession++;
    await _audioService.stop();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _pickFile() async {
    await _stopPreview();
    if (!mounted) return;
    await context.read<AddSoundCubit>().pickFileAndImport();
  }

  Future<void> _togglePreview(AudioEvent audio) async {
    final path = audio.localFilePath;
    if (path == null || path.isEmpty) return;
    final service = _audioService;

    if (_playing) {
      _previewSession++;
      await service.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }

    final session = ++_previewSession;
    try {
      if (_loadedPath != path) {
        await service.stop();
        await service.loadAudioFromFile(path);
        _loadedPath = path;
      } else {
        await service.seek(Duration.zero);
      }
      if (!mounted || session != _previewSession) return;
      setState(() => _playing = true);
      await service.play();
    } catch (error, stackTrace) {
      Log.error(
        'Failed to preview a picked sound: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      // Resolves at the end of playback or when paused/stopped; a superseding
      // session must not clear the newer preview's state.
      if (mounted && session == _previewSession) {
        setState(() => _playing = false);
      }
    }
  }

  /// Replaces whatever snackbar is up, so a retry's outcome is not queued
  /// behind the failure it retried.
  void _showSnackBar(BuildContext context, SnackBar snackBar) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  void _onSaved(BuildContext context, AddSoundState state) {
    final l10n = context.l10n;
    _showSnackBar(
      context,
      DivineSnackbarContainer.snackBar(
        state.isPublished
            ? l10n.soundUploadShared
            : state.alreadyInLibrary
            ? l10n.soundsAlreadySavedToLibrary
            : l10n.soundsSavedToLibrary,
      ),
    );
    context.safePop();
  }

  void _onFailure(BuildContext context, AddSoundFailure failure) {
    final l10n = context.l10n;
    _showSnackBar(
      context,
      DivineSnackbarContainer.snackBar(switch (failure) {
        AddSoundFailure.unsupportedFormat => l10n.soundsImportUnsupportedFormat,
        AddSoundFailure.unreadableFile => l10n.soundsImportUnreadable,
        AddSoundFailure.accountChanged => l10n.soundsImportAccountChanged,
        AddSoundFailure.saveFailed => l10n.soundsSaveFailed,
        AddSoundFailure.notSignedIn => l10n.soundUploadSignInFirst,
        AddSoundFailure.publishFailed => l10n.soundUploadFailed,
        AddSoundFailure.accountRestricted => l10n.soundUploadAccountRestricted,
      }, error: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddSoundCubit, AddSoundState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failure != current.failure,
      listener: (context, state) {
        if (state.status == AddSoundStatus.saved) {
          _onSaved(context, state);
          return;
        }
        final failure = state.failure;
        if (failure != null) _onFailure(context, failure);
      },
      builder: (context, state) {
        final audio = state.audio;
        final attribution = state.attribution;
        final cubit = context.read<AddSoundCubit>();
        return PopScope(
          canPop: !state.isBusy,
          child: Scaffold(
            backgroundColor: context.vineColors.surface,
            appBar: DiVineAppBar(
              title: context.l10n.soundsAddSound,
              showBackButton: true,
              backButtonSemanticLabel: context.l10n.commonBack,
              // Always a callback: the app bar's null fallback is a bare
              // Navigator.pop, which would sidestep the PopScope above.
              onBackPressed: () {
                if (!state.isBusy) context.safePop();
              },
            ),
            body: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (audio == null)
                  _PickFilePrompt(
                    isImporting: state.status == AddSoundStatus.importing,
                    onPick: _pickFile,
                  )
                else ...[
                  _PickedSound(
                    sound: audio,
                    isPlaying: _playing,
                    canPreview: !state.isBusy,
                    canChange: state.canEdit,
                    onTogglePreview: () => _togglePreview(audio),
                    onChangeFile: _pickFile,
                  ),
                  AnimatedReveal(
                    child: state.sharePublicly
                        ? null
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: DivineTextField(
                              key: const Key('add_sound_name_field'),
                              controller: _nameController,
                              enabled: !state.isBusy,
                              filled: true,
                              labelText: context.l10n.savedSoundYourLabel,
                              textInputAction: TextInputAction.done,
                              spellCheckConfiguration:
                                  const SpellCheckConfiguration.disabled(),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Material(
                      type: MaterialType.transparency,
                      child: DivineSwitchTile(
                        key: const Key('add_sound_share_publicly'),
                        value: state.sharePublicly,
                        title: context.l10n.soundsAddSharePublicly,
                        subtitle: context.l10n.soundUploadReuseNotice,
                        onChanged: state.canEdit
                            ? cubit.setSharePublicly
                            : null,
                      ),
                    ),
                  ),
                  AnimatedReveal(
                    child: state.sharePublicly && attribution != null
                        // ExcludeFocus as well as IgnorePointer: a field still
                        // focused when Share is tapped would keep taking
                        // keystrokes the cubit drops, so a retry would publish
                        // a credit other than the one on screen.
                        ? ExcludeFocus(
                            excluding: !state.canEdit,
                            child: IgnorePointer(
                              ignoring: !state.canEdit,
                              child: PublicAudioCreditEditor(
                                key: ValueKey(audio.id),
                                attribution: attribution,
                                onChanged: cubit.updateAttribution,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ],
            ),
            bottomNavigationBar: audio == null
                ? null
                : _SaveBar(
                    label: state.isPublished
                        ? context.l10n.soundUploadRetrySaveAction
                        : state.sharePublicly
                        ? context.l10n.soundUploadShareAction
                        : context.l10n.savedSoundSaveAction,
                    isSaving: state.status == AddSoundStatus.saving,
                    onSave: state.canSave
                        ? () => cubit.save(personalLabel: _nameController.text)
                        : null,
                  ),
          ),
        );
      },
    );
  }
}

class _PickFilePrompt extends StatelessWidget {
  const _PickFilePrompt({required this.isImporting, required this.onPick});

  final bool isImporting;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          DivineIcon(
            icon: DivineIconName.musicNote,
            size: 56,
            color: context.vineColors.mutedText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.soundsImportPromptDescription,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 24),
          DivineButton(
            key: const Key('add_sound_pick'),
            label: context.l10n.soundUploadChooseFile,
            leadingIcon: DivineIconName.folderOpen,
            expanded: true,
            isLoading: isImporting,
            onPressed: isImporting ? null : onPick,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.soundUploadSupportedFormats,
            textAlign: TextAlign.center,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedSound extends StatelessWidget {
  const _PickedSound({
    required this.sound,
    required this.isPlaying,
    required this.canPreview,
    required this.canChange,
    required this.onTogglePreview,
    required this.onChangeFile,
  });

  final AudioEvent sound;
  final bool isPlaying;
  final bool canPreview;
  final bool canChange;
  final VoidCallback onTogglePreview;
  final VoidCallback onChangeFile;

  @override
  Widget build(BuildContext context) {
    final duration = sound.formattedDuration;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.vineColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            spacing: 12,
            children: [
              DivineIconButton(
                key: const Key('add_sound_preview'),
                icon: isPlaying ? DivineIconName.pause : DivineIconName.play,
                type: DivineIconButtonType.secondary,
                semanticLabel: isPlaying
                    ? context.l10n.savedSoundPausePreviewAction
                    : context.l10n.savedSoundPreviewAction,
                onPressed: canPreview ? onTogglePreview : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      sound.title ?? context.l10n.savedSoundFallbackTitle,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (duration.isNotEmpty)
                      Text(
                        duration,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              DivineButton(
                key: const Key('add_sound_change_file'),
                label: context.l10n.soundUploadChangeFile,
                type: DivineButtonType.ghost,
                size: DivineButtonSize.small,
                onPressed: canChange ? onChangeFile : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.label,
    required this.isSaving,
    required this.onSave,
  });

  final String label;
  final bool isSaving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: DivineButton(
          key: const Key('add_sound_save'),
          label: label,
          expanded: true,
          isLoading: isSaving,
          onPressed: onSave,
        ),
      ),
    );
  }
}
