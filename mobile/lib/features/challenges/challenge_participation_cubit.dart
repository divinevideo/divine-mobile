import 'dart:async';
import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/observability/reportable_error.dart';

/// One owner-feed page. This cursor never confers entry membership.
class ChallengeCandidatePage {
  const ChallengeCandidatePage({required this.videos, this.nextOffset});
  final List<VideoEvent> videos;
  final int? nextOffset;
}

class ChallengeParticipationState {
  const ChallengeParticipationState({
    this.busy = false,
    this.read,
    this.review,
    this.status,
    this.playing,
    this.playingEntryId,
    this.candidatesHaveMore = false,
    this.actions = const [],
    this.candidates = const [],
    this.handoffs = const [],
    this.picking = false,
    this.reviewPreviewAllowed = false,
    this.previewGeneration = 0,
  });
  final NostrEvent? playing;
  final String? playingEntryId;
  final bool candidatesHaveMore;
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
    this.loadCandidatePage,
  }) : super(const ChallengeParticipationState());
  final String coordinate;
  final ChallengeSubmissionRepository submissions;
  final Future<ChallengeRead> Function() refresh;
  final Future<List<VideoEvent>> Function() loadCandidates;
  final Future<ChallengeCandidatePage> Function(int?)? loadCandidatePage;
  int? _nextCandidateOffset;
  int _playRequest = 0;
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
    String? playingEntryId,
    bool? candidatesHaveMore,
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
        playingEntryId: playingEntryId,
        candidatesHaveMore: candidatesHaveMore ?? state.candidatesHaveMore,
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
    bool keepPickingOnFailure = false,
  }) {
    final next = (_queues[submissions] ?? Future<void>.value()).then((_) async {
      if (isClosed) return;
      _set(
        busy: true,
        review: state.review,
        picking: state.picking,
        playing: state.playing,
        playingEntryId: state.playingEntryId,
      );
      try {
        await work();
      } on SubmissionException catch (error, stackTrace) {
        if (isClosed) return;
        addError(error, stackTrace);
        _set(
          status: error.status,
          review: keepReviewOnFailure ? state.review : null,
          picking: keepPickingOnFailure && state.picking,
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
          picking: keepPickingOnFailure && state.picking,
        );
      }
    });
    _queues[submissions] = next;
    return next;
  }

  Future<void> _reload({SubmissionStatus? status}) async {
    final playing = state.playing;
    final playingEntryId = state.playingEntryId;
    final request = _playRequest;
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
    final retained =
        request == _playRequest &&
        playingEntryId != null &&
        read.view.entries.any(
          (e) => e.event.id == playingEntryId && e.video.id == playing?.id,
        );
    _set(
      read: read,
      actions: actions,
      recovered: recovered,
      status: status,
      playing: retained ? playing : null,
      playingEntryId: retained ? playingEntryId : null,
    );
  }

  Future<void> load() => _run(_reload);
  Future<void> playEntry(String entryId) {
    final request = ++_playRequest;
    return _run(() async {
      final read = await refresh();
      if (request != _playRequest) {
        _set(read: read);
        return;
      }
      final entry = read.view.entries
          .where((e) => e.event.id == entryId)
          .firstOrNull;
      if (entry == null) {
        _set(read: read, status: SubmissionStatus.blocked);
        return;
      }
      _set(read: read, playing: entry.video, playingEntryId: entry.event.id);
    });
  }

  void stopPlaying() {
    _playRequest++;
    _set(busy: state.busy);
  }

  Future<void> chooseVideo() => _run(() async {
    final page =
        await loadCandidatePage?.call(null) ??
        ChallengeCandidatePage(videos: await loadCandidates());
    _nextCandidateOffset = page.nextOffset;
    _set(
      candidates: page.videos,
      picking: true,
      candidatesHaveMore: _nextCandidateOffset != null,
    );
  });
  Future<void> moreVideos() {
    if (state.busy ||
        !state.picking ||
        _nextCandidateOffset == null ||
        loadCandidatePage == null) {
      return Future.value();
    }
    return _run(() async {
      final offset = _nextCandidateOffset!;
      final page = await loadCandidatePage!(offset);
      _nextCandidateOffset =
          page.nextOffset != null && page.nextOffset! > offset
          ? page.nextOffset
          : null;
      final seen = <String>{};
      _set(
        candidates: [
          ...state.candidates,
          ...page.videos,
        ].where((v) => seen.add(v.id)).toList(),
        picking: true,
        candidatesHaveMore: _nextCandidateOffset != null,
      );
    }, keepPickingOnFailure: true);
  }

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
