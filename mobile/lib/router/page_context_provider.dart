// ABOUTME: Derived provider that parses router location into structured context
// ABOUTME: Single source of truth for "what page are we on?"

import 'package:riverpod/riverpod.dart';
import 'package:openvine/router/router_location_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/utils/unified_logger.dart';

/// StreamProvider that derives structured page context from router location
///
/// Uses async* to emit immediately when the raw location stream has a value.
/// This ensures tests using Stream.value() get synchronous first emission.
///
/// Example:
/// ```dart
/// final context = ref.watch(pageContextProvider);
/// context.when(
///   data: (ctx) {
///     if (ctx.type == RouteType.home) {
///       // Show home feed videos
///     }
///   },
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => ErrorWidget(e),
/// );
/// ```
final pageContextProvider = StreamProvider<RouteContext>((ref) async* {
  // Get the raw location stream (overridable in tests)
  final locations = ref.watch(routerLocationStreamProvider);

  // Emit a context immediately if the stream is a single-value Stream.value(...)
  // (In tests we often use Stream.value('/profile/npub...'))
  await for (final loc in locations) {
    print('🟪 PAGE_CONTEXT DEBUG: Raw location = $loc');
    final ctx = parseRoute(loc);
    print(
      '🟪 PAGE_CONTEXT DEBUG: Parsed context = type=${ctx.type}, npub=${ctx.npub}, index=${ctx.videoIndex}',
    );
    Log.info(
      'CTX derive: type=${ctx.type} npub=${ctx.npub} index=${ctx.videoIndex}',
      name: 'Route',
      category: LogCategory.system,
    );
    yield ctx;
  }
});
