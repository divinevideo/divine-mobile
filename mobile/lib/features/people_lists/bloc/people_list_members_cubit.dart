// ABOUTME: Cubit behind a people list's roster. Ranks the members by how
// ABOUTME: much they post and totals their videos and loops from Funnelcake.

import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/people_lists/bloc/people_list_members_state.dart';
import 'package:profile_repository/profile_repository.dart';

export 'package:openvine/features/people_lists/bloc/people_list_members_state.dart';

/// How many members a roster asks Funnelcake about.
///
/// A kind-30000 set can carry over a thousand members and the bulk profile
/// endpoint answers one page of [kPeopleListStatsPageSize] per call, so this
/// bounds what a single list can cost. Members past the cap stay in the
/// roster, unranked, after the ones with stats.
const kPeopleListStatsMemberCap = 300;

/// Pubkeys per bulk profile call.
const kPeopleListStatsPageSize = 100;

typedef _MemberStats = ({int videoCount, double totalLoops});

/// Drives a people list's roster: the members preview on the list screen
/// and the full roster behind "View all".
///
/// Stats are ranking, not content. Without them (no Funnelcake, a failed
/// page, a member the API does not know) the roster still renders, in the
/// list's own order, so the screen never depends on the fetch.
class PeopleListMembersCubit extends Cubit<PeopleListMembersState>
    with CloseGuardedEmit<PeopleListMembersState> {
  PeopleListMembersCubit({
    required ProfileRepository? profileRepository,
    required List<String> pubkeys,
  }) : _profileRepository = profileRepository,
       _pubkeys = List.unmodifiable(pubkeys),
       super(
         PeopleListMembersState(
           members: List.unmodifiable([
             for (final pubkey in pubkeys) PeopleListMember(pubkey: pubkey),
           ]),
         ),
       );

  final ProfileRepository? _profileRepository;
  final List<String> _pubkeys;

  /// Fetches the members' stats and ranks the roster. Safe to call again.
  Future<void> load() async {
    final repository = _profileRepository;
    if (repository == null || _pubkeys.isEmpty) {
      emitIfOpen(_ranked(const {}, status: PeopleListMembersStatus.success));
      return;
    }
    emitIfOpen(state.copyWith(status: PeopleListMembersStatus.loading));

    final stats = <String, _MemberStats>{};
    final sample = _pubkeys.take(kPeopleListStatsMemberCap).toList();
    try {
      for (
        var start = 0;
        start < sample.length;
        start += kPeopleListStatsPageSize
      ) {
        final page = sample.sublist(
          start,
          min(start + kPeopleListStatsPageSize, sample.length),
        );
        final response = await repository.getBulkProfilesFromApi(page);
        // Null means Funnelcake is not configured; no page will answer.
        if (response == null) break;
        for (final entry in response.profiles.entries) {
          final videoCount = entry.value.stats?.videoCount;
          if (videoCount == null) continue;
          stats[entry.key.toLowerCase()] = (
            videoCount: videoCount,
            totalLoops: entry.value.engagement?.totalLoops ?? 0,
          );
        }
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(_ranked(stats, status: PeopleListMembersStatus.failure));
      return;
    }
    emitIfOpen(_ranked(stats, status: PeopleListMembersStatus.success));
  }

  PeopleListMembersState _ranked(
    Map<String, _MemberStats> stats, {
    required PeopleListMembersStatus status,
  }) {
    final members = [
      for (final pubkey in _pubkeys)
        PeopleListMember(
          pubkey: pubkey,
          videoCount: stats[pubkey.toLowerCase()]?.videoCount,
          totalLoops: stats[pubkey.toLowerCase()]?.totalLoops,
        ),
    ];
    // Ranked members first, most videos first; ties and the unranked keep
    // the list's own order. Indexed because List.sort is not stable.
    final indexed = members.indexed.toList()
      ..sort((a, b) {
        final byVideos = (b.$2.videoCount ?? -1).compareTo(
          a.$2.videoCount ?? -1,
        );
        return byVideos != 0 ? byVideos : a.$1.compareTo(b.$1);
      });
    final ranked = indexed.map((entry) => entry.$2).toList();
    final withStats = ranked.where((member) => member.hasStats);

    return PeopleListMembersState(
      status: status,
      members: List.unmodifiable(ranked),
      totalVideos: withStats.isEmpty
          ? null
          : withStats.fold<int>(0, (sum, member) => sum + member.videoCount!),
      totalLoops: withStats.isEmpty
          ? null
          : withStats.fold<double>(
              0,
              (sum, member) => sum + member.totalLoops!,
            ),
    );
  }
}
