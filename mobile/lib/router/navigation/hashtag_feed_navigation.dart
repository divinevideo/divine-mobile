// ABOUTME: Opens a hashtag feed at most once per frame for every control that
// ABOUTME: links to one, so a quick second tap cannot stack a copy (#9980)

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/routes/search_routes.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Routers that opened a hashtag feed since the last frame was drawn.
final Expando<bool> _openedThisFrame = Expando<bool>('openHashtagFeed');

/// Pushes the feed for [tag], unless [context]'s router already opened a
/// hashtag feed since the last frame.
///
/// A go_router push lands at once, but its page takes taps only from the next
/// frame, so a second tap before then would stack another feed (#9980).
///
/// A failed push is logged under [logName] as "Failed to [description]".
void openHashtagFeed(
  BuildContext context,
  String tag, {
  required String logName,
  String description = 'open hashtag feed',
}) {
  final router = GoRouter.of(context);
  if (_openedThisFrame[router] ?? false) return;
  _openedThisFrame[router] = true;
  SchedulerBinding.instance
    ..addPostFrameCallback((_) => _openedThisFrame[router] = null)
    ..ensureVisualUpdate();
  runDetached(
    HashtagRouteData(tag: tag).push<void>(context),
    description,
    logName: logName,
    category: LogCategory.ui,
  );
}
