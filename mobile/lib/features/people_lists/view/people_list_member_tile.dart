// ABOUTME: One row of a people list's roster: avatar, name and handle. A tap
// ABOUTME: opens the profile; the list's owner can long-press to remove.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/people_list_member_avatar.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/vanished_account_identity.dart';

/// A member row: the design's avatar, name and "npub or NIP-05" handle.
///
/// [canRemove] is the owner's affordance — a long-press asks before
/// removing the member, with an undo on the confirmation snackbar.
class PeopleListMemberTile extends ConsumerWidget {
  const PeopleListMemberTile({
    required this.pubkey,
    required this.listId,
    required this.canRemove,
    super.key,
  });

  final String pubkey;
  final String listId;
  final bool canRemove;

  Future<void> _confirmRemove(BuildContext context, String displayName) async {
    final l10n = context.l10n;
    final bloc = context.read<PeopleListsBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final owner = bloc.state.activeOwnerPubkey;
    final shouldRemove = await context.showVideoPausingVineBottomSheet<bool>(
      scrollable: false,
      showHeaderDivider: false,
      body: Builder(
        builder: (sheetContext) => VineBottomSheetPrompt(
          sticker: DivineStickerName.profile,
          title: sheetContext.l10n.peopleListsRemoveConfirmTitle(displayName),
          subtitle: sheetContext.l10n.peopleListsRemoveConfirmBody,
          primaryButtonText: sheetContext.l10n.peopleListsRemove,
          onPrimaryPressed: () => sheetContext.popModalIfMounted(true),
          secondaryButtonText: sheetContext.l10n.commonCancel,
          onSecondaryPressed: () => sheetContext.popModalIfMounted(false),
        ),
      ),
    );

    // The roster can scroll or re-rank behind the sheet and dispose this row;
    // the owner's confirmation still stands.
    if (shouldRemove != true) return;

    Future<void> publish({required bool remove}) async {
      if (!messenger.mounted) return;
      if (owner == null || owner != bloc.state.activeOwnerPubkey) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.peopleListsSessionChanged)),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileSetupSavingButton)),
      );
      final result = await bloc.submit(
        remove
            ? PeopleListsPubkeyRemoveRequested(listId: listId, pubkey: pubkey)
            : PeopleListsPubkeyAddRequested(listId: listId, pubkey: pubkey),
      );
      if (!messenger.mounted) return;
      // A retry action may still be dismissing its old snackbar while the
      // next result arrives. Remove queued progress before showing the result.
      messenger
        ..clearSnackBars()
        ..removeCurrentSnackBar();
      if (result == PeopleListsOperationResult.cancelled) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.peopleListsSessionChanged)),
        );
      } else if (result == PeopleListsOperationResult.failed) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.listUpdateFailed),
            action: SnackBarAction(
              label: l10n.peopleListsAddPeopleRetry,
              onPressed: () => publish(remove: remove),
            ),
          ),
        );
      } else if (remove) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.peopleListsRemovedFromList(displayName)),
            action: SnackBarAction(
              label: l10n.peopleListsUndo,
              onPressed: () => publish(remove: false),
            ),
          ),
        );
      }
    }

    await publish(remove: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    final isVanished = ref.watch(profileVanishedProvider(pubkey));
    final displayName = vanishedAccountName(
      context,
      isVanished: isVanished,
      fallbackName:
          profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey),
    );
    final validPubkey = NostrKeyUtils.isValidKey(pubkey);
    final npub = validPubkey ? NostrKeyUtils.encodePubKey(pubkey) : pubkey;
    final verification = ref.watch(nip05VerificationProvider(pubkey)).value;
    final handle = verification == Nip05VerificationStatus.failed
        ? npub
        : (profile?.shortDisplayNip05 ?? npub);
    final onTap = validPubkey
        ? () => runDetached(
            context.push<void>(OtherProfileScreen.pathForNpub(npub)),
            'open people list member profile',
            logName: 'PeopleListMemberTile',
            category: LogCategory.ui,
          )
        : null;
    final onLongPress = canRemove
        ? () => _confirmRemove(context, displayName)
        : null;

    return Semantics(
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      label: canRemove
          ? l10n.peopleListsProfileLongPressHint(displayName)
          : l10n.peopleListsViewProfileHint(displayName),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            spacing: 16,
            children: [
              ExcludeSemantics(
                child: PeopleListMemberAvatar(
                  pubkey: pubkey,
                  pictureUrl: vanishedAccountPictureUrl(
                    isVanished: isVanished,
                    pictureUrl: profile?.picture,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isVanished)
                      Text(
                        handle,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
