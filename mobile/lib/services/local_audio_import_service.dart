import 'dart:io';

import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/utils/audio_mime_type.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

typedef AudioImportStorageRootProvider = Future<Directory> Function();
typedef AudioImportDurationResolver = Future<Duration?> Function(File file);
typedef AudioImportClock = DateTime Function();

/// Why an audio import failed.
///
/// The caller has to tell these apart: an unsupported or unreadable pick is a
/// dead end the user resolves by choosing a different file, while a decoder
/// failure means the bytes were there but not playable. Import UI renders a
/// different remedy for each rather than one generic "import failed".
enum LocalAudioImportFailureReason {
  /// The picked path does not exist or could not be opened.
  unreadableSource,

  /// The file extension is not one of the supported audio containers.
  unsupportedType,

  /// Copying the picked file into library storage failed.
  copyFailed,

  /// The file was copied but could not be decoded as audio.
  decodeFailed,
}

class LocalAudioImportException implements Exception {
  const LocalAudioImportException(
    this.message, {
    this.reason = LocalAudioImportFailureReason.unreadableSource,
  });

  final String message;
  final LocalAudioImportFailureReason reason;

  @override
  String toString() => message;
}

class LocalAudioImportService {
  LocalAudioImportService({
    AudioImportStorageRootProvider? storageRootProvider,
    AudioImportDurationResolver? durationResolver,
    AudioImportClock? clock,
  }) : _storageRootProvider = storageRootProvider ?? _defaultStorageRoot,
       _durationResolver = durationResolver ?? _defaultDurationResolver,
       _clock = clock ?? DateTime.now;

  final AudioImportStorageRootProvider _storageRootProvider;
  final AudioImportDurationResolver _durationResolver;
  final AudioImportClock _clock;

  /// Process-wide counter folded into every import id and file name so two
  /// imports that land in the same clock tick — the same injected clock in a
  /// test, or two picks inside one microsecond — still get distinct identities.
  static int _importSequence = 0;

  /// Copies [sourcePath] into library-owned audio storage.
  ///
  /// The destination is [libraryAudioImportsDirName], not the open draft: an
  /// imported track can be saved to My Sounds and outlive any draft, so no
  /// draft owns it (#8024).
  ///
  /// The returned [AudioEvent.id] is unique per call (microsecond timestamp),
  /// because two picks in the same millisecond used to collide and the second
  /// import would silently overwrite the first in the library.
  ///
  /// A copy that cannot be decoded is deleted before throwing, so a failed
  /// import never leaves an abandoned file behind.
  Future<AudioEvent> importAudioFile({
    required String sourcePath,
    required String displayName,
  }) {
    return _import(
      sourcePath: sourcePath,
      displayName: displayName,
      title: _titleFromDisplayName(displayName),
      moveSource: false,
    );
  }

  /// Moves a microphone recording at [recordingPath] into library-owned audio
  /// storage under [title].
  ///
  /// Unlike [importAudioFile] the source is consumed: the recording is a
  /// scratch file nobody else references, so it is moved rather than copied
  /// and nothing is left behind next to it. Failures are reported the same
  /// way, and a recording that cannot be decoded is deleted.
  Future<AudioEvent> importRecording({
    required String recordingPath,
    required String title,
  }) {
    return _import(
      sourcePath: recordingPath,
      displayName: p.basename(recordingPath),
      title: title,
      moveSource: true,
    );
  }

  Future<AudioEvent> _import({
    required String sourcePath,
    required String displayName,
    required String title,
    required bool moveSource,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const LocalAudioImportException('Audio file could not be opened.');
    }

    final mimeType = audioMimeTypeForPath(displayName);
    if (mimeType == null) {
      throw const LocalAudioImportException(
        'That audio file type is not supported.',
        reason: LocalAudioImportFailureReason.unsupportedType,
      );
    }

    final now = _clock();
    final uniqueSuffix = '${now.microsecondsSinceEpoch}_${_importSequence++}';
    final fileName = _safeFileName(
      '${uniqueSuffix}_${p.basename(displayName)}',
    );
    final root = await _storageRootProvider();
    await root.create(recursive: true);
    final destination = p.join(root.path, fileName);

    final File copied;
    try {
      copied = moveSource
          ? await _move(source, destination)
          : await source.copy(destination);
    } on Exception catch (error) {
      throw LocalAudioImportException(
        'The audio file could not be copied: $error',
        reason: LocalAudioImportFailureReason.copyFailed,
      );
    }

    final Duration? duration;
    try {
      duration = await _durationResolver(copied);
    } catch (error) {
      await _deleteQuietly(copied);
      throw const LocalAudioImportException(
        'That audio file could not be read.',
        reason: LocalAudioImportFailureReason.decodeFailed,
      );
    }

    return AudioEvent.fromLocalImport(
      id: 'local_import_$uniqueSuffix',
      filePath: copied.path,
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      title: title,
      mimeType: mimeType,
      duration: duration == null ? null : duration.inMilliseconds / 1000,
    );
  }

  /// Renames [source] to [destination], falling back to copy-then-delete when
  /// the two sit on different file systems.
  static Future<File> _move(File source, String destination) async {
    try {
      return await source.rename(destination);
    } on FileSystemException {
      final copied = await source.copy(destination);
      await _deleteQuietly(source);
      return copied;
    }
  }

  /// Deletes [file], swallowing a failure so it cannot mask the original error.
  static Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on Exception {
      // The copy is unreferenced and will be reclaimed by the import UI's
      // cleanup path or the device's own cleanup; reporting a delete failure
      // here would replace the decode error the user needs to see.
    }
  }

  static Future<Directory> _defaultStorageRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, libraryAudioImportsDirName));
  }

  static Future<Duration?> _defaultDurationResolver(File file) async {
    final metadata = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(file.path),
    );
    return metadata.duration;
  }

  static String _titleFromDisplayName(String displayName) {
    final withoutExtension = p.basenameWithoutExtension(displayName).trim();
    return withoutExtension.isEmpty ? 'Imported audio' : withoutExtension;
  }

  static String _safeFileName(String input) {
    return input.replaceAll(RegExp('[^A-Za-z0-9._-]+'), '_');
  }
}
