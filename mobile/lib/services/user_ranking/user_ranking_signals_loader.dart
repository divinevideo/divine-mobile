// ABOUTME: Builds user-ranking snapshots exclusively from local stores.
// ABOUTME: Refreshes stale signals separately without changing visible order.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart' show NIP71VideoKinds, UserProfile;
import 'package:openvine/utils/detached_future.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:user_ranking/user_ranking.dart';

/// Reads a fresh local signal snapshot on each list open, without network I/O.
class UserRankingSignalsLoader {
  UserRankingSignalsLoader({
    required DmRepository dmRepository,
    required FollowRepository followRepository,
    required ProfileRepository? profileRepository,
    required MyFollowersDao myFollowersDao,
    required ProfileStatsDao profileStatsDao,
    required NostrEventsDao nostrEventsDao,
    required Nip05VerificationsDao nip05VerificationsDao,
    required String currentUserPubkey,
    bool Function(String pubkey)? isBlocked,
    DateTime Function()? now,
  }) : _dmRepository = dmRepository,
       _followRepository = followRepository,
       _profileRepository = profileRepository,
       _myFollowersDao = myFollowersDao,
       _profileStatsDao = profileStatsDao,
       _nostrEventsDao = nostrEventsDao,
       _nip05VerificationsDao = nip05VerificationsDao,
       _currentUserPubkey = currentUserPubkey,
       _isBlocked = isBlocked,
       _now = now ?? DateTime.now;

  final DmRepository _dmRepository;
  final FollowRepository _followRepository;
  final ProfileRepository? _profileRepository;
  final MyFollowersDao _myFollowersDao;
  final ProfileStatsDao _profileStatsDao;
  final NostrEventsDao _nostrEventsDao;
  final Nip05VerificationsDao _nip05VerificationsDao;
  final String _currentUserPubkey;
  final bool Function(String pubkey)? _isBlocked;
  final DateTime Function() _now;

  /// Whether [pubkey] is eligible under the current owner and block policy.
  ///
  /// Synchronous and performs no I/O, so cached fallback paths can enforce
  /// eligibility even when loading the local signal snapshot fails.
  bool isEligible(String pubkey) =>
      pubkey != _currentUserPubkey && !(_isBlocked?.call(pubkey) ?? false);

  /// Reads rendered names from the local profile cache without fetching.
  Future<Map<String, String>> loadCachedDisplayNames(
    Iterable<String> pubkeys,
  ) async {
    final keys = pubkeys.where(isEligible).toSet();
    if (keys.isEmpty) return {};
    final profiles =
        await _profileRepository?.getCachedProfiles(
          pubkeys: keys.toList(growable: false),
        ) ??
        const <UserProfile>[];
    return {
      for (final profile in profiles)
        if (keys.contains(profile.pubkey) && isEligible(profile.pubkey))
          profile.pubkey: profile.bestDisplayName,
    };
  }

  /// Loads only cached signals for [pubkeys], excluding self and blocked users.
  ///
  /// Share recipients can opt into including previously messaged contacts who
  /// are not followed. Expansion uses the same accepted-conversation snapshot
  /// as interaction scoring; ordinary callers retain their own candidate set.
  Future<Map<String, UserRankingSignals>> load(
    Iterable<String> pubkeys, {
    bool includeDmCounterparts = false,
  }) async {
    final candidates = pubkeys.where(isEligible).toSet();
    if (candidates.isEmpty && !includeDmCounterparts) return {};

    final conversations = await _dmRepository
        .watchAcceptedConversations()
        .first;
    final interactions = <String, int>{};
    for (final conversation in conversations) {
      final timestamp = conversation.lastMessageTimestamp;
      if (conversation.isGroup ||
          !conversation.currentUserHasSent ||
          timestamp == null ||
          conversation.participantPubkeys.length != 2 ||
          !conversation.participantPubkeys.contains(_currentUserPubkey)) {
        continue;
      }
      for (final peer in conversation.participantPubkeys) {
        if (!isEligible(peer)) continue;
        if (includeDmCounterparts) candidates.add(peer);
        if (!candidates.contains(peer)) continue;
        final previous = interactions[peer];
        if (previous == null || timestamp > previous) {
          interactions[peer] = timestamp;
        }
      }
    }
    if (candidates.isEmpty) return {};
    final keys = candidates.toList(growable: false);
    final (followers, stats, videos, verifications, profiles) = await (
      _myFollowersDao.followerSubset(
        ownerPubkey: _currentUserPubkey,
        candidates: keys,
      ),
      _profileStatsDao.getStatsRawMany(keys),
      _nostrEventsDao.newestCreatedAtByAuthor(
        authors: keys,
        kinds: NIP71VideoKinds.getAllVideoKinds(),
      ),
      _nip05VerificationsDao.getValidVerifications(keys),
      _profileRepository?.getCachedProfiles(pubkeys: keys) ??
          Future<List<UserProfile>>.value(const []),
    ).wait;
    final verified = {
      for (final row in verifications)
        if (row.status == 'verified') row.pubkey,
    };
    final profileVideoCounts = {
      for (final profile in profiles) profile.pubkey: profile.restVideoCount,
    };
    return {
      for (final pubkey in keys)
        // A block may have arrived while the local queries were in flight.
        if (isEligible(pubkey))
          pubkey: UserRankingSignals(
            pubkey: pubkey,
            lastInteractionAt: _timestamp(interactions[pubkey]),
            youFollow: _followRepository.isFollowing(pubkey),
            // The local subset has no completeness marker. Absence is unknown,
            // not evidence that the account does not follow the viewer.
            followsYou: followers.contains(pubkey) ? true : null,
            hasVerifiedNip05: verified.contains(pubkey),
            videoCount: stats[pubkey]?.videoCount ?? profileVideoCounts[pubkey],
            lastPostedAt: _timestamp(videos[pubkey]),
          ),
    };
  }

  static DateTime? _timestamp(int? seconds) => seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  /// Refreshes sources for the next open; never mutates a loaded snapshot.
  void refreshInBackground(List<String> rankedPubkeys) {
    runDetached(
      Future<void>.sync(_followRepository.syncMyFollowers),
      'refresh ranking followers',
      logName: '$UserRankingSignalsLoader',
      category: LogCategory.system,
    );
    runDetached(
      _refreshStats(rankedPubkeys.take(100).toList(growable: false)),
      'refresh ranking profile stats',
      logName: '$UserRankingSignalsLoader',
      category: LogCategory.system,
    );
  }

  Future<void> _refreshStats(List<String> pubkeys) async {
    final repository = _profileRepository;
    if (repository == null || pubkeys.isEmpty) return;
    final stats = await _profileStatsDao.getStatsRawMany(pubkeys);
    final cutoff = _now().subtract(const Duration(days: 7));
    final stale = pubkeys
        .where((pubkey) {
          final row = stats[pubkey];
          return row == null || row.cachedAt.isBefore(cutoff);
        })
        .toList(growable: false);
    if (stale.isNotEmpty) await repository.refreshStatsForPubkeys(stale);
  }
}
