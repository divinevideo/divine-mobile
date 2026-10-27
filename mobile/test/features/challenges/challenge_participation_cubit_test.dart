import 'dart:convert';

import 'package:challenges_repository/challenges_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';

import '../../../packages/challenges_repository/test/harness.dart';

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
