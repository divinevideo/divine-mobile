// ABOUTME: "Continue with Apple / Google" buttons for the welcome and sign-in
// ABOUTME: screens, and the scope that provides their SocialSignInCubit.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart' show SocialProvider;
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/social_sign_in/social_sign_in_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
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
    final enabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.socialSignIn),
    );
    return BlocProvider(
      key: ValueKey((repository, authService, enabled)),
      create: (_) => SocialSignInCubit(
        repository: repository,
        authService: authService,
        enabled: enabled,
      ),
      child: child,
    );
  }
}

/// One full-width button per provider this device offers, followed by
/// [bottomSpacing]. Renders nothing when no provider is offered.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    this.enabled = true,
    this.bottomSpacing = 12,
    super.key,
  });

  /// False while another sign-in on the same screen is running. The buttons
  /// also disable themselves while their own sign-in runs.
  final bool enabled;

  /// Gap below the last button.
  final double bottomSpacing;

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
          padding: EdgeInsets.only(bottom: bottomSpacing),
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
    final (label, icon, semanticIdentifier) = switch (provider) {
      SocialProvider.apple => (
        l10n.authContinueWithApple,
        DivineIconName.appleSignIn,
        SemanticIds.authContinueWithAppleButton,
      ),
      SocialProvider.google => (
        l10n.authContinueWithGoogle,
        DivineIconName.googleSignIn,
        SemanticIds.authContinueWithGoogleButton,
      ),
    };
    return DivineButton(
      label: label,
      type: DivineButtonType.contrast,
      expanded: true,
      leadingIcon: icon,
      // Google's G keeps its colours; Apple's logo takes the text colour.
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
