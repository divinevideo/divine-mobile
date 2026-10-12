// ABOUTME: Cubit that brings videos picked from the device gallery back into
// ABOUTME: the clip library, once their C2PA credential proves a Divine capture.

import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:path/path.dart' as p;

/// Adds a verified gallery video to one account's clip library.
typedef GalleryClipImporter = Future<VideoClipImportResult> Function({
  required File source,
  required String c2paManifestId,
  List<String> contributorPubkeys,
});

/// Returns the [GalleryClipImporter] for the signed-in account's library.
///
/// Resolved when an import starts rather than when the screen opens, since
/// the library is per account and the check can outlive the screen.
typedef GalleryClipImporterResolver = GalleryClipImporter Function();

/// Returns a JPEG preview frame of the video at `videoPath`, or `null` when
/// none can be read.
typedef GalleryClipThumbnailLoader = Future<Uint8List?> Function(
  String videoPath,
);

/// Where one picked video is in the import.
enum GalleryClipImportItemStatus {
  /// Queued behind the videos picked before it.
  waiting,

  /// Its C2PA credential is being checked, and it is added if it passes.
  checking,

  /// It passed the check and is in the library.
  added,

  /// It passed the check, but the library already held the same footage, so
  /// nothing was added.
  alreadyInLibrary,

  /// Its credential does not prove a Divine camera capture, so it stays out.
  notVerified,

  /// The check could not run right now; nothing is known about the video.
  checkUnavailable,

  /// It passed the check but could not be stored.
  failed;

  /// Whether the import is done with this video.
  bool get isFinished => switch (this) {
    waiting || checking => false,
    added ||
    alreadyInLibrary ||
    notVerified ||
    checkUnavailable ||
    failed => true,
  };
}

/// One video picked from the gallery and how its import went.
class GalleryClipImportItem extends Equatable {
  /// Creates a [GalleryClipImportItem].
  const GalleryClipImportItem({
    required this.path,
    this.thumbnail,
    this.status = GalleryClipImportItemStatus.waiting,
  });

  /// The picker's temporary copy of the video.
  final String path;

  /// A JPEG preview frame, once one has been read.
  final Uint8List? thumbnail;

  /// Where the video is in the import.
  final GalleryClipImportItemStatus status;

  /// Returns a copy with the given fields replaced.
  GalleryClipImportItem copyWith({
    Uint8List? thumbnail,
    GalleryClipImportItemStatus? status,
  }) => GalleryClipImportItem(
    path: path,
    thumbnail: thumbnail ?? this.thumbnail,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [path, thumbnail, status];
}

/// [GalleryClipImportCubit] state.
class GalleryClipImportState extends Equatable {
  /// Creates a [GalleryClipImportState].
  const GalleryClipImportState({this.items = const []});

  /// The videos of the latest import, in the order they were picked.
  final List<GalleryClipImportItem> items;

  /// Whether any picked video is still waiting or being checked.
  bool get isImporting => items.any((item) => !item.status.isFinished);

  /// How many picked videos are in the library.
  int get addedCount => items
      .where((item) => item.status == GalleryClipImportItemStatus.added)
      .length;

  @override
  List<Object?> get props => [items];
}

/// Brings videos from the device gallery back into the clip library.
///
/// A clip saved to the gallery keeps its C2PA manifest, so it can come back
/// with the same proof it left with. A video is only added when
/// [ClipProvenanceVerifier] confirms it is a Divine camera capture or a
/// signed edit of captures, exactly as for a clip received in a DM, so the
/// gallery is no way around the check.
class GalleryClipImportCubit extends Cubit<GalleryClipImportState>
    with CloseGuardedEmit<GalleryClipImportState> {
  /// Creates a [GalleryClipImportCubit].
  GalleryClipImportCubit({
    required ClipProvenanceVerifier verifier,
    required GalleryClipImporterResolver resolveImporter,
    required GalleryClipThumbnailLoader loadThumbnail,
  }) : _verifier = verifier,
       _resolveImporter = resolveImporter,
       _loadThumbnail = loadThumbnail,
       super(const GalleryClipImportState());

  final ClipProvenanceVerifier _verifier;
  final GalleryClipImporterResolver _resolveImporter;
  final GalleryClipThumbnailLoader _loadThumbnail;

  /// Containers the C2PA reader is given. The extension picks the reader's
  /// parser, and Divine recordings are always MP4.
  static const Set<String> verifiableExtensions = {'.mp4', '.mov'};

  /// Checks every video in [paths] and adds those that pass to the library
  /// of the account signed in when this was called.
  ///
  /// Every video is listed at once with a preview frame, then checked one
  /// after another, so each one's status shows as it settles. An import
  /// asked for while another is still running is ignored.
  ///
  /// [paths] are the temporary copies the gallery picker made. Each is
  /// deleted once it has been handled, whatever the outcome; the library
  /// keeps its own copy.
  ///
  /// The work is not cancelled by [close], so a video still being checked
  /// when the screen goes away is still added.
  Future<void> importClips(List<String> paths) async {
    if (paths.isEmpty || state.isImporting) return;
    final importClip = _resolveImporter();
    final items = [for (final path in paths) GalleryClipImportItem(path: path)];

    void update(int index, GalleryClipImportItem item) {
      items[index] = item;
      emitIfOpen(GalleryClipImportState(items: List.unmodifiable(items)));
    }

    emitIfOpen(GalleryClipImportState(items: List.unmodifiable(items)));
    for (var i = 0; i < items.length; i++) {
      final thumbnail = await _thumbnailOf(items[i].path);
      if (thumbnail != null) update(i, items[i].copyWith(thumbnail: thumbnail));
    }
    for (var i = 0; i < items.length; i++) {
      update(
        i,
        items[i].copyWith(status: GalleryClipImportItemStatus.checking),
      );
      final status = await _import(items[i].path, importClip);
      update(i, items[i].copyWith(status: status));
    }
  }

  Future<Uint8List?> _thumbnailOf(String path) async {
    try {
      return await _loadThumbnail(path);
    } on Exception {
      // A missing preview only costs the row its picture.
      return null;
    }
  }

  Future<GalleryClipImportItemStatus> _import(
    String path,
    GalleryClipImporter importClip,
  ) async {
    try {
      if (!verifiableExtensions.contains(p.extension(path).toLowerCase())) {
        return GalleryClipImportItemStatus.notVerified;
      }

      final provenance = await _verifier.verify(path);
      if (!provenance.isVerified) {
        return provenance.isRejected
            ? GalleryClipImportItemStatus.notVerified
            : GalleryClipImportItemStatus.checkUnavailable;
      }

      final result = await importClip(
        source: File(path),
        c2paManifestId: provenance.activeManifestId!,
        contributorPubkeys: provenance.contributors,
      );
      switch (result) {
        case VideoClipImportSuccess(alreadyInLibrary: true):
          return GalleryClipImportItemStatus.alreadyInLibrary;
        case VideoClipImportSuccess():
          return GalleryClipImportItemStatus.added;
        case VideoClipImportFailure(
          reason: VideoClipImportFailureReason.sourceLookupFailed,
        ):
          // Whether it is a published post, and so whom to credit, could not
          // be checked; like a check that could not run, try again later.
          return GalleryClipImportItemStatus.checkUnavailable;
        case VideoClipImportFailure(:final reason):
          addError(GalleryClipImportFailure(reason), StackTrace.current);
          return GalleryClipImportItemStatus.failed;
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return GalleryClipImportItemStatus.failed;
    } finally {
      await _deletePickedCopy(path);
    }
  }

  Future<void> _deletePickedCopy(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Best effort: the copy sits in the OS cache, which reclaims it.
    }
  }
}

/// A verified gallery video the library import could not store. Diagnostic
/// only.
class GalleryClipImportFailure implements Exception {
  /// Creates a [GalleryClipImportFailure] for [reason].
  const GalleryClipImportFailure(this.reason);

  /// Why the import failed.
  final VideoClipImportFailureReason reason;

  @override
  String toString() => 'GalleryClipImportFailure: ${reason.name}';
}
