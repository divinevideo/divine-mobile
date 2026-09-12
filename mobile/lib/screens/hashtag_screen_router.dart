// ABOUTME: Router-aware hashtag screen that shows the hashtag grid
// ABOUTME: Reads route context to determine which hashtag to display

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:unified_logger/unified_logger.dart';

/// Router-aware hashtag screen that always shows the grid.
/// Fullscreen video feed is pushed as an overlay from HashtagFeedScreen.
class HashtagScreenRouter extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'hashtag';

  /// Base path for hashtag routes.
  static const String basePath = RoutePaths.hashtagBase;

  /// Path for this route.
  static const path = '/hashtag/:tag';

  /// Build path for a specific hashtag.
  static String pathForTag(String tag) => RoutePaths.hashtagForTag(tag);

  const HashtagScreenRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeCtx = ref.watch(pageContextProvider).asData?.value;

    if (routeCtx == null || routeCtx.type != RouteType.hashtag) {
      Log.warning(
        'HashtagScreenRouter: Invalid route context',
        name: 'HashtagRouter',
        category: LogCategory.ui,
      );
      return Scaffold(
        body: Center(child: Text(context.l10n.routerInvalidHashtagRoute)),
      );
    }

    final hashtag = routeCtx.hashtag ?? 'trending';

    Log.info(
      'HashtagScreenRouter: Showing grid for #$hashtag',
      name: 'HashtagRouter',
      category: LogCategory.ui,
    );

    return HashtagFeedScreen(hashtag: hashtag, embedded: true);
  }
}
