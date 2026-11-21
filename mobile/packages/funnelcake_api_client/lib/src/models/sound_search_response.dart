import 'package:funnelcake_api_client/src/models/sound_stats.dart';
import 'package:meta/meta.dart';

/// One page of a FunnelCake sound search, as returned by
/// `GET /api/v2/search/sounds`.
@immutable
class SoundSearchResponse {
  /// Creates a [SoundSearchResponse].
  const SoundSearchResponse({required this.sounds, this.nextCursor});

  /// Parses the `{data, pagination}` envelope of a v2 sound search.
  ///
  /// Throws a [FormatException] when [json] holds no `data` list.
  factory SoundSearchResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) {
      throw const FormatException('Sound search response has no data list');
    }
    final pagination = json['pagination'];
    final hasMore =
        pagination is Map<String, dynamic> && pagination['has_more'] == true;
    final cursor = pagination is Map<String, dynamic>
        ? pagination['next_cursor']?.toString()
        : null;
    return SoundSearchResponse(
      sounds: [
        for (final item in data)
          if (item is Map<String, dynamic>) SoundStats.fromJson(item),
      ],
      nextCursor: hasMore && cursor != null && cursor.isNotEmpty
          ? cursor
          : null,
    );
  }

  /// The sounds on this page, best match first.
  ///
  /// A page can hold fewer sounds than were asked for, or none, and still not
  /// be the last.
  final List<SoundStats> sounds;

  /// The cursor of the next page, or `null` when this page is the last.
  final String? nextCursor;

  /// Whether a page follows this one.
  bool get hasMore => nextCursor != null;
}

/// How a sound list without a search query is ordered.
enum SoundListSort {
  /// Newest first.
  recent,

  /// By trending score as of the server's last sound-index refresh.
  trending,
}
