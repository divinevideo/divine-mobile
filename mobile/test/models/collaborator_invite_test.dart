// ABOUTME: Tests how a collaborator invite card identifies its invitee.
// ABOUTME: Sent cards name the counterparty; received cards name the viewer.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/collaborator_invite.dart';

void main() {
  const viewer =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const counterparty =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const secondCounterparty =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  group(CollaboratorInvite, () {
    group('isForVideo', () {
      const invite = CollaboratorInvite(
        messageId:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        videoAddress: '34236:$viewer:skate-loop',
        videoKind: 34236,
        creatorPubkey: viewer,
        videoDTag: 'skate-loop',
        role: 'Collaborator',
      );

      VideoEvent video({
        required String pubkey,
        required String dTag,
        int? eventKind,
      }) => VideoEvent(
        id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        pubkey: pubkey,
        createdAt: 1730000000,
        content: '',
        timestamp: DateTime.utc(2024, 10, 27),
        addressableDTag: dTag,
        eventKind: eventKind,
      );

      test("matches the creator's video with the invite's d-tag", () {
        expect(
          invite.isForVideo(
            video(pubkey: viewer.toUpperCase(), dTag: 'skate-loop'),
          ),
          isTrue,
        );
      });

      test('rejects another author or another d-tag', () {
        expect(
          invite.isForVideo(video(pubkey: counterparty, dTag: 'skate-loop')),
          isFalse,
        );
        expect(
          invite.isForVideo(video(pubkey: viewer, dTag: 'other-loop')),
          isFalse,
        );
      });

      test(
        'rejects another known event kind with the same author and d-tag',
        () {
          expect(
            invite.isForVideo(
              video(pubkey: viewer, dTag: 'skate-loop', eventKind: 34235),
            ),
            isFalse,
          );
          expect(
            invite.isForVideo(
              video(pubkey: viewer, dTag: 'skate-loop', eventKind: 34236),
            ),
            isTrue,
          );
        },
      );
    });

    group('collaboratorPubkeyFor', () {
      test('names the viewer on a received invite', () {
        expect(
          CollaboratorInvite.collaboratorPubkeyFor(
            isSent: false,
            currentPubkey: viewer,
            counterpartyPubkeys: const [counterparty],
          ),
          viewer,
        );
      });

      test('names the one counterparty on a sent invite', () {
        expect(
          CollaboratorInvite.collaboratorPubkeyFor(
            isSent: true,
            currentPubkey: viewer,
            counterpartyPubkeys: const [counterparty],
          ),
          counterparty,
        );
      });

      test(
        'names nobody on a sent invite without exactly one counterparty',
        () {
          expect(
            CollaboratorInvite.collaboratorPubkeyFor(
              isSent: true,
              currentPubkey: viewer,
              counterpartyPubkeys: const [],
            ),
            isNull,
          );
          expect(
            CollaboratorInvite.collaboratorPubkeyFor(
              isSent: true,
              currentPubkey: viewer,
              counterpartyPubkeys: const [counterparty, secondCounterparty],
            ),
            isNull,
          );
        },
      );

      test('names nobody when the viewer is unknown', () {
        expect(
          CollaboratorInvite.collaboratorPubkeyFor(
            isSent: false,
            currentPubkey: '',
            counterpartyPubkeys: const [counterparty],
          ),
          isNull,
        );
      });
    });
  });
}
