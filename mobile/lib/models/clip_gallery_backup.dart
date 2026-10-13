// ABOUTME: Where the gallery backup of a new camera recording stands
// ABOUTME: Kept on the library clip so the backup survives restarts and retries

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

/// How far the gallery backup of a recording has got (#10067).
enum ClipGalleryBackupStatus {
  /// No copy in the gallery yet: the recording is waiting to be signed, or
  /// the copy could not be written and is tried again.
  pending,

  /// A copy carrying the recording's C2PA credential is in the gallery, so it
  /// can come back through the gallery import.
  saved,

  /// A copy without a C2PA credential is in the gallery, because the
  /// recording can never be signed, for example in a build that cannot sign.
  /// The gallery import rejects it.
  savedUnsigned,
}

/// The gallery backup of the camera recording a library clip was made from.
///
/// The backup is a copy of the recording file as the camera wrote it, signed
/// as a capture, so a chroma-key bake or any later edit of the clip never
/// replaces it.
@immutable
class ClipGalleryBackup {
  /// Creates the backup state of the recording at [recordingPath].
  const ClipGalleryBackup({required this.status, required this.recordingPath});

  /// Restores a backup state, resolving [json]'s recording against
  /// [documentsPath] the way clip file paths are resolved.
  ///
  /// Returns `null` when [json] is not a backup state this build can read, so
  /// one unreadable field does not abort a whole library or draft load.
  static ClipGalleryBackup? fromJson(
    Object? json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    if (json is! Map) return null;
    final status = ClipGalleryBackupStatus.values.asNameMap()[json['status']];
    final recording = json['recording'];
    if (status == null || recording is! String || recording.isEmpty) {
      return null;
    }
    return ClipGalleryBackup(
      status: status,
      recordingPath: resolvePath(
        recording,
        documentsPath,
        useOriginalPath: useOriginalPath,
      )!,
    );
  }

  /// How far the backup has got.
  final ClipGalleryBackupStatus status;

  /// The recording file the gallery copy is made of.
  final String recordingPath;

  /// Whether the clip should be flagged in the library: its recording is not
  /// in the gallery yet, or is there without a credential.
  bool get needsAttention => status != ClipGalleryBackupStatus.saved;

  /// A copy of this state with [status].
  ClipGalleryBackup withStatus(ClipGalleryBackupStatus status) =>
      ClipGalleryBackup(status: status, recordingPath: recordingPath);

  /// Serializes to JSON, storing only the basename like every clip path.
  ///
  /// The key is not `path`: the clip itself references the recording, and
  /// the backup state must not keep a file alive on its own.
  Map<String, dynamic> toJson() => {
    'status': status.name,
    'recording': p.basename(recordingPath),
  };

  @override
  bool operator ==(Object other) =>
      other is ClipGalleryBackup &&
      other.status == status &&
      other.recordingPath == recordingPath;

  @override
  int get hashCode => Object.hash(status, recordingPath);

  @override
  String toString() => 'ClipGalleryBackup(${status.name}: $recordingPath)';
}
