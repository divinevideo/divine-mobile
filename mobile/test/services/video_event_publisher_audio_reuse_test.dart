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

class _Auth extends Mock implements AuthService {}

class _Nostr extends Mock implements NostrClient {}

class _Uploads extends Mock implements UploadManager {}

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
          final publisher = VideoEventPublisher(
            uploadManager: _Uploads(),
            nostrService: nostr,
            authService: auth,
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
}
