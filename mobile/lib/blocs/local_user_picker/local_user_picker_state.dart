// ABOUTME: Immutable local mutual-picker data and first-visible row positions.
// ABOUTME: Derives search matches from the same identity labels rendered by rows.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:user_ranking/user_ranking.dart';

class LocalUserPickerState extends Equatable {
  LocalUserPickerState({
    List<UserProfile> profiles = const [],
    Map<String, UserRankingSignals> rankingSignals = const {},
    List<String> order = const [],
    Set<String> vanishedPubkeys = const {},
    this.orderReady = false,
    this.loaded = false,
    this.loadRevision = 0,
    this.query = '',
    this.deletedAccountLabel = '',
  }) : profiles = List.unmodifiable(profiles),
       rankingSignals = Map.unmodifiable(rankingSignals),
       order = List.unmodifiable(order),
       vanishedPubkeys = Set.unmodifiable(vanishedPubkeys);

  final List<UserProfile> profiles;
  final Map<String, UserRankingSignals> rankingSignals;
  final List<String> order;
  final Set<String> vanishedPubkeys;
  final bool orderReady;
  final bool loaded;
  final int loadRevision;
  final String query;
  final String deletedAccountLabel;

  String renderedName(UserProfile profile) =>
      vanishedPubkeys.contains(profile.pubkey)
      ? deletedAccountLabel
      : profile.bestDisplayName;

  List<UserProfile> get visibleProfiles {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return profiles;
    return List.unmodifiable(
      profiles.where((profile) {
        final nip05 = vanishedPubkeys.contains(profile.pubkey)
            ? ''
            : (profile.nip05 ?? '').toLowerCase();
        return renderedName(profile).toLowerCase().contains(needle) ||
            nip05.contains(needle);
      }),
    );
  }

  LocalUserPickerState copyWith({
    List<UserProfile>? profiles,
    Map<String, UserRankingSignals>? rankingSignals,
    List<String>? order,
    Set<String>? vanishedPubkeys,
    bool? orderReady,
    bool? loaded,
    int? loadRevision,
    String? query,
    String? deletedAccountLabel,
  }) => LocalUserPickerState(
    profiles: profiles ?? this.profiles,
    rankingSignals: rankingSignals ?? this.rankingSignals,
    order: order ?? this.order,
    vanishedPubkeys: vanishedPubkeys ?? this.vanishedPubkeys,
    orderReady: orderReady ?? this.orderReady,
    loaded: loaded ?? this.loaded,
    loadRevision: loadRevision ?? this.loadRevision,
    query: query ?? this.query,
    deletedAccountLabel: deletedAccountLabel ?? this.deletedAccountLabel,
  );

  @override
  List<Object> get props => [
    profiles,
    // UserProfile equality is event identity only. Cache hydration can fill
    // presentation fields for that same event and must still refresh the row.
    [
      for (final profile in profiles)
        (profile.name, profile.displayName, profile.picture, profile.nip05),
    ],
    rankingSignals,
    order,
    vanishedPubkeys,
    orderReady,
    loaded,
    loadRevision,
    query,
    deletedAccountLabel,
  ];
}
