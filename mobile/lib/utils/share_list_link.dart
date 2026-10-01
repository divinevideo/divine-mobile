// ABOUTME: Opens the share sheet on a list's web link and reports a failure
// ABOUTME: in a snackbar, for the video-list and people-list screens alike.

import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shares the web link of the list named [name], whose in-app [path] is the
/// same path under [AppConstants.webOrigin].
///
/// A sheet that cannot open is logged and reported in a snackbar on the
/// messenger [context] resolves before the sheet is asked for.
Future<void> shareListLink(
  BuildContext context, {
  required String name,
  required String path,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final url = '${AppConstants.webOrigin}$path';
  try {
    await showShareSheet(
      context,
      ShareParams(
        text: l10n.listShareText(name, url),
        subject: l10n.listShareSubject(name),
      ),
    );
  } on Exception catch (error, stackTrace) {
    Log.error(
      'Failed to share list',
      name: 'shareListLink',
      category: LogCategory.ui,
      error: error,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(SnackBar(content: Text(l10n.listShareFailed)));
  }
}
