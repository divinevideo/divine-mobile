// ABOUTME: Keeps received video DMs on this device, decrypted, for one account:
// ABOUTME: one download per video, a preview frame, and pruning by age and size.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:models/models.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_preview.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Downloads, verifies and decrypts a video DM, returning its plaintext. A
/// null [maxBytes] or [timeLimit] keeps the fetcher's own limit.
typedef DmVideoFetcher = Future<Uint8List> Function(
  DmMessage message, {
  int? maxBytes,
  Duration? timeLimit,
});

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
/// leaves this device ([deleteOwner], [sweepOwners]).
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
       _removalsAtCreation = _removals[_safeName(ownerPubkey)] ?? 0,
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

  /// Largest video, in ciphertext bytes, fetched without a tap on play. A
  /// bigger one waits for the tap, which still allows the full size.
  static const int autoDownloadMaxBytes = 25 * 1024 * 1024;

  /// How long a download without a tap on play may run.
  static const Duration autoDownloadTimeLimit = Duration(minutes: 1);

  static const String _partSuffix = '.part';

  /// Age past which [sweepOwners] treats a part file as left by a crash.
  static const Duration _crashedPartAge = Duration(hours: 1);

  /// How many times each account's videos were deleted by [deleteOwner]. A
  /// store remembers the count it was created at, so a download that lands
  /// after its account was removed cannot write the video back.
  static final Map<String, int> _removals = {};
  static const String _logName = 'DmVideoStore';

  /// How long a file may go unopened before [prune] deletes it.
  final Duration maxIdle;

  /// Upper bound, in bytes, on this account's kept files.
  final int maxBytes;

  final String _ownerPubkey;
  final int _removalsAtCreation;
  final DmVideoFetcher _fetchVideo;
  final DmVideoFrameReader _readFrame;
  final Future<Directory> Function() _rootDirectory;
  final DateTime Function() _now;

  final Map<String, Future<File>> _videosInFlight = {};
  final Map<String, Future<File>> _autoDownloadsInFlight = {};

  /// Downloads without a tap on play run one at a time: each holds a whole
  /// video in memory, and a long thread shows many at once.
  Future<void> _autoDownloadQueue = Future<void>.value();
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
    // removeWhere, not remove: remove hands back this very future, and
    // whenComplete waits for a future its callback returns.
    return _videosInFlight[id] ??= _obtainVideo(
      message,
    ).whenComplete(() => _videosInFlight.removeWhere((key, _) => key == id));
  }

  /// [message]'s kept preview frame, read once from its video.
  ///
  /// When [download] is false only a video that is already kept is used, so
  /// a message from someone the user has not accepted never fetches anything.
  /// When it is true the video is fetched in turn with other such downloads,
  /// within [autoDownloadMaxBytes] and [autoDownloadTimeLimit]; one declared
  /// bigger is not fetched. Null when there is no video to read or no frame
  /// can be read from it.
  Future<File?> previewFor(DmMessage message, {required bool download}) {
    final key = '${message.id}|$download';
    return _previewsInFlight[key] ??=
        _obtainPreview(
          message,
          download: download,
        ).whenComplete(
          () => _previewsInFlight.removeWhere((pending, _) => pending == key),
        );
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
    final owner = _safeName(ownerPubkey);
    _removals.update(owner, (count) => count + 1, ifAbsent: () => 1);
    final root = await (rootDirectory ?? getApplicationCacheDirectory)();
    final dir = Directory('${root.path}/$dirName/$owner');
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Deletes the videos kept for every account not in [keepOwnerPubkeys],
  /// and in the kept accounts' folders whatever nobody opened for [maxIdle]
  /// and part files a crash left. Returns how many accounts' videos it
  /// deleted.
  ///
  /// Runs at launch for every account, so an account the user switched away
  /// from does not keep its videos past [maxIdle]: its store prunes only
  /// while it is the signed-in one.
  static Future<int> sweepOwners(
    Set<String> keepOwnerPubkeys, {
    Future<Directory> Function()? rootDirectory,
    DateTime Function()? now,
    Duration maxIdle = defaultMaxIdle,
  }) async {
    final root = await (rootDirectory ?? getApplicationCacheDirectory)();
    final dir = Directory('${root.path}/$dirName');
    if (!dir.existsSync()) return 0;
    final keep = keepOwnerPubkeys.map(_safeName).toSet();
    final currentTime = (now ?? DateTime.now)();
    var deleted = 0;
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      if (keep.contains(
        entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
      )) {
        _deleteIdleFiles(entity, currentTime, maxIdle);
        continue;
      }
      await entity.delete(recursive: true);
      deleted++;
    }
    return deleted;
  }

  /// Deletes files in [dir] unopened for [maxIdle], and part files older than
  /// [_crashedPartAge]: a younger one may be a download the signed-in
  /// account's store is still writing.
  static void _deleteIdleFiles(
    Directory dir,
    DateTime now,
    Duration maxIdle,
  ) {
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final age = now.difference(entity.statSync().modified);
      final isPart = entity.path.endsWith(_partSuffix);
      if (age > maxIdle || (isPart && age > _crashedPartAge)) {
        _deleteQuietly(entity);
      }
    }
  }

  /// Fetches [message]'s video in turn with other downloads nobody tapped
  /// for, within their limits. Not shared with [videoFor], which a tap on
  /// play must not see fail for a limit it does not have.
  Future<File> _autoVideoFor(DmMessage message) {
    final id = message.id;
    return _autoDownloadsInFlight[id] ??=
        _inAutoDownloadQueue(
          () => _obtainVideo(
            message,
            maxBytes: autoDownloadMaxBytes,
            timeLimit: autoDownloadTimeLimit,
          ),
        ).whenComplete(
          () => _autoDownloadsInFlight.removeWhere((key, _) => key == id),
        );
  }

  Future<File> _inAutoDownloadQueue(Future<File> Function() download) {
    final turn = _autoDownloadQueue.then((_) => download());
    // The next download waits for this one to settle, failed or not.
    _autoDownloadQueue = turn.then<void>((_) {}, onError: (Object _) {});
    return turn;
  }

  Future<File> _obtainVideo(
    DmMessage message, {
    int? maxBytes,
    Duration? timeLimit,
  }) async {
    final file = File(
      '${(await _ownerDirectory()).path}/${videoFileNameFor(message)}',
    );
    if (file.existsSync()) {
      _markOpened(file);
      return file;
    }
    await _writeAtomically(
      file,
      await _fetchVideo(message, maxBytes: maxBytes, timeLimit: timeLimit),
    );
    // An account switch disposes the store while a download can still land.
    if (!_kept.isClosed) _kept.add(message.id);
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
    final declaredBytes = message.fileMetadata?.fileSize;
    final File video;
    if (keptVideo.existsSync()) {
      video = keptVideo;
    } else if (download &&
        (declaredBytes == null || declaredBytes <= autoDownloadMaxBytes)) {
      video = await _autoVideoFor(message);
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
      _throwIfOwnerRemoved();
      await part.parent.create(recursive: true);
      await part.writeAsBytes(bytes, flush: true);
      _throwIfOwnerRemoved();
      await part.rename(file.path);
    } catch (_) {
      _deleteQuietly(part);
      rethrow;
    } finally {
      _partsBeingWritten.remove(part.path);
    }
  }

  void _throwIfOwnerRemoved() {
    if ((_removals[_safeName(_ownerPubkey)] ?? 0) != _removalsAtCreation) {
      throw const DmVideoUnavailableException(
        'the account was removed from this device',
      );
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

  static void _deleteQuietly(File file) {
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
