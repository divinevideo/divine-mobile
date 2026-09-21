// ABOUTME: Full-screen flow to publish an audio file as a reusable sound.
// ABOUTME: Pick a file, credit it, share it — no video required.

import 'package:divine_ui/divine_ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent, UserProfile;
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/blocs/sound_upload/sound_upload_cubit.dart';
import 'package:openvine/constants/audio_picker_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/sound_upload_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/audio/public_audio_credit_editor.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Page: wires the import service, the Kind 1063 publisher, and the signed-in
/// identity into [SoundUploadCubit].
class SoundUploadScreen extends ConsumerWidget {
  const SoundUploadScreen({this.pickAudioFile, super.key});

  /// Route name for this screen.
  static const routeName = 'sound-upload';

  /// Path for this route.
  static const String path = RoutePaths.soundUpload;

  /// Path segment under the Library's sounds route.
  static const String subpath = RoutePaths.soundUploadSubpath;

  /// Overrides the platform file picker; tests inject a fake.
  final Future<XFile?> Function()? pickAudioFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-keyed on the signed-in account: a sound is signed and credited by
    // whoever is signed in when the flow opens, and an account switch
    // mid-flow starts over rather than crediting the wrong pubkey.
    ref.watch(currentAuthStateProvider);
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    final publisher = ref.watch(localAudioEventPublisherProvider);
    final importService = ref.watch(localAudioImportServiceProvider);
    return BlocProvider<SoundUploadCubit>(
      key: ValueKey((pubkey, publisher)),
      create: (_) {
        final profile = pubkey == null
            ? null
            : ref.read(userProfileReactiveProvider(pubkey)).value;
        return SoundUploadCubit(
          importService: importService,
          publisher: publisher,
          publisherPubkey: pubkey,
          publisherName:
              profile?.bestDisplayName ??
              (pubkey == null ? '' : UserProfile.defaultDisplayNameFor(pubkey)),
        );
      },
      child: SoundUploadView(pickAudioFile: pickAudioFile),
    );
  }
}

/// View: renders the pick → credit → share flow from [SoundUploadCubit] and
/// hands the published sound to the app-scoped [SavedSoundsBloc].
class SoundUploadView extends StatefulWidget {
  @visibleForTesting
  const SoundUploadView({
    this.pickAudioFile,
    @visibleForTesting this.audioService,
    super.key,
  });

  final Future<XFile?> Function()? pickAudioFile;

  /// Preview player; tests inject a fake so no platform player is created.
  final AudioPlaybackService? audioService;

  @override
  State<SoundUploadView> createState() => _SoundUploadViewState();
}

class _SoundUploadViewState extends State<SoundUploadView> {
  static const _logName = 'SoundUploadView';

  late final AudioPlaybackService _audioService =
      widget.audioService ?? AudioPlaybackService();

  /// Which picked file the player currently holds, so re-picking reloads.
  String? _loadedSoundId;

  /// Set when the sound is on the relay but the My Sounds write failed.
  ///
  /// The page then stays put with a retry instead of popping: a published
  /// sound with no library row is one its creator could not delete, since
  /// deletion resolves the record from the library and nothing else lists a
  /// standalone sound.
  bool _librarySaveFailed = false;

  @override
  void dispose() {
    runDetached(
      _audioService.dispose(),
      'dispose sound upload preview player',
      logName: _logName,
      category: LogCategory.ui,
    );
    super.dispose();
  }

  Future<void> _pickFile() async {
    await _stopPreview();
    final picker =
        widget.pickAudioFile ??
        () => openFile(
          acceptedTypeGroups: [
            audioPickerTypeGroup(label: context.l10n.audioPickerTypeGroup),
          ],
          initialDirectory: audioPickerInitialDirectory(),
        );
    final file = await picker();
    if (!mounted || file == null || file.path.isEmpty) return;
    await context.read<SoundUploadCubit>().importFile(
      sourcePath: file.path,
      displayName: file.name,
    );
  }

  Future<void> _stopPreview() async {
    if (!_audioService.isPlaying) return;
    await _audioService.stop();
  }

  Future<void> _togglePreview(AudioEvent sound) async {
    if (_audioService.isPlaying) {
      await _audioService.pause();
      await _audioService.seek(Duration.zero);
      return;
    }
    final path = sound.localFilePath;
    if (path == null) return;
    try {
      if (_loadedSoundId != sound.id) {
        await _audioService.stop();
        await _audioService.loadAudioFromFile(path);
        _loadedSoundId = sound.id;
      } else {
        await _audioService.seek(Duration.zero);
      }
      // Resolves when playback ends or is paused.
      await _audioService.play();
    } catch (e, stackTrace) {
      Log.error(
        'Failed to preview picked sound: $e',
        name: _logName,
        category: LogCategory.ui,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _onPublished(AudioEvent sound) async {
    await _stopPreview();
    if (!mounted) return;
    SavedSoundSaveResult? result;
    try {
      result = await context.read<SavedSoundsBloc>().saveSound(sound);
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result == null) {
      setState(() => _librarySaveFailed = true);
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.soundsSaveFailed,
          error: true,
          actionLabel: context.l10n.commonRetry,
          onActionPressed: () => _retryLibrarySave(sound),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(context.l10n.soundUploadShared),
    );
    context.pop();
  }

  void _retryLibrarySave(AudioEvent sound) {
    if (!mounted) return;
    // The failure snackbar would otherwise hold the outcome of the retry in
    // the messenger's queue until it times out.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _librarySaveFailed = false);
    runDetached(
      _onPublished(sound),
      'retry saving shared sound to library',
      logName: _logName,
      category: LogCategory.ui,
    );
  }

  void _onFailure(BuildContext context, SoundUploadFailure failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(switch (failure) {
        SoundUploadFailure.importFailed =>
          context.l10n.videoEditorAudioImportFailed,
        SoundUploadFailure.notSignedIn => context.l10n.soundUploadSignInFirst,
        SoundUploadFailure.publishFailed => context.l10n.soundUploadFailed,
        SoundUploadFailure.accountRestricted =>
          context.l10n.soundUploadAccountRestricted,
      }, error: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SoundUploadCubit, SoundUploadState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failure != current.failure,
      listener: (context, state) {
        final published = state.publishedSound;
        if (state.status == SoundUploadStatus.published && published != null) {
          runDetached(
            _onPublished(published),
            'save shared sound to library',
            logName: _logName,
            category: LogCategory.ui,
          );
          return;
        }
        final failure = state.failure;
        if (failure != null) _onFailure(context, failure);
      },
      builder: (context, state) {
        final sound = state.sound;
        final attribution = state.attribution;
        return PopScope(
          canPop: !state.isBusy,
          child: Scaffold(
            backgroundColor: context.vineColors.surface,
            appBar: DiVineAppBar(
              title: context.l10n.soundUploadTitle,
              showBackButton: true,
              backButtonSemanticLabel: context.l10n.commonBack,
              // Always a callback: the app bar's null fallback is a bare
              // Navigator.pop, which would sidestep the PopScope below.
              onBackPressed: () {
                if (!state.isBusy) context.pop();
              },
            ),
            body: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const _Intro(),
                if (sound == null || attribution == null)
                  _FilePicker(
                    isImporting: state.status == SoundUploadStatus.importing,
                    onPick: _pickFile,
                  )
                else ...[
                  StreamBuilder<bool>(
                    stream: _audioService.playingStream,
                    initialData: _audioService.isPlaying,
                    builder: (context, snapshot) => _PickedSound(
                      sound: sound,
                      isPlaying: snapshot.data ?? false,
                      // A published sound whose library write failed still
                      // needs its retry: picking another file would leave the
                      // bar bound to the sound already on the relay, and the
                      // new pick with no way to publish it.
                      enabled: !state.isBusy && !_librarySaveFailed,
                      onTogglePreview: () => _togglePreview(sound),
                      onChangeFile: _pickFile,
                    ),
                  ),
                  PublicAudioCreditEditor(
                    key: ValueKey(sound.id),
                    attribution: attribution,
                    onChanged: context
                        .read<SoundUploadCubit>()
                        .updateAttribution,
                  ),
                  const _ReuseNotice(),
                ],
              ],
            ),
            bottomNavigationBar: sound == null
                ? null
                : _librarySaveFailed && state.publishedSound != null
                ? _ShareBar(
                    buttonKey: const Key('sound_upload_retry_save'),
                    label: context.l10n.soundUploadRetrySaveAction,
                    isPublishing: false,
                    onShare: () => _retryLibrarySave(state.publishedSound!),
                  )
                : _ShareBar(
                    buttonKey: const Key('sound_upload_share'),
                    label: context.l10n.soundUploadShareAction,
                    isPublishing: state.status == SoundUploadStatus.publishing,
                    onShare: state.canPublish
                        ? context.read<SoundUploadCubit>().publish
                        : null,
                  ),
          ),
        );
      },
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        context.l10n.soundUploadIntro,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FilePicker extends StatelessWidget {
  const _FilePicker({required this.isImporting, required this.onPick});

  final bool isImporting;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          DivineButton(
            key: const Key('sound_upload_pick_file'),
            label: context.l10n.soundUploadChooseFile,
            leadingIcon: DivineIconName.folderOpen,
            type: DivineButtonType.secondary,
            expanded: true,
            isLoading: isImporting,
            onPressed: isImporting ? null : onPick,
          ),
          Text(
            context.l10n.soundUploadSupportedFormats,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
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
    required this.enabled,
    required this.onTogglePreview,
    required this.onChangeFile,
  });

  final AudioEvent sound;
  final bool isPlaying;
  final bool enabled;
  final VoidCallback onTogglePreview;
  final VoidCallback onChangeFile;

  @override
  Widget build(BuildContext context) {
    final duration = sound.duration;
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
                key: const Key('sound_upload_preview'),
                icon: isPlaying ? DivineIconName.pause : DivineIconName.play,
                type: DivineIconButtonType.secondary,
                semanticLabel: isPlaying
                    ? context.l10n.videoEditorAudioPausePreviewSemanticLabel
                    : context.l10n.videoEditorAudioPlayPreviewSemanticLabel,
                onPressed: enabled ? onTogglePreview : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      sound.title ?? context.l10n.videoEditorAudioUntitledSound,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (duration != null)
                      Text(
                        Duration(milliseconds: (duration * 1000).round())
                            .toMmSs(),
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              DivineButton(
                key: const Key('sound_upload_change_file'),
                label: context.l10n.soundUploadChangeFile,
                type: DivineButtonType.ghost,
                size: DivineButtonSize.small,
                onPressed: enabled ? onChangeFile : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReuseNotice extends StatelessWidget {
  const _ReuseNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          DivineIcon(
            icon: DivineIconName.musicNotesSimple,
            size: 18,
            color: context.vineColors.onSurfaceVariant,
          ),
          Expanded(
            child: Text(
              context.l10n.soundUploadReuseNotice,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({
    required this.buttonKey,
    required this.label,
    required this.isPublishing,
    required this.onShare,
  });

  /// Test anchor on the button itself, so a finder can read its state.
  final Key buttonKey;
  final String label;
  final bool isPublishing;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: DivineButton(
          key: buttonKey,
          label: label,
          expanded: true,
          isLoading: isPublishing,
          onPressed: onShare,
        ),
      ),
    );
  }
}
