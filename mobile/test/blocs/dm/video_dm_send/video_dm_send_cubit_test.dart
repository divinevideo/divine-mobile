// ABOUTME: Unit tests for VideoDmSendCubit.
// ABOUTME: Verifies the encrypting -> uploading -> sending -> sent progress
// ABOUTME: states, the failure path, and the double-send guard.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/video_dm_send/video_dm_send_cubit.dart';
import 'package:openvine/services/dm_video_send_service.dart';

class _MockDmVideoSendService extends Mock implements DmVideoSendService {}

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

    await cubit.send(
      recipientPubkey: _recipientPubkey,
      videoFile: videoFile,
      mimeType: 'video/mp4',
    );
    await pumpEventQueue();

    expect(statuses, [
      VideoDmSendStatus.encrypting,
      VideoDmSendStatus.uploading,
      VideoDmSendStatus.sending,
      VideoDmSendStatus.sent,
    ]);
    expect(cubit.state.status, VideoDmSendStatus.sent);
    expect(cubit.state.error, isNull);
  });

  test('a refused send ends in failed with the service error', () async {
    stubSend(
      phases: DmVideoSendPhase.values,
      result: const NIP17SendResult.failure('encrypted upload failed'),
    );

    final cubit = createCubit();
    addTearDown(cubit.close);
    final statuses = <VideoDmSendStatus>[];
    cubit.stream.listen((state) => statuses.add(state.status));

    await cubit.send(
      recipientPubkey: _recipientPubkey,
      videoFile: videoFile,
      mimeType: 'video/mp4',
    );
    await pumpEventQueue();

    expect(statuses.last, VideoDmSendStatus.failed);
    expect(cubit.state.error, 'encrypted upload failed');
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

    await cubit.send(
      recipientPubkey: _recipientPubkey,
      videoFile: videoFile,
      mimeType: 'video/mp4',
    );

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
      mimeType: 'video/mp4',
    );
    await cubit.send(
      recipientPubkey: _recipientPubkey,
      videoFile: videoFile,
      mimeType: 'video/mp4',
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
}
