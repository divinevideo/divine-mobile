// ABOUTME: Resolves a typed or pasted Nostr identifier in search to the
// ABOUTME: profile or video it names, for the search page to open.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/utils/nostr_search_query.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:videos_repository/videos_repository.dart';

part 'nostr_id_search_state.dart';

/// Decides whether the search query names a profile or video to open.
///
/// The text search runs for every query; this only adds the navigation for a
/// complete identifier. A bare hex value opens only when a lookup finds it.
/// The other forms open without a lookup, and the destination screen reports
/// an entity that does not exist.
class NostrIdSearchCubit extends Cubit<NostrIdSearchState>
    with CloseGuardedEmit<NostrIdSearchState> {
  /// Creates the cubit with [initialQuery] as its current query, so text the
  /// route prefilled resolves only once the user edits it.
  NostrIdSearchCubit({
    required ProfileRepository? profileRepository,
    required VideosRepository videosRepository,
    String initialQuery = '',
  }) : _resolver = NostrIdSearchResolver(
         profileExists: (hexPubkey) async {
           if (profileRepository == null) return false;
           final cached = await profileRepository.getCachedProfile(
             pubkey: hexPubkey,
           );
           if (cached != null) return true;
           final fresh = await profileRepository.fetchFreshProfile(
             pubkey: hexPubkey,
           );
           return fresh != null;
         },
         // A video the viewer's filters hide still exists: it opens like its
         // note1 does, and the detail screen names the setting (#7892).
         videoExists: (routeId) async {
           final lookup = await videosRepository.lookupVideoForRouteId(routeId);
           return lookup is! VideoRouteMissing;
         },
       ),
       super(NostrIdSearchState(query: initialQuery.trim()));

  final NostrIdSearchResolver _resolver;

  /// Resolves [rawQuery] when it differs from the current query.
  ///
  /// The search field also reports cursor and focus changes, which repeat the
  /// current query and are ignored. A lookup that finishes after the query
  /// changed is dropped, so a slow answer never opens a screen for text that
  /// is no longer in the field.
  Future<void> queryChanged(String rawQuery) async {
    final query = rawQuery.trim();
    if (query == state.query) return;
    emitIfOpen(NostrIdSearchState(query: query));
    final action = await _resolver.resolve(query);
    if (action == null || state.query != query) return;
    emitIfOpen(NostrIdSearchState(query: query, action: action));
  }
}
