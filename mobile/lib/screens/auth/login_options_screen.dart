// ABOUTME: Sign-in screen with email/password form and alternative Nostr methods
// ABOUTME: Options: Email sign-in, Import Nostr Key, Signer App, or Amber
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=5061-65986

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show AndroidPlugin;
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth/forgot_password_dialog.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';

/// Sign-in screen — Page that provides [DivineAuthCubit].
class LoginOptionsScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const String routeName = 'login-options';

  /// Route path for this screen.
  static const String path = '/login-options';

  const LoginOptionsScreen({this.initialEmail, this.initialError, super.key});

  /// Optional email to prefill from create-account recovery.
  final String? initialEmail;

  /// Optional error to display when arriving from create-account recovery.
  final String? initialError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final oauthClient = ref.watch(oauthClientProvider);
    final authService = ref.watch(authServiceProvider);
    final pendingVerificationService = ref.watch(
      pendingVerificationServiceProvider,
    );

    return BlocProvider(
      create: (_) =>
          DivineAuthCubit(
            oauthClient: oauthClient,
            authService: authService,
            pendingVerificationService: pendingVerificationService,
            validationMessages: AuthValidationMessages.fromL10n(l10n),
            analytics: ref.read(analyticsEventSinkProvider),
          )..initialize(
            isSignIn: true,
            initialEmail: initialEmail,
            initialGeneralError: initialError,
          ),
      child: _CommitAutofillOnAuthenticated(
        // Re-sample the flag on each auth event rather than passing the
        // service's own state enum through, so this screen stays clear of
        // service-layer types (scripts/check_ui_service_boundary.sh).
        authenticated: authService.authStateStream.map(
          (_) => authService.isAuthenticated,
        ),
        child: const _LoginOptionsView(),
      ),
    );
  }
}

/// Commits the autofill context off the auth-state signal rather than off
/// [DivineAuthSuccess].
///
/// A successful sign-in flips `AuthService` to authenticated, which refreshes
/// the router and closes [DivineAuthCubit] before `_handleSignIn` reaches its
/// emit. Listening for [DivineAuthSuccess] therefore misses the password-manager
/// save prompt whenever the redirect wins that race. This listens to the same
/// stream `RouterRefreshListenable` uses, and stream events are delivered before
/// the frame that disposes this subtree.
class _CommitAutofillOnAuthenticated extends StatefulWidget {
  const _CommitAutofillOnAuthenticated({
    required this.authenticated,
    required this.child,
  });

  /// Emits the session's authenticated flag on every auth-state change.
  final Stream<bool> authenticated;
  final Widget child;

  @override
  State<_CommitAutofillOnAuthenticated> createState() =>
      _CommitAutofillOnAuthenticatedState();
}

class _CommitAutofillOnAuthenticatedState
    extends State<_CommitAutofillOnAuthenticated> {
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.authenticated.listen(_onAuthenticatedChanged);
  }

  void _onAuthenticatedChanged(bool isAuthenticated) {
    if (!isAuthenticated) return;
    // Only the email/password form has credentials worth saving; the other
    // sign-in methods on this screen leave the autofill context empty.
    if (!_hasSubmittedCredentials) return;
    TextInput.finishAutofillContext();
  }

  bool get _hasSubmittedCredentials {
    final state = context.read<DivineAuthCubit>().state;
    return state is DivineAuthFormState && state.isSubmitting;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Sign-in screen — View that consumes [DivineAuthCubit] state.
class _LoginOptionsView extends StatelessWidget {
  const _LoginOptionsView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<DivineAuthCubit, DivineAuthState>(
      listenWhen: (prev, next) =>
          next is DivineAuthEmailVerification ||
          (prev is DivineAuthFormState &&
              next is DivineAuthFormState &&
              next.signInFailureReason != null &&
              prev.signInFailureReason != next.signInFailureReason),
      listener: (context, state) {
        if (state is DivineAuthFormState && state.signInFailureReason != null) {
          // Announce the failure to screen readers as it appears.
          SemanticsService.sendAnnouncement(
            View.of(context),
            _signInErrorMessage(context, state.signInFailureReason!),
            Directionality.of(context),
          );
          return;
        }
        if (state is DivineAuthEmailVerification) {
          final encodedEmail = Uri.encodeComponent(state.email);
          context.go(
            '${EmailVerificationScreen.path}'
            '?deviceCode=${state.deviceCode}'
            '&verifier=${state.verifier}'
            '&email=$encodedEmail',
          );
        }
      },
      child: Scaffold(
        backgroundColor: context.vineColors.background,
        body: SafeArea(
          child: BlocBuilder<DivineAuthCubit, DivineAuthState>(
            builder: (context, state) {
              if (state is DivineAuthFormState) {
                return _SignInContent(state: state);
              }
              return Center(
                child: DivineCircularProgressIndicator(
                  color: context.vineColors.accentPositive,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Main content with email/password form and alternative login methods.
class _SignInContent extends ConsumerStatefulWidget {
  const _SignInContent({required this.state});

  final DivineAuthFormState state;

  @override
  ConsumerState<_SignInContent> createState() => _SignInContentState();
}

class _SignInContentState extends ConsumerState<_SignInContent> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late FocusNode _emailFocusNode;
  late FocusNode _passwordFocusNode;
  bool _isConnectingAmber = false;
  bool _isConnectingNip07 = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.state.email);
    _passwordController = TextEditingController(text: widget.state.password);
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SignInContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_emailController.text != widget.state.email) {
      _emailController.text = widget.state.email;
    }
    if (_passwordController.text != widget.state.password) {
      _passwordController.text = widget.state.password;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _connectWithNip07() async {
    setState(() => _isConnectingNip07 = true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.connectWithNip07();

      if (!mounted) return;

      if (result.success) {
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? context.l10n.authNip07ConnectionFailed,
            ),
            backgroundColor: VineTheme.error,
          ),
        );
        authService.clearError();
      }
    } finally {
      if (mounted) {
        setState(() => _isConnectingNip07 = false);
      }
    }
  }

  Future<void> _connectWithAmber() async {
    final isInstalled = await AndroidPlugin.existAndroidNostrSigner() ?? false;
    if (!isInstalled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.authAmberNotInstalled),
          backgroundColor: VineTheme.error,
        ),
      );
      return;
    }

    setState(() => _isConnectingAmber = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.connectWithAmber();

      if (!mounted) return;

      if (result.success) {
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? context.l10n.authAmberConnectionFailed,
            ),
            backgroundColor: VineTheme.error,
          ),
        );
        // Clear the error so it doesn't show again on the welcome screen
        authService.clearError();
      }
    } finally {
      if (mounted) {
        setState(() => _isConnectingAmber = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    showForgotPasswordDialog(
      context: context,
      initialEmail: _emailController.text,
      onSendResetEmail: (email) async {
        return context.read<DivineAuthCubit>().sendPasswordResetEmail(email);
      },
      onResetAccepted: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              padding: EdgeInsets.zero,
              backgroundColor: VineTheme.transparent,
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              content: DivineSnackbarContainer(
                label: context.l10n.authPasswordResetSent,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = widget.state.isSubmitting;
    final isDisabled = isSubmitting || _isConnectingAmber || _isConnectingNip07;
    final isNip07Available = ref.watch(authServiceProvider).isNip07Available;

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Top bar: back + info
                Row(
                  children: [
                    AuthBackButton(enabled: !isDisabled),
                    const Spacer(),
                    RoundedIconButton(
                      onPressed: isDisabled
                          ? null
                          : () => _showInfoSheet(
                              context,
                              showNip07: isNip07Available,
                            ),
                      semanticLabel: context.l10n.authSignInOptionsInfo,
                      semanticIdentifier:
                          SemanticIds.authSignInOptionsInfoButton,
                      icon: DivineIcon(
                        icon: DivineIconName.info,
                        color: context.vineColors.onIconButton,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  context.l10n.authSignInTitle,
                  style: TextStyle(
                    fontFamily: VineTheme.fontFamilyBricolage,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: context.vineColors.primaryText,
                  ),
                ),

                const SizedBox(height: 40),

                // Email + Password wrapped for password manager autofill.
                AutofillGroup(
                  child: Form(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 16,
                      children: [
                        // Email field
                        DivineAuthTextField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          label: context.l10n.authEmailLabel,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: .next,
                          errorText: widget.state.emailError,
                          enabled: !isDisabled,
                          autocorrect: false,
                          onChanged: (value) => context
                              .read<DivineAuthCubit>()
                              .updateEmail(value),
                          onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                        ),

                        // Password field
                        DivineAuthTextField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          label: context.l10n.authPasswordLabel,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: .done,
                          errorText: widget.state.passwordError,
                          enabled: !isDisabled,
                          onChanged: (value) => context
                              .read<DivineAuthCubit>()
                              .updatePassword(value),
                          onSubmitted: isDisabled
                              ? null
                              : (_) => context.read<DivineAuthCubit>().submit(),
                          showPasswordSemanticLabel:
                              context.l10n.authShowPassword,
                          hidePasswordSemanticLabel:
                              context.l10n.authHidePassword,
                        ),
                      ],
                    ),
                  ),
                ),

                // Sign-in error, with a nudge toward every sign-in option.
                if (widget.state.signInFailureReason != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBox(
                    message: _signInErrorMessage(
                      context,
                      widget.state.signInFailureReason!,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _SignInOptionsHint(),
                ] else if (widget.state.generalError != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBox(message: widget.state.generalError!),
                ],

                const SizedBox(height: 24),

                // Sign in button
                DivineButton(
                  expanded: true,
                  label: context.l10n.authSignInButton,
                  isLoading: isSubmitting,
                  onPressed: isDisabled
                      ? null
                      : () => context.read<DivineAuthCubit>().submit(),
                ),

                const SizedBox(height: 16),

                // Forgot password
                Center(
                  child: GestureDetector(
                    onTap: isDisabled ? null : _showForgotPasswordDialog,
                    child: Text(
                      context.l10n.authForgotPassword,
                      style: TextStyle(
                        color: context.vineColors.primaryText,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: context.vineColors.primaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: DivineButton(
                    type: .link,
                    label: context.l10n.authContactSupport,
                    onPressed: isDisabled
                        ? null
                        : () => context.push(SupportCenterScreen.path),
                  ),
                ),
                const SizedBox(height: 24),

                // Push alternative methods to bottom
                const Spacer(),

                // Alternative login methods
                DivineButton(
                  type: .secondary,
                  expanded: true,
                  label: context.l10n.authImportNostrKey,
                  onPressed: isDisabled
                      ? null
                      : () => context.push(KeyImportScreen.path),
                ),

                const SizedBox(height: 12),

                DivineButton(
                  type: .secondary,
                  expanded: true,
                  label: context.l10n.authConnectSignerApp,
                  onPressed: isDisabled
                      ? null
                      : () => context.push(NostrConnectScreen.path),
                ),

                if (isNip07Available) ...[
                  const SizedBox(height: 12),
                  DivineButton(
                    type: .secondary,
                    expanded: true,
                    label: context.l10n.authSignInWithBrowserExtension,
                    isLoading: _isConnectingNip07,
                    onPressed: isDisabled ? null : _connectWithNip07,
                  ),
                ],

                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.android) ...[
                  const SizedBox(height: 12),
                  DivineButton(
                    type: .secondary,
                    expanded: true,
                    label: context.l10n.authSignInWithAmber,
                    isLoading: _isConnectingAmber,
                    onPressed: isDisabled ? null : _connectWithAmber,
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Localized copy for a failed sign-in. Kept neutral about account existence
/// for [SignInFailureReason.invalidCredentials] — see the enum doc.
String _signInErrorMessage(BuildContext context, SignInFailureReason reason) {
  final l10n = context.l10n;
  switch (reason) {
    case SignInFailureReason.invalidCredentials:
      return l10n.authSignInErrorInvalidCredentials;
    case SignInFailureReason.emailNotVerified:
      return l10n.authSignInErrorEmailNotVerified;
    case SignInFailureReason.invalidEmail:
      return l10n.authSignInErrorInvalidEmail;
    case SignInFailureReason.network:
      return l10n.authSignInErrorNetwork;
    case SignInFailureReason.unknown:
      return l10n.authSignInErrorGeneric;
  }
}

/// Tappable hint under a failed sign-in that opens the full sign-in options
/// sheet. Safe for every user: it never claims an account exists, so it works
/// whether the failure was a typo, an unverified email, or a Nostr-native user
/// on the wrong screen. The whole line is one 48dp tap target.
class _SignInOptionsHint extends ConsumerWidget {
  const _SignInOptionsHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showInfoSheet(
          context,
          showNip07: ref.read(authServiceProvider).isNip07Available,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
                children: [
                  TextSpan(text: l10n.authSignInOptionsHintPrefix),
                  TextSpan(
                    text: l10n.authSignInOptionsHintCta,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.accentPositive,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showInfoSheet(BuildContext context, {required bool showNip07}) {
  VineBottomSheet.show<void>(
    context: context,
    title: Text(context.l10n.authSignInOptionsTitle),
    buildScrollBody: (scrollController) => Builder(
      builder: (sheetContext) => ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          32 + MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        children: [
          _InfoItem(
            title: sheetContext.l10n.authInfoEmailPasswordTitle,
            description: sheetContext.l10n.authInfoEmailPasswordDescription,
          ),
          const SizedBox(height: 16),
          _InfoItem(
            title: sheetContext.l10n.authImportNostrKey,
            description: sheetContext.l10n.authInfoImportNostrKeyDescription,
          ),
          const SizedBox(height: 16),
          _InfoItem(
            title: sheetContext.l10n.authInfoSignerAppTitle,
            description: sheetContext.l10n.authInfoSignerAppDescription,
          ),
          if (showNip07) ...[
            const SizedBox(height: 16),
            _InfoItem(
              title: sheetContext.l10n.authInfoBrowserExtensionTitle,
              description:
                  sheetContext.l10n.authInfoBrowserExtensionDescription,
            ),
          ],
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 16),
            _InfoItem(
              title: sheetContext.l10n.authInfoAmberTitle,
              description: sheetContext.l10n.authInfoAmberDescription,
            ),
          ],
        ],
      ),
    ),
  );
}

/// Single info item in the info sheet.
class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: context.vineColors.secondaryText,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
