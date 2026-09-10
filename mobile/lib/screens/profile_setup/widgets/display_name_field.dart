import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';

/// Display-name field for the profile-setup form.
///
/// The [focusNode] is owned by the parent so the Save action can focus this
/// field when the name is left empty.
class DisplayNameField extends StatelessWidget {
  const DisplayNameField({
    required this.controller,
    required this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    // No supporting text: the design gives this card the plain 76px height,
    // with the floating label doing the placeholder's job.
    return DivineTextField(
      controller: controller,
      focusNode: focusNode,
      labelText: context.l10n.profileSetupDisplayNameLabel,
      filled: true,
      fillColor: context.vineColors.surfaceContainer,
      fillBorderRadius: profileFormCardRadius,
      primaryWhenFilled: true,
      // No onSubmitted: TextInputAction.next already advances the focus, and
      // advancing again on submit skipped a field — landing on the NIP-05 card,
      // which has no keyboard, so the keyboard just closed.
      textInputAction: TextInputAction.next,
    );
  }
}
