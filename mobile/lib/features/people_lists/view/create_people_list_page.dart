// ABOUTME: Full-screen creation and public metadata editing for people lists.
// ABOUTME: Retains create/edit inputs until relay-confirmed publication.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/widgets/people_list_result_notice.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';

/// Full-screen page that creates a new NIP-51 kind 30000 people list.
///
/// Consumers navigate here via the `/people-lists/new` route. The page owns
/// a single [TextFormField] for the list's display name plus an optional
/// description, and a "Create" [DivineButton] that dispatches
/// [PeopleListsCreateRequested] to the ambient [PeopleListsBloc].
///
/// Waits for its own operation result so failures leave entered fields intact.
class CreatePeopleListPage extends ConsumerStatefulWidget {
  /// Creates the create-list page.
  const CreatePeopleListPage({this.initialPubkey, this.editingList, super.key});

  /// Existing owned list whose public metadata is being edited.
  final UserList? editingList;

  /// GoRouter name for this route.
  static const routeName = 'people-list-create';

  /// GoRouter path template for this route.
  static const String path = RoutePaths.createPeopleList;

  /// Builds the path + query string that opens this page and seeds the
  /// new list with [pubkey] on submit.
  ///
  /// The pubkey is URI-encoded but never truncated; consumers pass the
  /// full hex pubkey so the create flow can add the target person in
  /// the same request.
  static String pathWithInitialPubkey(String pubkey) =>
      '$path?initialPubkey=${Uri.encodeQueryComponent(pubkey)}';

  /// Optional pubkey to seed into the new list on submit. Threaded
  /// through from `/people-lists/new?initialPubkey=<hex>` so the
  /// create flow works as a single URL-reloadable operation.
  final String? initialPubkey;

  @override
  ConsumerState<CreatePeopleListPage> createState() =>
      _CreatePeopleListPageState();
}

class _CreatePeopleListPageState extends ConsumerState<CreatePeopleListPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _submitting = false;
  PeopleListsOperationResult? _result;
  late final String? _openingOwner;

  @override
  void initState() {
    super.initState();
    _openingOwner = ref.read(authServiceProvider).currentPublicKeyHex;
    _nameController = TextEditingController(text: widget.editingList?.name);
    _descriptionController = TextEditingController(
      text: widget.editingList?.description,
    );
    // Rebuild the Create button enable-state as the text changes.
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    // setState forces _CreateButton to re-read `canSubmit`.
    setState(() {});
  }

  bool get _canSubmit => !_submitting && _nameController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    final owner = _openingOwner;
    if (name.isEmpty ||
        owner == null ||
        owner.isEmpty ||
        ref.read(authServiceProvider).currentPublicKeyHex != owner ||
        context.read<PeopleListsBloc>().state.activeOwnerPubkey != owner) {
      setState(() => _result = PeopleListsOperationResult.cancelled);
      return;
    }
    final initialPubkeys = switch (widget.initialPubkey) {
      final value? when value.isNotEmpty => [value],
      _ => const <String>[],
    };
    setState(() {
      _submitting = true;
      _result = null;
    });
    final editing = widget.editingList;
    final result = await context.read<PeopleListsBloc>().submit(
      editing == null
          ? PeopleListsCreateRequested(
              expectedOwnerPubkey: owner,
              name: name,
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              initialPubkeys: initialPubkeys,
            )
          : PeopleListsUpdateRequested(
              expectedOwnerPubkey: owner,
              listId: editing.id,
              name: name,
              description: _descriptionController.text.trim(),
            ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = result;
    });
    if (result == PeopleListsOperationResult.succeeded) {
      context.safePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: widget.editingList == null
            ? context.l10n.peopleListsNewListTitle
            : context.l10n.listEditTitle,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NameField(
                        controller: _nameController,
                        enabled: !_submitting,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: context.l10n.listDescriptionLabel,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(context.l10n.peopleListsPublicNotice),
                    ],
                  ),
                ),
              ),
              PeopleListResultNotice(
                result: _result,
                failedMessage: widget.editingList == null
                    ? context.l10n.listCreateFailed
                    : context.l10n.listUpdateFailed,
              ),
              if (_submitting)
                const Center(child: DivineCircularProgressIndicator()),
              _CreateButton(
                editing: widget.editingList != null,
                onPressed: _canSubmit ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.enabled});

  final bool enabled;

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: true,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
      decoration: InputDecoration(
        labelText: context.l10n.peopleListsListNameLabel,
        hintText: context.l10n.peopleListsListNameHint,
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed, required this.editing});

  final bool editing;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: editing
          ? context.l10n.listSave
          : context.l10n.peopleListsCreateButton,
      expanded: true,
      onPressed: onPressed,
    );
  }
}
