// ABOUTME: Tests for SoundUploadCubit: importing a picked file, owning the
// ABOUTME: credit's creator pubkey, and the publish lifecycle.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/blocs/sound_upload/sound_upload_cubit.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/services/local_audio_event_publisher.dart';
import 'package:openvine/services/local_audio_import_service.dart';

class _MockImportService extends Mock implements LocalAudioImportService {}

class _MockPublisher extends Mock implements LocalAudioEventPublisher {}

class _FakeAudioEvent extends Fake implements AudioEvent {}

class _FakeAttribution extends Fake implements AudioShareAttribution {}

const _self =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _soundEventId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

AudioEvent _imported() => AudioEvent.fromLocalImport(
  id: '${AudioEvent.localImportMarker}_1',
  filePath: '/tmp/beat.m4a',
  createdAt: 1,
  title: 'beat',
  mimeType: 'audio/mp4',
  duration: 6.2,
);

Event _publishedEvent() => Event.fromJson({
  'id': _soundEventId,
  'pubkey': _self,
  'created_at': 0,
  'kind': 1063,
  'tags': [
    ['title', 'beat'],
    ['allow_audio_reuse', 'true'],
  ],
  'content': '',
  'sig': 'sig',
});

void main() {
  late _MockImportService importService;
  late _MockPublisher publisher;

  setUpAll(() {
    registerFallbackValue(_FakeAudioEvent());
    registerFallbackValue(_FakeAttribution());
  });

  setUp(() {
    importService = _MockImportService();
    publisher = _MockPublisher();
    when(
      () => importService.importAudioFile(
        sourcePath: any(named: 'sourcePath'),
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer((_) async => _imported());
  });

  SoundUploadCubit buildCubit({String? publisherPubkey = _self}) =>
      SoundUploadCubit(
        importService: importService,
        publisher: publisher,
        publisherName: 'Alice',
        publisherPubkey: publisherPubkey,
      );

  Future<SoundUploadCubit> readyCubit() async {
    final cubit = buildCubit();
    await cubit.importFile(
      sourcePath: '/picked/beat.m4a',
      displayName: 'beat.m4a',
    );
    return cubit;
  }

  group(SoundUploadCubit, () {
    group('importFile', () {
      blocTest<SoundUploadCubit, SoundUploadState>(
        'copies the file and seeds an own-work credit for the publisher',
        build: buildCubit,
        act: (cubit) => cubit.importFile(
          sourcePath: '/picked/beat.m4a',
          displayName: 'beat.m4a',
        ),
        expect: () => [
          const SoundUploadState(status: SoundUploadStatus.importing),
          isA<SoundUploadState>()
              .having((s) => s.status, 'status', SoundUploadStatus.ready)
              .having((s) => s.sound?.title, 'sound title', 'beat')
              .having(
                (s) => s.attribution,
                'attribution',
                const AudioShareAttribution(
                  title: 'beat',
                  creatorName: 'Alice',
                  creatorPubkey: _self,
                  publicTags: [],
                  confirmedOwnWork: true,
                ),
              )
              .having((s) => s.canPublish, 'canPublish', isTrue),
        ],
        verify: (_) => verify(
          () => importService.importAudioFile(
            sourcePath: '/picked/beat.m4a',
            displayName: 'beat.m4a',
          ),
        ).called(1),
      );

      blocTest<SoundUploadCubit, SoundUploadState>(
        'reports an unreadable file and stays idle',
        build: buildCubit,
        setUp: () => when(
          () => importService.importAudioFile(
            sourcePath: any(named: 'sourcePath'),
            displayName: any(named: 'displayName'),
          ),
        ).thenThrow(const LocalAudioImportException('nope')),
        act: (cubit) => cubit.importFile(
          sourcePath: '/picked/beat.m4a',
          displayName: 'beat.m4a',
        ),
        expect: () => const [
          SoundUploadState(status: SoundUploadStatus.importing),
          SoundUploadState(failure: SoundUploadFailure.importFailed),
        ],
        errors: () => [isA<LocalAudioImportException>()],
      );

      blocTest<SoundUploadCubit, SoundUploadState>(
        'keeps the previous pick when a re-pick fails',
        build: buildCubit,
        act: (cubit) async {
          await cubit.importFile(
            sourcePath: '/picked/beat.m4a',
            displayName: 'beat.m4a',
          );
          when(
            () => importService.importAudioFile(
              sourcePath: any(named: 'sourcePath'),
              displayName: any(named: 'displayName'),
            ),
          ).thenThrow(const LocalAudioImportException('nope'));
          await cubit.importFile(
            sourcePath: '/picked/other.m4a',
            displayName: 'other.m4a',
          );
        },
        skip: 2,
        expect: () => [
          isA<SoundUploadState>().having(
            (s) => s.status,
            'status',
            SoundUploadStatus.importing,
          ),
          isA<SoundUploadState>()
              .having((s) => s.status, 'status', SoundUploadStatus.ready)
              .having((s) => s.sound?.title, 'sound title', 'beat')
              .having(
                (s) => s.failure,
                'failure',
                SoundUploadFailure.importFailed,
              ),
        ],
        errors: () => [isA<LocalAudioImportException>()],
      );
    });

    group('updateAttribution', () {
      test('credits the publisher pubkey only while it is own work', () async {
        final cubit = await readyCubit();
        addTearDown(cubit.close);

        cubit.updateAttribution(
          cubit.state.attribution!.copyWith(
            creatorName: 'Bucket drummer',
            confirmedOwnWork: false,
            sourceUrl: 'https://example.com/source',
          ),
        );
        expect(cubit.state.attribution?.creatorPubkey, isNull);
        expect(cubit.state.attribution?.creatorName, 'Bucket drummer');
        expect(cubit.state.canPublish, isTrue);

        cubit.updateAttribution(
          cubit.state.attribution!.copyWith(confirmedOwnWork: true),
        );
        expect(cubit.state.attribution?.creatorPubkey, _self);
      });

      test('disables sharing while the credit is incomplete', () async {
        final cubit = await readyCubit();
        addTearDown(cubit.close);

        cubit.updateAttribution(
          cubit.state.attribution!.copyWith(confirmedOwnWork: false),
        );

        expect(cubit.state.canPublish, isFalse);
      });

      test('is ignored before a file is picked', () {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        cubit.updateAttribution(
          const AudioShareAttribution(
            title: 'x',
            creatorName: 'y',
            publicTags: [],
            confirmedOwnWork: true,
          ),
        );

        expect(cubit.state, const SoundUploadState());
      });
    });

    group('publish', () {
      test('publishes a reusable sound and exposes it as published', () async {
        when(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer((_) async => LocalAudioPublished(_publishedEvent()));
        final cubit = await readyCubit();
        addTearDown(cubit.close);
        final statuses = <SoundUploadStatus>[];
        final subscription = cubit.stream.listen(
          (state) => statuses.add(state.status),
        );
        addTearDown(subscription.cancel);

        await cubit.publish();
        await pumpEventQueue();

        expect(statuses, [
          SoundUploadStatus.publishing,
          SoundUploadStatus.published,
        ]);
        expect(cubit.state.publishedSound?.id, _soundEventId);
        verify(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: cubit.state.attribution!,
            allowAudioReuse: true,
          ),
        ).called(1);
      });

      test('maps a failed step back to ready with a failure', () async {
        when(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer(
          (_) async => const LocalAudioPublishFailed(
            LocalAudioPublishFailure.uploadFailed,
          ),
        );
        final cubit = await readyCubit();
        addTearDown(cubit.close);

        await cubit.publish();

        expect(cubit.state.status, SoundUploadStatus.ready);
        expect(cubit.state.failure, SoundUploadFailure.publishFailed);
        expect(cubit.state.publishedSound, isNull);
        expect(cubit.state.canPublish, isTrue);
      });

      test('names a signed-out identity as its own failure', () async {
        when(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer(
          (_) async => const LocalAudioPublishFailed(
            LocalAudioPublishFailure.notAuthenticated,
          ),
        );
        final cubit = await readyCubit();
        addTearDown(cubit.close);

        await cubit.publish();

        expect(cubit.state.failure, SoundUploadFailure.notSignedIn);
      });

      test('surfaces an account restriction', () async {
        when(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenThrow(
          const AccountRestrictedPublishException(
            reason: 'blocked: pubkey is suspended',
            source: AccountRestrictionSource.webSocket,
          ),
        );
        final cubit = await readyCubit();
        addTearDown(cubit.close);

        await cubit.publish();

        expect(cubit.state.status, SoundUploadStatus.ready);
        expect(cubit.state.failure, SoundUploadFailure.accountRestricted);
      });

      test('clears the previous failure when retrying', () async {
        var attempt = 0;
        when(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          return attempt == 1
              ? const LocalAudioPublishFailed(
                  LocalAudioPublishFailure.relayRejected,
                )
              : LocalAudioPublished(_publishedEvent());
        });
        final cubit = await readyCubit();
        addTearDown(cubit.close);
        await cubit.publish();
        expect(cubit.state.failure, SoundUploadFailure.publishFailed);

        await cubit.publish();

        expect(cubit.state.failure, isNull);
        expect(cubit.state.status, SoundUploadStatus.published);
      });

      test('does nothing without a valid credit', () async {
        final cubit = await readyCubit();
        addTearDown(cubit.close);
        cubit.updateAttribution(
          cubit.state.attribution!.copyWith(title: '   '),
        );

        await cubit.publish();

        expect(cubit.state.status, SoundUploadStatus.ready);
        verifyNever(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        );
      });
    });
  });
}
