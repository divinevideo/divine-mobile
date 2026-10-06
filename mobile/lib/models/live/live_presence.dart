import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/models/live/live_role.dart';

@immutable
class LivePresence extends Equatable {
  const LivePresence({
    required this.sessionId,
    required this.pubkey,
    required this.role,
    required this.handRaised,
    required this.updatedAt,
    this.sessionHostPubkey,
  });

  final String sessionId;
  final String? sessionHostPubkey;
  final String pubkey;
  final LiveRole role;
  final bool handRaised;
  final DateTime updatedAt;

  String get sessionAddress =>
      _hasSessionHostPubkey ? '30313:$sessionHostPubkey:$sessionId' : sessionId;

  String get sessionAddressKey =>
      _hasSessionHostPubkey ? sessionAddress : sessionId;

  LivePresence copyWith({
    String? sessionId,
    String? sessionHostPubkey,
    String? pubkey,
    LiveRole? role,
    bool? handRaised,
    DateTime? updatedAt,
  }) {
    return LivePresence(
      sessionId: sessionId ?? this.sessionId,
      sessionHostPubkey: sessionHostPubkey ?? this.sessionHostPubkey,
      pubkey: pubkey ?? this.pubkey,
      role: role ?? this.role,
      handRaised: handRaised ?? this.handRaised,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get _hasSessionHostPubkey =>
      sessionHostPubkey != null && sessionHostPubkey!.isNotEmpty;

  @override
  List<Object?> get props => [
    sessionId,
    sessionHostPubkey,
    pubkey,
    role,
    handRaised,
    updatedAt,
  ];
}
