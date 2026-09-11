// ABOUTME: State for a people list's roster: members ranked by how much they
// ABOUTME: post, with the list-wide video and loop totals Funnelcake reports.

import 'package:equatable/equatable.dart';

/// Status of the roster's stats load.
enum PeopleListMembersStatus {
  /// Nothing requested yet; members are in the list's own order.
  initial,

  /// Stats are being fetched.
  loading,

  /// Stats arrived, or none were available, and the members are ranked.
  success,

  /// The stats fetch failed; members are ranked by whatever did arrive.
  failure,
}

/// One member of a people list with the posting stats known for them.
///
/// [videoCount] and [totalLoops] are `null` when no stats came back for the
/// member: Funnelcake unavailable, the member beyond the sampled window, or
/// a pubkey the API does not know.
class PeopleListMember extends Equatable {
  const PeopleListMember({
    required this.pubkey,
    this.videoCount,
    this.totalLoops,
  });

  final String pubkey;
  final int? videoCount;
  final double? totalLoops;

  bool get hasStats => videoCount != null;

  @override
  List<Object?> get props => [pubkey, videoCount, totalLoops];
}

class PeopleListMembersState extends Equatable {
  const PeopleListMembersState({
    this.status = PeopleListMembersStatus.initial,
    this.members = const [],
    this.totalVideos,
    this.totalLoops,
  });

  final PeopleListMembersStatus status;

  /// Members ranked by [PeopleListMember.videoCount], most first. Members
  /// without stats follow, in the list's own order.
  final List<PeopleListMember> members;

  /// Sum of the ranked members' videos; `null` until any stats arrive.
  final int? totalVideos;

  /// Sum of the ranked members' loops; `null` until any stats arrive.
  final double? totalLoops;

  PeopleListMembersState copyWith({
    PeopleListMembersStatus? status,
    List<PeopleListMember>? members,
    int? totalVideos,
    double? totalLoops,
  }) {
    return PeopleListMembersState(
      status: status ?? this.status,
      members: members ?? this.members,
      totalVideos: totalVideos ?? this.totalVideos,
      totalLoops: totalLoops ?? this.totalLoops,
    );
  }

  @override
  List<Object?> get props => [status, members, totalVideos, totalLoops];
}
