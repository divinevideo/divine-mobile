// ABOUTME: Keeps received video DMs on this device, decrypted, for one account:
// ABOUTME: one download per video, a preview frame, and pruning by age and size.

import 'dart:async';
import 'dart:convert';
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
/// null [maxBytes] or [timeLimit] keeps the fetcher's own limit, as does
/// either once [limitsApply] says no, and a download may stop once
/// [stillWanted] says no.
typedef DmVideoFetcher = Future<Uint8List> Function(
  DmMessage message, {
  int? maxBytes,
  Duration? timeLimit,
  bool Function()? limitsApply,
  bool Function()? stillWanted,
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
/// least recently opened go first, videos before frames. Everything kept for
/// a message that is gone (see `isMessageGone`) goes at the next [prune]. An
/// account's folder goes when the account leaves this device ([deleteOwner],
/// [sweepOwners]).
///
/// The decryption key and nonce are never written anywhere; only the
/// plaintext video and its frame are, and neither path is logged.
class DmVideoStore {
  /// Creates a [DmVideoStore] for the account [ownerPubkey].
  ///
  /// [isMessageGone] says whether a message was retracted or removed with
  /// its conversation; [prune] then deletes what is kept for it. Without it
  /// nothing is deleted on those grounds. [isConversationRemoved] says
  /// whether the user removed a conversation at or after a message in it was
  /// sent, which [prune] asks too, from a record kept beside each video: the
  /// message's row can be missing, as after an account switch.
  ///
  /// [readFrame] defaults to [readDmVideoCardFrame], [rootDirectory] to the
  /// app's cache directory and [now] to the wall clock; they exist so tests
  /// can inject fakes.
  DmVideoStore({
    required String ownerPubkey,
    required DmVideoFetcher fetchVideo,
    DmVideoFrameReader? readFrame,
    Future<bool> Function(String messageId)? isMessageGone,
    Future<bool> Function(String conversationId, int sentAt)?
    isConversationRemoved,
    Future<Directory> Function()? rootDirectory,
    DateTime Function()? now,
    this.maxIdle = defaultMaxIdle,
    this.maxBytes = defaultMaxBytes,
  }) : _ownerPubkey = ownerPubkey,
       _removalsAtCreation = _removals[_safeName(ownerPubkey)] ?? 0,
       _fetchVideo = fetchVideo,
       _readFrame = readFrame ?? readDmVideoCardFrame,
       _isMessageGone = isMessageGone,
       _isConversationRemoved = isConversationRemoved,
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

  /// How long after a message goes [prune] runs for it at most. Changes that
  /// arrive meanwhile share that prune: a history download writes in bursts,
  /// and a steady run of writes must not hold the prune off.
  static const Duration goneCleanupDelay = Duration(seconds: 5);

  /// How long a card waits before fetching again by itself after a failure
  /// that may pass, such as a dropped connection.
  static const Duration autoDownloadRetryAfter = Duration(minutes: 2);

  static const String _partSuffix = '.part';

  /// Beside a video from the start of its frame read until a frame is kept,
  /// so a read that fails or never finishes, as when the decoder crashes the
  /// app, is not tried again.
  static const String _frameAttemptSuffix = '.frame-attempt';

  /// Beside a kept video and its frame for as long as either stays: the
  /// conversation they came from and when the message was sent, so removing
  /// that conversation deletes them even once the message row is gone.
  static const String _conversationSuffix = '.conversation';

  /// Age past which a part file is taken as left by a crash: a younger one
  /// may still be being written, by this store or by the one an account
  /// switch replaced.
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
  final Future<bool> Function(String messageId)? _isMessageGone;
  final Future<bool> Function(String conversationId, int sentAt)?
  _isConversationRemoved;
  final Future<Directory> Function() _rootDirectory;
  final DateTime Function() _now;

  final Map<String, Future<File>> _videosInFlight = {};
  final Map<String, Future<File>> _autoDownloadsInFlight = {};

  /// Downloads nobody tapped for that are fetching, each with the signal a tap
  /// completes to take it over.
  final Map<String, ({Future<File> video, Completer<void> takeover})>
  _autoFetchesRunning = {};

  /// Videos handed to playback or a save. Never deleted for their age or the
  /// cap while this store lives, so playing or saving one does not find it
  /// gone; only a gone message's video is deleted after its hand-out.
  final Set<String> _handedOut = {};

  /// Videos about to be handed out or being read for their frame, counted.
  /// Never pruned until released.
  final Map<String, int> _leases = {};

  /// Files of gone messages a prune left because they were leased, pruned
  /// again once their last lease is released.
  final Set<String> _goneWhileLeased = {};

  /// The prune under way, if any, and whether one was asked for meanwhile.
  Future<void>? _pruning;
  bool _pruneAgain = false;

  /// Downloads without a tap on play run one at a time: each holds a whole
  /// video in memory, and a long thread shows many at once.
  final _OneAtATime _autoDownloads = _OneAtATime();

  /// Frame reads run one at a time too: a crash then marks only the video
  /// being read, and a long thread does not start a native decoder per card.
  final _OneAtATime _frameReads = _OneAtATime();
  final Map<String, Future<File?>> _previewsInFlight = {};

  /// Frame reads by message id, shared by every caller asking at once.
  final Map<String, Future<File?>> _frameReadsInFlight = {};

  /// Whether each caller waiting on a frame still wants it, by preview key.
  final Map<String, List<bool Function()>> _previewWanters = {};

  /// Paths of the frames this store read or found, by message id.
  final Map<String, String> _knownPreviews = {};

  /// Ids of messages whose frame could not be read this session. The mark
  /// beside the video keeps the read from being tried in later sessions too.
  final Set<String> _unreadableFrames = {};

  /// Downloads nobody tapped for that failed, by message id, with when a card
  /// may fetch it again by itself, or null when the failure will repeat.
  final Map<String, DateTime?> _autoDownloadFailures = {};
  int _writes = 0;
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
      '${_safeName(message.id)}$_previewSuffix';

  static const String _previewSuffix = '.preview.jpg';

  static String _safeName(String value) =>
      value.replaceAll(RegExp('[^A-Za-z0-9]'), '');

  /// [message]'s decrypted video, downloaded and decrypted the first time
  /// and kept after that. Callers asking at once share one download. A card's
  /// download already fetching it is taken over, free of its limits; one
  /// still waiting in the queue is not waited for.
  ///
  /// Throws whatever the fetcher throws (see `DmVideoDecryptor.decrypt`) or
  /// a [DmVideoUnavailableException] when the video cannot be stored, naming
  /// the cause but not the file. Nothing is kept on a failure.
  Future<File> videoFor(DmMessage message) {
    final id = message.id;
    // removeWhere, not remove: remove hands back this very future, and
    // whenComplete waits for a future its callback returns.
    return _videosInFlight[id] ??= _tapVideoFor(message)
        .then((file) {
          _handedOut.add(file.path);
          _release(file);
          return file;
        })
        .whenComplete(() => _videosInFlight.removeWhere((key, _) => key == id));
  }

  Future<File> _tapVideoFor(DmMessage message) async {
    final running = _autoFetchesRunning[message.id];
    if (running != null) {
      // From here on it runs without the automatic limits, out of the queue.
      if (!running.takeover.isCompleted) running.takeover.complete();
      try {
        // That download's lease is its card's, released after the frame.
        final file = await running.video;
        _lease(file);
        return file;
      } on Object catch (error) {
        // A limit it hit before this tap lifted them, or a failure that may
        // pass, is fetched again in full; anything else would only repeat,
        // as would storing it at once.
        final again =
            error is DmVideoLimitException ||
            (error is DmVideoUnavailableException &&
                error.mayPass &&
                error is! DmVideoStorageException);
        if (!again) rethrow;
      }
    }
    return _obtainVideo(message);
  }

  /// [message]'s kept preview frame, read once from its video.
  ///
  /// When [download] is false only a video that is already kept is used, so
  /// a message from someone the user has not accepted never fetches anything.
  /// When it is true the video is fetched in turn with other such downloads,
  /// within [autoDownloadMaxBytes] and [autoDownloadTimeLimit]; one declared
  /// bigger is not fetched. Null when there is no video to read or no frame
  /// can be read from it; a frame that could not be read, or whose read never
  /// finished, is not tried again. A download that failed is not tried again by
  /// itself this session when the failure will repeat, nor for
  /// [autoDownloadRetryAfter] when it may pass; a tap on play still fetches
  /// it.
  ///
  /// When [decode] is false nothing is decoded, only a frame read before is
  /// returned: for a sender the user blocked, whose file should not reach the
  /// native decoder without a tap.
  ///
  /// [stillWanted], when given, is asked before a queued download starts,
  /// while it runs and before the frame is read. Once no caller waiting on
  /// this frame wants it, as when their cards closed, that work is dropped
  /// and null returned, unless a tap on play waits for the same video.
  ///
  /// Throws what [videoFor] throws when it downloads the video, or a
  /// [DmVideoUnavailableException] when the frame cannot be stored.
  Future<File?> previewFor(
    DmMessage message, {
    required bool download,
    bool decode = true,
    bool Function()? stillWanted,
  }) {
    assert(decode || !download, 'a card downloads a video only to decode it');
    final key = '${message.id}|$download|$decode';
    (_previewWanters[key] ??= []).add(stillWanted ?? _alwaysWanted);
    return _previewsInFlight[key] ??=
        _obtainPreview(
          message,
          download: download,
          decode: decode,
          wanted: () =>
              _previewWanters[key]?.any((wanted) => wanted()) ?? false,
        ).whenComplete(() {
          _previewsInFlight.removeWhere((pending, _) => pending == key);
          _previewWanters.removeWhere((pending, _) => pending == key);
        });
  }

  static bool _alwaysWanted() => true;

  /// Whether a caller allowed to decode [messageId]'s video still waits for
  /// its frame. Callers share one read, whether they may download or not.
  bool _frameWanted(String messageId) => [
    for (final download in const [true, false])
      ...?_previewWanters['$messageId|$download|true'],
  ].any((wanted) => wanted());

  /// The path of [message]'s frame when this store already read or found it,
  /// so a card built again shows it at once. Null once the file is gone: the
  /// system can clear the cache directory while the app runs.
  String? knownPreviewPathFor(DmMessage message) {
    final path = _knownPreviews[message.id];
    if (path == null || File(path).existsSync()) return path;
    _knownPreviews.remove(message.id);
    return null;
  }

  /// Deletes files nobody opened for [maxIdle], then, until this account's
  /// files fit in [maxBytes], the least recently opened videos and, only
  /// after every video, frames: a frame is what a card shows, and costs
  /// little.
  ///
  /// Everything kept for a message that is gone is deleted too, even a video
  /// played this session: a video retracted by its sender or removed with its
  /// conversation goes at the next prune or, while a read or a hand-out of it
  /// is under way, once that ends. An account the user switched away from
  /// keeps such videos until it is signed in again or they sit unopened for
  /// [maxIdle], since its rows are cleared on the switch.
  ///
  /// A video handed to playback or a save this session, or being read for its
  /// frame, is not deleted for its age or the cap and does not count against
  /// [maxBytes], so in-use videos can keep the folder over it. Part files are
  /// deleted once old enough to be a crash's, or as soon as their message is
  /// gone. A folder that cannot be read is logged, without its path, and
  /// left.
  ///
  /// One prune runs at a time. Asked for while one runs, it runs once more
  /// after it, for every caller asking meanwhile, and completes with that.
  Future<void> prune() {
    final running = _pruning;
    if (running != null) {
      _pruneAgain = true;
      return running;
    }
    return _pruning = _pruneWhileAsked();
  }

  Future<void> _pruneWhileAsked() async {
    (Object, StackTrace)? unexpected;
    try {
      do {
        _pruneAgain = false;
        try {
          await _prune();
        } on FileSystemException catch (error) {
          Log.warning(
            'Could not prune kept video DMs: ${_causeOf(error)}',
            name: _logName,
            category: LogCategory.video,
          );
        } on Object catch (error, stackTrace) {
          // Thrown once the runs asked for meanwhile are done, not instead.
          unexpected ??= (error, stackTrace);
        }
      } while (_pruneAgain);
    } finally {
      // Cleared before this run completes, so a later ask starts a new run.
      _pruning = null;
    }
    if (unexpected case (final error, final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _prune() async {
    final dir = await _ownerDirectory();
    if (!dir.existsSync()) return;
    final gone = await _goneMessageIds(
      await dir.list().where((entity) => entity is File).cast<File>().toList(),
    );
    // Listed again where nothing awaits: a frame written during the lookups
    // is seen too, and no file can be handed out between the check that it
    // is free and its deletion.
    if (!dir.existsSync()) return;
    final files = dir.listSync().whereType<File>().toList();
    final withVideo = _messageIdsWithVideo(files);
    final withContent = _messageIdsWithContent(files);
    final leased = {for (final path in _leases.keys) _messageIdOf(File(path))};
    final now = _now();
    final kept = <({File file, DateTime opened, int size})>[];
    for (final file in files) {
      final stat = file.statSync();
      if (stat.type == FileSystemEntityType.notFound) continue;
      final age = now.difference(stat.modified);
      final id = _messageIdOf(file);
      // Even a video played this session goes: its sender took it back, or
      // the user removed it. Only a read or a hand-out under way holds it,
      // and its release prunes again; the record and mark stay with it, as
      // that prune may need the record to tell. A part file goes however
      // young, as its write is no longer wanted.
      if (gone.contains(id)) {
        if (_leases.containsKey(file.path)) {
          _goneWhileLeased.add(file.path);
        } else if (_isSatellite(file) && leased.contains(id)) {
          continue;
        } else {
          _deleteNow(file);
          continue;
        }
      }
      if (file.path.endsWith(_partSuffix)) {
        if (age > _crashedPartAge) _deleteNow(file);
        continue;
      }
      if (file.path.endsWith(_frameAttemptSuffix)) {
        if (!withVideo.contains(id)) _deleteNow(file);
        continue;
      }
      if (file.path.endsWith(_conversationSuffix)) {
        if (!withContent.contains(id) && !leased.contains(id)) {
          _deleteNow(file);
        }
        continue;
      }
      if (age > maxIdle && !_isInUse(file)) {
        _deleteNow(file);
        continue;
      }
      kept.add((file: file, opened: stat.modified, size: stat.size));
    }

    // Files in use neither count against the cap nor go to meet it: counted,
    // a few played videos would leave nothing else room, frames included.
    final trimmable = [
      for (final entry in kept)
        if (!_isInUse(entry.file)) entry,
    ];
    var total = trimmable.fold<int>(0, (sum, entry) => sum + entry.size);
    if (total <= maxBytes) return;
    trimmable.sort((a, b) {
      final aIsFrame = a.file.path.endsWith(_previewSuffix);
      if (aIsFrame != b.file.path.endsWith(_previewSuffix)) {
        return aIsFrame ? 1 : -1;
      }
      return a.opened.compareTo(b.opened);
    });
    for (final entry in trimmable) {
      if (total <= maxBytes) break;
      _deleteNow(entry.file);
      total -= entry.size;
    }
  }

  /// Closes [kept].
  Future<void> dispose() => _kept.close();

  /// Deletes every video kept for [ownerPubkey].
  ///
  /// Throws a [DmVideoUnavailableException] naming the cause, but not the
  /// folder, when they cannot all be deleted.
  static Future<void> deleteOwner(
    String ownerPubkey, {
    Future<Directory> Function()? rootDirectory,
  }) async {
    final owner = _safeName(ownerPubkey);
    _removals.update(owner, (count) => count + 1, ifAbsent: () => 1);
    final root = await (rootDirectory ?? getApplicationCacheDirectory)();
    final dir = Directory('${root.path}/$dirName/$owner');
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } on FileSystemException catch (error) {
      throw DmVideoUnavailableException(
        'could not delete the kept videos: ${_causeOf(error)}',
      );
    }
  }

  /// Deletes the videos kept for every account not in [keepOwnerPubkeys],
  /// and in the kept accounts' folders whatever nobody opened for [maxIdle]
  /// and part files a crash left. Returns how many accounts' videos it
  /// deleted. A folder that cannot be read or deleted is logged, without its
  /// path, and left for the next sweep; the others are still swept.
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
    try {
      await for (final entity in dir.list()) {
        if (entity is! Directory) continue;
        try {
          if (keep.contains(
            entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
          )) {
            await _deleteIdleFiles(entity, currentTime, maxIdle);
            continue;
          }
          await entity.delete(recursive: true);
          deleted++;
        } on FileSystemException catch (error) {
          Log.warning(
            "Could not sweep one account's kept video DMs: "
            '${_causeOf(error)}',
            name: _logName,
            category: LogCategory.video,
          );
        }
      }
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not sweep kept video DMs: ${_causeOf(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
    return deleted;
  }

  /// Deletes files in [dir] unopened for [maxIdle], and part files older than
  /// [_crashedPartAge]: a younger one may be a download the signed-in
  /// account's store is still writing.
  static Future<void> _deleteIdleFiles(
    Directory dir,
    DateTime now,
    Duration maxIdle,
  ) async {
    final files = await dir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    final withVideo = _messageIdsWithVideo(files);
    final withContent = _messageIdsWithContent(files);
    for (final file in files) {
      final id = _messageIdOf(file);
      if (file.path.endsWith(_frameAttemptSuffix) && !withVideo.contains(id) ||
          file.path.endsWith(_conversationSuffix) &&
              !withContent.contains(id)) {
        await _deleteQuietly(file);
        continue;
      }
      if (_isSatellite(file)) continue;
      final age = now.difference(file.statSync().modified);
      final isPart = file.path.endsWith(_partSuffix);
      if (age > maxIdle || (isPart && age > _crashedPartAge)) {
        await _deleteQuietly(file);
      }
    }
  }

  /// Ids of the messages whose video is among [files].
  static Set<String> _messageIdsWithVideo(List<File> files) => {
    for (final file in files)
      if (!file.path.endsWith(_partSuffix) &&
          !file.path.endsWith(_previewSuffix) &&
          !_isSatellite(file))
        _messageIdOf(file),
  };

  /// Ids of the messages with a video or a frame among [files], whole or
  /// still being written.
  static Set<String> _messageIdsWithContent(List<File> files) => {
    for (final file in files)
      if (!_isSatellite(file)) _messageIdOf(file),
  };

  /// Whether [file] only describes its message's other files, and so never
  /// ages or is trimmed by itself: a frame-read mark, kept while the video
  /// stays, as a decode that never finished must not be retried while the
  /// file that caused it is here; and a conversation record, kept while
  /// anything of the message stays, as it is what lets a removal find them.
  static bool _isSatellite(File file) =>
      file.path.endsWith(_frameAttemptSuffix) ||
      file.path.endsWith(_conversationSuffix);

  /// Fetches [message]'s video in turn with other downloads nobody tapped
  /// for, within their limits, or, when its turn comes, uses the download a
  /// tap started meanwhile. A tap that waits for the download once it runs
  /// takes it over: its limits are lifted and the next turn starts. Dropped
  /// at its turn, and stopped while running, once [wanted] says no and no tap
  /// waits for it.
  Future<File> _autoVideoFor(
    DmMessage message, {
    required bool Function() wanted,
  }) {
    final id = message.id;
    return _autoDownloadsInFlight[id] ??= _autoVideoInTurn(message, wanted)
        .whenComplete(
          () => _autoDownloadsInFlight.removeWhere((key, _) => key == id),
        );
  }

  Future<File> _autoVideoInTurn(
    DmMessage message,
    bool Function() wanted,
  ) async {
    final id = message.id;
    // A download a tap waits for is waited for after the turn: it runs
    // without limits, and other cards' downloads must not wait behind it.
    final (:download, :leased) = await _autoDownloads.run(() async {
      final tapped = _videosInFlight[id];
      if (tapped != null) return (download: tapped, leased: false);
      if (!wanted()) throw const _DownloadDropped();
      final takeover = Completer<void>();
      final fetch = _obtainVideo(
        message,
        maxBytes: autoDownloadMaxBytes,
        timeLimit: autoDownloadTimeLimit,
        limitsApply: () => !takeover.isCompleted,
        stillWanted: () => wanted() || takeover.isCompleted,
      );
      _autoFetchesRunning[id] = (video: fetch, takeover: takeover);
      // Its outcome reaches the card and any tap through their own waits.
      fetch
          .whenComplete(
            () => _autoFetchesRunning.removeWhere((key, _) => key == id),
          )
          .ignore();
      await Future.any<void>([fetch, takeover.future]);
      return (download: fetch, leased: true);
    });
    final file = await download;
    // A tap's download is leased for the tap only.
    if (!leased) _lease(file);
    return file;
  }

  Future<File> _obtainVideo(
    DmMessage message, {
    int? maxBytes,
    Duration? timeLimit,
    bool Function()? limitsApply,
    bool Function()? stillWanted,
  }) async {
    final file = File(
      '${(await _ownerDirectory()).path}/${videoFileNameFor(message)}',
    );
    // Leased as soon as it exists, or before it does, so it is never pruned
    // on its way to the caller, who releases it.
    _lease(file);
    if (file.existsSync()) {
      await _markOpened(file);
      return file;
    }
    try {
      final plaintext = await _fetchVideo(
        message,
        maxBytes: maxBytes,
        timeLimit: timeLimit,
        limitsApply: limitsApply,
        stillWanted: stillWanted,
      );
      // Landed after every card let go of it: keep no plaintext.
      if (stillWanted != null && !stillWanted()) {
        throw const DmVideoWithdrawnException();
      }
      // Written first, so a video is never kept without it.
      await _writeAtomically(
        File(
          '${file.parent.path}/${_safeName(message.id)}$_conversationSuffix',
        ),
        utf8.encode('${message.conversationId}\n${message.createdAt}'),
      );
      await _writeAtomically(file, plaintext);
    } on Object {
      _release(file);
      rethrow;
    }
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
    required bool decode,
    required bool Function() wanted,
  }) async {
    final dir = await _ownerDirectory();
    final preview = File('${dir.path}/${_previewFileNameFor(message)}');
    if (preview.existsSync()) {
      await _markOpened(preview);
      _knownPreviews[message.id] = preview.path;
      return preview;
    }
    if (_unreadableFrames.contains(message.id) || !decode) return null;

    final keptVideo = File('${dir.path}/${videoFileNameFor(message)}');
    final declaredBytes = message.fileMetadata?.fileSize;
    final File video;
    if (keptVideo.existsSync()) {
      _lease(keptVideo);
      video = keptVideo;
    } else if (download &&
        _mayAutoDownload(message.id) &&
        (declaredBytes == null || declaredBytes <= autoDownloadMaxBytes)) {
      try {
        video = await _autoVideoFor(message, wanted: wanted);
      } on _DownloadDropped {
        return null;
      } on DmVideoWithdrawnException {
        // Stopped because no card wanted it: nothing to hold against the next.
        return null;
      } on Object catch (error) {
        final mayPass = error is DmVideoUnavailableException && error.mayPass;
        if (!mayPass) {
          // It would fail again, for whichever card asks next.
          _autoDownloadFailures[message.id] = null;
        } else if (wanted()) {
          _autoDownloadFailures[message.id] = _now().add(
            autoDownloadRetryAfter,
          );
        }
        // No card waits: no one to tell.
        if (!wanted()) return null;
        rethrow;
      }
    } else {
      return null;
    }

    try {
      // No card shows it: decode nothing.
      if (!wanted()) return null;
      final id = message.id;
      return await (_frameReadsInFlight[id] ??= _frameReads
          .run(() async {
            // Its turn can come long after the check above: a card closed or
            // a sender blocked meanwhile must not cost a decode.
            if (!_frameWanted(id)) return null;
            return _readAndKeepFrame(message, video, preview);
          })
          .whenComplete(
            () => _frameReadsInFlight.removeWhere((key, _) => key == id),
          ));
    } finally {
      _release(video);
    }
  }

  Future<File?> _readAndKeepFrame(
    DmMessage message,
    File video,
    File preview,
  ) async {
    final attempt = File(
      '${preview.parent.path}/${_safeName(message.id)}$_frameAttemptSuffix',
    );
    // Left by a read that never finished: it could crash the app again each
    // time the chat opens.
    if (attempt.existsSync()) {
      _unreadableFrames.add(message.id);
      return null;
    }
    _throwIfOwnerRemoved();
    try {
      attempt.createSync();
    } on FileSystemException catch (error) {
      throw DmVideoStorageException(
        'could not start reading the frame: ${_causeOf(error)}',
      );
    }
    final frame = await _readFrame(video);
    if (frame == null || frame.isEmpty) {
      // The mark stays: the reader gives up on its timeout while the native
      // decoder may run on, and a decode that never ends is not retried.
      _unreadableFrames.add(message.id);
      return null;
    }
    try {
      await _writeAtomically(preview, frame);
    } finally {
      _deleteNow(attempt);
    }
    _knownPreviews[message.id] = preview.path;
    return preview;
  }

  /// Ids of the messages behind [files] that are gone. A lookup that fails
  /// keeps its message's files.
  Future<Set<String>> _goneMessageIds(List<File> files) async {
    final isGone = _isMessageGone;
    final isRemoved = _isConversationRemoved;
    if (isGone == null && isRemoved == null) return const {};
    final ids = {for (final file in files) _messageIdOf(file)};
    final records = {
      for (final file in files)
        if (file.path.endsWith(_conversationSuffix)) _messageIdOf(file): file,
    };
    final gone = <String>{};
    for (final id in ids) {
      try {
        if (isGone != null && await isGone(id)) {
          gone.add(id);
          continue;
        }
        final record = records[id];
        if (isRemoved == null || record == null) continue;
        final lines = (await record.readAsString()).split('\n');
        final sentAt = lines.length == 2 ? int.tryParse(lines[1]) : null;
        if (sentAt != null && await isRemoved(lines[0], sentAt)) gone.add(id);
      } on Object catch (error) {
        Log.warning(
          'Could not tell whether a kept video DM message is gone: '
          '${error.runtimeType}',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }
    return gone;
  }

  /// The message id a kept file is named after: its name up to the first dot.
  static String _messageIdOf(File file) =>
      file.uri.pathSegments.last.split('.').first;

  bool _mayAutoDownload(String messageId) {
    if (!_autoDownloadFailures.containsKey(messageId)) return true;
    final retryAt = _autoDownloadFailures[messageId];
    return retryAt != null && !_now().isBefore(retryAt);
  }

  Future<Directory> _ownerDirectory() async {
    final root = await _rootDirectory();
    return Directory('${root.path}/$dirName/${_safeName(_ownerPubkey)}');
  }

  /// Writes [bytes] beside [file] and renames it into place, so a reader
  /// never sees half a video and a crash leaves only a part file to prune.
  Future<void> _writeAtomically(File file, Uint8List bytes) async {
    // Each write its own part file: two reads of the same frame can run at
    // once, and sharing one would make the second rename fail.
    final part = File('${file.path}.${_writes++}$_partSuffix');
    try {
      _throwIfOwnerRemoved();
      await part.parent.create(recursive: true);
      await part.writeAsBytes(bytes, flush: true);
      _throwIfOwnerRemoved();
      await part.rename(file.path);
    } on FileSystemException catch (error) {
      await _deleteQuietly(part);
      throw DmVideoStorageException(
        'could not store the file: ${_causeOf(error)}',
      );
    } catch (_) {
      await _deleteQuietly(part);
      rethrow;
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
  Future<void> _markOpened(File file) async {
    try {
      await file.setLastModified(_now());
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not mark a kept video DM file as opened: ${_causeOf(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  void _lease(File file) =>
      _leases.update(file.path, (count) => count + 1, ifAbsent: () => 1);

  void _release(File file) {
    final count = _leases[file.path];
    if (count == null) return;
    if (count > 1) {
      _leases[file.path] = count - 1;
      return;
    }
    _leases.remove(file.path);
    if (_goneWhileLeased.remove(file.path)) {
      runDetached(
        prune(),
        'prune a released kept video DM whose message is gone',
        logName: _logName,
        category: LogCategory.video,
      );
    }
  }

  bool _isInUse(File file) =>
      _handedOut.contains(file.path) || _leases.containsKey(file.path);

  /// Deletes [file] before anything else can run, and forgets it if it was a
  /// frame.
  void _deleteNow(File file) {
    try {
      file.deleteSync();
    } on PathNotFoundException {
      // Already gone, which is all prune wanted.
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not delete a kept video DM file: ${_causeOf(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
    _knownPreviews.removeWhere((_, path) => path == file.path);
  }

  /// What went wrong, without the path: file names carry the account's
  /// pubkey and the message id.
  static String _causeOf(FileSystemException error) =>
      error.osError?.toString() ?? 'no OS error';

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not delete a kept video DM file: ${_causeOf(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }
}

/// Thrown when a kept video or frame could not be written to the device.
/// Trying again later may work, once there is room; downloading the video
/// again at once would only fail the same way.
class DmVideoStorageException extends DmVideoUnavailableException {
  /// Creates a [DmVideoStorageException] with a diagnostic [message].
  const DmVideoStorageException(super.message) : super(mayPass: true);
}

/// A queued download no card wants any more when its turn comes.
class _DownloadDropped implements Exception {
  const _DownloadDropped();
}

/// Runs tasks one at a time, each once the one before it has settled.
class _OneAtATime {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() task) {
    final turn = _tail.then((_) => task());
    // The next task waits for this one to settle, failed or not.
    _tail = turn.then<void>((_) {}, onError: (Object _) {});
    return turn;
  }
}
