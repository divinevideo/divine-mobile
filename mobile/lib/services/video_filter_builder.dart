// ABOUTME: VideoFilterBuilder - centralized filter construction with relay capability detection
// ABOUTME: Builds DivineFilter (sorted) when relay supports it, falls back to standard Filter otherwise

import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/divine_filter.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Sort options for video queries
enum VideoSortField {
  /// Most looped/replayed videos (trending)
  loopCount('loop_count'),

  /// Most liked videos
  likes('likes'),

  /// Most viewed videos
  views('views'),

  /// Most commented videos
  comments('comments'),

  /// Best average completion rate
  avgCompletion('avg_completion'),

  /// Newest videos first
  createdAt('created_at');

  const VideoSortField(this.fieldName);
  final String fieldName;
}

/// NIP-50 search sort modes (supported by otherstuff-relay)
enum NIP50SortMode {
  /// Recent events with high engagement (recency + popularity combined)
  hot('hot'),

  /// Most-referenced events across all time or specific periods
  top('top'),

  /// Recently created content gaining momentum quickly
  rising('rising'),

  /// Events with mixed positive/negative reaction ratios
  controversial('controversial');

  const NIP50SortMode(this.mode);
  final String mode;

  /// Convert to NIP-50 search query string
  String toSearchQuery() => 'sort:$mode';
}

/// Filter builder that automatically uses server-side sorting when relay supports it
///
/// Usage:
/// ```dart
/// final builder = VideoFilterBuilder(relayCapabilityService);
/// final filter = await builder.buildFilter(
///   baseFilter: Filter(kinds: [34236], limit: 50),
///   relayUrl: 'wss://relay.divine.video',
///   sortBy: VideoSortField.loopCount,
///   minLoops: 1000,
/// );
/// ```
class VideoFilterBuilder {
  final RelayCapabilityService _capabilityService;

  VideoFilterBuilder(this._capabilityService);

  /// Build a filter with NIP-50 search support
  ///
  /// Returns a Filter with the search field set for NIP-50 sort modes
  Filter buildNIP50Filter({
    required Filter baseFilter,
    required NIP50SortMode sortMode,
  }) {
    UnifiedLogger.debug(
      '🔍 VideoFilterBuilder.buildNIP50Filter: sortMode=${sortMode.mode}',
      name: 'VideoFilterBuilder',
    );

    // Create new filter with search field for NIP-50 sorting
    return Filter(
      ids: baseFilter.ids,
      authors: baseFilter.authors,
      kinds: baseFilter.kinds,
      e: baseFilter.e,
      p: baseFilter.p,
      t: baseFilter.t,
      h: baseFilter.h,
      d: baseFilter.d,
      since: baseFilter.since,
      until: baseFilter.until,
      limit: baseFilter.limit,
      search: sortMode.toSearchQuery(), // Add NIP-50 search query
    );
  }

  /// Build a filter with optional server-side sorting
  ///
  /// Returns:
  /// - DivineFilter if relay supports divine extensions and sortBy is specified
  /// - Standard Filter otherwise
  Future<Filter> buildFilter({
    required Filter baseFilter,
    required String relayUrl,
    VideoSortField? sortBy,
    SortDirection sortDirection = SortDirection.desc,
    Map<String, IntRangeFilter>? intFilters,
    String? cursor,
  }) async {
    UnifiedLogger.debug(
      '🔍 VideoFilterBuilder.buildFilter called: sortBy=$sortBy, intFilters=$intFilters, cursor=$cursor',
      name: 'VideoFilterBuilder',
    );

    // If no sorting requested, return standard filter
    if (sortBy == null && intFilters == null && cursor == null) {
      UnifiedLogger.debug(
        '⏭️  VideoFilterBuilder: No divine extensions requested, returning base filter',
        name: 'VideoFilterBuilder',
      );
      return baseFilter;
    }

    try {
      // Check relay capabilities
      UnifiedLogger.debug(
        '🔍 VideoFilterBuilder: Checking capabilities for $relayUrl',
        name: 'VideoFilterBuilder',
      );
      final capabilities = await _capabilityService.getRelayCapabilities(
        relayUrl,
      );

      UnifiedLogger.debug(
        '🔍 VideoFilterBuilder: Capabilities - hasDivineExtensions=${capabilities.hasDivineExtensions}, sortFields=${capabilities.sortFields.join(', ')}',
        name: 'VideoFilterBuilder',
      );

      // If relay doesn't support divine extensions, fall back to standard filter
      if (!capabilities.hasDivineExtensions) {
        UnifiedLogger.debug(
          'Relay $relayUrl does not support divine extensions, using standard filter',
          name: 'VideoFilterBuilder',
        );
        return baseFilter;
      }

      // Check if requested sort field is supported
      if (sortBy != null && !capabilities.supportsSortBy(sortBy.fieldName)) {
        UnifiedLogger.warning(
          'Relay $relayUrl does not support sorting by ${sortBy.fieldName}, using standard filter',
          name: 'VideoFilterBuilder',
        );
        return baseFilter;
      }

      // Validate int filters are supported
      if (intFilters != null) {
        for (final field in intFilters.keys) {
          if (!capabilities.supportsIntFilter(field)) {
            UnifiedLogger.warning(
              'Relay $relayUrl does not support int# filter for $field, using standard filter',
              name: 'VideoFilterBuilder',
            );
            return baseFilter;
          }
        }
      }

      // Build DivineFilter with requested extensions
      final divineFilter = DivineFilter(
        baseFilter: baseFilter,
        sort: sortBy != null
            ? SortConfig(field: sortBy.fieldName, direction: sortDirection)
            : null,
        intFilters: intFilters,
        cursor: cursor,
      );

      UnifiedLogger.info(
        'Using server-side sorting for $relayUrl: ${sortBy?.fieldName ?? "none"}',
        name: 'VideoFilterBuilder',
      );

      // Return the DivineFilter as a Filter (it extends Filter conceptually)
      // But since DivineFilter wraps Filter, we need to return it as a custom filter
      // We'll need to create a way to serialize this properly
      return _DivineFilterAdapter(divineFilter);
    } catch (e) {
      // If capability detection fails, fall back to standard filter
      UnifiedLogger.warning(
        'Failed to detect relay capabilities for $relayUrl: $e. Using standard filter.',
        name: 'VideoFilterBuilder',
      );
      return baseFilter;
    }
  }

  /// Build trending filter (sorted by loop_count desc)
  Future<Filter> buildTrendingFilter({
    required Filter baseFilter,
    required String relayUrl,
    int? minLoops,
  }) {
    return buildFilter(
      baseFilter: baseFilter,
      relayUrl: relayUrl,
      sortBy: VideoSortField.loopCount,
      sortDirection: SortDirection.desc,
      intFilters: minLoops != null
          ? {'loop_count': IntRangeFilter(gte: minLoops)}
          : null,
    );
  }

  /// Build most liked filter (sorted by likes desc)
  Future<Filter> buildMostLikedFilter({
    required Filter baseFilter,
    required String relayUrl,
    int? minLikes,
  }) {
    return buildFilter(
      baseFilter: baseFilter,
      relayUrl: relayUrl,
      sortBy: VideoSortField.likes,
      sortDirection: SortDirection.desc,
      intFilters: minLikes != null
          ? {'likes': IntRangeFilter(gte: minLikes)}
          : null,
    );
  }

  /// Build most viewed filter (sorted by views desc)
  Future<Filter> buildMostViewedFilter({
    required Filter baseFilter,
    required String relayUrl,
    int? minViews,
  }) {
    return buildFilter(
      baseFilter: baseFilter,
      relayUrl: relayUrl,
      sortBy: VideoSortField.views,
      sortDirection: SortDirection.desc,
      intFilters: minViews != null
          ? {'views': IntRangeFilter(gte: minViews)}
          : null,
    );
  }

  /// Build newest first filter (sorted by created_at desc)
  Future<Filter> buildNewestFilter({
    required Filter baseFilter,
    required String relayUrl,
  }) {
    return buildFilter(
      baseFilter: baseFilter,
      relayUrl: relayUrl,
      sortBy: VideoSortField.createdAt,
      sortDirection: SortDirection.desc,
    );
  }
}

/// Adapter to use DivineFilter as a Filter
/// This allows DivineFilter to be used in places expecting Filter
class _DivineFilterAdapter extends Filter {
  final DivineFilter _divineFilter;

  _DivineFilterAdapter(this._divineFilter)
    : super(
        kinds: _divineFilter.baseFilter.kinds,
        authors: _divineFilter.baseFilter.authors,
        ids: _divineFilter.baseFilter.ids,
        e: _divineFilter.baseFilter.e,
        p: _divineFilter.baseFilter.p,
        since: _divineFilter.baseFilter.since,
        until: _divineFilter.baseFilter.until,
        limit: _divineFilter.baseFilter.limit,
        t: _divineFilter.baseFilter.t,
        d: _divineFilter.baseFilter.d,
        h: _divineFilter.baseFilter.h,
      );

  @override
  Map<String, dynamic> toJson() {
    // Use DivineFilter's toJson which includes extensions
    return _divineFilter.toJson();
  }
}
