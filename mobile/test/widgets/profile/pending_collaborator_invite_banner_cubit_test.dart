// ABOUTME: Tests for PendingCollaboratorInviteBannerCubit
// ABOUTME: Verifies a retry that outlives its banner finishes without throwing

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/profile/pending_collaborator_invite_banner_cubit.dart';

class _MockDmRepository extends Mock implements DmRepository {}

const _creatorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _collaboratorPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _videoAddress = '34236:$_creatorPubkey:video-1';

final _group = PendingCollaboratorInviteGroup(
  creatorPubkey: _creatorPubkey,
  videoAddress: _videoAddress,
  invites: [
    PendingCollaboratorInvite(
      rumorId: 'rumor-1',
      collaboratorPubkey: _collaboratorPubkey,
      creatorPubkey: _creatorPubkey,
      videoAddress: _videoAddress,
      recipientWrapStatus: OutgoingWrapStatus.failed,
      selfWrapStatus: OutgoingWrapStatus.failed,
      retryCount: 1,
      queuedAt: DateTime.utc(2026, 5, 22, 13),
    ),
  ],
);

void main() {
  group(PendingCollaboratorInviteBannerCubit, () {
    late _MockDmRepository repository;

    setUp(() {
      repository = _MockDmRepository();
    });

    group('retry', () {
      test('completes without throwing when the banner closed before the '
          'retry finished', () async {
        final retryResult = Completer<CollaboratorInviteRetrySummary>();
        when(
          () => repository.retryPendingCollaboratorInvites(any()),
        ).thenAnswer((_) => retryResult.future);
        final cubit = PendingCollaboratorInviteBannerCubit(repository);

        final retry = cubit.retry(_group);
        expect(cubit.state.isRetrying, isTrue);
        await cubit.close();
        retryResult.complete(
          const CollaboratorInviteRetrySummary(
            attemptedCount: 1,
            successCount: 1,
            failureCount: 0,
          ),
        );

        await expectLater(retry, completes);
      });
    });
  });
}
