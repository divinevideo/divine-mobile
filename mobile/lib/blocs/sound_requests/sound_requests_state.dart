// ABOUTME: Immutable presentation state for sound requests and approvals.
// ABOUTME: Account identity prevents results crossing login transitions.
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

enum SoundRequestOperation { idle, working, sent, failed }

enum SoundRequestEligibility { checking, available, unavailable, failed }

class SoundRequestsState extends Equatable {
  const SoundRequestsState({
    this.ownerPubkey = '',
    this.snapshot = const SoundRequestSnapshot(),
    this.operation = SoundRequestOperation.idle,
    this.target,
    this.eligibility = const {},
    this.videos = const {},
  });
  final Map<String, VideoEvent> videos;
  final String ownerPubkey;
  final SoundRequestSnapshot snapshot;
  final SoundRequestOperation operation;
  final String? target;
  final Map<String, SoundRequestEligibility> eligibility;
  SoundRequestsState copyWith({
    SoundRequestSnapshot? snapshot,
    SoundRequestOperation? operation,
    String? target,
    Map<String, SoundRequestEligibility>? eligibility,
    Map<String, VideoEvent>? videos,
  }) => SoundRequestsState(
    ownerPubkey: ownerPubkey,
    videos: videos ?? this.videos,
    snapshot: snapshot ?? this.snapshot,
    operation: operation ?? this.operation,
    target: target ?? this.target,
    eligibility: eligibility ?? this.eligibility,
  );
  @override
  List<Object?> get props => [
    ownerPubkey,
    snapshot,
    operation,
    target,
    eligibility,
    videos,
  ];
}
