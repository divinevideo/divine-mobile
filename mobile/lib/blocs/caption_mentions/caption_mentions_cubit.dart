import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/mentions/mention_search.dart';
import 'package:openvine/mentions/mention_suggestion.dart';
import 'package:profile_repository/profile_repository.dart';

part 'caption_mentions_state.dart';

/// Supplies the profile repository at the moment a search runs.
typedef ProfileRepositoryLookup = ProfileRepository? Function();

/// Suggests accounts while the author types `@` in a video caption.
///
/// Mirrors the comment composer's two tiers: accounts the author follows are
/// matched from cache and appear immediately, then a REST search backfills
/// when that is thin. Failures leave the tier-1 results on screen rather than
/// surfacing an error — an autocomplete that cannot reach the network should
/// quietly offer less, not interrupt someone writing a caption.
class CaptionMentionsCubit extends Cubit<CaptionMentionsState>
    with CloseGuardedEmit<CaptionMentionsState> {
  CaptionMentionsCubit({
    ProfileRepositoryLookup? profileRepositoryOf,
    MentionCandidatePubkeysProvider? candidatePubkeys,
  }) : _profileRepositoryOf = profileRepositoryOf,
       _candidatePubkeys = candidatePubkeys,
       super(const CaptionMentionsState());

  /// Resolved per search rather than captured at construction, so the cubit
  /// never holds a previous account's repository — and so a caption field can
  /// be built before the repository layer is reachable at all.
  final ProfileRepositoryLookup? _profileRepositoryOf;
  final MentionCandidatePubkeysProvider? _candidatePubkeys;

  /// Monotonic id of the newest search, so a slow tier-2 response for an
  /// earlier query cannot overwrite the suggestions for what is typed now.
  int _searchId = 0;

  /// Updates suggestions for the mention being typed.
  ///
  /// [query] is the text after `@`, or null/empty when the caret is not in a
  /// mention, which dismisses the list.
  Future<void> search(String? query) async {
    final trimmed = query?.trim() ?? '';
    if (trimmed.isEmpty) {
      clear();
      return;
    }

    final id = ++_searchId;
    final lowercaseQuery = trimmed.toLowerCase();
    final repository = _profileRepositoryOf?.call();

    final tier1 = await mentionSearchLocal(
      lowercaseQuery: lowercaseQuery,
      candidates: _candidatePubkeys?.call() ?? const <String>[],
      profileRepository: repository,
    );
    if (id != _searchId) return;
    emitIfOpen(
      CaptionMentionsState(
        query: trimmed,
        suggestions: tier1.matches.map(_toSuggestion).toList(),
      ),
    );

    if (repository == null || tier1.matches.length >= 5) return;

    try {
      final merged = await mentionSearchRemote(
        lowercaseQuery: lowercaseQuery,
        profileRepository: repository,
        previousMatches: tier1.matches,
        previouslySeen: tier1.seen,
      );
      if (id != _searchId) return;
      emitIfOpen(
        CaptionMentionsState(
          query: trimmed,
          suggestions: merged.map(_toSuggestion).toList(),
        ),
      );
    } on Exception {
      // searchUsersFromApi already degrades to [] on typed REST failures;
      // anything escaping leaves the tier-1 suggestions visible.
    }
  }

  /// Dismisses the suggestion list.
  void clear() {
    _searchId++;
    if (state == const CaptionMentionsState()) return;
    emitIfOpen(const CaptionMentionsState());
  }

  static MentionSuggestion _toSuggestion(MentionMatch match) =>
      MentionSuggestion(
        pubkey: match.pubkey,
        displayName: match.displayName,
        picture: match.picture,
        nip05: match.nip05,
      );
}
