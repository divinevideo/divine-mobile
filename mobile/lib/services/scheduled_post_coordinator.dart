// ABOUTME: Drives the scheduled-post outbox for one account (#3538): hands
// ABOUTME: posts to the relay, mirrors its verdicts, publishes what the relay
// ABOUTME: did not, and runs the confirmed-publish side effects.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:meta/meta.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/repositories/scheduled_posts_repository.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/schedule_api_client.dart';
import 'package:openvine/services/video_publish/scheduled_event_restamper.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:unified_logger/unified_logger.dart';

/// Signs an unsigned event body. Bound to `AuthService.createAndSignEvent`.
typedef ScheduledEventSigner = Future<Event?> Function({
  required int kind,
  required String content,
  List<List<String>>? tags,
  int? createdAt,
});

/// Broadcasts an already-signed event. Bound to
/// `SignedEventRelayPublisher.publish`, whose retry-mode presence check keeps
/// a post the relay already published from being sent twice.
typedef ScheduledEventBroadcaster = Future<EventPublishOutcome> Function(
  Event event, {
  bool isRetry,
});

/// Side effects of a confirmed publish. Bound to
/// `VideoEventPublisher.recordScheduledPublish`.
typedef ScheduledPublishRecorder = Future<void> Function(
  Event event, {
  String? uploadId,
});

/// Outcome of a user action on a scheduled post.
enum ScheduledPostActionOutcome {
  /// The action took effect.
  done,

  /// The relay had already published the post; it is live now.
  alreadyPublished,

  /// The relay could not be reached; nothing changed.
  unavailable,

  /// Signing failed, or the account is not the owner; nothing changed.
  failed,
}

/// One account's scheduled posts, from hand-off to publish.
///
/// Lifecycle mirrors `ReportRetryService`: a sweep runs on foreground, on
/// reconnect, after every outbox write, and from one held timer armed to the
/// next moment a row needs attention. A sweep (1) finishes rows an earlier
/// sweep settled but never followed up, (2) hands pending rows to the
/// relay — or publishes them directly when their time is too close for the
/// relay to accept — (3) mirrors the relay's queue state, (4) publishes held
/// posts the relay is late on, and (5) runs the confirmed-publish side
/// effects for anything that went live. It leaves the rows a user action is
/// working on to that action.
///
/// Owner-scoped: every step re-checks that the signed-in account still owns
/// the outbox, so an account switch mid-sweep publishes nothing for the
/// previous account.
class ScheduledPostCoordinator {
  ScheduledPostCoordinator({
    required ScheduledPostsRepository repository,
    required ScheduledEventBroadcaster broadcast,
    required ScheduledPublishRecorder recordPublish,
    required ScheduledEventSigner sign,
    required DraftStorageService draftService,
    required Stream<bool> appForegroundStream,
    required String Function() currentPubkey,
    CollaboratorInviteService? collaboratorInviteService,
    Stream<void>? retryTriggerStream,
    Stream<void>? outboxChangedStream,
    Duration syncInterval = const Duration(minutes: 5),
    Duration minTimerDelay = const Duration(seconds: 5),
    Duration maxTimerDelay = const Duration(hours: 1),
    DateTime Function() now = DateTime.now,
  }) : _repository = repository,
       _broadcast = broadcast,
       _recordPublish = recordPublish,
       _sign = sign,
       _draftService = draftService,
       _appForegroundStream = appForegroundStream,
       _currentPubkey = currentPubkey,
       _inviteService = collaboratorInviteService,
       _retryTriggerStream = retryTriggerStream,
       _outboxChangedStream = outboxChangedStream,
       _syncInterval = syncInterval,
       _minTimerDelay = minTimerDelay,
       _maxTimerDelay = maxTimerDelay,
       _now = now;

  final ScheduledPostsRepository _repository;
  final ScheduledEventBroadcaster _broadcast;
  final ScheduledPublishRecorder _recordPublish;
  final ScheduledEventSigner _sign;
  final DraftStorageService _draftService;
  final Stream<bool> _appForegroundStream;
  final String Function() _currentPubkey;
  final CollaboratorInviteService? _inviteService;
  final Stream<void>? _retryTriggerStream;
  final Stream<void>? _outboxChangedStream;
  final Duration _syncInterval;
  final Duration _minTimerDelay;

  /// Web's `setTimeout` overflows past ~24.8 days and fires at once; a post
  /// 90 days out is re-armed from a shorter timer instead.
  final Duration _maxTimerDelay;
  final DateTime Function() _now;

  StreamSubscription<bool>? _foregroundSubscription;
  StreamSubscription<void>? _retrySubscription;
  StreamSubscription<void>? _outboxSubscription;
  Timer? _timer;
  Duration? _armedDelay;
  bool _isInitialized = false;
  bool _isSweeping = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _sweepAgain = false;
  bool _forceNext = false;
  DateTime? _lastSyncAt;

  /// Rows a user action is working on. A sweep leaves them to it, so the two
  /// never broadcast, finalize or park the same row twice.
  final Set<String> _acting = <String>{};
  List<ScheduledPostServerEntry> _serverOnly = const [];
  final _serverOnlyChanges = StreamController<void>.broadcast();

  static const _logName = 'ScheduledPostCoordinator';

  bool get isInitialized => _isInitialized;

  @visibleForTesting
  bool get isSweeping => _isSweeping;

  @visibleForTesting
  bool get hasTimer => _timer != null;

  @visibleForTesting
  Duration? get armedDelay => _armedDelay;

  String get ownerPubkey => _repository.ownerPubkey;

  /// Posts the relay holds for this account that were scheduled from another
  /// device, as of the last sync. They can only be withdrawn from here.
  List<ScheduledPostServerEntry> get serverOnlyPosts => _serverOnly;

  /// Fires when [serverOnlyPosts] changes.
  Stream<void> get serverOnlyChanges => _serverOnlyChanges.stream;

  bool get _ownsOutbox => _currentPubkey() == ownerPubkey;

  Future<void> initialize() async {
    if (_isInitialized || _disposed) return;
    _isInitialized = true;
    // Coming back or reconnecting is when an unconfirmed broadcast most
    // likely goes through, so neither waits out its backoff.
    _foregroundSubscription = _appForegroundStream.listen((foreground) {
      // The provider replays the current state on subscribe; only a change
      // is a return, and the sweep below already covers startup.
      if (foreground == _foreground) return;
      _foreground = foreground;
      if (foreground) {
        _repository.resetClientPublishBackoff();
        unawaited(sweep(force: true));
      } else {
        _timer?.cancel();
        _timer = null;
      }
    });
    _retrySubscription = _retryTriggerStream?.listen((_) {
      if (!_foreground) return;
      _repository.resetClientPublishBackoff();
      unawaited(sweep(force: true));
    });
    _outboxSubscription = _outboxChangedStream?.listen(
      (_) => unawaited(sweep()),
    );
    unawaited(sweep(force: true));
  }

  Future<void> dispose() async {
    _disposed = true;
    _isInitialized = false;
    _timer?.cancel();
    _timer = null;
    await _foregroundSubscription?.cancel();
    await _retrySubscription?.cancel();
    await _outboxSubscription?.cancel();
    await _serverOnlyChanges.close();
  }

  /// Runs one pass over the outbox. [force] also refreshes the relay's view
  /// regardless of how recently it was synced.
  Future<void> sweep({bool force = false}) async {
    if (_disposed || !_foreground) return;
    if (_isSweeping) {
      _sweepAgain = true;
      _forceNext |= force;
      return;
    }
    _isSweeping = true;
    _timer?.cancel();
    _timer = null;
    try {
      if (_ownsOutbox) await _sweepOnce(force: force);
    } on AsyncCancelledException {
      // Disposed mid-publish: teardown, not a failed sweep.
    } catch (e, stackTrace) {
      Log.warning(
        'Scheduled-post sweep failed; rows are retained: $e',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isSweeping = false;
      if (_sweepAgain && !_disposed && _foreground) {
        final forceNext = _forceNext;
        _sweepAgain = false;
        _forceNext = false;
        unawaited(sweep(force: forceNext));
      } else {
        await _scheduleNext();
      }
    }
  }

  Future<void> _sweepOnce({required bool force}) async {
    final now = _now();
    await _finalizeSettled();
    if (_stop) return;
    var pending = await _repository.pending();
    // A forced sweep syncs even with nothing local, so posts scheduled from
    // another device show up.
    if (pending.isEmpty && _serverOnly.isEmpty && !force) return;

    for (final post in pending) {
      if (_stop) return;
      if (post.status != ScheduledPostStatus.pendingSubmit) continue;
      if (_acting.contains(post.eventId)) continue;
      if (_repository.shouldPublishDirectly(post, now)) {
        if (!_repository.isClientPublishBackingOff(post, now)) {
          await _publishHeldPost(post);
        }
      } else if (_repository.isSubmitDue(post, now)) {
        await _repository.submit(post.eventId);
      }
    }
    if (_stop) return;

    pending = await _repository.pending();
    final syncDue =
        _lastSyncAt == null ||
        !now.isBefore(_lastSyncAt!.add(_syncInterval)) ||
        _repository.dueForClientPublish(pending, now).isNotEmpty;
    if (force || (syncDue && (pending.isNotEmpty || _serverOnly.isNotEmpty))) {
      final sync = await _repository.syncFromServer();
      if (sync.succeeded) {
        _lastSyncAt = now;
        _publishServerOnly(sync.serverOnly);
      }
      if (_stop) return;
      for (final post in sync.published) {
        await _finalizePublished(post);
      }
      for (final post in sync.cancelled) {
        await _finalizeCancelled(post);
      }
      pending = await _repository.pending();
    }
    if (_stop) return;

    if (_withdrawing.isNotEmpty) {
      for (final eventId in _withdrawing.toList()) {
        if (_stop) return;
        if (_acting.contains(eventId)) continue;
        await cancel(eventId);
      }
      if (_stop) return;
      // A withdrawal that landed deletes its row, and the list read above
      // still holds it: re-read before deciding what to broadcast.
      pending = await _repository.pending();
    }
    if (_stop) return;
    for (final post in _repository.dueForClientPublish(pending, _now())) {
      if (_stop) return;
      if (_acting.contains(post.eventId)) continue;
      if (_withdrawing.contains(post.eventId)) continue;
      await _publishHeldPost(post);
    }
  }

  /// Finishes rows a relay verdict or a publish already settled whose
  /// follow-up never ran: the sweep that wrote them stopped (backgrounded,
  /// disposed, account switched) or the app died in between. Nothing else
  /// reads a terminal row again, and every follow-up that runs before the
  /// row is claimed is safe to repeat — the outward-facing ones run after.
  Future<void> _finalizeSettled() async {
    for (final post in await _repository.list()) {
      if (_stop) return;
      if (_acting.contains(post.eventId)) continue;
      switch (post.status) {
        case ScheduledPostStatus.published:
          await _finalizePublished(post);
        case ScheduledPostStatus.cancelled:
          await _finalizeCancelled(post);
        case ScheduledPostStatus.pendingSubmit:
        case ScheduledPostStatus.scheduled:
        case ScheduledPostStatus.failed:
          break;
      }
    }
  }

  bool get _stop => _disposed || !_foreground || !_ownsOutbox;

  void _publishServerOnly(List<ScheduledPostServerEntry> entries) {
    final ids = {for (final e in entries) e.eventId};
    final previous = {for (final e in _serverOnly) e.eventId};
    _serverOnly = entries;
    if (ids.length != previous.length || !ids.containsAll(previous)) {
      if (!_serverOnlyChanges.isClosed) _serverOnlyChanges.add(null);
    }
  }

  /// Withdraws a post scheduled from another device.
  Future<ScheduledPostActionOutcome> cancelRemote(String eventId) async {
    if (!_ownsOutbox) return ScheduledPostActionOutcome.failed;
    final outcome = await _repository.cancelRemote(eventId);
    if (outcome == ScheduledPostCancelOutcome.cancelled ||
        outcome == ScheduledPostCancelOutcome.alreadyPublished) {
      _publishServerOnly([
        for (final entry in _serverOnly)
          if (entry.eventId != eventId) entry,
      ]);
    }
    return switch (outcome) {
      ScheduledPostCancelOutcome.cancelled => ScheduledPostActionOutcome.done,
      ScheduledPostCancelOutcome.alreadyPublished =>
        ScheduledPostActionOutcome.alreadyPublished,
      ScheduledPostCancelOutcome.unavailable =>
        ScheduledPostActionOutcome.unavailable,
      ScheduledPostCancelOutcome.failure => ScheduledPostActionOutcome.failed,
    };
  }

  /// Broadcasts a held [post] from this device. A transient failure leaves
  /// the row for the next sweep; the relay may still publish it meanwhile.
  Future<bool> _publishHeldPost(ScheduledPost post) async {
    var row = post;
    // A row that was never handed off is broadcast from here up to
    // directPublishLead before its time, and it carries created_at ==
    // publishAt. The relay refuses an event more than 60 s ahead of its own
    // clock, so that first attempt is thrown away for nothing. Re-date it to
    // now — there is no relay hold to withdraw, this device owns the only
    // copy, so the new id simply replaces the row.
    //
    // A row the relay already holds is left exactly as it is: its id is what
    // the relay would publish, and broadcasting a differently-dated copy
    // would put the same video out twice.
    if (post.status == ScheduledPostStatus.pendingSubmit) {
      final plan = await _planImmediateBroadcast(post);
      if (_stop || plan == null) return false;
      row = plan.redate
          ? await _redateForImmediateBroadcast(plan.post) ?? plan.post
          : plan.post;
    }
    if (_stop) return false;
    final event = ScheduledPostsRepository.decodeEvent(row);
    final EventPublishOutcome outcome;
    try {
      outcome = await _broadcast(event, isRetry: true);
    } on AccountRestrictedPublishException catch (e) {
      await _repository.markFailed(row.eventId, e.reason);
      return false;
    }
    if (outcome != EventPublishOutcome.published) {
      _repository.recordClientPublishFailure(row.eventId);
      Log.info(
        'Scheduled event ${row.eventId} not published yet; will retry',
        name: _logName,
        category: LogCategory.video,
      );
      return false;
    }
    if (_disposed) return true;
    await _repository.markPublished(row.eventId);
    await _finalizePublished(row);
    return true;
  }

  /// A POST the client recorded as a failure may still have been queued.
  /// Re-signing that row mints a second id the relay will also publish.
  static const _relayFutureDrift = Duration(seconds: 60);

  /// Whether [post] may be broadcast, and whether it must be re-dated first.
  ///
  /// A row that was never submitted can be re-dated: the relay has no copy.
  /// A row that was submitted is listed first. If the relay holds it, the
  /// caller leaves that id alone. If the list cannot be read, the original
  /// id is broadcast only inside the relay's drift window.
  Future<({ScheduledPost post, bool redate})?> _planImmediateBroadcast(
    ScheduledPost post,
  ) async {
    if (post.attempts == 0) return (post: post, redate: true);
    final sync = await _repository.syncFromServer();
    if (_stop) return null;
    if (!sync.succeeded) {
      if (post.publishAtUtc.difference(_now()) > _relayFutureDrift) {
        return null;
      }
      return (post: post, redate: false);
    }
    _lastSyncAt = _now();
    _publishServerOnly(sync.serverOnly);
    for (final published in sync.published) {
      await _finalizePublished(published);
    }
    if (_stop) return null;
    for (final cancelled in sync.cancelled) {
      await _finalizeCancelled(cancelled);
    }
    if (_stop) return null;
    final fresh = await _repository.getById(post.eventId);
    if (fresh == null || fresh.status != ScheduledPostStatus.pendingSubmit) {
      return null;
    }
    // A successful list that omits the id is not proof the relay missed it.
    // Absence is eventually consistent and capped, so re-dating would mint
    // a second event the relay can still publish.
    if (fresh.publishAtUtc.difference(_now()) > _relayFutureDrift) {
      return null;
    }
    return (post: fresh, redate: false);
  }

  /// Replaces a never-handed-off row with one dated now, so the broadcast
  /// below it is inside the relay's drift window. Returns null when the
  /// signer refuses, leaving the original row in place.
  Future<ScheduledPost?> _redateForImmediateBroadcast(
    ScheduledPost post,
  ) async {
    final now = _now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if (post.publishAt <= now) return post;
    final signed = await _resign(post, createdAt: now);
    if (_stop || signed == null) return null;
    if (signed.id == post.eventId) return post;
    final replacement = await _repository.enqueue(
      event: signed,
      draftId: post.draftId,
      uploadId: post.uploadId,
      expireAfterSecs: post.expireAfterSecs,
    );
    await _repository.delete(post.eventId);
    return replacement;
  }

  /// The post is live: echo it locally, send the collaborator invites that
  /// waited for it, and retire the draft copy and the outbox row.
  Future<void> _finalizePublished(ScheduledPost post) async {
    _withdrawing.remove(post.eventId);
    final event = ScheduledPostsRepository.decodeEvent(post);
    try {
      await _recordPublish(event, uploadId: post.uploadId);
    } catch (e, stackTrace) {
      Log.warning(
        'Local echo of scheduled event ${post.eventId} failed: $e',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
    }
    await _deleteDraft(post.draftId);
    // Claim the row before the one follow-up that is not safe to repeat.
    // _finalizeSettled re-runs every published row each sweep, so an invite
    // sent before the delete goes out again whenever the app dies in
    // between — as duplicate DMs to a collaborator, with nothing to dedupe
    // them. Losing them to a crash after the claim is what an immediate
    // publish already does.
    await _repository.delete(post.eventId);
    await _sendCollaboratorInvites(event);
    Log.info(
      'Scheduled event ${post.eventId} is live',
      name: _logName,
      category: LogCategory.video,
    );
  }

  /// The post was withdrawn: its draft copy becomes an ordinary draft again,
  /// unless another row still holds it — a move hands the draft to its
  /// replacement before the old row goes.
  Future<void> _finalizeCancelled(ScheduledPost post) async {
    _withdrawing.remove(post.eventId);
    final stillHeld = (await _repository.list()).any(
      (other) =>
          other.draftId == post.draftId &&
          other.eventId != post.eventId &&
          (other.isPending || other.status == ScheduledPostStatus.failed),
    );
    if (!stillHeld) {
      await _draftService.updatePublishStatus(
        draftId: post.draftId,
        status: PublishStatus.draft,
      );
      // Withdrawn means the creator no longer wants that time. Leaving it on
      // the draft pre-fills Post details with the schedule they just undid.
      await _draftService.updateScheduledAt(draftId: post.draftId);
    }
    await _repository.delete(post.eventId);
  }

  Future<void> _sendCollaboratorInvites(Event event) async {
    final inviteService = _inviteService;
    if (inviteService == null) return;
    final collaborators = <String>{};
    String? dTag;
    String? title;
    String? thumbnailUrl;
    for (final tag in event.tags) {
      if (tag.length < 2) continue;
      switch (tag[0]) {
        case 'p' when tag.length >= 4 && tag[3] == 'collaborator':
          collaborators.add(tag[1]);
        case 'd':
          dTag = tag[1];
        case 'title':
          title = tag[1];
        case 'image':
          thumbnailUrl = tag[1];
      }
    }
    if (collaborators.isEmpty || dTag == null || dTag.isEmpty) return;
    try {
      final result = await inviteService.sendInvites(
        collaboratorPubkeys: collaborators,
        creatorPubkey: event.pubkey,
        videoAddress: '${event.kind}:${event.pubkey}:$dTag',
        title: title,
        thumbnailUrl: thumbnailUrl,
        relayHint: collaboratorInviteRelayHint,
      );
      // Nobody is watching when a scheduled post goes live, so a refused
      // invite has no warning to surface: the log is its only trace.
      if (result.hasFailures) {
        final failed = [
          for (final MapEntry(key: pubkey, value: invite)
              in result.results.entries)
            if (!invite.success && !invite.retryablePending)
              '${pubkeyForLogs(pubkey)}: ${invite.error ?? 'unknown'}',
        ];
        Log.warning(
          'Collaborator invites for scheduled event ${event.id} did not all '
          'go out: ${failed.join('; ')}',
          name: _logName,
          category: LogCategory.video,
        );
      }
    } catch (e, stackTrace) {
      Log.warning(
        'Collaborator invites for scheduled event ${event.id} failed: $e',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _deleteDraft(String draftId) async {
    try {
      await _draftService.deleteDraft(draftId);
    } catch (e, stackTrace) {
      Log.warning(
        'Failed to delete draft $draftId of a published scheduled post: $e',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Runs a user [action] while sweeps leave [eventId] alone. The action
  /// passes any replacement row to `hold` before creating it. A nested
  /// action releases only the rows it took, never its caller's.
  Future<ScheduledPostActionOutcome> _whileHolding(
    String eventId,
    Future<ScheduledPostActionOutcome> Function(void Function(String) hold)
    action,
  ) async {
    final held = <String>[];
    void hold(String id) {
      if (_acting.add(id)) held.add(id);
    }

    hold(eventId);
    try {
      return await action(hold);
    } finally {
      held.forEach(_acting.remove);
    }
  }

  /// Withdraws [eventId] and returns its draft to the Drafts list.
  /// Rows the creator withdrew while the relay could not be reached.
  ///
  /// The relay may still publish them, so the row is left alone and the
  /// DELETE retried; this only stops *this* device's fallback from
  /// broadcasting a post its owner already asked to take back. In memory
  /// only, and deliberately so: the relay still holds the post, so nothing
  /// this device remembers keeps it from going live. Only the DELETE landing
  /// does, and the sweep retries it for as long as the app runs. After a
  /// restart the intent is gone and this device's fallback may broadcast a
  /// post whose withdrawal never reached the relay — which is the same
  /// outcome the relay would have produced on its own.
  final Set<String> _withdrawing = <String>{};

  Future<ScheduledPostActionOutcome> cancel(String eventId) async {
    if (!_ownsOutbox) return ScheduledPostActionOutcome.failed;
    return _whileHolding(eventId, (_) async {
      final post = await _repository.getById(eventId);
      if (post == null) return ScheduledPostActionOutcome.done;

      switch (await _repository.cancelOnServer(eventId)) {
        case ScheduledPostCancelOutcome.cancelled:
          await _finalizeCancelled(post);
          return ScheduledPostActionOutcome.done;
        case ScheduledPostCancelOutcome.alreadyPublished:
          await _finalizePublished(post);
          return ScheduledPostActionOutcome.alreadyPublished;
        case ScheduledPostCancelOutcome.unavailable:
          // The relay never heard the withdrawal, so the row stays as it is
          // and a later sweep tries the DELETE again. What must not happen
          // meanwhile is this device publishing the post the creator just
          // withdrew: the fallback skips a row while its cancel is pending.
          _withdrawing.add(eventId);
          return ScheduledPostActionOutcome.unavailable;
        case ScheduledPostCancelOutcome.failure:
          return ScheduledPostActionOutcome.failed;
      }
    });
  }

  /// Moves [eventId] to [newPublishAt]: a newly signed event replaces the
  /// held one, which is withdrawn from the relay.
  Future<ScheduledPostActionOutcome> reschedule(
    String eventId,
    DateTime newPublishAt,
  ) async {
    if (!_ownsOutbox) return ScheduledPostActionOutcome.failed;
    return _whileHolding(eventId, (_) async {
      final post = await _repository.getById(eventId);
      if (post == null) return ScheduledPostActionOutcome.failed;

      final signed = await _resign(
        post,
        createdAt: newPublishAt.toUtc().millisecondsSinceEpoch ~/ 1000,
      );
      if (_stop || signed == null) return ScheduledPostActionOutcome.failed;
      // The time it already has, over a body an earlier move restamped,
      // signs the held event again: replacing it would withdraw and delete
      // the only copy. A failed one goes back to the relay as it is.
      if (signed.id == post.eventId) {
        return post.status == ScheduledPostStatus.failed
            ? retry(eventId)
            : ScheduledPostActionOutcome.done;
      }

      final withdrawn = await _withdrawBeforeReplacing(post);
      if (_stop) return ScheduledPostActionOutcome.failed;
      if (withdrawn != ScheduledPostActionOutcome.done) return withdrawn;

      // The replacement is only handed off here, and the repository already
      // keeps a waking sweep from submitting it a second time.
      await _repository.enqueue(
        event: signed,
        draftId: post.draftId,
        uploadId: post.uploadId,
        expireAfterSecs: post.expireAfterSecs,
      );
      await _repository.delete(post.eventId);
      // Keep the draft's remembered time on the post's: a later withdrawal
      // hands it back offering the time it actually had, not the first one.
      await _draftService.updateScheduledAt(
        draftId: post.draftId,
        scheduledAt: newPublishAt,
      );
      return _outcomeOfHandOff(await _repository.submit(signed.id));
    });
  }

  /// A refused hand-off leaves the row failed, which the action must not
  /// report as done; one that could not reach the relay is retried later.
  ScheduledPostActionOutcome _outcomeOfHandOff(
    ScheduledPostSubmitResult handOff,
  ) => handOff.outcome == ScheduledPostSubmitOutcome.rejected
      ? ScheduledPostActionOutcome.failed
      : ScheduledPostActionOutcome.done;

  /// Publishes [eventId] right away, as a newly signed event dated now.
  Future<ScheduledPostActionOutcome> publishNow(String eventId) async {
    if (!_ownsOutbox) return ScheduledPostActionOutcome.failed;
    return _whileHolding(eventId, (hold) async {
      final post = await _repository.getById(eventId);
      if (post == null) return ScheduledPostActionOutcome.failed;

      final signed = await _resign(
        post,
        createdAt: _now().toUtc().millisecondsSinceEpoch ~/ 1000,
      );
      if (_stop || signed == null) return ScheduledPostActionOutcome.failed;
      // Already dated now: broadcast the held event rather than replace it
      // with itself, which would delete the only copy before the broadcast.
      if (signed.id == post.eventId) {
        return await _publishHeldPost(post)
            ? ScheduledPostActionOutcome.done
            : ScheduledPostActionOutcome.unavailable;
      }

      final withdrawn = await _withdrawBeforeReplacing(post);
      if (_stop) return ScheduledPostActionOutcome.failed;
      if (withdrawn != ScheduledPostActionOutcome.done) return withdrawn;

      hold(signed.id);
      final replacement = await _repository.enqueue(
        event: signed,
        draftId: post.draftId,
        uploadId: post.uploadId,
        expireAfterSecs: post.expireAfterSecs,
      );
      await _repository.delete(post.eventId);
      final published = await _publishHeldPost(replacement);
      return published
          ? ScheduledPostActionOutcome.done
          : ScheduledPostActionOutcome.unavailable;
    });
  }

  /// Gives a failed post another go: back to the relay when its time is
  /// still ahead, otherwise published now.
  Future<ScheduledPostActionOutcome> retry(String eventId) async {
    if (!_ownsOutbox) return ScheduledPostActionOutcome.failed;
    return _whileHolding(eventId, (_) async {
      final post = await _repository.getById(eventId);
      if (post == null) return ScheduledPostActionOutcome.failed;
      if (post.status != ScheduledPostStatus.failed) {
        return ScheduledPostActionOutcome.done;
      }

      final now = _now();
      if (post.publishAtUtc.isAfter(
        now.add(_repository.config.directPublishLead),
      )) {
        await _repository.requeue(eventId);
        return _outcomeOfHandOff(await _repository.submit(eventId));
      }
      return publishNow(eventId);
    });
  }

  Future<Event?> _resign(ScheduledPost post, {required int createdAt}) async {
    final source = ScheduledPostsRepository.decodeEvent(post);
    final body = restampScheduledEvent(
      source,
      createdAt: createdAt,
      expireAfterSecs: post.expireAfterSecs,
    );
    final signed = await _sign(
      kind: source.kind,
      content: body.content,
      tags: body.tags,
      createdAt: createdAt,
    );
    if (_stop ||
        signed == null ||
        signed.createdAt != createdAt ||
        signed.pubkey != ownerPubkey) {
      Log.error(
        'Could not re-sign scheduled event ${post.eventId} for $createdAt',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
    return signed;
  }

  /// Withdraws the held event so the relay never publishes both versions.
  Future<ScheduledPostActionOutcome> _withdrawBeforeReplacing(
    ScheduledPost post,
  ) async {
    switch (await _repository.cancelOnServer(post.eventId)) {
      case ScheduledPostCancelOutcome.cancelled:
        return ScheduledPostActionOutcome.done;
      case ScheduledPostCancelOutcome.alreadyPublished:
        await _finalizePublished(post);
        return ScheduledPostActionOutcome.alreadyPublished;
      case ScheduledPostCancelOutcome.unavailable:
        return ScheduledPostActionOutcome.unavailable;
      case ScheduledPostCancelOutcome.failure:
        return ScheduledPostActionOutcome.failed;
    }
  }

  Future<void> _scheduleNext() async {
    if (!_isInitialized || _disposed || !_foreground || _isSweeping) return;
    Duration? delay;
    var pending = const <ScheduledPost>[];
    try {
      pending = await _repository.pending();
      delay = _repository.nextWakeIn(pending, _now());
    } catch (e, stackTrace) {
      Log.warning(
        'Could not schedule the next scheduled-post sweep: $e',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      delay = _maxTimerDelay;
    }
    if (!_isInitialized || _disposed || !_foreground || _isSweeping) return;
    if (pending.isNotEmpty || _serverOnly.isNotEmpty) {
      final elapsed = _lastSyncAt == null
          ? _syncInterval
          : _now().difference(_lastSyncAt!);
      final untilSync = _syncInterval - elapsed;
      final syncWait = untilSync.isNegative ? Duration.zero : untilSync;
      if (delay == null || syncWait < delay) delay = syncWait;
    }
    if (delay == null) return;
    if (delay < _minTimerDelay) delay = _minTimerDelay;
    if (delay > _maxTimerDelay) delay = _maxTimerDelay;
    _armedDelay = delay;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(sweep()));
  }
}
