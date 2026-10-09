// ABOUTME: Unit tests for VideoDmSendCubit.
// ABOUTME: Verifies the encrypting -> uploading -> sending -> sent progress
// ABOUTME: states, the failure and too-large paths, and the double-send guard.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/video_dm_send/video_dm_send_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_send_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockDmVideoSendService extends Mock implements DmVideoSendService {}

class _MockClipProvenanceVerifier extends Mock
    implements ClipProvenanceVerifier {}

DivineVideoClip _clip(String id, {AspectRatio aspect = AspectRatio.square}) =>
    DivineVideoClip(
      id: id,
      video: EditorVideo.file('/documents/$id.mp4'),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime.utc(2026, 9, 28),
      targetAspectRatio: aspect,
      originalAspectRatio: 9 / 16,
    );

const _recipientPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  late _MockDmVideoSendService service;
  late File videoFile;

  setUpAll(() {
    registerFallbackValue(File('/tmp/fallback.mp4'));
    registerFallbackValue((DmVideoSendPhase _) {});
  });

  setUp(() {
    service = _MockDmVideoSendService();
    videoFile = File('clip.mp4');
  });

  VideoDmSendCubit createCubit() => VideoDmSendCubit(service: service);

  void stubSend({
    required List<DmVideoSendPhase> phases,
    required NIP17SendResult result,
  }) {
    when(
      () => service.sendVideo(
        recipientPubkey: any(named: 'recipientPubkey'),
        videoFile: any(named: 'videoFile'),
        mimeType: any(named: 'mimeType'),
        onPhase: any(named: 'onPhase'),
      ),
    ).thenAnswer((invocation) async {
      final onPhase =
          invocation.namedArguments[#onPhase]
              as void Function(DmVideoSendPhase)?;
      if (onPhase != null) phases.forEach(onPhase);
      return result;
    });
  }

  group(VideoDmSendState, () {
    test('isSending is true only for the in-flight stages', () {
      for (final status in VideoDmSendStatus.values) {
        final sending = VideoDmSendState(status: status).isSending;
        expect(
          sending,
          switch (status) {
            VideoDmSendStatus.checking ||
            VideoDmSendStatus.encrypting ||
            VideoDmSendStatus.uploading ||
            VideoDmSendStatus.sending => isTrue,
            VideoDmSendStatus.idle ||
            VideoDmSendStatus.sent ||
            VideoDmSendStatus.tooLarge ||
            VideoDmSendStatus.clipNotVerified ||
            VideoDmSendStatus.failed => isFalse,
          },
        );
      }
    });
  });

  group('send', () {
    test('send drives encrypting -> uploading -> sending -> sent', () async {
      stubSend(
        phases: DmVideoSendPhase.values,
        result: NIP17SendResult.success(
          rumorEventId: 'rumor-1',
          messageEventId: 'wrap-1',
          recipientPubkey: _recipientPubkey,
        ),
      );

      final cubit = createCubit();
      addTearDown(cubit.close);
      final statuses = <VideoDmSendStatus>[];
      cubit.stream.listen((state) => statuses.add(state.status));

      await cubit.send(recipientPubkey: _recipientPubkey, videoFile: videoFile);
      await pumpEventQueue();

      expect(statuses, [
        VideoDmSendStatus.encrypting,
        VideoDmSendStatus.uploading,
        VideoDmSendStatus.sending,
        VideoDmSendStatus.sent,
      ]);
      expect(cubit.state.status, VideoDmSendStatus.sent);
    });

    test('a refused send ends in failed', () async {
      stubSend(
        phases: DmVideoSendPhase.values,
        result: const NIP17SendResult.failure('encrypted upload failed'),
      );

      final cubit = createCubit();
      addTearDown(cubit.close);

      await cubit.send(recipientPubkey: _recipientPubkey, videoFile: videoFile);
      await pumpEventQueue();

      expect(cubit.state.status, VideoDmSendStatus.failed);
    });

    test('an oversized file ends in tooLarge', () async {
      when(
        () => service.sendVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          videoFile: any(named: 'videoFile'),
          mimeType: any(named: 'mimeType'),
          onPhase: any(named: 'onPhase'),
        ),
      ).thenThrow(const DmVideoTooLargeException(200 * 1024 * 1024));

      final cubit = createCubit();
      addTearDown(cubit.close);

      await cubit.send(recipientPubkey: _recipientPubkey, videoFile: videoFile);
      await pumpEventQueue();

      expect(cubit.state.status, VideoDmSendStatus.tooLarge);
    });

    test('a thrown send error ends in failed', () async {
      when(
        () => service.sendVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          videoFile: any(named: 'videoFile'),
          mimeType: any(named: 'mimeType'),
          onPhase: any(named: 'onPhase'),
        ),
      ).thenThrow(StateError('boom'));

      final cubit = createCubit();
      addTearDown(cubit.close);

      await cubit.send(recipientPubkey: _recipientPubkey, videoFile: videoFile);

      expect(cubit.state.status, VideoDmSendStatus.failed);
    });

    test('a second send while one is in flight is dropped', () async {
      final firstSendGate = Completer<void>();
      when(
        () => service.sendVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          videoFile: any(named: 'videoFile'),
          mimeType: any(named: 'mimeType'),
          onPhase: any(named: 'onPhase'),
        ),
      ).thenAnswer((invocation) async {
        await firstSendGate.future;
        return NIP17SendResult.success(
          rumorEventId: 'rumor-1',
          messageEventId: 'wrap-1',
          recipientPubkey: _recipientPubkey,
        );
      });

      final cubit = createCubit();
      addTearDown(cubit.close);

      final first = cubit.send(
        recipientPubkey: _recipientPubkey,
        videoFile: videoFile,
      );
      await cubit.send(
        recipientPubkey: _recipientPubkey,
        videoFile: videoFile,
      );

      firstSendGate.complete();
      await first;

      verify(
        () => service.sendVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          videoFile: any(named: 'videoFile'),
          mimeType: any(named: 'mimeType'),
          onPhase: any(named: 'onPhase'),
        ),
      ).called(1);
    });
  });

  group(videoDmMimeTypeFor, () {
    test('maps known video extensions to their MIME type', () {
      expect(videoDmMimeTypeFor('/clips/a.mp4'), 'video/mp4');
      expect(videoDmMimeTypeFor('/clips/a.MOV'), 'video/quicktime');
      expect(videoDmMimeTypeFor('/clips/a.m4v'), 'video/x-m4v');
      expect(videoDmMimeTypeFor('/clips/a.webm'), 'video/webm');
      expect(videoDmMimeTypeFor('/clips/a.mkv'), 'video/x-matroska');
    });

    test('falls back to video/mp4 for an unknown extension', () {
      expect(videoDmMimeTypeFor('/clips/a.unknown'), 'video/mp4');
      expect(videoDmMimeTypeFor('/clips/noextension'), 'video/mp4');
    });
  });

  group('sendClips', () {
    late _MockClipProvenanceVerifier verifier;
    late List<List<List<String>>> sentTags;
    late List<String> sentPaths;

    setUp(() {
      verifier = _MockClipProvenanceVerifier();
      sentTags = [];
      sentPaths = [];
      when(
        () => service.sendVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          videoFile: any(named: 'videoFile'),
          mimeType: any(named: 'mimeType'),
          extraTags: any(named: 'extraTags'),
          onPhase: any(named: 'onPhase'),
        ),
      ).thenAnswer((invocation) async {
        sentPaths.add((invocation.namedArguments[#videoFile] as File).path);
        sentTags.add(
          invocation.namedArguments[#extraTags] as List<List<String>>,
        );
        return NIP17SendResult.success(
          rumorEventId: 'rumor-${sentPaths.length}',
          messageEventId: 'wrap-${sentPaths.length}',
          recipientPubkey: _recipientPubkey,
        );
      });
    });

    VideoDmSendCubit createClipCubit() =>
        VideoDmSendCubit(service: service, clipVerifier: verifier);

    test(
      'checks each clip, then sends it marked as a clip with its crop',
      () async {
        when(() => verifier.verify(any())).thenAnswer(
          (_) async =>
              const ClipProvenanceResult(ClipProvenanceStatus.verified),
        );
        final cubit = createClipCubit();
        addTearDown(cubit.close);

        final outcome = await cubit.sendClips(
          recipientPubkey: _recipientPubkey,
          clips: [
            _clip('clip-a'),
            _clip('clip-b', aspect: AspectRatio.vertical),
          ],
        );

        expect(
          outcome,
          const ClipSendOutcome(
            VideoDmSendStatus.sent,
            sentCount: 2,
            total: 2,
          ),
        );
        expect(cubit.state.status, VideoDmSendStatus.idle);
        expect(sentPaths, ['/documents/clip-a.mp4', '/documents/clip-b.mp4']);
        expect(sentTags, [
          [
            ['divine-clip', 'square'],
          ],
          [
            ['divine-clip', 'vertical'],
          ],
        ]);
      },
    );

    test('a clip that fails the check is never uploaded', () async {
      when(() => verifier.verify(any())).thenAnswer(
        (_) async =>
            const ClipProvenanceResult(ClipProvenanceStatus.noCredentials),
      );
      final cubit = createClipCubit();
      addTearDown(cubit.close);

      final outcome = await cubit.sendClips(
        recipientPubkey: _recipientPubkey,
        clips: [_clip('clip-a')],
      );

      expect(outcome?.status, VideoDmSendStatus.clipNotVerified);
      expect(sentPaths, isEmpty);
    });

    test('a failing clip keeps the clips before it from going out', () async {
      when(() => verifier.verify('/documents/clip-a.mp4')).thenAnswer(
        (_) async => const ClipProvenanceResult(ClipProvenanceStatus.verified),
      );
      when(() => verifier.verify('/documents/clip-b.mp4')).thenAnswer(
        (_) async =>
            const ClipProvenanceResult(ClipProvenanceStatus.noCredentials),
      );
      final cubit = createClipCubit();
      addTearDown(cubit.close);

      final outcome = await cubit.sendClips(
        recipientPubkey: _recipientPubkey,
        clips: [_clip('clip-a'), _clip('clip-b')],
      );

      expect(outcome?.status, VideoDmSendStatus.clipNotVerified);
      expect(sentPaths, isEmpty);
    });

    test(
      'a check that cannot run leaves the decision to the recipient',
      () async {
        when(() => verifier.verify(any())).thenAnswer(
          (_) async =>
              const ClipProvenanceResult(ClipProvenanceStatus.unavailable),
        );
        final cubit = createClipCubit();
        addTearDown(cubit.close);

        final outcome = await cubit.sendClips(
          recipientPubkey: _recipientPubkey,
          clips: [_clip('clip-a')],
        );

        expect(outcome?.status, VideoDmSendStatus.sent);
        expect(sentPaths, ['/documents/clip-a.mp4']);
      },
    );

    test('reports how many clips went out when a later send fails', () async {
      when(() => verifier.verify(any())).thenAnswer(
        (_) async => const ClipProvenanceResult(ClipProvenanceStatus.verified),
      );
      when(
        () => service.sendVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          videoFile: any(named: 'videoFile'),
          mimeType: any(named: 'mimeType'),
          extraTags: any(named: 'extraTags'),
          onPhase: any(named: 'onPhase'),
        ),
      ).thenAnswer((invocation) async {
        final path = (invocation.namedArguments[#videoFile] as File).path;
        sentPaths.add(path);
        return path.endsWith('clip-a.mp4')
            ? NIP17SendResult.success(
                rumorEventId: 'rumor-1',
                messageEventId: 'wrap-1',
                recipientPubkey: _recipientPubkey,
              )
            : const NIP17SendResult.failure('relay rejected the wrap');
      });
      final cubit = createClipCubit();
      addTearDown(cubit.close);

      final outcome = await cubit.sendClips(
        recipientPubkey: _recipientPubkey,
        clips: [_clip('clip-a'), _clip('clip-b'), _clip('clip-c')],
      );

      expect(
        outcome,
        const ClipSendOutcome(
          VideoDmSendStatus.failed,
          sentCount: 1,
          total: 3,
        ),
      );
      expect(outcome!.isPartial, isTrue);
      expect(sentPaths, ['/documents/clip-a.mp4', '/documents/clip-b.mp4']);
    });

    test('finishes sending after the chat closes', () async {
      final check = Completer<ClipProvenanceResult>();
      when(() => verifier.verify(any())).thenAnswer((_) => check.future);
      final cubit = createClipCubit();

      final outcome = cubit.sendClips(
        recipientPubkey: _recipientPubkey,
        clips: [_clip('clip-a'), _clip('clip-b')],
      );
      await pumpEventQueue();
      await cubit.close();
      check.complete(
        const ClipProvenanceResult(ClipProvenanceStatus.verified),
      );

      expect(
        await outcome,
        const ClipSendOutcome(
          VideoDmSendStatus.sent,
          sentCount: 2,
          total: 2,
        ),
      );
      expect(sentPaths, ['/documents/clip-a.mp4', '/documents/clip-b.mp4']);
    });
  });
}
