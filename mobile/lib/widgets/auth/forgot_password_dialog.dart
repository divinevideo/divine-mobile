// ABOUTME: Shared forgot password dialog for authentication screens
// ABOUTME: StatefulWidget that owns and disposes its TextEditingController

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/validators.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shows a forgot password dialog that sends a reset email.
///
/// [initialEmail] pre-populates the email field.
/// [onSendResetEmail] is called with the validated email address; the sheet
/// stays open while it runs and closes only when it returns `true`. On
/// `false` or a thrown error the sheet shows retry copy instead.
/// [onResetAccepted] fires after the sheet has closed following an accepted
/// reset — never on cancel or dismissal.
void showForgotPasswordDialog({
  required BuildContext context,
  required String initialEmail,
  required Future<bool> Function(String email) onSendResetEmail,
  VoidCallback? onResetAccepted,
}) {
  unawaited(
    VineBottomSheet.show<bool>(
          context: context,
          scrollable: false,
          isDismissible: false,
          enableDrag: false,
          showDragHandle: false,
          title: Text(context.l10n.forgotPasswordTitle),
          body: _ForgotPasswordSheetContent(
            initialEmail: initialEmail,
            onSendResetEmail: onSendResetEmail,
          ),
        )
        .then((wasAccepted) {
          if (wasAccepted ?? false) {
            onResetAccepted?.call();
          }
        })
        .onError<Object>((error, stackTrace) {
          Log.error(
            'Forgot password reset sheet completion failed: $error',
            name: 'ForgotPasswordDialog',
            category: LogCategory.auth,
            stackTrace: stackTrace,
          );
        }),
  );
}

/// Internal sheet content widget that manages its own [TextEditingController].
class _ForgotPasswordSheetContent extends StatefulWidget {
  const _ForgotPasswordSheetContent({
    required this.initialEmail,
    required this.onSendResetEmail,
  });

  final String initialEmail;
  final Future<bool> Function(String email) onSendResetEmail;

  @override
  State<_ForgotPasswordSheetContent> createState() =>
      _ForgotPasswordSheetContentState();
}

class _ForgotPasswordSheetContentState
    extends State<_ForgotPasswordSheetContent> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  var _isSubmitting = false;
  var _sendFailed = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showSendFailure() {
    final message = context.l10n.authFailedToSendResetEmail;
    setState(() {
      _isSubmitting = false;
      _sendFailed = true;
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _sendFailed = false;
    });

    final bool wasAccepted;
    try {
      wasAccepted = await widget.onSendResetEmail(_emailController.text.trim());
    } catch (error, stackTrace) {
      Log.error(
        'Forgot password reset callback failed: $error',
        name: 'ForgotPasswordDialog',
        category: LogCategory.auth,
        stackTrace: stackTrace,
      );
      if (mounted) _showSendFailure();
      return;
    }

    if (!mounted) return;
    if (wasAccepted) {
      context.pop(true);
    } else {
      _showSendFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final validationMessages = AuthValidationMessages.fromL10n(context.l10n);
    return PopScope(
      canPop: !_isSubmitting,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.forgotPasswordDescription,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onChanged: (_) {
                  if (_sendFailed) {
                    setState(() => _sendFailed = false);
                  }
                },
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.primaryText,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.forgotPasswordEmailLabel,
                  labelStyle: VineTheme.bodyLargeFont(
                    color: context.vineColors.mutedText,
                  ),
                  prefixIcon: DivineIcon(
                    icon: DivineIconName.envelope,
                    color: context.vineColors.mutedText,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.vineColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: VineTheme.vineGreen,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) => Validators.validateEmail(
                  value,
                  messages: validationMessages,
                ),
              ),
              if (_sendFailed) ...[
                const SizedBox(height: 16),
                Text(
                  context.l10n.authFailedToSendResetEmail,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onErrorContainer,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => context.pop(),
                    child: Text(
                      context.l10n.forgotPasswordCancel,
                      style: VineTheme.labelLargeFont(
                        color: context.vineColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: context.vineColors.background,
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(
                      _isSubmitting
                          ? context.l10n.authSending
                          : _sendFailed
                          ? context.l10n.authTryAgain
                          : context.l10n.forgotPasswordSendLink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
