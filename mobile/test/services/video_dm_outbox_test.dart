// ABOUTME: Unit tests for VideoDmOutbox, the per-account owner of outgoing
// ABOUTME: video DMs: queueing, clip batches, progress, retry and outcomes.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_send_cancellation.dart';
import 'package:openvine/services/dm_video_send_service.dart';
import 'package:openvine/services/video_dm_outbox.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:unified_logger/unified_logger.dart' show LogCaptureService;

class _MockDmVideoSendService extends Mock implements DmVideoSendService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockDmVideoEncryption extends Mock implements DmVideoEncryption {}

class _MockFile extends Mock implements File {}

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

/// One send the test drives by hand: an `uploadVideo` call and the
/// `publishVideo` call that follows it.
class _PendingSend {
  _PendingSend({
    required this.videoFile,
    required this.mimeType,
    required this.blurhash,
    required this.onPhase,
    required this.onUploadProgress,
    required this.cancellation,
  }) : upload = _uploadOf(videoFile.path);

  final DmVideoSendCancellation cancellation;
  final File videoFile;
  final String mimeType;
  final String? blurhash;
  final void Function(DmVideoSendPhase phase)? onPhase;
  final void Function(double fraction)? onUploadProgress;

  /// What the upload returns, distinct for every send.
  final DmVideoUpload upload;

  /// The result of the whole send. Completing it finishes the upload too,
  /// then answers the publication with the same result.
  final Completer<NIP17SendResult> completer = Completer<NIP17SendResult>();

  final Completer<void> _uploadFinished = Completer<void>();

  /// Finishes the upload alone, leaving the publication that follows it
  /// waiting on [completer].
  void finishUpload() => _uploadFinished.complete();

  /// Settles when the upload finishes, through [finishUpload] or [completer].
  Future<DmVideoUpload> get uploaded =>
      Future.any([_uploadFinished.future, completer.future]).then(
        (_) => upload,
      );

  /// The extra tags the publication was given, once it ran.
  List<List<String>>? publishedTags;
}

/// A finished upload of the video at [path]. Every call returns a new
/// instance, so a test can tell one upload from another.
DmVideoUpload _uploadOf(String path) => DmVideoUpload(
  fileUrl: 'https://media.example/$path',
  fileMetadata: const DmFileMetadata(
    fileType: 'video/mp4',
    encryptionAlgorithm: 'aes-gcm',
    decryptionKey: 'key',
    decryptionNonce: 'nonce',
    fileHash: 'hash',
  ),
);

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
  late DateTime clockNow;
  var idCounter = 0;

  VideoDmOutbox createOutbox({
    DmVideoSendService Function()? sendService,
    ClipProvenanceVerifier? Function()? clipVerifier,
    Future<void> Function(List<DivineVideoClip> clips)? signOwnRecordings,
    ArchivedVineCheck? isArchivedVine,
    bool Function()? isAccountCurrent,
    CrashReporter? reporter,
    Future<void> Function(DmVideoSendCancellation)? waitUntilReady,
  }) {
    final created = VideoDmOutbox(
      sendService: sendService ?? () => service,
      readFrame: (file) => readFrame(file),
      newId: () => 'entry-${idCounter++}',
      now: () => clockNow,
      clipVerifier: clipVerifier,
      signOwnRecordings: signOwnRecordings,
      isArchivedVine: isArchivedVine,
      isAccountCurrent: isAccountCurrent,
      reporter: reporter,
      waitUntilReady: waitUntilReady,
    );
    addTearDown(created.dispose);
    return created;
  }

  Future<DmVideoUpload> anyUploadVideoOn(_MockDmVideoSendService mock) =>
      mock.uploadVideo(
        videoFile: any(named: 'videoFile'),
        mimeType: any(named: 'mimeType'),
        blurhash: any(named: 'blurhash'),
        onPhase: any(named: 'onPhase'),
        onUploadProgress: any(named: 'onUploadProgress'),
        cancellation: any(named: 'cancellation'),
      );

  Future<NIP17SendResult> anyPublishVideoOn(_MockDmVideoSendService mock) =>
      mock.publishVideo(
        recipientPubkey: any(named: 'recipientPubkey'),
        uploaded: any(named: 'uploaded'),
        extraTags: any(named: 'extraTags'),
        onPhase: any(named: 'onPhase'),
        cancellation: any(named: 'cancellation'),
      );

  When<Future<DmVideoUpload>> whenUploadVideo() =>
      when(() => anyUploadVideoOn(service));

  When<Future<NIP17SendResult>> whenPublishVideo() =>
      when(() => anyPublishVideoOn(service));

  /// Answers every upload at once with a new [DmVideoUpload] of its path.
  void stubAutoUpload() {
    whenUploadVideo().thenAnswer(
      (invocation) async =>
          _uploadOf((invocation.namedArguments[#videoFile] as File).path),
    );
  }

  /// Answers every upload and publication at once: each publication with
  /// [answer] for its path when given, otherwise with a success. Records the
  /// path and extra tags of each publication.
  void stubAutoSend([NIP17SendResult Function(String path)? answer]) {
    stubAutoUpload();
    whenPublishVideo().thenAnswer((invocation) async {
      final uploaded = invocation.namedArguments[#uploaded] as DmVideoUpload;
      final path = uploaded.fileUrl.replaceFirst('https://media.example/', '');
      sentPaths.add(path);
      sentTags.add(
        invocation.namedArguments[#extraTags] as List<List<String>>,
      );
      if (answer != null) return answer(path);
      return _success('rumor-${sentPaths.length}');
    });
  }

  void stubControlledSend() {
    whenUploadVideo().thenAnswer((invocation) {
      final send = _PendingSend(
        cancellation:
            invocation.namedArguments[#cancellation] as DmVideoSendCancellation,
        videoFile: invocation.namedArguments[#videoFile] as File,
        mimeType: invocation.namedArguments[#mimeType] as String,
        blurhash: invocation.namedArguments[#blurhash] as String?,
        onPhase:
            invocation.namedArguments[#onPhase]
                as void Function(DmVideoSendPhase)?,
        onUploadProgress:
            invocation.namedArguments[#onUploadProgress]
                as void Function(double)?,
      );
      sends.add(send);
      return send.uploaded;
    });
    // Starts publication as the service does: past the point of
    // cancellation, then reporting it.
    whenPublishVideo().thenAnswer((invocation) {
      final uploaded = invocation.namedArguments[#uploaded] as DmVideoUpload;
      final send = sends.lastWhere((send) => identical(send.upload, uploaded));
      send.publishedTags =
          invocation.namedArguments[#extraTags] as List<List<String>>;
      (invocation.namedArguments[#cancellation] as DmVideoSendCancellation?)
          ?.beginPublication();
      (invocation.namedArguments[#onPhase] as void Function(DmVideoSendPhase)?)
          ?.call(DmVideoSendPhase.sending);
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

  List<String> loggedMessages() => [
    for (final entry in LogCaptureService().getRecentLogs()) entry.message,
  ];

  List<VideoDmSendOutcome> recordOutcomes() {
    final outcomes = <VideoDmSendOutcome>[];
    final subscription = outbox.outcomes.listen(outcomes.add);
    addTearDown(subscription.cancel);
    return outcomes;
  }

  group(VideoDmOutbox, () {
    setUpAll(() {
      registerFallbackValue(File('/tmp/fallback.mp4'));
      registerFallbackValue((DmVideoSendPhase _) {});
      registerFallbackValue((double _) {});
      registerFallbackValue(DmVideoSendCancellation()..finish());
      registerFallbackValue(_uploadOf('/tmp/fallback.mp4'));
      registerFallbackValue(_uploadOf('/tmp/fallback.mp4').fileMetadata);
    });

    setUp(() {
      service = _MockDmVideoSendService();
      sends = [];
      sentPaths = [];
      sentTags = [];
      readFrame = (_) async => null;
      idCounter = 0;
      clockNow = DateTime.utc(2026, 11, 13);
    });

    test(
      'keeps an owned draft package for retry and deletes it after send',
      () async {
        final file = _MockFile();
        when(() => file.path).thenReturn('/v/project.divinedraft');
        when(file.delete).thenAnswer((_) async => file);
        stubControlledSend();
        outbox = createOutbox();
        final entries = recordConversation('c1');

        outbox.sendDraft(
          conversationId: 'c1',
          recipientPubkey: _recipientPubkey,
          file: file,
        );
        await pumpEventQueue();
        sends.single.completer.completeError(
          const DmVideoUploadFailed('server refused'),
        );
        await pumpEventQueue();
        final failed = entries.last.single;
        expect(failed.canRetry, isTrue);
        verifyNever(file.delete);

        outbox.retry(failed.id);
        await pumpEventQueue();
        expect(sends.last.videoFile.path, file.path);
        expect(sends.last.mimeType, DmFileMetadata.editableDraftMimeType);
        sends.last.completer.complete(_success('preview'));
        await pumpEventQueue();

        expect(entries.last.single.phase, OutgoingVideoDmPhase.sent);
        verify(file.delete).called(1);
      },
    );

    test("sends a draft's title tag and cover blurhash", () async {
      final file = _MockFile();
      when(() => file.path).thenReturn('/v/project.divinedraft');
      when(file.delete).thenAnswer((_) async => file);
      stubControlledSend();
      outbox = createOutbox();
      final entries = recordConversation('c1');

      outbox.sendDraft(
        conversationId: 'c1',
        recipientPubkey: _recipientPubkey,
        file: file,
        title: '  Beach cut  ',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );
      await pumpEventQueue();

      expect(entries.last.single.draftTitle, '  Beach cut  ');
      expect(sends.single.mimeType, DmFileMetadata.editableDraftMimeType);
      expect(sends.single.blurhash, 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
      sends.single.completer.complete(_success('draft'));
      await pumpEventQueue();
      expect(sends.single.publishedTags, [
        ['title', 'Beach cut'],
      ]);
    });

    test(
      "republishes a draft's kept upload with its title tag on retry",
      () async {
        final file = _MockFile();
        when(() => file.path).thenReturn('/v/project.divinedraft');
        when(file.delete).thenAnswer((_) async => file);
        var attempts = 0;
        stubAutoSend(
          (_) => attempts++ == 0
              ? const NIP17SendResult.failure('offline')
              : _success('draft'),
        );
        outbox = createOutbox();
        final entries = recordConversation('c1');

        outbox.sendDraft(
          conversationId: 'c1',
          recipientPubkey: _recipientPubkey,
          file: file,
          title: 'Beach cut',
        );
        await pumpEventQueue();
        final failed = entries.last.single;
        expect(failed.phase, OutgoingVideoDmPhase.failed);
        verifyNever(file.delete);

        outbox.retry(failed.id);
        await pumpEventQueue();

        verify(() => anyUploadVideoOn(service)).called(1);
        expect(sentTags, [
          [
            ['title', 'Beach cut'],
          ],
          [
            ['title', 'Beach cut'],
          ],
        ]);
        expect(entries.last.single.phase, OutgoingVideoDmPhase.sent);
        verify(file.delete).called(1);
      },
    );

    test('sends an untitled draft without a title tag', () async {
      final file = _MockFile();
      when(() => file.path).thenReturn('/v/project.divinedraft');
      when(file.delete).thenAnswer((_) async => file);
      stubControlledSend();
      outbox = createOutbox();

      outbox.sendDraft(
        conversationId: 'c1',
        recipientPubkey: _recipientPubkey,
        file: file,
        title: ' ',
      );
      await pumpEventQueue();

      expect(sends.single.blurhash, isNull);
      sends.single.completer.complete(_success('draft'));
      await pumpEventQueue();
      expect(sends.single.publishedTags, isEmpty);
    });

    test('stalled upload fails and releases the account queue', () {
      fakeAsync((clock) {
        stubControlledSend();
        outbox = createOutbox();
        final entries = <List<OutgoingVideoDm>>[];
        final outcomes = <VideoDmSendOutcome>[];
        final entriesSub = outbox.watchConversation('c1').listen(entries.add);
        final outcomesSub = outbox.outcomes.listen(outcomes.add);
        sendVideo();
        sendVideo(path: '/v/next.mp4');
        clock.flushMicrotasks();
        sends.first.onPhase!(DmVideoSendPhase.uploading);
        sends.first.onUploadProgress!(0.4);
        clock.elapse(const Duration(minutes: 1));
        sends.first.onUploadProgress!(0.4);
        sends.first.onUploadProgress!(0.3);
        clock.elapse(const Duration(minutes: 1));
        clock.flushMicrotasks();
        expect(entries.last.first.phase, OutgoingVideoDmPhase.failed);
        expect(entries.last.first.canRetry, isTrue);
        expect(sends, hasLength(2));
        expect(outcomes.single.status, VideoDmOutcomeStatus.failed);
        unawaited(entriesSub.cancel());
        unawaited(outcomesSub.cancel());
        outbox.dispose();
        clock.flushMicrotasks();
      });
    });

    testWidgets('expired attempt cannot mutate a retried entry or emit twice', (
      tester,
    ) async {
      stubControlledSend();
      final reporter = _RecordingCrashReporter();
      outbox = createOutbox(reporter: reporter);
      final entries = recordConversation('c1');
      final outcomes = recordOutcomes();
      sendVideo();
      await tester.pump();
      final old = sends.single;
      await tester.pump(const Duration(minutes: 30));
      expect(entries.last.single.canRetry, isTrue);
      expect(old.cancellation.uploadCancelToken.isCancelled, isTrue);
      outbox.retry(entries.last.single.id);
      await tester.pump();
      expect(sends, hasLength(2));
      // Uploading is the one phase that takes progress, so a late callback
      // from the old attempt would show here if it were let through.
      sends.last.onPhase!(DmVideoSendPhase.uploading);
      await tester.pump();
      expect(entries.last.single.phase, OutgoingVideoDmPhase.uploading);
      old.onUploadProgress!(0.9);
      old.onPhase!(DmVideoSendPhase.encrypting);
      await tester.pump();
      expect(entries.last.single.uploadProgress, isNull);
      expect(entries.last.single.phase, OutgoingVideoDmPhase.uploading);
      old.onPhase!(DmVideoSendPhase.sending);
      old.completer.complete(_success('late'));
      await tester.pump();
      expect(entries.last.single.phase, OutgoingVideoDmPhase.uploading);
      expect(outcomes, hasLength(1));
      sends.last.completer.complete(_success('retried'));
      await tester.pump();
      expect(entries.last.single.rumorEventId, 'retried');
      expect(outcomes, hasLength(2));
      expect(reporter.errors, isEmpty);
    });

    testWidgets(
      'increasing upload progress refreshes inactivity but not total deadline',
      (tester) async {
        stubControlledSend();
        outbox = createOutbox();
        final entries = recordConversation('c1');
        sendVideo();
        await tester.pump();
        sends.single.onPhase!(DmVideoSendPhase.uploading);
        for (var minute = 1; minute <= 29; minute++) {
          await tester.pump(const Duration(minutes: 1));
          sends.single.onUploadProgress!(minute / 100);
          expect(entries.last.single.phase, OutgoingVideoDmPhase.uploading);
        }
        await tester.pump(const Duration(minutes: 1));
        expect(entries.last.single.canRetry, isTrue);
      },
    );

    testWidgets(
      'publication keeps its delivery result beyond preparation deadline',
      (tester) async {
        stubControlledSend();
        outbox = createOutbox();
        final entries = recordConversation('c1');
        final outcomes = recordOutcomes();
        sendVideo();
        await tester.pump();
        sends.single.finishUpload();
        await tester.pump();
        await tester.pump(const Duration(hours: 1));
        expect(entries.last.single.phase, OutgoingVideoDmPhase.publishing);
        expect(outcomes, isEmpty);
        sends.single.completer.complete(_success('published'));
        await tester.pump();
        expect(entries.last.single.phase, OutgoingVideoDmPhase.sent);
        expect(outcomes.single.status, VideoDmOutcomeStatus.sent);
      },
    );

    testWidgets(
      'stalled clip leaves partial batch and starts next conversation',
      (tester) async {
        stubControlledSend();
        outbox = createOutbox();
        final entries = recordConversation('c1');
        final outcomes = recordOutcomes();
        sendClips([_clip('one'), _clip('two'), _clip('three')]);
        sendVideo(conversationId: 'c2');
        await tester.pump();
        sends.first.completer.complete(_success('one'));
        await tester.pump();
        sends.last.onPhase!(DmVideoSendPhase.uploading);
        await tester.pump(const Duration(minutes: 2));
        expect(entries.last.map((e) => e.phase), [
          OutgoingVideoDmPhase.sent,
          OutgoingVideoDmPhase.failed,
          OutgoingVideoDmPhase.failed,
        ]);
        expect(outcomes.single.isPartial, isTrue);
        expect(outcomes.single.sentCount, 1);
        expect(sends, hasLength(3));
        sends.last.completer.complete(_success('next-chat'));
        await tester.pump();
        expect(outcomes, hasLength(2));
      },
    );

    testWidgets(
      'signer timeout fails without reading service or crash reporting',
      (tester) async {
        final reporter = _RecordingCrashReporter();
        outbox = createOutbox(
          reporter: reporter,
          waitUntilReady: (_) => Completer<void>().future,
        );
        final entries = recordConversation('c1');
        final outcomes = recordOutcomes();
        sendVideo();
        await tester.pump();
        expect(entries.last.single.phase, OutgoingVideoDmPhase.queued);
        await tester.pump(const Duration(minutes: 2));
        expect(entries.last.single.canRetry, isTrue);
        expect(outcomes.single.status, VideoDmOutcomeStatus.failed);
        verifyZeroInteractions(service);
        expect(reporter.errors, isEmpty);
      },
    );

    testWidgets(
      'clip verification deadline releases queue and ignores late check',
      (tester) async {
        stubControlledSend();
        final verification = Completer<ClipProvenanceResult>();
        final verifier = _MockClipProvenanceVerifier();
        when(() => verifier.verify(any()))
            .thenAnswer((_) => verification.future);
        outbox = createOutbox(clipVerifier: () => verifier);
        final entries = recordConversation('c1');
        final outcomes = recordOutcomes();
        sendClips([_clip('one'), _clip('two')]);
        sendVideo(conversationId: 'c2');
        await tester.pump();
        await tester.pump(const Duration(minutes: 30));
        expect(entries.last.every((e) => e.canRetry), isTrue);
        expect(sends, hasLength(1));
        verification.complete(_verified);
        await tester.pump();
        expect(sends, hasLength(1));
        expect(outcomes, hasLength(1));
        sends.single.completer.complete(_success('next'));
        await tester.pump();
        expect(outcomes, hasLength(2));
      },
    );

    testWidgets(
      'quiesce cancels uploads but waits for an irreversible publication',
      (tester) async {
        stubControlledSend();
        outbox = createOutbox();
        sendVideo();
        sendVideo(path: '/v/queued.mp4');
        await tester.pump();
        sends.single.finishUpload();
        await tester.pump();
        var settled = false;
        final quiesced = outbox.quiesce().then((_) => settled = true);
        await tester.pump(const Duration(minutes: 30));
        expect(settled, isFalse);
        expect(
          sends.single.cancellation.uploadCancelToken.isCancelled,
          isFalse,
        );
        sends.single.completer.complete(_success('published'));
        await quiesced;
        expect(settled, isTrue);
        expect(sends, hasLength(1));
      },
    );

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

      test(
        'uploads the file with its MIME type, then publishes it to the '
        'recipient',
        () async {
          sendVideo(path: '/v/picked.MOV');

          expect(sends, hasLength(1));
          expect(sends.single.videoFile.path, equals('/v/picked.MOV'));
          expect(sends.single.mimeType, equals('video/quicktime'));
          verifyNever(() => anyPublishVideoOn(service));

          sends.single.completer.complete(_success('r1'));
          await pumpEventQueue();

          verify(
            () => service.publishVideo(
              recipientPubkey: _recipientPubkey,
              uploaded: sends.single.upload,
              extraTags: any(named: 'extraTags'),
              onPhase: any(named: 'onPhase'),
              cancellation: any(named: 'cancellation'),
            ),
          ).called(1);
        },
      );

      test('reads the send service when each send starts', () async {
        sendVideo(path: '/v/first.mp4');
        final firstService = service;
        // The DM repository rebuilt while the first send was running.
        service = _MockDmVideoSendService();
        stubControlledSend();
        sendVideo(path: '/v/second.mp4');

        sends.single.completer.complete(_success('rumor-1'));
        await pumpEventQueue();

        expect(
          sends.map((send) => send.videoFile.path),
          equals(['/v/first.mp4', '/v/second.mp4']),
        );
        verify(() => anyUploadVideoOn(firstService)).called(1);
        verify(() => anyPublishVideoOn(firstService)).called(1);
        verify(() => anyUploadVideoOn(service)).called(1);
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
          send.finishUpload();
          await pumpEventQueue();
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
              conversationId: 'c1',
              recipientPubkey: _recipientPubkey,
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
        whenUploadVideo().thenThrow(const DmVideoTooLargeException(1 << 30));
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
              conversationId: 'c1',
              recipientPubkey: _recipientPubkey,
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
              conversationId: 'c1',
              recipientPubkey: _recipientPubkey,
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
        whenUploadVideo().thenAnswer(
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
        whenUploadVideo().thenThrow(StateError('invariant broken'));
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
        'dispose stops publishing and ignores a send that finishes afterwards',
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

      test('stops the rest of a batch when disposed mid-batch', () async {
        stubControlledSend();
        outbox = createOutbox();

        sendClips([_clip('clip-a'), _clip('clip-b')]);
        await pumpEventQueue();
        expect(sends, hasLength(1));

        outbox.dispose();
        sends.single.completer.complete(_success('rumor-a'));
        await pumpEventQueue();

        expect(
          sends.map((send) => send.videoFile.path),
          equals([_clipPath('clip-a')]),
        );
      });

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
                conversationId: 'c1',
                recipientPubkey: _recipientPubkey,
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

        sends.single.completer.complete(_success('rumor-a'));
        await pumpEventQueue();
        expect(
          sends.first.publishedTags,
          equals([
            ['divine-clip', 'square'],
          ]),
        );
      });

      testWidgets(
        'waits for the signer before signing or checking, and fails the '
        'batch when it never comes',
        (tester) async {
          when(() => verifier.verify(any())).thenAnswer((_) async => _verified);
          var signed = false;
          final reporter = _RecordingCrashReporter();
          outbox = createOutbox(
            clipVerifier: () => verifier,
            signOwnRecordings: (_) async => signed = true,
            reporter: reporter,
            waitUntilReady: (_) => Completer<void>().future,
          );
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();

          sendClips([_clip('clip-a'), _clip('clip-b')]);
          await tester.pump();

          expect(signed, isFalse);
          verifyNever(() => verifier.verify(any()));
          expect(outcomes, isEmpty);

          await tester.pump(videoDmSignerReadinessTimeout);

          expect(events.last, hasLength(2));
          expect(events.last.every((entry) => entry.canRetry), isTrue);
          expect(outcomes.single.status, VideoDmOutcomeStatus.failed);
          expect(outcomes.single.sentCount, 0);
          expect(signed, isFalse);
          verifyNever(() => verifier.verify(any()));
          expect(sentPaths, isEmpty);
          expect(reporter.errors, isEmpty);
        },
      );

      test('logs a clip check the session interrupts', () async {
        await LogCaptureService().clearAllLogs();
        when(
          () => verifier.verify(any()),
        ).thenAnswer((_) => Completer<ClipProvenanceResult>().future);
        outbox = createOutbox(clipVerifier: () => verifier);
        final events = recordConversation('c1');

        sendClips([_clip('clip-a'), _clip('clip-b')]);
        await pumpEventQueue();
        outbox.cancelPendingSends();
        await pumpEventQueue();

        expect(
          events.last.every((e) => e.phase == OutgoingVideoDmPhase.failed),
          isTrue,
        );
        expect(
          loggedMessages(),
          contains(
            'Video DM clip batch ${events.last.first.batchId} check '
            'interrupted: originating session ended',
          ),
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
                conversationId: 'c1',
                recipientPubkey: _recipientPubkey,
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
              conversationId: 'c1',
              recipientPubkey: _recipientPubkey,
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
            await LogCaptureService().clearAllLogs();
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
            final logged = [
              for (final entry in LogCaptureService().getRecentLogs())
                entry.message,
            ].join('\n');
            expect(logged, contains('Archived-Vine lookup failed'));
            // A file error's message can quote the gallery path.
            expect(logged, isNot(contains('no relay took the read')));
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
                conversationId: 'c1',
                recipientPubkey: _recipientPubkey,
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
              conversationId: 'c1',
              recipientPubkey: _recipientPubkey,
              status: VideoDmOutcomeStatus.failed,
              sentCount: 1,
              total: 3,
            ),
          ]),
        );
        expect(outcomes.single.isPartial, isTrue);
      });

      test('a too-large clip ends the batch as tooLarge', () async {
        stubAutoSend();
        whenUploadVideo().thenAnswer((invocation) async {
          final path = (invocation.namedArguments[#videoFile] as File).path;
          if (path == _clipPath('clip-b')) {
            throw const DmVideoTooLargeException(1 << 30);
          }
          return _uploadOf(path);
        });
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
              conversationId: 'c1',
              recipientPubkey: _recipientPubkey,
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
        whenUploadVideo().thenThrow(StateError('invariant broken'));
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
        whenUploadVideo().thenAnswer(
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
        whenUploadVideo().thenThrow(const DmVideoTooLargeException(1 << 30));
        outbox = createOutbox(reporter: reporter);
        final outcomes = recordOutcomes();

        sendVideo();
        await pumpEventQueue();

        expect(outcomes.single.status, equals(VideoDmOutcomeStatus.tooLarge));
        expect(reporter.errors, isEmpty);
      });

      test(
        'does not forward an expected error the send service throws',
        () async {
          whenUploadVideo().thenThrow(const SocketException('offline'));
          outbox = createOutbox(reporter: reporter);
          final outcomes = recordOutcomes();

          sendVideo();
          await pumpEventQueue();

          expect(outcomes.single.status, equals(VideoDmOutcomeStatus.failed));
          expect(reporter.errors, isEmpty);
        },
      );

      test('does not forward an expected error a clip check throws', () async {
        stubAutoSend();
        final verifier = _MockClipProvenanceVerifier();
        when(
          () => verifier.verify(any()),
        ).thenThrow(Exception('manifest read failed'));
        outbox = createOutbox(
          clipVerifier: () => verifier,
          reporter: reporter,
        );
        final outcomes = recordOutcomes();

        sendClips([_clip('clip-a')]);
        await pumpEventQueue();

        expect(outcomes.single.status, equals(VideoDmOutcomeStatus.failed));
        expect(reporter.errors, isEmpty);
        expect(sentPaths, isEmpty);
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
        're-queues a failed gallery video and sends it again',
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
                conversationId: 'c1',
                recipientPubkey: _recipientPubkey,
                status: VideoDmOutcomeStatus.failed,
                sentCount: 0,
                total: 1,
              ),
              const VideoDmSendOutcome(
                conversationId: 'c1',
                recipientPubkey: _recipientPubkey,
                status: VideoDmOutcomeStatus.sent,
                sentCount: 1,
                total: 1,
              ),
            ]),
          );
        },
      );

      test(
        'retry re-queues a clip whose upload failed and re-checks it alone',
        () async {
          when(() => verifier.verify(any())).thenAnswer((_) async => _verified);
          var failClipB = true;
          stubAutoSend();
          whenUploadVideo().thenAnswer((invocation) async {
            final path = (invocation.namedArguments[#videoFile] as File).path;
            if (path == _clipPath('clip-b') && failClipB) {
              throw const DmVideoUploadFailed('server refused');
            }
            return _uploadOf(path);
          });
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
            equals([_clipPath('clip-a'), _clipPath('clip-b')]),
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
          expect(retried.rumorEventId, equals('rumor-2'));
          expect(
            outcomes,
            equals([
              const VideoDmSendOutcome(
                conversationId: 'c1',
                recipientPubkey: _recipientPubkey,
                status: VideoDmOutcomeStatus.failed,
                sentCount: 1,
                total: 2,
              ),
              const VideoDmSendOutcome(
                conversationId: 'c1',
                recipientPubkey: _recipientPubkey,
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
          stubAutoSend();
          whenUploadVideo().thenThrow(const DmVideoUploadFailed('refused'));
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
          expect(sentPaths, isEmpty);
          expect(
            outcomes.last,
            equals(
              const VideoDmSendOutcome(
                conversationId: 'c1',
                recipientPubkey: _recipientPubkey,
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
        sends.single.completer.completeError(
          const DmVideoUploadFailed('server refused'),
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

        whenUploadVideo().thenThrow(const DmVideoTooLargeException(1 << 30));
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

      group('after the upload finished', () {
        late List<DmVideoUpload> uploads;
        late List<(DmVideoUpload, List<List<String>>)> published;

        /// Answers each upload with a new [DmVideoUpload] of its path and each
        /// publication with the next of [answers], reporting the publishing
        /// phase as the real service does.
        void stubSends(List<NIP17SendResult> answers) {
          whenUploadVideo().thenAnswer((invocation) async {
            final upload = _uploadOf(
              (invocation.namedArguments[#videoFile] as File).path,
            );
            uploads.add(upload);
            return upload;
          });
          whenPublishVideo().thenAnswer((invocation) async {
            (invocation.namedArguments[#onPhase]
                    as void Function(DmVideoSendPhase)?)
                ?.call(DmVideoSendPhase.sending);
            published.add((
              invocation.namedArguments[#uploaded] as DmVideoUpload,
              invocation.namedArguments[#extraTags] as List<List<String>>,
            ));
            return answers.removeAt(0);
          });
        }

        const unreadableInbox = NIP17SendResult.failure(
          'Recipient DM inbox unreadable; file message not published',
        );

        setUp(() {
          uploads = [];
          published = [];
        });

        test('publishes the same upload again without uploading', () async {
          stubSends([unreadableInbox, _success('rumor-retried')]);
          outbox = createOutbox();
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();
          sendVideo();
          await pumpEventQueue();
          final failed = events.last.single;
          expect(failed.phase, equals(OutgoingVideoDmPhase.failed));

          outbox.retry(failed.id);
          await pumpEventQueue();

          verify(() => anyUploadVideoOn(service)).called(1);
          expect(uploads, hasLength(1));
          expect(published, hasLength(2));
          expect(published[0].$1, same(uploads.single));
          expect(published[1].$1, same(uploads.single));
          expect(events.last.single.phase, equals(OutgoingVideoDmPhase.sent));
          expect(events.last.single.rumorEventId, equals('rumor-retried'));
          expect(outcomes.last.status, equals(VideoDmOutcomeStatus.sent));
        });

        test('goes straight from queued to publishing', () async {
          stubSends([unreadableInbox, _success('rumor-retried')]);
          outbox = createOutbox();
          final events = recordConversation('c1');
          sendVideo();
          await pumpEventQueue();
          final before = events.length;

          outbox.retry(events.last.single.id);
          await pumpEventQueue();

          expect(
            [
              for (final entries in events.skip(before))
                (entries.single.phase, entries.single.uploadProgress),
            ],
            equals([
              (OutgoingVideoDmPhase.queued, null),
              (OutgoingVideoDmPhase.publishing, null),
              (OutgoingVideoDmPhase.sent, null),
            ]),
          );
        });

        test('still waits for the signer before publishing', () async {
          stubSends([unreadableInbox, _success('rumor-retried')]);
          var signerReady = Completer<void>()..complete();
          outbox = createOutbox(waitUntilReady: (_) => signerReady.future);
          final events = recordConversation('c1');
          sendVideo();
          await pumpEventQueue();
          signerReady = Completer<void>();

          outbox.retry(events.last.single.id);
          await pumpEventQueue();

          expect(published, hasLength(1));
          expect(events.last.single.phase, equals(OutgoingVideoDmPhase.queued));

          signerReady.complete();
          await pumpEventQueue();

          expect(published, hasLength(2));
          expect(events.last.single.phase, equals(OutgoingVideoDmPhase.sent));
        });

        test('uploads again when the upload itself failed', () async {
          var uploadAttempts = 0;
          stubSends([_success('rumor-retried')]);
          whenUploadVideo().thenAnswer((invocation) async {
            if (++uploadAttempts == 1) {
              throw const DmVideoUploadFailed('server refused');
            }
            final upload = _uploadOf(
              (invocation.namedArguments[#videoFile] as File).path,
            );
            uploads.add(upload);
            return upload;
          });
          outbox = createOutbox();
          final events = recordConversation('c1');
          sendVideo();
          await pumpEventQueue();
          expect(events.last.single.phase, equals(OutgoingVideoDmPhase.failed));
          expect(published, isEmpty);

          outbox.retry(events.last.single.id);
          await pumpEventQueue();

          verify(() => anyUploadVideoOn(service)).called(2);
          expect(published.single.$1, same(uploads.single));
          expect(events.last.single.phase, equals(OutgoingVideoDmPhase.sent));
        });

        test(
          'a clip publishes its own upload again without being checked',
          () async {
            when(
              () => verifier.verify(any()),
            ).thenAnswer((_) async => _verified);
            final signed = <List<String>>[];
            stubSends([
              _success('rumor-a'),
              unreadableInbox,
              _success('rumor-b'),
            ]);
            outbox = createOutbox(
              clipVerifier: () => verifier,
              signOwnRecordings: (clips) async =>
                  signed.add([for (final clip in clips) clip.id]),
            );
            final events = recordConversation('c1');
            sendClips([
              _clip('clip-a'),
              _clip('clip-b', aspect: AspectRatio.vertical),
            ]);
            await pumpEventQueue();
            final failed = events.last[1];
            expect(failed.phase, equals(OutgoingVideoDmPhase.failed));
            clearInteractions(verifier);

            outbox.retry(failed.id);
            await pumpEventQueue();

            verifyZeroInteractions(verifier);
            expect(
              signed,
              equals([
                ['clip-a', 'clip-b'],
              ]),
            );
            expect(uploads, hasLength(2));
            expect(published, hasLength(3));
            expect(published[2].$1, same(published[1].$1));
            expect(published[2].$1, same(uploads[1]));
            expect(
              published[2].$2,
              equals([
                ['divine-clip', 'vertical'],
              ]),
            );
            expect(events.last[1].phase, equals(OutgoingVideoDmPhase.sent));
            expect(events.last[1].rumorEventId, equals('rumor-b'));
          },
        );

        test('a removed entry keeps no upload', () async {
          stubSends([unreadableInbox, _success('rumor-new')]);
          outbox = createOutbox();
          final events = recordConversation('c1');
          sendVideo();
          await pumpEventQueue();
          expect(outbox.keptUploadCount, equals(1));

          outbox.remove(events.last.single.id);
          expect(outbox.keptUploadCount, isZero);
          // A new entry that happens to reuse the removed id uploads its own
          // file.
          idCounter = 0;
          sendVideo(path: '/v/new.mp4');
          await pumpEventQueue();

          verify(() => anyUploadVideoOn(service)).called(2);
          expect(published.last.$1, same(uploads.last));
          expect(
            published.last.$1.fileUrl,
            equals('https://media.example//v/new.mp4'),
          );
        });

        test('a sent entry keeps no upload', () async {
          stubSends([unreadableInbox, _success('rumor-retried')]);
          outbox = createOutbox();
          final events = recordConversation('c1');
          sendVideo();
          await pumpEventQueue();

          outbox.retry(events.last.single.id);
          await pumpEventQueue();
          expect(events.last.single.phase, equals(OutgoingVideoDmPhase.sent));
          expect(outbox.keptUploadCount, isZero);
        });

        test(
          'publishes the same upload again after the publication threw',
          () async {
            stubSends([_success('rumor-retried')]);
            var publishes = 0;
            whenPublishVideo().thenAnswer((invocation) async {
              published.add((
                invocation.namedArguments[#uploaded] as DmVideoUpload,
                invocation.namedArguments[#extraTags] as List<List<String>>,
              ));
              if (++publishes == 1) {
                throw const SocketException('relay socket closed');
              }
              return _success('rumor-retried');
            });
            outbox = createOutbox();
            final events = recordConversation('c1');
            sendVideo();
            await pumpEventQueue();
            expect(
              events.last.single.phase,
              equals(OutgoingVideoDmPhase.failed),
            );

            outbox.retry(events.last.single.id);
            await pumpEventQueue();

            verify(() => anyUploadVideoOn(service)).called(1);
            expect(published, hasLength(2));
            expect(published[1].$1, same(published[0].$1));
            expect(published[1].$1, same(uploads.single));
            expect(events.last.single.phase, equals(OutgoingVideoDmPhase.sent));
          },
        );

        test(
          'reuses an upload kept for just under the maximum age',
          () async {
            stubSends([unreadableInbox, _success('rumor-retried')]);
            outbox = createOutbox();
            final events = recordConversation('c1');
            sendVideo();
            await pumpEventQueue();
            clockNow = clockNow.add(
              videoDmKeptUploadMaxAge - const Duration(milliseconds: 1),
            );

            outbox.retry(events.last.single.id);
            await pumpEventQueue();

            verify(() => anyUploadVideoOn(service)).called(1);
            expect(published[1].$1, same(uploads.single));
            expect(events.last.single.phase, equals(OutgoingVideoDmPhase.sent));
          },
        );

        test(
          'uploads again once the kept upload reaches the maximum age',
          () async {
            stubSends([unreadableInbox, _success('rumor-retried')]);
            outbox = createOutbox();
            final events = recordConversation('c1');
            sendVideo();
            await pumpEventQueue();
            clockNow = clockNow.add(videoDmKeptUploadMaxAge);

            outbox.retry(events.last.single.id);
            await pumpEventQueue();

            verify(() => anyUploadVideoOn(service)).called(2);
            expect(uploads, hasLength(2));
            expect(published[1].$1, same(uploads[1]));
            expect(events.last.single.phase, equals(OutgoingVideoDmPhase.sent));
            expect(outbox.keptUploadCount, isZero);
          },
        );

        test('publishing a kept upload again does not renew its age', () async {
          stubSends([unreadableInbox, unreadableInbox, _success('rumor-c')]);
          outbox = createOutbox();
          final events = recordConversation('c1');
          sendVideo();
          await pumpEventQueue();
          clockNow = clockNow.add(videoDmKeptUploadMaxAge ~/ 2);
          outbox.retry(events.last.single.id);
          await pumpEventQueue();
          expect(uploads, hasLength(1));
          clockNow = clockNow.add(videoDmKeptUploadMaxAge ~/ 2);

          outbox.retry(events.last.single.id);
          await pumpEventQueue();

          expect(uploads, hasLength(2));
          expect(published.last.$1, same(uploads.last));
        });

        test('an expired clip upload is checked and uploaded again', () async {
          when(() => verifier.verify(any())).thenAnswer((_) async => _verified);
          stubSends([unreadableInbox, _success('rumor-a')]);
          outbox = createOutbox(clipVerifier: () => verifier);
          final events = recordConversation('c1');
          sendClips([_clip('clip-a')]);
          await pumpEventQueue();
          clearInteractions(verifier);
          clockNow = clockNow.add(videoDmKeptUploadMaxAge);

          outbox.retry(events.last.single.id);
          await pumpEventQueue();

          verify(() => verifier.verify(_clipPath('clip-a'))).called(1);
          expect(uploads, hasLength(2));
          expect(published.last.$1, same(uploads.last));
          expect(events.last.single.phase, equals(OutgoingVideoDmPhase.sent));
        });

        test('dispose drops every kept upload', () async {
          stubSends([unreadableInbox, unreadableInbox]);
          outbox = createOutbox();
          sendVideo();
          sendVideo(path: '/v/b.mp4');
          await pumpEventQueue();
          expect(outbox.keptUploadCount, equals(2));

          outbox.dispose();

          expect(outbox.keptUploadCount, isZero);
        });
      });
    });

    group('waiting for a relay before publishing', () {
      late _MockDmRepository repository;
      late Completer<bool> relay;
      late DmVideoSendService realService;

      Future<NIP17SendResult> anyFileMessage() => repository.sendFileMessage(
        recipientPubkey: any(named: 'recipientPubkey'),
        fileUrl: any(named: 'fileUrl'),
        fileMetadata: any(named: 'fileMetadata'),
        extraTags: any(named: 'extraTags'),
      );

      setUp(() {
        repository = _MockDmRepository();
        relay = Completer<bool>();
        when(repository.waitForConnectedRelay).thenAnswer((_) => relay.future);
        when(anyFileMessage).thenAnswer((_) async => _success('rumor-1'));
        final ciphertext = _MockFile();
        when(ciphertext.delete).thenAnswer((_) async => ciphertext);
        final encryption = _MockDmVideoEncryption();
        when(() => encryption.encryptFile(any())).thenAnswer(
          (_) async => EncryptedVideoFile(
            ciphertextFile: ciphertext,
            key: 'c' * 64,
            nonce: 'd' * 24,
            ciphertextHash: 'a' * 64,
            plaintextHash: 'b' * 64,
            ciphertextSize: 4,
          ),
        );
        final blossom = _MockBlossomUploadService();
        when(
          () => blossom.uploadEncryptedFile(
            ciphertextFile: any(named: 'ciphertextFile'),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
            onUploadAttempt: any(named: 'onUploadAttempt'),
          ),
        ).thenAnswer(
          (_) async => BlossomUploadResult(
            success: true,
            videoId: 'a' * 64,
            url: 'https://media.example/${'a' * 64}',
          ),
        );
        realService = DmVideoSendService(
          dmRepository: repository,
          blossom: blossom,
          encryption: encryption,
          readPreview: (_) async => (blurhash: null, dimensions: null),
        );
      });

      test(
        'cancelPendingSends during the wait fails the send at once and '
        'keeps its upload',
        () async {
          outbox = createOutbox(sendService: () => realService);
          final events = recordConversation('c1');
          sendVideo();
          await pumpEventQueue();
          verify(repository.waitForConnectedRelay).called(1);
          expect(events.last.single.phase, isNot(OutgoingVideoDmPhase.failed));

          outbox.cancelPendingSends();
          await pumpEventQueue();

          expect(events.last.single.phase, equals(OutgoingVideoDmPhase.failed));
          expect(events.last.single.canRetry, isTrue);
          expect(outbox.keptUploadCount, equals(1));
          relay.complete(true);
          await pumpEventQueue();
          verifyNever(anyFileMessage);
        },
      );

      test('dispose during the wait ends the attempt at once', () async {
        outbox = createOutbox(sendService: () => realService);
        sendVideo();
        await pumpEventQueue();
        verify(repository.waitForConnectedRelay).called(1);

        outbox.dispose();
        await pumpEventQueue();
        relay.complete(true);
        await pumpEventQueue();

        verifyNever(anyFileMessage);
      });

      test('quiesce completes without waiting out the relay wait', () async {
        outbox = createOutbox(sendService: () => realService);
        sendVideo();
        await pumpEventQueue();
        verify(repository.waitForConnectedRelay).called(1);
        var quiesced = false;

        unawaited(outbox.quiesce().then((_) => quiesced = true));
        await pumpEventQueue();

        expect(relay.isCompleted, isFalse);
        expect(quiesced, isTrue);
        verifyNever(anyFileMessage);
      });

      test('publishes as soon as the wait answers', () async {
        relay.complete(true);
        outbox = createOutbox(sendService: () => realService);
        final events = recordConversation('c1');

        sendVideo();
        await pumpEventQueue();

        verify(anyFileMessage).called(1);
        expect(events.last.single.phase, equals(OutgoingVideoDmPhase.sent));
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

    group('sent entries nobody watches', () {
      setUp(stubControlledSend);

      Future<List<OutgoingVideoDm>> currentEntries(String conversationId) {
        final events = recordConversation(conversationId);
        return pumpEventQueue().then((_) => events.last);
      }

      test('are dropped when the send finishes with its chat closed', () async {
        outbox = createOutbox();
        sendVideo();
        await pumpEventQueue();

        sends.single.completer.complete(_success('rumor-a'));
        await pumpEventQueue();

        expect(await currentEntries('c1'), isEmpty);
      });

      test('are dropped when the last watcher of their chat leaves', () async {
        outbox = createOutbox();
        final subscription = outbox.watchConversation('c1').listen((_) {});
        sendVideo();
        await pumpEventQueue();
        sends.single.completer.complete(_success('rumor-a'));
        await pumpEventQueue();

        await subscription.cancel();
        await pumpEventQueue();

        expect(await currentEntries('c1'), isEmpty);
      });

      test('are kept while another watcher of their chat remains', () async {
        outbox = createOutbox();
        final kept = recordConversation('c1');
        final leaving = outbox.watchConversation('c1').listen((_) {});
        sendVideo();
        await pumpEventQueue();
        sends.single.completer.complete(_success('rumor-a'));
        await pumpEventQueue();

        await leaving.cancel();
        await pumpEventQueue();

        expect(
          kept.last.single.phase,
          equals(OutgoingVideoDmPhase.sent),
        );
      });

      test('do not take entries still in flight with them', () async {
        outbox = createOutbox();
        final subscription = outbox.watchConversation('c1').listen((_) {});
        sendVideo();
        await pumpEventQueue();

        await subscription.cancel();
        await pumpEventQueue();

        expect(
          (await currentEntries('c1')).single.phase,
          equals(OutgoingVideoDmPhase.encrypting),
        );
      });
    });

    group('account switch', () {
      test(
        'refuses to send under a different account and fails the entry',
        () async {
          await LogCaptureService().clearAllLogs();
          stubAutoSend();
          var accountIsOurs = true;
          outbox = createOutbox(isAccountCurrent: () => accountIsOurs);
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();

          accountIsOurs = false;
          sendVideo();
          await pumpEventQueue();

          expect(sentPaths, isEmpty);
          expect(events.last.single.phase, equals(OutgoingVideoDmPhase.failed));
          expect(
            events.last.single.failure,
            equals(OutgoingVideoDmFailure.failed),
          );
          expect(outcomes.single.status, equals(VideoDmOutcomeStatus.failed));
          expect(outcomes.single.sentCount, 0);
          expect(
            loggedMessages(),
            contains(
              'Video DM ${events.last.single.id} not sent: originating '
              'account no longer active',
            ),
          );
        },
      );

      test(
        'a send queued behind a running one is refused once the account '
        'changes',
        () async {
          stubControlledSend();
          var accountIsOurs = true;
          outbox = createOutbox(isAccountCurrent: () => accountIsOurs);
          final events = recordConversation('c1');

          sendVideo(path: '/v/running.mp4');
          sendVideo(path: '/v/queued.mp4');
          await pumpEventQueue();
          expect(sends, hasLength(1));

          accountIsOurs = false;
          sends[0].completer.complete(_success('rumor-1'));
          await pumpEventQueue();

          expect(
            sends,
            hasLength(1),
            reason:
                'the queued send never reaches '
                "the new account's send service",
          );
          final [running, queued] = events.last;
          // Its upload finished after the switch, and publication checks the
          // account again before it starts.
          expect(running.phase, equals(OutgoingVideoDmPhase.failed));
          expect(queued.phase, equals(OutgoingVideoDmPhase.failed));
        },
      );

      test(
        'refuses a clip batch before its check when the account changed, so '
        'nothing is signed under the new account',
        () async {
          await LogCaptureService().clearAllLogs();
          final verifier = _MockClipProvenanceVerifier();
          var signed = false;
          outbox = createOutbox(
            clipVerifier: () => verifier,
            signOwnRecordings: (_) async => signed = true,
            isAccountCurrent: () => false,
          );
          final events = recordConversation('c1');
          final outcomes = recordOutcomes();

          sendClips([_clip('clip-a')]);
          await pumpEventQueue();

          expect(signed, isFalse);
          verifyNever(() => verifier.verify(any()));
          expect(sentPaths, isEmpty);
          expect(
            events.last.every((e) => e.phase == OutgoingVideoDmPhase.failed),
            isTrue,
          );
          expect(outcomes.single.status, equals(VideoDmOutcomeStatus.failed));
          expect(
            loggedMessages(),
            contains(
              'Video DM clip batch ${events.last.first.batchId} not sent: '
              'originating account no longer active',
            ),
          );
        },
      );
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
          conversationId: 'c1',
          recipientPubkey: _recipientPubkey,
          status: VideoDmOutcomeStatus.failed,
          sentCount: 1,
          total: 3,
        ).isPartial,
        isTrue,
      );
      expect(
        const VideoDmSendOutcome(
          conversationId: 'c1',
          recipientPubkey: _recipientPubkey,
          status: VideoDmOutcomeStatus.failed,
          sentCount: 0,
          total: 3,
        ).isPartial,
        isFalse,
      );
      expect(
        const VideoDmSendOutcome(
          conversationId: 'c1',
          recipientPubkey: _recipientPubkey,
          status: VideoDmOutcomeStatus.sent,
          sentCount: 3,
          total: 3,
        ).isPartial,
        isFalse,
      );
    });
  });
}
