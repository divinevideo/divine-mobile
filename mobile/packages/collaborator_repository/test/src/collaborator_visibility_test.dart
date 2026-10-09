// ABOUTME: Tests for CollaboratorVisibility view-model.

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

const _creator =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _creatorUpper =
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _collab1 =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _collab1Upper =
    'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const _collab2 =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _viewer =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

void main() {
  group(CollaboratorVisibility, () {
    group('fallback', () {
      test('shows nothing to a viewer who is not the author', () {
        const vis = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1, _collab2],
          currentUserPubkey: _viewer,
          creatorPubkey: _creator,
        );
        expect(vis.visiblePubkeys, isEmpty);
      });

      test('shows nothing when the viewer is unknown', () {
        const vis = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1, _collab2],
        );
        expect(vis.isInviterView, isFalse);
        expect(vis.visiblePubkeys, isEmpty);
      });

      test('shows the author every invitee as pending', () {
        const vis = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1, _collab2],
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.visiblePubkeys, equals([_collab1, _collab2]));
        expect(vis.isPendingForInviter(_collab1), isTrue);
        expect(vis.pendingCount, equals(2));
      });

      test('statusFor returns pending for any pubkey', () {
        const vis = CollaboratorVisibility.fallback(taggedPubkeys: [_collab1]);
        expect(vis.statusFor(_collab1), equals(CollaboratorStatus.pending));
        expect(vis.statusFor(_collab2), equals(CollaboratorStatus.pending));
      });
    });

    group('inviter view', () {
      test('isInviterView true when current user is the creator', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.pending},
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.isInviterView, isTrue);
      });

      test('pending entries flagged as pending; confirmed are not', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.pending,
            _collab2: CollaboratorStatus.confirmed,
          },
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.isPendingForInviter(_collab1), isTrue);
        expect(vis.isPendingForInviter(_collab2), isFalse);
      });

      test('creator and status comparisons are case-insensitive', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1Upper: CollaboratorStatus.pending},
          currentUserPubkey: _creatorUpper,
          creatorPubkey: _creator,
        );
        expect(vis.isInviterView, isTrue);
        expect(vis.isPendingForInviter(_collab1), isTrue);
        expect(vis.pendingCount, equals(1));
      });

      test('missing entries default to pending', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {},
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.isPendingForInviter(_collab1), isTrue);
      });

      test('pendingCount counts pending entries only', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.pending,
            _collab2: CollaboratorStatus.confirmed,
          },
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.pendingCount, equals(1));
      });

      test('visiblePubkeys returns all tagged when none ignored', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.pending,
            _collab2: CollaboratorStatus.confirmed,
          },
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.visiblePubkeys, equals([_collab1, _collab2]));
      });
    });

    group('recipient view', () {
      test('isInviterView false when current user is a collaborator', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.pending},
          currentUserPubkey: _collab1,
          creatorPubkey: _creator,
        );
        expect(vis.isInviterView, isFalse);
      });

      test('isPendingForInviter false for recipient view', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.pending,
            _collab2: CollaboratorStatus.pending,
          },
          currentUserPubkey: _collab1,
          creatorPubkey: _creator,
        );
        expect(vis.isPendingForInviter(_collab1), isFalse);
        expect(vis.isPendingForInviter(_collab2), isFalse);
      });

      test(
        'current user ignore is hidden when visibility receives normalized tag',
        () {
          const vis = CollaboratorVisibility(
            taggedPubkeys: [_collab1],
            statusByPubkey: {_collab1Upper: CollaboratorStatus.ignored},
            currentUserPubkey: _collab1Upper,
            creatorPubkey: _creator,
            isResolved: true,
          );
          expect(vis.visiblePubkeys, isEmpty);
        },
      );

      // Pre-#6907 this group also pinned that a recipient sees the full raw
      // tagged list — unconfirmed peers included, and their own entry visible
      // even while pending. That contract is exactly what #6907 removes; the
      // replacement lives in the 'tagged collaborator viewing a video they
      // did not author' group below.
    });

    group('third-party view', () {
      test('isInviterView false', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.pending},
          currentUserPubkey: _viewer,
          creatorPubkey: _creator,
        );
        expect(vis.isInviterView, isFalse);
      });

      test('unconfirmed filtered out, and no pending decoration', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.pending,
            _collab2: CollaboratorStatus.confirmed,
          },
          currentUserPubkey: _viewer,
          creatorPubkey: _creator,
          isResolved: true,
        );
        expect(vis.visiblePubkeys, equals([_collab2]));
        expect(vis.pendingCount, equals(0));
        expect(vis.isPendingForInviter(_collab1), isFalse);
        expect(vis.isPendingForInviter(_collab2), isFalse);
      });
    });

    group('equality', () {
      test('two equivalent instances compare equal', () {
        const a = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.confirmed},
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        const b = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.confirmed},
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(a, equals(b));
      });

      test('instances for different viewers are unequal', () {
        const author = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1],
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        const thirdParty = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1],
          currentUserPubkey: _viewer,
          creatorPubkey: _creator,
        );
        expect(author, isNot(equals(thirdParty)));
      });

      test('an empty viewer and creator never make an inviter view', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {},
          currentUserPubkey: '',
          creatorPubkey: '',
          isResolved: true,
        );
        expect(vis.isInviterView, isFalse);
        expect(vis.visiblePubkeys, isEmpty);
      });
    });

    group('third-party viewer', () {
      test('renders nothing until the acceptance query resolves', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {_collab1: CollaboratorStatus.confirmed},
          currentUserPubkey: _viewer,
          creatorPubkey: _creator,
        );
        expect(
          vis.visiblePubkeys,
          isEmpty,
          reason:
              'Before EOSE an absent entry means "not heard back yet"; '
              'rendering then would flash a partial list.',
        );
      });

      test('renders only confirmed collaborators once resolved', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.confirmed,
            _collab2: CollaboratorStatus.pending,
          },
          currentUserPubkey: _viewer,
          creatorPubkey: _creator,
          isResolved: true,
        );
        expect(
          vis.visiblePubkeys,
          equals([_collab1]),
          reason:
              'A creator can tag any pubkey; crediting an unconfirmed one '
              'publicly is the #6907 leak.',
        );
      });

      test('hides a collaborator who was tagged but never accepted', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.pending},
          currentUserPubkey: _viewer,
          creatorPubkey: _creator,
          isResolved: true,
        );
        expect(vis.visiblePubkeys, isEmpty);
      });

      test('pendingCount stays zero so no pending suffix leaks', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {_collab1: CollaboratorStatus.pending},
          currentUserPubkey: _viewer,
          creatorPubkey: _creator,
          isResolved: true,
        );
        expect(vis.pendingCount, isZero);
      });
    });

    group('inviter view is unaffected by the third-party filter', () {
      test('still shows unconfirmed collaborators once resolved', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.confirmed,
            _collab2: CollaboratorStatus.pending,
          },
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
          isResolved: true,
        );
        expect(
          vis.visiblePubkeys,
          equals([_collab1, _collab2]),
          reason: 'The author needs to see who they invited.',
        );
        expect(vis.pendingCount, equals(1));
        expect(vis.isPendingForInviter(_collab2), isTrue);
      });

      test('drops the author own entry when they self-tagged then ignored', () {
        // Defensive coverage for malformed or hand-built visibility inputs:
        // a local ignore still hides the current user's own chip.
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_creator, _collab1],
          statusByPubkey: {
            _creator: CollaboratorStatus.ignored,
            _collab1: CollaboratorStatus.confirmed,
          },
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
          isResolved: true,
        );
        expect(vis.visiblePubkeys, equals([_collab1]));
      });

      test('shows unconfirmed collaborators even before resolve', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.pending},
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(
          vis.visiblePubkeys,
          equals([_collab1]),
          reason:
              'The author already knows who they tagged, so gating their own '
              'view on EOSE would only make the row flicker.',
        );
      });
    });

    group('tagged collaborator viewing a video they did not author', () {
      test('sees themselves once their acceptance is confirmed', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.confirmed},
          currentUserPubkey: _collab1,
          creatorPubkey: _creator,
          isResolved: true,
        );
        expect(vis.visiblePubkeys, equals([_collab1]));
      });

      test('does not see themselves after locally ignoring', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.ignored},
          currentUserPubkey: _collab1,
          creatorPubkey: _creator,
          isResolved: true,
        );
        expect(vis.visiblePubkeys, isEmpty);
      });
    });
  });
}
