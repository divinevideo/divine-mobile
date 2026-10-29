import 'dart:async';
import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart' as cp;
import 'package:challenges_repository/challenges_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_video_tile.dart';
import 'package:openvine/observability/reportable_error.dart';

import '../../../packages/challenges_repository/test/harness.dart';

class _ErrorObserver extends BlocObserver {
  final errors = <Object>[];
  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    errors.add(error);
  }
}

void main() {
  late Harness h;
  late ChallengeParticipationCubit cubit;
  setUp(() {
    h = Harness();
    cubit = ChallengeParticipationCubit(
      coordinate: '31923:${h.organizer.pubkey}:synthetic:challenge',
      submissions: h.repository,
      refresh: () =>
          h.reads.refresh('31923:${h.organizer.pubkey}:synthetic:challenge'),
      loadCandidates: () async => [],
      exactVideo: (id) async => id == h.video.id ? h.video : null,
      clientTags: () async => [],
      prepareRecording: (_) async => 'recording',
      handoffs: () async => [],
      reviewPublished: (_) => h.prepare(),
    );
  });
  tearDown(() => cubit.close());
  group('challenge_participation_cubit', () {
    for (final error in <Object>[
      const SubmissionException(SubmissionStatus.ownerChanged),
      TimeoutException('Synthetic read timed out'),
      StateError('Synthetic invariant'),
      RangeError('Synthetic range'),
      TypeError(),
    ]) {
      test(
        'reports ${error.runtimeType} with the existing classification',
        () async {
          final originalObserver = Bloc.observer;
          final observer = _ErrorObserver();
          Bloc.observer = observer;
          addTearDown(() {
            Bloc.observer = originalObserver;
          });
          final observed = ChallengeParticipationCubit(
            coordinate: cubit.coordinate,
            submissions: h.repository,
            refresh: () async => throw error,
            loadCandidates: cubit.loadCandidates,
            exactVideo: cubit.exactVideo,
            clientTags: cubit.clientTags,
            prepareRecording: cubit.prepareRecording,
            handoffs: cubit.handoffs,
            reviewPublished: cubit.reviewPublished,
          );
          addTearDown(observed.close);
          await observed.load();
          expect(observer.errors, hasLength(1));
          if (error is StateError ||
              error is TypeError ||
              error is RangeError) {
            expect(
              observer.errors.single,
              isA<Reportable<Object>>().having(
                (e) => e.unwrap(),
                'original invariant',
                same(error),
              ),
            );
          } else {
            expect(observer.errors.single, same(error));
            expect(observer.errors.single, isNot(isA<ReportableError>()));
          }
          expect(
            observed.state.status,
            error is SubmissionException
                ? error.status
                : SubmissionStatus.readUnavailable,
          );
          expect(observed.state.reviewPreviewAllowed, isFalse);
          expect(h.signatures, 0);
        },
      );
    }
    test('queued renewal immediately revokes preview permission', () async {
      await cubit.selectVideo(h.video.id);
      final review = cubit.state.review;
      final entered = Completer<void>();
      final release = Completer<void>();
      final other = ChallengeParticipationCubit(
        coordinate: cubit.coordinate,
        submissions: h.repository,
        refresh: () async {
          entered.complete();
          await release.future;
          return cubit.refresh();
        },
        loadCandidates: cubit.loadCandidates,
        exactVideo: cubit.exactVideo,
        clientTags: cubit.clientTags,
        prepareRecording: cubit.prepareRecording,
        handoffs: cubit.handoffs,
        reviewPublished: cubit.reviewPublished,
      );
      addTearDown(other.close);
      final blocked = other.load();
      await entered.future;
      final renewal = cubit.refreshReview();
      try {
        expect(cubit.state.busy, isTrue);
        expect(cubit.state.reviewPreviewAllowed, isFalse);
        expect(cubit.state.review, same(review));
        expect(h.signatures, 0);
      } finally {
        release.complete();
        await blocked;
        await renewal;
      }
    });
    test(
      'selection needs review; retry and restart retain exact signed action',
      () async {
        await cubit.load();
        await cubit.selectVideo(h.video.id);
        expect(cubit.state.review!.video.id, h.video.id);
        expect(h.signatures, 0);
        await cubit.confirm();
        expect(cubit.state.status, SubmissionStatus.retryable);
        final body = cubit.state.actions.single.signedBody;
        await cubit.retry(cubit.state.actions.single.review.id);
        expect(cubit.state.actions.single.signedBody, body);
        expect(h.signatures, 1);
        await cubit.load();
        expect(cubit.state.actions.single.signedBody, body);
      },
    );
    test(
      'playback rechecks current policy on the exact pinned entry',
      () async {
        await cubit.load();
        await cubit.selectVideo(h.video.id);
        await cubit.confirm();
        final action = cubit.state.actions.single;
        h.source.records.add(action.signedBody);
        final entryId =
            (jsonDecode(action.signedBody) as Map<String, dynamic>)['id']
                as String;
        await cubit.playEntry(entryId);
        expect(cubit.state.playing?.id, h.video.id);
        h.hidden.add(h.video.id);
        await cubit.playEntry(entryId);
        expect(cubit.state.playing, isNull);
        expect(cubit.state.status, SubmissionStatus.blocked);
      },
    );
    test(
      'refresh keeps exact playback and Back prevents late reopening',
      () async {
        await cubit.selectVideo(h.video.id);
        await cubit.confirm();
        final body = cubit.state.actions.single.signedBody;
        h.source.records.add(body);
        final entryId =
            (jsonDecode(body) as Map<String, dynamic>)['id'] as String;
        await cubit.playEntry(entryId);
        await cubit.load();
        expect(cubit.state.playing?.id, h.video.id);
        expect(cubit.state.playingEntryId, entryId);
        final release = Completer<void>();
        final readStarted = Completer<void>();
        var delay = false;
        final delayed = ChallengeParticipationCubit(
          coordinate: cubit.coordinate,
          submissions: h.repository,
          refresh: () async {
            if (delay) {
              readStarted.complete();
              await release.future;
            }
            return cubit.refresh();
          },
          loadCandidates: cubit.loadCandidates,
          exactVideo: cubit.exactVideo,
          clientTags: cubit.clientTags,
          prepareRecording: cubit.prepareRecording,
          handoffs: cubit.handoffs,
          reviewPublished: cubit.reviewPublished,
        );
        addTearDown(delayed.close);
        await delayed.playEntry(entryId);
        delay = true;
        final refreshing = delayed.load();
        await readStarted.future;
        delayed.stopPlaying();
        release.complete();
        await refreshing;
        expect(delayed.state.playing, isNull);
        h.hidden.add(h.video.id);
        await cubit.load();
        expect(cubit.state.playing, isNull);
      },
    );
    test(
      'candidate pages retain cursor on failure and deduplicate exact IDs',
      () async {
        final older = cp.NostrEvent.fromJson(
          h.creator.sign(
            kind: 34236,
            tags: [
              ['d', 'synthetic:older'],
            ],
            content: 'Synthetic older video',
          ),
        );
        var fail = true;
        final offsets = <int?>[];
        final picker = ChallengeParticipationCubit(
          coordinate: cubit.coordinate,
          submissions: h.repository,
          refresh: cubit.refresh,
          loadCandidates: cubit.loadCandidates,
          loadCandidatePage: (offset) async {
            offsets.add(offset);
            if (offset == 20 && fail) throw TimeoutException('Synthetic page');
            return ChallengeCandidatePage(
              videos: [
                challengeVideoModel(h.video)!,
                if (offset != null) challengeVideoModel(older)!,
              ],
              nextOffset: offset == null ? 20 : null,
            );
          },
          exactVideo: (id) async => id == older.id ? older : h.video,
          clientTags: cubit.clientTags,
          prepareRecording: cubit.prepareRecording,
          handoffs: cubit.handoffs,
          reviewPublished: cubit.reviewPublished,
        );
        addTearDown(picker.close);
        await picker.chooseVideo();
        expect(picker.state.candidatesHaveMore, isTrue);
        await picker.moreVideos();
        expect(picker.state.picking, isTrue);
        expect(picker.state.candidates, hasLength(1));
        expect(picker.state.status, SubmissionStatus.readUnavailable);
        fail = false;
        await picker.moreVideos();
        expect(offsets, [null, 20, 20]);
        expect(picker.state.candidates, hasLength(2));
        expect(picker.state.candidatesHaveMore, isFalse);
        h.videoId = older.id;
        await picker.selectVideo(older.id);
        expect(picker.state.review?.video.id, older.id);
        expect(h.signatures, 0);
      },
    );
    test(
      'calendar without challenge marker cannot expose challenge rules',
      () async {
        h.source.records = [
          jsonEncode(
            h.organizer.sign(
              tags: [
                ['d', 'synthetic:challenge'],
                ['title', 'Ordinary calendar'],
                ['start', '100'],
                ['end', '200'],
              ],
            ),
          ),
        ];
        await cubit.load();
        expect(cubit.state.read!.view.definition, isNull);
        expect(cubit.state.read!.view.state, 'unavailable');
      },
    );
    test('wrong or unavailable exact revision cannot become consent', () async {
      await cubit.load();
      await cubit.selectVideo('ff' * 32);
      expect(cubit.state.review, isNull);
      expect(cubit.state.status, SubmissionStatus.reviewRequired);
      expect(h.signatures, 0);
    });
    test(
      'current rules changing after review requires another review',
      () async {
        await cubit.load();
        await cubit.selectVideo(h.video.id);
        h.source.records = [
          jsonEncode(
            h.organizer.definition(createdAt: 149, content: 'New rules'),
          ),
        ];
        await cubit.confirm();
        expect(cubit.state.status, SubmissionStatus.reviewRequired);
        expect(h.signatures, 0);
      },
    );
    test('withdrawal is separate explicit consent', () async {
      await cubit.load();
      await cubit.selectVideo(h.video.id);
      await cubit.confirm();
      final entry = cubit.state.actions.single;
      await cubit.withdraw(entry.signedBody);
      expect(cubit.state.review!.withdrawalEntry, isNotNull);
      expect(h.signatures, 1);
      await cubit.confirm();
      expect(h.signatures, 2);
      expect(cubit.state.actions, hasLength(2));
    });
    test(
      'echo from another page transport is queued until it settles',
      () async {
        final other = ChallengeParticipationCubit(
          coordinate: cubit.coordinate,
          submissions: h.repository,
          refresh: cubit.refresh,
          loadCandidates: cubit.loadCandidates,
          exactVideo: cubit.exactVideo,
          clientTags: cubit.clientTags,
          prepareRecording: cubit.prepareRecording,
          handoffs: cubit.handoffs,
          reviewPublished: cubit.reviewPublished,
        );
        addTearDown(other.close);
        await other.selectVideo(h.video.id);
        Future<void>? echo;
        h.transport.onPublish = () {
          final action = h.store.actions.values.single;
          echo = cubit.reconcile(
            action.review.id,
            action.signedBody,
            relay: h.relay,
          );
        };
        await other.confirm();
        await echo;
        expect(cubit.state.actions.single.echoed, isTrue);
        expect(cubit.state.status, SubmissionStatus.submitted);
      },
    );
    test('echo during transport waits and reconciles after delivery', () async {
      await cubit.load();
      await cubit.selectVideo(h.video.id);
      Future<void>? echo;
      h.transport.onPublish = () {
        final action = h.store.actions.values.single;
        echo = cubit.reconcile(
          action.review.id,
          action.signedBody,
          relay: h.relay,
        );
      };
      await cubit.confirm();
      await echo;
      expect(cubit.state.actions.single.echoed, isTrue);
      expect(cubit.state.status, SubmissionStatus.submitted);
    });
  });
}
