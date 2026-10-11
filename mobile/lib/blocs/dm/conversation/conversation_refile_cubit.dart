// ABOUTME: Reports where an open conversation's messages went when the
// ABOUTME: repository takes it apart, so its screen can follow them (#10037).

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';

/// The conversations the messages of one conversation were moved to.
///
/// A reply that tags someone extra opens a room when it is stored before the
/// message it answers, and moves under that message once it arrives. Empty
/// until that happens to the conversation this cubit was created for.
class ConversationRefileCubit extends Cubit<Set<String>>
    with CloseGuardedEmit<Set<String>> {
  ConversationRefileCubit({
    required DmRepository dmRepository,
    required String conversationId,
  }) : super(const {}) {
    _subscription = dmRepository
        .watchRefiledFrom(conversationId)
        .listen(emitIfOpen);
  }

  late final StreamSubscription<Set<String>> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
