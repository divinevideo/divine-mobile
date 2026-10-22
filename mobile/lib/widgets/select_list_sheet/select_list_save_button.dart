// ABOUTME: The check button in the list picker's header: writes the picks
// ABOUTME: and shows a spinner while they are being written.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/select_list/select_list_cubit.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';

/// The header's check button; needs a [SelectListCubit] above it.
///
/// Disabled while a save runs, and while no list is picked and none that
/// holds the video is unpicked. During recovery, Done only closes the sheet.
class SelectListSaveButton extends StatelessWidget {
  /// Creates the button.
  const SelectListSaveButton({super.key});

  Future<void> _save(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final route = ModalRoute.of(context);
    final l10n = context.l10n;
    final cubit = context.read<SelectListCubit>();
    cubit.refreshRecoveryReadOnly();
    if (cubit.state.recoveryReadOnly || !cubit.state.serviceAvailable) {
      context.popModalIfMounted();
      return;
    }
    final status = await cubit.submitted();
    if (!cubit.isSessionCurrent) return;
    if ((route?.isCurrent ?? false) || !(messenger?.mounted ?? false)) return;
    final message = switch (status) {
      SelectListStatus.failure => l10n.listUpdateFailed,
      SelectListStatus.failureListFull => l10n.listPrivateFull,
      _ => null,
    };
    if (message != null) {
      messenger!.showSnackBar(
        DivineSnackbarContainer.snackBar(message, error: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (SelectListCubit cubit) => cubit.state.isSaving,
    );
    final canSubmit = context.select(
      (SelectListCubit cubit) => cubit.state.canSubmit,
    );
    final closesWithoutSaving = context.select(
      (SelectListCubit cubit) =>
          cubit.state.recoveryReadOnly || !cubit.state.serviceAvailable,
    );
    return ListInfoCheckButton(
      semanticLabel: context.l10n.listDone,
      isSaving: isSaving,
      onPressed: !canSubmit && !closesWithoutSaving
          ? null
          : () => runDetached(
              _save(context),
              'save list picks',
              logName: 'SelectListSheet',
              category: LogCategory.ui,
            ),
    );
  }
}
