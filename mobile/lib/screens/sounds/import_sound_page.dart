// ABOUTME: Import a file from device storage into the private sound library.
// ABOUTME: Copies, previews, optionally names, then durably saves the sound.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/blocs/sound_import/sound_import_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Full-screen flow that adds an audio file to My Sounds without starting a
/// video.
///
/// Reached from the library's permanent Add sound action. It never routes
/// through the editor's catalog/trimming picker: the picked file is copied
/// whole into library storage and stays whole — trimming is a creation-time
/// concern, not a library one.
class ImportSoundPage extends ConsumerWidget {
  const ImportSoundPage({super.key});

  static const routeName = 'import-sound';
  static const String path = RoutePaths.importSound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedSoundsBloc = context.read<SavedSoundsBloc>();
    return BlocProvider<SoundImportCubit>(
      create: (_) => SoundImportCubit(
        importService: ref.read(localAudioImportServiceProvider),
        pickFile: ref.read(audioImportFilePickerProvider),
        saveSound: savedSoundsBloc.saveSound,
        reclaimAudio: ref.read(audioImportReclaimerProvider),
        viewerAccountId: () => ref.read(currentAccountIdProvider),
      ),
      child: const ImportSoundView(),
    );
  }
}

class ImportSoundView extends ConsumerStatefulWidget {
  const ImportSoundView({super.key});

  @override
  ConsumerState<ImportSoundView> createState() => _ImportSoundViewState();
}

class _ImportSoundViewState extends ConsumerState<ImportSoundView> {
  static const _logName = 'ImportSoundPage';

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
    // Stop on navigation so an import preview cannot outlive this route.
    unawaited(_audioService.stop());
    super.dispose();
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
        'Failed to preview an imported sound: $error',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.soundsAddSound,
        showBackButton: true,
        onBackPressed: context.safePop,
        backgroundColor: context.vineColors.card,
      ),
      body: BlocConsumer<SoundImportCubit, SoundImportState>(
        listenWhen: (previous, next) =>
            next.status == SoundImportStatus.saved &&
            previous.status != SoundImportStatus.saved,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_savedMessage(context, state.alreadyInLibrary)),
              duration: const Duration(seconds: 2),
            ),
          );
          context.safePop();
        },
        builder: (context, state) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _ImportBody(
              state: state,
              nameController: _nameController,
              isPlaying: _playing,
              onPreview: _togglePreview,
            ),
          ),
        ),
      ),
    );
  }

  String _savedMessage(BuildContext context, bool alreadySaved) {
    return alreadySaved
        ? context.l10n.soundsAlreadySavedToLibrary
        : context.l10n.soundsSavedToLibrary;
  }
}

/// Renders whichever stage of the import the cubit is in.
class _ImportBody extends StatelessWidget {
  const _ImportBody({
    required this.state,
    required this.nameController,
    required this.isPlaying,
    required this.onPreview,
  });

  final SoundImportState state;
  final TextEditingController nameController;
  final bool isPlaying;
  final void Function(AudioEvent audio) onPreview;

  @override
  Widget build(BuildContext context) {
    if (state.status == SoundImportStatus.copying) {
      return const SizedBox(
        height: 240,
        child: Center(child: DivineCircularProgressIndicator()),
      );
    }

    final audio = state.audio;
    if (audio == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.status == SoundImportStatus.failure) ...[
            _FailureNotice(
              message: _failureMessage(context, state.failureReason),
            ),
            const SizedBox(height: 16),
          ],
          _PickFilePrompt(
            onPick: () => context.read<SoundImportCubit>().pickFileAndImport(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ImportedFileCard(
          audio: audio,
          isPlaying: isPlaying,
          enabled: !state.isBusy,
          onPreview: () => onPreview(audio),
        ),
        const SizedBox(height: 16),
        DivineTextField(
          key: const Key('import_sound_name_field'),
          controller: nameController,
          enabled: !state.isBusy,
          filled: true,
          labelText: context.l10n.savedSoundYourLabel,
          textInputAction: TextInputAction.done,
          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
        ),
        if (state.failureReason == SoundImportFailureReason.saveFailed) ...[
          const SizedBox(height: 12),
          _FailureNotice(message: context.l10n.soundsSaveFailed),
        ],
        const SizedBox(height: 20),
        DivineButton(
          key: const Key('import_sound_save'),
          expanded: true,
          label: context.l10n.savedSoundSaveAction,
          onPressed: state.canSave
              ? () => context.read<SoundImportCubit>().save(
                  personalLabel: nameController.text,
                )
              : null,
        ),
      ],
    );
  }

  String _failureMessage(
    BuildContext context,
    SoundImportFailureReason? reason,
  ) {
    return switch (reason) {
      SoundImportFailureReason.unsupportedFormat =>
        context.l10n.soundsImportUnsupportedFormat,
      SoundImportFailureReason.unreadableFile ||
      SoundImportFailureReason.undecodable =>
        context.l10n.soundsImportUnreadable,
      SoundImportFailureReason.saveFailed => context.l10n.soundsSaveFailed,
      SoundImportFailureReason.accountChanged =>
        context.l10n.soundsImportAccountChanged,
      null => context.l10n.videoEditorAudioImportFailed,
    };
  }
}

class _PickFilePrompt extends StatelessWidget {
  const _PickFilePrompt({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          context.l10n.soundsImportPromptTitle,
          textAlign: TextAlign.center,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.soundsImportPromptDescription,
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 24),
        DivineButton(
          key: const Key('import_sound_pick'),
          expanded: true,
          label: context.l10n.videoEditorAudioImportAudio,
          onPressed: onPick,
        ),
      ],
    );
  }
}

class _ImportedFileCard extends StatelessWidget {
  const _ImportedFileCard({
    required this.audio,
    required this.isPlaying,
    required this.enabled,
    required this.onPreview,
  });

  final AudioEvent audio;
  final bool isPlaying;
  final bool enabled;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final duration = audio.formattedDuration;
    final title = audio.title ?? context.l10n.savedSoundFallbackTitle;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            DivineIcon(
              icon: DivineIconName.waveform,
              color: context.vineColors.accentPositive,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.titleSmallFont(
                      color: context.vineColors.onSurface,
                    ),
                  ),
                  if (duration.isNotEmpty)
                    Text(
                      duration,
                      style: VineTheme.labelMediumFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            DivineIconButton(
              key: const Key('import_sound_preview'),
              icon: isPlaying ? DivineIconName.pause : DivineIconName.play,
              semanticLabel: isPlaying
                  ? context.l10n.savedSoundPausePreviewAction
                  : context.l10n.savedSoundPreviewAction,
              size: DivineIconButtonSize.small,
              type: DivineIconButtonType.secondary,
              onPressed: enabled ? onPreview : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureNotice extends StatelessWidget {
  const _FailureNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        DivineIcon(
          icon: DivineIconName.warning,
          size: 18,
          color: context.vineColors.onErrorContainer,
        ),
        Expanded(
          child: Text(
            message,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onErrorContainer,
            ),
          ),
        ),
      ],
    );
  }
}
