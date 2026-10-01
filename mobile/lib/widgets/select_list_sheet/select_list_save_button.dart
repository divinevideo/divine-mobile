// ABOUTME: The check button in the list picker's header: writes the picks
// ABOUTME: and shows a spinner while they are being written.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/select_list/select_list_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';

/// The header's check button; needs a [SelectListCubit] above it.
///
/// Disabled until at least one list is picked.
class SelectListSaveButton extends StatelessWidget {
  /// Creates the button.
  const SelectListSaveButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (SelectListCubit cubit) => cubit.state.isSaving,
    );
    final canSubmit = context.select(
      (SelectListCubit cubit) => cubit.state.canSubmit,
    );
    return ListInfoCheckButton(
      semanticLabel: context.l10n.listDone,
      isSaving: isSaving,
      onPressed: !canSubmit
          ? null
          : () => runDetached(
              context.read<SelectListCubit>().submitted(),
              'save list picks',
              logName: 'SelectListSheet',
              category: LogCategory.ui,
            ),
    );
  }
}
