// ABOUTME: Unit tests for VideoDmOutbox, the per-account owner of outgoing
// ABOUTME: video DMs: queueing, phases, upload progress, outcomes and dispose.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_send_service.dart';
import 'package:openvine/services/video_dm_outbox.dart';

class _MockDmVideoSendService extends Mock implements DmVideoSendService {}

/// One `sendVideo` call the test drives by hand.
class _PendingSend {
  _PendingSend({
    required this.videoFile,
    required this.mimeType,
    required this.onPhase,
    required this.onUploadProgress,
  });

  final File videoFile;
  final String mimeType;
  final void Function(DmVideoSendPhase phase)? onPhase;
  final void Function(double fraction)? onUploadProgress;
  final Completer<NIP17SendResult> completer = Completer<NIP17SendResult>();
}

const _recipientPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

NIP17SendResult _success(String rumorEventId) => NIP17SendResult.success(
  rumorEventId: rumorEventId,
  messageEventId: 'wrap-$rumorEventId',
  recipientPubkey: _recipientPubkey,
);

void main() {
  late _MockDmVideoSendService service;
  late List<_PendingSend> sends;
  late DmVideoCardFrameReader readFrame;
  late VideoDmOutbox outbox;
  var idCounter = 0;

  setUpAll(() {
    registerFallbackValue(File('/tmp/fallback.mp4'));
    registerFallbackValue((DmVideoSendPhase _) {});
    registerFallbackValue((double _) {});
  });

  setUp(() {
    service = _MockDmVideoSendService();
    sends = [];
    readFrame = (_) async => null;
    idCounter = 0;
  });

  VideoDmOutbox createOutbox() {
    final created = VideoDmOutbox(
      sendService: () => service,
      readFrame: (file) => readFrame(file),
      newId: () => 'entry-${idCounter++}',
      now: () => DateTime.utc(2026, 11, 13),
    );
    addTearDown(created.dispose);
    return created;
  }

  When<Future<NIP17SendResult>> whenSendVideo() => when(
    () => service.sendVideo(
      recipientPubkey: any(named: 'recipientPubkey'),
      videoFile: any(named: 'videoFile'),
      mimeType: any(named: 'mimeType'),
      onPhase: any(named: 'onPhase'),
      onUploadProgress: any(named: 'onUploadProgress'),
    ),
  );

  void stubControlledSend() {
    whenSendVideo().thenAnswer((invocation) {
      final send = _PendingSend(
        videoFile: invocation.namedArguments[#videoFile] as File,
        mimeType: invocation.namedArguments[#mimeType] as String,
        onPhase:
            invocation.namedArguments[#onPhase]
                as void Function(DmVideoSendPhase)?,
        onUploadProgress:
            invocation.namedArguments[#onUploadProgress]
                as void Function(double)?,
      );
      sends.add(send);
      return send.completer.future;
    });
  }

  void sendVideo({String conversationId = 'c1', String path = '/v/a.mp4'}) =>
      outbox.sendVideo(
        conversationId: conversationId,
        recipientPubkey: _recipientPubkey,
        file: File(path),
      );

  List<List<OutgoingVideoDm>> recordConversation(String conversationId) {
    final events = <List<OutgoingVideoDm>>[];
    final subscription = outbox
        .watchConversation(conversationId)
        .listen(events.add);
    addTearDown(subscription.cancel);
    return events;
  }

  List<VideoDmSendOutcome> recordOutcomes() {
    final outcomes = <VideoDmSendOutcome>[];
    final subscription = outbox.outcomes.listen(outcomes.add);
    addTearDown(subscription.cancel);
    return outcomes;
  }

  group(VideoDmOutbox, () {
    group('sendVideo', () {
      setUp(() {
        stubControlledSend();
        outbox = createOutbox();
      });

      test('adds a queued entry synchronously, before any await', () async {
        sendVideo(path: '/v/picked.mp4');
        final events = recordConversation('c1');
        await pumpEventQueue(times: 1);

        expect(events, isNotEmpty);
        final entry = events.first.single;
        expect(entry.localPath, equals('/v/picked.mp4'));
        expect(entry.recipientPubkey, equals(_recipientPubkey));
        expect(entry.conversationId, equals('c1'));
        expect(entry.requestedAt, equals(DateTime.utc(2026, 11, 13)));
        expect(
          entry.phase,
          isIn([OutgoingVideoDmPhase.queued, OutgoingVideoDmPhase.encrypting]),
        );
      });

      test('passes the recipient, file and MIME type to the send service', () {
        sendVideo(path: '/v/picked.MOV');

        expect(sends, hasLength(1));
        expect(sends.single.videoFile.path, equals('/v/picked.MOV'));
        expect(sends.single.mimeType, equals('video/quicktime'));
        verify(
          () => service.sendVideo(
            recipientPubkey: _recipientPubkey,
            videoFile: any(named: 'videoFile'),
            mimeType: any(named: 'mimeType'),
            onPhase: any(named: 'onPhase'),
            onUploadProgress: any(named: 'onUploadProgress'),
          ),
        ).called(1);
      });

      test(
        'walks encrypting → uploading with progress → publishing → sent',
        () async {
          final events = recordConversation('c1');
          sendVideo();
          await pumpEventQueue();

          final send = sends.single;
          send.onPhase!(DmVideoSendPhase.encrypting);
          send.onPhase!(DmVideoSendPhase.uploading);
          send.onUploadProgress!(0.4);
          send.onPhase!(DmVideoSendPhase.sending);
          send.completer.complete(_success('r1'));
          await pumpEventQueue();

          final steps = [
            for (final entries in events)
              if (entries.isNotEmpty)
                (entries.single.phase, entries.single.uploadProgress),
          ];
          expect(
            steps,
            equals([
              (OutgoingVideoDmPhase.queued, null),
              (OutgoingVideoDmPhase.encrypting, null),
              (OutgoingVideoDmPhase.uploading, null),
              (OutgoingVideoDmPhase.uploading, 0.4),
              (OutgoingVideoDmPhase.publishing, null),
              (OutgoingVideoDmPhase.sent, null),
            ]),
          );
          final sent = events.last.single;
          expect(sent.rumorEventId, equals('r1'));
          expect(sent.failure, isNull);
        },
      );

      test('emits one sent outcome', () async {
        final outcomes = recordOutcomes();
        sendVideo();
        await pumpEventQueue();

        sends.single.completer.complete(_success('r1'));
        await pumpEventQueue();

        expect(
          outcomes,
          equals([
            const VideoDmSendOutcome(
              status: VideoDmOutcomeStatus.sent,
              sentCount: 1,
              total: 1,
            ),
          ]),
        );
        expect(outcomes.single.isPartial, isFalse);
      });

      test('runs one send at a time', () async {
        final events = recordConversation('c1');
        sendVideo(path: '/v/first.mp4');
        sendVideo(path: '/v/second.mp4');
        await pumpEventQueue();

        expect(events.last, hasLength(2));
        expect(events.last[1].localPath, equals('/v/second.mp4'));
        expect(events.last[1].phase, equals(OutgoingVideoDmPhase.queued));
        expect(sends, hasLength(1));
        expect(sends.single.videoFile.path, equals('/v/first.mp4'));

        sends.single.completer.complete(_success('r1'));
        await pumpEventQueue();

        expect(sends, hasLength(2));
        expect(sends[1].videoFile.path, equals('/v/second.mp4'));
        expect(events.last[0].phase, equals(OutgoingVideoDmPhase.sent));
        expect(events.last[1].phase, isNot(OutgoingVideoDmPhase.queued));
      });

      test('a late subscriber gets the current entries', () async {
        sendVideo();
        await pumpEventQueue();
        sends.single.onPhase!(DmVideoSendPhase.uploading);
        sends.single.onUploadProgress!(0.4);
        await pumpEventQueue();

        final events = recordConversation('c1');
        await pumpEventQueue();

        expect(events, isNotEmpty);
        expect(events.first.single.phase, OutgoingVideoDmPhase.uploading);
        expect(events.first.single.uploadProgress, equals(0.4));
      });

      test('maps DmVideoTooLargeException to failed(tooLarge)', () async {
        whenSendVideo().thenThrow(const DmVideoTooLargeException(1 << 30));
        final events = recordConversation('c1');
        final outcomes = recordOutcomes();

        sendVideo();
        await pumpEventQueue();

        final entry = events.last.single;
        expect(entry.phase, equals(OutgoingVideoDmPhase.failed));
        expect(entry.failure, equals(OutgoingVideoDmFailure.tooLarge));
        expect(entry.canRetry, isFalse);
        expect(
          outcomes,
          equals([
            const VideoDmSendOutcome(
              status: VideoDmOutcomeStatus.tooLarge,
              sentCount: 0,
              total: 1,
            ),
          ]),
        );
      });

      test('maps a failure result to failed(failed)', () async {
        final events = recordConversation('c1');
        final outcomes = recordOutcomes();
        sendVideo();
        await pumpEventQueue();

        sends.single.completer.complete(
          const NIP17SendResult.failure('relay rejected'),
        );
        await pumpEventQueue();

        final entry = events.last.single;
        expect(entry.phase, equals(OutgoingVideoDmPhase.failed));
        expect(entry.failure, equals(OutgoingVideoDmFailure.failed));
        expect(entry.rumorEventId, isNull);
        expect(entry.canRetry, isTrue);
        expect(
          outcomes,
          equals([
            const VideoDmSendOutcome(
              status: VideoDmOutcomeStatus.failed,
              sentCount: 0,
              total: 1,
            ),
          ]),
        );
      });

      test(
        'maps an unconfirmed (retryablePending) result to failed(failed)',
        () async {
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();
          sendVideo();
          await pumpEventQueue();

          sends.single.completer.complete(
            const NIP17SendResult.failure('no OK', retryablePending: true),
          );
          await pumpEventQueue();

          final entry = events.last.single;
          expect(entry.phase, equals(OutgoingVideoDmPhase.failed));
          expect(entry.failure, equals(OutgoingVideoDmFailure.failed));
          expect(entry.canRetry, isTrue);
          expect(outcomes.single.status, equals(VideoDmOutcomeStatus.failed));
        },
      );

      test('a missing file ends failed, not thrown', () async {
        whenSendVideo().thenAnswer(
          (_) async => throw const FileSystemException(
            'Cannot open file',
            '/v/missing.mp4',
          ),
        );
        final events = recordConversation('c1');
        final outcomes = recordOutcomes();

        sendVideo(path: '/v/missing.mp4');
        await pumpEventQueue();

        final entry = events.last.single;
        expect(entry.phase, equals(OutgoingVideoDmPhase.failed));
        expect(entry.failure, equals(OutgoingVideoDmFailure.failed));
        expect(entry.canRetry, isTrue);
        expect(outcomes.single.status, equals(VideoDmOutcomeStatus.failed));
      });

      test('an unexpected error ends failed, not thrown', () async {
        whenSendVideo().thenThrow(StateError('invariant broken'));
        final events = recordConversation('c1');

        sendVideo();
        await pumpEventQueue();

        final entry = events.last.single;
        expect(entry.phase, equals(OutgoingVideoDmPhase.failed));
        expect(entry.failure, equals(OutgoingVideoDmFailure.failed));
      });

      test('stores the card frame read from the file', () async {
        final frame = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
        final readPaths = <String>[];
        readFrame = (file) async {
          readPaths.add(file.path);
          return frame;
        };
        final events = recordConversation('c1');

        sendVideo(path: '/v/framed.mp4');
        await pumpEventQueue();

        expect(readPaths, equals(['/v/framed.mp4']));
        expect(events.last.single.frame, equals(frame));
        expect(events.last.single.phase, isNot(OutgoingVideoDmPhase.sent));
      });

      test('a frame that cannot be read leaves frame null', () async {
        final events = recordConversation('c1');
        sendVideo();
        await pumpEventQueue();

        sends.single.completer.complete(_success('r1'));
        await pumpEventQueue();

        expect(events.last.single.frame, isNull);
        expect(events.last.single.phase, equals(OutgoingVideoDmPhase.sent));
      });

      test(
        'dispose drops entries and ignores a send that finishes afterwards',
        () async {
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();
          sendVideo();
          await pumpEventQueue();
          final send = sends.single;
          final eventCount = events.length;

          outbox.dispose();
          send.onPhase!(DmVideoSendPhase.uploading);
          send.onUploadProgress!(0.5);
          send.completer.complete(_success('r1'));
          await pumpEventQueue();

          expect(events, hasLength(eventCount));
          expect(outcomes, isEmpty);

          sendVideo(path: '/v/after-dispose.mp4');
          await pumpEventQueue();
          expect(sends, hasLength(1));
        },
      );

      test('keeps conversations separate', () async {
        final c1Events = recordConversation('c1');
        final c2Events = recordConversation('c2');

        sendVideo(conversationId: 'c2', path: '/v/for-c2.mp4');
        await pumpEventQueue();
        expect(c1Events.where((entries) => entries.isNotEmpty), isEmpty);

        sendVideo(path: '/v/for-c1.mp4');
        await pumpEventQueue();

        expect(c1Events.last.single.localPath, equals('/v/for-c1.mp4'));
        expect(c2Events.last.single.localPath, equals('/v/for-c2.mp4'));
      });
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

  group(OutgoingVideoDm, () {
    OutgoingVideoDm entry({
      OutgoingVideoDmPhase phase = OutgoingVideoDmPhase.failed,
      OutgoingVideoDmFailure? failure,
    }) => OutgoingVideoDm(
      id: 'e1',
      conversationId: 'c1',
      recipientPubkey: _recipientPubkey,
      localPath: '/v/a.mp4',
      requestedAt: DateTime.utc(2026, 11, 13),
      phase: phase,
      failure: failure,
    );

    test('canRetry only for a failed entry whose failure is failed', () {
      expect(entry(failure: OutgoingVideoDmFailure.failed).canRetry, isTrue);
      expect(
        entry(failure: OutgoingVideoDmFailure.tooLarge).canRetry,
        isFalse,
      );
      expect(
        entry(failure: OutgoingVideoDmFailure.clipNotVerified).canRetry,
        isFalse,
      );
      expect(entry(phase: OutgoingVideoDmPhase.sent).canRetry, isFalse);
    });

    test('copyWith can clear uploadProgress', () {
      final uploading = entry(
        phase: OutgoingVideoDmPhase.uploading,
      ).copyWith(uploadProgress: () => 0.4);
      expect(uploading.uploadProgress, equals(0.4));

      final cleared = uploading.copyWith(
        phase: OutgoingVideoDmPhase.publishing,
        uploadProgress: () => null,
      );
      expect(cleared.uploadProgress, isNull);
      expect(cleared.phase, equals(OutgoingVideoDmPhase.publishing));
      expect(cleared.localPath, equals(uploading.localPath));
    });
  });

  group(VideoDmSendOutcome, () {
    test('isPartial when some but not all went out', () {
      expect(
        const VideoDmSendOutcome(
          status: VideoDmOutcomeStatus.failed,
          sentCount: 1,
          total: 3,
        ).isPartial,
        isTrue,
      );
      expect(
        const VideoDmSendOutcome(
          status: VideoDmOutcomeStatus.failed,
          sentCount: 0,
          total: 3,
        ).isPartial,
        isFalse,
      );
      expect(
        const VideoDmSendOutcome(
          status: VideoDmOutcomeStatus.sent,
          sentCount: 3,
          total: 3,
        ).isPartial,
        isFalse,
      );
    });
  });
}
