// ABOUTME: One row of a people list's roster: avatar, name and handle. A tap
// ABOUTME: opens the profile; the list's owner can long-press to remove.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/people_list_member_avatar.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

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

    if (shouldRemove != true || !context.mounted) return;

    final bloc = context.read<PeopleListsBloc>()
      ..add(PeopleListsPubkeyRemoveRequested(listId: listId, pubkey: pubkey));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.peopleListsRemovedFromList(displayName)),
        action: SnackBarAction(
          label: l10n.peopleListsUndo,
          onPressed: () => bloc.add(
            PeopleListsPubkeyAddRequested(listId: listId, pubkey: pubkey),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey);
    final npub = NostrKeyUtils.encodePubKey(pubkey);
    final handle = profile?.shortDisplayNip05 ?? npub;

    return Semantics(
      button: true,
      label: canRemove
          ? l10n.peopleListsProfileLongPressHint(displayName)
          : l10n.peopleListsViewProfileHint(displayName),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(OtherProfileScreen.pathForNpub(npub)),
        onLongPress: canRemove
            ? () => _confirmRemove(context, displayName)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            spacing: 16,
            children: [
              ExcludeSemantics(
                child: PeopleListMemberAvatar(
                  pubkey: pubkey,
                  pictureUrl: profile?.picture,
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
