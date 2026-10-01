// ABOUTME: The body of the list info sheet: name and description inputs, the
// ABOUTME: collaborators row and the visibility switch.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_collaborators_row.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_failure_message.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_fields.dart';

/// The form inside the list info sheet.
///
/// Owns the text controllers so they outlive the sheet's exit animation: the
/// route keeps rebuilding its subtree on the way out. Every value the form
/// holds lives in [CuratedListInfoCubit]; the controllers only carry it to
/// and from the fields.
class ListInfoForm extends StatefulWidget {
  /// Creates the form.
  const ListInfoForm({super.key});

  @override
  State<ListInfoForm> createState() => _ListInfoFormState();
}

class _ListInfoFormState extends State<ListInfoForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final state = context.read<CuratedListInfoCubit>().state;
    _nameController = TextEditingController(text: state.name);
    _descriptionController = TextEditingController(text: state.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CuratedListInfoCubit, CuratedListInfoState>(
      listenWhen: (previous, current) => !previous.canClose && current.canClose,
      listener: (context, _) => context.popModalIfMounted(),
      child: SingleChildScrollView(
        // Keeps the focused field clear of the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SaveFailedMessage(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                spacing: 16,
                children: [
                  _NameField(controller: _nameController),
                  _DescriptionField(controller: _descriptionController),
                ],
              ),
            ),
            const ListInfoCollaboratorsRow(),
            const _RowDivider(),
            const _VisibilityTile(),
            const _RowDivider(),
          ],
        ),
      ),
    );
  }
}

class _SaveFailedMessage extends StatelessWidget {
  const _SaveFailedMessage();

  @override
  Widget build(BuildContext context) {
    final failed = context.select(
      (CuratedListInfoCubit cubit) =>
          cubit.state.status == CuratedListInfoStatus.failure,
    );
    final isEditing = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.isEditing,
    );
    if (!failed) return const SizedBox.shrink();

    final l10n = context.l10n;
    return ListInfoFailureMessage(
      isEditing ? l10n.listUpdateFailed : l10n.listCreateFailed,
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.isSaving,
    );
    return ListNameField(
      controller: controller,
      enabled: !isSaving,
      onChanged: context.read<CuratedListInfoCubit>().nameChanged,
    );
  }
}

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.isSaving,
    );
    return ListDescriptionField(
      controller: controller,
      enabled: !isSaving,
      onChanged: context.read<CuratedListInfoCubit>().descriptionChanged,
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPublic = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.isPublic,
    );
    final isSaving = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.isSaving,
    );
    // The sheet paints its surface with a ColoredBox, which would hide the
    // tile's ink; its own Material puts the ink back on top.
    return Material(
      type: MaterialType.transparency,
      child: DivineSwitchTile(
        title: l10n.listMakePublicLabel,
        // A private list still shows its name, description, tags and cover,
        // which the owner has to be told before choosing it.
        subtitle: isPublic
            ? l10n.listMakePublicSubtitle
            : l10n.listPrivateListSubtitle,
        value: isPublic,
        onChanged: isSaving
            ? null
            : (value) => context.read<CuratedListInfoCubit>().visibilityChanged(
                isPublic: value,
              ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.vineColors.outlineDisabled,
    );
  }
}
