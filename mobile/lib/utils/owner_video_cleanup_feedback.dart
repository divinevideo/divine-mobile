// ABOUTME: Presents terminal creator-delete cleanup feedback after relay success.
// ABOUTME: Captures UI dependencies before a delete surface is dismissed.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/content_deletion_service.dart';

void showOwnerVideoCleanupCompletion(
  BuildContext context,
  OwnerVideoActionsCubit cubit,
  String videoId,
) {
  final completion = cubit.cleanupCompletionFor(videoId);
  if (completion == null) return;

  final messenger = ScaffoldMessenger.of(context);
  final confirmed = context.l10n.shareMenuDeleteCleanupConfirmed;
  final delayed = context.l10n.shareMenuDeleteCleanupDelayed;
  final failed = context.l10n.shareMenuDeleteCleanupFailed;
  final partial = context.l10n.shareMenuDeletePartiallyConfirmed;

  unawaited(
    completion.then((operation) {
      if (!messenger.mounted) return;
      final message = switch (operation.cleanupStatus) {
        OwnerVideoCleanupStatus.confirmed =>
          operation.deleteResult?.acceptance == DeleteAcceptance.someRelays
              ? partial
              : confirmed,
        OwnerVideoCleanupStatus.delayed => delayed,
        OwnerVideoCleanupStatus.failed => failed,
        OwnerVideoCleanupStatus.unavailable => confirmed,
        OwnerVideoCleanupStatus.idle ||
        OwnerVideoCleanupStatus.inProgress => delayed,
      };
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          message,
          error: operation.cleanupStatus == OwnerVideoCleanupStatus.failed,
        ),
      );
    }),
  );
}
