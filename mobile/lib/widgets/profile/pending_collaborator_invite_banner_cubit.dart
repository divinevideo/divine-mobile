// ABOUTME: Cubit for queued collaborator-invite banner retry state.
// ABOUTME: Owns retry orchestration so the banner widget only renders + listens.

import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';

enum PendingCollaboratorInviteBannerFeedback {
  none,
  retryUnavailable,
  retryCompleted,
}

class PendingCollaboratorInviteBannerState extends Equatable {
  const PendingCollaboratorInviteBannerState({
    this.isRetrying = false,
    this.feedback = PendingCollaboratorInviteBannerFeedback.none,
    this.remainingInviteCount = 0,
    this.blockedInviteCount = 0,
  });

  final bool isRetrying;
  final PendingCollaboratorInviteBannerFeedback feedback;

  /// Invites that failed transiently and remain queued for a later retry.
  final int remainingInviteCount;

  /// Invites terminally dropped because the collaborator cannot receive DMs
  /// (a confirmed #176 policy block). Their queue rows are deleted, so they
  /// are surfaced apart from [remainingInviteCount].
  final int blockedInviteCount;

  PendingCollaboratorInviteBannerState copyWith({
    bool? isRetrying,
    PendingCollaboratorInviteBannerFeedback? feedback,
    int? remainingInviteCount,
    int? blockedInviteCount,
  }) {
    return PendingCollaboratorInviteBannerState(
      isRetrying: isRetrying ?? this.isRetrying,
      feedback: feedback ?? this.feedback,
      remainingInviteCount: remainingInviteCount ?? this.remainingInviteCount,
      blockedInviteCount: blockedInviteCount ?? this.blockedInviteCount,
    );
  }

  @override
  List<Object?> get props => [
    isRetrying,
    feedback,
    remainingInviteCount,
    blockedInviteCount,
  ];
}

class PendingCollaboratorInviteBannerCubit
    extends Cubit<PendingCollaboratorInviteBannerState>
    with CloseGuardedEmit<PendingCollaboratorInviteBannerState> {
  PendingCollaboratorInviteBannerCubit(this._dmRepository)
    : super(const PendingCollaboratorInviteBannerState());

  final DmRepository? _dmRepository;

  Future<void> retry(PendingCollaboratorInviteGroup group) async {
    final repository = _dmRepository;
    if (repository == null) {
      emit(
        state.copyWith(
          feedback: PendingCollaboratorInviteBannerFeedback.retryUnavailable,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isRetrying: true,
        feedback: PendingCollaboratorInviteBannerFeedback.none,
      ),
    );

    final summary = await repository.retryPendingCollaboratorInvites(
      group.invites,
    );

    // The banner can close mid-retry (tab switch, group cleared); the invites
    // were still retried, so there is only a result left to drop.
    emitIfOpen(
      state.copyWith(
        isRetrying: false,
        feedback: PendingCollaboratorInviteBannerFeedback.retryCompleted,
        remainingInviteCount: summary.failureCount,
        blockedInviteCount: summary.blockedCount,
      ),
    );
  }
}
