// ABOUTME: Per-account, in-memory owner of outgoing video DMs: queues sends,
// ABOUTME: runs them one at a time, and publishes their phase and progress.

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_preview.dart';
import 'package:openvine/services/dm_video_send_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:uuid/uuid.dart';

/// Size limit for a picked video, in whole megabytes, for display copy.
const int videoDmMaxMegabytes = dmVideoMaxPlaintextBytes ~/ (1024 * 1024);

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

/// Where an [OutgoingVideoDm] is in its send.
enum OutgoingVideoDmPhase {
  /// Waiting for the sends ahead of it.
  queued,

  /// A library clip's C2PA credential is being checked.
  checking,

  /// The plaintext file is being encrypted for upload.
  encrypting,

  /// The ciphertext is being uploaded to Blossom.
  uploading,

  /// The kind 15 file message is being published to relays.
  publishing,

  /// The recipient gift wrap reached a relay.
  sent,

  /// The send ended without delivering; see [OutgoingVideoDm.failure].
  failed,
}

/// Why an [OutgoingVideoDm] ended [OutgoingVideoDmPhase.failed].
enum OutgoingVideoDmFailure {
  /// The file exceeds [dmVideoMaxPlaintextBytes]; nothing was uploaded.
  tooLarge,

  /// A library clip failed its C2PA camera-capture check and is not an
  /// archived Vine, so it was not sent.
  clipNotVerified,

  /// The send did not complete. Retrying redoes the whole pipeline.
  failed,
}

/// How a finished send request ended.
enum VideoDmOutcomeStatus {
  /// Everything in the request went out.
  sent,

  /// The file was too large to send.
  tooLarge,

  /// A library clip failed its C2PA camera-capture check.
  clipNotVerified,

  /// The send did not complete.
  failed,
}

/// One outgoing video DM, from the moment it is requested until its message
/// row is on screen or it is removed.
class OutgoingVideoDm extends Equatable {
  /// Creates an [OutgoingVideoDm].
  const OutgoingVideoDm({
    required this.id,
    required this.conversationId,
    required this.recipientPubkey,
    required this.localPath,
    required this.requestedAt,
    this.clip,
    this.batchId,
    this.frame,
    this.phase = OutgoingVideoDmPhase.queued,
    this.uploadProgress,
    this.failure,
    this.rumorEventId,
  });

  /// Local id, stable for the entry's life.
  final String id;

  /// The conversation the video is sent in.
  final String conversationId;

  /// Hex public key of the recipient.
  final String recipientPubkey;

  /// The picked or library file being sent.
  final String localPath;

  /// The library clip being sent; null for a gallery video.
  final DivineVideoClip? clip;

  /// Shared by the clips of one multi-clip pick; null for a single video.
  final String? batchId;

  /// When the send was requested.
  final DateTime requestedAt;

  /// JPEG bytes of the card frame; null until read, or if it cannot be.
  final Uint8List? frame;

  /// Where the send is.
  final OutgoingVideoDmPhase phase;

  /// Upload completion fraction (0.0 to 1.0); set only while uploading.
  final double? uploadProgress;

  /// Why the send failed; set only when [phase] is failed.
  final OutgoingVideoDmFailure? failure;

  /// The id of the sent message's row; set when [phase] is sent.
  final String? rumorEventId;

  /// Whether retrying could succeed: a too-large file or a rejected clip
  /// would fail again the same way.
  bool get canRetry =>
      phase == OutgoingVideoDmPhase.failed &&
      failure == OutgoingVideoDmFailure.failed;

  /// Returns a copy with the given fields replaced. Nullable fields take a
  /// getter so they can be cleared: `uploadProgress: () => null`.
  OutgoingVideoDm copyWith({
    OutgoingVideoDmPhase? phase,
    Uint8List? Function()? frame,
    double? Function()? uploadProgress,
    OutgoingVideoDmFailure? Function()? failure,
    String? Function()? rumorEventId,
  }) => OutgoingVideoDm(
    id: id,
    conversationId: conversationId,
    recipientPubkey: recipientPubkey,
    localPath: localPath,
    clip: clip,
    batchId: batchId,
    requestedAt: requestedAt,
    frame: frame != null ? frame() : this.frame,
    phase: phase ?? this.phase,
    uploadProgress: uploadProgress != null
        ? uploadProgress()
        : this.uploadProgress,
    failure: failure != null ? failure() : this.failure,
    rumorEventId: rumorEventId != null ? rumorEventId() : this.rumorEventId,
  );

  @override
  List<Object?> get props => [
    id,
    conversationId,
    recipientPubkey,
    localPath,
    clip,
    batchId,
    requestedAt,
    frame,
    phase,
    uploadProgress,
    failure,
    rumorEventId,
  ];
}

/// How one send request (a single video, or a whole clip batch) ended.
class VideoDmSendOutcome extends Equatable {
  /// Creates a [VideoDmSendOutcome].
  const VideoDmSendOutcome({
    required this.status,
    required this.sentCount,
    required this.total,
  });

  /// The terminal status: [VideoDmOutcomeStatus.sent] when everything went
  /// out.
  final VideoDmOutcomeStatus status;

  /// How many videos were delivered before the request ended.
  final int sentCount;

  /// How many videos the request held.
  final int total;

  /// Whether some, but not all, videos went out.
  bool get isPartial => sentCount > 0 && sentCount < total;

  @override
  List<Object?> get props => [status, sentCount, total];
}

/// Owns the outgoing video DMs of one account, so a send keeps going and
/// keeps reporting progress after the user leaves the chat.
///
/// Requests are queued synchronously and run one at a time, first in first
/// out. Each job reads the send service when it starts, so a job keeps the
/// instance it started with. Nothing is persisted: [dispose] drops every
/// entry, and a send already in flight finishes unobserved.
class VideoDmOutbox {
  /// Creates a [VideoDmOutbox].
  ///
  /// [sendService] is read when each job starts. [readFrame] reads a card
  /// frame when an entry is created; [newId] and [now] stamp new entries.
  VideoDmOutbox({
    required DmVideoSendService Function() sendService,
    DmVideoCardFrameReader readFrame = readDmVideoCardFrame,
    String Function()? newId,
    DateTime Function()? now,
  }) : _sendService = sendService,
       _readFrame = readFrame,
       _newId = newId ?? const Uuid().v4,
       _now = now ?? DateTime.now;

  static const _logName = 'VideoDmOutbox';

  final DmVideoSendService Function() _sendService;
  final DmVideoCardFrameReader _readFrame;
  final String Function() _newId;
  final DateTime Function() _now;

  final BehaviorSubject<List<OutgoingVideoDm>> _entries =
      BehaviorSubject<List<OutgoingVideoDm>>.seeded(const []);
  final StreamController<VideoDmSendOutcome> _outcomes =
      StreamController<VideoDmSendOutcome>.broadcast();
  final Queue<String> _queue = Queue<String>();
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
    _queue.add(entry.id);
    runDetached(
      _attachFrame(entry.id, file),
      'read a video DM card frame',
      logName: _logName,
      category: LogCategory.video,
    );
    _startWorker();
  }

  /// Stops publishing, drops every entry, and ignores sends that finish
  /// afterwards. Safe to call more than once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _queue.clear();
    unawaited(_entries.close());
    unawaited(_outcomes.close());
  }

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
    );
  }

  Future<void> _drainQueue() async {
    try {
      while (!_disposed && _queue.isNotEmpty) {
        final entry = _entry(_queue.removeFirst());
        if (entry == null) continue;
        await _sendGalleryVideo(entry);
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _sendGalleryVideo(OutgoingVideoDm entry) async {
    final id = entry.id;
    _update(id, (e) => e.copyWith(phase: OutgoingVideoDmPhase.encrypting));
    try {
      final result = await _sendService().sendVideo(
        recipientPubkey: entry.recipientPubkey,
        videoFile: File(entry.localPath),
        mimeType: videoDmMimeTypeFor(entry.localPath),
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
        _emitOutcome(VideoDmOutcomeStatus.sent, sentCount: 1);
        return;
      }
      Log.warning(
        'Video DM $id was not delivered '
        '(retryablePending: ${result.retryablePending})',
        name: _logName,
        category: LogCategory.video,
        error: VideoDmSendFailure(result.error ?? 'unknown'),
      );
      _fail(id, OutgoingVideoDmFailure.failed);
    } on DmVideoTooLargeException catch (error) {
      Log.warning(
        'Video DM $id is too large to send',
        name: _logName,
        category: LogCategory.video,
        error: error,
      );
      _fail(id, OutgoingVideoDmFailure.tooLarge);
    } on FileSystemException catch (error) {
      // The message only: the exception's path names the plaintext file.
      Log.warning(
        'Video DM $id file could not be read: ${error.message} '
        '(${error.osError?.message})',
        name: _logName,
        category: LogCategory.video,
      );
      _fail(id, OutgoingVideoDmFailure.failed);
    } catch (error, stackTrace) {
      _logUnexpected(id, error, stackTrace);
      _fail(id, OutgoingVideoDmFailure.failed);
    }
  }

  /// Logs an error the pipeline does not classify, and forwards it to crash
  /// reporting when it is a programming error, as [runDetached] does.
  void _logUnexpected(String id, Object error, StackTrace stackTrace) {
    Log.error(
      'Video DM $id failed: $error',
      name: _logName,
      category: LogCategory.video,
      error: error,
      stackTrace: stackTrace,
    );
    final reportable = asReportableError(
      error,
      context: '$_logName sendVideo',
    );
    if (reportable == null) return;
    unawaited(
      detachedFailureReporter.recordError(
        reportable,
        stackTrace,
        reason: sanitizeForCrashReport('$_logName sendVideo'),
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

  void _onUploadProgress(String id, double fraction) {
    _update(id, (e) {
      if (e.phase != OutgoingVideoDmPhase.uploading) return e;
      return e.copyWith(uploadProgress: () => fraction);
    });
  }

  void _fail(String id, OutgoingVideoDmFailure failure) {
    _update(
      id,
      (e) => e.copyWith(
        phase: OutgoingVideoDmPhase.failed,
        uploadProgress: () => null,
        failure: () => failure,
      ),
    );
    _emitOutcome(switch (failure) {
      OutgoingVideoDmFailure.tooLarge => VideoDmOutcomeStatus.tooLarge,
      OutgoingVideoDmFailure.clipNotVerified =>
        VideoDmOutcomeStatus.clipNotVerified,
      OutgoingVideoDmFailure.failed => VideoDmOutcomeStatus.failed,
    }, sentCount: 0);
  }

  void _emitOutcome(VideoDmOutcomeStatus status, {required int sentCount}) {
    if (_disposed) return;
    _outcomes.add(
      VideoDmSendOutcome(status: status, sentCount: sentCount, total: 1),
    );
  }

  OutgoingVideoDm? _entry(String id) =>
      _entries.value.firstWhereOrNull((entry) => entry.id == id);

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
