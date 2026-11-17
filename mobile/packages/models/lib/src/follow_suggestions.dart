// ABOUTME: Blended active and classic creator recommendations from Funnelcake.
// ABOUTME: Keeps archive provenance separate from recommendation reasons.

import 'package:models/src/user_profile_data.dart';

/// A ranked person. A classic archive does not imply current activity.
class FollowSuggestion {
  const FollowSuggestion({
    required this.pubkey,
    required this.profile,
    required this.reason,
    required this.isClassic,
  });

  factory FollowSuggestion.fromJson(Map<String, dynamic> json) {
    final pubkey = json['pubkey'] as String;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(pubkey)) {
      throw const FormatException('Invalid suggestion public key');
    }
    return FollowSuggestion(
      pubkey: pubkey,
      profile: UserProfileData.fromJson(
        pubkey,
        json['profile'] as Map<String, dynamic>? ?? {},
      ),
      reason: json['reason'] as String? ?? 'popular',
      isClassic: json['is_classic'] == true,
    );
  }

  final String pubkey;
  final UserProfileData profile;

  /// Ranking provenance; does not by itself prove a mutual-follow relationship.
  final String reason;
  final bool isClassic;
}

/// An opaque cursor is passed back unchanged, even on empty filtered pages.
class FollowSuggestionsPage {
  const FollowSuggestionsPage({this.suggestions = const [], this.nextCursor});

  factory FollowSuggestionsPage.fromJson(Map<String, dynamic> json) =>
      FollowSuggestionsPage(
        suggestions: List.unmodifiable(
          (json['suggestions'] as List<dynamic>).map(
            (row) => FollowSuggestion.fromJson(row as Map<String, dynamic>),
          ),
        ),
        nextCursor: json['next_cursor'] as String?,
      );

  final List<FollowSuggestion> suggestions;
  final String? nextCursor;
}
