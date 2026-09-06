import 'package:models/models.dart' show UserProfile;
import 'package:profile_repository/profile_repository.dart';

/// A single mention match, as a record so this helper has no dependency on
/// the bloc-state's [MentionSuggestion] type.
typedef MentionMatch = ({
  String pubkey,
  String? displayName,
  String? picture,
  String? nip05,
});

/// Function returning the live candidate pubkey iterables the composer should
/// scan: video author + comment participants + follow-list. Captured by the
/// composer constructor; each search invokes the function to read the latest
/// state from [CommentsListBloc] / [FollowRepository] at call time.
typedef MentionCandidatePubkeysProvider = Iterable<String> Function();

/// Tier-1 local lookup over [candidates] backed by [profileRepository]'s
/// cache. Returns up to 5 matches whose display name contains
/// [lowercaseQuery], along with the deduped set of seen pubkeys so the
/// caller can pass it to [mentionSearchRemote] for tier-2 backfill.
Future<({List<MentionMatch> matches, Set<String> seen})> mentionSearchLocal({
  required String lowercaseQuery,
  required Iterable<String> candidates,
  required ProfileRepository? profileRepository,
}) async {
  final seen = <String>{};
  final matches = <MentionMatch>[];

  for (final pubkey in candidates) {
    if (seen.contains(pubkey)) continue;
    seen.add(pubkey);

    final profile = await profileRepository?.getCachedProfile(pubkey: pubkey);
    final displayName = profile?.displayName ?? profile?.name;
    if (displayName != null &&
        displayName.toLowerCase().contains(lowercaseQuery)) {
      matches.add((
        pubkey: pubkey,
        // Matched on the raw value so query behaviour is unchanged, but
        // carried sanitized: this string is rendered in the suggestion list
        // and inserted into the composer on select.
        displayName: UserProfile.sanitizeDisplayName(displayName),
        picture: profile?.picture,
        nip05: profile?.nip05,
      ));
    }
    if (matches.length >= 5) break;
  }

  return (matches: matches, seen: seen);
}

/// Tier-2 REST lookup that merges remote results into [previousMatches],
/// skipping any pubkey already in [previouslySeen]. Returns at most 5
/// matches overall.
Future<List<MentionMatch>> mentionSearchRemote({
  required String lowercaseQuery,
  required ProfileRepository profileRepository,
  required List<MentionMatch> previousMatches,
  required Set<String> previouslySeen,
}) async {
  final merged = List<MentionMatch>.from(previousMatches);
  final seen = Set<String>.from(previouslySeen);

  final remoteResults = await profileRepository.searchUsersFromApi(
    query: lowercaseQuery,
    limit: 10,
    sortBy: profileSearchSortFollowers,
  );

  for (final profile in remoteResults) {
    if (seen.contains(profile.pubkey)) continue;
    seen.add(profile.pubkey);
    final name = profile.displayName ?? profile.name;
    if (name == null) continue;
    merged.add((
      pubkey: profile.pubkey,
      displayName: UserProfile.sanitizeDisplayName(name),
      picture: profile.picture,
      nip05: profile.nip05,
    ));
    if (merged.length >= 5) break;
  }

  return merged;
}
