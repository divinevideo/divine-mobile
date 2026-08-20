// ABOUTME: Shared scaffold layout for auth form screens (create account,
// ABOUTME: secure account). Owns the email/password DivineAuthTextFields
// ABOUTME: internally to guarantee consistency between forms.
// Figma: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=6560-62187

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// A shared scaffold layout for authentication form screens.
///
/// Provides the standard dark-background layout with:
/// - [AuthBackButton] at the top
/// - Title text
/// - Email and password [DivineAuthTextField] fields (built internally)
/// - Dog sticker (right-aligned, rotated)
/// - Optional error widget
/// - Primary and optional secondary button slots pushed to bottom
///
/// The email and password fields are constructed internally with shared
/// configuration (labels, keyboard type, autofill hints) to prevent
/// drift between CreateAccountScreen and SecureAccountScreen. Each screen
/// passes controllers, error strings, and onChanged callbacks for the
/// parts that differ.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    required this.title,
    required this.emailController,
    required this.passwordController,
    required this.primaryButton,
    super.key,
    this.confirmPasswordController,
    this.emailError,
    this.passwordError,
    this.confirmPasswordError,
    this.enabled = true,
    this.onEmailChanged,
    this.onPasswordChanged,
    this.onConfirmPasswordChanged,
    this.errorWidget,
    this.headerWidget,
    this.belowFieldsWidget,
    this.secondaryButton,
    this.onBack,
    this.emailLabel = 'Email',
    this.passwordLabel = 'Password',
    this.confirmPasswordLabel = 'Confirm password',
  });

  /// The title displayed below the back button.
  final String title;

  /// Controller for the email text field.
  final TextEditingController emailController;

  /// Controller for the password text field.
  final TextEditingController passwordController;

  /// Controller for the confirm-password text field. When null, no
  /// confirmation field is rendered.
  final TextEditingController? confirmPasswordController;

  /// Error message for the email field (null = no error).
  final String? emailError;

  /// Error message for the password field (null = no error).
  final String? passwordError;

  /// Error message for the confirm password field (null = no error).
  final String? confirmPasswordError;

  /// Whether the form fields are enabled.
  final bool enabled;

  /// Called when the email field text changes.
  final ValueChanged<String>? onEmailChanged;

  /// Called when the password field text changes.
  final ValueChanged<String>? onPasswordChanged;

  /// Called when the confirm password field text changes.
  final ValueChanged<String>? onConfirmPasswordChanged;

  /// Optional error widget displayed below the dog sticker.
  final Widget? errorWidget;

  /// Optional content displayed between the title and form fields.
  final Widget? headerWidget;

  /// Optional content displayed directly below the form fields (e.g. a
  /// marketing opt-in checkbox on the create-account form).
  final Widget? belowFieldsWidget;

  /// The primary action button (e.g. "Create account").
  final Widget primaryButton;

  /// Optional secondary action button (e.g. "Skip for now").
  final Widget? secondaryButton;

  /// Custom back button callback. Defaults to [AuthBackButton]'s safe back
  /// behavior.
  final VoidCallback? onBack;

  /// Label for the email field.
  final String emailLabel;

  /// Label for the password field.
  final String passwordLabel;

  /// Label for the optional confirm-password field.
  final String confirmPasswordLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // Back button
                          AuthBackButton(onPressed: onBack),

                          const SizedBox(height: 32),

                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: VineTheme.fontFamilyBricolage,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: context.vineColors.primaryText,
                            ),
                          ),

                          if (headerWidget != null) ...[
                            const SizedBox(height: 12),
                            headerWidget!,
                            const SizedBox(height: 24),
                          ] else
                            const SizedBox(height: 32),

                          // AutofillGroup + Form enables password manager
                          // autofill for the email and password fields.
                          AutofillGroup(
                            child: Form(
                              child: Column(
                                children: [
                                  // Email field
                                  DivineAuthTextField(
                                    controller: emailController,
                                    label: emailLabel,
                                    keyboardType: TextInputType.emailAddress,
                                    errorText: emailError,
                                    enabled: enabled,
                                    autocorrect: false,
                                    autofillHints: const [
                                      AutofillHints.email,
                                    ],
                                    onChanged: onEmailChanged,
                                  ),

                                  const SizedBox(height: 16),

                                  // Password field
                                  DivineAuthTextField(
                                    controller: passwordController,
                                    label: passwordLabel,
                                    obscureText: true,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    errorText: passwordError,
                                    enabled: enabled,
                                    onChanged: onPasswordChanged,
                                    showPasswordSemanticLabel:
                                        context.l10n.authShowPassword,
                                    hidePasswordSemanticLabel:
                                        context.l10n.authHidePassword,
                                  ),

                                  if (confirmPasswordController != null) ...[
                                    const SizedBox(height: 16),
                                    DivineAuthTextField(
                                      controller: confirmPasswordController,
                                      label: confirmPasswordLabel,
                                      obscureText: true,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      errorText: confirmPasswordError,
                                      enabled: enabled,
                                      onChanged: onConfirmPasswordChanged,
                                      showPasswordSemanticLabel:
                                          context.l10n.authShowPassword,
                                      hidePasswordSemanticLabel:
                                          context.l10n.authHidePassword,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          if (belowFieldsWidget != null) ...[
                            const SizedBox(height: 16),
                            belowFieldsWidget!,
                          ],

                          const SizedBox(height: 16),

                          // Dog sticker
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Transform.translate(
                              offset: const Offset(20, 0),
                              child: Transform.rotate(
                                angle: 12 * pi / 180,
                                child: SvgPicture.asset(
                                  'assets/stickers/samoyed_dog.svg',
                                  width: 174,
                                  height: 174,
                                ),
                              ),
                            ),
                          ),

                          // Error display
                          if (errorWidget != null) ...[
                            const SizedBox(height: 16),
                            errorWidget!,
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Primary button
              primaryButton,

              // Secondary button (optional)
              if (secondaryButton != null) ...[
                const SizedBox(height: 12),
                secondaryButton!,
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
