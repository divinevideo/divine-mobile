// ABOUTME: Lets a creator see and edit an invite message before sharing it.
// ABOUTME: The Divine download link is always added on its own line.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:openvine/utils/share_sheet.dart';

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
  // Seeded once from the current locale's default message.
  TextEditingController? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _message ??= TextEditingController(
      text: context.l10n.inviteFriendsDefaultMessage,
    );
  }

  @override
  void dispose() {
    _message?.dispose();
    super.dispose();
  }

  Future<void> _share(BuildContext buttonContext) async {
    // Resolve the iPad anchor before awaiting, while the button is mounted.
    final origin = shareAnchorForContext(buttonContext);
    final result = await showShareSheetAtOrigin(
      ShareParams(
        text: inviteShareText(_message!.text, AppConstants.downloadUrl),
      ),
      sharePositionOrigin: origin,
    );
    // A dismissed sheet keeps the page open to try again. When the platform
    // cannot say what happened, assume the share went through.
    if (result.status == ShareResultStatus.dismissed || !mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: DiVineAppBar(
        title: l10n.inviteFriendsTitle,
        showBackButton: true,
        backButtonSemanticLabel: l10n.commonBack,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DivineTextField(
              controller: _message,
              labelText: l10n.inviteFriendsMessageLabel,
              helperText: l10n.inviteFriendsLinkNote(AppConstants.downloadUrl),
              helperMaxLines: 3,
              filled: true,
              fillColor: colors.surfaceContainer,
              keyboardType: TextInputType.multiline,
              textInputAction: .newline,
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (buttonContext) => DivineButton(
                label: l10n.inviteFriendsShare,
                expanded: true,
                onPressed: () => _share(buttonContext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
