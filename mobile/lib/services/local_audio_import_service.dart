import 'dart:io';

import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

typedef AudioImportStorageRootProvider = Future<Directory> Function();
typedef AudioImportDurationResolver = Future<Duration?> Function(File file);
typedef AudioImportClock = DateTime Function();

class LocalAudioImportException implements Exception {
  const LocalAudioImportException(this.message);

  final String message;

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

  /// Copies [sourcePath] into library-owned audio storage.
  ///
  /// The destination is [libraryAudioImportsDirName], not the open draft: an
  /// imported track can be saved to My Sounds and outlive any draft, so no
  /// draft owns it (#8024).
  Future<AudioEvent> importAudioFile({
    required String sourcePath,
    required String displayName,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const LocalAudioImportException('Audio file could not be opened.');
    }

    final extension = p.extension(displayName).toLowerCase();
    final mimeType = _mimeTypeForExtension(extension);
    if (mimeType == null) {
      throw const LocalAudioImportException(
        'That audio file type is not supported.',
      );
    }

    final now = _clock();
    final fileName = _safeFileName(
      '${now.millisecondsSinceEpoch}_${p.basename(displayName)}',
    );
    final root = await _storageRootProvider();
    await root.create(recursive: true);

    final copied = await source.copy(p.join(root.path, fileName));
    final duration = await _durationResolver(copied);

    return AudioEvent.fromLocalImport(
      id: 'local_import_${now.millisecondsSinceEpoch}',
      filePath: copied.path,
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      title: _titleFromDisplayName(displayName),
      mimeType: mimeType,
      duration: duration == null ? null : duration.inMilliseconds / 1000,
    );
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

  static String? _mimeTypeForExtension(String extension) => switch (extension) {
    '.aac' => 'audio/aac',
    '.m4a' => 'audio/mp4',
    '.mp3' => 'audio/mpeg',
    '.wav' => 'audio/wav',
    '.weba' => 'audio/webm',
    '.webm' => 'audio/webm',
    _ => null,
  };

  static String _titleFromDisplayName(String displayName) {
    final withoutExtension = p.basenameWithoutExtension(displayName).trim();
    return withoutExtension.isEmpty ? 'Imported audio' : withoutExtension;
  }

  static String _safeFileName(String input) {
    return input.replaceAll(RegExp('[^A-Za-z0-9._-]+'), '_');
  }
}
