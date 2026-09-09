// ABOUTME: Sounds tab for the Library screen.
// ABOUTME: Shows reusable sounds the user has explicitly saved.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/creator_sync/sound_sync_cubit.dart';
import 'package:openvine/blocs/creator_sync/sound_sync_state.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_sync_provider.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/widgets/library/saved_sound_card.dart';
import 'package:openvine/widgets/library/saved_sound_details_editor.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// User-saved sounds tab for the Library screen.
///
/// Shows sounds saved through the out-of-flow "Use Sound" actions. Editor
/// selection remains inside the recording/editor flow.
class SoundsTab extends ConsumerStatefulWidget {
  const SoundsTab({this.showAudioPicker, super.key});

  final Future<AudioEvent?> Function(BuildContext context)? showAudioPicker;

  @override
  ConsumerState<SoundsTab> createState() => _SoundsTabState();
}

class _SoundsTabState extends ConsumerState<SoundsTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _previewingSoundId;

  /// Whether the preview named by [_previewingSoundId] is paused.
  ///
  /// A paused preview keeps its card and its waveform fill — it is still the
  /// active preview, just not advancing.
  bool _previewPaused = false;

  /// Playback position of the running preview as a 0–1 fraction, so the
  /// previewing card can fill its waveform as the sound plays.
  Stream<double>? _previewProgress;

  /// Last fraction observed on [_previewProgress].
  ///
  /// Seeded into the card so a list rebuild or off-screen remount does not
  /// flash the waveform back to empty while a preview is still active
  /// (including while paused, when the position stream is quiet).
  double _previewProgressValue = 0;

  /// Bumped whenever a new preview load starts or the preview is stopped, so
  /// an in-flight `loadAudio` / `play` from a superseded tap cannot clobber
  /// the active card state.
  int _previewSession = 0;

  /// Bumped when a running `play()` is intentionally interrupted (pause,
  /// stop, or a newer play). The `_playToEnd` that owned the interrupted
  /// `play()` must not treat that resolution as "the sound ended".
  int _playEpoch = 0;

  /// Serializes `loadAudio` calls on the shared player. Session checks alone
  /// protect card state; without this gate two overlapping loads can still
  /// interleave `setAudioSource` on [AudioPlaybackService].
  Future<void>? _previewLoadGate;

  /// Cached reference to audio service for safe disposal.
  AudioPlaybackService? _audioService;

  @override
  void dispose() {
    _previewSession++;
    _playEpoch++;
    if (_previewingSoundId != null && _audioService != null) {
      _audioService!.stop();
    }
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<SavedSoundsBloc>().add(SavedSoundsQueryChanged(query));
  }

  void _clearPreviewState() {
    setState(() {
      _previewingSoundId = null;
      _previewPaused = false;
      _previewProgress = null;
      _previewProgressValue = 0;
    });
  }

  Future<void> _stopPreview() async {
    _previewSession++;
    _playEpoch++;
    if (_previewingSoundId != null) {
      _audioService ??= ref.read(audioPlaybackServiceProvider);
      await _audioService!.stop();
      if (mounted) _clearPreviewState();
    }
  }

  Future<void> _onPreviewTap(AudioEvent sound) async {
    _audioService ??= ref.read(audioPlaybackServiceProvider);
    final audioService = _audioService!;

    if (_previewingSoundId == sound.id) {
      await _togglePreviewPause(audioService, sound.id);
      return;
    }

    if (sound.url == null || sound.url!.isEmpty) return;

    final session = ++_previewSession;
    _playEpoch++;
    final priorLoad = _previewLoadGate;
    final loadDone = Completer<void>();
    _previewLoadGate = loadDone.future;

    try {
      if (priorLoad != null) await priorLoad;
      if (!mounted || session != _previewSession) return;

      await audioService.stop();
      if (!mounted || session != _previewSession) return;

      final total = await audioService.loadAudio(sound.url!);
      if (!mounted || session != _previewSession) return;
      setState(() {
        _previewingSoundId = sound.id;
        _previewPaused = false;
        _previewProgressValue = 0;
        _previewProgress = _progressFor(audioService, total, session);
      });
    } catch (e) {
      Log.error(
        'Failed to preview sound: $e',
        name: 'SoundsTab',
        category: LogCategory.video,
      );
      if (mounted && session == _previewSession) _clearPreviewState();
      return;
    } finally {
      if (!loadDone.isCompleted) loadDone.complete();
      if (identical(_previewLoadGate, loadDone.future)) {
        _previewLoadGate = null;
      }
    }
    await _playToEnd(audioService, sound.id, session);
  }

  /// Pauses the running preview, or resumes it where it left off.
  Future<void> _togglePreviewPause(
    AudioPlaybackService audioService,
    String soundId,
  ) async {
    if (_previewPaused) {
      final session = _previewSession;
      setState(() => _previewPaused = false);
      await _playToEnd(audioService, soundId, session);
      return;
    }
    // Flipped before the await: pausing resolves the pending `play()`.
    // Bump [_playEpoch] so that resolving `_playToEnd` cannot clear state
    // if a resume starts before this pause await finishes.
    setState(() => _previewPaused = true);
    _playEpoch++;
    await audioService.pause();
  }

  /// Plays until the sound ends, then hands the card back to its idle state.
  ///
  /// `play()` also resolves when the preview is paused, and when another
  /// sound stopped this one and now owns the preview state. Neither is an
  /// ending, so both leave the state alone.
  Future<void> _playToEnd(
    AudioPlaybackService audioService,
    String soundId,
    int session,
  ) async {
    final playEpoch = ++_playEpoch;
    try {
      await audioService.play();
    } catch (e) {
      Log.error(
        'Failed to preview sound: $e',
        name: 'SoundsTab',
        category: LogCategory.video,
      );
    }
    if (mounted &&
        session == _previewSession &&
        playEpoch == _playEpoch &&
        _previewingSoundId == soundId &&
        !_previewPaused) {
      _clearPreviewState();
    }
  }

  Stream<double> _progressFor(
    AudioPlaybackService service,
    Duration? total,
    int session,
  ) {
    final totalMs = total?.inMilliseconds ?? 0;
    if (totalMs <= 0) return const Stream<double>.empty();
    return service.positionStream.map((position) {
      final value = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
      if (session == _previewSession) {
        _previewProgressValue = value;
      }
      return value;
    });
  }

  Future<void> _onRemoveTap(SavedSound sound) async {
    await _stopPreview();
    if (!mounted) return;

    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: context.l10n.savedSoundRemoveConfirmTitle,
      subtitle: context.l10n.savedSoundRemoveConfirmMessage,
      primaryButtonText: context.l10n.soundsRemoveSavedSound,
      primaryButtonType: DivineButtonType.error,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      secondaryButtonText: context.l10n.commonCancel,
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
    if (confirmed != true || !mounted) return;

    var removed = true;
    try {
      await context.read<SavedSoundsBloc>().removeSound(sound.id);
    } catch (_) {
      removed = false;
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? context.l10n.soundsRemovedFromLibrary
              : context.l10n.soundsRemoveFailed,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onAddAudioTap() async {
    await _stopPreview();
    if (!mounted) return;

    final selectedSound =
        await (widget.showAudioPicker?.call(context) ??
            AudioSelectionBottomSheet.show(context));
    if (selectedSound == null || !mounted) return;

    final bloc = context.read<SavedSoundsBloc>();
    SavedSoundSaveResult? result;
    try {
      result = await bloc.saveSound(selectedSound);
    } catch (_) {
      result = null;
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (result) {
          SavedSoundSaveResult.saved => context.l10n.soundsSavedToLibrary,
          SavedSoundSaveResult.alreadySaved =>
            context.l10n.soundsAlreadySavedToLibrary,
          null => context.l10n.soundsSaveFailed,
        }),
        duration: const Duration(seconds: 2),
      ),
    );

    if (result == null) return;
    final saved = bloc.state.sounds.where(
      (record) => record.id == selectedSound.id,
    );
    if (saved.isEmpty) return;
    await _onEditTap(saved.first);
  }

  Future<void> _onOpenDetails(SavedSound sound) async {
    await _stopPreview();
    if (!mounted) return;
    context.push(SoundDetailScreen.pathForId(sound.audio.id));
  }

  Future<void> _onEditTap(SavedSound sound) async {
    await _stopPreview();
    if (!mounted) return;
    await SavedSoundDetailsEditor.show(context, sound: sound);
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(soundSyncAvailabilityProvider).value;
    final syncRepository = switch (availability) {
      SoundSyncAvailable(:final repository) => repository,
      _ => null,
    };
    final locked = availability is SoundSyncVaultLocked;
    // Everything is a sliver in one scroll view rather than a fixed header
    // above an `Expanded` list: the search field scrolls away with the
    // results, so an open keyboard no longer squeezes the list into the
    // sliver of height left below the header.
    final scrollView = CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverFloatingHeader(
          child: _SearchInput(
            controller: _searchController,
            onChanged: _onSearchChanged,
          ),
        ),
        if (kDebugMode && !kIsWeb)
          SliverToBoxAdapter(
            child: _DebugAudioPickerLauncher(onTap: _onAddAudioTap),
          ),
        if (locked)
          const SliverToBoxAdapter(child: _SyncLockedBanner())
        else if (syncRepository != null)
          const SliverToBoxAdapter(child: _SyncStatusBanner()),
        _SoundsContent(
          playingSoundId: _previewingSoundId,
          playingPaused: _previewPaused,
          playingProgress: _previewProgress,
          playingProgressValue: _previewProgressValue,
          onPreview: (sound) => _onPreviewTap(sound.audio),
          onOpenDetails: _onOpenDetails,
          onEdit: _onEditTap,
          onRemove: _onRemoveTap,
        ),
        const SliverBottomSafeArea(),
      ],
    );
    if (syncRepository == null) return scrollView;
    return BlocProvider<SoundSyncCubit>(
      key: ValueKey(syncRepository),
      create: (_) => SoundSyncCubit(repository: syncRepository)..syncNow(),
      child: scrollView,
    );
  }
}

/// Sliver body of the tab: the saved-sound list, or a placeholder that fills
/// whatever viewport is left when there is nothing to show.
class _SoundsContent extends StatelessWidget {
  const _SoundsContent({
    required this.playingSoundId,
    required this.playingPaused,
    required this.playingProgress,
    required this.playingProgressValue,
    required this.onPreview,
    required this.onOpenDetails,
    required this.onEdit,
    required this.onRemove,
  });

  final String? playingSoundId;
  final bool playingPaused;
  final Stream<double>? playingProgress;
  final double playingProgressValue;
  final ValueChanged<SavedSound> onPreview;
  final ValueChanged<SavedSound> onOpenDetails;
  final ValueChanged<SavedSound> onEdit;
  final ValueChanged<SavedSound> onRemove;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavedSoundsBloc, SavedSoundsState>(
      builder: (context, state) {
        if (state.sounds.isEmpty) return const _EmptyState();
        if (state.visibleSounds.isEmpty) return const _NoResultsState();

        return _SavedSoundsSection(
          state: state,
          playingSoundId: playingSoundId,
          playingPaused: playingPaused,
          playingProgress: playingProgress,
          playingProgressValue: playingProgressValue,
          onPreview: onPreview,
          onOpenDetails: onOpenDetails,
          onEdit: onEdit,
          onRemove: onRemove,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: context.vineColors.mutedText,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.soundsSavedEmptyTitle,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                context.l10n.soundsSavedEmptyDescription,
                style: TextStyle(
                  color: context.vineColors.onSurfaceMuted,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: context.vineColors.mutedText,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.soundsNoSoundsFound,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SoundSyncCubit, SoundSyncState, SoundSyncStatus>(
      selector: (state) => state.status,
      builder: (context, status) {
        final message = switch (status) {
          SoundSyncStatus.idle => null,
          SoundSyncStatus.syncing => context.l10n.soundSyncStatusSyncing,
          SoundSyncStatus.success => context.l10n.soundSyncStatusSynced,
          SoundSyncStatus.failure => context.l10n.soundSyncStatusFailed,
          SoundSyncStatus.locked => context.l10n.soundSyncStatusLocked,
        };
        if (message == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            message,
            style: VineTheme.labelSmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
        );
      },
    );
  }
}

/// Shown instead of [_SyncStatusBanner] when the vault key could not be
/// unlocked. No [SoundSyncCubit] exists in this case — see
/// [_SoundsTabState.build] — so this renders the locked copy directly
/// rather than selecting cubit state.
class _SyncLockedBanner extends StatelessWidget {
  const _SyncLockedBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        context.l10n.soundSyncStatusLocked,
        style: VineTheme.labelSmallFont(
          color: context.vineColors.onSurfaceMuted,
        ),
      ),
    );
  }
}

class _DebugAudioPickerLauncher extends StatelessWidget {
  const _DebugAudioPickerLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DivineButton(
        label: context.l10n.videoEditorAudioAddAudio,
        type: DivineButtonType.secondary,
        onPressed: onTap,
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.vineColors.surfaceContainerHigh,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: context.vineColors.primaryText),
        decoration: InputDecoration(
          hintText: context.l10n.soundsSearchHint,
          hintStyle: TextStyle(color: context.vineColors.onSurfaceMuted),
          prefixIconConstraints: const BoxConstraints(),
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
            child: DivineIcon(
              icon: DivineIconName.search,
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          filled: true,
          fillColor: context.vineColors.surfaceContainer,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

/// Saved-sound list as a [SliverMainAxisGroup] so its header, filters, and
/// cards scroll as one with the search field above them.
class _SavedSoundsSection extends StatelessWidget {
  const _SavedSoundsSection({
    required this.state,
    required this.playingSoundId,
    required this.playingPaused,
    required this.playingProgress,
    required this.playingProgressValue,
    required this.onPreview,
    required this.onOpenDetails,
    required this.onEdit,
    required this.onRemove,
  });

  final SavedSoundsState state;
  final String? playingSoundId;
  final bool playingPaused;
  final Stream<double>? playingProgress;
  final double playingProgressValue;
  final ValueChanged<SavedSound> onPreview;
  final ValueChanged<SavedSound> onOpenDetails;
  final ValueChanged<SavedSound> onEdit;
  final ValueChanged<SavedSound> onRemove;

  @override
  Widget build(BuildContext context) {
    final sounds = state.visibleSounds;
    final hashtags =
        state.sounds.expand((sound) => sound.personalHashtags).toSet().toList()
          ..sort();
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _SectionHeader(count: state.sounds.length)),
        if (hashtags.isNotEmpty)
          SliverToBoxAdapter(
            child: _HashtagFilters(
              hashtags: hashtags,
              selectedHashtag: state.selectedHashtag,
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: sounds.length,
            itemBuilder: (context, index) {
              final sound = sounds[index];
              final isPreviewing = playingSoundId == sound.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SavedSoundCard(
                  sound: sound,
                  isMissingFile: state.isMissingFile(sound),
                  isPlaying: isPreviewing && !playingPaused,
                  progress: isPreviewing ? playingProgress : null,
                  progressValue: isPreviewing ? playingProgressValue : 0,
                  onTap: () => onOpenDetails(sound),
                  onPreview: () => onPreview(sound),
                  onEdit: () => onEdit(sound),
                  onRemove: () => onRemove(sound),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          DivineIcon(
            icon: DivineIconName.musicNote,
            color: context.vineColors.accentPositive,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.soundsSavedLibraryTitle,
            style: TextStyle(
              color: context.vineColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: TextStyle(
              color: context.vineColors.onSurfaceMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _HashtagFilters extends StatelessWidget {
  const _HashtagFilters({
    required this.hashtags,
    required this.selectedHashtag,
  });

  final List<String> hashtags;
  final String? selectedHashtag;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Inset lives on the scroll view, not around it, so the chips run to
        // the screen edge instead of stopping short of it.
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          spacing: 8,
          children: [
            for (final hashtag in hashtags)
              Semantics(
                label: selectedHashtag == hashtag
                    ? context.l10n.savedSoundClearHashtagFilter
                    : '#$hashtag',
                child: FilterChip(
                  key: Key('saved_sound_filter_$hashtag'),
                  label: Text('#$hashtag'),
                  selected: selectedHashtag == hashtag,
                  onSelected: (selected) {
                    context.read<SavedSoundsBloc>().add(
                      SavedSoundsHashtagSelected(selected ? hashtag : null),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
