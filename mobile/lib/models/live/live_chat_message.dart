import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class LiveChatMessage extends Equatable {
  const LiveChatMessage({
    required this.id,
    required this.sessionAddress,
    required this.pubkey,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String sessionAddress;
  final String pubkey;
  final String content;
  final DateTime createdAt;

  String get sessionId {
    final parts = sessionAddress.split(':');
    return parts.length > 2 ? parts[2] : '';
  }

  @override
  List<Object?> get props => [id, sessionAddress, pubkey, content, createdAt];
}
