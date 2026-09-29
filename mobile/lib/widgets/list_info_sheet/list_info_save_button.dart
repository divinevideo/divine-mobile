// ABOUTME: The check button in the list info sheet's header.
// ABOUTME: Confirms a visibility change, then submits the form.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/list_info_sheet/list_visibility_change_dialog.dart';
import 'package:unified_logger/unified_logger.dart';

/// Saves the list info form.
///
/// Disabled until the list has a name, and replaced by a spinner while the
/// save runs so a second tap cannot start another one.
class ListInfoSaveButton extends StatelessWidget {
  /// Creates the save button.
  const ListInfoSaveButton({super.key});

  /// Edge of the small icon button's tap target, which the spinner takes
  /// over so that the header does not shift when a save starts.
  static const double _tapTargetSize = 48;

  /// Diameter of the spinner.
  static const double _spinnerSize = 20;

  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<CuratedListInfoCubit>();
    final wasPublic = cubit.state.wasPublic;
    if (cubit.state.visibilityWillChange && wasPublic != null) {
      final confirmed = await confirmListVisibilityChange(
        context,
        wasPublic: wasPublic,
      );
      if (!confirmed) return;
    }
    await cubit.submitted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.isEditing,
    );
    final isSaving = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.isSaving,
    );
    final canSubmit = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.canSubmit,
    );
    final label = isEditing ? l10n.listSave : l10n.listCreate;

    if (isSaving) {
      return SizedBox.square(
        dimension: DivineIcon.scaleSize(context, _tapTargetSize),
        child: Center(
          child: SizedBox.square(
            dimension: DivineIcon.scaleSize(context, _spinnerSize),
            child: DivineCircularProgressIndicator(
              strokeWidth: 2,
              color: VineTheme.primary,
              semanticsLabel: label,
            ),
          ),
        ),
      );
    }

    return DivineIconButton(
      icon: DivineIconName.check,
      size: DivineIconButtonSize.small,
      semanticLabel: label,
      onPressed: canSubmit
          ? () => runDetached(
              _submit(context),
              'save list info',
              logName: 'ListInfoSaveButton',
              category: LogCategory.ui,
            )
          : null,
    );
  }
}
