import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';

/// Website field for the profile-setup form.
///
/// Not part of the current design for this screen, so it sits below the form
/// rather than inside it — the field still writes the kind-0 `website` value.
class WebsiteField extends StatelessWidget {
  const WebsiteField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DivineTextField(
      controller: controller,
      labelText: context.l10n.profileSetupWebsiteLabel,
      filled: true,
      fillColor: context.vineColors.surfaceContainer,
      fillBorderRadius: profileFormCardRadius,
      primaryWhenFilled: true,
      textCapitalization: .none,
      keyboardType: TextInputType.url,
      autocorrect: false,
      // Last field in the form, so done dismisses the keyboard rather than
      // moving on. Flutter does that for `done` without an onSubmitted.
      textInputAction: TextInputAction.done,
    );
  }
}
