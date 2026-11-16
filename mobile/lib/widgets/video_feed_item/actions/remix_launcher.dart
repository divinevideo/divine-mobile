// ABOUTME: Opens the clip library after a remix has been saved there.
// ABOUTME: Leaves the user's in-progress recording, editor and drafts intact.

import 'package:flutter/widgets.dart';
import 'package:openvine/router/routes/library_routes.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_feed_item/actions/sheet_dismissal.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shows the saved remix in the library, where it can be picked alongside the
/// user's recordings. Completes when the library opens, or the launch is dropped.
Future<void> openRemixInLibrary(
  BuildContext sheetContext, {
  required bool fromOthers,
}) async {
  if (!sheetContext.mounted || !_isSheetOnTop(sheetContext)) return;

  await presentAfterSheetDismiss<void>(sheetContext, (hostContext) async {
    runDetached(
      LibraryClipsRouteData(fromOthers: fromOthers).push<void>(hostContext),
      'show the remix in the clip library',
      logName: 'RemixLauncher',
      category: LogCategory.video,
    );
  });
}

bool _isSheetOnTop(BuildContext sheetContext) {
  if (ModalRoute.of(sheetContext)?.isCurrent ?? false) return true;
  Log.info(
    'Dropped a remix launch: a route covers the sheet, or it is closing',
    name: 'RemixLauncher',
    category: LogCategory.video,
  );
  return false;
}
