import 'dart:async';
import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/models/challenge_recording_context.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';

import '../../../packages/challenges_repository/test/synthetic.dart';

class _Drafts extends Mock implements DraftStorageService {}

void main() {
  group('successful challenge video handoff', () {
    test('handoff failure keeps successful video and durable published draft recovery', () async {
      final signer = SyntheticSigner();
      final context = ChallengeRecordingContext(
        generation: 'c' * 64,
        owner: signer.pubkey,
        definition: NostrEvent.fromJson(signer.definition()),
        recordingId: 'recording',
        clientTags: const [],
      );
      final draft = DivineVideoDraft.create(
        id: 'publish',
        clips: const [],
        title: '',
        description: '',
        hashtags: {},
        selectedApproach: 'video',
        challengeContext: context,
      );
      final body = jsonEncode(
        signer.sign(
          kind: 34236,
          tags: [
            ['d', 'synthetic-video'],
          ],
        ),
      );
      final saved = Completer<DivineVideoDraft>();
      final drafts = _Drafts();
      registerFallbackValue(draft);
      when(
        () => drafts.saveDraft(
          any(),
          deferOrphanCleanup: any(named: 'deferOrphanCleanup'),
        ),
      ).thenAnswer((call) async {
        saved.complete(call.positionalArguments.first as DivineVideoDraft);
      });
      final bloc = BackgroundPublishBloc(
        videoPublishServiceFactory: ({required onProgress}) async =>
            throw StateError('Must not upload again'),
        draftStorageService: drafts,
        challengeHandoff: (_, _) async => throw StateError('Disk unavailable'),
        challengeVideoSuccess: (value, signedVideo) async {
          saved.complete(
            value.copyWith(
              publishStatus: PublishStatus.published,
              publishedVideoEvent: signedVideo,
            ),
          );
        },
      );
      addTearDown(bloc.close);
      bloc.add(
        BackgroundPublishRequested(
          draft: draft,
          publishmentProcess: Future.value(
            PublishSuccess(signedEventBody: body),
          ),
        ),
      );
      final recovery = await saved.future;
      expect(recovery.publishStatus, PublishStatus.published);
      expect(recovery.publishedVideoEvent, body);
      expect(bloc.state.recentlyPublished.single.signedVideoBody, body);
      expect(bloc.state.uploads, isEmpty);
      verifyNever(() => drafts.deleteDraft(any()));
    });
    test('scheduled video never creates a challenge handoff', () async {
      final signer = SyntheticSigner();
      final context = ChallengeRecordingContext(
        generation: 'c' * 64,
        owner: signer.pubkey,
        definition: NostrEvent.fromJson(signer.definition()),
        recordingId: 'recording',
        clientTags: const [],
      );
      final draft = DivineVideoDraft.create(
        id: 'schedule',
        clips: const [],
        title: '',
        description: '',
        hashtags: {},
        selectedApproach: 'video',
        challengeContext: context,
      );
      final drafts = _Drafts();
      final scheduled = Completer<void>();
      when(
        () => drafts.updatePublishStatus(
          draftId: 'schedule',
          status: PublishStatus.scheduled,
        ),
      ).thenAnswer((_) async {
        scheduled.complete();
        return true;
      });
      var handoffs = 0;
      final bloc = BackgroundPublishBloc(
        videoPublishServiceFactory: ({required onProgress}) async =>
            throw StateError('Must not upload again'),
        draftStorageService: drafts,
        challengeHandoff: (_, _) async {
          handoffs++;
        },
      );
      addTearDown(bloc.close);
      bloc.add(
        BackgroundPublishRequested(
          draft: draft,
          publishmentProcess: Future.value(
            PublishScheduled(
              eventId: 'a' * 64,
              publishAt: DateTime(2030),
              submitted: true,
            ),
          ),
        ),
      );
      await scheduled.future;
      await bloc.close();
      expect(handoffs, 0);
      expect(bloc.state.recentlyPublished, isEmpty);
      verifyNever(() => drafts.deleteDraft('schedule'));
    });
    test(
      'draft cleanup waits for durable handoff while video success is visible',
      () async {
        final signer = SyntheticSigner();
        final context = ChallengeRecordingContext(
          generation: 'c' * 64,
          owner: signer.pubkey,
          definition: NostrEvent.fromJson(signer.definition()),
          recordingId: 'recording',
          clientTags: const [],
        );
        final draft = DivineVideoDraft.create(
          id: 'publish',
          clips: const [],
          title: '',
          description: '',
          hashtags: {},
          selectedApproach: 'video',
          challengeContext: context,
        );
        final body = jsonEncode(
          signer.sign(
            kind: 34236,
            tags: [
              ['d', 'synthetic-video'],
            ],
          ),
        );
        final saved = Completer<void>();
        final entered = Completer<void>();
        final drafts = _Drafts();
        when(() => drafts.deleteDraft(any())).thenAnswer((_) async {});
        final bloc = BackgroundPublishBloc(
          videoPublishServiceFactory: ({required onProgress}) async =>
              throw StateError('Must not upload again'),
          draftStorageService: drafts,
          challengeVideoSuccess: (_, _) async {},
          challengeDraftCleanup: (value) => drafts.deleteDraft(value.id),
          challengeHandoff: (value, signedVideo) async {
            expect(signedVideo, body);
            entered.complete();
            await saved.future;
          },
        );
        addTearDown(bloc.close);
        bloc.add(
          BackgroundPublishRequested(
            draft: draft,
            publishmentProcess: Future.value(
              PublishSuccess(signedEventBody: body),
            ),
          ),
        );
        await entered.future;
        expect(
          bloc.state.recentlyPublished.single.challengeEntryPending,
          isTrue,
        );
        expect(bloc.state.uploads, isEmpty);
        verifyNever(() => drafts.deleteDraft(any()));
        saved.complete();
        await bloc.close();
        verify(() => drafts.deleteDraft('publish')).called(1);
      },
    );
  });
}
