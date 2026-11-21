// ABOUTME: Runs one invite share at a time and reports how it ended.
// ABOUTME: Pure Dart: the screen supplies the platform share as a function.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';

/// The text shared for an invite: the message, then [url] on its own line.
///
/// A blank message shares only [url], so the invite still works.
String inviteShareText(String message, String url) {
  final trimmed = message.trim();
  return trimmed.isEmpty ? url : '$trimmed\n$url';
}

/// How the platform share sheet ended, as far as the platform can tell.
enum InviteShareOutcome { shared, dismissed, unknown }

/// Opens the platform share sheet with [text].
typedef InviteShareSend = Future<InviteShareOutcome> Function(String text);

enum InviteShareStatus { idle, sharing, shared, failed }

class InviteFriendsState extends Equatable {
  const InviteFriendsState({this.status = InviteShareStatus.idle});

  final InviteShareStatus status;

  @override
  List<Object?> get props => [status];
}

class InviteFriendsCubit extends Cubit<InviteFriendsState>
    with CloseGuardedEmit<InviteFriendsState> {
  InviteFriendsCubit() : super(const InviteFriendsState());

  /// Shares [message] and [url] through [send].
  ///
  /// Ignored while a share is already open. A dismissed sheet returns to
  /// idle so it can be tried again; when the platform cannot say what
  /// happened, the share is assumed to have gone through.
  Future<void> share(String message, String url, InviteShareSend send) async {
    if (isClosed || state.status == InviteShareStatus.sharing) return;
    emit(const InviteFriendsState(status: InviteShareStatus.sharing));
    final InviteShareOutcome outcome;
    try {
      outcome = await send(inviteShareText(message, url));
    } on Exception catch (error, stackTrace) {
      // Expected platform failure (no share target, mail fallback error):
      // nothing was sent and the person can retry.
      addError(error, stackTrace);
      emitIfOpen(const InviteFriendsState(status: InviteShareStatus.failed));
      return;
    }
    emitIfOpen(
      InviteFriendsState(
        status: outcome == InviteShareOutcome.dismissed
            ? InviteShareStatus.idle
            : InviteShareStatus.shared,
      ),
    );
  }
}
