// ABOUTME: Public-submission warning shared by the bug report and feature request flows
// ABOUTME: Sits above the form so the disclosure is read before anything is typed

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Warns that a support submission is published to a public repository.
///
/// Shared rather than duplicated per form: both flows publish to the same
/// place, so the disclosure has to make the same promise on each. Two copies
/// of the text would let one form's wording drift from the other's with
/// nothing to catch it.
class SupportPublicSubmissionNotice extends StatelessWidget {
  const SupportPublicSubmissionNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DivineInfoCard(
      title: l10n.supportPublicSubmissionTitle,
      message: l10n.supportPublicSubmissionMessage,
      tone: DivineInfoCardTone.warning,
      compact: true,
    );
  }
}
