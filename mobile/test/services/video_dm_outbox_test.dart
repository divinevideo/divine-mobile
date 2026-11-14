// ABOUTME: Unit tests for VideoDmOutbox, the per-account owner of outgoing
// ABOUTME: video DMs: queueing, clip batches, progress, retry and outcomes.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_send_service.dart';
import 'package:openvine/services/video_dm_outbox.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockDmVideoSendService extends Mock implements DmVideoSendService {}

class _MockClipProvenanceVerifier extends Mock
    implements ClipProvenanceVerifier {}

/// Records every error the outbox forwards to crash reporting.
class _RecordingCrashReporter implements CrashReporter {
  final errors = <(Object error, String? reason)>[];

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    errors.add((error, reason));
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {}
}

/// One `sendVideo` call the test drives by hand.
class _PendingSend {
  _PendingSend({
    required this.videoFile,
    required this.mimeType,
    required this.extraTags,
    required this.onPhase,
    required this.onUploadProgress,
  });

  final File videoFile;
  final String mimeType;
  final List<List<String>> extraTags;
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

const _verified = ClipProvenanceResult(ClipProvenanceStatus.verified);
const _noCredentials = ClipProvenanceResult(
  ClipProvenanceStatus.noCredentials,
);

DivineVideoClip _clip(
  String id, {
  AspectRatio aspect = AspectRatio.square,
  bool hasFile = true,
}) => DivineVideoClip(
  id: id,
  // A network source has no local file to send.
  video: hasFile
      ? EditorVideo.file('/documents/$id.mp4')
      : EditorVideo.network('https://media.example/$id.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime.utc(2026, 9, 28),
  targetAspectRatio: aspect,
  originalAspectRatio: 9 / 16,
);

String _clipPath(String id) => '/documents/$id.mp4';

void main() {
  late _MockDmVideoSendService service;
  late List<_PendingSend> sends;
  late DmVideoCardFrameReader readFrame;
  late VideoDmOutbox outbox;
  late List<String> sentPaths;
  late List<List<List<String>>> sentTags;
  var idCounter = 0;

  setUpAll(() {
    registerFallbackValue(File('/tmp/fallback.mp4'));
    registerFallbackValue((DmVideoSendPhase _) {});
    registerFallbackValue((double _) {});
  });

  setUp(() {
    service = _MockDmVideoSendService();
    sends = [];
    sentPaths = [];
    sentTags = [];
    readFrame = (_) async => null;
    idCounter = 0;
  });

  VideoDmOutbox createOutbox({
    ClipProvenanceVerifier? Function()? clipVerifier,
    Future<void> Function(List<DivineVideoClip> clips)? signOwnRecordings,
    ArchivedVineCheck? isArchivedVine,
    CrashReporter? reporter,
  }) {
    final created = VideoDmOutbox(
      sendService: () => service,
      readFrame: (file) => readFrame(file),
      newId: () => 'entry-${idCounter++}',
      now: () => DateTime.utc(2026, 11, 13),
      clipVerifier: clipVerifier,
      signOwnRecordings: signOwnRecordings,
      isArchivedVine: isArchivedVine,
      reporter: reporter,
    );
    addTearDown(created.dispose);
    return created;
  }

  When<Future<NIP17SendResult>> whenSendVideo() => when(
    () => service.sendVideo(
      recipientPubkey: any(named: 'recipientPubkey'),
      videoFile: any(named: 'videoFile'),
      mimeType: any(named: 'mimeType'),
      extraTags: any(named: 'extraTags'),
      onPhase: any(named: 'onPhase'),
      onUploadProgress: any(named: 'onUploadProgress'),
    ),
  );

  /// Answers every send at once: with [answer] for its path when given,
  /// otherwise with a success. Records each path and its extra tags.
  void stubAutoSend([NIP17SendResult Function(String path)? answer]) {
    whenSendVideo().thenAnswer((invocation) async {
      final path = (invocation.namedArguments[#videoFile] as File).path;
      sentPaths.add(path);
      sentTags.add(
        invocation.namedArguments[#extraTags] as List<List<String>>,
      );
      if (answer != null) return answer(path);
      return _success('rumor-${sentPaths.length}');
    });
  }

  void stubControlledSend() {
    whenSendVideo().thenAnswer((invocation) {
      final send = _PendingSend(
        videoFile: invocation.namedArguments[#videoFile] as File,
        mimeType: invocation.namedArguments[#mimeType] as String,
        extraTags: invocation.namedArguments[#extraTags] as List<List<String>>,
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

  void sendClips(List<DivineVideoClip> clips) => outbox.sendClips(
    conversationId: 'c1',
    recipientPubkey: _recipientPubkey,
    clips: clips,
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

      test(
        'publishes upload progress only when the shown percent changes',
        () async {
          final events = recordConversation('c1');
          sendVideo();
          await pumpEventQueue();
          final send = sends.single;
          send.onPhase!(DmVideoSendPhase.uploading);
          await pumpEventQueue();
          final beforeProgress = events.length;

          [0.101, 0.102, 0.103, 0.104].forEach(send.onUploadProgress!);
          await pumpEventQueue();

          expect(events, hasLength(beforeProgress + 1));
          expect(events.last.single.uploadProgress, equals(0.101));

          send.onUploadProgress!(0.106);
          await pumpEventQueue();

          expect(events, hasLength(beforeProgress + 2));
          expect(events.last.single.uploadProgress, equals(0.106));
        },
      );

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

    group('sendClips', () {
      late _MockClipProvenanceVerifier verifier;

      setUp(() {
        verifier = _MockClipProvenanceVerifier();
        stubAutoSend();
      });

      List<(OutgoingVideoDmPhase, OutgoingVideoDmFailure?)> phasesOf(
        List<OutgoingVideoDm> entries,
      ) => [for (final entry in entries) (entry.phase, entry.failure)];

      test('an empty list is a no-op', () async {
        outbox = createOutbox(clipVerifier: () => verifier);
        final events = recordConversation('c1');
        final outcomes = recordOutcomes();

        sendClips(const []);
        await pumpEventQueue();

        expect(events, equals([<OutgoingVideoDm>[]]));
        expect(outcomes, isEmpty);
        expect(sentPaths, isEmpty);
        verifyNever(() => verifier.verify(any()));
      });

      test(
        'checks each clip, then sends it marked as a clip with its crop',
        () async {
          when(() => verifier.verify(any())).thenAnswer((_) async => _verified);
          outbox = createOutbox(clipVerifier: () => verifier);
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();

          sendClips([
            _clip('clip-a'),
            _clip('clip-b', aspect: AspectRatio.vertical),
          ]);
          await pumpEventQueue();

          expect(sentPaths, equals([_clipPath('clip-a'), _clipPath('clip-b')]));
          expect(
            sentTags,
            equals([
              [
                ['divine-clip', 'square'],
              ],
              [
                ['divine-clip', 'vertical'],
              ],
            ]),
          );
          final entries = events.last;
          expect(
            entries.map((entry) => entry.clip?.id),
            equals(['clip-a', 'clip-b']),
          );
          expect(
            entries.map((entry) => entry.localPath),
            equals([_clipPath('clip-a'), _clipPath('clip-b')]),
          );
          expect(entries.first.batchId, isNotNull);
          expect(entries.last.batchId, equals(entries.first.batchId));
          expect(
            entries.map((entry) => (entry.phase, entry.rumorEventId)),
            equals([
              (OutgoingVideoDmPhase.sent, 'rumor-1'),
              (OutgoingVideoDmPhase.sent, 'rumor-2'),
            ]),
          );
          expect(
            outcomes,
            equals([
              const VideoDmSendOutcome(
                status: VideoDmOutcomeStatus.sent,
                sentCount: 2,
                total: 2,
              ),
            ]),
          );
        },
      );

      test('checks the whole batch before any upload', () async {
        final check = Completer<ClipProvenanceResult>();
        when(() => verifier.verify(any())).thenAnswer((_) => check.future);
        outbox = createOutbox(clipVerifier: () => verifier);
        final events = recordConversation('c1');

        sendClips([_clip('clip-a'), _clip('clip-b')]);
        await pumpEventQueue();

        expect(
          events.last.map((entry) => entry.phase),
          equals([
            OutgoingVideoDmPhase.checking,
            OutgoingVideoDmPhase.checking,
          ]),
        );
        expect(sentPaths, isEmpty);

        check.complete(_verified);
        await pumpEventQueue();

        expect(sentPaths, equals([_clipPath('clip-a'), _clipPath('clip-b')]));
      });

      test('clips wait queued for their turn once the check passes', () async {
        stubControlledSend();
        when(() => verifier.verify(any())).thenAnswer((_) async => _verified);
        outbox = createOutbox(clipVerifier: () => verifier);
        final events = recordConversation('c1');

        sendClips([_clip('clip-a'), _clip('clip-b')]);
        await pumpEventQueue();

        expect(
          events.last.map((entry) => entry.phase),
          equals([
            OutgoingVideoDmPhase.encrypting,
            OutgoingVideoDmPhase.queued,
          ]),
        );
        expect(sends.single.videoFile.path, equals(_clipPath('clip-a')));
        expect(
          sends.single.extraTags,
          equals([
            ['divine-clip', 'square'],
          ]),
        );
      });

      test('reads a card frame for each clip', () async {
        final readPaths = <String>[];
        readFrame = (file) async {
          readPaths.add(file.path);
          return null;
        };
        outbox = createOutbox();

        sendClips([_clip('clip-a'), _clip('clip-b')]);
        await pumpEventQueue();

        expect(
          readPaths,
          unorderedEquals([_clipPath('clip-a'), _clipPath('clip-b')]),
        );
      });

      test('signs own recordings left unsigned before checking them', () async {
        final steps = <String>[];
        when(() => verifier.verify(any())).thenAnswer((invocation) async {
          steps.add('verify ${invocation.positionalArguments.single}');
          return _verified;
        });
        outbox = createOutbox(
          clipVerifier: () => verifier,
          signOwnRecordings: (clips) async =>
              steps.add('sign ${clips.map((clip) => clip.id).join(',')}'),
        );

        sendClips([_clip('clip-a'), _clip('clip-b')]);
        await pumpEventQueue();

        // A recording whose signing failed offline would otherwise fail the
        // sender's own check.
        expect(
          steps,
          equals([
            'sign clip-a,clip-b',
            'verify ${_clipPath('clip-a')}',
            'verify ${_clipPath('clip-b')}',
          ]),
        );
      });

      test(
        'a rejected clip fails only itself as clipNotVerified; '
        'the rest fail as failed',
        () async {
          when(
            () => verifier.verify(_clipPath('clip-a')),
          ).thenAnswer((_) async => _verified);
          when(
            () => verifier.verify(_clipPath('clip-b')),
          ).thenAnswer((_) async => _noCredentials);
          when(
            () => verifier.verify(_clipPath('clip-c')),
          ).thenAnswer((_) async => _verified);
          outbox = createOutbox(clipVerifier: () => verifier);
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();

          sendClips([_clip('clip-a'), _clip('clip-b'), _clip('clip-c')]);
          await pumpEventQueue();

          expect(
            phasesOf(events.last),
            equals([
              (OutgoingVideoDmPhase.failed, OutgoingVideoDmFailure.failed),
              (
                OutgoingVideoDmPhase.failed,
                OutgoingVideoDmFailure.clipNotVerified,
              ),
              (OutgoingVideoDmPhase.failed, OutgoingVideoDmFailure.failed),
            ]),
          );
          expect(sentPaths, isEmpty);
          // The check stops at the first rejected clip.
          verifyNever(() => verifier.verify(_clipPath('clip-c')));
          expect(
            outcomes,
            equals([
              const VideoDmSendOutcome(
                status: VideoDmOutcomeStatus.clipNotVerified,
                sentCount: 0,
                total: 3,
              ),
            ]),
          );
        },
      );

      test(
        'a check that cannot run leaves the decision to the recipient',
        () async {
          when(() => verifier.verify(any())).thenAnswer(
            (_) async =>
                const ClipProvenanceResult(ClipProvenanceStatus.unavailable),
          );
          outbox = createOutbox(clipVerifier: () => verifier);
          final outcomes = recordOutcomes();

          sendClips([_clip('clip-a')]);
          await pumpEventQueue();

          expect(sentPaths, equals([_clipPath('clip-a')]));
          expect(outcomes.single.status, equals(VideoDmOutcomeStatus.sent));
        },
      );

      test('a check that throws fails the batch without uploading', () async {
        when(
          () => verifier.verify(any()),
        ).thenAnswer((_) async => throw Exception('manifest read failed'));
        outbox = createOutbox(clipVerifier: () => verifier);
        final events = recordConversation('c1');
        final outcomes = recordOutcomes();

        sendClips([_clip('clip-a'), _clip('clip-b')]);
        await pumpEventQueue();

        expect(
          phasesOf(events.last),
          equals([
            (OutgoingVideoDmPhase.failed, OutgoingVideoDmFailure.failed),
            (OutgoingVideoDmPhase.failed, OutgoingVideoDmFailure.failed),
          ]),
        );
        expect(sentPaths, isEmpty);
        expect(
          outcomes,
          equals([
            const VideoDmSendOutcome(
              status: VideoDmOutcomeStatus.failed,
              sentCount: 0,
              total: 2,
            ),
          ]),
        );
      });

      test(
        'never asks whether a clip with a credential that fails is a Vine',
        () async {
          when(() => verifier.verify(any())).thenAnswer(
            (_) async => const ClipProvenanceResult(
              ClipProvenanceStatus.notCameraCapture,
            ),
          );
          var asked = false;
          outbox = createOutbox(
            clipVerifier: () => verifier,
            isArchivedVine: (_) async => asked = true,
          );
          final events = recordConversation('c1');

          sendClips([_clip('clip-a')]);
          await pumpEventQueue();

          // An archived Vine carries no manifest at all; one that fails the
          // check is footage that claims a history it cannot show.
          expect(
            events.last.single.failure,
            equals(OutgoingVideoDmFailure.clipNotVerified),
          );
          expect(asked, isFalse);
          expect(sentPaths, isEmpty);
        },
      );

      group('with a clip that has no credential', () {
        setUp(() {
          when(
            () => verifier.verify(any()),
          ).thenAnswer((_) async => _noCredentials);
        });

        test('sends an archived Vine, which the recipient adds too', () async {
          final checked = <String>[];
          outbox = createOutbox(
            clipVerifier: () => verifier,
            isArchivedVine: (path) async {
              checked.add(path);
              return true;
            },
          );
          final outcomes = recordOutcomes();

          sendClips([_clip('clip-a')]);
          await pumpEventQueue();

          expect(checked, equals([_clipPath('clip-a')]));
          expect(sentPaths, equals([_clipPath('clip-a')]));
          expect(outcomes.single.status, equals(VideoDmOutcomeStatus.sent));
        });

        test('holds back footage that is not an archived Vine', () async {
          outbox = createOutbox(
            clipVerifier: () => verifier,
            isArchivedVine: (_) async => false,
          );
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();

          sendClips([_clip('clip-a')]);
          await pumpEventQueue();

          expect(
            events.last.single.failure,
            equals(OutgoingVideoDmFailure.clipNotVerified),
          );
          expect(sentPaths, isEmpty);
          expect(
            outcomes.single.status,
            equals(VideoDmOutcomeStatus.clipNotVerified),
          );
        });

        test(
          'leaves the decision to the recipient when the Vine lookup fails',
          () async {
            outbox = createOutbox(
              clipVerifier: () => verifier,
              isArchivedVine: (_) async =>
                  throw Exception('no relay took the read'),
            );
            final outcomes = recordOutcomes();

            sendClips([_clip('clip-a')]);
            await pumpEventQueue();

            expect(sentPaths, equals([_clipPath('clip-a')]));
            expect(outcomes.single.status, equals(VideoDmOutcomeStatus.sent));
          },
        );
      });

      test('without a verifier, sends with no check and no signing', () async {
        var signed = false;
        outbox = createOutbox(signOwnRecordings: (_) async => signed = true);
        final events = recordConversation('c1');

        sendClips([_clip('clip-a')]);
        await pumpEventQueue();

        expect(signed, isFalse);
        expect(
          events.expand((entries) => entries).map((entry) => entry.phase),
          isNot(contains(OutgoingVideoDmPhase.checking)),
        );
        expect(sentPaths, equals([_clipPath('clip-a')]));
      });

      test('reads the verifier when each batch starts', () async {
        ClipProvenanceVerifier? current;
        when(
          () => verifier.verify(any()),
        ).thenAnswer((_) async => _noCredentials);
        outbox = createOutbox(clipVerifier: () => current);
        final events = recordConversation('c1');

        sendClips([_clip('clip-a')]);
        await pumpEventQueue();
        current = verifier;
        sendClips([_clip('clip-b')]);
        await pumpEventQueue();

        expect(sentPaths, equals([_clipPath('clip-a')]));
        expect(
          phasesOf(events.last),
          equals([
            (OutgoingVideoDmPhase.sent, null),
            (
              OutgoingVideoDmPhase.failed,
              OutgoingVideoDmFailure.clipNotVerified,
            ),
          ]),
        );
      });

      test(
        'a clip without a video file fails the batch before any check',
        () async {
          outbox = createOutbox(clipVerifier: () => verifier);
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();

          sendClips([_clip('clip-a'), _clip('clip-b', hasFile: false)]);
          await pumpEventQueue();

          expect(
            phasesOf(events.last),
            equals([
              (OutgoingVideoDmPhase.failed, OutgoingVideoDmFailure.failed),
              (OutgoingVideoDmPhase.failed, OutgoingVideoDmFailure.failed),
            ]),
          );
          verifyNever(() => verifier.verify(any()));
          expect(sentPaths, isEmpty);
          expect(
            outcomes,
            equals([
              const VideoDmSendOutcome(
                status: VideoDmOutcomeStatus.failed,
                sentCount: 0,
                total: 2,
              ),
            ]),
          );
        },
      );

      test('a failed upload stops the rest of the batch', () async {
        stubAutoSend(
          (path) => path == _clipPath('clip-b')
              ? const NIP17SendResult.failure('relay rejected the wrap')
              : _success('rumor-a'),
        );
        outbox = createOutbox();
        final events = recordConversation('c1');
        final outcomes = recordOutcomes();

        sendClips([_clip('clip-a'), _clip('clip-b'), _clip('clip-c')]);
        await pumpEventQueue();

        expect(sentPaths, equals([_clipPath('clip-a'), _clipPath('clip-b')]));
        expect(
          phasesOf(events.last),
          equals([
            (OutgoingVideoDmPhase.sent, null),
            (OutgoingVideoDmPhase.failed, OutgoingVideoDmFailure.failed),
            (OutgoingVideoDmPhase.failed, OutgoingVideoDmFailure.failed),
          ]),
        );
        expect(
          outcomes,
          equals([
            const VideoDmSendOutcome(
              status: VideoDmOutcomeStatus.failed,
              sentCount: 1,
              total: 3,
            ),
          ]),
        );
        expect(outcomes.single.isPartial, isTrue);
      });

      test('a too-large clip ends the batch as tooLarge', () async {
        stubAutoSend(
          (path) => path == _clipPath('clip-b')
              ? throw const DmVideoTooLargeException(1 << 30)
              : _success('rumor-a'),
        );
        outbox = createOutbox();
        final events = recordConversation('c1');
        final outcomes = recordOutcomes();

        sendClips([_clip('clip-a'), _clip('clip-b'), _clip('clip-c')]);
        await pumpEventQueue();

        expect(
          phasesOf(events.last),
          equals([
            (OutgoingVideoDmPhase.sent, null),
            (OutgoingVideoDmPhase.failed, OutgoingVideoDmFailure.tooLarge),
            (OutgoingVideoDmPhase.failed, OutgoingVideoDmFailure.failed),
          ]),
        );
        expect(
          outcomes,
          equals([
            const VideoDmSendOutcome(
              status: VideoDmOutcomeStatus.tooLarge,
              sentCount: 1,
              total: 3,
            ),
          ]),
        );
      });

      test('does nothing after dispose', () async {
        outbox = createOutbox();
        final outcomes = recordOutcomes();
        outbox.dispose();

        sendClips([_clip('clip-a')]);
        await pumpEventQueue();

        expect(sentPaths, isEmpty);
        expect(outcomes, isEmpty);
      });
    });

    group('crash reporting', () {
      late _RecordingCrashReporter reporter;

      setUp(() {
        reporter = _RecordingCrashReporter();
      });

      Matcher reportedStateError(String reason) => isA<(Object, String?)>()
          .having(
            (report) => report.$1,
            'error',
            isA<Reportable<Object>>().having(
              (r) => r.unwrap(),
              'unwrap',
              isA<StateError>(),
            ),
          )
          .having((report) => report.$2, 'reason', reason);

      test('forwards a programming error from the send service', () async {
        whenSendVideo().thenThrow(StateError('invariant broken'));
        outbox = createOutbox(reporter: reporter);

        sendVideo();
        await pumpEventQueue();

        expect(
          reporter.errors,
          equals([reportedStateError('VideoDmOutbox sendVideo')]),
        );
      });

      test('does not forward a failure result', () async {
        stubAutoSend((_) => const NIP17SendResult.failure('relay rejected'));
        outbox = createOutbox(reporter: reporter);
        final outcomes = recordOutcomes();

        sendVideo();
        await pumpEventQueue();

        expect(outcomes.single.status, equals(VideoDmOutcomeStatus.failed));
        expect(reporter.errors, isEmpty);
      });

      test('does not forward an unreadable file', () async {
        whenSendVideo().thenAnswer(
          (_) async => throw const FileSystemException(
            'Cannot open file',
            '/v/missing.mp4',
          ),
        );
        outbox = createOutbox(reporter: reporter);
        final outcomes = recordOutcomes();

        sendVideo(path: '/v/missing.mp4');
        await pumpEventQueue();

        expect(outcomes.single.status, equals(VideoDmOutcomeStatus.failed));
        expect(reporter.errors, isEmpty);
      });

      test('does not forward a video that is too large', () async {
        whenSendVideo().thenThrow(const DmVideoTooLargeException(1 << 30));
        outbox = createOutbox(reporter: reporter);
        final outcomes = recordOutcomes();

        sendVideo();
        await pumpEventQueue();

        expect(outcomes.single.status, equals(VideoDmOutcomeStatus.tooLarge));
        expect(reporter.errors, isEmpty);
      });

      test('reports a clip check that throws under its own site', () async {
        stubAutoSend();
        final verifier = _MockClipProvenanceVerifier();
        when(() => verifier.verify(any())).thenAnswer((invocation) async {
          final path = invocation.positionalArguments.single as String;
          if (path == _clipPath('clip-b')) throw StateError('bad manifest');
          return _verified;
        });
        outbox = createOutbox(
          clipVerifier: () => verifier,
          reporter: reporter,
        );

        sendClips([_clip('clip-a'), _clip('clip-b')]);
        await pumpEventQueue();

        expect(
          reporter.errors,
          equals([reportedStateError('VideoDmOutbox checkClipBatch')]),
        );
        expect(sentPaths, isEmpty);
      });
    });

    group('retry', () {
      late _MockClipProvenanceVerifier verifier;

      setUp(() {
        verifier = _MockClipProvenanceVerifier();
      });

      test(
        're-queues a failed gallery video and redoes the whole pipeline',
        () async {
          var attempts = 0;
          stubAutoSend(
            (_) => ++attempts == 1
                ? const NIP17SendResult.failure('no OK', retryablePending: true)
                : _success('rumor-retried'),
          );
          outbox = createOutbox();
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();
          sendVideo();
          await pumpEventQueue();
          final failed = events.last.single;
          expect(failed.canRetry, isTrue);

          outbox.retry(failed.id);
          await pumpEventQueue();

          expect(sentPaths, equals(['/v/a.mp4', '/v/a.mp4']));
          final retried = events.last.single;
          expect(retried.id, equals(failed.id));
          expect(retried.requestedAt, equals(failed.requestedAt));
          expect(retried.phase, equals(OutgoingVideoDmPhase.sent));
          expect(retried.failure, isNull);
          expect(retried.rumorEventId, equals('rumor-retried'));
          expect(
            outcomes,
            equals([
              const VideoDmSendOutcome(
                status: VideoDmOutcomeStatus.failed,
                sentCount: 0,
                total: 1,
              ),
              const VideoDmSendOutcome(
                status: VideoDmOutcomeStatus.sent,
                sentCount: 1,
                total: 1,
              ),
            ]),
          );
        },
      );

      test(
        'retry re-queues a failed entry and re-checks a clip alone',
        () async {
          when(() => verifier.verify(any())).thenAnswer((_) async => _verified);
          var failClipB = true;
          stubAutoSend(
            (path) => path == _clipPath('clip-b') && failClipB
                ? const NIP17SendResult.failure('relay rejected the wrap')
                : _success('rumor-${sentPaths.length}'),
          );
          final signed = <List<String>>[];
          outbox = createOutbox(
            clipVerifier: () => verifier,
            signOwnRecordings: (clips) async =>
                signed.add([for (final clip in clips) clip.id]),
          );
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();
          sendClips([_clip('clip-a'), _clip('clip-b')]);
          await pumpEventQueue();
          final failed = events.last[1];
          expect(failed.failure, equals(OutgoingVideoDmFailure.failed));
          clearInteractions(verifier);
          failClipB = false;

          outbox.retry(failed.id);
          await pumpEventQueue();

          verify(() => verifier.verify(_clipPath('clip-b'))).called(1);
          verifyNoMoreInteractions(verifier);
          expect(
            signed,
            equals([
              ['clip-a', 'clip-b'],
              ['clip-b'],
            ]),
          );
          expect(
            sentPaths,
            equals([
              _clipPath('clip-a'),
              _clipPath('clip-b'),
              _clipPath('clip-b'),
            ]),
          );
          expect(
            sentTags.last,
            equals([
              ['divine-clip', 'square'],
            ]),
          );
          final retried = events.last[1];
          expect(retried.id, equals(failed.id));
          expect(retried.batchId, equals(failed.batchId));
          expect(retried.phase, equals(OutgoingVideoDmPhase.sent));
          expect(retried.rumorEventId, equals('rumor-3'));
          expect(
            outcomes,
            equals([
              const VideoDmSendOutcome(
                status: VideoDmOutcomeStatus.failed,
                sentCount: 1,
                total: 2,
              ),
              const VideoDmSendOutcome(
                status: VideoDmOutcomeStatus.sent,
                sentCount: 1,
                total: 1,
              ),
            ]),
          );
        },
      );

      test(
        'a retried clip the check now rejects ends clipNotVerified',
        () async {
          when(() => verifier.verify(any())).thenAnswer((_) async => _verified);
          stubAutoSend((_) => const NIP17SendResult.failure('relay rejected'));
          outbox = createOutbox(clipVerifier: () => verifier);
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();
          sendClips([_clip('clip-a')]);
          await pumpEventQueue();
          when(
            () => verifier.verify(any()),
          ).thenAnswer((_) async => _noCredentials);

          outbox.retry(events.last.single.id);
          await pumpEventQueue();

          expect(
            events.last.single.failure,
            equals(OutgoingVideoDmFailure.clipNotVerified),
          );
          expect(sentPaths, hasLength(1));
          expect(
            outcomes.last,
            equals(
              const VideoDmSendOutcome(
                status: VideoDmOutcomeStatus.clipNotVerified,
                sentCount: 0,
                total: 1,
              ),
            ),
          );
        },
      );

      test('goes to the back of the queue', () async {
        stubControlledSend();
        outbox = createOutbox();
        final events = recordConversation('c1');
        sendVideo();
        await pumpEventQueue();
        sends.single.completer.complete(
          const NIP17SendResult.failure('relay rejected'),
        );
        await pumpEventQueue();
        sendVideo(path: '/v/b.mp4');
        sendVideo(path: '/v/c.mp4');
        await pumpEventQueue();
        expect(sends, hasLength(2));

        outbox.retry(events.last.first.id);
        await pumpEventQueue();

        expect(sends, hasLength(2));
        expect(events.last.first.phase, equals(OutgoingVideoDmPhase.queued));

        sends[1].completer.complete(_success('rumor-b'));
        await pumpEventQueue();
        sends[2].completer.complete(_success('rumor-c'));
        await pumpEventQueue();

        expect(
          sends.map((send) => send.videoFile.path),
          equals(['/v/a.mp4', '/v/b.mp4', '/v/c.mp4', '/v/a.mp4']),
        );
      });

      test('retry is ignored unless canRetry', () async {
        stubControlledSend();
        when(
          () => verifier.verify(_clipPath('clip-a')),
        ).thenAnswer((_) async => _noCredentials);
        outbox = createOutbox(clipVerifier: () => verifier);
        final events = recordConversation('c1');
        sendClips([_clip('clip-a')]);
        await pumpEventQueue();
        final notVerified = events.last.single;
        expect(
          notVerified.failure,
          equals(OutgoingVideoDmFailure.clipNotVerified),
        );
        sendVideo(path: '/v/running.mp4');
        await pumpEventQueue();
        final running = events.last.last;
        expect(sends, hasLength(1));

        outbox
          ..retry(notVerified.id)
          ..retry(running.id)
          ..retry('unknown');
        await pumpEventQueue();

        verify(() => verifier.verify(any())).called(1);
        expect(sends, hasLength(1));
        expect(events.last.first, equals(notVerified));

        whenSendVideo().thenThrow(const DmVideoTooLargeException(1 << 30));
        sends.single.completer.complete(_success('rumor-running'));
        sendVideo(path: '/v/huge.mp4');
        await pumpEventQueue();
        final tooLarge = events.last.last;
        expect(tooLarge.failure, equals(OutgoingVideoDmFailure.tooLarge));
        final eventCount = events.length;

        outbox.retry(tooLarge.id);
        await pumpEventQueue();

        expect(events, hasLength(eventCount));
      });
    });

    group('remove', () {
      test('remove drops a failed entry and ignores others', () async {
        stubControlledSend();
        outbox = createOutbox();
        final events = recordConversation('c1');
        sendVideo(path: '/v/failed.mp4');
        sendVideo(path: '/v/sent.mp4');
        sendVideo(path: '/v/running.mp4');
        await pumpEventQueue();
        sends[0].completer.complete(
          const NIP17SendResult.failure('relay rejected'),
        );
        await pumpEventQueue();
        sends[1].completer.complete(_success('rumor-sent'));
        await pumpEventQueue();
        final [failed, sent, running] = events.last;
        expect(failed.phase, equals(OutgoingVideoDmPhase.failed));
        expect(sent.phase, equals(OutgoingVideoDmPhase.sent));
        expect(running.phase, equals(OutgoingVideoDmPhase.encrypting));

        outbox
          ..remove(failed.id)
          ..remove(sent.id)
          ..remove(running.id)
          ..remove('unknown');
        await pumpEventQueue();

        expect(events.last, equals([sent, running]));
      });
    });

    group('acknowledge', () {
      test('acknowledge drops a sent entry and ignores others', () async {
        stubControlledSend();
        outbox = createOutbox();
        final events = recordConversation('c1');
        sendVideo(path: '/v/failed.mp4');
        sendVideo(path: '/v/sent.mp4');
        sendVideo(path: '/v/running.mp4');
        await pumpEventQueue();
        sends[0].completer.complete(
          const NIP17SendResult.failure('relay rejected'),
        );
        await pumpEventQueue();
        sends[1].completer.complete(_success('rumor-sent'));
        await pumpEventQueue();
        final [failed, sent, running] = events.last;
        expect(sent.phase, equals(OutgoingVideoDmPhase.sent));

        outbox
          ..acknowledge(failed.id)
          ..acknowledge(sent.id)
          ..acknowledge(running.id)
          ..acknowledge('unknown');
        await pumpEventQueue();

        expect(events.last, equals([failed, running]));
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
