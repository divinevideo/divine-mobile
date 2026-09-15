// ABOUTME: State for opening a private native support conversation
// ABOUTME: Exposes loading and fallback outcomes without leaking services into UI

import 'package:equatable/equatable.dart';

enum SupportContactStatus {
  idle,
  opening,
  messagingOpened,
  emailOpened,
  emailFailed,
}

class SupportContactState extends Equatable {
  const SupportContactState({this.status = SupportContactStatus.idle});

  final SupportContactStatus status;

  @override
  List<Object?> get props => [status];
}
