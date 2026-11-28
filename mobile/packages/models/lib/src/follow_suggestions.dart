// ABOUTME: Blended active and classic creator recommendations from Funnelcake.
// ABOUTME: Keeps archive provenance separate from recommendation reasons.

import 'package:models/src/user_profile_data.dart';

/// A single eligible video supplied alongside its creator recommendation.
/// It contains image metadata only, never a fabricated video event.
class FollowSuggestionVideoPreview {
  const FollowSuggestionVideoPreview({
    required this.id,
    required this.thumbnailUrl,
    this.blurhash,
  });

  /// Ignores malformed optional metadata while preserving the creator row.
  static FollowSuggestionVideoPreview? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id'];
    final url = value['thumbnail_url'];
    if (id is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(id) ||
        url is! String ||
        url != url.trim() ||
        RegExp(r'\s').hasMatch(url)) {
      return null;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final blurhash = value['blurhash'];
    return FollowSuggestionVideoPreview(
      id: id,
      thumbnailUrl: url,
      blurhash: blurhash is String && blurhash.trim().isNotEmpty
          ? blurhash
          : null,
    );
  }

  final String id;
  final String thumbnailUrl;
  final String? blurhash;
}

/// A ranked person. A classic archive does not imply current activity.
class FollowSuggestion {
  const FollowSuggestion({
    required this.pubkey,
    required this.profile,
    required this.reason,
    required this.isClassic,
    this.videoPreview,
  });

  factory FollowSuggestion.fromJson(Map<String, dynamic> json) {
    final parsed = tryParse(json);
    if (parsed == null) {
      throw const FormatException('Invalid suggestion public key');
    }
    return parsed;
  }

  /// Parses a suggestion row, returning null instead of throwing on malformed
  /// rows so a single bad entry never fails an entire recommendations page.
  static FollowSuggestion? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final pubkey = value['pubkey'];
    if (pubkey is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(pubkey)) {
      return null;
    }
    final rawProfile = value['profile'];
    if (rawProfile != null && rawProfile is! Map<String, dynamic>) {
      return null;
    }
    final rawReason = value['reason'];
    final reason = rawReason is String && rawReason.isNotEmpty
        ? rawReason
        : 'popular';
    try {
      return FollowSuggestion(
        pubkey: pubkey,
        profile: UserProfileData.fromJson(
          pubkey,
          rawProfile as Map<String, dynamic>? ?? const {},
        ),
        reason: reason,
        isClassic: value['is_classic'] == true,
        videoPreview: FollowSuggestionVideoPreview.tryParse(
          value['video_preview'],
        ),
      );
    } on Object {
      return null;
    }
  }

  final String pubkey;
  final UserProfileData profile;

  /// Ranking provenance; does not by itself prove a mutual-follow relationship.
  final String reason;
  final bool isClassic;

  /// Optional image-only preview of this creator's eligible video.
  final FollowSuggestionVideoPreview? videoPreview;
}

/// An opaque cursor is passed back unchanged, even on empty filtered pages.
class FollowSuggestionsPage {
  const FollowSuggestionsPage({this.suggestions = const [], this.nextCursor});

  factory FollowSuggestionsPage.fromJson(Map<String, dynamic> json) =>
      FollowSuggestionsPage(
        suggestions: List.unmodifiable(
          (json['suggestions'] as List<dynamic>)
              .map(FollowSuggestion.tryParse)
              .whereType<FollowSuggestion>(),
        ),
        nextCursor: json['next_cursor'] as String?,
      );

  final List<FollowSuggestion> suggestions;
  final String? nextCursor;
}
