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

  /// The stats fetch failed; members are ranked by whatever did arrive and
  /// the totals stay off.
  failure,
}

/// One member of a people list with the posting stats known for them.
///
/// [videoCount] and [totalLoops] are `null` when no stats came back for the
/// member: Funnelcake unavailable, the member beyond the sampled window, or
/// a pubkey the API does not know. [totalLoops] is also `null` by itself
/// when the member's stats carried no engagement block.
class PeopleListMember extends Equatable {
  const PeopleListMember({
    required this.pubkey,
    this.videoCount,
    this.totalLoops,
  });

  final String pubkey;

  /// Vertical videos only, matching what the grid can render.
  final int? videoCount;

  final double? totalLoops;

  bool get hasStats => videoCount != null;

  @override
  List<Object?> get props => [pubkey, videoCount, totalLoops];
}

class PeopleListMembersState extends Equatable {
  const PeopleListMembersState({
    this.status = PeopleListMembersStatus.initial,
    this.roster = const [],
    this.members = const [],
    this.totalVideos,
    this.totalLoops,
  });

  final PeopleListMembersStatus status;

  /// Every member of the list, ranked by [PeopleListMember.videoCount], most
  /// first. Members without stats follow, in the list's own order. The
  /// totals are computed over this.
  final List<PeopleListMember> roster;

  /// The [roster] minus the members hidden from the viewer: accounts either
  /// side blocked or muted. This is what the screens render.
  final List<PeopleListMember> members;

  /// Every member's videos, summed. `null` unless every member answered
  /// with a count: a list past the sampled window, a failed page, no
  /// Funnelcake, a member the API does not know or one whose stats carry no
  /// vertical count would all leave a partial sum, which is not the list's
  /// total.
  final int? totalVideos;

  /// Every member's loops, summed. `null` under the same conditions as
  /// [totalVideos], and when any ranked member's loops are unknown.
  final double? totalLoops;

  PeopleListMembersState copyWith({
    PeopleListMembersStatus? status,
    List<PeopleListMember>? roster,
    List<PeopleListMember>? members,
    int? totalVideos,
    double? totalLoops,
  }) {
    return PeopleListMembersState(
      status: status ?? this.status,
      roster: roster ?? this.roster,
      members: members ?? this.members,
      totalVideos: totalVideos ?? this.totalVideos,
      totalLoops: totalLoops ?? this.totalLoops,
    );
  }

  @override
  List<Object?> get props => [
    status,
    roster,
    members,
    totalVideos,
    totalLoops,
  ];
}
