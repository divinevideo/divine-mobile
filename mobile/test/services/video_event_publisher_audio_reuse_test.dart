import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:videos_repository/videos_repository.dart'
    show
        LatestVideoRevision,
        LatestVideoRevisionAbsent,
        LatestVideoRevisionFound,
        LatestVideoRevisionUnknown,
        VideosRepository;

import '../helpers/test_pubkeys.dart';

class _Auth extends Mock implements AuthService {}

class _Nostr extends Mock implements NostrClient {}

class _Uploads extends Mock implements UploadManager {}

class _Videos extends Mock implements VideosRepository {}

class _Event extends Fake implements Event {}

const owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const audio =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
void main() {
  setUpAll(() {
    registerFallbackValue(_Event());
    registerFallbackValue(Duration.zero);
  });
  for (final accepted in [true, false]) {
    group('interactions', () {
      test(
        'audio metadata replacement preserves unrelated metadata; accepted=$accepted',
        () async {
          final auth = _Auth();
          final nostr = _Nostr();
          final original = Event.fromJson({
            'id': 'c' * 64,
            'pubkey': owner,
            'kind': 34236,
            'created_at': 4102444800,
            'content': 'Keep this description',
            'sig': 'd' * 128,
            'tags': [
              ['d', 'clip:one'],
              ['imeta', 'url https://example.com/video.mp4', 'm video/mp4'],
              ['text-track', 'captions'],
              ['t', 'fun'],
              ['allow_audio_reuse', 'false'],
            ],
          });
          final source = VideoEvent.fromNostrEvent(original);
          when(() => auth.currentPublicKeyHex).thenReturn(owner);
          when(() => auth.isAuthenticated).thenReturn(true);
          Event? signed;
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((call) async {
            return signed = Event.fromJson({
              'id': 'e' * 64,
              'pubkey': owner,
              'kind': call.namedArguments[#kind],
              'content': call.namedArguments[#content],
              'created_at': call.namedArguments[#createdAt],
              'tags': call.namedArguments[#tags],
              'sig': 'f' * 128,
            });
          });
          when(() => nostr.isInitialized).thenReturn(true);
          when(() => nostr.configuredRelayCount).thenReturn(1);
          when(() => nostr.connectedRelayCount).thenReturn(1);
          when(() => nostr.configuredRelays)
              .thenReturn(['wss://relay.divine.video']);
          when(() => nostr.connectedRelays)
              .thenReturn(['wss://relay.divine.video']);
          when(
            () => nostr.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer(
            (call) async => PublishOutcome(
              eventId: (call.positionalArguments[0] as Event).id,
              acceptedBy: accepted ? ['wss://relay.divine.video'] : [],
              rejectedBy: accepted
                  ? {}
                  : {'wss://relay.divine.video': 'denied'},
              noResponseFrom: [],
            ),
          );
          final videos = _Videos();
          when(
            () => videos.fetchLatestVideoRevision('34236:$owner:clip:one'),
          ).thenAnswer((_) async => LatestVideoRevisionFound(original));
          final publisher = VideoEventPublisher(
            uploadManager: _Uploads(),
            nostrService: nostr,
            authService: auth,
            videosRepositoryGetter: () => videos,
          );
          final publication = publisher.republishWithAudioReuse(
            existingEvent: source,
            audioEventId: audio,
            audioRelayHint: 'wss://relay.divine.video',
          );
          if (accepted) {
            expect(await publication, isA<VideoEvent>());
          } else {
            await expectLater(
              publication,
              throwsA(isA<SoundReusePublicationException>()),
            );
          }
          expect(signed!.kind, 34236);
          expect(signed!.createdAt, 4102444801);
          expect(signed!.content, 'Keep this description');
          expect(
            signed!.tags,
            containsAll([
              ['d', 'clip:one'],
              ['imeta', 'url https://example.com/video.mp4', 'm video/mp4'],
              ['text-track', 'captions'],
              ['t', 'fun'],
              ['allow_audio_reuse', 'true'],
              ['e', audio, 'wss://relay.divine.video', 'audio'],
            ]),
          );
          expect(signed!.tags, hasLength(6));
          expect(signed!.tags, isNot(contains(['allow_audio_reuse', 'false'])));
        },
      );
    });
  }

  group('newest revision on the relays', () {
    late _Auth auth;
    late _Nostr nostr;
    late _Videos videos;
    Event? signed;

    Event revision({
      required String id,
      required int createdAt,
      required String content,
      List<List<String>> extraTags = const [],
    }) => Event.fromJson({
      'id': id,
      'pubkey': owner,
      'kind': 34236,
      'created_at': createdAt,
      'content': content,
      'sig': '',
      'tags': [
        ['d', 'clip:one'],
        ['imeta', 'url https://example.com/video.mp4', 'm video/mp4'],
        ['allow_audio_reuse', 'false'],
        ...extraTags,
      ],
    });

    late VideoEvent opened;

    setUp(() {
      auth = _Auth();
      nostr = _Nostr();
      videos = _Videos();
      signed = null;
      opened = VideoEvent.fromNostrEvent(
        revision(id: 'c' * 64, createdAt: 1700000000, content: 'Opened'),
      );
      when(() => auth.currentPublicKeyHex).thenReturn(owner);
      when(() => auth.isAuthenticated).thenReturn(true);
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((call) async {
        return signed = Event.fromJson({
          'id': 'e' * 64,
          'pubkey': owner,
          'kind': call.namedArguments[#kind],
          'content': call.namedArguments[#content],
          'created_at': call.namedArguments[#createdAt],
          'tags': call.namedArguments[#tags],
          'sig': 'f' * 128,
        });
      });
      when(() => nostr.isInitialized).thenReturn(true);
      when(() => nostr.configuredRelayCount).thenReturn(1);
      when(() => nostr.connectedRelayCount).thenReturn(1);
      when(() => nostr.configuredRelays)
          .thenReturn(['wss://relay.divine.video']);
      when(() => nostr.connectedRelays)
          .thenReturn(['wss://relay.divine.video']);
      when(
        () => nostr.publishEventAwaitOk(any(), timeout: any(named: 'timeout')),
      ).thenAnswer(
        (call) async => PublishOutcome(
          eventId: (call.positionalArguments[0] as Event).id,
          acceptedBy: ['wss://relay.divine.video'],
          rejectedBy: {},
          noResponseFrom: [],
        ),
      );
    });

    VideoEventPublisher publisherWith(LatestVideoRevision answer) {
      when(
        () => videos.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => answer);
      return VideoEventPublisher(
        uploadManager: _Uploads(),
        nostrService: nostr,
        authService: auth,
        videosRepositoryGetter: () => videos,
      );
    }

    test('rebuilds from the newest revision, not the copy in hand', () async {
      const subtitles = [
        'text-track',
        'https://example.com/subs-en.vtt',
        'wss://relay.divine.video',
        'captions',
        'en',
      ];
      final publisher = publisherWith(
        LatestVideoRevisionFound(
          revision(
            id: 'd' * 64,
            createdAt: 4102444800,
            content: 'Newer description',
            extraTags: const [subtitles],
          ),
        ),
      );

      await publisher.republishWithAudioReuse(
        existingEvent: opened,
        audioEventId: audio,
        audioRelayHint: 'wss://relay.divine.video',
      );

      expect(signed!.tags, contains(equals(subtitles)));
      expect(signed!.content, 'Newer description');
      expect(signed!.createdAt, 4102444801);
      expect(
        signed!.tags,
        contains(equals(['e', audio, 'wss://relay.divine.video', 'audio'])),
      );
    });

    test('keeps a different sound linked by a newer revision', () async {
      final publisher = publisherWith(
        LatestVideoRevisionFound(
          revision(
            id: 'd' * 64,
            createdAt: 4102444800,
            content: 'Newer description',
            extraTags: [
              ['e', 'f' * 64, '', 'audio'],
            ],
          ),
        ),
      );
      await expectLater(
        publisher.republishWithAudioReuse(
          existingEvent: opened,
          audioEventId: audio,
          audioRelayHint: 'wss://relay.divine.video',
        ),
        throwsA(isA<SoundReusePublicationException>()),
      );
      expect(signed, isNull);
    });

    test('refuses when the account changes during the newest read', () async {
      var account = owner;
      when(() => auth.currentPublicKeyHex).thenAnswer((_) => account);
      when(() => videos.fetchLatestVideoRevision(any())).thenAnswer((_) async {
        account = syntheticOtherTestPubkey;
        return LatestVideoRevisionFound(
          revision(id: 'd' * 64, createdAt: 4102444800, content: 'Newer'),
        );
      });
      final publisher = VideoEventPublisher(
        uploadManager: _Uploads(),
        nostrService: nostr,
        authService: auth,
        videosRepositoryGetter: () => videos,
      );

      await expectLater(
        publisher.republishWithAudioReuse(
          existingEvent: opened,
          audioEventId: audio,
          audioRelayHint: 'wss://relay.divine.video',
        ),
        throwsA(isA<SoundReusePublicationException>()),
      );
      expect(signed, isNull);
    });

    test('refuses when the approval ends during the newest read', () async {
      var current = true;
      when(() => videos.fetchLatestVideoRevision(any())).thenAnswer((_) async {
        current = false;
        return LatestVideoRevisionFound(
          revision(id: 'd' * 64, createdAt: 4102444800, content: 'Newer'),
        );
      });
      final publisher = VideoEventPublisher(
        uploadManager: _Uploads(),
        nostrService: nostr,
        authService: auth,
        videosRepositoryGetter: () => videos,
      );

      await expectLater(
        publisher.republishWithAudioReuse(
          existingEvent: opened,
          audioEventId: audio,
          audioRelayHint: 'wss://relay.divine.video',
          isOperationCurrent: () => current,
        ),
        throwsA(isA<SoundReusePublicationException>()),
      );
      expect(signed, isNull);
    });

    for (final (name, answer) in [
      ('cannot tell', const LatestVideoRevisionUnknown()),
      ('hold none', const LatestVideoRevisionAbsent()),
    ]) {
      test('refuses when the relays $name what the newest revision is', () {
        final publisher = publisherWith(answer);

        expect(
          publisher.republishWithAudioReuse(
            existingEvent: opened,
            audioEventId: audio,
            audioRelayHint: 'wss://relay.divine.video',
          ),
          throwsA(isA<SoundReusePublicationException>()),
        );
      });
    }

    test('refuses when it has no repository to read the newest revision '
        'from', () async {
      final publisher = VideoEventPublisher(
        uploadManager: _Uploads(),
        nostrService: nostr,
        authService: auth,
      );

      await expectLater(
        publisher.republishWithAudioReuse(
          existingEvent: opened,
          audioEventId: audio,
          audioRelayHint: 'wss://relay.divine.video',
        ),
        throwsA(isA<SoundReusePublicationException>()),
      );
      expect(signed, isNull);
    });
  });
}
