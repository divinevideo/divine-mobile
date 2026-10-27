import 'dart:async';
import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show VideoEvent;

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
      ),
    );
  }

  Future<void> _run(Future<void> Function() work) {
    final next = (_queues[submissions] ?? Future<void>.value()).then((_) async {
      if (isClosed) return;
      _set(busy: true, review: state.review, picking: state.picking);
      try {
        await work();
      } on SubmissionException catch (error) {
        _set(status: error.status);
      } on Object {
        _set(status: SubmissionStatus.readUnavailable);
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
    _set(read: read, review: review);
  });
  Future<void> recover(String id) =>
      _run(() async => _set(review: await reviewPublished(id)));
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
