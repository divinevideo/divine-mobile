// ABOUTME: Extra data classes for GoRouter navigation
// ABOUTME: Used to pass structured data between routes via GoRouter extra

/// Safely reads a GoRouter `state.extra` payload as [T].
///
/// Returns `null` when [extra] is not a [T]. A deep link arrives with no
/// `extra`, and saved route state can hand it back as decoded JSON — a plain
/// `Map<String, dynamic>` rather than the originally-passed typed object — so
/// a raw `extra as T` cast throws
/// `type '_Map<String, dynamic>' is not a subtype of type 'T'` and crashes the
/// route builder (Crashlytics iOS 5b96bfc6…, efec8882…). Each affected route
/// already tolerates a missing payload (optional hints, id-based loaders, or a
/// `??` fallback), so returning `null` degrades gracefully instead of crashing.
///
/// The deeper fix is to stop passing typed objects through `extra` entirely
/// (see `.claude/rules/routing.md` — `extra` breaks deep linking and
/// restoration); that migration is tracked separately.
T? extraAs<T>(Object? extra) => extra is T ? extra : null;

/// Reads a typed value from a restored route-extra map.
///
/// GoRouter may restore `extra` as a dynamically typed map.  Read individual
/// values with a runtime check rather than casting the whole map (generic Map
/// types are invariant and a `Map<String, dynamic>` is not a
/// `Map<String, String?>`).
T? extraValue<T>(Object? extra, String key) {
  if (extra is! Map) return null;
  return extraAs<T>(extra[key]);
}

/// Extra data for curated list route (passed via GoRouter extra)
class CuratedListRouteExtra {
  const CuratedListRouteExtra({
    required this.listName,
    this.videoIds,
    this.authorPubkey,
  });

  final String listName;
  final List<String>? videoIds;
  final String? authorPubkey;
}
