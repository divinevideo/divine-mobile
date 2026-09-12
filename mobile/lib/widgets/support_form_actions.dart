// ABOUTME: Pinned footer shared by the bug report and feature request forms
// ABOUTME: Failure banner above a cancel/send row, plus success confirmation

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/support_failure_banner.dart';
import 'package:openvine/widgets/support_form_fields.dart';

/// Closes a support form route and confirms on the screen behind it.
///
/// The counterpart of [SupportFailureBanner]: failure keeps the flow open so
/// the form can be retried, success hands the confirmation to the screen below.
/// Resolve [message] and capture the messenger before popping — the current
/// route's context is defunct afterwards.
void closeSupportFlowWithConfirmation(
  BuildContext context, {
  required String message,
}) {
  final messenger = ScaffoldMessenger.of(context);
  context.pop();
  messenger.showSnackBar(DivineSnackbarContainer.snackBar(message));
}

/// Footer of a support form: the reason the last submission failed, when
/// there is one, above a cancel/send row.
///
/// Presentational — the caller maps its cubit's state onto these fields.
/// [fields] is passed whole rather than as a plain `canSubmit` bool because
/// the send button re-reads it inside a [ListenableBuilder] on
/// `fields.requiredFields`; a value captured at the caller's build time would
/// not track typing.
class SupportFormActions extends StatelessWidget {
  const SupportFormActions({
    required this.fields,
    required this.sendLabel,
    required this.isSubmitting,
    required this.onSubmit,
    this.failureMessage,
    super.key,
  });

  final SupportFormFields fields;

  /// Label of the primary action, e.g. "Send report".
  final String sendLabel;

  final bool isSubmitting;
  final VoidCallback onSubmit;

  /// Why the last submission failed, or null while there is nothing to report.
  final String? failureMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          if (failureMessage case final message?)
            SupportFailureBanner(message: message),
          ListenableBuilder(
            listenable: fields.requiredFields,
            builder: (context, _) => Row(
              spacing: 12,
              children: [
                Expanded(
                  child: DivineButton(
                    label: context.l10n.commonCancel,
                    type: DivineButtonType.secondary,
                    onPressed: isSubmitting ? null : context.pop,
                  ),
                ),
                Expanded(
                  child: DivineButton(
                    label: sendLabel,
                    isLoading: isSubmitting,
                    onPressed: fields.canSubmit && !isSubmitting
                        ? onSubmit
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
