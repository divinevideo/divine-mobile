// ABOUTME: DivineFilter - extends nostr_sdk Filter to support divine relay extensions
// ABOUTME: Adds sort, int# filters, and cursor for server-side sorted queries

import 'package:nostr_sdk/filter.dart';

/// Sort direction for server-side sorting
enum SortDirection {
  asc,
  desc;

  String toJson() => name;
}

/// Sort configuration for divine relay queries
class SortConfig {
  final String field; // e.g., 'loop_count', 'likes', 'created_at'
  final SortDirection direction;

  const SortConfig({required this.field, this.direction = SortDirection.desc});

  Map<String, dynamic> toJson() => {'field': field, 'dir': direction.toJson()};
}

/// Range filter for integer metrics
class IntRangeFilter {
  final int? gte; // Greater than or equal
  final int? lte; // Less than or equal
  final int? gt; // Greater than
  final int? lt; // Less than

  const IntRangeFilter({this.gte, this.lte, this.gt, this.lt});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (gte != null) json['gte'] = gte;
    if (lte != null) json['lte'] = lte;
    if (gt != null) json['gt'] = gt;
    if (lt != null) json['lt'] = lt;
    return json;
  }
}

/// Extended Filter that supports divine relay vendor extensions
///
/// Usage:
/// ```dart
/// final filter = DivineFilter(
///   baseFilter: Filter(kinds: [34236], limit: 50),
///   sort: SortConfig(field: 'loop_count', direction: SortDirection.desc),
///   intFilters: {
///     'likes': IntRangeFilter(gte: 100),
///     'loop_count': IntRangeFilter(gte: 1000),
///   },
/// );
/// ```
class DivineFilter {
  final Filter baseFilter;
  final SortConfig? sort;
  final Map<String, IntRangeFilter>? intFilters; // int#<field> filters
  final String? cursor; // For pagination

  const DivineFilter({
    required this.baseFilter,
    this.sort,
    this.intFilters,
    this.cursor,
  });

  /// Convert to JSON for Nostr REQ message
  /// Merges base filter JSON with divine extensions
  Map<String, dynamic> toJson() {
    final json = baseFilter.toJson();

    // Add sort if present
    if (sort != null) {
      json['sort'] = sort!.toJson();
    }

    // Add int# filters if present
    if (intFilters != null && intFilters!.isNotEmpty) {
      for (final entry in intFilters!.entries) {
        json['int#${entry.key}'] = entry.value.toJson();
      }
    }

    // Add cursor if present
    if (cursor != null) {
      json['cursor'] = cursor;
    }

    return json;
  }

  /// Create a copy with updated cursor (for pagination)
  DivineFilter withCursor(String newCursor) {
    return DivineFilter(
      baseFilter: baseFilter,
      sort: sort,
      intFilters: intFilters,
      cursor: newCursor,
    );
  }

  /// Create a standard trending query (sorted by loop_count)
  factory DivineFilter.trending({required Filter baseFilter, int? minLoops}) {
    return DivineFilter(
      baseFilter: baseFilter,
      sort: SortConfig(field: 'loop_count', direction: SortDirection.desc),
      intFilters: minLoops != null
          ? {'loop_count': IntRangeFilter(gte: minLoops)}
          : null,
    );
  }

  /// Create a most liked query (sorted by likes)
  factory DivineFilter.mostLiked({required Filter baseFilter, int? minLikes}) {
    return DivineFilter(
      baseFilter: baseFilter,
      sort: SortConfig(field: 'likes', direction: SortDirection.desc),
      intFilters: minLikes != null
          ? {'likes': IntRangeFilter(gte: minLikes)}
          : null,
    );
  }

  /// Create a most viewed query (sorted by views)
  factory DivineFilter.mostViewed({required Filter baseFilter, int? minViews}) {
    return DivineFilter(
      baseFilter: baseFilter,
      sort: SortConfig(field: 'views', direction: SortDirection.desc),
      intFilters: minViews != null
          ? {'views': IntRangeFilter(gte: minViews)}
          : null,
    );
  }

  /// Create a newest first query (sorted by created_at)
  factory DivineFilter.newest({required Filter baseFilter}) {
    return DivineFilter(
      baseFilter: baseFilter,
      sort: SortConfig(field: 'created_at', direction: SortDirection.desc),
    );
  }
}
