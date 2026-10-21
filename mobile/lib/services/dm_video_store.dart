// ABOUTME: Keeps received video DMs on this device, decrypted, for one account:
// ABOUTME: one download per video, a preview frame, and pruning by age and size.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_files.dart';
import 'package:openvine/services/dm_video_frame_read_marks.dart';
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
/// Completes only once the decoder no longer reads the file, not on a UI
/// timeout: the store leases the file until completion, and holds the frame
/// queue until then or for at most [DmVideoStore.frameTurnLimit].
typedef DmVideoFrameReader = Future<Uint8List?> Function(File video);

/// Current conversation metadata for a message whose row is still available.
typedef DmVideoMessageLocation = ({String conversationId, int sentAt});

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
/// A file is deleted [maxAge] after it was kept, however often it is opened
/// since, and past [maxBytes] the oldest go first, videos before frames; a
/// frame counts as kept when its video was. Everything kept for a message
/// that is gone (see `isMessageGone`) goes at the next [prune]. An account's
/// folder goes when the account leaves this device ([deleteOwner],
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
  /// [findMessageLocation], when supplied, refreshes that record from a live
  /// row after conversation repair; a missing row still uses the kept record.
  ///
  /// [readFrame] defaults to [readDmVideoCardFrame] without its own timeout:
  /// the store bounds the UI wait separately from native completion.
  /// [rootDirectory] defaults to the app's cache directory, [now] to the
  /// wall clock and [launchId], which each frame read's mark names, to this
  /// launch of the app's; they exist so tests can inject fakes, such as a
  /// store of an earlier launch.
  DmVideoStore({
    required String ownerPubkey,
    required DmVideoFetcher fetchVideo,
    DmVideoFrameReader? readFrame,
    Future<bool> Function(String messageId)? isMessageGone,
    Future<bool> Function(String conversationId, int sentAt)?
    isConversationRemoved,
    Future<DmVideoMessageLocation?> Function(String messageId)?
    findMessageLocation,
    Future<Directory> Function()? rootDirectory,
    DateTime Function()? now,
    this.maxAge = defaultMaxAge,
    this.maxBytes = defaultMaxBytes,
    this.frameTurnLimit = defaultFrameTurnLimit,
    this.frameDeadline = defaultFrameDeadline,
    String? launchId,
  }) : _ownerPubkey = ownerPubkey,
       _launchId = launchId,
       _removalsAtCreation = _removals[dmVideoSafeName(ownerPubkey)] ?? 0,
       _fetchVideo = fetchVideo,
       _readFrame = readFrame ?? _readCardFrameUntilSettled,
       _isMessageGone = isMessageGone,
       _isConversationRemoved = isConversationRemoved,
       _findMessageLocation = findMessageLocation,
       _rootDirectory = rootDirectory ?? getApplicationCacheDirectory,
       _now = now ?? DateTime.now {
    _stores.removeWhere((entry) => entry.target == null);
    _stores.add(WeakReference(this));
  }

  /// Folder under the cache directory that holds every account's videos.
  static const String dirName = 'dm_videos';

  /// How long after it was kept [prune] deletes a file, however often it was
  /// opened: a copy kept here no longer asks the media server, so a takedown
  /// there does not reach it before then.
  static const Duration defaultMaxAge = Duration(days: 30);

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

  /// How many downloads nobody tapped for may fail for one message before
  /// the store stops fetching it by itself for the session: each try tells
  /// the sender's media server that the thread is open. A tap on play still
  /// fetches it.
  static const int autoDownloadMaxTries = 3;

  /// Longest a frame read keeps the decoder from the next one. A decode that
  /// outlasts it keeps its video leased until it returns, but the next read
  /// starts beside it: a native call that never replies must not leave
  /// every other card on its fallback until the store is rebuilt.
  static const Duration defaultFrameTurnLimit = Duration(seconds: 60);

  /// How long a card waits for its frame by default; see [frameDeadline].
  static const Duration defaultFrameDeadline = dmVideoPreviewTimeout;

  static const String _partSuffix = '.part';
  static const String _legacyPlaybackDirName = 'dm_video_playback';

  /// Beside a kept video and its frame for as long as either stays: the
  /// conversation they came from and when the message was sent, so removing
  /// that conversation deletes them even once the message row is gone.
  static const String _conversationSuffix = '.conversation';

  /// Left for a message whose download failed in a way that would repeat, so
  /// no later session fetches it by itself either. Empty; it goes with its
  /// message, or [maxAge] after it was left, and is never trimmed for the
  /// cap.
  static const String _failedSuffix = '.failed';

  /// Age past which a part file is taken as left by a crash: a younger one
  /// may still be being written, by this store or by the one an account
  /// switch replaced.
  static const Duration _crashedPartAge = Duration(hours: 1);

  /// How many times each account's videos were deleted by [deleteOwner]. A
  /// store remembers the count it was created at, so a download that lands
  /// after its account was removed cannot write the video back.
  static final Map<String, int> _removals = {};

  /// Every store still reachable, so [sweepOwners] leaves alone what any of
  /// them leased or handed out. Weak, so the list keeps no store alive.
  static final List<WeakReference<DmVideoStore>> _stores = [];
  static const String _logName = 'DmVideoStore';

  static Future<Uint8List?> _readCardFrameUntilSettled(File video) =>
      readDmVideoCardFrame(video, timeout: null);

  /// How long after it was kept [prune] deletes a file.
  final Duration maxAge;

  /// Upper bound, in bytes, on this account's kept files.
  final int maxBytes;

  /// How long a frame read may keep the decoder; see
  /// [defaultFrameTurnLimit].
  final Duration frameTurnLimit;

  /// How long a card waits for its frame once its decode starts. The
  /// decode runs on past it; a frame that arrives later is still kept.
  final Duration frameDeadline;

  final String _ownerPubkey;
  final String? _launchId;
  final int _removalsAtCreation;
  final DmVideoFetcher _fetchVideo;
  final DmVideoFrameReader _readFrame;
  final Future<bool> Function(String messageId)? _isMessageGone;
  final Future<bool> Function(String conversationId, int sentAt)?
  _isConversationRemoved;
  final Future<DmVideoMessageLocation?> Function(String messageId)?
  _findMessageLocation;
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

  /// Files of gone messages a prune left because they were leased, deleted
  /// with the rest of their message's files once their last lease is
  /// released.
  final Set<String> _goneWhileLeased = {};

  /// The prune under way, if any, and whether one was asked for meanwhile.
  Future<void>? _pruning;
  bool _pruneAgain = false;

  /// Downloads without a tap on play run one at a time: each holds a whole
  /// video in memory, and a long thread shows many at once.
  final _OneAtATime _autoDownloads = _OneAtATime();

  /// Frame reads run one at a time too: a crash then marks only the video
  /// being read, and a long thread does not start a native decoder per card.
  /// The getThumbnails call used here has no confirmed cancellation: a read
  /// that never replies holds this turn for [frameTurnLimit], then the next
  /// read starts beside it, while its file stays leased until it replies.
  final _OneAtATime _frameReads = _OneAtATime();
  final Map<String, Future<File?>> _previewsInFlight = {};

  /// Frame reads by message id, shared by every caller asking at once. The
  /// UI deadline starts at the turn, not while a visible card is queued.
  final Map<String, ({Future<void> started, Future<File?> settled})>
  _frameReadsInFlight = {};

  /// Whether each caller waiting on a frame still wants it, by message id.
  final Map<String, List<bool Function()>> _previewWanters = {};

  /// Paths of the frames this store read or found, by message id.
  final Map<String, String> _knownPreviews = {};

  /// What each message's conversation record says, by message id, once this
  /// store wrote it or found it current.
  final Map<String, String> _currentRecords = {};

  /// Ids of messages whose frame could not be read this session. The mark
  /// beside the video keeps the read from being tried in later sessions too.
  final Set<String> _unreadableFrames = {};

  /// Downloads nobody tapped for that failed, by message id, with when a card
  /// may fetch it again by itself, or null when it may not this session.
  final Map<String, DateTime?> _autoDownloadFailures = {};

  /// How many downloads nobody tapped for failed this session, by message id.
  final Map<String, int> _autoDownloadFailureCounts = {};

  /// Marks around each frame read, so a decode that crashed the app is not
  /// tried again: nothing of a sender one of whose reads an earlier launch
  /// never finished is fetched or read by itself until their mark is
  /// [maxAge] old. A tap still plays their videos.
  late final DmVideoFrameReadMarks _frameReadMarks = DmVideoFrameReadMarks(
    ownerRemoved: () => _ownerRemoved,
    launchId: _launchId,
  );
  // An account switch can leave a tapped download running in an older store.
  // Number writes across stores so their sibling part files cannot collide.
  static int _writes = 0;
  final StreamController<String> _kept = StreamController<String>.broadcast();

  /// Ids of messages whose video or late preview frame was just kept, so a
  /// waiting card can pick it up without another download or decode.
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
    return '${dmVideoSafeName(message.id)}.$extension';
  }

  static String _previewFileNameFor(DmMessage message) =>
      '${dmVideoSafeName(message.id)}$_previewSuffix';

  static const String _previewSuffix = '.preview.jpg';

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
  /// Downloads and decodes without a tap on play, so it is asked only for a
  /// sender the user trusts. A video not kept yet is fetched in turn with
  /// other such downloads, within [autoDownloadMaxBytes] and
  /// [autoDownloadTimeLimit]; one declared bigger is not fetched. Null when
  /// there is no video to read or no frame can be read from it; a frame that
  /// could not be read, or whose read never finished, is not tried again.
  /// Null too when the decode outlasts [frameDeadline]; its frame is still
  /// kept, and announced on [kept]. A download that failed in a way that
  /// would repeat is not tried again by itself, this session or a later one,
  /// until [maxAge] has passed; one that may pass is tried again after
  /// [autoDownloadRetryAfter], and at most [autoDownloadMaxTries] times a
  /// session. A tap on play still fetches it. Nothing is fetched or read by
  /// itself for a sender one of whose frame reads an earlier launch never
  /// finished with the app in the foreground, until that is [maxAge] old; a
  /// tap still plays their videos.
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
    bool Function()? stillWanted,
  }) {
    final id = message.id;
    (_previewWanters[id] ??= []).add(stillWanted ?? _alwaysWanted);
    return _previewsInFlight[id] ??=
        _obtainPreview(
          message,
          wanted: () => _previewWanters[id]?.any((wanted) => wanted()) ?? false,
        ).whenComplete(() {
          _previewsInFlight.removeWhere((pending, _) => pending == id);
          _previewWanters.removeWhere((pending, _) => pending == id);
        });
  }

  static bool _alwaysWanted() => true;

  /// The path of [message]'s frame when this store already read or found it,
  /// so a card built again shows it at once. Null once the file is gone: the
  /// system can clear the cache directory while the app runs.
  String? knownPreviewPathFor(DmMessage message) {
    final path = _knownPreviews[message.id];
    if (path == null || File(path).existsSync()) return path;
    _knownPreviews.remove(message.id);
    return null;
  }

  /// Whether the app is in the foreground, as its provider reports. While it
  /// is not, frame reads under way leave their marks empty: the system kills
  /// apps in the background, and that must not count as a decode crashing
  /// the app, nor blame the video's sender.
  bool get appInForeground => _frameReadMarks.appInForeground;

  set appInForeground(bool inForeground) =>
      _frameReadMarks.appInForeground = inForeground;

  /// Deletes files kept more than [maxAge] ago, then, until this account's
  /// files fit in [maxBytes], the oldest videos and, only after every video,
  /// frames: a frame is what a card shows, and costs little.
  ///
  /// Everything kept for a message that is gone is deleted too, even a video
  /// played this session: a video retracted by its sender or removed with its
  /// conversation goes at the next prune or, while a read or a hand-out of it
  /// is under way, once that ends. Sign-out and an account switch prune
  /// before they clear the account's rows; a message that goes while another
  /// account is signed in is found once this one signs in again, or its
  /// files reach [maxAge].
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
            'Could not prune kept video DMs: ${dmVideoFileErrorCause(error)}',
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
    // Before a gone message's frame-read mark can be deleted unread.
    _frameReadMarks.lookForUnfinishedReads(dir);
    if (!dir.existsSync()) return;
    final gone = await _goneMessageIds(
      await dir.list().where((entity) => entity is File).cast<File>().toList(),
    );
    // Listed again where nothing awaits: a frame written during the lookups
    // is seen too, and no file can be handed out between the check that it
    // is free and its deletion.
    if (!dir.existsSync()) return;
    final files = dir.listSync().whereType<File>().toList();
    final leased = {for (final path in _leases.keys) _messageIdOf(File(path))};
    final now = _now();
    final kept = <({File file, DateTime keptAt, int size})>[];
    for (final file in files) {
      final stat = file.statSync();
      if (stat.type == FileSystemEntityType.notFound) continue;
      final age = now.difference(stat.modified);
      final id = _messageIdOf(file);
      // Even a video played this session goes: its sender took it back, or
      // the user removed it. Only a read or a hand-out under way holds it,
      // and its release deletes what is kept for the message; the record and
      // mark stay with it meanwhile, so a later launch can still tell if the
      // read never ends. A part file goes however young, as its write is no
      // longer wanted.
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
      // Decided below, once age and the cap have deleted what they will.
      if (_isSatellite(file)) continue;
      if (age > maxAge && !_isInUse(file)) {
        _deleteNow(file);
        continue;
      }
      // Empty, so trimming it would free nothing.
      if (_isMark(file)) continue;
      kept.add((file: file, keptAt: stat.modified, size: stat.size));
    }
    _trimToCap(kept);
    _deleteOrphanedSatellites(dir, leased);
  }

  /// Deletes the oldest of [kept] until what is not in use fits in
  /// [maxBytes], videos before frames.
  void _trimToCap(List<({File file, DateTime keptAt, int size})> kept) {
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
      return a.keptAt.compareTo(b.keptAt);
    });
    for (final entry in trimmable) {
      if (total <= maxBytes) break;
      _deleteNow(entry.file);
      total -= entry.size;
    }
  }

  /// Deletes, from what [dir] holds now, frame-read marks whose video is gone
  /// and records whose message has nothing left and is not [leased], so they
  /// go in the same prune as the files they describe.
  void _deleteOrphanedSatellites(Directory dir, Set<String> leased) {
    final files = dir.listSync().whereType<File>().toList();
    final withVideo = _messageIdsWithVideo(files);
    final withContent = _messageIdsWithContent(files);
    for (final file in files) {
      final id = _messageIdOf(file);
      if (DmVideoFrameReadMarks.isReadMark(file) && !withVideo.contains(id) ||
          file.path.endsWith(_conversationSuffix) &&
              !withContent.contains(id) &&
              !leased.contains(id)) {
        _deleteNow(file);
      }
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
    if (kIsWeb) return;
    final owner = dmVideoSafeName(ownerPubkey);
    _removals.update(owner, (count) => count + 1, ifAbsent: () => 1);
    final root = await (rootDirectory ?? getApplicationCacheDirectory)();
    final dir = Directory('${root.path}/$dirName/$owner');
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } on FileSystemException catch (error) {
      throw DmVideoUnavailableException(
        'could not delete the kept videos: ${dmVideoFileErrorCause(error)}',
      );
    }
  }

  /// Deletes the videos kept for every account not in [keepOwnerPubkeys],
  /// and in the kept accounts' folders whatever was kept more than [maxAge] ago
  /// and part files a crash left. Returns how many accounts' videos it
  /// deleted. A folder that cannot be read or deleted is logged, without its
  /// path, and left for the next sweep; the others are still swept.
  ///
  /// Runs at launch for every account, so an account the user switched away
  /// from does not keep its videos past [maxAge]: its store prunes only
  /// while it is the signed-in one. In a kept account's folder it leaves
  /// alone what a live store leased or handed out; the folder of an account
  /// not in [keepOwnerPubkeys] goes whole.
  static Future<int> sweepOwners(
    Set<String> keepOwnerPubkeys, {
    Future<Directory> Function()? rootDirectory,
    DateTime Function()? now,
    Duration maxAge = defaultMaxAge,
  }) async {
    if (kIsWeb) return 0;
    final root = await (rootDirectory ?? getApplicationCacheDirectory)();
    final dir = Directory('${root.path}/$dirName');
    if (!dir.existsSync()) return 0;
    final keep = keepOwnerPubkeys.map(dmVideoSafeName).toSet();
    final currentTime = (now ?? DateTime.now)();
    var deleted = 0;
    try {
      await for (final entity in dir.list()) {
        if (entity is! Directory) continue;
        try {
          final owner = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
          if (keep.contains(owner)) {
            await _deleteExpiredFiles(entity, currentTime, maxAge);
            continue;
          }
          await entity.delete(recursive: true);
          deleted++;
        } on FileSystemException catch (error) {
          Log.warning(
            "Could not sweep one account's kept video DMs: "
            '${dmVideoFileErrorCause(error)}',
            name: _logName,
            category: LogCategory.video,
          );
        }
      }
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not sweep kept video DMs: ${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
    return deleted;
  }

  /// Removes plaintext playback files that earlier versions left behind if
  /// the app exited before playback cleanup. The old playback path no longer
  /// exists, so nothing in this version reads or writes that legacy folder.
  /// Native-only and best effort; no path is included in diagnostics.
  static Future<void> deleteLegacyPlaybackClips({
    Future<Directory> Function()? temporaryDirectory,
  }) async {
    if (kIsWeb) return;
    try {
      final root = await (temporaryDirectory ?? getTemporaryDirectory)();
      final legacy = Directory('${root.path}/$_legacyPlaybackDirName');
      if (legacy.existsSync()) await legacy.delete(recursive: true);
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not remove obsolete decrypted playback clips: '
        '${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    } on MissingPlatformDirectoryException {
      Log.warning(
        'Could not locate the temporary directory for obsolete playback clips',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// Deletes files in [dir] kept more than [maxAge] ago, and part files older
  /// than [_crashedPartAge]: a younger one may be a download the signed-in
  /// account's store is still writing.
  static Future<void> _deleteExpiredFiles(
    Directory dir,
    DateTime now,
    Duration maxAge,
  ) async {
    Future<List<File>> listFiles() =>
        dir.list().where((entity) => entity is File).cast<File>().toList();
    for (final file in await listFiles()) {
      if (_isSatellite(file)) continue;
      final age = now.difference(file.statSync().modified);
      final isPart = file.path.endsWith(_partSuffix);
      if (age > maxAge || (isPart && age > _crashedPartAge)) {
        _deleteUnusedByStores(file);
      }
    }
    // After the files they describe, so marks and records go in the same
    // sweep as the last of those.
    final files = await listFiles();
    final withVideo = _messageIdsWithVideo(files);
    final withContent = _messageIdsWithContent(files);
    for (final file in files) {
      final id = _messageIdOf(file);
      if (DmVideoFrameReadMarks.isReadMark(file) && !withVideo.contains(id) ||
          file.path.endsWith(_conversationSuffix) &&
              !withContent.contains(id)) {
        _deleteUnusedByStores(file);
      }
    }
  }

  /// Ids of the messages whose video is among [files].
  static Set<String> _messageIdsWithVideo(List<File> files) => {
    for (final file in files)
      if (!file.path.endsWith(_partSuffix) &&
          !file.path.endsWith(_previewSuffix) &&
          !_isMark(file) &&
          !_isSatellite(file))
        _messageIdOf(file),
  };

  /// Ids of the messages with a video, a frame or a mark among [files], whole
  /// or still being written: a removal must still find them.
  /// A record still being written counts too, which only keeps its message's
  /// record until the part goes.
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
      DmVideoFrameReadMarks.isReadMark(file) ||
      file.path.endsWith(_conversationSuffix);

  /// Whether [file] is an empty mark, of a failed download or of a sender
  /// whose frame read never finished: it ages, but is never trimmed.
  static bool _isMark(File file) =>
      file.path.endsWith(_failedSuffix) ||
      DmVideoFrameReadMarks.isSenderMark(file);

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
      await _recordConversationQuietly(message, file.parent);
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
      await _recordConversation(message, file.parent, force: true);
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
    required bool Function() wanted,
  }) async {
    final dir = await _ownerDirectory();
    _frameReadMarks.lookForUnfinishedReads(dir);
    final preview = File('${dir.path}/${_previewFileNameFor(message)}');
    if (preview.existsSync()) {
      await _recordConversationQuietly(message, dir);
      _knownPreviews[message.id] = preview.path;
      return preview;
    }
    if (_unreadableFrames.contains(message.id) ||
        _frameReadMarks.senderHungTheDecoder(dir, message.senderPubkey)) {
      return null;
    }

    final keptVideo = File('${dir.path}/${videoFileNameFor(message)}');
    final declaredBytes = message.fileMetadata?.fileSize;
    final File video;
    if (keptVideo.existsSync()) {
      _lease(keptVideo);
      video = keptVideo;
      await _recordConversationQuietly(message, dir);
    } else if (_mayAutoDownload(dir, message.id) &&
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
        final failures = _autoDownloadFailureCounts.update(
          message.id,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        if (!mayPass) {
          // It would fail again, for whichever card asks next, in this
          // session or a later one.
          _autoDownloadFailures[message.id] = null;
          await _rememberLastingFailure(dir, message);
        } else if (failures >= autoDownloadMaxTries) {
          // Each try tells the sender's server that the thread is open.
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
      final read = _frameReadsInFlight.putIfAbsent(
        id,
        () => _queueFrameRead(message, video, preview, wanted),
      );
      // Interest holds while queued: the card's deadline bounds its wait for
      // its own decode, not its place behind other native reads.
      await Future.any<void>([read.started, read.settled.then<void>((_) {})]);
      return await read.settled.timeout(
        frameDeadline,
        onTimeout: () => null,
      );
    } finally {
      _release(video);
    }
  }

  ({Future<void> started, Future<File?> settled}) _queueFrameRead(
    DmMessage message,
    File video,
    File preview,
    bool Function() wanted,
  ) {
    final started = Completer<void>();
    final read = Completer<File?>();
    final id = message.id;
    unawaited(
      _frameReads.run(() async {
        started.complete();
        // A card closed, or held back since, must not cost a decode.
        if (!wanted()) {
          read.complete();
          return;
        }
        // The lease outlives a card's UI deadline and the turn: it ends only
        // when the decoder is done with the file.
        _lease(video);
        final decoding = _readAndKeepFrame(
          message,
          video,
          preview,
        ).whenComplete(() => _release(video));
        read.complete(decoding);
        await decoding
            .then<void>((_) {}, onError: (Object _) {})
            .timeout(
              frameTurnLimit,
              onTimeout: () => Log.warning(
                'A video DM frame decode still ran '
                '${frameTurnLimit.inSeconds} s after it started; the next '
                'frame read no longer waits for it',
                name: _logName,
                category: LogCategory.video,
              ),
            );
      }),
    );
    final settled = read.future.whenComplete(
      () => _frameReadsInFlight.removeWhere((key, _) => key == id),
    );
    return (started: started.future, settled: settled);
  }

  /// Writes [message]'s conversation record in [dir], unless this store knows
  /// it already says the same or, without [force], finds that it does: a
  /// repair can move a message to another conversation after its video was
  /// kept, and a removal must still find the video.
  ///
  /// Throws a [DmVideoStorageException] when the record cannot be written.
  Future<void> _recordConversation(
    DmMessage message,
    Directory dir, {
    bool force = false,
  }) async {
    final content = _conversationRecordContent(
      message.conversationId,
      message.createdAt,
    );
    final record = File(
      '${dir.path}/${dmVideoSafeName(message.id)}$_conversationSuffix',
    );
    // What this store wrote can still be deleted from outside it: the launch
    // sweep, or the system clearing the cache folder.
    final known = _currentRecords[message.id] == content && record.existsSync();
    if (force || (!known && await _readQuietly(record) != content)) {
      await _writeAtomically(record, utf8.encode(content));
    }
    _currentRecords[message.id] = content;
  }

  /// [_recordConversation], logging rather than throwing: a video or frame
  /// already kept is still handed out when its record cannot be written.
  Future<void> _recordConversationQuietly(
    DmMessage message,
    Directory dir,
  ) async {
    try {
      await _recordConversation(message, dir);
    } on DmVideoUnavailableException catch (error) {
      Log.warning(
        "Could not record a kept video DM's conversation: ${error.message}",
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  static Future<String?> _readQuietly(File file) async {
    try {
      return await file.readAsString();
    } on FileSystemException {
      return null;
    }
  }

  static String _conversationRecordContent(String conversationId, int sentAt) =>
      '$conversationId\n$sentAt';

  Future<File?> _readAndKeepFrame(
    DmMessage message,
    File video,
    File preview,
  ) async {
    final mark = DmVideoFrameReadMarks.readMarkOf(preview.parent, message.id);
    // Left by a read that never finished: it could crash the app again each
    // time the chat opens.
    if (mark.existsSync()) {
      _unreadableFrames.add(message.id);
      return null;
    }
    _throwIfOwnerRemoved();
    try {
      _frameReadMarks.readStarted(mark, message.senderPubkey);
    } on FileSystemException catch (error) {
      throw DmVideoStorageException(
        'could not start reading the frame: ${dmVideoFileErrorCause(error)}',
      );
    }
    final videoStat = video.statSync();
    Uint8List? frame;
    try {
      frame = await _readFrame(video);
    } finally {
      // The mark stays when the decoder cannot produce a frame, emptied as
      // the read ended. A decode that never settles leaves it naming the
      // launch and the sender, even across an app restart.
      if (frame == null || frame.isEmpty) _frameReadMarks.readEnded(mark);
    }
    if (frame == null || frame.isEmpty) {
      _unreadableFrames.add(message.id);
      return null;
    }
    try {
      await _writeAtomically(preview, frame);
    } finally {
      _frameReadMarks.frameKept(mark);
    }
    if (videoStat.type != FileSystemEntityType.notFound) {
      await _dateLikeItsVideo(preview, videoStat.modified);
    }
    _knownPreviews[message.id] = preview.path;
    // A card may have reached its UI deadline and now waits on this stream.
    // Its late native reply still supplies a frame without another decode.
    if (!_kept.isClosed) _kept.add(message.id);
    return preview;
  }

  /// Ids of the messages behind [files] that are gone. A lookup that fails
  /// keeps its message's files. On the way, the record of a message a repair
  /// moved to another conversation is rewritten to say where it is now.
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
        if (isRemoved == null) continue;
        final current = await _findMessageLocation?.call(id);
        if (current != null) {
          if (await isRemoved(current.conversationId, current.sentAt)) {
            gone.add(id);
          } else {
            // A group repair may have moved this message since it was kept.
            // Refresh the durable record before a later account switch drops
            // its row. Check disk, not just this store's metadata cache:
            // another same-account store can write the same record.
            final record =
                records[id] ??
                File('${files.first.parent.path}/$id$_conversationSuffix');
            final content = _conversationRecordContent(
              current.conversationId,
              current.sentAt,
            );
            if (await _readQuietly(record) != content) {
              try {
                await _writeAtomically(record, utf8.encode(content));
              } on DmVideoUnavailableException catch (error) {
                // The message is not gone; only its record is out of date.
                Log.warning(
                  'Could not refresh a kept video DM conversation record: '
                  '${error.message}',
                  name: _logName,
                  category: LogCategory.video,
                );
                continue;
              }
            }
            _currentRecords[id] = content;
          }
          continue;
        }
        final record = records[id];
        if (record == null) continue;
        final lines = (await record.readAsString()).split('\n');
        final sentAt = lines.length == 2 ? int.tryParse(lines[1]) : null;
        if (sentAt != null && await isRemoved(lines[0], sentAt)) gone.add(id);
      } on PathNotFoundException {
        // Deleted since the listing, as the launch sweep deletes an expired
        // video's files: there is nothing left to decide.
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

  bool _mayAutoDownload(Directory dir, String messageId) {
    if (!_autoDownloadFailures.containsKey(messageId)) {
      if (!_failureMarkOf(dir, messageId).existsSync()) return true;
      // An earlier session's download failed in a way that would repeat.
      _autoDownloadFailures[messageId] = null;
      return false;
    }
    final retryAt = _autoDownloadFailures[messageId];
    return retryAt != null && !_now().isBefore(retryAt);
  }

  static File _failureMarkOf(Directory dir, String messageId) =>
      File('${dir.path}/${dmVideoSafeName(messageId)}$_failedSuffix');

  /// Leaves the mark that keeps later sessions from fetching [message]'s
  /// video by themselves: its download failed in a way that would repeat.
  Future<void> _rememberLastingFailure(Directory dir, DmMessage message) async {
    // Writing it would bring a removed account's folder back.
    if (_ownerRemoved) return;
    final mark = _failureMarkOf(dir, message.id);
    try {
      await mark.create(recursive: true);
      // Removed while it was written: keep nothing for that account.
      if (_ownerRemoved) await _deleteQuietly(mark);
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not remember a failed video DM download: '
        '${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  Future<Directory> _ownerDirectory() async {
    final root = await _rootDirectory();
    return Directory('${root.path}/$dirName/${dmVideoSafeName(_ownerPubkey)}');
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
        'could not store the file: ${dmVideoFileErrorCause(error)}',
      );
    } catch (_) {
      await _deleteQuietly(part);
      rethrow;
    }
  }

  bool get _ownerRemoved =>
      (_removals[dmVideoSafeName(_ownerPubkey)] ?? 0) != _removalsAtCreation;

  void _throwIfOwnerRemoved() {
    if (_ownerRemoved) {
      throw const DmVideoUnavailableException(
        'the account was removed from this device',
      );
    }
  }

  /// Dates [frame] [keptAt], when its video was kept, so [prune] deletes it
  /// with that video however much later it was read.
  Future<void> _dateLikeItsVideo(File frame, DateTime keptAt) async {
    try {
      await frame.setLastModified(keptAt);
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not date a kept video DM frame like its video: '
        '${dmVideoFileErrorCause(error)}',
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
      _deleteKeptForGoneMessage(file);
      runDetached(
        prune(),
        'prune a released kept video DM whose message is gone',
        logName: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// Deletes everything kept for [file]'s message, which a prune found gone
  /// while it was held. Not asked again: the rows that said so may be cleared
  /// by now, as an account switch does.
  void _deleteKeptForGoneMessage(File file) {
    final id = _messageIdOf(file);
    final List<File> files;
    try {
      files = file.parent.listSync().whereType<File>().toList();
    } on FileSystemException catch (error) {
      Log.warning(
        "Could not delete a gone video DM message's files: "
        '${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
      return;
    }
    for (final kept in files) {
      if (_messageIdOf(kept) == id && !_leases.containsKey(kept.path)) {
        _deleteNow(kept);
      }
    }
  }

  bool _isInUse(File file) =>
      _handedOut.contains(file.path) || _leases.containsKey(file.path);

  static bool _usedDuringSweep(File file) {
    _stores.removeWhere((entry) => entry.target == null);
    for (final entry in _stores) {
      final store = entry.target;
      if (store == null) continue;
      if (store._leases.containsKey(file.path) ||
          (!store._kept.isClosed && store._handedOut.contains(file.path))) {
        return true;
      }
      if (_isSatellite(file) || file.path.endsWith(_partSuffix)) {
        final id = _messageIdOf(file);
        for (final path in store._leases.keys) {
          final leased = File(path);
          if (leased.parent.path == file.parent.path &&
              _messageIdOf(leased) == id) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static void _deleteUnusedByStores(File file) {
    // No suspension between checking the live leases and deleting: a native
    // read cannot acquire its lease in the middle of an asynchronous unlink.
    if (_usedDuringSweep(file)) return;
    try {
      file.deleteSync();
    } on PathNotFoundException {
      // Another cleanup already removed it.
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not expire a kept video DM file: '
        '${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// Deletes [file] before anything else can run, and forgets it if it was a
  /// frame.
  void _deleteNow(File file) {
    try {
      file.deleteSync();
    } on PathNotFoundException {
      // Already gone, which is all prune wanted.
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not delete a kept video DM file: '
        '${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
    _knownPreviews.removeWhere((_, path) => path == file.path);
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not delete a kept video DM file: '
        '${dmVideoFileErrorCause(error)}',
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
