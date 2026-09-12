// ABOUTME: Reset password screen for setting a new password via token
// ABOUTME: Dark-themed screen with password field, samoyed sticker, and submit
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=7447-109578

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:unified_logger/unified_logger.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// Route name for navigation
  static const String routeName = 'reset-password';

  /// Path for navigation
  static const String path = RoutePaths.resetPassword;

  const ResetPasswordScreen({required this.token, this.email, super.key});

  final String token;

  /// Account email (optional) — when present, rendered as a read-only field
  /// inside the form's [AutofillGroup] with [AutofillHints.username] so
  /// password managers update the existing credential instead of creating a
  /// new one. See issue #3156.
  final String? email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  TextEditingController? _emailController;

  bool _isLoading = false;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _generalError;

  bool get _hasEmail => widget.email != null && widget.email!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasEmail) {
      _emailController = TextEditingController(text: widget.email);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController?.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final messages = AuthValidationMessages.fromL10n(context.l10n);
    final password = _passwordController.text;
    final passwordError = Validators.validatePassword(
      password,
      messages: messages,
    );
    final confirmPasswordError = Validators.validateConfirmPassword(
      _confirmPasswordController.text,
      password: password,
      messages: messages,
    );
    if (passwordError != null || confirmPasswordError != null) {
      setState(() {
        _passwordError = passwordError;
        _confirmPasswordError = confirmPasswordError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _passwordError = null;
      _confirmPasswordError = null;
      _generalError = null;
    });

    try {
      final oauth = ref.read(oauthClientProvider);

      final result = await oauth.resetPassword(
        token: widget.token,
        newPassword: password,
      );

      if (!mounted) return;

      if (result.success) {
        TextInput.finishAutofillContext();
        if (!mounted) return;
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.authPasswordResetSuccess)),
        );
      } else {
        setState(() {
          _generalError =
              result.message ?? context.l10n.authPasswordResetFailed;
        });
      }
    } catch (e) {
      Log.error(
        'Reset Password error: $e',
        name: 'ResetPasswordScreen',
        category: LogCategory.auth,
      );
      if (mounted) {
        setState(() {
          _generalError = context.l10n.authUnexpectedError;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Back button
                      AuthBackButton(enabled: !_isLoading),

                      const SizedBox(height: 32),

                      // Title
                      Text(
                        context.l10n.authResetPasswordTitle,
                        style: TextStyle(
                          fontFamily: VineTheme.fontFamilyBricolage,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: context.vineColors.primaryText,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        context.l10n.authResetPasswordSubtitle,
                        style: TextStyle(
                          fontSize: 16,
                          color: context.vineColors.secondaryText,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // AutofillGroup + Form enables password manager save
                      // prompts. When the account email is known (passed via
                      // the reset link), render it as a read-only field with
                      // AutofillHints.username so iOS Keychain / Google
                      // Password Manager update the existing credential
                      // rather than creating a duplicate. See #3156.
                      AutofillGroup(
                        child: Form(
                          child: Column(
                            children: [
                              if (_hasEmail) ...[
                                DivineAuthTextField(
                                  controller: _emailController,
                                  label: context.l10n.authEmailLabel,
                                  readOnly: true,
                                  autofillHints: const [
                                    AutofillHints.username,
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                              DivineAuthTextField(
                                controller: _passwordController,
                                label: context.l10n.authNewPasswordLabel,
                                obscureText: true,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                errorText: _passwordError,
                                enabled: !_isLoading,
                                onChanged: (_) {
                                  if (_passwordError != null ||
                                      _confirmPasswordError != null) {
                                    setState(() {
                                      _passwordError = null;
                                      _confirmPasswordError = null;
                                    });
                                  }
                                },
                                textInputAction: TextInputAction.next,
                                showPasswordSemanticLabel:
                                    context.l10n.authShowPassword,
                                hidePasswordSemanticLabel:
                                    context.l10n.authHidePassword,
                              ),
                              const SizedBox(height: 16),
                              DivineAuthTextField(
                                controller: _confirmPasswordController,
                                label: context.l10n.authConfirmNewPasswordLabel,
                                obscureText: true,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                errorText: _confirmPasswordError,
                                enabled: !_isLoading,
                                onChanged: (_) {
                                  if (_confirmPasswordError != null) {
                                    setState(
                                      () => _confirmPasswordError = null,
                                    );
                                  }
                                },
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _handleSubmit(),
                                showPasswordSemanticLabel:
                                    context.l10n.authShowPassword,
                                hidePasswordSemanticLabel:
                                    context.l10n.authHidePassword,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_generalError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _generalError!,
                          style: VineTheme.bodyMediumFont(
                            color: VineTheme.error,
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Samoyed sticker
                      const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: DivineSticker(
                          sticker: DivineStickerName.samoyedDog,
                          size: 160,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Update password button — pinned below the scrollable content.
              DivineButton(
                expanded: true,
                label: context.l10n.authUpdatePassword,
                isLoading: _isLoading,
                onPressed: _handleSubmit,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
