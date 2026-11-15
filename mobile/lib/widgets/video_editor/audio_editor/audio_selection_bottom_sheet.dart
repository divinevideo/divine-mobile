import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show AudioEvent, AudioEventKind, SoundKind, VineSound, VineSoundKind;
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/divine_sound_extensions.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/models/paged_sounds.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/audio/sound_list_tile.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/private_key_search_warning.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_category_bar.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_editor_selection_overlay.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_kind_filter_pill.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:sound_service/sound_service.dart';
import 'package:sounds_repository/sounds_repository.dart'
    show linkDivineSounds, rankForYouSounds, rankSearchMatches;
import 'package:unified_logger/unified_logger.dart';

class AudioSelectionBottomSheet extends ConsumerStatefulWidget {
  const AudioSelectionBottomSheet({
    this.scrollController,
    this.localAudioImportService,
    this.pickAudioFile,
    this.onSoundPicked,
    this.categoryBarLeading,
    @visibleForTesting this.audioService,
    super.key,
  }) : assert(
         (scrollController == null) != (onSoundPicked == null),
         'Pass the sheet its scrollController, or embed it with onSoundPicked',
       ),
       assert(
         categoryBarLeading == null || onSoundPicked != null,
         'categoryBarLeading only shows when the picker is embedded',
       );

  /// The sheet's controller, which the lists drive so a drag on them closes
  /// the sheet. Embedded, the picker scrolls on its own and takes none.
  final ScrollController? scrollController;
  final LocalAudioImportService? localAudioImportService;
  final Future<XFile?> Function()? pickAudioFile;
  final AudioPlaybackService? audioService;

  /// Receives the confirmed sound when the picker is embedded in a page,
  /// where its search and import scroll away with the list below a pinned
  /// category bar, and the search floats back in on scrolling up.
  ///
  /// Without it the picker is presented by [show], keeps that header pinned,
  /// and pops its route with the sound instead.
  final ValueChanged<AudioEvent>? onSoundPicked;

  /// Pinned to the left of the category bar when the picker is embedded, such
  /// as the button that leaves the page it fills.
  final Widget? categoryBarLeading;

  /// Presents the picker as a full-height sheet, closed by dragging it down.
  /// It has no title row, so the lists get the room.
  static Future<AudioEvent?> show(BuildContext context) {
    return VineBottomSheet.show<AudioEvent>(
      context: context,
      maxChildSize: 1,
      initialChildSize: 1,
      minChildSize: VineTheme.bottomSheetDismissFloor,
      // The sheet's own messenger: a sound the reuse check refuses says so in
      // a snackbar, which would otherwise land on the editor's scaffold,
      // underneath the sheet.
      contentWrapper: (_, sheet) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: VineTheme.transparent,
          resizeToAvoidBottomInset: false,
          body: sheet,
        ),
      ),
      buildScrollBody: (scrollController) =>
          AudioSelectionBottomSheet(scrollController: scrollController),
    );
  }

  /// Starts loading what the picker opens on, For you with its covers and
  /// Divine's own sounds, so a picker opened soon after shows them at once
  /// instead of after the second or two their relay queries take.
  ///
  /// They stay loaded for a few minutes, so calling this again meanwhile
  /// costs nothing.
  static void preload(WidgetRef ref) {
    // The covers wait on For you, so reading them loads both.
    ref
      ..read(forYouSoundCoversProvider)
      ..read(divineSoundsProvider);
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
  AudioCategory _category = .forYou;

  /// The kind every list is narrowed to, or `null` for all sounds.
  SoundKind? _kind;
  String _searchQuery = '';

  /// [_searchQuery] as it stood when the user last paused typing.
  ///
  /// The relay tag query is keyed on this rather than on every keystroke: one
  /// provider instance is created per distinct string, so an undebounced field
  /// would open a relay round trip per character.
  String _debouncedQuery = '';
  Timer? _searchDebounce;
  bool _isLoadingAudio = false;

  /// How tall the card of the picked sound is, so the lists can scroll
  /// their last rows clear of it.
  final _selectionCardHeight = ValueNotifier<double>(0);

  /// How long the field must be quiet before the relay is asked.
  static const _searchDebounceDelay = Duration(milliseconds: 350);

  @override
  int get tabCount => AudioCategory.values.length;

  @override
  void initState() {
    super.initState();
    _audioService = widget.audioService ?? AudioPlaybackService();
    // A preview loops like the video it will play under. Played once, it
    // would also leave its row animating: the player still counts as playing
    // once it reaches the end.
    _audioService.setLooping(looping: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  @override
  void dispose() {
    runDetached(
      _audioService.dispose(),
      'dispose audio playback service',
      logName: 'AudioSelectionBottomSheet',
      category: LogCategory.ui,
    );
    _searchDebounce?.cancel();
    _searchController.dispose();
    _selectionCardHeight.dispose();
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
    _searchDebounce?.cancel();
    if (_searchQuery == _debouncedQuery) return;
    _searchDebounce = Timer(_searchDebounceDelay, () {
      if (!mounted) return;
      setState(() => _debouncedQuery = _searchQuery);
    });
  }

  List<AudioEvent> _filterAudioEvents(List<AudioEvent> sounds) {
    if (_searchQuery.isEmpty && _kind == null) return sounds;
    return sounds
        .where((sound) => sound.matchesSearch(_searchQuery))
        .where(_isOfKind)
        .toList(growable: false);
  }

  /// Whether [sound] is of the chosen kind. A sound of unknown kind only
  /// shows while no kind is chosen.
  bool _isOfKind(AudioEvent sound) => _kind == null || sound.soundKind == _kind;

  /// The newest community sounds to show for the current query.
  ///
  /// The loaded page is filtered first, so the list narrows on the first
  /// keystroke instead of blanking while a debounced query is in flight. Once
  /// [searchResults] has answered for exactly what is typed, the sounds it
  /// reached that the page did not hold are appended.
  ///
  /// Appended rather than swapped in, for two reasons: rows the user can
  /// already see stay where they are when the answer lands, and the list
  /// cannot lose one if the repository's cache no longer holds the loaded
  /// page — as it briefly does not while a refresh is in flight.
  List<AudioEvent> _communitySounds(
    List<AudioEvent> loaded,
    AsyncValue<List<AudioEvent>> searchResults,
  ) {
    final matches = _filterAudioEvents(loaded);
    if (_searchQuery.isEmpty) return matches;
    if (_debouncedQuery != _searchQuery) return matches;
    final reached = searchResults.value;
    if (reached == null) return matches;
    final listed = matches.map((sound) => sound.id).toSet();
    return [
      ...matches,
      ...reached.where(_isOfKind).where((sound) => listed.add(sound.id)),
    ];
  }

  /// [matches] by how well their title fits the search, Divine's first among
  /// equals; as given while nothing is searched.
  List<T> _bySearchFit<T>(
    List<T> matches, {
    required String? Function(T item) titleOf,
    required AudioEvent Function(T item) audioOf,
  }) {
    if (_searchQuery.isEmpty) return matches;
    return rankSearchMatches(
      matches,
      _searchQuery,
      titleOf: titleOf,
      isDivine: (item) => audioOf(item).isDivine,
    );
  }

  List<AudioEvent> _soundsBySearchFit(List<AudioEvent> matches) =>
      _bySearchFit(matches, titleOf: (sound) => sound.title, audioOf: (s) => s);

  /// The "For you" list unsearched: the first page of followed sounds ranked
  /// in among Divine's own, and each later page ranked on its own after it.
  ///
  /// A later page holds only sounds older than the first's, so ranking it in
  /// with the rest would move rows the user has scrolled past.
  List<AudioEvent> _rankedForYou(
    List<List<AudioEvent>> followedPages,
    List<AudioEvent> divineSounds,
  ) {
    final now = clock.now();
    return [
      ...rankForYouSounds(
        followed: followedPages.firstOrNull ?? const [],
        divine: divineSounds,
        now: now,
      ),
      for (final page in followedPages.skip(1))
        ...rankForYouSounds(followed: page, divine: const [], now: now),
    ];
  }

  /// The cover the picked sound's row shows: the one it was published with,
  /// a saved sound's cover, or the frame of its source video.
  SoundCover? _selectedCover({
    required List<SavedSound> savedSounds,
    required Map<String, SoundCover?>? savedSourceCovers,
    required List<Map<String, SoundCover?>?> coversBySourceVideo,
  }) {
    final selected = _selectedItem;
    if (selected == null) return null;
    if (SoundCover.publishedWith(selected) case final cover?) return cover;
    for (final saved in savedSounds) {
      if (saved.id != selected.id) continue;
      final cover = SoundCover.forSavedSound(
        saved,
        sourceCovers: savedSourceCovers,
      );
      if (cover != null) return cover;
    }
    final reference = selected.sourceVideoReference;
    if (reference == null) return null;
    for (final covers in coversBySourceVideo) {
      if (covers?[reference] case final cover?) return cover;
    }
    return null;
  }

  /// Whether [sound] was taken from a video [lookup] looked for and did not
  /// find, deleted or hidden from this viewer, or whose creator lets no one
  /// else reuse its sound.
  ///
  /// Such a sound would not pass the reuse check, so its row would only
  /// refuse a tap. A sound [lookup] has not reached yet is not left out.
  bool _cannotBeReused(
    AudioEvent sound,
    AsyncValue<Map<String, SoundCover?>>? lookup,
  ) => SoundCover.cannotBeReused(
    sound,
    lookup == null || lookup.hasError ? null : lookup.value,
    viewerPubkeyHex: ref.read(authServiceProvider).currentPublicKeyHex,
  );

  /// Loads [sound] into the preview player, stopping whatever played, and
  /// returns it with the duration the file reports when the event carried
  /// none, so the overlay and the row can show it.
  Future<AudioEvent> _loadPreview(AudioEvent sound) async {
    // From here the player no longer holds the sound it held, so a sound
    // picked while this loads is loaded anew rather than played from it.
    _loadedSoundId = null;
    await _audioService.stop();
    final loadedDuration = sound.isLocalImport && sound.localFilePath != null
        ? await _audioService.loadAudioFromFile(sound.localFilePath!)
        : await _audioService.loadAudio(sound.url!);
    _loadedSoundId = sound.id;
    if (sound.duration == null && loadedDuration != null) {
      return sound.copyWith(duration: loadedDuration.inMilliseconds / 1000.0);
    }
    return sound;
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
        try {
          resolvedSound = await _loadPreview(sound);
        } finally {
          // A sound picked meanwhile owns the flag, which holds Done while
          // its reuse check runs.
          if (mounted && _selectedItem?.id == sound.id) {
            setState(() => _isLoadingAudio = false);
          }
        }
      }

      // Another sound was picked while this one loaded; that one plays.
      if (!mounted || _selectedItem?.id != sound.id) return;
      setState(() {
        _selectedItem = resolvedSound;
      });
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
    // Tapping the picked sound again unpicks it.
    if (_selectedItem?.id == sound.id) return _deselectSound();

    // Bundled / imported / provider-catalog sounds carry their own terms and
    // never reach the resolver. Everything else — including the creator's own
    // sounds — is decided by `audioReuseConsentProvider`, which owns the owner
    // exception this call site used to be missing.
    final needsConsent =
        !sound.isBundled &&
        !sound.isLocalImport &&
        !sound.isExternalProviderSound;
    var preview = sound;
    if (needsConsent) {
      // A sound the check refuses must not play, so the preview waits for it,
      // with the row picked and the overlay loading. The file loads
      // meanwhile, and a sound picked from a list hands the check the source
      // video its cover came from, so both take about as long.
      setState(() {
        _selectedItem = sound;
        _isLoadingAudio = true;
      });
      final loading = _loadPreview(sound).then<AudioEvent?>(
        (loaded) => loaded,
        // The preview below reloads and reports a file that would not load.
        onError: (Object _) => null,
      );
      final canReuse = await ref.read(audioReuseConsentProvider(sound).future);
      // Another tap came in meanwhile; that one decides.
      if (!mounted || _selectedItem?.id != sound.id) return;
      if (!canReuse) {
        await _refuseReuse(sound);
        return;
      }
      final loaded = await loading;
      if (!mounted || _selectedItem?.id != sound.id) return;
      preview = loaded ?? sound;
      setState(() => _isLoadingAudio = false);
    }

    Log.info(
      'Sound selected: ${sound.title ?? 'Untitled'} (${sound.id})',
      name: 'AudioSelectionBottomSheet',
      category: LogCategory.ui,
    );
    setState(() {
      _selectedItem = preview;
    });
    await _togglePlayPause(enforcePlay: true);
  }

  /// Leaves no sound picked and stops the preview. A reuse check or a file
  /// still loading for the sound finds it unpicked and stops there.
  Future<void> _deselectSound() async {
    setState(() {
      _selectedItem = null;
      _isLoadingAudio = false;
    });
    await _audioService.pause();
    await _audioService.seek(.zero);
  }

  /// Unpicks [sound], whose creator does not allow reusing it, and says so.
  Future<void> _refuseReuse(AudioEvent sound) async {
    await _audioService.stop();
    if (!mounted) return;
    setState(() {
      _selectedItem = null;
      _isLoadingAudio = false;
    });
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
  }

  Future<void> _importAudio() async {
    final picker =
        widget.pickAudioFile ??
        () => ref
            .read(audioFilePickerServiceProvider)
            .pickAudioFile(typeGroupLabel: context.l10n.audioPickerTypeGroup);

    try {
      final file = await picker();
      if (file == null) return;
      final filePath = file.path;
      if (filePath.isEmpty) return;

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
      Log.warning(
        'Audio import refused (${e.reason.name}): ${e.message}',
        name: 'AudioSelectionBottomSheet',
        category: LogCategory.ui,
      );
      if (!mounted) return;
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (e.reason) {
            LocalAudioImportFailureReason.unsupportedType =>
              l10n.soundsImportUnsupportedFormat,
            LocalAudioImportFailureReason.unreadableSource ||
            LocalAudioImportFailureReason.copyFailed ||
            LocalAudioImportFailureReason.decodeFailed =>
              l10n.soundsImportUnreadable,
          }),
        ),
      );
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
      if (widget.onSoundPicked == null) context.pop();
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
            _complete(sound);
          case AudioTimingDeleted():
            break;
        }
      }
    } else {
      _complete(sound);
    }
  }

  void _complete(AudioEvent sound) {
    final onSoundPicked = widget.onSoundPicked;
    if (onSoundPicked != null) {
      onSoundPicked(sound);
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
    // The owner exemption follows account changes just as the tap check does.
    ref.watch(currentAuthStateProvider);
    final bundledSoundsAsync = ref.watch(soundLibraryServiceProvider);
    // Batched like the counts below and just as supplementary: a row waits on
    // a plain tile while its list's covers load, then shows its cover, or its
    // colour tile if it has none. Every list keeps its own covers, so a tab
    // that swipes in shows the ones it already has. A failed lookup settles as
    // no covers, so its rows fall back to their colour tiles instead of
    // waiting.
    Map<String, SoundCover?>? settled(
      AsyncValue<Map<String, SoundCover?>> covers,
    ) => covers.hasError ? const {} : covers.value;
    // The open list loads first and the others once its covers are in, so
    // their relay queries do not hold it up: with all three loading at once,
    // For you's covers took 0.71-0.87 s against 0.43-0.57 s alone.
    final openCovers = switch (_category) {
      AudioCategory.forYou => settled(ref.watch(forYouSoundCoversProvider)),
      AudioCategory.popular => settled(ref.watch(popularSoundCoversProvider)),
      AudioCategory.newest => settled(ref.watch(trendingSoundCoversProvider)),
      AudioCategory.mySounds => const <String, SoundCover?>{},
    };
    bool loads(AudioCategory category) =>
        category == _category || openCovers != null;
    final forYouAsync = loads(.forYou)
        ? ref.watch(forYouSoundsProvider)
        : const AsyncLoading<PagedSounds>();
    final divineSoundsAsync = loads(.forYou)
        ? ref.watch(divineSoundsProvider)
        : null;
    final popularAsync = loads(.popular)
        ? ref.watch(popularSoundsProvider)
        : const AsyncLoading<PagedSounds>();
    final nostrSoundsAsync = loads(.newest)
        ? ref.watch(trendingSoundsProvider)
        : const AsyncLoading<PagedSounds>();
    final forYouLookup = loads(.forYou)
        ? ref.watch(forYouSoundCoversProvider)
        : null;
    final popularLookup = loads(.popular)
        ? ref.watch(popularSoundCoversProvider)
        : null;
    final trendingLookup = loads(.newest)
        ? ref.watch(trendingSoundCoversProvider)
        : null;
    final forYouCovers = forYouLookup == null ? null : settled(forYouLookup);
    final popularCovers = popularLookup == null ? null : settled(popularLookup);
    final trendingCovers = trendingLookup == null
        ? null
        : settled(trendingLookup);
    // One batched query for the whole newest list rather than a count
    // provider per row. Absent while it resolves, and absent for good if it
    // fails: the counts are supplementary, so the list never waits on them.
    final usageCounts = loads(.newest)
        ? ref.watch(trendingSoundUsageCountsProvider).value
        : null;
    final savedSoundsState = context.watch<SavedSoundsBloc>().state;
    final savedSourcesLookup = loads(.mySounds)
        ? ref.watch(
            savedSoundSourcesProvider(
              SoundSourceReferences(
                savedSoundsState.sounds.map((sound) => sound.audio),
              ),
            ),
          )
        : null;
    final savedSourceCovers =
        savedSourcesLookup == null || savedSourcesLookup.hasError
        ? null
        : savedSourcesLookup.value;
    // Searched as whole records, not as their bare audio: the label and
    // hashtags the user filed a sound under live on the record, and they are
    // the words they will reach for here.
    final matchingSavedSounds = _bySearchFit(
      savedSoundsState.sounds
          .where((sound) => sound.matchesSearch(_searchQuery))
          .where((sound) => _isOfKind(sound.audio))
          .toList(growable: false),
      // The row shows the owner's label, so that is the title that fits.
      titleOf: (sound) => sound.personalLabel ?? sound.audio.title,
      audioOf: (sound) => sound.audio,
    );
    // Only the Newest tab shows relay results. The field is shared, so on
    // any other tab the query stays local: on My sounds it is often a
    // private label, which must not go out as a `#t` filter.
    final newestQuery = _category == AudioCategory.newest
        ? _debouncedQuery
        : '';
    final searchResults = ref.watch(soundSearchResultsProvider(newestQuery));
    final searchLookup = ref.watch(soundSearchCoversProvider(newestQuery));
    final searchCovers = settled(searchLookup);

    final bundledVineSounds =
        bundledSoundsAsync.whenOrNull(data: (service) => service.sounds) ??
        <VineSound>[];
    // Divine's own sounds are matched as their manifest entries, whose tags
    // the converted sounds below do not carry.
    final filteredBundledVineSounds = bundledVineSounds
        .where((sound) => sound.matchesSearch(_searchQuery))
        .where((sound) => _kind == null || sound.soundKind == _kind)
        .toList();
    final shownBundledIds = {
      for (final sound in filteredBundledVineSounds)
        '${AudioEvent.bundledMarker}_${sound.id}',
    };
    // Divine's sounds: the ones the app ships, each tied to the event Divine
    // published for it, then the published ones it does not ship. Tied before
    // they are narrowed, so a shipped sound a search leaves out cannot let
    // its published event back in as a sound of its own.
    final divineSounds = [
      for (final sound in linkDivineSounds(
        shipped: [
          for (final (index, sound) in bundledVineSounds.indexed)
            AudioEvent.fromBundledSound(sound, index: index),
        ],
        published: divineSoundsAsync?.value ?? const [],
      ))
        if (sound.isBundled
            ? shownBundledIds.contains(sound.id)
            : sound.matchesSearch(_searchQuery) && _isOfKind(sound))
          sound,
    ];
    // Outside My sounds, importing is offered where a search came up empty:
    // the sound the user wanted is not here, so it may be on their device.
    final searchEmptyState = _SearchEmptyState(
      hasQuery: _searchQuery.isNotEmpty,
      onImport: _importAudio,
    );
    final embedded = widget.onSoundPicked != null;
    // Embedded, there is no controller, so each list picks up the inner
    // controller of the NestedScrollView below as its primary one.
    final listScrollController = widget.scrollController;

    final categoryBar = AudioCategoryBar(
      controller: tabController,
      onSelect: _selectCategory,
    );
    final searchInput = _PickerSearchInput(
      controller: _searchController,
      onChanged: _onSearchChanged,
      // The kind narrows every list as the search does, so it sits in the
      // search field.
      suffix: AudioKindFilterPill(
        selected: _kind,
        onChanged: (kind) => setState(() => _kind = kind),
      ),
    );
    // A kind narrows a list the way a search does, so an empty result
    // says nothing matched rather than that there are no sounds at all.
    final isNarrowed = _searchQuery.isNotEmpty || _kind != null;
    final emptyState = isNarrowed ? searchEmptyState : const _EmptyState();
    const loadingState = Center(child: BrandedLoadingIndicator());
    // A list loads its next page when scrolled to its end, but not while a
    // search or a kind narrows it. A search orders it by fit, which changes
    // with every page. A kind may match nothing a page brings, so the end
    // would stay in reach and ask on through the whole list: Popular's 1070
    // sounds held not one effect.
    final loadsMoreOnScroll = !isNarrowed;
    final followedPages = [
      for (final page in forYouAsync.value?.pages ?? const <List<AudioEvent>>[])
        _filterAudioEvents(
          page,
        ).where((sound) => !_cannotBeReused(sound, forYouLookup)).toList(),
    ];
    // Its own Material, so the rows' ink shows over the sheet's background.
    final lists = Material(
      type: MaterialType.transparency,
      child: TabBarView(
        controller: tabController,
        children: [
          // Sounds from people the viewer follows, ranked in among Divine's own
          // by how new they are. Divine's are always there, so a failed or empty
          // lookup still leaves a list rather than an error.
          if (forYouAsync.hasValue || forYouAsync.hasError)
            _SoundsContent(
              scrollController: listScrollController,
              selectionCardHeight: _selectionCardHeight,
              // A search orders by fit instead, with no daily mix.
              sounds: _searchQuery.isEmpty
                  ? _rankedForYou(followedPages, divineSounds)
                  : _soundsBySearchFit([
                      for (final page in followedPages) ...page,
                      ...divineSounds,
                    ]),
              selectedSound: _selectedItem,
              audioService: _audioService,
              onSelect: _selectSound,
              coversBySourceVideo: forYouCovers,
              isLookingUpCovers: forYouLookup?.isLoading ?? false,
              paging: loadsMoreOnScroll ? forYouAsync.value : null,
              onLoadMore: ref.read(forYouSoundsProvider.notifier).loadMore,
              emptyState: emptyState,
            )
          else
            loadingState,
          popularAsync.when(
            data: (popular) => _SoundsContent(
              scrollController: listScrollController,
              selectionCardHeight: _selectionCardHeight,
              sounds: _soundsBySearchFit(
                _filterAudioEvents(popular.sounds)
                    .where((sound) => !_cannotBeReused(sound, popularLookup))
                    .toList(),
              ),
              selectedSound: _selectedItem,
              audioService: _audioService,
              onSelect: _selectSound,
              usageCounts: popular.usageCounts,
              coversBySourceVideo: popularCovers,
              isLookingUpCovers: popularLookup?.isLoading ?? false,
              paging: loadsMoreOnScroll ? popular : null,
              onLoadMore: ref.read(popularSoundsProvider.notifier).loadMore,
              emptyState: emptyState,
            ),
            loading: () => loadingState,
            error: (error, stack) => _ErrorState(
              error: error,
              onRetry: () => ref.invalidate(popularSoundsProvider),
            ),
          ),
          nostrSoundsAsync.when(
            data: (newestList) {
              final nostrSounds = newestList.sounds;
              final newest = {for (final sound in nostrSounds) sound.id};
              return _SoundsContent(
                scrollController: listScrollController,
                selectionCardHeight: _selectionCardHeight,
                // A search result's video is looked up with the search.
                sounds: _soundsBySearchFit(
                  _communitySounds(nostrSounds, searchResults)
                      .where(
                        (sound) => !_cannotBeReused(
                          sound,
                          newest.contains(sound.id)
                              ? trendingLookup
                              : searchLookup,
                        ),
                      )
                      .toList(),
                ),
                selectedSound: _selectedItem,
                audioService: _audioService,
                onSelect: _selectSound,
                usageCounts: usageCounts,
                coversBySourceVideo: trendingCovers == null
                    ? null
                    : {...trendingCovers, ...?searchCovers},
                isLookingUpCovers:
                    (trendingLookup?.isLoading ?? false) ||
                    searchLookup.isLoading,
                paging: loadsMoreOnScroll ? newestList : null,
                onLoadMore: ref.read(trendingSoundsProvider.notifier).loadMore,
                emptyState: emptyState,
              );
            },
            loading: () => loadingState,
            error: (error, stack) => _ErrorState(
              error: error,
              onRetry: () => ref.invalidate(trendingSoundsProvider),
            ),
          ),
          // My sounds is where the user's own files live, so importing one
          // stays its first row.
          _SoundsContent(
            scrollController: listScrollController,
            selectionCardHeight: _selectionCardHeight,
            leading: _ImportAudioAction(onTap: _importAudio),
            sounds: matchingSavedSounds
                .map((sound) => sound.audio)
                .where((sound) => !_cannotBeReused(sound, savedSourcesLookup))
                .toList(growable: false),
            displayTitles: {
              for (final sound in matchingSavedSounds)
                sound.id: ?sound.personalLabel,
            },
            // The same covers My Sounds in the Library shows.
            covers: {
              for (final sound in matchingSavedSounds)
                sound.id: ?SoundCover.forSavedSound(
                  sound,
                  sourceCovers: savedSourceCovers,
                ),
            },
            selectedSound: _selectedItem,
            audioService: _audioService,
            onSelect: _selectSound,
            // A saved entry whose file is gone stays listed but
            // cannot be chosen: selecting it would attach a source
            // that plays nothing to the draft (#8023).
            unavailableSoundIds: savedSoundsState.missingFileSoundIds,
            emptyState: isNarrowed
                ? _SearchEmptyState(hasQuery: _searchQuery.isNotEmpty)
                : _EmptyState(
                    title: context.l10n.soundsSavedEmptyTitle,
                    subtitle: context.l10n.soundsSavedEmptyDescription,
                  ),
          ),
        ],
      ),
    );

    final picker = Stack(
      children: [
        if (embedded)
          // Embedded in a page, the categories stay put while the search
          // scrolls away with the list and floats back in as soon as the list
          // scrolls up again.
          Column(
            crossAxisAlignment: .stretch,
            children: [
              if (widget.categoryBarLeading case final leading?)
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 12),
                      child: leading,
                    ),
                    Expanded(child: categoryBar),
                  ],
                )
              else
                categoryBar,
              Expanded(
                child: NestedScrollView(
                  floatHeaderSlivers: true,
                  headerSliverBuilder: (context, _) => [
                    SliverFloatingHeader(
                      animationStyle: context.reduceMotion
                          ? AnimationStyle.noAnimation
                          : null,
                      child: searchInput,
                    ),
                  ],
                  body: lists,
                ),
              ),
            ],
          )
        else
          // The search filters every list, so it sits above their tabs.
          Column(
            crossAxisAlignment: .stretch,
            children: [
              searchInput,
              categoryBar,
              Expanded(child: lists),
            ],
          ),

        Align(
          alignment: .bottomCenter,
          // Picking a sound fades the card up into place from below the
          // bottom edge, its safe-area padding included, and unpicking it runs
          // the same way back. Switching to another sound keeps the card, as
          // both are the same widget.
          child: _HeightReporter(
            height: _selectionCardHeight,
            child: AnimatedSwitcher(
              duration: const Duration(
                milliseconds: 220,
              ).autoReduceMotion(context),
              switchInCurve: Curves.easeOutCubic,
              // An outgoing child runs this curve backwards, so an ease-out
              // here leaves the card slowly and speeds it away. An ease-in
              // would drop half of it in the first few frames.
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _selectedItem != null
                  ? AudioEditorSelectionOverlay(
                      audio: _selectedItem!,
                      cover: _selectedCover(
                        savedSounds: savedSoundsState.sounds,
                        savedSourceCovers: savedSourceCovers,
                        coversBySourceVideo: [
                          forYouCovers,
                          popularCovers,
                          trendingCovers,
                          searchCovers,
                        ],
                      ),
                      audioService: _audioService,
                      isLoading: _isLoadingAudio,
                      onTapDone: _handleDoneSelection,
                      onTogglePlayState: _togglePlayPause,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );

    return _KeyboardClearance(child: picker);
  }
}

/// Keeps [child] clear of the software keyboard by padding its bottom with
/// the part of the keyboard that covers it.
///
/// None of the picker's hosts resize for the keyboard, so without this the
/// last rows, the empty state and the Done bar sit behind it while the user
/// searches. Embedded in the recorder the picker ends above the mode wheel,
/// so only the keyboard above its own bottom edge is taken off.
class _KeyboardClearance extends StatefulWidget {
  const _KeyboardClearance({required this.child});

  final Widget child;

  @override
  State<_KeyboardClearance> createState() => _KeyboardClearanceState();
}

class _KeyboardClearanceState extends State<_KeyboardClearance> {
  /// How far this widget's bottom edge sat above the bottom of the screen
  /// at its last measurement.
  double _spaceBelow = 0;
  bool _isMeasureScheduled = false;

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    // The space below only matters while the keyboard is up, and it can
    // change as it rises: what sits below gives up its safe-area padding.
    if (keyboardHeight > 0) {
      _scheduleMeasure(screenHeight: MediaQuery.sizeOf(context).height);
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: math.max(0, keyboardHeight - _spaceBelow),
      ),
      // What the picker lays out below is already clear of the keyboard.
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: widget.child,
      ),
    );
  }

  void _scheduleMeasure({required double screenHeight}) {
    if (_isMeasureScheduled) return;
    _isMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasureScheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      final spaceBelow = math.max(0.0, screenHeight - bottom);
      if (spaceBelow == _spaceBelow) return;
      setState(() => _spaceBelow = spaceBelow);
    });
  }
}

/// My sounds' first row: imports an audio file from the device. Shaped like
/// the sound rows below it, with a tile where their cover sits.
class _ImportAudioAction extends StatelessWidget {
  const _ImportAudioAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoundListActionTile(
      key: const Key('audio_import_action'),
      icon: DivineIconName.folderOpen,
      title: context.l10n.videoEditorAudioImportAudio,
      subtitle: context.l10n.soundUploadSupportedFormats,
      onTap: onTap,
    );
  }
}

class _PickerSearchInput extends StatelessWidget {
  const _PickerSearchInput({
    required this.controller,
    required this.onChanged,
    required this.suffix,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Sits at the field's end, inside it.
  final Widget suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.vineColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: SemanticIds.audioSearchField,
            textField: true,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: context.vineColors.primaryText),
              decoration: InputDecoration(
                hintText: context.l10n.soundsSearchHint,
                hintStyle: TextStyle(
                  color: context.vineColors.onSurfaceMuted,
                ),
                prefixIconConstraints: const BoxConstraints(),
                suffixIconConstraints: const BoxConstraints(),
                suffixIcon: suffix,
                prefixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 12,
                    end: 8,
                  ),
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
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => PrivateKeySearchWarning(
              query: value.text,
              padding: const EdgeInsets.only(top: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundsContent extends ConsumerWidget {
  const _SoundsContent({
    required this.scrollController,
    required this.selectionCardHeight,
    required this.sounds,
    required this.selectedSound,
    required this.audioService,
    required this.onSelect,
    this.displayTitles = const {},
    this.covers = const {},
    this.coversBySourceVideo = const {},
    this.isLookingUpCovers = false,
    this.unavailableSoundIds = const {},
    this.usageCounts,
    this.paging,
    this.onLoadMore,
    this.emptyState = const _EmptyState(),
    this.leading,
  });

  /// Drives the list, or `null` to use the primary scroll controller, as
  /// inside a [NestedScrollView].
  final ScrollController? scrollController;

  /// How tall the card of the picked sound over the list's end is.
  final ValueListenable<double> selectionCardHeight;
  final List<AudioEvent> sounds;
  final AudioEvent? selectedSound;
  final AudioPlaybackService audioService;
  final ValueChanged<AudioEvent> onSelect;

  /// Row titles that override the sound's own, keyed by `AudioEvent.id`.
  ///
  /// The saved tab passes the private labels, so a row reads the way its
  /// owner filed it.
  final Map<String, String> displayTitles;

  /// Row covers keyed by `AudioEvent.id`.
  final Map<String, SoundCover> covers;

  /// Row covers keyed by `AudioEvent.sourceVideoReference`, for sounds whose
  /// cover is the video they came from: `null` for a video looked up and not
  /// found, absent for one not looked up. The map is `null` while the first
  /// lookup runs.
  final Map<String, SoundCover?>? coversBySourceVideo;

  /// Whether a lookup for [coversBySourceVideo] is running, so rows it has
  /// not reached yet wait for it.
  final bool isLookingUpCovers;

  /// Sounds listed here but not selectable, because their device-local audio
  /// file is gone.
  final Set<String> unavailableSoundIds;

  /// Reuse counts keyed by `AudioEvent.attributionEventId`, or `null` when this
  /// list has no counts to show (bundled and saved tabs, or the community list
  /// before its batched query resolves).
  final Map<String, int>? usageCounts;

  /// How far the list has loaded, when it loads its next page on reaching
  /// its end through [onLoadMore]; `null` for a list that shows all it has.
  final PagedSounds? paging;

  /// Loads the next page of [paging].
  final VoidCallback? onLoadMore;

  final Widget emptyState;

  /// Scrolls with the list above its first row, and stays above [emptyState].
  final Widget? leading;

  int? _videoCountFor(AudioEvent audio) {
    final id = audio.attributionEventId;
    return id == null ? null : usageCounts?[id];
  }

  SoundCover? _coverFor(AudioEvent audio) {
    // A cover the uploader chose wins over the frame of a source video.
    if (SoundCover.publishedWith(audio) case final cover?) return cover;
    if (covers[audio.id] case final cover?) return cover;
    final reference = audio.sourceVideoReference;
    return reference == null ? null : coversBySourceVideo?[reference];
  }

  /// Whether [audio]'s cover is still being looked up, so its row waits on a
  /// plain tile rather than showing a colour it may not keep.
  bool _isCoverPending(AudioEvent audio) {
    final reference = audio.sourceVideoReference;
    if (reference == null || SoundCover.publishedWith(audio) != null) {
      return false;
    }
    final covers = coversBySourceVideo;
    return covers == null ||
        (isLookingUpCovers && !covers.containsKey(reference));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlocked = ref.watch(soundAuthorFilterProvider);
    final sounds = this.sounds
        .where((sound) => !isBlocked(sound.pubkey))
        .toList(growable: false);
    final leading = this.leading;
    final paging = this.paging;
    final onLoadMore = this.onLoadMore;
    final loadsMore = paging != null && onLoadMore != null && paging.hasMore;
    // Nothing to show yet may only mean the pages so far held nothing that
    // fits, so a list with more to load goes on loading.
    if (sounds.isEmpty && !loadsMore) {
      return _LeadingAbove(leading: leading, child: emptyState);
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        if (leading != null) SliverToBoxAdapter(child: leading),
        SliverList.builder(
          // While more can load, one row after the sounds asks for them. A
          // list builds its rows only as they near the screen, so it asks
          // once the list is scrolled to its end.
          itemCount: sounds.length + (loadsMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == sounds.length) {
              return _LoadMoreRow(
                isLoading: paging!.isLoadingMore,
                loadedPages: paging.pages.length,
                onLoadMore: onLoadMore!,
              );
            }
            final audio = sounds[index];
            final isUnavailable = unavailableSoundIds.contains(audio.id);
            final isSelected = !isUnavailable && audio.id == selectedSound?.id;
            if (!isSelected) {
              return AudioListTile(
                audio: audio,
                displayTitle: displayTitles[audio.id],
                cover: _coverFor(audio),
                isCoverPending: _isCoverPending(audio),
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
                  displayTitle: displayTitles[displayAudio.id],
                  cover: _coverFor(displayAudio),
                  isCoverPending: _isCoverPending(displayAudio),
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
        SliverToBoxAdapter(
          child: _ListEndSpace(selectionCardHeight: selectionCardHeight),
        ),
        const SliverBottomSafeArea(),
      ],
    );
  }
}

/// The space after a list's last row, so it scrolls clear of the card of the
/// picked sound.
class _ListEndSpace extends StatelessWidget {
  const _ListEndSpace({required this.selectionCardHeight});

  final ValueListenable<double> selectionCardHeight;

  /// The space when the card fits in it, as it does at the normal text size.
  static const _minHeight = 120.0;

  /// Left between the last row and the card.
  static const _gap = 16.0;

  @override
  Widget build(BuildContext context) {
    // The card pads its bottom for the safe area, which the list adds after
    // this space too.
    final safeArea = MediaQuery.paddingOf(context).bottom;
    return ValueListenableBuilder<double>(
      valueListenable: selectionCardHeight,
      builder: (context, cardHeight, _) => SizedBox(
        height: math.max(_minHeight, cardHeight - safeArea + _gap),
      ),
    );
  }
}

/// Writes how tall [child] is laid out into [height], after each frame it
/// changes in.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.height, super.child});

  final ValueNotifier<double> height;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightReporter(height);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) {
    renderObject.height = height;
  }
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.height);

  ValueNotifier<double> height;

  @override
  void performLayout() {
    super.performLayout();
    if (size.height == height.value) return;
    // Listeners rebuild, which cannot happen while the tree lays out.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached && hasSize) height.value = size.height;
    });
  }
}

/// The row after a list's last sound while more can load. Built once the
/// list nears its end, it asks for the next page, and again each time a page
/// lands without pushing it out of reach; it spins while one loads.
class _LoadMoreRow extends StatefulWidget {
  const _LoadMoreRow({
    required this.isLoading,
    required this.loadedPages,
    required this.onLoadMore,
  });

  final bool isLoading;

  /// How many pages the list has loaded.
  final int loadedPages;

  final VoidCallback onLoadMore;

  @override
  State<_LoadMoreRow> createState() => _LoadMoreRowState();
}

class _LoadMoreRowState extends State<_LoadMoreRow> {
  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void didUpdateWidget(_LoadMoreRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A page whose sounds were all left out adds no rows, so this row stays
    // where it is, still in reach.
    if (widget.loadedPages != oldWidget.loadedPages) _ask();
  }

  // Asked as the list builds, when a provider may not change yet.
  void _ask() => scheduleMicrotask(widget.onLoadMore);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: widget.isLoading
          ? Center(
              child: DivineCircularProgressIndicator(
                color: context.vineColors.accentPositive,
                semanticsLabel: context.l10n.commonLoading,
              ),
            )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.title, this.subtitle});

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return _CenteredScrollable(
      padding: _emptyStatePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_off,
            size: 64,
            color: context.vineColors.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            title ?? context.l10n.videoEditorAudioNoSoundsAvailableTitle,
            textAlign: TextAlign.center,
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
  const _SearchEmptyState({required this.hasQuery, this.onImport});

  /// Whether a search, rather than only the kind filter, narrowed the list;
  /// only then does trying another term help.
  final bool hasQuery;

  /// Offers importing a file instead, or `null` where the list already does.
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return _CenteredScrollable(
      padding: _emptyStatePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: context.vineColors.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.soundsNoSoundsFound,
            textAlign: TextAlign.center,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          if (hasQuery) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.soundsNoSoundsFoundDescription,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (onImport case final onImport?) ...[
            const SizedBox(height: 24),
            DivineButton(
              key: const Key('audio_search_import'),
              label: context.l10n.videoEditorAudioImportAudio,
              leadingIcon: DivineIconName.folderOpen,
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              onPressed: onImport,
            ),
          ],
        ],
      ),
    );
  }
}

/// Keeps an empty state's lines off the screen's edges when they wrap.
const _emptyStatePadding = EdgeInsets.symmetric(horizontal: 24);

/// Centres [child] in the space it is given, and lets it scroll once that
/// space is shorter than it, as above a raised keyboard on a small phone.
class _CenteredScrollable extends StatelessWidget {
  const _CenteredScrollable({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// [leading] above [child], which fills the rest, or just [child] without
/// one.
class _LeadingAbove extends StatelessWidget {
  const _LeadingAbove({required this.leading, required this.child});

  final Widget? leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    if (leading == null) return child;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        leading,
        Expanded(child: child),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;

  /// Loads the list that failed again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredScrollable(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              onPressed: onRetry,
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
