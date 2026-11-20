// ABOUTME: Lets a creator see and edit an invite message before sharing it.
// ABOUTME: The Divine download link is always added on its own line.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/creator_highlights/invite_friends_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// Opened from the daily highlight's "Bring your friends" link.
class InviteFriendsScreen extends StatelessWidget {
  const InviteFriendsScreen({super.key});

  static const routeName = 'invite-friends';
  static const String path = RoutePaths.inviteFriends;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => InviteFriendsCubit(),
    child: const _InviteFriendsView(),
  );
}

class _InviteFriendsView extends StatefulWidget {
  const _InviteFriendsView();

  @override
  State<_InviteFriendsView> createState() => _InviteFriendsViewState();
}

class _InviteFriendsViewState extends State<_InviteFriendsView> {
  final _message = TextEditingController();
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    _message.text = context.l10n.inviteFriendsDefaultMessage;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _share(BuildContext buttonContext) {
    // Resolve the iPad anchor now, while the button is mounted.
    final origin = shareAnchorForContext(buttonContext);
    runDetached(
      context.read<InviteFriendsCubit>().share(
        _message.text,
        AppConstants.downloadUrl,
        (text) async {
          final result = await showShareSheetAtOrigin(
            ShareParams(text: text),
            sharePositionOrigin: origin,
          );
          return switch (result.status) {
            ShareResultStatus.success => InviteShareOutcome.shared,
            ShareResultStatus.dismissed => InviteShareOutcome.dismissed,
            ShareResultStatus.unavailable => InviteShareOutcome.unknown,
          };
        },
      ),
      'share invite',
      logName: 'InviteFriendsScreen',
      category: LogCategory.ui,
    );
  }

  // A link or reload can open this page with nothing below it to go back to.
  void _leave() => context.safePop(fallback: RoutePaths.inbox);

  void _onStatus(BuildContext context, InviteFriendsState state) {
    switch (state.status) {
      case InviteShareStatus.shared:
        // Never pop a route that arrived while the sheet was up.
        if (ModalRoute.of(context)?.isCurrent ?? false) _leave();
      case InviteShareStatus.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.inviteFriendsShareFailed,
            error: true,
          ),
        );
      case InviteShareStatus.idle:
      case InviteShareStatus.sharing:
        // Nothing to do: the button reflects these.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return BlocListener<InviteFriendsCubit, InviteFriendsState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onStatus,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: DiVineAppBar(
          title: l10n.inviteFriendsTitle,
          showBackButton: true,
          onBackPressed: _leave,
          backButtonSemanticLabel: l10n.commonBack,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            // A multiline field has no done key; dragging puts it away.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              DivineTextField(
                controller: _message,
                labelText: l10n.inviteFriendsMessageLabel,
                filled: true,
                fillColor: colors.surfaceContainer,
                keyboardType: TextInputType.multiline,
                textInputAction: .newline,
                minLines: 3,
                maxLines: 6,
              ),
              // Its own text rather than the field's helper, which a field
              // limits to one line and would cut the link off.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  DivineTextField.defaultContentPadding.left,
                  8,
                  DivineTextField.defaultContentPadding.right,
                  0,
                ),
                child: Text(
                  l10n.inviteFriendsLinkNote(AppConstants.downloadUrl),
                  style: VineTheme.bodySmallFont(color: colors.secondaryText),
                ),
              ),
              const SizedBox(height: 24),
              BlocSelector<InviteFriendsCubit, InviteFriendsState, bool>(
                selector: (state) => state.status == InviteShareStatus.sharing,
                builder: (buttonContext, sharing) => DivineButton(
                  label: l10n.inviteFriendsShare,
                  expanded: true,
                  onPressed: sharing ? null : () => _share(buttonContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
