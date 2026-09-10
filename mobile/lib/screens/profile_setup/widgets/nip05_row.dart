import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';

/// Entry point to the external NIP-05 flow.
///
/// The username field above claims a divine.video handle; this row is for
/// pointing the profile at a NIP-05 address on a domain the user controls.
/// Both live on [Nip05SettingsScreen], which already owns the mode switch and
/// its confirmation step.
class Nip05Row extends StatelessWidget {
  /// Creates the NIP-05 row.
  const Nip05Row({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSelectRow(
      label: context.l10n.profileSetupUseOwnNip05,
      onTap: () => context.pushNamed(Nip05SettingsScreen.routeName),
    );
  }
}
