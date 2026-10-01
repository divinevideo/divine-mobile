// ABOUTME: The collaborators row of the list info sheet.
// ABOUTME: Names who can add to the list and opens the picker to change them.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:openvine/widgets/vanished_account_identity.dart';

/// Names the list's collaborators and opens the picker that changes them.
///
/// Inert while the list is private: a private list's items are encrypted to
/// its owner alone, so nobody else could add to it. The picks are kept and
/// come back if the list is made public again before saving.
class ListInfoCollaboratorsRow extends ConsumerWidget {
  /// Creates the collaborators row.
  const ListInfoCollaboratorsRow({super.key});

  Future<void> _pickCollaborators(BuildContext context, WidgetRef ref) async {
    final cubit = context.read<CuratedListInfoCubit>();
    final l10n = context.l10n;
    final viewerPubkey = ref.read(authServiceProvider).currentPublicKeyHex;

    // Only a collaborator whose profile has resolved can be shown as picked.
    final offered = [
      for (final pubkey in cubit.state.collaboratorPubkeys)
        ref.read(userProfileReactiveProvider(pubkey)).value,
    ].nonNulls.toList();

    final picked = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.mutualFollowsOnly,
      title: l10n.listAddCollaboratorTitle,
      searchText: l10n.videoMetadataMutualFollowersSearchText,
      searchHint: l10n.listCollaboratorSearchHint,
      initialSelectedProfiles: offered,
      excludeViewerPubkey: viewerPubkey,
      // Keeps the picker open for more than one pick. The selection is read
      // from its result, so closing it without confirming changes nothing.
      onUserToggled: (_) {},
    );
    if (picked == null) return;

    cubit.collaboratorsPicked(
      offered: {for (final profile in offered) profile.pubkey},
      picked: {for (final profile in picked) profile.pubkey},
      viewerPubkey: viewerPubkey,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final pubkeys = context.select(
      (CuratedListInfoCubit cubit) => cubit.state.savedCollaboratorPubkeys,
    );
    final isEnabled = context.select(
      (CuratedListInfoCubit cubit) =>
          cubit.state.canHaveCollaborators && !cubit.state.isSaving,
    );

    final names = [
      for (final pubkey in pubkeys)
        vanishedAccountName(
          context,
          isVanished: ref.watch(profileVanishedProvider(pubkey)),
          fallbackName:
              ref
                  .watch(userProfileReactiveProvider(pubkey))
                  .value
                  ?.bestDisplayName ??
              UserProfile.defaultDisplayNameFor(pubkey),
        ),
    ].join(l10n.listMemberNamesSeparator);
    final value = pubkeys.isEmpty ? l10n.listCollaboratorsNone : names;

    void open() => runDetached(
      _pickCollaborators(context, ref),
      'pick list collaborators',
      logName: 'ListInfoCollaboratorsRow',
      category: LogCategory.ui,
    );

    return Opacity(
      opacity: isEnabled ? 1 : DivineSwitchTile.disabledOpacity,
      child: Semantics(
        button: true,
        enabled: isEnabled,
        label: l10n.metadataCollaboratorsLabel,
        value: value,
        // excludeSemantics drops the child subtree, the GestureDetector's tap
        // action with it, so the action is declared again here.
        onTap: isEnabled ? open : null,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isEnabled ? open : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  l10n.metadataCollaboratorsLabel,
                  style: VineTheme.labelSmallFont(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Row(
                  spacing: 16,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: VineTheme.titleMediumFont(
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DivineIcon(
                      icon: DivineIconName.caretRight,
                      color: colors.accentPositive,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
