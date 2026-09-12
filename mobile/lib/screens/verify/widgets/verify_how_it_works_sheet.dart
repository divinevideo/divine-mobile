// ABOUTME: Explains what linking an account actually proves, for people who
// ABOUTME: want to know before they hand over a handle.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// The "how does it work" explainer, mirroring the section on
/// verify.divine.video so both surfaces describe the same handshake.
class VerifyHowItWorksSheet extends StatelessWidget {
  /// Creates a [VerifyHowItWorksSheet].
  @visibleForTesting
  const VerifyHowItWorksSheet({super.key});

  /// Opens the explainer.
  static Future<void> show(BuildContext context) {
    return VineBottomSheet.show<void>(
      context: context,
      contentTitle: context.l10n.verifyHowItWorksTitle,
      scrollable: false,
      body: const VerifyHowItWorksSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          _Paragraph(l10n.verifyHowItWorksIntro),
          _HandshakeSide(l10n.verifyHowItWorksYourSide),
          _HandshakeSide(l10n.verifyHowItWorksOtherSide),
          _Paragraph(l10n.verifyHowItWorksBothSides),
          _Paragraph(l10n.verifyHowItWorksOwnership),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
    );
  }
}

/// One half of the handshake, marked so the two read as a pair rather than as
/// more prose.
class _HandshakeSide extends StatelessWidget {
  const _HandshakeSide(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: DivineIcon(
            icon: DivineIconName.check,
            size: 16,
            color: VineTheme.primary,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}
