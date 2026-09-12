import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';

/// Longest bio the profile form accepts.
///
/// The limit lives here and nowhere else — neither `ProfileEditorBloc`, the
/// profile repository, nor `UserProfile` constrains `about`, which travels
/// straight into the kind-0 payload. Raising it is a UI decision.
const int bioMaxLength = 1000;

/// Bio field for the profile-setup form, with the character counter Figma
/// draws alongside the label.
class BioField extends StatelessWidget {
  const BioField({required this.controller, this.focusNode, super.key});

  final TextEditingController controller;

  /// Owned by the parent so the username field's next key can land here.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DivineTextField(
          controller: controller,
          focusNode: focusNode,
          labelText: context.l10n.profileSetupBioLabel,
          filled: true,
          fillColor: context.vineColors.surfaceContainer,
          fillBorderRadius: profileFormCardRadius,
          primaryWhenFilled: true,
          textInputAction: .newline,
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 6,
          // Bounded by a formatter rather than `maxLength`, which would also
          // render Material's own counter under the field and duplicate the
          // one drawn beside the label.
          inputFormatters: [
            LengthLimitingTextInputFormatter(bioMaxLength),
          ],
        ),
        Positioned(
          // Aligned to the field's own content padding so a tweak there keeps
          // the counter in step. The -1 lifts the baseline onto the floating
          // label's.
          top: DivineTextField.defaultContentPadding.top - 1,
          right: DivineTextField.defaultContentPadding.right,
          // A readout, not a control: without this the text wins the hit test
          // over the field beneath it, and tapping the field's top-right
          // corner dismissed the keyboard instead of placing the caret.
          child: IgnorePointer(
            child: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, child) => Text(
                '${value.text.length}/$bioMaxLength',
                style: VineTheme.labelSmallFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
