// ABOUTME: State for opening the native support conversation from Support Center
// ABOUTME: Exposes loading and fallback outcomes without leaking services into UI

import 'package:equatable/equatable.dart';

enum SupportContactStatus { idle, opening, opened, unavailable }

class SupportContactState extends Equatable {
  const SupportContactState({this.status = SupportContactStatus.idle});

  final SupportContactStatus status;

  @override
  List<Object?> get props => [status];
}
