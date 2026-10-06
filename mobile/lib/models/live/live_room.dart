import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum LiveRoomVisibility {
  public,
  private,
  closed;

  static LiveRoomVisibility fromNostrStatus(String? rawStatus) {
    final normalized = rawStatus?.trim().toLowerCase();
    switch (normalized) {
      case 'private':
        return LiveRoomVisibility.private;
      case 'closed':
        return LiveRoomVisibility.closed;
      case 'public':
      case 'open':
      default:
        return LiveRoomVisibility.public;
    }
  }

  String get nostrStatusValue {
    switch (this) {
      case LiveRoomVisibility.public:
        return 'open';
      case LiveRoomVisibility.private:
        return 'private';
      case LiveRoomVisibility.closed:
        return 'closed';
    }
  }
}

@immutable
class LiveRoom extends Equatable {
  const LiveRoom({
    required this.id,
    required this.hostPubkey,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.relays,
    required this.visibility,
  });

  final String id;
  final String hostPubkey;
  final String title;
  final String summary;
  final String? imageUrl;
  final List<String> relays;
  final LiveRoomVisibility visibility;

  String get address => '30312:$hostPubkey:$id';

  LiveRoom copyWith({
    String? id,
    String? hostPubkey,
    String? title,
    String? summary,
    String? imageUrl,
    List<String>? relays,
    LiveRoomVisibility? visibility,
  }) {
    return LiveRoom(
      id: id ?? this.id,
      hostPubkey: hostPubkey ?? this.hostPubkey,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      imageUrl: imageUrl ?? this.imageUrl,
      relays: relays ?? this.relays,
      visibility: visibility ?? this.visibility,
    );
  }

  @override
  List<Object?> get props => [
    id,
    hostPubkey,
    title,
    summary,
    imageUrl,
    relays,
    visibility,
  ];
}
