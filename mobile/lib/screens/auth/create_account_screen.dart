// ABOUTME: Create account screen with email/password registration form
// ABOUTME: Provides DivineAuthCubit in sign-up mode
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=7391-55983

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth/auth_form_scaffold.dart';

/// Create account screen — Page that provides [DivineAuthCubit] in sign-up
/// mode.
class CreateAccountScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const String routeName = 'create-account';

  /// Route path for this screen (relative, under /welcome).
  static const String path = '/create-account';

  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  @override
  void initState() {
    super.initState();
    // Recorded once from initState: firing an analytics call (which enqueues
    // a row and kicks a network flush) from build() would rerun on every
    // rebuild, including build passes Flutter discards.
    final inviteAccessGrant = context.read<InviteGateBloc>().state.accessGrant;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .recordRegistrationStarted(
            entryPoint: inviteAccessGrant == null
                ? ProductAnalyticsV2RegistrationEntryPoint.landing
                : ProductAnalyticsV2RegistrationEntryPoint.invite,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final oauthClient = ref.watch(oauthClientProvider);
    final authService = ref.watch(authServiceProvider);
    final pendingVerificationService = ref.watch(
      pendingVerificationServiceProvider,
    );
    final inviteApiClient = context.read<InviteApiClient>();
    final inviteAccessGrant = context.read<InviteGateBloc>().state.accessGrant;

    return BlocProvider(
      create: (_) => DivineAuthCubit(
        oauthClient: oauthClient,
        authService: authService,
        pendingVerificationService: pendingVerificationService,
        inviteApiClient: inviteApiClient,
        inviteCode: inviteAccessGrant?.code,
        inviteSourceSlug: inviteAccessGrant?.creatorSlug,
        validationMessages: AuthValidationMessages.fromL10n(l10n),
        requirePasswordConfirmation: true,
        analytics: ref.read(analyticsEventSinkProvider),
      )..initialize(),
      child: _CreateAccountView(inviteAccessGrant: inviteAccessGrant),
    );
  }
}

/// Create account screen — View that consumes [DivineAuthCubit] state.
class _CreateAccountView extends StatelessWidget {
  const _CreateAccountView({this.inviteAccessGrant});

  final InviteAccessGrant? inviteAccessGrant;

  @override
  Widget build(BuildContext context) {
    return BlocListener<DivineAuthCubit, DivineAuthState>(
      listenWhen: (prev, next) =>
          next is DivineAuthEmailVerification ||
          next is DivineAuthFormState && next.showLoginOptionsRecovery,
      listener: (context, state) {
        if (state is DivineAuthFormState && state.showLoginOptionsRecovery) {
          context.go(
            WelcomeScreen.loginOptionsPathWithRecovery(
              email: state.email,
              error: state.generalError,
            ),
          );
          return;
        }
        if (state is DivineAuthEmailVerification) {
          TextInput.finishAutofillContext();
          final encodedEmail = Uri.encodeComponent(state.email);
          context.go(
            '${EmailVerificationScreen.path}'
            '?deviceCode=${state.deviceCode}'
            '&verifier=${state.verifier}'
            '&email=$encodedEmail',
          );
        }
      },
      child: BlocBuilder<DivineAuthCubit, DivineAuthState>(
        builder: (context, state) {
          if (state is DivineAuthFormState) {
            return _CreateAccountBody(
              state: state,
              inviteAccessGrant: inviteAccessGrant,
            );
          }
          return Scaffold(
            backgroundColor: context.vineColors.background,
            body: Center(
              child: DivineCircularProgressIndicator(
                color: context.vineColors.accentPositive,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Body of the create account form with email and password.
class _CreateAccountBody extends StatefulWidget {
  const _CreateAccountBody({required this.state, this.inviteAccessGrant});

  final DivineAuthFormState state;
  final InviteAccessGrant? inviteAccessGrant;

  @override
  State<_CreateAccountBody> createState() => _CreateAccountBodyState();
}

class _CreateAccountBodyState extends State<_CreateAccountBody> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.state.email);
    _passwordController = TextEditingController(text: widget.state.password);
    _confirmPasswordController = TextEditingController(
      text: widget.state.confirmPassword,
    );
  }

  @override
  void didUpdateWidget(covariant _CreateAccountBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_emailController.text != widget.state.email) {
      _emailController.text = widget.state.email;
    }
    if (_passwordController.text != widget.state.password) {
      _passwordController.text = widget.state.password;
    }
    if (_confirmPasswordController.text != widget.state.confirmPassword) {
      _confirmPasswordController.text = widget.state.confirmPassword;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<DivineAuthCubit>().submit();
  }

  Future<void> _skip() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.vineColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SkipConfirmationSheet(),
    );

    if (confirmed != true || !mounted) return;

    context.read<DivineAuthCubit>().skipWithAnonymousAccount();
  }

  void _returnToInviteGate() {
    final inviteCode = widget.state.inviteRecoveryCode;
    if (inviteCode == null) {
      return;
    }

    context.read<InviteGateBloc>().add(const InviteGateAccessCleared());
    context.go(
      WelcomeScreen.inviteGatePathWithCode(
        inviteCode,
        error: widget.state.generalError,
        sourceSlug: widget.state.inviteRecoverySourceSlug,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = widget.state.isSubmitting;
    final isSkipping = widget.state.isSkipping;
    final isDisabled = isSubmitting || isSkipping;
    final inviteGrant = widget.inviteAccessGrant;
    final hasCreatorContext =
        (inviteGrant?.creatorDisplayName?.isNotEmpty ?? false) ||
        inviteGrant?.remaining != null;

    return AuthFormScaffold(
      title: context.l10n.authCreateAccountTitle,
      headerWidget: hasCreatorContext
          ? _CreatorInviteContext(grant: inviteGrant)
          : null,
      onBack: isDisabled ? null : () => context.pop(),
      emailController: _emailController,
      passwordController: _passwordController,
      confirmPasswordController: _confirmPasswordController,
      emailLabel: context.l10n.authEmailLabel,
      passwordLabel: context.l10n.authPasswordLabel,
      confirmPasswordLabel: context.l10n.authConfirmPasswordLabel,
      emailError: widget.state.emailError,
      passwordError: widget.state.passwordError,
      confirmPasswordError: widget.state.confirmPasswordError,
      enabled: !isDisabled,
      onEmailChanged: (value) =>
          context.read<DivineAuthCubit>().updateEmail(value),
      onPasswordChanged: (value) =>
          context.read<DivineAuthCubit>().updatePassword(value),
      onConfirmPasswordChanged: (value) =>
          context.read<DivineAuthCubit>().updateConfirmPassword(value),
      errorWidget: widget.state.generalError != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuthErrorBox(message: widget.state.generalError!),
                if (widget.state.showInviteGateRecovery &&
                    widget.state.inviteRecoveryCode != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: isDisabled ? null : _returnToInviteGate,
                      child: Text(context.l10n.authBackToInviteCode),
                    ),
                  ),
                ],
              ],
            )
          : null,
      primaryButton: DivineButton(
        expanded: true,
        label: context.l10n.authCreateAccountTitle,
        isLoading: isSubmitting,
        onPressed: isDisabled ? null : _submit,
      ),
      secondaryButton: _SkipButton(
        isSkipping: isSkipping,
        isDisabled: isDisabled,
        onPressed: _skip,
      ),
    );
  }
}

class _CreatorInviteContext extends StatelessWidget {
  const _CreatorInviteContext({this.grant});

  final InviteAccessGrant? grant;

  @override
  Widget build(BuildContext context) {
    final displayName = grant?.creatorDisplayName;
    final remaining = grant?.remaining;
    if ((displayName == null || displayName.isEmpty) && remaining == null) {
      return const SizedBox.shrink();
    }

    final lines = <String>[
      if (displayName != null && displayName.isNotEmpty)
        '$displayName invited you',
      if (remaining != null) '$remaining invites left',
    ];

    return Text(
      lines.join('\n'),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        height: 1.4,
        color: context.vineColors.mutedText,
      ),
    );
  }
}

/// Skip button for users who want anonymous keys.
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.isSkipping,
    required this.isDisabled,
    required this.onPressed,
  });

  final bool isSkipping;
  final bool isDisabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: isDisabled ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: context.vineColors.secondaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: isSkipping
            ? SizedBox(
                height: 18,
                width: 18,
                child: DivineCircularProgressIndicator(
                  color: context.vineColors.secondaryText,
                  strokeWidth: 2,
                ),
              )
            : Text(
                context.l10n.authUseDivineNoBackup,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

/// Bottom sheet asking the user to confirm skipping email/password setup.
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=6872-22358
class _SkipConfirmationSheet extends StatelessWidget {
  const _SkipConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: .fromLTRB(
        24,
        24,
        24,
        32 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.vineColors.outlineMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          SvgPicture.asset(
            'assets/stickers/pointing_finger.svg',
            width: 132,
            height: 132,
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            context.l10n.authSkipConfirmTitle,
            style: TextStyle(
              fontFamily: VineTheme.fontFamilyBricolage,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            context.l10n.authSkipConfirmKeyCreated,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: context.vineColors.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.authSkipConfirmKeyOnly,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: context.vineColors.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.authSkipConfirmRecommendEmail,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: context.vineColors.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Add email & password button
          DivineButton(
            expanded: true,
            label: context.l10n.authAddEmailPassword,
            onPressed: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 12),

          // Use this device only button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: context.vineColors.secondaryText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                context.l10n.authUseThisDeviceOnly,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
