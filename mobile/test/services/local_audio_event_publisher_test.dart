// ABOUTME: Tests for LocalAudioEventPublisher: the Kind 1063 a device-local
// ABOUTME: file becomes, with and without a source video, and each failed step.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/local_audio_event_publisher.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockRelayPublisher extends Mock implements SignedEventRelayPublisher {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _FakeEvent extends Fake implements Event {}

const _self =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _soundEventId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _sha256 =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

Event _signedAudioEvent(List<List<String>> tags) => Event.fromJson({
  'id': _soundEventId,
  'pubkey': _self,
  'created_at': 0,
  'kind': 1063,
  'tags': tags,
  'content': '',
  'sig': 'sig',
});

const _ownWork = AudioShareAttribution(
  title: 'Kitchen beat',
  creatorName: 'Alice',
  creatorPubkey: _self,
  publicTags: ['beat', 'Kitchen'],
  confirmedOwnWork: true,
);

void main() {
  late Directory tempDir;
  late File audioFile;
  late _MockAuthService authService;
  late _MockRelayPublisher relayPublisher;
  late _MockBlossomUploadService blossom;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(File('unused'));
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('local-audio-publisher');
    audioFile = File('${tempDir.path}/beat.m4a')
      ..writeAsBytesSync(const [1, 2, 3, 4]);
    authService = _MockAuthService();
    relayPublisher = _MockRelayPublisher();
    blossom = _MockBlossomUploadService();
    when(() => authService.isAuthenticated).thenReturn(true);
    when(() => authService.currentPublicKeyHex).thenReturn(_self);
    when(
      () => blossom.uploadAudio(
        audioFile: any(named: 'audioFile'),
        mimeType: any(named: 'mimeType'),
      ),
    ).thenAnswer(
      (_) async => const BlossomUploadResult(
        success: true,
        videoId: _sha256,
        fallbackUrl: 'https://cdn.example/beat.m4a',
      ),
    );
    when(
      () => authService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((invocation) async {
      final tags = invocation.namedArguments[#tags] as List<List<String>>;
      return _signedAudioEvent(tags);
    });
    when(
      () => relayPublisher.publishViaWebSocket(any()),
    ).thenAnswer((_) async => EventPublishOutcome.published);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  AudioEvent importedSound() => AudioEvent.fromLocalImport(
    id: '${AudioEvent.localImportMarker}_1',
    filePath: audioFile.path,
    createdAt: 1,
    title: 'beat',
    mimeType: 'audio/mp4',
    duration: 6.2,
  );

  LocalAudioEventPublisher publisher({bool withBlossom = true}) =>
      LocalAudioEventPublisher(
        relayPublisher: relayPublisher,
        authService: authService,
        blossomUploadService: withBlossom ? blossom : null,
      );

  List<List<String>> signedTags() =>
      verify(
            () => authService.createAndSignEvent(
              kind: 1063,
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured.single
          as List<List<String>>;

  group(LocalAudioEventPublisher, () {
    group('publish', () {
      test('mints a standalone Kind 1063 with no source video', () async {
        final result = await publisher().publish(
          audio: importedSound(),
          attribution: _ownWork,
          allowAudioReuse: true,
        );

        expect(result, isA<LocalAudioPublished>());
        final published = (result as LocalAudioPublished).audio;
        expect(published.id, _soundEventId);
        expect(published.sourceVideoReference, isNull);
        expect(published.allowsReuse, isTrue);
        expect(published.hasExplicitReuseConsent, isTrue);
        expect(published.creatorName, 'Alice');
        expect(published.creatorPubkey, _self);
        expect(published.publicTags, ['beat', 'kitchen']);
        final tags = signedTags();
        expect(
          tags,
          anyElement(equals(['url', 'https://cdn.example/beat.m4a'])),
        );
        expect(tags, anyElement(equals(['m', 'audio/mp4'])));
        expect(tags, anyElement(equals(['x', _sha256])));
        expect(tags, anyElement(equals(['size', '4'])));
        expect(tags, anyElement(equals(['duration', '6.2'])));
        expect(tags, anyElement(equals(['allow_audio_reuse', 'true'])));
        expect(tags.where((tag) => tag.first == 'a'), isEmpty);
      });

      test('carries the source-video coordinate when given one', () async {
        final result = await publisher().publish(
          audio: importedSound(),
          attribution: _ownWork,
          allowAudioReuse: false,
          sourceVideoReference: '34236:$_self:vine-1',
          sourceVideoRelay: 'wss://relay.example',
        );

        expect(result, isA<LocalAudioPublished>());
        expect(
          signedTags(),
          anyElement(
            equals(['a', '34236:$_self:vine-1', 'wss://relay.example']),
          ),
        );
        expect(
          (result as LocalAudioPublished).audio.allowsReuse,
          isFalse,
        );
      });

      test('writes the readable credit into the event content', () async {
        await publisher().publish(
          audio: importedSound(),
          attribution: _ownWork.copyWith(
            confirmedOwnWork: false,
            sourceUrl: 'https://example.com/source',
            licenseName: 'CC BY',
          ),
          allowAudioReuse: true,
        );

        final content =
            verify(
                  () => authService.createAndSignEvent(
                    kind: 1063,
                    content: captureAny(named: 'content'),
                    tags: any(named: 'tags'),
                  ),
                ).captured.single
                as String;
        expect(
          content,
          'Kitchen beat\n'
          'Created by Alice\n'
          'Source: https://example.com/source\n'
          'License: CC BY',
        );
      });

      test('refuses incomplete attribution before uploading', () async {
        final result = await publisher().publish(
          audio: importedSound(),
          attribution: const AudioShareAttribution(
            title: 'Untitled',
            creatorName: 'Alice',
            publicTags: [],
            confirmedOwnWork: false,
          ),
          allowAudioReuse: true,
        );

        expect(
          result,
          isA<LocalAudioPublishFailed>().having(
            (r) => r.failure,
            'failure',
            LocalAudioPublishFailure.invalidAttribution,
          ),
        );
        verifyNever(
          () => blossom.uploadAudio(
            audioFile: any(named: 'audioFile'),
            mimeType: any(named: 'mimeType'),
          ),
        );
      });

      test('reports a missing file without uploading', () async {
        audioFile.deleteSync();

        final result = await publisher().publish(
          audio: importedSound(),
          attribution: _ownWork,
          allowAudioReuse: true,
        );

        expect(
          result,
          isA<LocalAudioPublishFailed>().having(
            (r) => r.failure,
            'failure',
            LocalAudioPublishFailure.fileUnavailable,
          ),
        );
        verifyNever(
          () => blossom.uploadAudio(
            audioFile: any(named: 'audioFile'),
            mimeType: any(named: 'mimeType'),
          ),
        );
      });

      test('reports a missing upload service as unavailable', () async {
        final result = await publisher(withBlossom: false).publish(
          audio: importedSound(),
          attribution: _ownWork,
          allowAudioReuse: true,
        );

        expect(
          result,
          isA<LocalAudioPublishFailed>().having(
            (r) => r.failure,
            'failure',
            LocalAudioPublishFailure.fileUnavailable,
          ),
        );
      });

      test('refuses to upload for a signed-out identity', () async {
        when(() => authService.isAuthenticated).thenReturn(false);

        final result = await publisher().publish(
          audio: importedSound(),
          attribution: _ownWork,
          allowAudioReuse: true,
        );

        expect(
          result,
          isA<LocalAudioPublishFailed>().having(
            (r) => r.failure,
            'failure',
            LocalAudioPublishFailure.notAuthenticated,
          ),
        );
        verifyNever(
          () => blossom.uploadAudio(
            audioFile: any(named: 'audioFile'),
            mimeType: any(named: 'mimeType'),
          ),
        );
      });

      test('reports a rejected upload', () async {
        when(
          () => blossom.uploadAudio(
            audioFile: any(named: 'audioFile'),
            mimeType: any(named: 'mimeType'),
          ),
        ).thenAnswer(
          (_) async =>
              const BlossomUploadResult(success: false, errorMessage: '413'),
        );

        final result = await publisher().publish(
          audio: importedSound(),
          attribution: _ownWork,
          allowAudioReuse: true,
        );

        expect(
          result,
          isA<LocalAudioPublishFailed>().having(
            (r) => r.failure,
            'failure',
            LocalAudioPublishFailure.uploadFailed,
          ),
        );
        verifyNever(
          () => authService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
      });

      test('reports a signer that produced nothing', () async {
        when(
          () => authService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final result = await publisher().publish(
          audio: importedSound(),
          attribution: _ownWork,
          allowAudioReuse: true,
        );

        expect(
          result,
          isA<LocalAudioPublishFailed>().having(
            (r) => r.failure,
            'failure',
            LocalAudioPublishFailure.signingFailed,
          ),
        );
        verifyNever(() => relayPublisher.publishViaWebSocket(any()));
      });

      test('reports a relay that did not acknowledge the event', () async {
        when(
          () => relayPublisher.publishViaWebSocket(any()),
        ).thenAnswer((_) async => EventPublishOutcome.transientFailure);

        final result = await publisher().publish(
          audio: importedSound(),
          attribution: _ownWork,
          allowAudioReuse: true,
        );

        expect(
          result,
          isA<LocalAudioPublishFailed>().having(
            (r) => r.failure,
            'failure',
            LocalAudioPublishFailure.relayRejected,
          ),
        );
      });

      test('lets an account restriction surface to the caller', () async {
        when(() => relayPublisher.publishViaWebSocket(any())).thenThrow(
          const AccountRestrictedPublishException(
            reason: 'blocked: pubkey is suspended',
            source: AccountRestrictionSource.webSocket,
          ),
        );

        await expectLater(
          publisher().publish(
            audio: importedSound(),
            attribution: _ownWork,
            allowAudioReuse: true,
          ),
          throwsA(isA<AccountRestrictedPublishException>()),
        );
      });
    });

    group('audioEventCreditContent', () {
      test('omits blank source and license lines', () {
        expect(
          audioEventCreditContent(
            title: ' Beat ',
            creatorName: ' Alice ',
            sourceUrl: '  ',
          ),
          'Beat\nCreated by Alice',
        );
      });
    });
  });
}
