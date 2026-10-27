import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/challenges/challenge_video_policy.dart';
import 'package:openvine/services/media_availability_checker.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

import '../../../packages/challenges_repository/test/synthetic.dart';

class _Client extends Mock implements NostrClient {}

class _Media extends Mock implements MediaAvailabilityChecker {}

class _Moderation extends Mock implements VideoModerationStatusService {}

void main() {
  group('ChallengeVideoPolicy refresh', () {
    setUpAll(() => registerFallbackValue(<Filter>[]));
    test(
      'current policy stays separate from pinned and current video revisions',
      () async {
        final signer = SyntheticSigner();
        final video = NostrEvent.fromJson(
          signer.sign(
            kind: 34236,
            tags: [
              ['d', 'video'],
              [
                'imeta',
                'url https://media.example.test/video.mp4',
                'm video/mp4',
                'x ${'a' * 64}',
              ],
            ],
          ),
        );
        final newer = NostrEvent.fromJson(
          signer.sign(kind: video.kind, createdAt: 110, tags: video.tags),
        );
        final client = _Client();
        final media = _Media();
        final moderation = _Moderation();
        var sourceVisible = true;
        var ownerValid = true;
        var available = true;
        VideoModerationStatus? status;
        var read = QueryResult(
          events: [Event.fromJson(newer.toJson())],
          endedBy: QueryEnd.complete,
          answeredNetworkRelayCount: 1,
        );
        when(() => client.configuredRelays)
            .thenReturn(['wss://relay.example.test']);
        when(() => client.isRelayAllowed(any())).thenReturn(true);
        when(
          () => client.readEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            useCache: false,
            requireAllRelaysSettled: true,
            maxCollectedEvents: 2,
            maxCollectedBytes: 256 * 1024,
          ),
        ).thenAnswer((_) async => read);
        when(() => moderation.fetchStatus(any()))
            .thenAnswer((_) async => status);
        when(() => media.isConfirmedAvailable(any()))
            .thenAnswer((_) async => available);
        final policy = ChallengeVideoPolicy(
          client: client,
          moderation: moderation,
          media: media,
          checkOwner: () async {
            if (!ownerValid) throw StateError('Revoked');
          },
          sourceAllowed: (_) => sourceVisible,
        );
        expect(policy.isVisible(video), isFalse);
        await policy.refresh(video);
        expect(
          policy.isVisible(video),
          isFalse,
          reason: 'Unknown moderation must not authorize playback',
        );
        status = const VideoModerationStatus(
          moderated: true,
          blocked: false,
          quarantined: false,
          ageRestricted: false,
          needsReview: false,
          aiGenerated: false,
        );
        await policy.refresh(video);
        expect(policy.isVisible(video), isTrue);
        expect(policy.currentVideoId(video), newer.id);
        expect(
          policy.isVisible(newer),
          isFalse,
          reason: 'A current revision cannot substitute for the reviewed pinned media',
        );
        sourceVisible = false;
        expect(policy.isVisible(video), isFalse);
        sourceVisible = true;
        available = false;
        await policy.refresh(video);
        expect(policy.isVisible(video), isFalse);
        read = QueryResult(
          events: [Event.fromJson(newer.toJson())],
          endedBy: QueryEnd.complete,
          possiblyCapped: true,
          answeredNetworkRelayCount: 1,
        );
        await policy.refresh(video);
        expect(policy.currentVideoId(video), isNull);
        ownerValid = false;
        await expectLater(policy.refresh(video), throwsStateError);
      },
    );
  });
}
