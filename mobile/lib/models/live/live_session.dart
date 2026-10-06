import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum LiveSessionStatus {
  planned,
  live,
  ended;

  static LiveSessionStatus fromTagValue(String? rawStatus) {
    final normalized = rawStatus?.trim().toLowerCase();
    switch (normalized) {
      case 'planned':
        return LiveSessionStatus.planned;
      case 'ended':
        return LiveSessionStatus.ended;
      case 'live':
      default:
        return LiveSessionStatus.live;
    }
  }

  String get tagValue {
    switch (this) {
      case LiveSessionStatus.planned:
        return 'planned';
      case LiveSessionStatus.live:
        return 'live';
      case LiveSessionStatus.ended:
        return 'ended';
    }
  }
}

@immutable
class LiveSession extends Equatable {
  const LiveSession({
    required this.id,
    required this.roomId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.speakerPubkeys,
    required this.audienceCount,
    this.hostPubkey,
  });

  final String id;
  final String roomId;
  final String? hostPubkey;
  final LiveSessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<String> speakerPubkeys;
  final int audienceCount;

  bool get isLive => status == LiveSessionStatus.live;

  bool get hasEnded => status == LiveSessionStatus.ended;

  String get address => _hasHostPubkey ? '30313:$hostPubkey:$id' : id;

  String get roomAddress =>
      _hasHostPubkey ? '30312:$hostPubkey:$roomId' : roomId;

  String get addressKey => _hasHostPubkey ? address : id;

  String get roomAddressKey => _hasHostPubkey ? roomAddress : roomId;

  LiveSession copyWith({
    String? id,
    String? roomId,
    String? hostPubkey,
    LiveSessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    List<String>? speakerPubkeys,
    int? audienceCount,
  }) {
    return LiveSession(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      hostPubkey: hostPubkey ?? this.hostPubkey,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      speakerPubkeys: speakerPubkeys ?? this.speakerPubkeys,
      audienceCount: audienceCount ?? this.audienceCount,
    );
  }

  bool get _hasHostPubkey => hostPubkey != null && hostPubkey!.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    roomId,
    hostPubkey,
    status,
    startedAt,
    endedAt,
    speakerPubkeys,
    audienceCount,
  ];
}
