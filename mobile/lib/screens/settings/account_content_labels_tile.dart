// ABOUTME: Reusable settings tile for account-level content self-labels.
// ABOUTME: Used by Content & Safety and legacy content preferences routes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/account_content_labels/account_content_labels_cubit.dart';
import 'package:openvine/blocs/account_content_labels/account_content_labels_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_content_label_name.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';

/// Page: provides an [AccountContentLabelsCubit] scoped to this tile.
class AccountContentLabelsTile extends ConsumerWidget {
  const AccountContentLabelsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(accountLabelServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) => AccountContentLabelsCubit(service: service)..load(),
      child: const _AccountContentLabelsTileView(),
    );
  }
}

class _AccountContentLabelsTileView extends StatelessWidget {
  const _AccountContentLabelsTileView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountContentLabelsCubit, AccountContentLabelsState>(
      builder: (context, state) {
        return ListTile(
          leading: DivineIcon(
            icon: DivineIconName.warning,
            color: context.vineColors.accentPositive,
          ),
          title: Text(
            context.l10n.contentPreferencesAccountLabels,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          subtitle: Text(
            state.labels.isNotEmpty
                ? state.labels
                      .map(
                        (label) =>
                            localizedContentLabelName(context.l10n, label),
                      )
                      .join(', ')
                : context.l10n.contentPreferencesAccountLabelsEmpty,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          trailing: DivineIcon(
            icon: DivineIconName.caretRight,
            color: context.vineColors.mutedText,
          ),
          onTap: () => _selectLabels(context, state.labels),
        );
      },
    );
  }

  Future<void> _selectLabels(
    BuildContext context,
    Set<ContentLabel> current,
  ) async {
    final cubit = context.read<AccountContentLabelsCubit>();
    // Shared between the scroll body and the pinned bottom action, which
    // VineBottomSheet renders as sibling slots rather than one subtree.
    final selection = ValueNotifier<Set<ContentLabel>>(Set.of(current));
    final result = await VineBottomSheet.show<Set<ContentLabel>>(
      context: context,
      contentTitle: context.l10n.contentPreferencesAccountContentLabels,
      maxChildSize: 1,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      // On the title row rather than the header: the header sits above the
      // divider, which reads as chrome detached from the list it clears.
      contentTitleTrailing: _ClearAllAction(selection: selection),
      bottomInput: _AccountLabelDoneButton(selection: selection),
      buildScrollBody: (scrollController) => _AccountLabelMultiSelect(
        scrollController: scrollController,
        selection: selection,
      ),
    );
    selection.dispose();

    if (result != null) {
      await cubit.setLabels(result);
    }
  }
}

/// Title-row action that clears the in-progress selection.
class _ClearAllAction extends StatelessWidget {
  const _ClearAllAction({required this.selection});

  final ValueNotifier<Set<ContentLabel>> selection;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<ContentLabel>>(
      valueListenable: selection,
      builder: (context, selected, _) {
        if (selected.isEmpty) return const SizedBox.shrink();
        return DivineButton(
          label: context.l10n.contentPreferencesClearAll,
          type: DivineButtonType.link,
          size: DivineButtonSize.small,
          onPressed: () => selection.value = <ContentLabel>{},
        );
      },
    );
  }
}

/// Pinned bottom action that closes the sheet with the current selection.
class _AccountLabelDoneButton extends StatelessWidget {
  const _AccountLabelDoneButton({required this.selection});

  final ValueNotifier<Set<ContentLabel>> selection;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<ContentLabel>>(
      valueListenable: selection,
      builder: (context, selected, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DivineButton(
            label: selected.isEmpty
                ? context.l10n.contentPreferencesDoneNoLabels
                : context.l10n.contentPreferencesDoneCount(selected.length),
            expanded: true,
            onPressed: () => Navigator.of(context).pop(selected),
          ),
        ),
      ),
    );
  }
}

class _AccountLabelMultiSelect extends StatelessWidget {
  const _AccountLabelMultiSelect({
    required this.scrollController,
    required this.selection,
  });

  final ValueNotifier<Set<ContentLabel>> selection;
  final ScrollController scrollController;

  void _toggle(ContentLabel label) {
    final next = Set.of(selection.value);
    if (!next.remove(label)) next.add(label);
    selection.value = next;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<ContentLabel>>(
      valueListenable: selection,
      builder: (context, selected, _) => ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.zero,
        itemCount: ContentLabel.values.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.l10n.contentPreferencesSelectAllThatApply,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            );
          }
          final label = ContentLabel.values[index - 1];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: DivineRowCheckbox(
              state: selected.contains(label)
                  ? DivineCheckboxState.selected
                  : DivineCheckboxState.unselected,
              onChanged: (_) => _toggle(label),
              label: Text(
                localizedContentLabelName(context.l10n, label),
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
