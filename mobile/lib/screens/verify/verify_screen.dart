// ABOUTME: The verify dashboard — every linked account, its verdict, and the
// ABOUTME: platforms still on offer. Replaces the verifier.divine.video trip.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/verify/verify_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/screens/verify/verify_connect_screen.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:openvine/screens/verify/widgets/verify_claim_row.dart';
import 'package:openvine/screens/verify/widgets/verify_how_it_works_sheet.dart';
import 'package:openvine/screens/verify/widgets/verify_platform_row.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:profile_repository/profile_repository.dart';

/// Route host for the verify dashboard.
class VerifyPage extends ConsumerWidget {
  /// Creates a [VerifyPage].
  const VerifyPage({super.key});

  /// Route name used by GoRouter.
  static const routeName = 'verify';

  /// Route path used by GoRouter.
  static const path = '/verify';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(identityClaimsRepositoryProvider);
    // `authServiceProvider` is a keepAlive singleton that does not rebuild when
    // the signed-in identity changes, so without this the pubkey below stays
    // whatever it was on first build. The key already keeps the cubit alive
    // across rebuilds that do not change it.
    ref.watch(currentAuthStateProvider);
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;

    if (pubkey == null || pubkey.isEmpty) {
      return const _VerifyScaffold(body: _VerifySignedOut());
    }

    return BlocProvider(
      // Re-create on a repository swap: the captured signer and client belong
      // to the identity that was current when the flow opened.
      key: ValueKey((repository, pubkey)),
      create: (_) =>
          VerifyCubit(repository: repository, pubkey: pubkey)..load(),
      child: const VerifyView(),
    );
  }
}

/// The verify dashboard itself.
class VerifyView extends StatelessWidget {
  /// Creates a [VerifyView].
  @visibleForTesting
  const VerifyView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<VerifyCubit, VerifyState>(
      listenWhen: (previous, current) =>
          previous.errorAttempt != current.errorAttempt,
      listener: _onError,
      child: const _VerifyScaffold(body: _VerifyBody()),
    );
  }

  void _onError(BuildContext context, VerifyState state) {
    final error = state.error;
    // An unlink that fails leaves the row exactly where it was, which on its
    // own reads as a button that does nothing.
    if (error == null) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(switch (error) {
        VerifyError.remove => l10n.verifyErrorRemoveFailed,
        VerifyError.linksUnreadable => l10n.verifyErrorLinksUnreadable,
        VerifyError.load => l10n.verifyLoadFailed,
      }, error: true),
    );
  }
}

class _VerifyScaffold extends StatelessWidget {
  const _VerifyScaffold({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.verifyTitle,
        showBackButton: true,
        onBackPressed: () => context.safePop(),
      ),
      body: body,
    );
  }
}

class _VerifySignedOut extends StatelessWidget {
  const _VerifySignedOut();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.verifySignedOutMessage,
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
      ),
    );
  }
}

class _VerifyBody extends StatelessWidget {
  const _VerifyBody();

  @override
  Widget build(BuildContext context) {
    final status = context.select((VerifyCubit cubit) => cubit.state.status);

    return switch (status) {
      VerifyStatus.initial ||
      VerifyStatus.loading => const Center(child: BrandedLoadingIndicator()),
      VerifyStatus.failure => const _VerifyLoadFailure(),
      VerifyStatus.ready => const _VerifyContent(),
    };
  }
}

class _VerifyLoadFailure extends StatelessWidget {
  const _VerifyLoadFailure();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              l10n.verifyLoadFailed,
              textAlign: TextAlign.center,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.mutedText,
              ),
            ),
            DivineButton(
              label: l10n.verifyRetry,
              type: DivineButtonType.secondary,
              onPressed: () => context.read<VerifyCubit>().load(),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyContent extends StatelessWidget {
  const _VerifyContent();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final claims = context.select((VerifyCubit cubit) => cubit.state.claims);
    final verifiedKeys = context.select(
      (VerifyCubit cubit) => cubit.state.verifiedKeys,
    );
    final verifierReachable = context.select(
      (VerifyCubit cubit) => cubit.state.verifierReachable,
    );
    final removingKey = context.select(
      (VerifyCubit cubit) => cubit.state.removingKey,
    );
    final linkable = context.select(
      (VerifyCubit cubit) => cubit.state.linkablePlatforms,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          l10n.verifyIntro,
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
        const SizedBox(height: 8),
        const _HowItWorksLink(),
        const SizedBox(height: 24),
        if (claims.isNotEmpty) ...[
          _SectionLabel(l10n.verifyLinkedSectionTitle),
          if (!verifierReachable)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.verifyVerifierUnreachable,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.mutedText,
                ),
              ),
            ),
          for (final claim in claims)
            _linkedClaimRow(
              claim: claim,
              verifiedKeys: verifiedKeys,
              removingKey: removingKey,
              onRemove: () => _confirmRemove(context, claim),
            ),
          const SizedBox(height: 24),
        ],
        _SectionLabel(l10n.verifyAddSectionTitle),
        if (linkable.isEmpty)
          Text(
            l10n.verifyAllPlatformsLinked,
            style: VineTheme.bodySmallFont(color: context.vineColors.mutedText),
          )
        else
          for (final platform in linkable)
            VerifyPlatformRow(
              platform: platform,
              onTap: () => _openConnect(context, platform),
            ),
      ],
    );
  }

  Widget _linkedClaimRow({
    required IdentityClaim claim,
    required Set<String> verifiedKeys,
    required String? removingKey,
    required VoidCallback onRemove,
  }) {
    final key = VerifyState.keyOf(claim);
    return VerifyClaimRow(
      claim: claim,
      isVerified: verifiedKeys.contains(key),
      isRemoving: removingKey == key,
      onRemove: removingKey != null ? null : onRemove,
    );
  }

  /// Confirms before unlinking.
  ///
  /// One tap on the row's trash icon would otherwise both drop the `i` tag and
  /// revoke the verifier's cached OAuth login, so a mis-tap costs a full
  /// sign-in — the only destructive step in this flow that the user cannot
  /// undo by pressing the same button again.
  Future<void> _confirmRemove(BuildContext context, IdentityClaim claim) async {
    final cubit = context.read<VerifyCubit>();
    final l10n = context.l10n;
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: l10n.verifyUnlinkConfirmTitle(verifyPlatformLabel(claim.platform)),
      subtitle: l10n.verifyUnlinkConfirmSubtitle(claim.identity),
      primaryButtonText: l10n.verifyUnlinkConfirmCta,
      primaryButtonType: DivineButtonType.error,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      secondaryButtonText: l10n.commonCancel,
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
    if (confirmed != true) return;
    await cubit.removeClaim(claim);
  }

  Future<void> _openConnect(
    BuildContext context,
    VerifierPlatform platform,
  ) async {
    final cubit = context.read<VerifyCubit>();
    final linked = await context.pushNamed<IdentityClaim>(
      VerifyConnectPage.routeName,
      pathParameters: {'platform': platform.key},
    );
    if (linked == null || !context.mounted) return;

    cubit.claimLinked(linked);
    final message = context.l10n.verifyLinkedConfirmation(
      verifyPlatformLabel(linked.platform),
    );
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(DivineSnackbarContainer.snackBar(message));
  }
}

/// Opens the explainer for people who want to know what linking proves before
/// they hand over a handle.
class _HowItWorksLink extends StatelessWidget {
  const _HowItWorksLink();

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: context.l10n.verifyHowItWorksTitle,
      type: DivineButtonType.secondary,
      size: DivineButtonSize.small,
      onPressed: () => VerifyHowItWorksSheet.show(context),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: VineTheme.labelMediumFont(color: context.vineColors.mutedText),
      ),
    );
  }
}
