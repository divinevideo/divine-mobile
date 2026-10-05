// ABOUTME: The body of the list info sheet: name and description inputs, the
// ABOUTME: collaborators row and the visibility switch.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_collaborators_row.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_failure_message.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_fields.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_recovery_pending_message.dart';
import 'package:unified_logger/unified_logger.dart';

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
      // The scroll view ends at the keyboard rather than running behind it,
      // so a field being typed in is scrolled into view above it.
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Outside the scroll view: Save sits in the pinned header, so the
            // failure it reports must not scroll out of sight.
            const _SaveFailedMessage(),
            const _RecoveryMessage(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        spacing: 16,
                        children: [
                          _NameField(controller: _nameController),
                          _DescriptionField(
                            controller: _descriptionController,
                          ),
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
            ),
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
    final status = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.status,
    );
    final isEditing = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.isEditing,
    );
    if (status != CuratedListInfoStatus.failure &&
        status != CuratedListInfoStatus.permissionsUnconfirmed) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    return ListInfoFailureMessage(
      status == CuratedListInfoStatus.permissionsUnconfirmed
          ? l10n.listPermissionsUnconfirmed
          : isEditing
          ? l10n.listUpdateFailed
          : l10n.listCreateFailed,
    );
  }
}

class _RecoveryMessage extends StatelessWidget {
  const _RecoveryMessage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CuratedListInfoCubit>().state;
    if (!state.needsSync) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListInfoRecoveryPendingMessage(),
          DivineButton(
            label: context.l10n.listRetrySync,
            type: DivineButtonType.link,
            onPressed: state.isSaving
                ? null
                : () => runDetached(
                    context.read<CuratedListInfoCubit>().retrySync(),
                    'recover list sync',
                    logName: 'ListInfoForm',
                    category: LogCategory.ui,
                  ),
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (CuratedListInfoCubit cubit) => !cubit.state.canEdit,
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
      (CuratedListInfoCubit cubit) => !cubit.state.canEdit,
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
      (CuratedListInfoCubit cubit) => !cubit.state.canEdit,
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
