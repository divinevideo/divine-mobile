// ABOUTME: Cubit owning one report sheet's submission across both channels.
// ABOUTME: Constructor-injected services, no Riverpod at submit time.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// What a report targets, and how its moderation DM is labelled.
///
/// A user report targets the account, not one of its videos: the report
/// sheet's constructor allows a video and a `userPubkey` together, so the
/// blob-hash accessors gate on the routing decision rather than on a video
/// being present — otherwise the backend files an account-level report
/// against that one blob.
class ReportTarget extends Equatable {
  const ReportTarget({
    required this.eventId,
    required this.authorPubkey,
    required this.moderationKindLabel,
    required this.moderationEventLabel,
    this.userPubkey,
    this.sourceRelay,
    this.sha256,
    this.videoUrl,
  });

  /// Event id the kind-1984 names. Synthetic (`user_<pubkey>`) for a user
  /// report.
  final String eventId;

  final String authorPubkey;

  /// Pubkey of the reported account, when this report targets a user rather
  /// than one piece of content.
  final String? userPubkey;

  final String? sourceRelay;

  /// The reported video's Blossom blob hash, where the publisher supplied one.
  final String? sha256;

  /// Canonical fallback for [sha256] — Blossom URLs carry the
  /// content-addressed hash in their path.
  final String? videoUrl;

  /// Header used in the moderation DM (e.g. "Content Report"). Internal-only.
  final String moderationKindLabel;

  /// Label preceding the event id in the moderation DM body (e.g. "Event").
  /// Internal-only.
  final String moderationEventLabel;

  bool get isUserReport => userPubkey != null;

  /// Blob hash for the moderation DM, or null when the report targets an
  /// account rather than a video.
  String? get moderationSha256 => isUserReport ? null : sha256;

  /// Blob-hash fallback URL for the moderation DM, gated exactly as
  /// [moderationSha256] is.
  String? get moderationVideoUrl => isUserReport ? null : videoUrl;

  @override
  List<Object?> get props => [
    eventId,
    authorPubkey,
    userPubkey,
    sourceRelay,
    sha256,
    videoUrl,
    moderationKindLabel,
    moderationEventLabel,
  ];
}

/// What this sheet has established about its moderation DM, across every
/// submit it makes.
///
/// The DM is the report itself, so a second copy is a second report to
/// triage (#6610). Only [pending] may dispatch; every other outcome is
/// terminal.
enum ModerationDmOutcome {
  /// Nothing sent yet, or a send failed and left a row to re-drive.
  pending,

  /// The team demonstrably has it: no send, no caveat.
  delivered,

  /// A parked row went unreachable. `recoverFullSend` raises `ArgumentError`
  /// both when the row is gone (the sweep may have delivered it, or the user
  /// deleted it) and when it belongs to another account, so delivery can be
  /// neither confirmed nor retried — there is no row left to re-drive, and
  /// minting a fresh one would be the #6610 duplicate. Keeps the caveat.
  unverifiable,

  /// The DM was refused by the sender/recipient policy gate. This is terminal:
  /// retrying just re-hits the same policy, so resubmits keep the caveat and do
  /// not call `sendMessage` again.
  blocked,

  /// The DM was refused before enqueue because its rumor was too large.
  /// Resubmitting unchanged content cannot succeed and there is no row to
  /// re-drive, so this is terminal like [blocked].
  tooLong,
}

/// The moderation DM's progress across every submit this sheet makes.
class ModerationDmProgress extends Equatable {
  const ModerationDmProgress({
    this.outcome = ModerationDmOutcome.pending,
    this.queuedRumorId,
    this.queuedReason,
    this.queuedDetails,
    this.delivered,
  });

  /// What this sheet knows about the moderation DM so far.
  ///
  /// A resubmit deliberately re-publishes the kind-1984 and files a second
  /// ticket, but must not send a second identical DM to a team that already
  /// has one — or mint a fresh one to replace a row it can no longer reach.
  final ModerationDmOutcome outcome;

  /// The `outgoing_dms` row an earlier undelivered submit parked for the
  /// retry sweep, if one is still outstanding.
  ///
  /// A later submit re-drives *this* row rather than calling `sendMessage`
  /// again: a second call mints a fresh rumor and a second durable row, so the
  /// sweep would deliver one copy and the retry another (#6610). Cleared once
  /// the row is consumed.
  final String? queuedRumorId;

  /// The reason [queuedRumorId]'s rumor was built with.
  ///
  /// The parked rumor's tags are frozen at build time and replayed verbatim by
  /// `recoverFullSend`, so a re-drive after the user changed their mind would
  /// label the report with the superseded reason. Compared before re-driving.
  final ContentFilterReason? queuedReason;

  /// The details text [queuedRumorId]'s rumor was built with.
  ///
  /// Details ride in the human-readable DM body, not the machine tags. They
  /// still have to be part of the parked-row identity so a re-drive cannot
  /// ship stale prose after the user edits and resubmits.
  final String? queuedDetails;

  /// The snapshot a delivered moderation DM carried.
  ///
  /// A plain resubmit should not DM the team twice, but a changed resubmit must
  /// not leave the team with prose or tags from the old report while the
  /// kind-1984 channel republishes the new one.
  final ({ContentFilterReason reason, String details})? delivered;

  /// Whether a DM already delivered carried exactly [reason] and [details].
  bool matchesDelivered(ContentFilterReason reason, String details) =>
      outcome == ModerationDmOutcome.delivered &&
      delivered?.reason == reason &&
      delivered?.details == details;

  /// Whether the parked row's rumor was built with something other than
  /// [reason] / [details], and so must be replaced rather than re-driven.
  bool isStaleFor(ContentFilterReason reason, String details) =>
      (queuedReason != null && queuedReason != reason) ||
      (queuedDetails != null && queuedDetails != details);

  /// Clears the parked row without touching [outcome].
  ModerationDmProgress withoutQueuedRow() =>
      ModerationDmProgress(outcome: outcome, delivered: delivered);

  @override
  List<Object?> get props => [
    outcome,
    queuedRumorId,
    queuedReason,
    queuedDetails,
    delivered,
  ];
}

/// What a moderation DM needs to go out: the repository that sends it and the
/// team inbox it is addressed to.
typedef ModerationDmTransport = ({DmRepository repository, String pubkey});

/// Resolves [ModerationDmTransport] at dispatch time.
///
/// A resolver rather than the values themselves, for two reasons the report
/// flow depends on:
///
/// - Both reads can throw. The moderation label service resolves its pubkey
///   lazily and the DM repository is built from the whole auth/database graph,
///   so resolving them when the sheet opens would let a moderation-side
///   failure block a report that the kind-1984 channel could still carry.
///   Resolving inside [ReportSubmissionCubit]'s dispatch keeps a preflight
///   failure a DM-only failure.
/// - Nothing is captured, so nothing can go stale. The undelivered path
///   dispatches unawaited and the sheet may be gone by then; late resolution
///   also means an account switch cannot leave this cubit wired to the
///   previous account's repository.
typedef ModerationDmTransportResolver = ModerationDmTransport Function();

/// Resolves the primary report service at submit time.
typedef ContentReportingServiceResolver =
    Future<ContentReportingService> Function();

/// Where one report submission has got to.
enum ReportSubmissionStatus {
  /// Nothing in flight; the form is live.
  editing,

  /// A submit is in flight.
  submitting,

  /// The report was durably submitted — show the confirmation. Delivery of the
  /// three channels is owned by their durable queues, so this is unconditional.
  submitted,

  /// The report was rejected or the submit threw.
  failure,
}

class ReportSubmissionState extends Equatable {
  const ReportSubmissionState({
    this.status = ReportSubmissionStatus.editing,
    this.moderationDm = const ModerationDmProgress(),
  });

  final ReportSubmissionStatus status;

  final ModerationDmProgress moderationDm;

  bool get isSubmitting => status == ReportSubmissionStatus.submitting;

  ReportSubmissionState copyWith({
    ReportSubmissionStatus? status,
    ModerationDmProgress? moderationDm,
  }) => ReportSubmissionState(
    status: status ?? this.status,
    moderationDm: moderationDm ?? this.moderationDm,
  );

  @override
  List<Object?> get props => [status, moderationDm];
}

/// Owns one report sheet's submission: the kind-1984 / Zendesk report and the
/// moderation DM that accompanies it.
///
/// Both channels are driven from a single [submit] call so they cannot label
/// one report differently. The caller captures the reason before the first
/// await and hands it in; nothing here reads live form state.
///
/// Service resolvers are constructor-injected so the cubit stays free of
/// Riverpod while still reading account-scoped dependencies at submit time.
class ReportSubmissionCubit extends Cubit<ReportSubmissionState> {
  ReportSubmissionCubit({
    required ContentReportingServiceResolver resolveContentReportingService,
    required ModerationDmTransportResolver resolveModerationDmTransport,
    required ReportTarget target,
  }) : _resolveContentReportingService = resolveContentReportingService,
       _resolveModerationDmTransport = resolveModerationDmTransport,
       _target = target,
       super(const ReportSubmissionState());

  final ContentReportingServiceResolver _resolveContentReportingService;
  final ModerationDmTransportResolver _resolveModerationDmTransport;
  final ReportTarget _target;

  /// The in-flight send queue, so a submit that lands while an earlier one is
  /// still awaiting a relay waits for the first to park its row before deciding
  /// whether to re-drive, replace, or skip it.
  ///
  /// A coordination primitive rather than data — it is never rendered and
  /// never asserted on, so it stays off [ReportSubmissionState].
  Future<void>? _moderationDmInFlight;

  /// Submits one report through both channels.
  ///
  /// [reason] and [details] are the submit's own snapshot, captured by the
  /// caller before its first await: the kind-1984 publish and the moderation DM
  /// are a relay round trip apart, and the reason cards stay tappable in
  /// between, so re-reading live selection on the far side let the two channels
  /// label the same report differently.
  ///
  /// [reasonTitle] is the localized reason name for the DM's human-readable
  /// body; localization stays in the UI layer.
  ///
  /// Read [ReportSubmissionState.status] for which message, if any, to show.
  ///
  /// Returns nothing: the moderation service's own prose is arbitrary
  /// server-controlled text, and Divine's error surface is not the place to
  /// render it (#3589). It is logged instead.
  Future<void> submit({
    required ContentFilterReason reason,
    required String reasonTitle,
    required String details,
  }) async {
    if (state.isSubmitting) return;
    _update(status: ReportSubmissionStatus.submitting);

    try {
      final service = await _resolveContentReportingService();
      final userPubkey = _target.userPubkey;
      final result = userPubkey != null
          ? await service.reportUser(
              userPubkey: userPubkey,
              reason: reason,
              details: details,
            )
          : await service.reportContent(
              eventId: _target.eventId,
              authorPubkey: _target.authorPubkey,
              reason: reason,
              details: details,
              sourceRelay: _target.sourceRelay,
            );
      if (isClosed) return;

      if (result.isSilentSuccess && result.delivery == ReportDelivery.refused) {
        // A deliberate refusal — a self-report (#8352). Nothing was built,
        // published, or recorded, and nothing should be sent: not the
        // kind-1984 event, and NOT the moderation DM, or a self-naming report
        // would leave the device privately. Silent success — show the normal
        // confirmation without touching the DM path.
        _update(status: ReportSubmissionStatus.submitted);
        return;
      }

      if (result.success) {
        // Optimistic: the report is durable the moment reportContent returns
        // (PR 1 queues its relay + Zendesk channels), so confirm now. Enqueue
        // the moderation DM durably too — awaiting only the fast local write —
        // and let it publish in the background, so the confirmation never waits
        // on a relay. Delivery of all three channels is owned by their durable
        // queues, so the confirmation is unconditional. #8053.
        await _sendModerationDm(reason, reasonTitle, details);
        if (isClosed) return;
        _update(status: ReportSubmissionStatus.submitted);
        return;
      }

      Log.error(
        'Report submission failed: ${result.error}',
        name: 'ReportSubmissionCubit',
        category: LogCategory.ui,
      );
      _update(status: ReportSubmissionStatus.failure);
      return;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to submit report: $e',
        name: 'ReportSubmissionCubit',
        category: LogCategory.ui,
      );
      // Unwrapped: `ContentReportingService` returns `ReportResult.failure`
      // for the expected publish/auth problems, so a throw reaching here is
      // an infrastructure failure the user is already being told about. Per
      // rules/error_handling.md's "when in doubt: NO", it stays out of
      // Crashlytics until there is evidence it is an invariant violation.
      addError(e, stackTrace);
      _update(status: ReportSubmissionStatus.failure);
      return;
    }
  }

  /// Sends the report to the moderation team's DM inbox (TC-025/026),
  /// exactly once across every submit this sheet makes.
  ///
  /// Returns whether it failed to reach them.
  ///
  /// Four things can already be true when a submit reaches here, and each
  /// has to coalesce rather than send again (#6610) — the DM is the report
  /// itself, so a second copy is a second report to triage:
  ///
  /// - the team already received it: nothing to do.
  /// - a parked row went unreachable: nothing left to drive, and a fresh
  ///   send would be that second copy. Keep the caveat and stop.
  /// - a send is still in flight: queue behind it rather than run alongside
  ///   it, so the first has parked its row before the second looks for one.
  /// - an earlier submit parked a queue row: re-drive that row, in
  ///   [_dispatchModerationDm].
  ///
  /// Queuing rather than joining is what makes the snapshot matter: an
  /// outstanding send carries the label and prose it was built with, so
  /// returning its result to a submit the user has since re-aimed would report
  /// the superseded snapshot. Waiting lets the re-aimed submit see the row the
  /// first one parked and replace it.
  Future<void> _sendModerationDm(
    ContentFilterReason reason,
    String reasonTitle,
    String details,
  ) {
    final outstanding = _moderationDmInFlight;
    final next = outstanding == null
        ? _runModerationDm(reason, reasonTitle, details)
        // _dispatchModerationDm absorbs its own errors, but handle the error
        // arm anyway so a hypothetical one cannot cancel the queued submit.
        : outstanding.then<void>(
            (_) => _runModerationDm(reason, reasonTitle, details),
            onError: (_) => _runModerationDm(reason, reasonTitle, details),
          );
    _moderationDmInFlight = next;
    unawaited(
      next.whenComplete(() {
        if (identical(_moderationDmInFlight, next)) {
          _moderationDmInFlight = null;
        }
      }),
    );
    return next;
  }

  /// One link in the [_sendModerationDm] queue: re-checks the terminal
  /// outcomes, which an earlier link may have reached while this one waited.
  Future<void> _runModerationDm(
    ContentFilterReason reason,
    String reasonTitle,
    String details,
  ) {
    final progress = state.moderationDm;
    // Already delivered with this exact reason/details, or terminal
    // (unverifiable / blocked / tooLong): do not send another copy (#6610).
    if (progress.matchesDelivered(reason, details)) return Future.value();
    if (progress.outcome
        case ModerationDmOutcome.unverifiable ||
            ModerationDmOutcome.blocked ||
            ModerationDmOutcome.tooLong) {
      return Future.value();
    }
    return _dispatchModerationDm(reason, reasonTitle, details);
  }

  /// Drives one moderation-DM attempt: a fresh send, or a re-drive of the
  /// row a previous undelivered submit parked.
  ///
  /// The whole body sits under the catch, transport resolution included: the
  /// undelivered path fires this unawaited, so a throw would otherwise land in
  /// the zone handler with nobody to catch it — and a moderation-side failure
  /// must stay a DM-only failure rather than taking down a report the
  /// kind-1984 channel already carried.
  ///
  /// [dispatchReason] is the submitting call's snapshot. Nothing here reads
  /// live form state: the offline path fires this unawaited and leaves the
  /// reason cards live, so the selection can move while a send is in flight,
  /// and the row parked below must be recorded under the reason its rumor
  /// actually carries or the staleness check above it goes blind.
  Future<void> _dispatchModerationDm(
    ContentFilterReason dispatchReason,
    String dispatchReasonTitle,
    String dispatchDetails,
  ) async {
    try {
      final transport = _resolveModerationDmTransport();
      final content = _formatReportDm(
        reasonTitle: dispatchReasonTitle,
        details: dispatchDetails,
      );

      // A parked row carries the reason it was built with, baked into its
      // stored rumor. Re-driving it after the user picked a different reason
      // would ship the OLD NIP-32 label while the kind-1984 republish carries
      // the new one — the exact cross-channel divergence this DM's tags exist
      // to prevent, and permanent once `user_reports` pins the first write.
      // Drop that row and mint a correct one instead.
      //
      // Best effort: if the sweep already delivered the superseded copy, the
      // cancel is a no-op and the team ends up triaging two DMs while
      // `user_reports` keeps the reason the delivered one pinned. That case is
      // unrecoverable from here either way — re-driving it would pin the same
      // wrong reason and skip the correction entirely.
      if (state.moderationDm.isStaleFor(dispatchReason, dispatchDetails)) {
        final stale = state.moderationDm.queuedRumorId;
        if (stale != null) {
          try {
            await transport.repository.cancelOutgoingSend(rumorId: stale);
            // ignore: avoid_catching_errors
          } on ArgumentError {
            // Same ambiguity as recoverFullSend: the row may be gone because
            // the sweep delivered it, the user deleted it, or the active
            // account changed. Do not mint a fresh report DM when we cannot
            // prove the stale one was cancelled.
            _markUnverifiable();
            return;
          }
        }
        _update(moderationDm: state.moderationDm.withoutQueuedRow());
      }

      final parked = state.moderationDm.queuedRumorId;
      if (parked != null) {
        // Coalesce (#6610): re-drive the row an earlier submit parked rather
        // than minting a second rumor. The drive runs in the background so the
        // confirmation is never blocked on a relay.
        _driveModerationDm(transport, parked, dispatchReason, dispatchDetails);
        return;
      }

      // Fresh send: enqueue the DM durably, awaiting only the fast local write.
      // The enqueue-then-recoverFullSend path is NIP-17 gift wrap only and
      // never fires the metadata-leaking NIP-04 fallback (that lives in
      // sendMessage's publish path alone), so identity-bearing report content
      // cannot leak as plaintext even though we no longer pass
      // skipNip04Fallback. #8053.
      final enqueued = await transport.repository.enqueueSend(
        recipientPubkey: transport.pubkey,
        content: content,
        additionalTags: ContentReportingService.moderationDmTags(
          reason: dispatchReason,
          sha256: _target.moderationSha256,
          videoUrl: _target.moderationVideoUrl,
        ),
      );

      if (enqueued.blocked || enqueued.tooLong) {
        // Terminal before a row was parked: the policy gate (#176) or the size
        // ceiling (#7331) refused it. Record it so a resubmit does not
        // re-attempt (#6610); the report reached its other channels regardless.
        _update(
          moderationDm: ModerationDmProgress(
            outcome: enqueued.blocked
                ? ModerationDmOutcome.blocked
                : ModerationDmOutcome.tooLong,
            delivered: state.moderationDm.delivered,
          ),
        );
        Log.warning(
          'Moderation DM refused before enqueue '
          '(recipient=${pubkeyForLogs(transport.pubkey)}, '
          'blocked=${enqueued.blocked}, tooLong=${enqueued.tooLong}): '
          '${enqueued.error}',
          name: 'ReportSubmissionCubit',
          category: LogCategory.system,
        );
        return;
      }

      final rumorId = enqueued.queuedRumorId;
      if (rumorId == null) {
        // A refusal with no row (a self-addressed send) — unreachable for the
        // moderation pubkey, handled defensively: nothing parked, nothing to
        // drive.
        return;
      }

      // The row is durable now; record it for coalescing, then drive its
      // publish in the background.
      _update(
        moderationDm: ModerationDmProgress(
          delivered: state.moderationDm.delivered,
          queuedRumorId: rumorId,
          // The snapshot, not live selection: the parked rumor was built with
          // it, and the staleness check compares against it on a later submit.
          queuedReason: dispatchReason,
          queuedDetails: dispatchDetails,
        ),
      );
      _driveModerationDm(transport, rumorId, dispatchReason, dispatchDetails);
    } catch (e, stackTrace) {
      // Pre-flight throws only (uninitialized repository, invalid recipient) —
      // never a delivery outcome. The report already reached its other
      // channels; a moderation-DM preflight failure must not take it down.
      Log.warning(
        'Failed to enqueue moderation DM: $e',
        name: 'ReportSubmissionCubit',
        category: LogCategory.system,
      );
      // Unwrapped, for the same reason as the submit path above.
      addError(e, stackTrace);
    }
  }

  /// Drives a parked moderation-DM row's publish in the background, recording
  /// the outcome for #6610 coalescing when it settles. Never blocks the
  /// confirmation. A row that is gone (delivered by the sweep, or cancelled)
  /// surfaces as an `ArgumentError` and is left to the sweep — never re-sent.
  void _driveModerationDm(
    ModerationDmTransport transport,
    String rumorId,
    ContentFilterReason reason,
    String details,
  ) {
    unawaited(
      transport.repository
          .recoverFullSend(rumorId: rumorId, resetRetryBudget: true)
          .then(
            (result) {
              if (!isClosed) _recordDmDriveResult(result, reason, details);
            },
            onError: (Object e) {
              Log.warning(
                'Moderation DM background drive could not resolve $rumorId: $e',
                name: 'ReportSubmissionCubit',
                category: LogCategory.system,
              );
              // `recoverFullSend` raises ArgumentError when the row is gone
              // (delivered by the sweep, cancelled, or a foreign account):
              // delivery can be neither confirmed nor retried. Mark it
              // unverifiable so a resubmit does not mint the #6610 duplicate.
              if (e is ArgumentError && !isClosed) _markUnverifiable();
            },
          ),
    );
  }

  void _recordDmDriveResult(
    NIP17SendResult result,
    ContentFilterReason reason,
    String details,
  ) {
    switch (result) {
      case NIP17SendSuccess():
        // Delivered: the team has it. Clear the parked row so a plain resubmit
        // does not send a second copy (#6610).
        _update(
          moderationDm: ModerationDmProgress(
            outcome: ModerationDmOutcome.delivered,
            delivered: (reason: reason, details: details),
          ),
        );
      case NIP17SendFailure(blocked: true):
        _update(
          moderationDm: ModerationDmProgress(
            outcome: ModerationDmOutcome.blocked,
            delivered: state.moderationDm.delivered,
          ),
        );
      case NIP17SendFailure(tooLong: true):
        _update(
          moderationDm: ModerationDmProgress(
            outcome: ModerationDmOutcome.tooLong,
            delivered: state.moderationDm.delivered,
          ),
        );
      case NIP17SendFailure():
        // Soft/hard failure: the row stays parked (already recorded) for the
        // sweep; leave the pending state untouched.
        break;
    }
  }

  void _markUnverifiable() => _update(
    moderationDm: ModerationDmProgress(
      outcome: ModerationDmOutcome.unverifiable,
      delivered: state.moderationDm.delivered,
    ),
  );

  String _formatReportDm({
    required String reasonTitle,
    required String details,
  }) {
    final buffer = StringBuffer()
      ..writeln(_target.moderationKindLabel)
      ..writeln('Reason: $reasonTitle')
      ..writeln('${_target.moderationEventLabel}: ${_target.eventId}');
    if (details.isNotEmpty) {
      // The moderation DM is private, but still leaves the device. Redact
      // per field before assembly, matching the public report projections.
      buffer.writeln('Details: ${sanitizeDiagnosticText(details)}');
    }
    return buffer.toString().trimRight();
  }

  /// Emits unless the sheet has already closed. The offline path dispatches
  /// its DM unawaited, so this cubit can outlive nothing and still be asked
  /// to record an outcome after `close()`.
  void _update({
    ReportSubmissionStatus? status,
    ModerationDmProgress? moderationDm,
  }) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: status,
        moderationDm: moderationDm,
      ),
    );
  }
}
