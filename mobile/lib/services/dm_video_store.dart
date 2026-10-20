// ABOUTME: Keeps received video DMs on this device, decrypted, for one account:
// ABOUTME: one download per video, a preview frame, and pruning by age and size.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:models/models.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_preview.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Downloads, verifies and decrypts a video DM, returning its plaintext.
typedef DmVideoFetcher = Future<Uint8List> Function(DmMessage message);

/// Reads the preview frame of a decrypted video, or null when it cannot.
typedef DmVideoFrameReader = Future<Uint8List?> Function(File video);

/// The [DmVideoStore] of the account signed in now, or null when none is.
///
/// Resolved when a save starts, so a save keeps the account that asked even
/// if the user switches accounts while it runs.
typedef DmVideoStoreResolver = DmVideoStore? Function();

/// Keeps one account's received video DMs on this device, decrypted, so each
/// is downloaded and decrypted once and its card can show a real frame.
///
/// Files live in the app's cache directory, which is not backed up and which
/// the system may clear when storage runs low, under one folder per account.
/// A file nobody opened for [maxIdle] is deleted, and past [maxBytes] the
/// least recently opened go first. An account's folder goes when the account
/// leaves this device ([deleteOwner], [deleteOwnersNotIn]).
///
/// The decryption key and nonce are never written anywhere; only the
/// plaintext video and its frame are, and neither path is logged.
class DmVideoStore {
  /// Creates a [DmVideoStore] for the account [ownerPubkey].
  ///
  /// [readFrame] defaults to [readDmVideoCardFrame], [rootDirectory] to the
  /// app's cache directory and [now] to the wall clock; they exist so tests
  /// can inject fakes.
  DmVideoStore({
    required String ownerPubkey,
    required DmVideoFetcher fetchVideo,
    DmVideoFrameReader? readFrame,
    Future<Directory> Function()? rootDirectory,
    DateTime Function()? now,
    this.maxIdle = defaultMaxIdle,
    this.maxBytes = defaultMaxBytes,
  }) : _ownerPubkey = ownerPubkey,
       _fetchVideo = fetchVideo,
       _readFrame = readFrame ?? readDmVideoCardFrame,
       _rootDirectory = rootDirectory ?? getApplicationCacheDirectory,
       _now = now ?? DateTime.now;

  /// Folder under the cache directory that holds every account's videos.
  static const String dirName = 'dm_videos';

  /// How long a kept file may go unopened before [prune] deletes it.
  static const Duration defaultMaxIdle = Duration(days: 30);

  /// How much one account's kept files may take before [prune] trims them.
  static const int defaultMaxBytes = 300 * 1024 * 1024;

  static const String _partSuffix = '.part';
  static const String _logName = 'DmVideoStore';

  /// How long a file may go unopened before [prune] deletes it.
  final Duration maxIdle;

  /// Upper bound, in bytes, on this account's kept files.
  final int maxBytes;

  final String _ownerPubkey;
  final DmVideoFetcher _fetchVideo;
  final DmVideoFrameReader _readFrame;
  final Future<Directory> Function() _rootDirectory;
  final DateTime Function() _now;

  final Map<String, Future<File>> _videosInFlight = {};
  final Map<String, Future<File?>> _previewsInFlight = {};
  final Set<String> _partsBeingWritten = {};
  final StreamController<String> _kept = StreamController<String>.broadcast();

  /// Ids of messages whose video was just kept, so a card waiting for a
  /// video it may not download itself can show its frame once it is played.
  Stream<String> get kept => _kept.stream;

  /// File name of [message]'s kept video.
  ///
  /// The extension comes from [dmVideoFileExtensionFor] so the native decoder
  /// sees a container it recognises: iOS refuses a QuickTime video named
  /// after its MIME subtype, `.quicktime`.
  static String videoFileNameFor(DmMessage message) {
    final extension = dmVideoFileExtensionFor(
      message.fileMetadata?.fileType ?? '',
    );
    return '${_safeName(message.id)}.$extension';
  }

  static String _previewFileNameFor(DmMessage message) =>
      '${_safeName(message.id)}.preview.jpg';

  static String _safeName(String value) =>
      value.replaceAll(RegExp('[^A-Za-z0-9]'), '');

  /// [message]'s decrypted video, downloaded and decrypted the first time
  /// and kept after that. Callers asking at once share one download.
  ///
  /// Throws whatever the fetcher throws (see `DmVideoDecryptor.decrypt`) or
  /// a [FileSystemException] when the video cannot be stored. Nothing is kept
  /// on a failure.
  Future<File> videoFor(DmMessage message) {
    final id = message.id;
    // A block body: `remove` returns this very future, and whenComplete
    // would wait for it, so an arrow body never completes.
    return _videosInFlight[id] ??= _obtainVideo(message).whenComplete(() {
      _videosInFlight.remove(id);
    });
  }

  /// [message]'s kept preview frame, read once from its video.
  ///
  /// When [download] is false only a video that is already kept is used, so
  /// a message from someone the user has not accepted never fetches anything.
  /// Null when there is no video to read or no frame can be read from it.
  Future<File?> previewFor(DmMessage message, {required bool download}) {
    final key = '${message.id}|$download';
    return _previewsInFlight[key] ??=
        _obtainPreview(
          message,
          download: download,
        ).whenComplete(() {
          _previewsInFlight.remove(key);
        });
  }

  /// Deletes files nobody opened for [maxIdle], then the least recently
  /// opened ones until this account's files fit in [maxBytes].
  Future<void> prune() async {
    final dir = await _ownerDirectory();
    if (!dir.existsSync()) return;
    final cutoff = _now().subtract(maxIdle);
    final kept = <({File file, DateTime opened, int size})>[];
    await for (final entity in dir.list()) {
      if (entity is! File || _partsBeingWritten.contains(entity.path)) {
        continue;
      }
      final stat = entity.statSync();
      // A part file not being written was left by a crash mid-write.
      if (entity.path.endsWith(_partSuffix) || stat.modified.isBefore(cutoff)) {
        _deleteQuietly(entity);
        continue;
      }
      kept.add((file: entity, opened: stat.modified, size: stat.size));
    }

    var total = kept.fold<int>(0, (sum, entry) => sum + entry.size);
    if (total <= maxBytes) return;
    kept.sort((a, b) => a.opened.compareTo(b.opened));
    for (final entry in kept) {
      if (total <= maxBytes) break;
      _deleteQuietly(entry.file);
      total -= entry.size;
    }
  }

  /// Closes [kept].
  Future<void> dispose() => _kept.close();

  /// Deletes every video kept for [ownerPubkey].
  static Future<void> deleteOwner(
    String ownerPubkey, {
    Future<Directory> Function()? rootDirectory,
  }) async {
    final root = await (rootDirectory ?? getApplicationCacheDirectory)();
    final dir = Directory('${root.path}/$dirName/${_safeName(ownerPubkey)}');
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Deletes the videos kept for every account not in [keepOwnerPubkeys] and
  /// returns how many accounts' videos it deleted.
  static Future<int> deleteOwnersNotIn(
    Set<String> keepOwnerPubkeys, {
    Future<Directory> Function()? rootDirectory,
  }) async {
    final root = await (rootDirectory ?? getApplicationCacheDirectory)();
    final dir = Directory('${root.path}/$dirName');
    if (!dir.existsSync()) return 0;
    final keep = keepOwnerPubkeys.map(_safeName).toSet();
    var deleted = 0;
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      if (keep.contains(
        entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
      )) {
        continue;
      }
      await entity.delete(recursive: true);
      deleted++;
    }
    return deleted;
  }

  Future<File> _obtainVideo(DmMessage message) async {
    final file = File(
      '${(await _ownerDirectory()).path}/${videoFileNameFor(message)}',
    );
    if (file.existsSync()) {
      _markOpened(file);
      return file;
    }
    await _writeAtomically(file, await _fetchVideo(message));
    _kept.add(message.id);
    runDetached(
      prune(),
      'prune kept video DMs',
      logName: _logName,
      category: LogCategory.video,
    );
    return file;
  }

  Future<File?> _obtainPreview(
    DmMessage message, {
    required bool download,
  }) async {
    final dir = await _ownerDirectory();
    final preview = File('${dir.path}/${_previewFileNameFor(message)}');
    if (preview.existsSync()) {
      _markOpened(preview);
      return preview;
    }

    final keptVideo = File('${dir.path}/${videoFileNameFor(message)}');
    final File video;
    if (keptVideo.existsSync()) {
      video = keptVideo;
    } else if (download) {
      video = await videoFor(message);
    } else {
      return null;
    }

    final frame = await _readFrame(video);
    if (frame == null || frame.isEmpty) return null;
    await _writeAtomically(preview, frame);
    return preview;
  }

  Future<Directory> _ownerDirectory() async {
    final root = await _rootDirectory();
    return Directory('${root.path}/$dirName/${_safeName(_ownerPubkey)}');
  }

  /// Writes [bytes] beside [file] and renames it into place, so a reader
  /// never sees half a video and a crash leaves only a part file to prune.
  Future<void> _writeAtomically(File file, Uint8List bytes) async {
    final part = File('${file.path}$_partSuffix');
    _partsBeingWritten.add(part.path);
    try {
      await part.parent.create(recursive: true);
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(file.path);
    } catch (_) {
      _deleteQuietly(part);
      rethrow;
    } finally {
      _partsBeingWritten.remove(part.path);
    }
  }

  /// Records that [file] was opened now, which keeps [prune] off it.
  void _markOpened(File file) {
    try {
      file.setLastModifiedSync(_now());
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not mark a kept video DM file as opened: ${error.osError}',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not delete a kept video DM file: ${error.osError}',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }
}
