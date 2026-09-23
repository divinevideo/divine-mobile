// ABOUTME: Owns the scheduled-post outbox for one account (#3538): the local
// ABOUTME: rows, their hand-off to the relay's hold queue, and the state sync.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:db_client/db_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/schedule_api_client.dart';
import 'package:unified_logger/unified_logger.dart';

/// Timing knobs for the outbox. Defaults match the relay: a janitor sweeps
/// the hold queue every five minutes and the relay tolerates 60 s of clock
/// drift, so the app only steps in six minutes after the publish time.
class ScheduledPostRetryConfig {
  const ScheduledPostRetryConfig({
    this.initialDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(hours: 1),
    this.backoffMultiplier = 2.0,
    this.unavailableDelay = const Duration(minutes: 15),
    this.fallbackGrace = const Duration(minutes: 6),
    this.directPublishLead = const Duration(minutes: 2),
  });

  /// Backoff for a submission the relay did not answer.
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  /// Retry pace while the endpoint itself is not served (gateway 404 / 503).
  final Duration unavailableDelay;

  /// How long after the publish time the app waits for the relay before it
  /// broadcasts a held event itself.
  final Duration fallbackGrace;

  /// A post due sooner than this is published directly instead of handed to
  /// the relay, whose intake refuses anything inside its 60 s drift window.
  final Duration directPublishLead;
}

enum ScheduledPostSubmitOutcome { submitted, retryLater, rejected }

/// What became of one submission attempt.
class ScheduledPostSubmitResult {
  const ScheduledPostSubmitResult._(this.outcome, {this.kind, this.message});

  const ScheduledPostSubmitResult.submitted()
    : this._(ScheduledPostSubmitOutcome.submitted);

  const ScheduledPostSubmitResult.retryLater(String reason)
    : this._(ScheduledPostSubmitOutcome.retryLater, message: reason);

  const ScheduledPostSubmitResult.rejected({
    required ScheduleRejectionKind kind,
    required String message,
  }) : this._(
         ScheduledPostSubmitOutcome.rejected,
         kind: kind,
         message: message,
       );

  final ScheduledPostSubmitOutcome outcome;
  final ScheduleRejectionKind? kind;
  final String? message;
}

enum ScheduledPostCancelOutcome {
  /// The relay no longer holds the post (cancelled now, or never held it).
  cancelled,

  /// The relay already published it; there is no un-publish.
  alreadyPublished,

  /// The endpoint is not served; the local row was left as it was.
  unavailable,

  /// A transient error; the local row was left as it was.
  failure,
}

/// Rows whose state the relay changed during a sync.
class ScheduledPostSyncResult {
  const ScheduledPostSyncResult({
    required this.succeeded,
    this.published = const [],
    this.cancelled = const [],
    this.failed = const [],
    this.serverOnly = const [],
  });

  /// Whether the relay answered at all.
  final bool succeeded;
  final List<ScheduledPost> published;
  final List<ScheduledPost> cancelled;
  final List<ScheduledPost> failed;

  /// Pending posts the relay holds that this device has no row for —
  /// scheduled from another device. They can only be cancelled from here.
  final List<ScheduledPostServerEntry> serverOnly;
}

/// The scheduled-post outbox of one account.
///
/// Every row is the one durable copy of a pre-signed, future-dated event.
/// The repository decides when a row needs the relay again ([isSubmitDue]),
/// when the app should broadcast it itself ([dueForClientPublish]), and when
/// the next such moment is ([nextWakeIn]); the coordinator only schedules.
/// Reads are scoped to [ownerPubkey], so an account switch swaps the whole
/// repository rather than filtering one.
class ScheduledPostsRepository {
  ScheduledPostsRepository({
    required ScheduledPostsDao dao,
    required ScheduleApiClient client,
    required this.ownerPubkey,
    ScheduledPostRetryConfig config = const ScheduledPostRetryConfig(),
    DateTime Function() now = DateTime.now,
  }) : _dao = dao,
       _client = client,
       _config = config,
       _now = now;

  final ScheduledPostsDao _dao;
  final ScheduleApiClient _client;
  final ScheduledPostRetryConfig _config;
  final DateTime Function() _now;
  final String ownerPubkey;

  final _changes = StreamController<void>.broadcast();

  static const _logName = 'ScheduledPostsRepository';

  ScheduledPostRetryConfig get config => _config;

  /// Fires after every local write, so a coordinator can re-arm its timer.
  Stream<void> get changes => _changes.stream;

  void dispose() {
    // Broadcast controller with no pending adds: close() completes as soon
    // as its listeners are done, and the caller is tearing the repository
    // down rather than waiting on it.
    unawaited(_changes.close());
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// The signed event a row holds.
  static Event decodeEvent(ScheduledPost post) => Event.fromJson(
    jsonDecode(post.signedEventJson) as Map<String, dynamic>,
  );

  Future<ScheduledPost?> getById(String eventId) => _dao.getById(eventId);

  Future<ScheduledPost?> getByDraftId(String draftId) =>
      _dao.getByDraftId(draftId);

  Future<List<ScheduledPost>> list() => _dao.listForOwner(ownerPubkey);

  Stream<List<ScheduledPost>> watch() => _dao.watchForOwner(ownerPubkey);

  Future<List<ScheduledPost>> pending() => _dao.pendingForOwner(ownerPubkey);

  /// Stores the signed [event] as a post awaiting hand-off to the relay.
  Future<ScheduledPost> enqueue({
    required Event event,
    required String draftId,
    String? uploadId,
    int? expireAfterSecs,
  }) async {
    final post = ScheduledPost(
      eventId: event.id,
      ownerPubkey: ownerPubkey,
      draftId: draftId,
      uploadId: uploadId,
      kind: event.kind,
      signedEventJson: jsonEncode(event.toJson()),
      publishAt: event.createdAt,
      expireAfterSecs: expireAfterSecs,
      createdAt: _now(),
    );
    await _dao.enqueue(post);
    _notify();
    return post;
  }

  /// Hands a `pendingSubmit` row to the relay and records the answer.
  ///
  /// One request per event at a time. Enqueueing notifies the coordinator,
  /// whose sweep reaches for the same row the publish path is already
  /// submitting — without this both POST it, and the relay answers the second
  /// with a 409 it never needed to see.
  Future<ScheduledPostSubmitResult> submit(String eventId) async {
    if (!_submitting.add(eventId)) {
      return const ScheduledPostSubmitResult.retryLater('already_submitting');
    }
    try {
      return await _submit(eventId);
    } finally {
      _submitting.remove(eventId);
    }
  }

  final Set<String> _submitting = <String>{};

  Future<ScheduledPostSubmitResult> _submit(String eventId) async {
    final post = await _dao.getById(eventId);
    if (post == null || post.status != ScheduledPostStatus.pendingSubmit) {
      return const ScheduledPostSubmitResult.retryLater('not_pending');
    }

    final result = await _client.schedule(decodeEvent(post));
    final attemptedAt = _now();
    switch (result) {
      case ScheduleSubmitAccepted():
        await _dao.updateStatus(
          eventId: eventId,
          status: ScheduledPostStatus.scheduled,
          clearFailureReason: true,
          attemptedAt: attemptedAt,
        );
        _notify();
        return const ScheduledPostSubmitResult.submitted();
      case ScheduleSubmitRejected(:final kind, :final message):
        await _dao.updateStatus(
          eventId: eventId,
          status: ScheduledPostStatus.failed,
          failureReason: message,
          attemptedAt: attemptedAt,
        );
        _notify();
        return ScheduledPostSubmitResult.rejected(kind: kind, message: message);
      case ScheduleSubmitTransientFailure(:final reason, :final unavailable):
        await _dao.updateStatus(
          eventId: eventId,
          failureReason: unavailable ? '$_unavailablePrefix$reason' : reason,
          attemptedAt: attemptedAt,
        );
        _notify();
        return ScheduledPostSubmitResult.retryLater(reason);
    }
  }

  /// Whether a `pendingSubmit` row's backoff has elapsed at [now].
  bool isSubmitDue(ScheduledPost post, DateTime now) {
    if (post.status != ScheduledPostStatus.pendingSubmit) return false;
    final lastAttempt = post.lastAttemptAt;
    if (lastAttempt == null) return true;
    return !now.isBefore(lastAttempt.add(_backoffFor(post)));
  }

  /// Marks the stored reason of a submission the client judged unserved
  /// (gateway 404, 503), which retries at the slower unavailable pace.
  static const _unavailablePrefix = 'unavailable: ';

  Duration _backoffFor(ScheduledPost post) {
    if (post.attempts == 0) return Duration.zero;
    if (post.failureReason?.startsWith(_unavailablePrefix) ?? false) {
      return _config.unavailableDelay;
    }
    final factor = math.pow(_config.backoffMultiplier, post.attempts - 1);
    final millis = _config.initialDelay.inMilliseconds * factor;
    return Duration(
      milliseconds: math.min(millis, _config.maxDelay.inMilliseconds).round(),
    );
  }

  /// When the app itself should broadcast [post] rather than wait: a held
  /// post the relay has not published [ScheduledPostRetryConfig.fallbackGrace]
  /// after its time, or a never-handed-off post whose time has come.
  DateTime clientPublishTime(ScheduledPost post) {
    final publishAt = post.publishAtUtc;
    return post.status == ScheduledPostStatus.scheduled
        ? publishAt.add(_config.fallbackGrace)
        : publishAt;
  }

  /// A `pendingSubmit` post the relay would refuse as "not far enough in the
  /// future" is broadcast directly instead of submitted.
  bool shouldPublishDirectly(ScheduledPost post, DateTime now) =>
      post.status == ScheduledPostStatus.pendingSubmit &&
      !post.publishAtUtc.isAfter(now.add(_config.directPublishLead));

  /// Pending rows the app should broadcast itself at [now].
  List<ScheduledPost> dueForClientPublish(
    List<ScheduledPost> pending,
    DateTime now,
  ) {
    return [
      for (final post in pending)
        if (post.isPending && !clientPublishTime(post).isAfter(now)) post,
    ];
  }

  /// Time until the next moment a pending row needs attention — a submission
  /// retry or a client publish — or null when nothing is pending.
  Duration? nextWakeIn(List<ScheduledPost> pending, DateTime now) {
    DateTime? next;
    for (final post in pending) {
      if (!post.isPending) continue;
      final candidates = <DateTime>[clientPublishTime(post)];
      if (post.status == ScheduledPostStatus.pendingSubmit) {
        final lastAttempt = post.lastAttemptAt;
        candidates.add(
          lastAttempt == null ? now : lastAttempt.add(_backoffFor(post)),
        );
      }
      for (final candidate in candidates) {
        if (next == null || candidate.isBefore(next)) next = candidate;
      }
    }
    if (next == null) return null;
    final wait = next.difference(now);
    return wait.isNegative ? Duration.zero : wait;
  }

  /// Refreshes local rows from the relay's view of the queue.
  ///
  /// A row missing from the relay's list is left alone: the list is
  /// eventually consistent and capped, so absence is not cancellation.
  Future<ScheduledPostSyncResult> syncFromServer() async {
    final result = await _client.list();
    if (result is! ScheduleListLoaded) {
      final failure = result as ScheduleListFailure;
      Log.warning(
        'Scheduled-post sync failed: ${failure.reason}',
        name: _logName,
        category: LogCategory.video,
      );
      return const ScheduledPostSyncResult(succeeded: false);
    }

    final local = {for (final p in await list()) p.eventId: p};
    final published = <ScheduledPost>[];
    final cancelled = <ScheduledPost>[];
    final failed = <ScheduledPost>[];
    final serverOnly = <ScheduledPostServerEntry>[];
    var changed = false;

    for (final entry in result.entries) {
      final post = local[entry.eventId];
      if (post == null) {
        if (entry.state == ScheduledPostServerState.schedule) {
          serverOnly.add(entry);
        }
        continue;
      }
      if (post.status == ScheduledPostStatus.published ||
          post.status == ScheduledPostStatus.cancelled) {
        continue;
      }
      switch (entry.state) {
        case ScheduledPostServerState.schedule:
          if (post.status == ScheduledPostStatus.pendingSubmit) {
            await _dao.updateStatus(
              eventId: post.eventId,
              status: ScheduledPostStatus.scheduled,
              clearFailureReason: true,
            );
            changed = true;
          }
        case ScheduledPostServerState.published:
          await _dao.updateStatus(
            eventId: post.eventId,
            status: ScheduledPostStatus.published,
            clearFailureReason: true,
          );
          published.add(post.copyWith(status: ScheduledPostStatus.published));
          changed = true;
        case ScheduledPostServerState.failed:
          if (post.status != ScheduledPostStatus.failed ||
              post.failureReason != entry.failureReason) {
            await _dao.updateStatus(
              eventId: post.eventId,
              status: ScheduledPostStatus.failed,
              failureReason: entry.failureReason,
            );
            failed.add(
              post.copyWith(
                status: ScheduledPostStatus.failed,
                failureReason: entry.failureReason,
              ),
            );
            changed = true;
          }
        case ScheduledPostServerState.cancel:
          await _dao.updateStatus(
            eventId: post.eventId,
            status: ScheduledPostStatus.cancelled,
          );
          cancelled.add(post.copyWith(status: ScheduledPostStatus.cancelled));
          changed = true;
      }
    }

    if (changed) _notify();
    return ScheduledPostSyncResult(
      succeeded: true,
      published: published,
      cancelled: cancelled,
      failed: failed,
      serverOnly: serverOnly,
    );
  }

  /// Withdraws [eventId] from the relay and marks the row cancelled.
  ///
  /// Only a `scheduled` row is on the relay's side: a `pendingSubmit` row
  /// was never handed off and a `failed` row is terminal there, so both are
  /// cancelled locally without a round trip (as is a relay 404).
  Future<ScheduledPostCancelOutcome> cancelOnServer(String eventId) async {
    final post = await _dao.getById(eventId);
    if (post == null) return ScheduledPostCancelOutcome.cancelled;

    if (post.status == ScheduledPostStatus.scheduled) {
      final result = await _client.cancel(eventId);
      switch (result) {
        case ScheduleCancelled():
        case ScheduleCancelNotFound():
          break;
        case ScheduleCancelConflict():
          // The relay no longer holds it as pending; only the state it
          // reports says whether that means published or withdrawn.
          switch (await _serverState(eventId)) {
            case ScheduledPostServerState.published:
              await markPublished(eventId);
              return ScheduledPostCancelOutcome.alreadyPublished;
            case ScheduledPostServerState.cancel:
            case ScheduledPostServerState.failed:
              break;
            case ScheduledPostServerState.schedule:
            case null:
              return ScheduledPostCancelOutcome.failure;
          }
        case ScheduleCancelTransientFailure(:final unavailable):
          return unavailable
              ? ScheduledPostCancelOutcome.unavailable
              : ScheduledPostCancelOutcome.failure;
      }
    }

    await _dao.updateStatus(
      eventId: eventId,
      status: ScheduledPostStatus.cancelled,
    );
    _notify();
    return ScheduledPostCancelOutcome.cancelled;
  }

  /// Withdraws a post this device has no row for — one scheduled from
  /// another device — from the relay.
  Future<ScheduledPostCancelOutcome> cancelRemote(String eventId) async {
    switch (await _client.cancel(eventId)) {
      case ScheduleCancelled():
      case ScheduleCancelNotFound():
        return ScheduledPostCancelOutcome.cancelled;
      case ScheduleCancelConflict():
        return switch (await _serverState(eventId)) {
          ScheduledPostServerState.published =>
            ScheduledPostCancelOutcome.alreadyPublished,
          ScheduledPostServerState.cancel || ScheduledPostServerState.failed =>
            ScheduledPostCancelOutcome.cancelled,
          ScheduledPostServerState.schedule ||
          null => ScheduledPostCancelOutcome.failure,
        };
      case ScheduleCancelTransientFailure(:final unavailable):
        return unavailable
            ? ScheduledPostCancelOutcome.unavailable
            : ScheduledPostCancelOutcome.failure;
    }
  }

  /// What the relay's list says became of [eventId] after a cancel answered
  /// 409, or null when it cannot say: the list failed, still reports the
  /// post as held, or no longer carries it (it is capped).
  Future<ScheduledPostServerState?> _serverState(String eventId) async {
    final result = await _client.list();
    ScheduledPostServerState? state;
    if (result is ScheduleListLoaded) {
      for (final entry in result.entries) {
        if (entry.eventId == eventId) state = entry.state;
      }
    }
    if (state == null || state == ScheduledPostServerState.schedule) {
      Log.warning(
        'Cancel of scheduled event $eventId answered 409 but the relay state '
        'is unconfirmed (${state?.name ?? 'not listed'}); leaving it',
        name: _logName,
        category: LogCategory.video,
      );
    }
    return state;
  }

  Future<void> markPublished(String eventId) async {
    await _dao.updateStatus(
      eventId: eventId,
      status: ScheduledPostStatus.published,
      clearFailureReason: true,
    );
    _notify();
  }

  Future<void> markFailed(String eventId, String reason) async {
    await _dao.updateStatus(
      eventId: eventId,
      status: ScheduledPostStatus.failed,
      failureReason: reason,
    );
    _notify();
  }

  /// Returns a failed row to the queue for another hand-off attempt.
  Future<void> requeue(String eventId) async {
    await _dao.updateStatus(
      eventId: eventId,
      status: ScheduledPostStatus.pendingSubmit,
      clearFailureReason: true,
    );
    _notify();
  }

  Future<void> delete(String eventId) async {
    await _dao.deleteById(eventId);
    _notify();
  }
}
