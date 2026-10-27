import 'dart:async';
import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/observability/reportable_error.dart';

class ChallengeParticipationState {
  const ChallengeParticipationState({
    this.busy = false,
    this.read,
    this.review,
    this.status,
    this.playing,
    this.actions = const [],
    this.candidates = const [],
    this.handoffs = const [],
    this.picking = false,
    this.reviewPreviewAllowed = false,
    this.previewGeneration = 0,
  });
  final NostrEvent? playing;
  final bool busy;
  final ChallengeRead? read;
  final SubmissionReview? review;
  final SubmissionStatus? status;
  final List<PendingChallengeAction> actions;
  final List<VideoEvent> candidates;
  final List<String> handoffs;
  final bool picking;
  final bool reviewPreviewAllowed;
  final int previewGeneration;
}

/// Serializes UI operations, including echo ingestion after active transport.
/// Consent and exact-byte retries remain owned by the merged repository.
class ChallengeParticipationCubit extends Cubit<ChallengeParticipationState> {
  ChallengeParticipationCubit({
    required this.coordinate,
    required this.submissions,
    required this.refresh,
    required this.loadCandidates,
    required this.exactVideo,
    required this.clientTags,
    required this.prepareRecording,
    required this.handoffs,
    required this.reviewPublished,
  }) : super(const ChallengeParticipationState());
  final String coordinate;
  final ChallengeSubmissionRepository submissions;
  final Future<ChallengeRead> Function() refresh;
  final Future<List<VideoEvent>> Function() loadCandidates;
  final Future<NostrEvent?> Function(String) exactVideo;
  final Future<List<List<String>>> Function() clientTags;
  final Future<String> Function(NostrEvent) prepareRecording;
  final Future<List<String>> Function() handoffs;
  final Future<SubmissionReview> Function(String) reviewPublished;
  // Weakly keyed by the owner-scoped repository: every mounted challenge
  // page sharing it must finish transport before another page ingests echoes.
  static final _queues = Expando<Future<void>>();

  void _set({
    bool busy = false,
    ChallengeRead? read,
    SubmissionReview? review,
    SubmissionStatus? status,
    List<PendingChallengeAction>? actions,
    NostrEvent? playing,
    List<VideoEvent>? candidates,
    List<String>? recovered,
    bool picking = false,
    bool reviewPreviewAllowed = false,
    int? previewGeneration,
  }) {
    if (isClosed) return;
    emit(
      ChallengeParticipationState(
        busy: busy,
        read: read ?? state.read,
        review: review,
        status: status,
        playing: playing,
        actions: actions ?? state.actions,
        candidates: candidates ?? state.candidates,
        handoffs: recovered ?? state.handoffs,
        picking: picking,
        reviewPreviewAllowed: reviewPreviewAllowed,
        previewGeneration: previewGeneration ?? state.previewGeneration,
      ),
    );
  }

  Future<void> _run(
    Future<void> Function() work, {
    bool keepReviewOnFailure = false,
  }) {
    final next = (_queues[submissions] ?? Future<void>.value()).then((_) async {
      if (isClosed) return;
      _set(busy: true, review: state.review, picking: state.picking);
      try {
        await work();
      } on SubmissionException catch (error, stackTrace) {
        if (isClosed) return;
        addError(error, stackTrace);
        _set(
          status: error.status,
          review: keepReviewOnFailure ? state.review : null,
        );
      } on Object catch (error, stackTrace) {
        if (isClosed) return;
        addError(
          asReportableError(
                error,
                context: 'ChallengeParticipationCubit._run',
              ) ??
              error,
          stackTrace,
        );
        _set(
          status: SubmissionStatus.readUnavailable,
          review: keepReviewOnFailure ? state.review : null,
        );
      }
    });
    _queues[submissions] = next;
    return next;
  }

  Future<void> _reload({SubmissionStatus? status}) async {
    final read = await refresh();
    final actions = (await submissions.pendingActions())
        .where(
          (a) =>
              (parseChallengeEvent(a.review.definition).value!
                      as ChallengeDefinition)
                  .coordinate ==
              coordinate,
        )
        .toList();
    final recovered = await handoffs();
    _set(read: read, actions: actions, recovered: recovered, status: status);
  }

  Future<void> load() => _run(_reload);
  Future<void> playEntry(String entryId) => _run(() async {
    final read = await refresh();
    final entry = read.view.entries
        .where((e) => e.event.id == entryId)
        .firstOrNull;
    if (entry == null) {
      _set(read: read, status: SubmissionStatus.blocked);
      return;
    }
    _set(read: read, playing: entry.video);
  });
  Future<void> chooseVideo() => _run(() async {
    final candidates = await loadCandidates();
    _set(candidates: candidates, picking: true);
  });
  Future<void> selectVideo(String eventId) => _run(() async {
    final read = await refresh();
    final definition = read.view.definition;
    final video = await exactVideo(eventId);
    if (definition == null || video == null || video.id != eventId) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    final review = await submissions.prepareEntry(
      definition: definition.event,
      video: video,
      clientTags: await clientTags(),
    );
    _set(read: read, review: review, reviewPreviewAllowed: true);
  });
  Future<void> recover(String id) => _run(
    () async =>
        _set(review: await reviewPublished(id), reviewPreviewAllowed: true),
  );

  /// Revalidates only the exact reviewed video; consent and signing stay in
  /// the repository. Clear playback while its lease is renewed, then give the
  /// view a new player generation so a transient lease gap cannot strand it.
  Future<void> refreshReview() {
    // Another mounted page may own the shared queue. Revoke local preview
    // permission immediately, before waiting to fetch fresh evidence.
    _set(busy: true, review: state.review);
    return _run(() async {
      final review = state.review;
      if (review == null) return _set();
      if (review.withdrawalEntry != null) {
        _set(review: review);
        return;
      }
      if (submissions.currentOwner() != review.owner) {
        throw const SubmissionException(SubmissionStatus.ownerChanged);
      }
      final refreshVideo = submissions.refreshVideo;
      if (refreshVideo == null) {
        throw const SubmissionException(SubmissionStatus.readUnavailable);
      }
      await refreshVideo(review.video);
      if (state.review != review) return;
      if (submissions.currentOwner() != review.owner) {
        throw const SubmissionException(SubmissionStatus.ownerChanged);
      }
      if (!submissions.canPublish(review) ||
          !submissions.reads.isVisible(review.video) ||
          !submissions.reads.isVisible(review.definition)) {
        throw const SubmissionException(SubmissionStatus.blocked);
      }
      _set(
        review: review,
        reviewPreviewAllowed: true,
        previewGeneration: state.previewGeneration + 1,
      );
    }, keepReviewOnFailure: true);
  }

  Future<void> withdraw(String signedEntry) => _run(() async {
    final review = await submissions.prepareWithdrawal(
      entry: NostrEvent.fromJson(
        jsonDecode(signedEntry) as Map<String, dynamic>,
      ),
      clientTags: await clientTags(),
    );
    _set(review: review);
  });
  Future<void> confirm() => _run(() async {
    final review = state.review;
    if (review == null) return _reload(status: SubmissionStatus.reviewRequired);
    final result = await submissions.submit(review);
    await _reload(status: result.status);
  });
  Future<void> retry(String id) => _run(() async {
    final result = await submissions.retry(id);
    await _reload(status: result.status);
  });
  Future<void> reconcile(
    String id,
    String body, {
    String? relay,
    bool indexed = false,
  }) => _run(() async {
    final result = await submissions.reconcile(
      id,
      body,
      relay: relay,
      indexed: indexed,
    );
    await _reload(status: result.status);
  });
  Future<String?> record() async {
    String? id;
    await _run(() async {
      final read = await refresh();
      final definition = read.view.definition;
      if (definition == null || read.view.state != 'open') {
        throw const SubmissionException(SubmissionStatus.reviewRequired);
      }
      id = await prepareRecording(definition.event);
      _set(read: read);
    });
    return id;
  }

  void cancelReview() => _set();
}
