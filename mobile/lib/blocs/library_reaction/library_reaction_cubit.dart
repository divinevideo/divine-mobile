// ABOUTME: Prepares one reaction cell from camera cuts and owns generated media.
// ABOUTME: Keeps rendering, poster geometry and reference-checked cleanup off the UI.

import 'package:db_client/db_client.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/services/video_editor/captured_chroma_key_baker.dart';
import 'package:openvine/services/video_editor/video_editor_merge_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

typedef MergeReactionTakes = Future<DivineVideoClip?> Function({
  required List<DivineVideoClip> clips,
  required String renderId,
});

typedef ReactionPoster = ({String path, Duration timestamp});
typedef ExtractReactionPoster = Future<ReactionPoster?> Function(String path);

enum LibraryReactionStatus { idle, merging, failure }

class LibraryReactionState extends Equatable {
  LibraryReactionState({
    this.status = LibraryReactionStatus.idle,
    List<String> generatedPaths = const [],
  }) : generatedPaths = List.unmodifiable(generatedPaths);

  final LibraryReactionStatus status;
  final List<String> generatedPaths;

  LibraryReactionState copyWith({
    LibraryReactionStatus? status,
    List<String>? generatedPaths,
  }) => LibraryReactionState(
    status: status ?? this.status,
    generatedPaths: generatedPaths == null
        ? this.generatedPaths
        : List.unmodifiable(generatedPaths),
  );

  @override
  List<Object?> get props => [status, generatedPaths];
}

class LibraryReactionCubit extends Cubit<LibraryReactionState>
    with CloseGuardedEmit<LibraryReactionState> {
  LibraryReactionCubit({
    required void Function(Iterable<String?> paths) deferFileCleanup,
    required Future<DivineVideoClip> Function(DivineVideoClip clip)
    bakeCapturedChromaKey,
    DraftsDao? draftsDao,
    ClipsDao? clipsDao,
    MergeReactionTakes? mergeTakes,
    ExtractReactionPoster? extractThumbnail,
    Future<void> Function(List<String> paths)? cleanupFiles,
  }) : assert(
         cleanupFiles != null || (draftsDao != null && clipsDao != null),
         'Provide cleanupFiles or both database DAOs',
       ),
       _deferFileCleanup = deferFileCleanup,
       _bakeCapturedChromaKey = bakeCapturedChromaKey,
       _draftsDao = draftsDao,
       _clipsDao = clipsDao,
       _mergeTakes = mergeTakes ?? VideoEditorMergeService.mergeClips,
       _extractThumbnail = extractThumbnail ?? _posterFor,
       _cleanupFiles = cleanupFiles,
       super(LibraryReactionState());

  final void Function(Iterable<String?> paths) _deferFileCleanup;
  final Future<DivineVideoClip> Function(DivineVideoClip clip)
  _bakeCapturedChromaKey;
  final DraftsDao? _draftsDao;
  final ClipsDao? _clipsDao;
  final MergeReactionTakes _mergeTakes;
  final ExtractReactionPoster _extractThumbnail;
  final Future<void> Function(List<String> paths)? _cleanupFiles;

  static Future<ReactionPoster?> _posterFor(String path) async {
    final poster = await VideoThumbnailService.extractThumbnail(
      videoPath: path,
    );
    return poster == null
        ? null
        : (path: poster.path, timestamp: poster.timestamp);
  }

  /// Merges [takes] in capture order into one clip whose aspect ratio and
  /// poster describe the rendered file, keeping canvas coordinates and
  /// credits. A single take is returned unchanged.
  ///
  /// Returns null when a step throws (reported through [addError], with
  /// failure status), when the render or poster comes back empty, or when
  /// this cubit is closed or already merging.
  Future<DivineVideoClip?> combine(List<DivineVideoClip> takes) async {
    if (takes.isEmpty ||
        isClosed ||
        state.status == LibraryReactionStatus.merging) {
      return null;
    }
    if (takes.length == 1) return takes.single;
    emit(state.copyWith(status: LibraryReactionStatus.merging));
    try {
      // Recorder enrichment starts keying in the background. A merge reads
      // pixels directly and drops the pending key, so join its bake first.
      final ready = await bakePendingCapturedChromaKeys(
        takes,
        _bakeCapturedChromaKey,
      );
      final rendered = await _mergeTakes(
        clips: ready,
        renderId: 'reaction_${DateTime.now().microsecondsSinceEpoch}',
      );
      final path = rendered?.video?.file?.path;
      if (path == null || !await _keepGenerated(path)) return null;
      final poster = await _extractThumbnail(path);
      if (poster == null || !await _keepGenerated(poster.path)) return null;
      return rendered!.copyWith(
        videoAspectRatio: rendered.targetAspectRatio.value,
        thumbnailPath: poster.path,
        thumbnailTimestamp: poster.timestamp,
      );
    } catch (error, stackTrace) {
      addError(
        asReportableError(error, context: 'LibraryReactionCubit.combine') ??
            error,
        stackTrace,
      );
      emitIfOpen(state.copyWith(status: LibraryReactionStatus.failure));
      return null;
    } finally {
      if (state.status == LibraryReactionStatus.merging) {
        emitIfOpen(state.copyWith(status: LibraryReactionStatus.idle));
      }
    }
  }

  /// Records [path] as owned here, or deletes it when the flow closed this
  /// cubit while the file was being written and nothing else would.
  Future<bool> _keepGenerated(String path) async {
    final kept = emitIfOpen(
      state.copyWith(generatedPaths: [...state.generatedPaths, path]),
    );
    if (!kept) await cleanupFiles([path]);
    return kept;
  }

  /// Deletes generated files still owned here, including any recorded after
  /// the flow's last [cleanupGeneratedFiles].
  @override
  Future<void> close() async {
    final owned = state.generatedPaths;
    final closing = super.close();
    await cleanupFiles(owned);
    await closing;
  }

  /// Transfers generated media to the editor before it can end its session.
  void adoptGeneratedFiles() {
    if (state.generatedPaths.isEmpty) return;
    _deferFileCleanup(state.generatedPaths);
    emit(state.copyWith(generatedPaths: []));
  }

  /// Deletes the [paths] no draft or library clip references; a path whose
  /// check fails goes to the editor's deferred cleanup instead.
  Future<void> cleanupFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    final cleanup = _cleanupFiles;
    if (cleanup != null) {
      await cleanup(paths);
      return;
    }
    final remaining = await FileCleanupService.deleteFilesIfUnreferenced(
      paths,
      draftsDao: _draftsDao!,
      clipsDao: _clipsDao!,
    );
    if (remaining.isNotEmpty) _deferFileCleanup(remaining);
  }

  /// Only generated videos and posters; saved camera takes remain untouched.
  Future<void> cleanupGeneratedFiles() async {
    final paths = state.generatedPaths;
    emit(state.copyWith(generatedPaths: []));
    await cleanupFiles(paths);
  }
}
