// ABOUTME: Full-screen create-list page for people lists.
// ABOUTME: Dispatches PeopleListsCreateRequested and pops on submit.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';

/// Full-screen page that creates a new NIP-51 kind 30000 people list.
///
/// Consumers navigate here via the `/people-lists/new` route. The page owns
/// a single [TextFormField] for the list's display name plus an optional
/// description, and a "Create" [DivineButton] that dispatches
/// [PeopleListsCreateRequested] to the ambient [PeopleListsBloc].
///
/// The page intentionally stays thin: no local form bloc, no async wait on
/// the repository. It relies on [PeopleListsBloc]'s optimistic update so the
/// rest of the UI reflects the new list immediately after dispatch.
class CreatePeopleListPage extends StatefulWidget {
  /// Creates the create-list page.
  const CreatePeopleListPage({this.initialPubkey, super.key});

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
  State<CreatePeopleListPage> createState() => _CreatePeopleListPageState();
}

class _CreatePeopleListPageState extends State<CreatePeopleListPage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    // Rebuild the Create button enable-state as the text changes.
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() {
    // setState forces _CreateButton to re-read `canSubmit`.
    setState(() {});
  }

  bool get _canSubmit => _nameController.text.trim().isNotEmpty;

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    final initialPubkeys = switch (widget.initialPubkey) {
      final value? when value.isNotEmpty => [value],
      _ => const <String>[],
    };
    context.read<PeopleListsBloc>().add(
      PeopleListsCreateRequested(
        name: name,
        initialPubkeys: initialPubkeys,
      ),
    );
    // Use Navigator.maybePop so the page works even when no GoRouter is
    // present (e.g., simple widget-test harnesses without MaterialApp.router).
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.peopleListsNewListTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NameField(controller: _nameController),
              const Spacer(),
              _CreateButton(
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
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
      decoration: InputDecoration(
        labelText: context.l10n.peopleListsListNameLabel,
        hintText: context.l10n.peopleListsListNameHint,
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: context.l10n.peopleListsCreateButton,
      expanded: true,
      onPressed: onPressed,
    );
  }
}
