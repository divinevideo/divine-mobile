// ABOUTME: Resolves an owned people list before opening its metadata editor.
// ABOUTME: Retains the opening account boundary across sync and account changes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';

/// Loads an owned list for editing without treating a pending read as absence.
class EditPeopleListPage extends ConsumerStatefulWidget {
  const EditPeopleListPage({required this.listId, super.key});

  static const path = '/people-lists/:listId/edit';
  static const routeName = 'people-list-edit';

  final String listId;

  @override
  ConsumerState<EditPeopleListPage> createState() => _EditPeopleListPageState();
}

class _EditPeopleListPageState extends ConsumerState<EditPeopleListPage> {
  late final String? _openingOwner;

  @override
  void initState() {
    super.initState();
    _openingOwner = ref.read(authServiceProvider).currentPublicKeyHex;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PeopleListsBloc, PeopleListsState>(
      builder: (context, state) {
        if (_openingOwner == null ||
            !state.enabled ||
            state.activeOwnerPubkey != _openingOwner ||
            ref.read(authServiceProvider).currentPublicKeyHex !=
                _openingOwner) {
          return _EditStatus(message: context.l10n.peopleListsSessionChanged);
        }
        for (final list in state.lists) {
          if (list.id == widget.listId && list.isEditable) {
            return CreatePeopleListPage(editingList: list);
          }
        }
        if (state.ownerReadStatus == PeopleListsOwnerReadStatus.failed) {
          return _EditStatus(
            message: context.l10n.peopleListsLoadFailed,
            onRetry: () => context.read<PeopleListsBloc>().add(
              const PeopleListsOwnerSyncRequested(),
            ),
          );
        }
        if (!state.listsKnown) return const _EditStatus();
        return _EditStatus(message: context.l10n.peopleListsListNotFoundTitle);
      },
    );
  }
}

class _EditStatus extends StatelessWidget {
  const _EditStatus({this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.listEditTitle,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: message == null
              ? const DivineCircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    Text(message!, textAlign: TextAlign.center),
                    if (onRetry != null)
                      DivineButton(
                        label: context.l10n.peopleListsAddPeopleRetry,
                        onPressed: onRetry,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
