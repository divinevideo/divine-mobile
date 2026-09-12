// ABOUTME: Main screen for the video editor with layer editing capabilities.
// ABOUTME: Orchestrates BLoC providers, sticker precaching, and editor canvas.

import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/blocs/video_editor/voice_over/voice_over_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/features/creation_analytics/creation_analytics_tracker.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/codec_heavy_surface_guard.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/video_editor/caption_layer_mapping.dart';
import 'package:openvine/models/video_editor/caption_style_preset.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/repositories/sticker_repository.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_editor/video_text_editor_screen.dart';
import 'package:openvine/screens/video_editor/voice_over_recorder_screen.dart';
import 'package:openvine/screens/video_editor/voice_over_take_commit.dart';
import 'package:openvine/screens/video_editor/voice_over_take_placement.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/await_push_transition.dart';
import 'package:openvine/utils/editor_text_fonts.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_captions_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_scaffold.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// The main video editor screen for adding layers (text, stickers, effects).
///
/// Manages the [VideoEditorMainBloc] and [VideoEditorStickerBloc] lifecycle,
/// precaches sticker images, and coordinates the editor canvas with toolbars.
class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({super.key, this.draftId, this.fromLibrary = false});

  /// Optional draft ID to load an existing draft.
  final String? draftId;

  /// Whether the editor was opened from the clip library.
  final bool fromLibrary;

  /// Route name for this screen.
  static const routeName = 'video-editor';

  static const draftRouteName = '$routeName-draft';

  /// Path for this route.
  static const String path = RoutePaths.videoEditor;

  static const draftPathWithId = '$path/:draftId';

  /// Query parameter carrying how the editor was entered.
  static const originQueryParameter = 'from';

  /// Value of [originQueryParameter] for an entry from the clip library.
  static const libraryOrigin = 'library';

  /// Builds the editor location, optionally for an existing [draftId].
  ///
  /// The origin rides in the URL rather than `extra` so a restored session
  /// keeps the library exit behaviour instead of silently falling back to the
  /// recorder one (#3335).
  static String pathFor({String? draftId, bool fromLibrary = false}) {
    return Uri(
      path: draftId == null || draftId.isEmpty ? path : '$path/$draftId',
      queryParameters: fromLibrary
          ? {originQueryParameter: libraryOrigin}
          : null,
    ).toString();
  }

  /// Whether [uri] entered the editor from the clip library.
  static bool fromLibraryForRoute(Uri uri) =>
      uri.queryParameters[originQueryParameter] == libraryOrigin;

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen>
    with CodecHeavySurfaceGuard {
  // The editor builds its preview decoder immediately, so release the feed's
  // decoder now rather than waiting for the entrance transition.
  @override
  bool get assertCodecSignalAfterEntranceTransition => false;

  final _editorKey = GlobalKey<ProImageEditorState>();
  final GlobalKey<State<StatefulWidget>> _removeAreaKey = GlobalKey();

  /// Marks the canvas body so a full-screen tool laid over the editor can map
  /// a touch back into layer coordinates.
  final GlobalKey _canvasBodyKey = GlobalKey();

  late final _isLoadingDraft = ValueNotifier<bool>(widget.draftId != null);

  /// Manually managed instead of using [BlocProvider.create] so we can reuse
  /// it in contexts outside the widget tree (e.g., bottom sheets opened via
  /// [VineBottomSheet.show]).
  late final VideoEditorStickerBloc _stickerBloc;

  /// Manually managed so we can dispatch [ClipEditorInitialized] after the
  /// video editor provider finishes loading (especially for drafts).
  late final ClipEditorBloc _clipEditorBloc;

  /// Manually managed so [_extractWaveform] can dispatch events without
  /// needing a child context below [MultiBlocProvider].
  late final TimelineOverlayBloc _timelineOverlayBloc;
  late final CreationAnalyticsTracker _creationAnalyticsTracker;

  /// Body size notifier, updated by [_CanvasFitter].
  final _bodySizeNotifier = ValueNotifier<Size>(Size.zero);

  /// Editor zoom transform notifier (identity = not zoomed), driven by the
  /// editor's zoom matrix. The letterbox scrim applies the same transform so
  /// the bars move with the magnified frame.
  final _zoomMatrixNotifier = ValueNotifier<Matrix4>(Matrix4.identity());

  /// Fine-grained editor play time (timeline space), updated by the canvas on
  /// every playhead tick so canvas overlays track playback smoothly.
  final _playTimeNotifier = ValueNotifier<Duration>(Duration.zero);
  final _playheadAdvancingNotifier = ValueNotifier<bool>(false);

  /// Track ids whose missing duration we already tried to backfill, so a
  /// failed probe isn't retried on every audio-track change.
  final Set<String> _durationHealAttempted = {};

  /// The locale the sticker catalog was last loaded for. Tracked so a locale
  /// change while the editor is open re-localizes descriptions. The active
  /// locale is only readable from a [Localizations] ancestor (available from
  /// [didChangeDependencies] onward), not from [initState].
  String? _loadedStickerLocale;

  ProImageEditorState? get _editor => _editorKey.currentState;

  DivineVideoClip? get _clip => ref.read(clipManagerProvider).firstClipOrNull;

  /// FittedBox scale factor between bodySize and renderSize.
  ///
  /// Must pass the same arguments as [VideoEditorScope.fittedBoxScale] —
  /// layers sized here are painted by the canvas at that scale.
  double get _fittedBoxScale => VideoEditorScope.calculateFittedBoxScale(
    _bodySizeNotifier.value,
    _clip?.originalAspectRatio ?? 9 / 16,
    targetAspectRatio: _clip?.targetAspectRatio.value,
  );

  @override
  void initState() {
    super.initState();
    _creationAnalyticsTracker = ref.read(creationAnalyticsTrackerProvider);
    Log.info(
      '🎬 Initialized (draftId: ${widget.draftId}, fromLibrary: ${widget.fromLibrary})',
      name: 'VideoEditorScreen',
      category: LogCategory.video,
    );
    _stickerBloc = VideoEditorStickerBloc(
      stickerRepository: StickerRepository(),
      onPrecacheStickers: _precacheStickers,
    );
    // Captured while mounted: long clip renders (reverse / transform /
    // chroma-key, ~15-20s) can finish after this State unmounts. `ref` is
    // unsafe then, but the notifier outlives the screen for the editor
    // session, so deferred cleanup and final-clip invalidation still need to
    // reach it — otherwise orphans never enter `_deferredFileCleanup`.
    final videoEditor = ref.read(videoEditorProvider.notifier);
    _clipEditorBloc = ClipEditorBloc(
      // The clip library sits behind a Riverpod provider the BLoC can't reach,
      // so it arrives as a callback — the same transition seam that brings the
      // clip list in. `ref` is unsafe once this State unmounts, so bail rather
      // than let a save that outlived the screen throw "Using ref when
      // unmounted"; the render is abandoned with the editor session either way.
      saveClipToLibrary: ({required clip}) async {
        if (!mounted) return false;
        return ref.read(clipManagerProvider.notifier).saveClipToLibrary(clip);
      },
      deferFileCleanup: videoEditor.deferFileCleanup,
      onFinalClipInvalidated: () {
        // A clip render (reverse / transform) can resolve after this screen is
        // disposed — the user backed out while a long clip was still
        // re-encoding (~15-20s). `_editor` is unsafe once the State is
        // unmounted; the video-editor notifier was captured above so cleanup
        // and invalidation still run.
        videoEditor.invalidateFinalRenderedClip();
        if (!mounted) return;

        if (_editor != null) {
          // A split subdivides one clip at the same total span, so no marker
          // moves — a marker on the left half stays on the start clip, one on
          // the right stays on the end clip. Persist the current markers in
          // the same history entry as the split clips so undo/redo restores a
          // consistent timeline.
          _editor!.addHistory(
            meta: {
              ..._editor!.stateManager.activeMeta,
              VideoEditorConstants.clipsStateHistoryKey: _clipEditorBloc
                  .state
                  .clips
                  .map((e) => e.toJson())
                  .toList(),
              VideoEditorConstants.timelineMarkersStateHistoryKey:
                  _timelineOverlayBloc.state.timelineMarkers
                      .map((marker) => marker.inMilliseconds)
                      .toList(),
            },
          );
        }
      },
    );
    _timelineOverlayBloc = TimelineOverlayBloc();

    // For non-draft flows clips are already available.
    final initialClips = ref.read(clipManagerProvider).clips;
    if (initialClips.isNotEmpty) {
      _clipEditorBloc.add(ClipEditorInitialized(initialClips));
    }

    addPostFrameCallbackIfMounted(() async {
      Log.debug(
        '🎬 Initializing video editor provider',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
      );

      await ref
          .read(videoEditorProvider.notifier)
          .initialize(draftId: widget.draftId);

      if (!mounted) return;
      final clips = ref.read(clipManagerProvider).clips;
      final tracker = _creationAnalyticsTracker;
      final recorderMode =
          tracker.activeMode ??
          (isStopMotionComposition(clips)
              ? VideoRecorderMode.stopMotion
              : VideoRecorderMode.fromName(
                  ref
                      .read(sharedPreferencesProvider)
                      .getString(VideoRecorderMode.persistenceKey),
                ));
      await tracker.editorOpened(recorderMode);

      Log.info(
        '🎬 Video editor initialized successfully',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
      );

      // A restored draft's text layers carry only the serialized Google Font
      // family name. Re-register the editor fonts before the canvas imports
      // the state history, otherwise the imported overlays fall back to the
      // default font (see #5181).
      if (mounted &&
          ref.read(videoEditorProvider).editorStateHistory.isNotEmpty) {
        await preloadEditorTextFonts();
      }

      if (mounted) {
        // Clips are now loaded — initialize the clip editor BLoC.
        final clips = ref.read(clipManagerProvider).clips;
        _clipEditorBloc.add(ClipEditorInitialized(clips));

        _isLoadingDraft.value = false;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = Localizations.localeOf(context).languageCode;
    if (localeCode != _loadedStickerLocale) {
      _loadedStickerLocale = localeCode;
      _stickerBloc.add(VideoEditorStickerLoad(localeCode));
    }
  }

  @override
  void dispose() {
    if (widget.fromLibrary || widget.draftId != null) {
      unawaited(_creationAnalyticsTracker.creationAbandoned());
    }
    Log.info(
      '🎨 Disposed',
      name: 'VideoEditorScreen',
      category: LogCategory.video,
    );
    _stickerBloc.close();
    _clipEditorBloc.close();
    _timelineOverlayBloc.close();
    _isLoadingDraft.dispose();
    _bodySizeNotifier.dispose();
    _zoomMatrixNotifier.dispose();
    _playTimeNotifier.dispose();
    _playheadAdvancingNotifier.dispose();
    super.dispose();
  }

  /// Precaches stickers for faster display.
  void _precacheStickers(List<StickerData> stickers) {
    if (!mounted) return;

    Log.debug(
      '🎨 Precaching ${stickers.length} stickers',
      name: 'VideoEditorScreen',
      category: LogCategory.video,
    );

    final estimatedSize = MediaQuery.sizeOf(context) / 3;

    for (final sticker in stickers) {
      // SVG assets are vector and don't need raster precaching.
      if (sticker.networkUrl == null) continue;

      unawaited(
        precacheImage(
          NetworkImage(sticker.networkUrl!),
          context,
          size: estimatedSize,
        ),
      );
    }
  }

  /// Opens the camera recorder as a modal overlay over the editor.
  ///
  /// Snapshots the current clip IDs before opening so that any newly recorded
  /// clips can be rolled back if the user cancels (`result != true`).
  /// On success or cancel, calls [_syncClipsToEditor] to keep the
  /// [ClipEditorBloc] in sync.
  Future<void> _openCamera({
    required ClipEditorBloc clipEditorBloc,
    required Duration playhead,
  }) async {
    final initialClips = ref.read(clipManagerProvider).clips;
    final initialIds = initialClips.map((c) => c.id).toSet();
    // A stop-motion composition adds the new stills into its single frames clip
    // at the playhead; a normal composition just keeps the appended clip.
    final stopMotionTarget = isStopMotionComposition(initialClips)
        ? initialClips.first
        : null;

    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder<bool>(
        settings: const RouteSettings(name: 'video_recorder'),
        opaque: false,
        barrierDismissible: true,
        barrierColor: VineTheme.transparent,
        pageBuilder: (_, _, _) => const VideoRecorderScreen(
          fromEditor: true,
          entryPoint: CreationEntryPoint.editor,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    final notifier = ref.read(clipManagerProvider.notifier);
    if (result != true) {
      final newClips = notifier.clips
          .where((c) => !initialIds.contains(c.id))
          .toList();
      for (final clip in newClips) {
        await notifier.removeClipById(clip.id);
      }
    } else if (stopMotionTarget != null) {
      await _insertCapturedStopMotionFrames(
        target: stopMotionTarget,
        initialIds: initialIds,
        playhead: playhead,
      );
    }

    _syncClipsToEditor(clipEditorBloc: clipEditorBloc);
  }

  /// Splices stills captured over a stop-motion composition into its frames
  /// clip [target] at the [playhead] position, then drops the throwaway clip
  /// (and its library row) the recorder created for the capture session.
  Future<void> _insertCapturedStopMotionFrames({
    required DivineVideoClip target,
    required Set<String> initialIds,
    required Duration playhead,
  }) async {
    final notifier = ref.read(clipManagerProvider.notifier);
    final clips = notifier.clips;
    final added = clips
        .where((c) => !initialIds.contains(c.id) && c.isStopMotion)
        .toList();
    final capturedFrames = [
      for (final clip in added) ...?clip.stopMotionFrames,
    ];
    if (capturedFrames.isEmpty) return;

    final targetFrames = target.stopMotionFrames ?? const [];
    // Fresh captures arrive stretched to fill a second on their own
    // ([StopMotionFrameOps.initialHold]) — one still added from here would
    // splice into a long clip at a 1s hold — so the session's global default
    // is re-applied, both to undo that stretch and to keep the new stills from
    // drifting from the ones already in the clip.
    final newFrames = StopMotionFrameOps.setGlobalHold(
      capturedFrames,
      StopMotionFrameOps.globalDefaultFramesPerImage(targetFrames),
    );
    final index = StopMotionFrameOps.insertIndexAtPosition(
      targetFrames,
      playhead,
    );
    final merged = StopMotionFrameOps.clipWithFrames(
      target,
      StopMotionFrameOps.insertFramesAt(targetFrames, index, newFrames),
    );

    final addedIds = added.map((c) => c.id).toSet();
    notifier.replaceClips([
      for (final clip in clips)
        if (clip.id == target.id)
          merged
        else if (!addedIds.contains(clip.id))
          clip,
    ]);

    // The recorder saved each capture session as its own library set; those
    // stills now live in [target], so drop the throwaway rows (files kept).
    final libraryService = ref.read(clipLibraryServiceProvider);
    for (final id in addedIds) {
      await libraryService.deleteClipRow(id);
    }
  }

  Future<void> _openClipsEditor({
    required VideoEditorMainBloc mainBloc,
    required ClipEditorBloc clipEditorBloc,
  }) async {
    // Pause playback while the library is open.
    mainBloc
      ..add(const VideoEditorMainOpenSubEditor(.clips))
      ..add(const VideoEditorExternalPauseRequested(isPaused: true));
    final currentClips = ref.read(clipManagerProvider).clips;

    // Clip types can't be mixed in one composition, so the picker only
    // offers the type the session already edits.
    final clipTypeFilter = isStopMotionComposition(currentClips)
        ? LibraryClipTypeFilter.stopMotion
        : LibraryClipTypeFilter.video;

    final newClips = await VineBottomSheet.show<List<DivineVideoClip>>(
      context: context,
      maxChildSize: 1,
      initialChildSize: 0.9,
      minChildSize: VineTheme.bottomSheetDismissFloor,
      buildScrollBody: (scrollController) => LibraryScreen(
        initialTabIndex: 1,
        selectionMode: true,
        clipTypeFilter: clipTypeFilter,
        editorClips: currentClips,
        scrollController: scrollController,
      ),
    );

    mainBloc.add(const VideoEditorMainSubEditorClosed());

    if (newClips != null && newClips.isNotEmpty) {
      Log.info(
        '🎬 Adding ${newClips.length} new clips from library',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
      );

      final clipManager = ref.read(clipManagerProvider.notifier);
      // Drop unreadable stills, then collapse stop-motion sets added to a
      // stop-motion session into the session's single frames clip — the
      // frame-first editor edits exactly one frames list (see
      // StopMotionFrameOps.mergeClips).
      final usableClips = [
        for (final clip in newClips) ?StopMotionFrameOps.sanitizedClip(clip),
      ];
      final merged = StopMotionFrameOps.mergeClips([
        ...ref.read(clipManagerProvider).clips,
        ...usableClips,
      ]);
      if (merged != null) {
        clipManager.replaceClips([merged]);
      } else {
        clipManager.addMultipleClips(usableClips);
      }

      _syncClipsToEditor(clipEditorBloc: clipEditorBloc);
    }
  }

  /// Syncs the current clip list from [clipManagerProvider] into the
  /// [ClipEditorBloc] and appends a history entry to the pro_image_editor.
  ///
  /// Both callers add content — stills shot from the editor's camera, a
  /// stop-motion set merged in from the clips picker — so the composition can
  /// end up longer than the one a sound was clamped to when it was added.
  /// [VideoEditorExtensions.setLengthenedClipState] carries a window that ran
  /// to the old end onto the new one (#6401); a window the user trimmed short
  /// is left alone.
  void _syncClipsToEditor({required ClipEditorBloc clipEditorBloc}) {
    // Read before the dispatch: this is the composition the audio windows were
    // last clamped against.
    final previousClips = clipEditorBloc.state.clips;

    // Sync the updated clip list into the editor BLoC.
    final updatedClips = ref.read(clipManagerProvider).clips;
    clipEditorBloc.add(ClipEditorInitialized(updatedClips));

    if (_editor != null) {
      _editor!.setLengthenedClipState(
        previousClips: previousClips,
        clips: updatedClips,
      );
    }
  }

  /// Opens the sticker picker sheet and adds the selected sticker as a layer.
  ///
  /// Resets the search query before opening and adds a [WidgetLayer] to the
  /// editor canvas if a sticker is selected.
  Future<void> _addStickers() async {
    // Reset search when opening the sheet
    _stickerBloc.add(const VideoEditorStickerSearch(''));

    final sticker = await VineBottomSheet.show<StickerData>(
      context: context,
      title: Text(context.l10n.videoEditorStickers),
      maxChildSize: 1,
      initialChildSize: 1,
      minChildSize: VineTheme.bottomSheetDismissFloor,
      buildScrollBody: (scrollController) => BlocProvider.value(
        value: _stickerBloc,
        child: VideoEditorStickerSheet(scrollController: scrollController),
      ),
    );

    if (sticker != null) {
      Log.debug(
        '🎨 Adding sticker layer: ${sticker.description.fallback}',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
      );
      // 1/3 of screen width, converted to render coordinates
      final bodySize = _bodySizeNotifier.value;
      final stickerWidth = min(300.0, (bodySize.width / 3) / _fittedBoxScale);

      final layer = WidgetLayer(
        width: stickerWidth,
        widget: VideoEditorSticker(
          sticker: sticker,
          enableLimitCacheSize: false,
        ),
        meta: sticker.toJson(),
        exportConfigs: WidgetLayerExportConfigs(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          meta: sticker.toJson(),
        ),
      );
      _editor!.addLayer(layer, blockSelectLayer: true);
    }
  }

  /// Opens the text editor screen to add or edit a text layer.
  ///
  /// If [layer] is provided, the editor is initialized with its values for
  /// editing. Otherwise, a new text layer is created.
  ///
  /// Returns the resulting [TextLayer] if the user confirms, or `null` if
  /// cancelled.
  Future<TextLayer?> _addEditTextLayer({
    required VideoEditorMainBloc mainBloc,
    required VideoEditorTextBloc textBloc,
    TextLayer? layer,
  }) async {
    Log.debug(
      '🎨 Opening text editor (editing: ${layer != null})',
      name: 'VideoEditorScreen',
      category: LogCategory.video,
    );
    mainBloc.add(const VideoEditorMainOpenSubEditor(.text));

    final result = await Navigator.push<TextLayer>(
      context,
      PageRouteBuilder<TextLayer>(
        settings: const RouteSettings(name: 'video_text_editor'),
        opaque: false,
        barrierDismissible: true,
        barrierColor: VineTheme.transparent,
        pageBuilder: (_, _, _) => BlocProvider.value(
          value: textBloc,
          child: VideoTextEditorScreen(layer: layer),
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    textBloc.add(const VideoEditorTextClosePanels());
    mainBloc.add(const VideoEditorMainSubEditorClosed());

    if (result == null || layer != null) return result;

    return result.copyWith(scale: 1 / _fittedBoxScale);
  }

  /// Opens the captions editor sheet. Captions are always published as CC;
  /// the sheet's burn-in toggle decides whether they are also burned in.
  Future<void> _openCaptions({
    required VideoEditorMainBloc mainBloc,
    required ClipEditorBloc clipEditorBloc,
  }) async {
    final editor = _editor;
    if (editor == null) return;

    final existingTrack = editor.stateManager.captionTrack;
    final captionLayers = editor.activeLayers.where(isCaptionCueLayer).toList();
    final hasSession = existingTrack != null || captionLayers.isNotEmpty;

    final burnIn = existingTrack?.burnIn ?? captionLayers.isNotEmpty;
    final presetId =
        existingTrack?.presetId ?? CaptionStylePreset.presets.first.id;
    // Cues are authoritative on the track; only a legacy burn-in draft (cues
    // stored solely as layers) needs the layer fallback.
    final List<CaptionCue>? initialCues = hasSession
        ? (existingTrack != null && existingTrack.cues.isNotEmpty
              ? existingTrack.cues
              : captionCuesFromLayers(captionLayers))
        : null;

    // The app language drives recognition; a stored track keeps the language
    // it was transcribed with.
    final languageTag =
        existingTrack?.languageTag ??
        Localizations.localeOf(context).toLanguageTag();

    mainBloc.add(const VideoEditorMainOpenSubEditor(.captions));

    // The cubit prefers server-side transcription (higher quality), falling
    // back to on-device per clip when the request fails.
    final result = await showCaptionsEditorSheet(
      context,
      burnIn: burnIn,
      presetId: presetId,
      customStyle: existingTrack?.customStyle,
      languageTag: languageTag,
      clips: clipEditorBloc.state.clips,
      totalDuration: clipEditorBloc.state.totalDuration,
      initialCues: initialCues,
      canDeleteTrack: hasSession,
      blossomUploadService: ref.read(blossomUploadServiceProvider),
    );

    mainBloc.add(const VideoEditorMainSubEditorClosed());
    if (result == null) return;
    _commitCaptionsResult(result);
  }

  /// Commits a captions-editor result as one history entry (one undo step):
  /// the track (cues + burn-in flag) goes into the `captions` meta key, and
  /// when burn-in is on the cues are also materialized as marked caption
  /// layers. Delete removes both.
  void _commitCaptionsResult(CaptionsEditorResult result) {
    final editor = _editor;
    if (editor == null) return;

    switch (result) {
      case CaptionsDeleted():
        editor.commitCaptionState(track: null);
      case CaptionsConfirmed(:final track) when !track.burnIn:
        editor.commitCaptionState(track: track);
      case CaptionsConfirmed(:final track, :final cues):
        // A custom style wins over the built-in preset for the burned look.
        final style =
            track.customStyle?.resolve() ??
            CaptionStylePreset.byId(track.presetId).style;
        final bodySize = _bodySizeNotifier.value;
        // Preserve any on-canvas position/rotation/scale the user already
        // applied to a cue's layer, keyed by cue id, so re-editing captions
        // doesn't reset their manual adjustments.
        final existingByCueId = <String, Layer>{
          for (final layer in editor.activeLayers)
            ?captionCueIdOf(layer): layer,
        };
        editor.commitCaptionState(
          track: track,
          captionLayers: [
            for (final cue in cues)
              preserveCaptionLayerTransform(
                style.buildLayer(
                  cue,
                  bodySize: bodySize,
                ),
                existingByCueId[cue.id],
              ),
          ],
        );
    }
  }

  Future<void> _openMusicLibrary() async {
    var result = await AudioSelectionBottomSheet.show(context);
    if (!mounted || result == null) return;

    // Nostr sounds sometimes carry no duration tag, which otherwise persists a
    // zero-length timeline window (endTime=0). Probe the source once and store
    // the real duration so the track is placed and rendered correctly.
    final durationSecs = await _resolveSoundDurationSecs(result);
    if (!mounted) return;

    final editor = _editorKey.currentState;
    if (editor == null) return;

    final audioDuration = Duration(milliseconds: (durationSecs * 1000).toInt());
    final clipDuration = _clipEditorBloc.state.totalDuration;
    const maxDuration = VideoEditorConstants.maxDuration;
    final endTime = [
      audioDuration,
      clipDuration,
      maxDuration,
    ].reduce((a, b) => a < b ? a : b);

    result = result.copyWith(
      id: '${result.id}-${DateTime.now().millisecondsSinceEpoch}',
      startTime: .zero,
      endTime: endTime,
      duration: durationSecs > 0 ? durationSecs : null,
    );
    editor.addHistory(
      meta: buildAppendedAudioMeta(
        activeMeta: editor.stateManager.activeMeta,
        existingTracks: editor.stateManager.audioTracks,
        newTracks: [result],
      ),
    );
  }

  /// Opens the full-screen voice-over recorder and appends the recorded takes
  /// to the editor timeline.
  ///
  /// Takes are laid back-to-back: the first starts at the beginning and each
  /// subsequent take starts where the previous one ended, clamped to
  /// [VideoEditorConstants.maxDuration]. All takes are committed in a single
  /// history entry so one undo removes them together.
  Future<void> _openVoiceOver({required VideoEditorMainBloc mainBloc}) async {
    final availableDuration = resolveVoiceOverAvailableDuration(
      clipDuration: _clipEditorBloc.state.totalDuration,
      maxDuration: VideoEditorConstants.maxDuration,
    );

    // Count voice-over already on the timeline so the take numbering continues
    // (e.g. "Recording 5") instead of restarting at 1.
    final priorTakeCount = countPriorVoiceOverTakes(
      audioTracks: _timelineOverlayBloc.state.audioTracks,
      voiceOverIdPrefix: VoiceOverCubit.voiceOverIdPrefix,
    );

    // Pause editor playback so the preview's audio isn't captured into the
    // voice-over while the recorder is open.
    mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: true));
    final takes = await Navigator.of(context).push<List<AudioEvent>>(
      PageRouteBuilder<List<AudioEvent>>(
        settings: const RouteSettings(name: 'voice_over_recorder'),
        pageBuilder: (_, _, _) => VoiceOverRecorderScreen(
          availableDuration: availableDuration,
          priorTakeCount: priorTakeCount,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Classic Material "fade upwards": slides up slightly while fading in.
          return const FadeUpwardsPageTransitionsBuilder().buildTransitions(
            null,
            context,
            animation,
            secondaryAnimation,
            child,
          );
        },
      ),
    );
    // Committed (Done) takes whose files never reach the timeline belong to no
    // draft, so the deferred draft-scoped cleanup can't reclaim them. Delete
    // them on every early return below to avoid permanent orphans. (A close/
    // discard returns null here and the cubit already deleted those files.)
    if (!mounted) {
      await deleteVoiceOverTakeFiles(takes);
      return;
    }
    mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: false));
    if (takes == null || takes.isEmpty) return;

    // The recorder's per-take duration is derived from amplitude-sample counts
    // and can drift from the encoded file. Probe each file's real duration up
    // front so the committed timeline window matches the audio (mirrors the
    // music-library path).
    final takeSecs = <double>[];
    for (final take in takes) {
      takeSecs.add(await resolveRecordedTakeDurationSecs(take));
    }
    if (!mounted) {
      await deleteVoiceOverTakeFiles(takes);
      return;
    }

    final editor = _editorKey.currentState;
    if (editor == null) {
      await deleteVoiceOverTakeFiles(takes);
      return;
    }
    final placed = placeVoiceOverTakes(
      takes: takes,
      takeDurationsSecs: takeSecs,
      availableDuration: availableDuration,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (placed.isEmpty) {
      await deleteVoiceOverTakeFiles(takes);
      return;
    }

    editor.addHistory(
      meta: buildAppendedAudioMeta(
        activeMeta: editor.stateManager.activeMeta,
        existingTracks: editor.stateManager.audioTracks,
        newTracks: placed,
      ),
    );
  }

  /// Resolves the sound's duration in seconds, probing the source via
  /// [ProVideoEditor.getMetadata] when the event carries no duration tag
  /// (common for Nostr sounds). Returns the tagged duration when present, or
  /// `0` when it can't be determined.
  Future<double> _resolveSoundDurationSecs(AudioEvent sound) async {
    final tagged = sound.duration ?? 0;
    if (tagged > 0) return tagged;

    final path = sound.isBundled ? sound.assetPath : sound.url;
    if (path == null || path.isEmpty) return 0;
    try {
      final source = sound.isBundled
          ? EditorVideo.asset(path)
          : path.startsWith('/')
          ? EditorVideo.file(path)
          : EditorVideo.network(path);
      final metadata = await ProVideoEditor.instance.getMetadata(source);
      return metadata.duration.inMilliseconds / 1000.0;
    } catch (e, s) {
      Log.error(
        'Failed to probe audio duration for ${sound.id}',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
        error: e,
        stackTrace: s,
      );
      return 0;
    }
  }

  /// Backfills a real duration onto persisted audio tracks that carry none.
  ///
  /// Sounds added before [_resolveSoundDurationSecs] existed (or from Nostr
  /// events without a duration tag) persist `duration == 0`, which becomes a
  /// zero-length timeline window (`endTime == 0`) — an invisible bar. Probe the
  /// source once, recompute `endTime`, and rewrite the editor history so the
  /// repair persists. Each track is attempted at most once per session.
  Future<void> _healMissingAudioDurations(List<AudioEvent> tracks) async {
    final pending = tracks
        .where(
          (t) =>
              (t.duration ?? 0) <= 0 && !_durationHealAttempted.contains(t.id),
        )
        .toList(growable: false);
    if (pending.isEmpty) return;
    _durationHealAttempted.addAll(pending.map((t) => t.id));

    final resolved = <String, double>{};
    for (final track in pending) {
      final secs = await _resolveSoundDurationSecs(track);
      if (secs > 0) resolved[track.id] = secs;
    }
    if (!mounted || resolved.isEmpty) return;

    final editor = _editorKey.currentState;
    if (editor == null) return;

    final clipDuration = _clipEditorBloc.state.totalDuration;
    const maxDuration = VideoEditorConstants.maxDuration;
    final healed = editor.stateManager.audioTracks.map((track) {
      final secs = resolved[track.id];
      if (secs == null) return track;
      final audioDuration = Duration(milliseconds: (secs * 1000).toInt());
      final endTime = [
        audioDuration,
        clipDuration,
        maxDuration,
      ].reduce((a, b) => a < b ? a : b);
      return track.copyWith(duration: secs, endTime: endTime);
    }).toList();

    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: healed
            .map((e) => e.toJson())
            .toList(),
      },
    );
  }

  /// Extracts waveform data for an audio track and updates the timeline
  /// overlay with the samples.
  ///
  /// Always extracts the **full source file**. Windowing to
  /// `[startOffset, startOffset + span]` is [StereoWaveformPainter]'s job via
  /// its `startOffset` / `maxDuration` args (see `_SoundContent`). Extracting a
  /// pre-windowed segment here would (a) double-window against the painter's
  /// offset and (b) restyle bar heights on every left-trim, because the
  /// painter normalizes against the loudest sample in the arrays it is given.
  ///
  /// The measured duration travels with the samples: covering the whole source
  /// makes it the source duration, which is the basis the painter maps samples
  /// to time against. Sounds whose `duration` never resolved
  /// (see [_healMissingAudioDurations]) would otherwise reach the painter with
  /// no basis and draw the entire file squeezed into the visible bar.
  Future<void> _extractWaveform(AudioEvent audio) async {
    final path = audio.isBundled ? audio.assetPath : audio.url;
    if (path == null) return;

    try {
      final video = audio.isBundled
          ? EditorVideo.asset(path)
          : path.startsWith('/')
          ? EditorVideo.file(path)
          : EditorVideo.network(path);
      final data = await ProVideoEditor.instance.getWaveform(
        WaveformConfigs(video: video),
      );
      if (!mounted) return;
      _timelineOverlayBloc.add(
        TimelineOverlayWaveformLoaded(
          itemId: audio.id,
          leftChannel: data.leftChannel,
          rightChannel: data.rightChannel,
          sourceDuration: data.duration,
        ),
      );
    } catch (e, s) {
      Log.error(
        'Failed to extract timeline waveform: $e',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Awaits the entrance transition of a screen pushed over the editor.
  ///
  /// Uses the screen's own context, which sits **above** the canvas's nested
  /// `Navigator`, so `ModalRoute.of` resolves to the go_router editor route
  /// whose `secondaryAnimation` the push actually drives. The canvas's own
  /// context resolves to that inner route instead, which the outer push never
  /// animates — so the canvas delegates here.
  Future<void> _awaitMetadataCoverTransition() => awaitPushTransition(
    context,
    timeout: VideoEditorConstants.coverTransitionTimeout,
  );

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => VideoEditorMainBloc()),
        BlocProvider.value(value: _stickerBloc),
        BlocProvider(create: (_) => VideoEditorFilterBloc()),
        BlocProvider(create: (_) => VideoEditorTuneBloc()),
        BlocProvider(create: (_) => VideoEditorDrawBloc()),
        BlocProvider(create: (_) => VideoEditorTextBloc()),
        BlocProvider.value(value: _timelineOverlayBloc),
        BlocProvider.value(value: _clipEditorBloc),
      ],
      child: BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
        listenWhen: (previous, current) =>
            previous.audioTracks != current.audioTracks,
        listener: (context, state) {
          final existingWaveformIds = state.items
              .where((i) => i.waveformLeftChannel != null)
              .map((i) => i.id)
              .toSet();

          for (final audio in state.audioTracks) {
            // Full-source samples are offset-invariant; the painter scrolls
            // via startOffset. Re-extract only when this track has no samples
            // yet (new sound, or a rebuild that dropped the cache).
            if (!existingWaveformIds.contains(audio.id)) {
              unawaited(_extractWaveform(audio));
            }
          }

          unawaited(_healMissingAudioDurations(state.audioTracks));
        },
        child: Builder(
          builder: (context) {
            final clip = ref.watch(
              clipManagerProvider.select((s) => s.firstClipOrNull),
            );
            return VideoEditorScope(
              editorKey: _editorKey,
              removeAreaKey: _removeAreaKey,
              canvasBodyKey: _canvasBodyKey,
              originalClipAspectRatio: clip?.originalAspectRatio ?? 9 / 16,
              targetClipAspectRatio: clip?.targetAspectRatio.value,
              bodySizeNotifier: _bodySizeNotifier,
              zoomMatrixNotifier: _zoomMatrixNotifier,
              playTimeNotifier: _playTimeNotifier,
              playheadAdvancingNotifier: _playheadAdvancingNotifier,
              fromLibrary: widget.fromLibrary,
              onOpenCamera: () => _openCamera(
                clipEditorBloc: context.read<ClipEditorBloc>(),
                playhead: context
                    .read<VideoEditorMainBloc>()
                    .state
                    .currentPosition,
              ),
              onOpenClipsEditor: () {
                final mainBloc = context.read<VideoEditorMainBloc>();
                final clipEditorBloc = context.read<ClipEditorBloc>();
                _openClipsEditor(
                  mainBloc: mainBloc,
                  clipEditorBloc: clipEditorBloc,
                );
              },
              onAddStickers: _addStickers,
              onAddEditTextLayer: ([layer]) {
                final mainBloc = context.read<VideoEditorMainBloc>();
                final textBloc = context.read<VideoEditorTextBloc>();

                return _addEditTextLayer(
                  mainBloc: mainBloc,
                  textBloc: textBloc,
                  layer: layer,
                );
              },
              onOpenMusicLibrary: _openMusicLibrary,
              onOpenVoiceOver: () {
                final mainBloc = context.read<VideoEditorMainBloc>();
                _openVoiceOver(mainBloc: mainBloc);
              },
              onOpenCaptions: () {
                final mainBloc = context.read<VideoEditorMainBloc>();
                final clipEditorBloc = context.read<ClipEditorBloc>();
                _openCaptions(
                  mainBloc: mainBloc,
                  clipEditorBloc: clipEditorBloc,
                );
              },
              awaitPushCoverTransition: _awaitMetadataCoverTransition,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isLoadingDraft,
                builder: (_, isLoading, _) =>
                    VideoEditorScaffold(isLoading: isLoading),
              ),
            );
          },
        ),
      ),
    );
  }
}
