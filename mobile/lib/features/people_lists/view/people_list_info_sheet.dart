// ABOUTME: The sheet that edits a people list's name and description.
// ABOUTME: Owns its cubit; the renamed list reaches the screens via the bloc.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/people_list_info_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';

/// Shows the sheet that edits [list]'s name and description.
///
/// Does nothing without a signed-in owner the feature is on for: only an
/// owner's own list offers the action that opens this. Completes once the
/// sheet has closed.
Future<void> showPeopleListInfoSheet(
  BuildContext context, {
  required UserList list,
}) async {
  final mutations = context.read<PeopleListsBloc>();
  final ownerPubkey = mutations.state.activeOwnerPubkey;
  if (ownerPubkey == null || ownerPubkey.isEmpty) return;

  final l10n = context.l10n;
  final formKey = GlobalKey();

  await context.showVideoPausingVineBottomSheet<void>(
    scrollable: false,
    expanded: false,
    isScrollControlled: true,
    title: Text(l10n.listEditInfoAction),
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
    trailing: const _SaveButton(),
    contentWrapper: (_, sheet) => BlocProvider<PeopleListInfoCubit>(
      create: (_) => PeopleListInfoCubit(
        submitMutation: mutations.submit,
        ownerPubkey: ownerPubkey,
        list: list,
      ),
      child: sheet,
    ),
    body: _PeopleListInfoForm(key: formKey),
  );
}

/// The name and description inputs.
///
/// Owns the text controllers so they outlive the sheet's exit animation; the
/// values themselves live in [PeopleListInfoCubit].
class _PeopleListInfoForm extends StatefulWidget {
  const _PeopleListInfoForm({super.key});

  @override
  State<_PeopleListInfoForm> createState() => _PeopleListInfoFormState();
}

class _PeopleListInfoFormState extends State<_PeopleListInfoForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final state = context.read<PeopleListInfoCubit>().state;
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
    return BlocListener<PeopleListInfoCubit, PeopleListInfoState>(
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
      (PeopleListInfoCubit cubit) =>
          cubit.state.status == PeopleListInfoStatus.failure,
    );
    if (!failed) return const SizedBox.shrink();
    return ListInfoFailureMessage(context.l10n.listUpdateFailed);
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (PeopleListInfoCubit cubit) => cubit.state.isSaving,
    );
    return ListNameField(
      controller: controller,
      enabled: !isSaving,
      onChanged: context.read<PeopleListInfoCubit>().nameChanged,
    );
  }
}

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (PeopleListInfoCubit cubit) => cubit.state.isSaving,
    );
    return ListDescriptionField(
      controller: controller,
      enabled: !isSaving,
      onChanged: context.read<PeopleListInfoCubit>().descriptionChanged,
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<PeopleListInfoCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final route = ModalRoute.of(context);
    final failureMessage = context.l10n.listUpdateFailed;
    final status = await cubit.submitted();
    if (status == PeopleListInfoStatus.failure &&
        route?.isCurrent == false &&
        messenger.mounted) {
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(failureMessage, error: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (PeopleListInfoCubit cubit) => cubit.state.isSaving,
    );
    final canSubmit = context.select(
      (PeopleListInfoCubit cubit) => cubit.state.canSubmit,
    );
    return ListInfoCheckButton(
      semanticLabel: context.l10n.listSave,
      isSaving: isSaving,
      onPressed: canSubmit
          ? () => runDetached(
              _submit(context),
              'save people list info',
              logName: 'PeopleListInfoSheet',
              category: LogCategory.ui,
            )
          : null,
    );
  }
}
