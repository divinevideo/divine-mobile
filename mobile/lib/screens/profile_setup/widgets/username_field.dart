import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';

/// The Divine handle field.
///
/// The field renders `@name`, matching the product handle users expect.
///
/// Note this is display only — the controller holds the bare handle and that
/// is what gets claimed. The registry still issues the underlying
/// `_@<handle>.divine.video` NIP-05 subdomain form.
///
/// Disabled while the profile points at an external NIP-05: the two are
/// alternatives, and the external address is edited on its own screen.
class UsernameField extends StatelessWidget {
  const UsernameField({
    required this.controller,
    required this.nextFocusNode,
    super.key,
  });

  final TextEditingController controller;

  /// Focused when the keyboard's next key is pressed.
  ///
  /// Targeted rather than left to `nextFocus()`: the NIP-05 card sits between
  /// this field and the bio in traversal order, and it takes focus without
  /// bringing a keyboard — so next appeared to do nothing but dismiss it.
  final FocusNode nextFocusNode;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
      buildWhen: (prev, curr) => prev.nip05Mode != curr.nip05Mode,
      builder: (context, editorState) {
        final isExternal = editorState.nip05Mode == Nip05Mode.external_;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DivineTextField(
              controller: controller,
              enabled: !isExternal,
              labelText: context.l10n.profileSetupUsernameLabel,
              filled: true,
              fillColor: context.vineColors.surfaceContainer,
              fillBorderRadius: profileFormCardRadius,
              primaryWhenFilled: true,
              prefixText: '@',
              textCapitalization: .none,
              textInputAction: TextInputAction.next,
              // Replaces the default next-focus walk rather than running after
              // it, so focus lands on the bio in one hop.
              onEditingComplete: () {
                controller.clearComposing();
                nextFocusNode.requestFocus();
              },
              onChanged: (value) =>
                  context.read<ProfileEditorBloc>().add(UsernameChanged(value)),
              // Lowercase as the user types. The name server stores and resolves
              // usernames as lowercase, so normalizing here avoids a confusing
              // "invalid format" error for a typed capital letter. Invalid
              // characters remain visible so validation can explain the rule.
              inputFormatters: const [LowercaseTextInputFormatter()],
            ),
            ProfileFieldSupportingText(context.l10n.profileSetupUsernameHelper),
            if (!isExternal)
              BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
                builder: (context, state) => UsernameStatusIndicator(
                  status: state.usernameStatus,
                  error: state.usernameError,
                ),
              ),
          ],
        );
      },
    );
  }
}
