// ABOUTME: Per-account, in-memory owner of outgoing video DMs: queues sends,
// ABOUTME: runs them one at a time, and publishes their phase and progress.

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:models/models.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/dm_clip_tag.dart';
import 'package:openvine/models/outgoing_video_dm.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_preview.dart';
import 'package:openvine/services/dm_video_send_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:uuid/uuid.dart';

export 'package:openvine/models/outgoing_video_dm.dart';

/// Maps a picked file's extension to the plaintext MIME type recorded in the
/// kind 15 metadata, through [dmVideoMimeTypesByExtension]. Defaults to
/// `video/mp4`, the format Divine itself sends.
String videoDmMimeTypeFor(String path) {
  final extension = path.split('.').last.toLowerCase();
  return dmVideoMimeTypesByExtension[extension] ?? 'video/mp4';
}

/// Whether the file at `path` is the exact file of a published Vine post.
///
/// Throws when that cannot be told.
typedef ArchivedVineCheck = Future<bool> Function(String path);

/// Reads the JPEG card frame shown on a video bubble, or null when it cannot
/// be read.
typedef DmVideoCardFrameReader = Future<Uint8List?> Function(File video);

/// A send the pipeline refused or could not complete, carrying the
/// repository's diagnostic reason for logs. Never shown to the user.
class VideoDmSendFailure implements Exception {
  /// Creates a [VideoDmSendFailure] with a diagnostic [reason].
  const VideoDmSendFailure(this.reason);

  /// Diagnostic text from the send result.
  final String reason;

  @override
  String toString() => 'VideoDmSendFailure: $reason';
}

/// One unit of work for the outbox worker.
sealed class _OutboxJob {
  const _OutboxJob();
}

/// Sends one gallery video.
class _VideoJob extends _OutboxJob {
  const _VideoJob(this.id);

  final String id;
}

/// Checks the clips of one batch, then sends them in order. A retried clip
/// runs as a batch of one.
class _ClipBatchJob extends _OutboxJob {
  const _ClipBatchJob(this.ids);

  final List<String> ids;
}

/// Owns the outgoing video DMs of one account, so a send keeps going and
/// keeps reporting progress after the user leaves the chat.
///
/// Requests are queued synchronously and run one at a time, first in first
/// out. Each job reads the send service and clip verifier when it starts, so
/// a job keeps the instances it started with. Nothing is persisted: [dispose]
/// drops every entry, and a send already in flight finishes unobserved.
class VideoDmOutbox {
  /// Creates a [VideoDmOutbox].
  ///
  /// [sendService] is read when each job starts. [readFrame] reads a card
  /// frame when an entry is created; [newId] and [now] stamp new entries.
  ///
  /// [clipVerifier] is read when each clip check starts; the check runs when
  /// it returns a verifier. Without one the check is left to the recipient,
  /// whose own check is the one that decides whether the clip may enter their
  /// library.
  ///
  /// [signOwnRecordings] signs the sender's own recordings among the clips
  /// whose signing at record time failed, for example offline, so they can
  /// still be sent as clips. It runs before the check.
  ///
  /// [isArchivedVine] lets a clip with no credential through when it is an
  /// archived Vine, which the recipient adds too. Without it such a clip is
  /// held back like any other that fails the check.
  ///
  /// [reporter] receives the programming errors a send or a clip check
  /// throws. It defaults to the app-wide [detachedFailureReporter], read when
  /// each error is reported.
  VideoDmOutbox({
    required DmVideoSendService Function() sendService,
    DmVideoCardFrameReader readFrame = readDmVideoCardFrame,
    String Function()? newId,
    DateTime Function()? now,
    ClipProvenanceVerifier? Function()? clipVerifier,
    Future<void> Function(List<DivineVideoClip> clips)? signOwnRecordings,
    ArchivedVineCheck? isArchivedVine,
    CrashReporter? reporter,
  }) : _sendService = sendService,
       _readFrame = readFrame,
       _newId = newId ?? const Uuid().v4,
       _now = now ?? DateTime.now,
       _clipVerifier = clipVerifier,
       _signOwnRecordings = signOwnRecordings,
       _isArchivedVine = isArchivedVine,
       _reporter = reporter;

  static const _logName = 'VideoDmOutbox';

  final DmVideoSendService Function() _sendService;
  final DmVideoCardFrameReader _readFrame;
  final String Function() _newId;
  final DateTime Function() _now;
  final ClipProvenanceVerifier? Function()? _clipVerifier;
  final Future<void> Function(List<DivineVideoClip> clips)? _signOwnRecordings;
  final ArchivedVineCheck? _isArchivedVine;
  final CrashReporter? _reporter;

  final BehaviorSubject<List<OutgoingVideoDm>> _entries =
      BehaviorSubject<List<OutgoingVideoDm>>.seeded(const []);
  final StreamController<VideoDmSendOutcome> _outcomes =
      StreamController<VideoDmSendOutcome>.broadcast();
  final Queue<_OutboxJob> _queue = Queue<_OutboxJob>();
  bool _working = false;
  bool _disposed = false;

  /// The current entries of [conversationId], in request order. Emits the
  /// current list on listen, then on every change to that conversation.
  Stream<List<OutgoingVideoDm>> watchConversation(String conversationId) =>
      _entries.stream
          .map(
            (entries) => List<OutgoingVideoDm>.unmodifiable(
              entries.where((e) => e.conversationId == conversationId),
            ),
          )
          .distinct(const ListEquality<OutgoingVideoDm>().equals);

  /// One event per finished request. Broadcast, with no replay.
  Stream<VideoDmSendOutcome> get outcomes => _outcomes.stream;

  /// Queues [file] to be sent to [recipientPubkey] in [conversationId] as a
  /// NIP-17 kind 15 file message.
  ///
  /// Returns at once; the queued entry is published before it returns. Does
  /// nothing after [dispose].
  void sendVideo({
    required String conversationId,
    required String recipientPubkey,
    required File file,
  }) {
    if (_disposed) return;
    final entry = OutgoingVideoDm(
      id: _newId(),
      conversationId: conversationId,
      recipientPubkey: recipientPubkey,
      localPath: file.path,
      requestedAt: _now(),
    );
    _entries.add([..._entries.value, entry]);
    _queue.add(_VideoJob(entry.id));
    _readFrameFor(entry.id, file);
    _startWorker();
  }

  /// Queues [clips] to be sent to [recipientPubkey] in [conversationId], each
  /// as a kind 15 file message marked with a [DmClipTag], one after another.
  ///
  /// Every clip's C2PA credential is checked before the first upload, so a
  /// clip the recipient could not add to their library is never uploaded,
  /// and one failing clip keeps the whole batch from going out. A check that
  /// cannot run (no trust anchors, no C2PA on this platform) does not block
  /// the send, since the recipient checks again anyway. A send that fails
  /// stops the remaining clips, so the batch can end up partly sent; the
  /// batch's single [VideoDmSendOutcome] says how far it got.
  ///
  /// Returns at once; the queued entries are published before it returns.
  /// Does nothing when [clips] is empty or after [dispose].
  void sendClips({
    required String conversationId,
    required String recipientPubkey,
    required List<DivineVideoClip> clips,
  }) {
    if (_disposed || clips.isEmpty) return;
    final batchId = _newId();
    final requestedAt = _now();
    final batch = [
      for (final clip in clips)
        OutgoingVideoDm(
          id: _newId(),
          conversationId: conversationId,
          recipientPubkey: recipientPubkey,
          localPath: clip.video?.file?.path ?? '',
          clip: clip,
          batchId: batchId,
          requestedAt: requestedAt,
        ),
    ];
    _entries.add([..._entries.value, ...batch]);
    _queue.add(_ClipBatchJob([for (final entry in batch) entry.id]));
    for (final entry in batch) {
      final path = _clipPath(entry);
      if (path != null) _readFrameFor(entry.id, File(path));
    }
    _startWorker();
  }

  /// Queues failed entry [id] again, at the back of the queue, to redo its
  /// whole pipeline; a clip is checked again on its own first. Does nothing
  /// unless the entry exists and [OutgoingVideoDm.canRetry].
  void retry(String id) {
    if (_disposed) return;
    final entry = _entry(id);
    if (entry == null || !entry.canRetry) return;
    _update(
      id,
      (e) => e.copyWith(
        phase: OutgoingVideoDmPhase.queued,
        uploadProgress: () => null,
        failure: () => null,
        rumorEventId: () => null,
      ),
    );
    _queue.add(entry.clip == null ? _VideoJob(id) : _ClipBatchJob([id]));
    _startWorker();
  }

  /// Drops entry [id] when it has failed. Does nothing otherwise.
  void remove(String id) => _drop(id, OutgoingVideoDmPhase.failed);

  /// Drops entry [id] when it was sent, once its message row is on screen.
  /// Does nothing otherwise.
  void acknowledge(String id) => _drop(id, OutgoingVideoDmPhase.sent);

  /// Stops publishing, drops every entry, and ignores sends that finish
  /// afterwards. Safe to call more than once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _queue.clear();
    unawaited(_entries.close());
    unawaited(_outcomes.close());
  }

  void _readFrameFor(String id, File file) => runDetached(
    _attachFrame(id, file),
    'read a video DM card frame',
    logName: _logName,
    category: LogCategory.video,
    reporter: _reporter,
  );

  Future<void> _attachFrame(String id, File file) async {
    final frame = await _readFrame(file);
    if (frame == null) return;
    _update(id, (entry) => entry.copyWith(frame: () => frame));
  }

  void _startWorker() {
    if (_working) return;
    _working = true;
    runDetached(
      _drainQueue(),
      'run the video DM outbox',
      logName: _logName,
      category: LogCategory.video,
      reporter: _reporter,
    );
  }

  Future<void> _drainQueue() async {
    try {
      while (!_disposed && _queue.isNotEmpty) {
        switch (_queue.removeFirst()) {
          case _VideoJob(:final id):
            await _runVideo(id);
          case _ClipBatchJob(:final ids):
            await _runClipBatch(ids);
        }
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _runVideo(String id) async {
    final entry = _entry(id);
    if (entry == null) return;
    final failure = await _sendEntry(entry);
    _emitOutcome(
      _outcomeStatusFor(failure),
      sentCount: failure == null ? 1 : 0,
      total: 1,
    );
  }

  /// Checks the clips of [ids] as one batch, then sends them in order,
  /// stopping at the first that fails. Emits one outcome for the batch.
  Future<void> _runClipBatch(List<String> ids) async {
    final batch = ids.map(_entry).nonNulls.toList();
    if (batch.isEmpty) return;
    final total = batch.length;

    /// Fails every entry of the batch, [rejected] as clipNotVerified and
    /// the rest as failed.
    void failBatch([OutgoingVideoDm? rejected]) {
      for (final entry in batch) {
        _markFailed(
          entry.id,
          entry.id == rejected?.id
              ? OutgoingVideoDmFailure.clipNotVerified
              : OutgoingVideoDmFailure.failed,
        );
      }
    }

    final missing = batch.firstWhereOrNull((e) => _clipPath(e) == null);
    if (missing != null) {
      Log.warning(
        'Video DM clip batch not sent',
        name: _logName,
        category: LogCategory.video,
        error: VideoDmSendFailure('entry ${missing.id} has no video file'),
      );
      failBatch();
      _emitOutcome(VideoDmOutcomeStatus.failed, sentCount: 0, total: total);
      return;
    }

    final verifier = _clipVerifier?.call();
    if (verifier != null) {
      for (final entry in batch) {
        _setPhase(entry.id, OutgoingVideoDmPhase.checking);
      }
      final OutgoingVideoDm? rejected;
      try {
        rejected = await _firstRejectedClip(verifier, batch);
      } catch (error, stackTrace) {
        _logUnexpected(
          'Video DM clip batch ${batch.first.batchId} check',
          error,
          stackTrace,
          site: 'checkClipBatch',
        );
        failBatch();
        _emitOutcome(VideoDmOutcomeStatus.failed, sentCount: 0, total: total);
        return;
      }
      if (_disposed) return;
      if (rejected != null) {
        Log.warning(
          'Video DM ${rejected.id} failed its clip check; batch not sent',
          name: _logName,
          category: LogCategory.video,
        );
        failBatch(rejected);
        _emitOutcome(
          VideoDmOutcomeStatus.clipNotVerified,
          sentCount: 0,
          total: total,
        );
        return;
      }
      for (final entry in batch) {
        _setPhase(entry.id, OutgoingVideoDmPhase.queued);
      }
    }

    var sentCount = 0;
    for (final (index, entry) in batch.indexed) {
      if (_disposed) return;
      final failure = await _sendEntry(
        entry,
        extraTags: [DmClipTag.build(entry.clip!.targetAspectRatio)],
      );
      if (failure != null) {
        for (final rest in batch.skip(index + 1)) {
          _markFailed(rest.id, OutgoingVideoDmFailure.failed);
        }
        _emitOutcome(
          _outcomeStatusFor(failure),
          sentCount: sentCount,
          total: total,
        );
        return;
      }
      sentCount++;
    }
    _emitOutcome(VideoDmOutcomeStatus.sent, sentCount: sentCount, total: total);
  }

  /// Signs the batch's own recordings, then checks each clip in order and
  /// returns the first the recipient could not add, or null when none.
  Future<OutgoingVideoDm?> _firstRejectedClip(
    ClipProvenanceVerifier verifier,
    List<OutgoingVideoDm> batch,
  ) async {
    await _signOwnRecordings?.call([for (final entry in batch) entry.clip!]);
    for (final entry in batch) {
      final path = _clipPath(entry)!;
      final provenance = await verifier.verify(path);
      if (provenance.isRejected && !await _isSendableVine(provenance, path)) {
        return entry;
      }
    }
    return null;
  }

  /// Whether a clip the check rejected for having no credential is an
  /// archived Vine, which the recipient adds anyway. When that cannot be
  /// told, the clip goes out like one whose check could not run, and the
  /// recipient's check decides.
  Future<bool> _isSendableVine(
    ClipProvenanceResult provenance,
    String path,
  ) async {
    final isArchivedVine = _isArchivedVine;
    if (isArchivedVine == null ||
        provenance.status != ClipProvenanceStatus.noCredentials) {
      return false;
    }
    try {
      return await isArchivedVine(path);
    } on Exception {
      return true;
    }
  }

  /// Runs [entry] through encrypt, upload and publish, and leaves it sent or
  /// failed. Returns null when it was sent, otherwise why it failed.
  Future<OutgoingVideoDmFailure?> _sendEntry(
    OutgoingVideoDm entry, {
    List<List<String>> extraTags = const [],
  }) async {
    final id = entry.id;
    _setPhase(id, OutgoingVideoDmPhase.encrypting);
    try {
      final result = await _sendService().sendVideo(
        recipientPubkey: entry.recipientPubkey,
        videoFile: File(entry.localPath),
        mimeType: videoDmMimeTypeFor(entry.localPath),
        extraTags: extraTags,
        onPhase: (phase) => _onPhase(id, phase),
        onUploadProgress: (fraction) => _onUploadProgress(id, fraction),
      );
      if (result case NIP17SendSuccess(:final rumorEventId)) {
        _update(
          id,
          (e) => e.copyWith(
            phase: OutgoingVideoDmPhase.sent,
            uploadProgress: () => null,
            rumorEventId: () => rumorEventId,
          ),
        );
        return null;
      }
      Log.warning(
        'Video DM $id was not delivered '
        '(retryablePending: ${result.retryablePending})',
        name: _logName,
        category: LogCategory.video,
        error: VideoDmSendFailure(result.error ?? 'unknown'),
      );
      return _markFailed(id, OutgoingVideoDmFailure.failed);
    } on DmVideoTooLargeException catch (error) {
      Log.warning(
        'Video DM $id is too large to send',
        name: _logName,
        category: LogCategory.video,
        error: error,
      );
      return _markFailed(id, OutgoingVideoDmFailure.tooLarge);
    } on FileSystemException catch (error) {
      // The message only: the exception's path names the plaintext file.
      Log.warning(
        'Video DM $id file could not be read: ${error.message} '
        '(${error.osError?.message})',
        name: _logName,
        category: LogCategory.video,
      );
      return _markFailed(id, OutgoingVideoDmFailure.failed);
    } catch (error, stackTrace) {
      _logUnexpected('Video DM $id', error, stackTrace, site: 'sendVideo');
      return _markFailed(id, OutgoingVideoDmFailure.failed);
    }
  }

  /// Logs an error the pipeline does not classify for [subject], and forwards
  /// it to crash reporting under [site] when it is a programming error, as
  /// [runDetached] does.
  void _logUnexpected(
    String subject,
    Object error,
    StackTrace stackTrace, {
    required String site,
  }) {
    Log.error(
      '$subject failed: $error',
      name: _logName,
      category: LogCategory.video,
      error: error,
      stackTrace: stackTrace,
    );
    final context = '$_logName $site';
    final reportable = asReportableError(error, context: context);
    if (reportable == null) return;
    unawaited(
      (_reporter ?? detachedFailureReporter).recordError(
        reportable,
        stackTrace,
        reason: sanitizeForCrashReport(context),
      ),
    );
  }

  void _onPhase(String id, DmVideoSendPhase phase) {
    final mapped = switch (phase) {
      DmVideoSendPhase.encrypting => OutgoingVideoDmPhase.encrypting,
      DmVideoSendPhase.uploading => OutgoingVideoDmPhase.uploading,
      DmVideoSendPhase.sending => OutgoingVideoDmPhase.publishing,
    };
    _update(id, (e) {
      if (e.phase == mapped) return e;
      return e.copyWith(phase: mapped, uploadProgress: () => null);
    });
  }

  /// Stores [fraction] only when the whole percent the bubble shows changes,
  /// so the thousands of callbacks of a large upload do not each rebuild the
  /// thread.
  void _onUploadProgress(String id, double fraction) {
    _update(id, (e) {
      if (e.phase != OutgoingVideoDmPhase.uploading) return e;
      final previous = e.uploadProgress;
      if (previous != null &&
          _shownPercent(previous) == _shownPercent(fraction)) {
        return e;
      }
      return e.copyWith(uploadProgress: () => fraction);
    });
  }

  static int _shownPercent(double fraction) =>
      (fraction.clamp(0.0, 1.0) * 100).round();

  void _setPhase(String id, OutgoingVideoDmPhase phase) =>
      _update(id, (e) => e.copyWith(phase: phase));

  /// Marks entry [id] failed with [failure], and returns [failure].
  OutgoingVideoDmFailure _markFailed(
    String id,
    OutgoingVideoDmFailure failure,
  ) {
    _update(
      id,
      (e) => e.copyWith(
        phase: OutgoingVideoDmPhase.failed,
        uploadProgress: () => null,
        failure: () => failure,
      ),
    );
    return failure;
  }

  static VideoDmOutcomeStatus _outcomeStatusFor(
    OutgoingVideoDmFailure? failure,
  ) => switch (failure) {
    null => VideoDmOutcomeStatus.sent,
    OutgoingVideoDmFailure.tooLarge => VideoDmOutcomeStatus.tooLarge,
    OutgoingVideoDmFailure.clipNotVerified =>
      VideoDmOutcomeStatus.clipNotVerified,
    OutgoingVideoDmFailure.failed => VideoDmOutcomeStatus.failed,
  };

  void _emitOutcome(
    VideoDmOutcomeStatus status, {
    required int sentCount,
    required int total,
  }) {
    if (_disposed) return;
    _outcomes.add(
      VideoDmSendOutcome(status: status, sentCount: sentCount, total: total),
    );
  }

  /// Removes entry [id] when it is in [phase].
  void _drop(String id, OutgoingVideoDmPhase phase) {
    if (_disposed) return;
    final entries = _entries.value;
    if (!entries.any((entry) => entry.id == id && entry.phase == phase)) {
      return;
    }
    _entries.add([
      for (final entry in entries)
        if (entry.id != id) entry,
    ]);
  }

  OutgoingVideoDm? _entry(String id) =>
      _entries.value.firstWhereOrNull((entry) => entry.id == id);

  static String? _clipPath(OutgoingVideoDm entry) =>
      entry.clip?.video?.file?.path;

  /// Replaces entry [id] with [change] applied, unless it is gone, the
  /// outbox is disposed, or nothing changed.
  void _update(String id, OutgoingVideoDm Function(OutgoingVideoDm) change) {
    if (_disposed) return;
    final entries = _entries.value;
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    final updated = change(entries[index]);
    if (updated == entries[index]) return;
    _entries.add([...entries]..[index] = updated);
  }
}
