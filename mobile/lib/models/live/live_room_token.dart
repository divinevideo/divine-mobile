import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class LiveRoomToken extends Equatable {
  const LiveRoomToken({
    required this.token,
    required this.roomName,
    required this.participantIdentity,
    required this.serverUrl,
    required this.canPublish,
  });

  factory LiveRoomToken.fromJson(Map<String, dynamic> json) {
    return LiveRoomToken(
      token: json['token'] as String? ?? '',
      roomName:
          json['roomName'] as String? ?? json['room_name'] as String? ?? '',
      participantIdentity:
          json['participantIdentity'] as String? ??
          json['participant_identity'] as String? ??
          '',
      serverUrl:
          json['serverUrl'] as String? ?? json['server_url'] as String? ?? '',
      canPublish: _parseCanPublish(json['canPublish'] ?? json['can_publish']),
    );
  }

  final String token;
  final String roomName;
  final String participantIdentity;
  final String serverUrl;
  final bool canPublish;

  LiveRoomToken copyWith({
    String? token,
    String? roomName,
    String? participantIdentity,
    String? serverUrl,
    bool? canPublish,
  }) {
    return LiveRoomToken(
      token: token ?? this.token,
      roomName: roomName ?? this.roomName,
      participantIdentity: participantIdentity ?? this.participantIdentity,
      serverUrl: serverUrl ?? this.serverUrl,
      canPublish: canPublish ?? this.canPublish,
    );
  }

  @override
  List<Object?> get props => [
    token,
    roomName,
    participantIdentity,
    serverUrl,
    canPublish,
  ];

  static bool _parseCanPublish(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return false;
  }
}
