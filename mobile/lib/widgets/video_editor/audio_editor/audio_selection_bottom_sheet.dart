import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent, VineSound;
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_category_bar.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_editor_selection_overlay.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

final _featuredVineSounds = [
  VineSound(
    id: 'wednesday',
    title: 'Wednesday My Dudes',
    assetPath: 'assets/sounds/wednesday.mp3',
    duration: const Duration(milliseconds: 6269),
    tags: const ['featured'],
  ),
];

class AudioSelectionBottomSheet extends ConsumerStatefulWidget {
  const AudioSelectionBottomSheet({
    required this.scrollController,
    this.localAudioImportService,
    this.pickAudioFile,
    @visibleForTesting this.audioService,
    super.key,
  });

  final ScrollController scrollController;
  final LocalAudioImportService? localAudioImportService;
  final Future<FilePickerResult?> Function()? pickAudioFile;
  final AudioPlaybackService? audioService;

  static Future<AudioEvent?> show(BuildContext context) {
    return VineBottomSheet.show<AudioEvent>(
      context: context,
      maxChildSize: 1,
      initialChildSize: 1,
      minChildSize: VineTheme.bottomSheetDismissFloor,
      headerPadding: const EdgeInsetsDirectional.only(
        start: 12,
        end: 12,
        top: 8,
      ),
      title: Row(
        mainAxisAlignment: .spaceBetween,
        spacing: 8,
        children: [
          DivineIconButton(
            icon: .x,
            onPressed: context.pop,
            type: .secondary,
            size: .small,
          ),

          Flexible(child: Text(context.l10n.videoEditorAudioAddAudio)),

          const IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: 0,
                child: DivineIconButton(
                  icon: .x,
                  onPressed: null,
                  size: .small,
                ),
              ),
            ),
          ),
        ],
      ),
      buildScrollBody: (scrollController) =>
          AudioSelectionBottomSheet(scrollController: scrollController),
    );
  }

  @override
  ConsumerState<AudioSelectionBottomSheet> createState() =>
      _AudioSelectionBottomSheetState();
}

class _AudioSelectionBottomSheetState
    extends ConsumerState<AudioSelectionBottomSheet>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  late final AudioPlaybackService _audioService;
  final _searchController = TextEditingController();
  String? _loadedSoundId;
  AudioEvent? _selectedItem;
  AudioCategory _category = .divine;
  String _searchQuery = '';
  bool _isLoadingAudio = false;

  @override
  int get tabCount => AudioCategory.values.length;

  @override
  void initState() {
    super.initState();
    _audioService = widget.audioService ?? AudioPlaybackService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  @override
  void dispose() {
    _audioService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void onTabChanged() {
    if (tabController.indexIsChanging) return;
    final newCategory = AudioCategory.values[tabController.index];
    if (_category != newCategory) {
      setState(() => _category = newCategory);
    }
  }

  void _selectCategory(AudioCategory category) {
    setState(() {
      _category = category;
      tabController.animateTo(
        AudioCategory.values.indexWhere((el) => el == category),
      );
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
    });
  }

  List<AudioEvent> _filterAudioEvents(List<AudioEvent> sounds) {
    if (_searchQuery.isEmpty) return sounds;
    return sounds.where((sound) {
      final title = sound.title?.toLowerCase() ?? '';
      final source = sound.source?.toLowerCase() ?? '';
      return title.contains(_searchQuery) || source.contains(_searchQuery);
    }).toList();
  }

  Future<void> _togglePlayPause({bool enforcePlay = false}) async {
    if (_selectedItem == null) {
      return;
    }

    if (_audioService.isPlaying && !enforcePlay) {
      await _audioService.pause();
      await _audioService.seek(.zero);
      return;
    }

    final sound = _selectedItem!;

    if (sound.url == null || sound.url!.isEmpty) {
      Log.warning(
        'Cannot preview sound: no URL available (${sound.id})',
        name: 'AudioSelectionBottomSheet',
        category: LogCategory.ui,
      );
      return;
    }

    final shouldReload = _loadedSoundId != sound.id;

    Log.debug(
      'Starting preview: ${sound.title ?? sound.id}',
      name: 'AudioSelectionBottomSheet',
      category: LogCategory.ui,
    );

    try {
      await _audioService.seek(.zero);
      var resolvedSound = sound;
      if (shouldReload) {
        if (mounted) setState(() => _isLoadingAudio = true);
        await _audioService.stop();
        try {
          final loadedDuration =
              sound.isLocalImport && sound.localFilePath != null
              ? await _audioService.loadAudioFromFile(sound.localFilePath!)
              : await _audioService.loadAudio(sound.url!);
          _loadedSoundId = sound.id;
          // Backfill missing duration so the selection overlay and list
          // tile can show a correct timestamp for Nostr sounds that don't
          // carry a duration tag.
          if (sound.duration == null && loadedDuration != null) {
            resolvedSound = sound.copyWith(
              duration: loadedDuration.inMilliseconds / 1000.0,
            );
          }
        } finally {
          if (mounted) setState(() => _isLoadingAudio = false);
        }
      }

      if (mounted) {
        setState(() {
          _selectedItem = resolvedSound;
        });
      }
      if (!mounted) return;
      // Blocks here for the entire duration of playback — only
      // releases once the song finishes playing to the end or was paused.
      await _audioService.play();
    } catch (e) {
      Log.error(
        'Failed to preview sound: $e',
        name: 'AudioSelectionBottomSheet',
        category: LogCategory.ui,
      );
    } finally {
      if (_selectedItem == sound) {
        await _audioService.pause();
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _selectSound(AudioEvent sound) async {
    if (_selectedItem?.id == sound.id) return;

    // Bundled / imported / provider-catalog sounds carry their own terms and
    // never reach the resolver. Everything else — including the creator's own
    // sounds — is decided by `audioReuseConsentProvider`, which owns the owner
    // exception this call site used to be missing.
    final canReuse =
        sound.isBundled ||
        sound.isLocalImport ||
        sound.isExternalProviderSound ||
        await ref.read(audioReuseConsentProvider(sound).future);
    if (!mounted) return;
    if (!canReuse) {
      Log.info(
        'Sound selection blocked because reuse consent could not be verified: '
        '${sound.id}',
        name: 'AudioSelectionBottomSheet',
        category: LogCategory.ui,
      );
      // Replace rather than enqueue: the messenger outlives this sheet, so a
      // burst of blocked taps would otherwise leave a backlog of identical
      // toasts trailing the user into the editor (#6769).
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.soundReuseUnavailable),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    Log.info(
      'Sound selected: ${sound.title ?? 'Untitled'} (${sound.id})',
      name: 'AudioSelectionBottomSheet',
      category: LogCategory.ui,
    );
    setState(() {
      _selectedItem = sound;
    });
    await _togglePlayPause(enforcePlay: true);
  }

  Future<void> _importAudio() async {
    final picker =
        widget.pickAudioFile ??
        () {
          return FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: const [
              'aac',
              'm4a',
              'mp3',
              'wav',
              'weba',
              'webm',
            ],
          );
        };

    try {
      final result = await picker();
      final files = result?.files;
      if (files == null || files.isEmpty) return;

      final file = files.first;
      final filePath = file.path;
      if (filePath == null || filePath.isEmpty) return;

      final imported =
          await (widget.localAudioImportService ?? LocalAudioImportService())
              .importAudioFile(
                sourcePath: filePath,
                displayName: file.name,
              );

      if (!mounted) return;
      setState(() => _selectedItem = imported);
      await _togglePlayPause(enforcePlay: true);
    } on LocalAudioImportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, s) {
      Log.error(
        'Failed to import audio: $e',
        name: 'AudioSelectionBottomSheet',
        category: LogCategory.ui,
        error: e,
        stackTrace: s,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.videoEditorAudioImportFailed)),
      );
    }
  }

  Future<void> _handleDoneSelection() async {
    await _audioService.stop();
    if (!mounted) return;

    if (_selectedItem == null) {
      context.pop();
      return;
    }

    var sound = _selectedItem!;
    if (sound.duration == null) {
      final resolvedDuration = await _resolveDurationSecs(sound);
      if (!mounted) return;
      if (resolvedDuration != null) {
        sound = sound.copyWith(duration: resolvedDuration);
        setState(() => _selectedItem = sound);
      }
    }

    if (sound.duration == null ||
        sound.duration! >
            (VideoEditorConstants.maxDuration.inMilliseconds / 1000.0)) {
      final timingResult = await Navigator.of(context).push<AudioTimingResult>(
        PageRouteBuilder(
          settings: const RouteSettings(name: 'audio_timing'),
          opaque: false,
          barrierColor: VineTheme.transparent,
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          pageBuilder: (_, _, _) => VideoAudioEditorTimingScreen(
            sound: sound,
            enableDeleteButton: false,
          ),
        ),
      );

      if (timingResult != null && mounted) {
        switch (timingResult) {
          case AudioTimingConfirmed(:final sound):
            context.pop(sound);
          case AudioTimingDeleted():
            break;
        }
      }
    } else {
      context.pop(sound);
    }
  }

  /// Resolves the audio duration in seconds via [ProVideoEditor.getMetadata].
  /// Returns `null` if no source is available or metadata extraction fails.
  Future<double?> _resolveDurationSecs(AudioEvent sound) async {
    final assetPath = sound.assetPath;
    final url = sound.url;
    final localPath = sound.localFilePath;
    if ((assetPath == null || assetPath.isEmpty) &&
        (url == null || url.isEmpty) &&
        (localPath == null || localPath.isEmpty)) {
      return null;
    }
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        localPath != null
            ? EditorVideo.file(File(localPath))
            : EditorVideo.autoSource(assetPath: assetPath, networkUrl: url),
      );
      final secs = metadata.duration.inMilliseconds / 1000.0;
      return secs > 0 ? secs : null;
    } catch (e, s) {
      Log.error(
        'Failed to resolve duration for sound ${sound.id}: $e',
        name: 'AudioSelectionBottomSheet',
        category: LogCategory.ui,
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundledSoundsAsync = ref.watch(soundLibraryServiceProvider);
    final nostrSoundsAsync = ref.watch(trendingSoundsProvider);
    // One batched query for the whole community list rather than a count
    // provider per row. Absent while it resolves, and absent for good if it
    // fails: the counts are supplementary, so the list never waits on them.
    final usageCounts = ref.watch(trendingSoundUsageCountsProvider).value;
    final savedSoundsState = context.watch<SavedSoundsBloc>().state;
    final savedSounds = savedSoundsState.sounds
        .map((sound) => sound.audio)
        .toList(growable: false);

    final bundledVineSounds =
        bundledSoundsAsync.whenOrNull(data: (service) => service.sounds) ??
        <VineSound>[];
    final filteredBundledVineSounds = _searchQuery.isEmpty
        ? bundledVineSounds
        : bundledVineSounds
              .where((sound) => sound.matchesSearch(_searchQuery))
              .toList();
    final bundledSounds = filteredBundledVineSounds.indexed
        .map((e) => AudioEvent.fromBundledSound(e.$2, index: e.$1))
        .toList();
    final featuredSounds =
        (_searchQuery.isEmpty
                ? _featuredVineSounds
                : _featuredVineSounds
                      .where((sound) => sound.matchesSearch(_searchQuery))
                      .toList())
            .indexed
            .map((e) => AudioEvent.fromBundledSound(e.$2, index: e.$1))
            .toList();
    final filteredSavedSounds = _filterAudioEvents(savedSounds);
    const searchEmptyState = _SearchEmptyState();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: .stretch,
          children: [
            AudioCategoryBar(category: _category, onSelect: _selectCategory),
            _PickerSearchInput(
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
            _ImportAudioAction(onTap: _importAudio),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  _SoundsContent(
                    scrollController: widget.scrollController,
                    sounds: bundledSounds,
                    selectedSound: _selectedItem,
                    audioService: _audioService,
                    onSelect: _selectSound,
                  ),
                  nostrSoundsAsync.when(
                    data: (nostrSounds) {
                      return _SoundsContent(
                        scrollController: widget.scrollController,
                        sounds: _filterAudioEvents(nostrSounds),
                        selectedSound: _selectedItem,
                        audioService: _audioService,
                        onSelect: _selectSound,
                        usageCounts: usageCounts,
                        emptyState: _searchQuery.isNotEmpty
                            ? searchEmptyState
                            : const _EmptyState(),
                      );
                    },
                    loading: () =>
                        const Center(child: BrandedLoadingIndicator()),
                    error: (error, stack) => _ErrorState(error: error),
                  ),
                  _SoundsContent(
                    scrollController: widget.scrollController,
                    sounds: featuredSounds,
                    selectedSound: _selectedItem,
                    audioService: _audioService,
                    onSelect: _selectSound,
                    emptyState: _searchQuery.isNotEmpty
                        ? searchEmptyState
                        : const _EmptyState(),
                  ),
                  _SoundsContent(
                    scrollController: widget.scrollController,
                    sounds: filteredSavedSounds,
                    selectedSound: _selectedItem,
                    audioService: _audioService,
                    onSelect: _selectSound,
                    // A saved entry whose file is gone stays listed but
                    // cannot be chosen: selecting it would attach a source
                    // that plays nothing to the draft (#8023).
                    unavailableSoundIds: savedSoundsState.missingFileSoundIds,
                    emptyState: _searchQuery.isNotEmpty
                        ? searchEmptyState
                        : _EmptyState(
                            title: context.l10n.soundsSavedEmptyTitle,
                            subtitle: context.l10n.soundsSavedEmptyDescription,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),

        Align(
          alignment: .bottomCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _selectedItem != null
                ? AudioEditorSelectionOverlay(
                    audio: _selectedItem!,
                    audioService: _audioService,
                    isLoading: _isLoadingAudio,
                    onTapDone: _handleDoneSelection,
                    onTogglePlayState: _togglePlayPause,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _ImportAudioAction extends StatelessWidget {
  const _ImportAudioAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.vineColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.upload_file, color: context.vineColors.primaryText),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.videoEditorAudioImportAudio,
                  style: TextStyle(
                    color: context.vineColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerSearchInput extends StatelessWidget {
  const _PickerSearchInput({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.vineColors.surface,
      child: Semantics(
        identifier: SemanticIds.audioSearchField,
        textField: true,
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
            fillColor: context.vineColors.background,
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
      ),
    );
  }
}

class _SoundsContent extends StatelessWidget {
  const _SoundsContent({
    required this.scrollController,
    required this.sounds,
    required this.selectedSound,
    required this.audioService,
    required this.onSelect,
    this.unavailableSoundIds = const {},
    this.usageCounts,
    this.emptyState = const _EmptyState(),
  });

  final ScrollController scrollController;
  final List<AudioEvent> sounds;
  final AudioEvent? selectedSound;
  final AudioPlaybackService audioService;
  final ValueChanged<AudioEvent> onSelect;

  /// Sounds listed here but not selectable, because their device-local audio
  /// file is gone.
  final Set<String> unavailableSoundIds;

  /// Reuse counts keyed by `AudioEvent.attributionEventId`, or `null` when this
  /// list has no counts to show (bundled and saved tabs, or the community list
  /// before its batched query resolves).
  final Map<String, int>? usageCounts;

  final Widget emptyState;

  int? _videoCountFor(AudioEvent audio) {
    final id = audio.attributionEventId;
    return id == null ? null : usageCounts?[id];
  }

  static const _bottomSpace = 120.0;

  @override
  Widget build(BuildContext context) {
    if (sounds.isEmpty) {
      return emptyState;
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Divider(height: 1, color: context.vineColors.outlineDisabled),
        ),

        SliverList.separated(
          itemCount: sounds.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: context.vineColors.outlineDisabled),
          itemBuilder: (context, index) {
            final audio = sounds[index];
            final isUnavailable = unavailableSoundIds.contains(audio.id);
            final isSelected = !isUnavailable && audio.id == selectedSound?.id;
            if (!isSelected) {
              return AudioListTile(
                audio: audio,
                isSelected: false,
                isUnavailable: isUnavailable,
                videoCount: _videoCountFor(audio),
                semanticIdentifier: SemanticIds.audioSoundTile(index),
                onTap: () => onSelect(audio),
              );
            }
            // Use selectedSound for the selected entry so any duration
            // backfilled after loading the preview shows up in the
            // subtitle.
            final displayAudio = selectedSound ?? audio;
            return StreamBuilder<bool>(
              stream: audioService.playingStream,
              initialData: audioService.isPlaying,
              builder: (context, snapshot) {
                return AudioListTile(
                  audio: displayAudio,
                  isSelected: true,
                  isPlaying: snapshot.data ?? false,
                  videoCount: _videoCountFor(displayAudio),
                  semanticIdentifier: SemanticIds.audioSoundTile(index),
                  onTap: () => onSelect(displayAudio),
                );
              },
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: _bottomSpace)),
        const SliverBottomSafeArea(),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.title, this.subtitle});

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 64,
            color: context.vineColors.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            title ?? context.l10n.videoEditorAudioNoSoundsAvailableTitle,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle ?? context.l10n.videoEditorAudioNoSoundsAvailableSubtitle,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: context.vineColors.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.soundsNoSoundsFound,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.soundsNoSoundsFoundDescription,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DivineIcon(
              icon: DivineIconName.warningCircle,
              size: 64,
              color: VineTheme.likeRed,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.videoEditorAudioFailedToLoadTitle,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: VineTheme.bodySmallFont(
                color: context.vineColors.secondaryText,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(trendingSoundsProvider);
              },
              icon: DivineIcon(
                icon: DivineIconName.arrowClockwise,
                color: context.vineColors.background,
              ),
              label: Text(context.l10n.commonRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: context.vineColors.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
