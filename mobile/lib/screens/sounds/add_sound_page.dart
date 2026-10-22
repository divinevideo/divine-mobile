// ABOUTME: Adds an audio file from the device, or a sound recorded on the spot,
// ABOUTME: to My Sounds, privately or shared publicly with a credit.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent, UserProfile;
import 'package:openvine/blocs/add_sound/add_sound_cubit.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/blocs/sound_recorder/sound_recorder_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/sound_upload_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/audio/live_amplitude_waveform.dart';
import 'package:openvine/widgets/audio/public_audio_credit_editor.dart';
import 'package:openvine/widgets/audio/record_toggle_button.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:sound_service/sound_service.dart';
import 'package:time_formatter/time_formatter.dart';
import 'package:unified_logger/unified_logger.dart';

/// Full-screen flow that adds a sound to My Sounds without starting a video.
///
/// Reached from the library's Add sound action. The sound is an audio file
/// picked from the device, or one recorded with the microphone right here;
/// either way it lands whole in library storage and is kept private by
/// default, while "Share publicly" publishes it as a reusable Kind 1063 with a
/// credit before it lands in My Sounds. It never routes through the editor's
/// catalog/trimming picker: trimming is a creation-time concern, not a library
/// one.
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
    return MultiBlocProvider(
      // A sound is credited to, and saved for, whoever is signed in when the
      // flow opens; an account switch starts over, recording included.
      key: ValueKey(pubkey),
      providers: [
        BlocProvider<AddSoundCubit>(
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
                  (pubkey == null
                      ? ''
                      : UserProfile.defaultDisplayNameFor(pubkey)),
              publisherPubkey: pubkey,
            );
          },
        ),
        BlocProvider<SoundRecorderCubit>(
          create: (_) => SoundRecorderCubit(
            permissionsService: const PermissionHandlerPermissionsService(),
            audioSessionService: ref.read(audioSessionServiceProvider),
          ),
        ),
      ],
      child: const AddSoundView(),
    );
  }
}

/// View: renders the pick or record → name or credit → save flow from
/// [AddSoundCubit], and hands each finished recording from
/// [SoundRecorderCubit] over to it.
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
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _audioService = ref.read(audioPlaybackServiceProvider);
    _lifecycle = AppLifecycleListener(onHide: _stopRecordingOutOfSight);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Another screen opened over this one, e.g. from a notification tap.
    if (ModalRoute.isCurrentOf(context) == false) _stopRecordingOutOfSight();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _previewSession++;
    _nameController.dispose();
    // Stop on navigation so a preview cannot outlive this route.
    unawaited(_audioService.stop());
    super.dispose();
  }

  Future<void> _stopPreview() async {
    _previewSession++;
    await _audioService.stop();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _pickFile() async {
    // Picking a file is the way around a refused microphone.
    context.read<SoundRecorderCubit>().dismissPermissionNotice();
    await _stopPreview();
    if (!mounted) return;
    final recorder = context.read<SoundRecorderCubit>().state;
    if (recorder.isStarting || recorder.isActive) return;
    await context.read<AddSoundCubit>().pickFileAndImport();
  }

  Future<void> _startRecording() async {
    // The microphone would pick up the preview.
    await _stopPreview();
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (ModalRoute.isCurrentOf(context) == false ||
        lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      return;
    }
    final sound = context.read<AddSoundCubit>().state;
    if (sound.isBusy || sound.isPublished) return;
    await context.read<SoundRecorderCubit>().start();
  }

  /// Ends a recording the person can no longer see — another screen opened
  /// over this one, or the app left the foreground — and keeps the take for
  /// when they come back, as the length limit does. The microphone only runs
  /// while the recorder is on screen.
  void _stopRecordingOutOfSight() {
    final recorder = context.read<SoundRecorderCubit>();
    if (!recorder.state.isRecording && !recorder.state.isStarting) return;
    runDetached(
      recorder.stop(),
      'stop a recording that went out of sight',
      logName: _logName,
      category: LogCategory.video,
    );
  }

  void _cancelRecording() {
    runDetached(
      context.read<SoundRecorderCubit>().cancel(),
      'cancel a sound recording',
      logName: _logName,
      category: LogCategory.video,
    );
  }

  /// Moves a finished recording into the flow, titled after when it was made
  /// until the user names it.
  ///
  /// The title is local time in the app's language, so it only names the
  /// private copy: a public share starts with an empty title (see
  /// `AddSoundCubit.importRecording`).
  void _takeOverRecording(BuildContext context, String path) {
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.MMMd(locale);
    final recordedAt =
        (MediaQuery.alwaysUse24HourFormatOf(context)
                ? date.add_Hm()
                : date.add_jm())
            .format(DateTime.now());
    runDetached(
      context.read<AddSoundCubit>().importRecording(
        path: path,
        title: context.l10n.soundsRecordingTitle(recordedAt),
      ),
      'take over a sound recording',
      logName: _logName,
      category: LogCategory.video,
    );
  }

  void _onRecorderStatus(BuildContext context, SoundRecorderStatus status) {
    switch (status) {
      case SoundRecorderStatus.recording:
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            context.l10n.videoEditorVoiceOverRecordingStarted,
            Directionality.of(context),
          ),
        );
      case SoundRecorderStatus.failed:
        _showSnackBar(
          context,
          DivineSnackbarContainer.snackBar(
            context.l10n.soundsRecordFailed,
            error: true,
          ),
        );
      case SoundRecorderStatus.idle:
      case SoundRecorderStatus.permissionDenied:
      case SoundRecorderStatus.starting:
      case SoundRecorderStatus.stopping:
        break;
    }
  }

  Future<void> _togglePreview(AudioEvent audio) async {
    final recorder = context.read<SoundRecorderCubit>().state;
    if (recorder.isStarting || recorder.isActive) return;
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
      final recorder = context.read<SoundRecorderCubit>().state;
      if (recorder.isStarting || recorder.isActive) return;
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

  Future<void> _saveSound() async {
    final recorder = context.read<SoundRecorderCubit>().state;
    if (recorder.isStarting || recorder.isActive) return;
    await context.read<AddSoundCubit>().save(
      personalLabel: _nameController.text,
    );
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
    return MultiBlocListener(
      listeners: [
        BlocListener<SoundRecorderCubit, SoundRecorderState>(
          listenWhen: (previous, current) =>
              current.recordingPath != null &&
              current.recordingPath != previous.recordingPath,
          listener: (context, state) =>
              _takeOverRecording(context, state.recordingPath!),
        ),
        BlocListener<SoundRecorderCubit, SoundRecorderState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) =>
              _onRecorderStatus(context, state.status),
        ),
      ],
      child: BlocConsumer<AddSoundCubit, AddSoundState>(
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
          final isRecorderActive = context.select(
            (SoundRecorderCubit c) => c.state.isActive,
          );
          final isRecorderStarting = context.select(
            (SoundRecorderCubit c) => c.state.isStarting,
          );
          final isRecorderBusy = isRecorderActive || isRecorderStarting;
          final isMicrophoneDenied = context.select(
            (SoundRecorderCubit c) =>
                c.state.status == SoundRecorderStatus.permissionDenied,
          );
          final isRecordedSound = state.source == AddSoundSource.recording;
          return PopScope(
            canPop: !state.isBusy && !isRecorderBusy,
            // Leaving while recording cancels the recording, not the flow.
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && isRecorderBusy) _cancelRecording();
            },
            child: Scaffold(
              backgroundColor: context.vineColors.surface,
              appBar: DiVineAppBar(
                title: context.l10n.soundsAddSound,
                showBackButton: true,
                backButtonSemanticLabel: context.l10n.commonBack,
                // Always a callback: the app bar's null fallback is a bare
                // Navigator.pop, which would sidestep the PopScope above.
                onBackPressed: () {
                  if (isRecorderBusy) {
                    _cancelRecording();
                  } else if (!state.isBusy) {
                    context.safePop();
                  }
                },
              ),
              body: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (isMicrophoneDenied) const _MicrophoneDenied(),
                  if (isRecorderActive)
                    const _RecordingPanel()
                  else if (audio == null)
                    _SourcePrompt(
                      inFlight: state.status == AddSoundStatus.importing
                          ? state.source
                          : isRecorderStarting
                          ? AddSoundSource.recording
                          : null,
                      onPick: _pickFile,
                      onRecord: _startRecording,
                    )
                  else ...[
                    _PickedSound(
                      sound: audio,
                      isPlaying: _playing,
                      canPreview: !state.isBusy && !isRecorderStarting,
                      canChange: state.canEdit && !isRecorderStarting,
                      isRecordedSound: isRecordedSound,
                      onTogglePreview: () => _togglePreview(audio),
                      onChange: isRecordedSound ? _startRecording : _pickFile,
                    ),
                    AnimatedReveal(
                      child: state.sharePublicly
                          ? null
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: DivineTextField(
                                key: const Key('add_sound_name_field'),
                                controller: _nameController,
                                enabled: !state.isBusy && !isRecorderStarting,
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
                          onChanged: state.canEdit && !isRecorderStarting
                              ? cubit.setSharePublicly
                              : null,
                        ),
                      ),
                    ),
                    AnimatedReveal(
                      child: state.sharePublicly && attribution != null
                          // ExcludeFocus as well as IgnorePointer: a field
                          // still focused when Share is tapped would keep
                          // taking keystrokes the cubit drops, so a retry
                          // would publish a credit other than the one on
                          // screen.
                          ? ExcludeFocus(
                              excluding: !state.canEdit || isRecorderStarting,
                              child: IgnorePointer(
                                ignoring: !state.canEdit || isRecorderStarting,
                                child: PublicAudioCreditEditor(
                                  key: ValueKey(audio.id),
                                  attribution: attribution,
                                  onChanged: cubit.updateAttribution,
                                  emptyTitleHint:
                                      context.l10n.soundsShareTitleRequiredHint,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ],
              ),
              bottomNavigationBar: audio == null || isRecorderActive
                  ? null
                  : _SaveBar(
                      label: state.isPublished
                          ? context.l10n.soundUploadRetrySaveAction
                          : state.sharePublicly
                          ? context.l10n.soundUploadShareAction
                          : context.l10n.savedSoundSaveAction,
                      isSaving: state.status == AddSoundStatus.saving,
                      onSave: state.canSave && !isRecorderStarting
                          ? _saveSound
                          : null,
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// The two ways to add a sound: pick a file or record one.
class _SourcePrompt extends StatelessWidget {
  const _SourcePrompt({
    required this.inFlight,
    required this.onPick,
    required this.onRecord,
  });

  /// The source being worked on — a file importing, or the microphone
  /// starting or a recording importing — or null when nothing is. Both
  /// buttons wait for it.
  final AddSoundSource? inFlight;
  final VoidCallback onPick;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final busy = inFlight != null;
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
            context.l10n.soundsAddPromptDescription,
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
            isLoading: inFlight == AddSoundSource.file,
            onPressed: busy ? null : onPick,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.soundUploadSupportedFormats,
            textAlign: TextAlign.center,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 24),
          DivineButton(
            key: const Key('add_sound_record'),
            label: context.l10n.soundsRecordAction,
            leadingIcon: DivineIconName.microphone,
            type: DivineButtonType.secondary,
            expanded: true,
            isLoading: inFlight == AddSoundSource.recording,
            onPressed: busy ? null : onRecord,
          ),
        ],
      ),
    );
  }
}

/// Shown while microphone access is refused, with the way to grant it.
class _MicrophoneDenied extends StatelessWidget {
  const _MicrophoneDenied();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.vineColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Row(
                spacing: 8,
                children: [
                  DivineIcon(
                    icon: DivineIconName.microphone,
                    color: context.vineColors.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Text(
                      l10n.videoEditorVoiceOverPermissionTitle,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                l10n.soundsRecordPermissionBody,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
              DivineButton(
                key: const Key('add_sound_open_settings'),
                label: l10n.videoEditorVoiceOverOpenSettings,
                type: DivineButtonType.secondary,
                size: DivineButtonSize.small,
                onPressed: () =>
                    context.read<SoundRecorderCubit>().openSettings(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The recording in progress: its live levels, its length, and stop.
class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 40, 16, 16),
      child: Column(
        spacing: 24,
        children: [
          RepaintBoundary(
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: _RecordingWave(),
            ),
          ),
          _RecordingClock(),
          _StopRecordingButton(),
        ],
      ),
    );
  }
}

class _RecordingWave extends StatelessWidget {
  const _RecordingWave();

  @override
  Widget build(BuildContext context) {
    final bars = context.select((SoundRecorderCubit c) => c.state.waveformBars);
    final samplePosition = context.select(
      (SoundRecorderCubit c) => c.state.elapsed,
    );
    final isRecording = context.select(
      (SoundRecorderCubit c) => c.state.isRecording,
    );
    return LiveAmplitudeWaveform(
      bars: bars,
      isRecording: isRecording,
      color: context.vineColors.accentPositive,
      sampleInterval: SoundRecorderCubit.amplitudeInterval,
      samplePosition: samplePosition,
    );
  }
}

/// Elapsed time over the length at which the recording stops on its own.
class _RecordingClock extends StatelessWidget {
  const _RecordingClock();

  @override
  Widget build(BuildContext context) {
    final elapsed = context.select((SoundRecorderCubit c) => c.state.elapsed);
    final maxDuration = context.select(
      (SoundRecorderCubit c) => c.state.maxDuration,
    );
    return Text(
      '${TimeFormatter.formatMinutesSeconds(elapsed)} / '
      '${TimeFormatter.formatMinutesSeconds(maxDuration)}',
      style: VineTheme.titleLargeFont(color: context.vineColors.onSurface),
    );
  }
}

class _StopRecordingButton extends StatelessWidget {
  const _StopRecordingButton();

  @override
  Widget build(BuildContext context) {
    // Stays a stop shape while the file is being finished, but inert.
    final isRecording = context.select(
      (SoundRecorderCubit c) => c.state.isRecording,
    );
    return RecordToggleButton(
      key: const Key('add_sound_stop_recording'),
      isRecording: true,
      semanticLabel: context.l10n.videoEditorVoiceOverStopSemanticLabel,
      onPressed: isRecording
          ? () => context.read<SoundRecorderCubit>().stop()
          : null,
    );
  }
}

class _PickedSound extends StatelessWidget {
  const _PickedSound({
    required this.sound,
    required this.isPlaying,
    required this.canPreview,
    required this.canChange,
    required this.isRecordedSound,
    required this.onTogglePreview,
    required this.onChange,
  });

  final AudioEvent sound;
  final bool isPlaying;
  final bool canPreview;
  final bool canChange;

  /// Whether [sound] was recorded here, so it is replaced by recording again
  /// rather than through the file picker.
  final bool isRecordedSound;
  final VoidCallback onTogglePreview;
  final VoidCallback onChange;

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
                key: Key(
                  isRecordedSound
                      ? 'add_sound_record_again'
                      : 'add_sound_change_file',
                ),
                label: isRecordedSound
                    ? context.l10n.soundsRecordAgainAction
                    : context.l10n.soundUploadChangeFile,
                type: DivineButtonType.ghost,
                size: DivineButtonSize.small,
                onPressed: canChange ? onChange : null,
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
