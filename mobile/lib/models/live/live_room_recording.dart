import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum RecordingStatus {
  pending,
  processing,
  ready,
  failed;

  static RecordingStatus fromValue(String? rawStatus) {
    final normalized = rawStatus?.trim().toLowerCase();
    switch (normalized) {
      case 'pending':
      case 'queued':
        return RecordingStatus.pending;
      case 'ready':
      case 'completed':
        return RecordingStatus.ready;
      case 'failed':
      case 'error':
        return RecordingStatus.failed;
      case 'processing':
      default:
        return RecordingStatus.processing;
    }
  }
}

@immutable
class LiveRoomRecording extends Equatable {
  const LiveRoomRecording({
    required this.playbackUrl,
    required this.status,
  });

  factory LiveRoomRecording.fromJson(Map<String, dynamic> json) {
    return LiveRoomRecording(
      playbackUrl:
          json['playbackUrl'] as String? ??
          json['playback_url'] as String? ??
          '',
      status: RecordingStatus.fromValue(json['status'] as String?),
    );
  }

  final String playbackUrl;
  final RecordingStatus status;

  bool get isReady => status == RecordingStatus.ready && playbackUrl.isNotEmpty;

  LiveRoomRecording copyWith({
    String? playbackUrl,
    RecordingStatus? status,
  }) {
    return LiveRoomRecording(
      playbackUrl: playbackUrl ?? this.playbackUrl,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [playbackUrl, status];
}
