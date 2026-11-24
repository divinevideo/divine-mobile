// ABOUTME: "Continue with Apple / Google" buttons for the welcome and sign-in
// ABOUTME: screens, and the scope that provides their SocialSignInCubit.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart' show SocialProvider;
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/social_sign_in/social_sign_in_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/social_sign_in_providers.dart';

/// Provides the [SocialSignInCubit] that [SocialSignInButtons] read.
class SocialSignInScope extends ConsumerWidget {
  const SocialSignInScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(socialSignInRepositoryProvider);
    final authService = ref.watch(authServiceProvider);
    return BlocProvider(
      key: ValueKey((repository, authService)),
      create: (_) => SocialSignInCubit(
        repository: repository,
        authService: authService,
      ),
      child: child,
    );
  }
}

/// One full-width button per provider this device offers, followed by the
/// same gap the auth screens leave between their buttons. Renders nothing
/// when no provider is offered.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({this.enabled = true, super.key});

  /// False while another sign-in on the same screen is running.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SocialSignInCubit, SocialSignInState>(
      listenWhen: (previous, current) =>
          current.status == SocialSignInStatus.failed &&
          previous.status != SocialSignInStatus.failed,
      listener: (context, state) {
        final reason = state.failureReason;
        if (reason == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(socialSignInFailureMessage(context.l10n, reason)),
            backgroundColor: VineTheme.error,
          ),
        );
      },
      builder: (context, state) {
        if (state.availableProviders.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            spacing: 12,
            children: [
              for (final provider in state.availableProviders)
                _ProviderButton(
                  provider: provider,
                  isLoading: state.isBusy && state.activeProvider == provider,
                  enabled: enabled && !state.isBusy,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.provider,
    required this.isLoading,
    required this.enabled,
  });

  final SocialProvider provider;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Both use the quiet outlined style, so the green "create account"
    // button stays in front. Apple's custom-button rules allow it as long as
    // the logo and title are pure white or black, which is what `contrast`
    // adds; Google's G keeps its own colours.
    final (label, icon, type, semanticIdentifier) = switch (provider) {
      SocialProvider.apple => (
        l10n.authContinueWithApple,
        DivineIconName.appleSignIn,
        DivineButtonType.contrast,
        SemanticIds.authContinueWithAppleButton,
      ),
      SocialProvider.google => (
        l10n.authContinueWithGoogle,
        DivineIconName.googleSignIn,
        DivineButtonType.outline,
        SemanticIds.authContinueWithGoogleButton,
      ),
    };
    return DivineButton(
      label: label,
      type: type,
      expanded: true,
      leadingIcon: icon,
      tintLeadingIcon: provider != SocialProvider.google,
      isLoading: isLoading,
      semanticIdentifier: semanticIdentifier,
      onPressed: enabled
          ? () => context.read<SocialSignInCubit>().signIn(provider)
          : null,
    );
  }
}

/// Localized copy for a failed Google or Apple sign-in.
String socialSignInFailureMessage(
  AppLocalizations l10n,
  SocialSignInFailureReason reason,
) => switch (reason) {
  SocialSignInFailureReason.unavailable => l10n.authSocialSignInUnavailable,
  SocialSignInFailureReason.accountLinkRequired =>
    l10n.authSocialSignInAccountLinkRequired,
  SocialSignInFailureReason.emailMissing => l10n.authSocialSignInEmailMissing,
  SocialSignInFailureReason.emailNotVerified =>
    l10n.authSocialSignInEmailNotVerified,
  SocialSignInFailureReason.rateLimited => l10n.accountCredentialsRateLimited,
  SocialSignInFailureReason.network => l10n.authSignInErrorNetwork,
  SocialSignInFailureReason.accountCleanupFailed =>
    l10n.authAccountCleanupFailed,
  SocialSignInFailureReason.failed => l10n.authSignInErrorGeneric,
};
