import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

class SaveButton extends StatelessWidget {
  const SaveButton({required this.canSave, required this.onSave, super.key});

  final bool canSave;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<ProfileEditorBloc, bool>(
      (bloc) => bloc.state.status == ProfileEditorStatus.loading,
    );

    return DivineButton(
      label: isLoading
          ? context.l10n.profileSetupSavingButton
          : context.l10n.profileSetupSaveButton,
      isLoading: isLoading,
      expanded: true,
      onPressed: (isLoading || !canSave) ? null : onSave,
    );
  }
}
