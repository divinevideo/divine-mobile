// ABOUTME: Tests collaborator invite behavior in the post-publish edit flow.
// ABOUTME: Ensures newly added collaborators receive structured NIP-17 invites.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/video_metadata_update_service.dart';

class MockCollaboratorInviteService extends Mock
    implements CollaboratorInviteService {}

void main() {
  group('sendPostPublishCollaboratorInvites', () {
    late MockCollaboratorInviteService inviteService;

    setUp(() {
      inviteService = MockCollaboratorInviteService();
    });

    test('sends an invite for a collaborator added after publish', () async {
      const collaboratorPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      when(
        () => inviteService.sendInvite(
          collaboratorPubkey: any(named: 'collaboratorPubkey'),
          creatorPubkey: any(named: 'creatorPubkey'),
          videoAddress: any(named: 'videoAddress'),
          title: any(named: 'title'),
          thumbnailUrl: any(named: 'thumbnailUrl'),
          relayHint: any(named: 'relayHint'),
        ),
      ).thenAnswer(
        (_) async => const CollaboratorInviteResult(
          success: true,
          messageEventId: 'invite_event',
        ),
      );

      final results = await sendPostPublishCollaboratorInvites(
        inviteService: inviteService,
        video: _video(),
        previousCollaboratorPubkeys: const [],
        updatedCollaboratorPubkeys: const [collaboratorPubkey],
      );

      expect(results.keys, contains(collaboratorPubkey));
      expect(results[collaboratorPubkey]?.success, isTrue);
      verify(
        () => inviteService.sendInvite(
          collaboratorPubkey: collaboratorPubkey,
          creatorPubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          videoAddress: '34236:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:video-d-tag',
          title: 'Updated title',
          thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
          relayHint: 'wss://relay.divine.video',
        ),
      ).called(1);
    });

    test('does not invite collaborators already present before edit', () async {
      const collaboratorPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      final results = await sendPostPublishCollaboratorInvites(
        inviteService: inviteService,
        video: _video(collaboratorPubkeys: const [collaboratorPubkey]),
        previousCollaboratorPubkeys: const [collaboratorPubkey],
        updatedCollaboratorPubkeys: const [collaboratorPubkey],
      );

      expect(results, isEmpty);
      verifyNever(
        () => inviteService.sendInvite(
          collaboratorPubkey: any(named: 'collaboratorPubkey'),
          creatorPubkey: any(named: 'creatorPubkey'),
          videoAddress: any(named: 'videoAddress'),
          title: any(named: 'title'),
          thumbnailUrl: any(named: 'thumbnailUrl'),
          relayHint: any(named: 'relayHint'),
        ),
      );
    });

    test(
      'returns structured failure when a new collaborator invite throws',
      () async {
        const collaboratorPubkey =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        when(
          () => inviteService.sendInvite(
            collaboratorPubkey: any(named: 'collaboratorPubkey'),
            creatorPubkey: any(named: 'creatorPubkey'),
            videoAddress: any(named: 'videoAddress'),
            title: any(named: 'title'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            relayHint: any(named: 'relayHint'),
          ),
        ).thenThrow(Exception('relay exploded'));

        final results = await sendPostPublishCollaboratorInvites(
          inviteService: inviteService,
          video: _video(),
          previousCollaboratorPubkeys: const [],
          updatedCollaboratorPubkeys: const [collaboratorPubkey],
        );

        expect(results.keys, contains(collaboratorPubkey));
        expect(results[collaboratorPubkey]?.success, isFalse);
        expect(results[collaboratorPubkey]?.error, contains('relay exploded'));
      },
    );
  });
}

VideoEvent _video({List<String> collaboratorPubkeys = const []}) {
  return VideoEvent(
    id: 'event-id',
    pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    createdAt: 100,
    content: 'caption',
    timestamp: DateTime.fromMillisecondsSinceEpoch(100000),
    title: 'Updated title',
    videoUrl: 'https://cdn.example.com/video.mp4',
    thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
    vineId: 'video-d-tag',
    collaboratorPubkeys: collaboratorPubkeys,
  );
}
