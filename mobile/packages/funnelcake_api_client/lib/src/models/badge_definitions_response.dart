import 'package:nostr_sdk/nostr_sdk.dart';

/// A page of raw Nostr badge definition events from Funnelcake.
class BadgeDefinitionsResponse {
  /// Creates a badge definition page.
  const BadgeDefinitionsResponse({required this.badges, this.nextCursor});

  /// Parses the complete envelope without treating malformed data as absence.
  factory BadgeDefinitionsResponse.fromJson(Map<String, dynamic> json) {
    final badges = json['badges'];
    final nextCursor = json['next_cursor'];
    if (badges is! List<dynamic> ||
        !json.containsKey('next_cursor') ||
        (nextCursor != null && nextCursor is! String)) {
      throw const FormatException('Malformed badge definitions response');
    }

    return BadgeDefinitionsResponse(
      badges: badges.map((value) {
        // Event.fromJson permits a missing signature; this endpoint promises
        // the complete signed event rather than a flattened metadata record.
        if (value is! Map<String, dynamic> || value['sig'] is! String) {
          throw const FormatException('Malformed badge definition event');
        }
        return Event.fromJson(value);
      }).toList(),
      nextCursor: nextCursor as String?,
    );
  }

  /// Full events, including their original tags, content, ID and signature.
  final List<Event> badges;

  /// Opaque cursor to pass unchanged when requesting the next page.
  final String? nextCursor;
}
