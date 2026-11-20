// ABOUTME: Lets a creator see and edit an invite message before sharing it.
// ABOUTME: The Divine download link is always added on its own line.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// The text shared for an invite: the message, then [url] on its own line.
///
/// A blank message shares only [url], so the invite still works.
String inviteShareText(String message, String url) {
  final trimmed = message.trim();
  return trimmed.isEmpty ? url : '$trimmed\n$url';
}

/// Opened from the daily highlight's "Bring your friends" link.
class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  static const routeName = 'invite-friends';
  static const String path = RoutePaths.inviteFriends;

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  final _message = TextEditingController();
  bool _seeded = false;
  // True while the share sheet is open, so a second tap cannot start another.
  bool _sharing = false;

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

  Future<void> _share(BuildContext buttonContext) async {
    // Two taps can land before the disabled button is rebuilt.
    if (_sharing) return;
    // Resolve the iPad anchor before awaiting, while the button is mounted.
    final origin = shareAnchorForContext(buttonContext);
    setState(() => _sharing = true);
    final ShareResult result;
    try {
      result = await showShareSheetAtOrigin(
        ShareParams(
          text: inviteShareText(_message.text, AppConstants.downloadUrl),
        ),
        sharePositionOrigin: origin,
      );
    } on PlatformException catch (error, stackTrace) {
      // The person can simply try again; nothing was sent.
      Log.warning(
        'Invite share failed',
        name: 'InviteFriendsScreen',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.inviteFriendsShareFailed,
          error: true,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _sharing = false);
    // A dismissed sheet keeps the page open to try again. When the platform
    // cannot say what happened, assume the share went through. Pop only while
    // this page is on top, never a route that arrived while the sheet was up.
    if (result.status == ShareResultStatus.dismissed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _leave();
  }

  // A link or reload can open this page with nothing below it to go back to.
  void _leave() => context.safePop(fallback: RoutePaths.inbox);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return Scaffold(
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
          // A multiline field has no done key; dragging puts the keyboard away.
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
            Builder(
              builder: (buttonContext) => DivineButton(
                label: l10n.inviteFriendsShare,
                expanded: true,
                onPressed: _sharing ? null : () => _share(buttonContext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
