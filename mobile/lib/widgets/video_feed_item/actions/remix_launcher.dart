// ABOUTME: Opens the clip library after a remix has been saved there.
// ABOUTME: Leaves the user's in-progress recording, editor and drafts intact.

import 'package:flutter/widgets.dart';
import 'package:openvine/router/routes/library_routes.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_feed_item/actions/sheet_dismissal.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shows the saved remix in the library, where it can be picked alongside the
/// user's recordings. Completes once the library is pushed or the launch is
/// dropped, not when the library closes.
///
/// Dropped when a route the user opened covers the sheet, or the sheet is
/// already closing: dismissing it then would close that other route instead.
Future<void> openRemixInLibrary(
  BuildContext sheetContext, {
  required bool fromOthers,
}) async {
  if (!sheetContext.mounted || !_isSheetOnTop(sheetContext)) return;

  await presentAfterSheetDismiss<void>(sheetContext, (hostContext) async {
    // Not awaited: the push completes only when the library closes.
    runDetached(
      LibraryClipsRouteData(
        fromOthers: fromOthers ? 'true' : null,
      ).push<void>(hostContext),
      'show the remix in the clip library',
      logName: 'RemixLauncher',
      category: LogCategory.video,
    );
  });
}

/// Whether the sheet owning the mounted [sheetContext] is the top route, so
/// dismissing it closes the sheet and nothing else.
bool _isSheetOnTop(BuildContext sheetContext) {
  if (ModalRoute.of(sheetContext)?.isCurrent ?? false) return true;
  Log.info(
    'Dropped a remix launch: a route covers the sheet, or it is closing',
    name: 'RemixLauncher',
    category: LogCategory.video,
  );
  return false;
}
