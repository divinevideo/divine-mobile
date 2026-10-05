// ABOUTME: Opens the sheet that creates a curated list or edits one's info.
// ABOUTME: Owns the sheet's cubit and reports a save no relay accepted.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show ScaffoldMessenger;
import 'package:models/models.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/curated_list_editor_session_provider.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_form.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_save_button.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet_layout.dart';

/// How a visit to the list info sheet ended.
enum ListInfoSheetOutcome {
  /// The sheet was closed without a successful save.
  dismissed,

  /// The list was created or its edits saved.
  saved,

  /// The list exists, but the video could not be added locally.
  createdWithoutVideo,

  /// The list includes the video locally and awaits publication.
  createdWithVideoPendingSync,
}

/// Shows the sheet that creates a curated list, or edits [existingList].
///
/// A [video] is added to the list the sheet creates.
///
/// Completes once the sheet has closed and its save has settled. A rename
/// lets the sheet close before any relay answers, so the wait covers the
/// answer that arrives afterwards and its failure, if any, is reported on the
/// screen the sheet was opened from. A [video] the created list refused is
/// returned as [ListInfoSheetOutcome.createdWithoutVideo] instead. A locally
/// added video still waiting on relays returns
/// [ListInfoSheetOutcome.createdWithVideoPendingSync]. In both cases,
/// the caller may itself be a sheet that would cover a report drawn
/// underneath, as the list picker is.
Future<ListInfoSheetOutcome> showListInfoSheet(
  BuildContext context, {
  VideoEvent? video,
  CuratedList? existingList,
}) async {
  final l10n = context.l10n;
  // Resolved before the sheet opens: once it has closed, the screen that
  // opened it may be gone, and neither could be recovered from [context].
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);

  final session = container.read(curatedListEditorSessionProvider);
  final cubit = CuratedListInfoCubit(
    resolveService: () => session.service,
    currentOwnerPubkey: () => session.currentOwnerPubkey,
    existingList: existingList,
    videoEventId: video?.id,
  );
  final formKey = GlobalKey();

  try {
    await context.showVideoPausingVineBottomSheet<void>(
      scrollable: false,
      expanded: false,
      isScrollControlled: true,
      title: Text(
        existingList == null ? l10n.listCreateNewList : l10n.listEditTitle,
      ),
      headerPadding: listInfoSheetHeaderPadding,
      headerLeadingAction: DivineIconButton(
        icon: DivineIconName.x,
        type: DivineIconButtonType.secondary,
        size: DivineIconButtonSize.small,
        semanticLabel: l10n.commonClose,
        // The form's context belongs to the sheet's own route, so the pop is
        // skipped once that route is already on its way out.
        onPressed: () => formKey.currentContext?.popModalIfMounted(),
      ),
      trailing: const ListInfoSaveButton(),
      contentWrapper: (_, sheet) => BlocProvider<CuratedListInfoCubit>.value(
        value: cubit,
        child: sheet,
      ),
      body: ListInfoForm(key: formKey),
    );

    var settled = cubit.state;
    // Let a save finish after manual dismissal so its result is still reported.
    final savePending =
        settled.isSaving ||
        settled.status == CuratedListInfoStatus.savedAwaitingRelay;
    if (savePending) {
      settled = await cubit.stream.firstWhere(
        (state) =>
            !state.isSaving &&
            state.status != CuratedListInfoStatus.savedAwaitingRelay,
        orElse: () => cubit.state,
      );
    }
    if (!cubit.isSessionCurrent) {
      return ListInfoSheetOutcome.dismissed;
    }
    // A failure the form was still showing when it closed has been reported
    // there; one that arrived after the sheet closed has not.
    final unreported =
        settled.status == CuratedListInfoStatus.publishFailed ||
        (savePending &&
            (settled.status == CuratedListInfoStatus.failure ||
                settled.status ==
                    CuratedListInfoStatus.permissionsUnconfirmed));
    if (messenger.mounted && unreported) {
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          settled.status == CuratedListInfoStatus.permissionsUnconfirmed
              ? l10n.listPermissionsUnconfirmed
              : existingList == null
              ? l10n.listCreateFailed
              : l10n.listUpdateFailed,
          error: true,
        ),
      );
    }
    return switch (settled.status) {
      CuratedListInfoStatus.createdWithVideoPendingSync =>
        ListInfoSheetOutcome.createdWithVideoPendingSync,
      CuratedListInfoStatus.createdWithoutVideo =>
        ListInfoSheetOutcome.createdWithoutVideo,
      CuratedListInfoStatus.saved ||
      CuratedListInfoStatus.savedAwaitingRelay ||
      CuratedListInfoStatus.publishFailed => ListInfoSheetOutcome.saved,
      CuratedListInfoStatus.editing ||
      CuratedListInfoStatus.saving ||
      CuratedListInfoStatus.failure ||
      CuratedListInfoStatus.permissionsUnconfirmed =>
        ListInfoSheetOutcome.dismissed,
    };
  } finally {
    await cubit.close();
  }
}
