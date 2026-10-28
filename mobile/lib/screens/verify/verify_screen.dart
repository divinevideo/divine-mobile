// ABOUTME: The verify dashboard — every linked account, its verdict, and the
// ABOUTME: platforms still on offer. Replaces the verifier.divine.video trip.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/blocs/verify/verify_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:openvine/screens/verify/widgets/verify_claim_row.dart';
import 'package:openvine/screens/verify/widgets/verify_how_it_works_sheet.dart';
import 'package:openvine/screens/verify/widgets/verify_platform_row.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

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
    // As on the connect screen: iOS below 17.4 can report a completed sign-in
    // as a cancel, so no sign-in is offered there.
    final oauthUsable = ref.watch(appOAuthSupportProvider).value ?? false;

    if (pubkey == null || pubkey.isEmpty) {
      return const _VerifyScaffold(body: _VerifySignedOut());
    }

    return BlocProvider(
      // Re-create on a repository swap: the captured signer and client belong
      // to the identity that was current when the flow opened.
      key: ValueKey((repository, pubkey)),
      create: (_) {
        final cubit = VerifyCubit(repository: repository, pubkey: pubkey);
        runDetached(
          cubit.load(),
          'load identity claims',
          logName: 'VerifyPage',
          category: LogCategory.auth,
        );
        return cubit;
      },
      child: VerifyView(oauthUsable: oauthUsable),
    );
  }
}

/// The verify dashboard itself.
class VerifyView extends StatelessWidget {
  /// Creates a [VerifyView].
  @visibleForTesting
  const VerifyView({this.oauthUsable = false, super.key});

  /// Whether this device can run a platform sign-in.
  final bool oauthUsable;

  @override
  Widget build(BuildContext context) {
    return BlocListener<VerifyCubit, VerifyState>(
      listenWhen: (previous, current) =>
          previous.errorAttempt != current.errorAttempt,
      listener: _onError,
      child: _VerifyScaffold(body: _VerifyBody(oauthUsable: oauthUsable)),
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
  const _VerifyBody({required this.oauthUsable});

  final bool oauthUsable;

  @override
  Widget build(BuildContext context) {
    final status = context.select((VerifyCubit cubit) => cubit.state.status);

    return switch (status) {
      VerifyStatus.initial ||
      VerifyStatus.loading => const Center(child: BrandedLoadingIndicator()),
      VerifyStatus.failure => const _VerifyLoadFailure(),
      VerifyStatus.ready => _VerifyContent(oauthUsable: oauthUsable),
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
              onPressed: () => runDetached(
                context.read<VerifyCubit>().load(),
                'retry loading identity claims',
                logName: 'VerifyView',
                category: LogCategory.auth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyContent extends StatelessWidget {
  const _VerifyContent({required this.oauthUsable});

  final bool oauthUsable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final claims = context.select((VerifyCubit cubit) => cubit.state.claims);
    final verifiedKeys = context.select(
      (VerifyCubit cubit) => cubit.state.verifiedKeys,
    );
    final showsUncheckedNote = context.select(
      (VerifyCubit cubit) => cubit.state.showsUncheckedNote,
    );
    final removingKey = context.select(
      (VerifyCubit cubit) => cubit.state.removingKey,
    );
    final linkable = context.select(
      (VerifyCubit cubit) => cubit.state.linkablePlatforms,
    );
    final canSignInAgain = context.select(
      (VerifyCubit cubit) => cubit.state.canSignInAgain,
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
          if (showsUncheckedNote)
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
              onSignInAgain: oauthUsable && canSignInAgain(claim)
                  ? () =>
                        _openConnect(context, claim.platform, replacing: claim)
                  : null,
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
              onTap: () => _openConnect(context, platform.key),
            ),
      ],
    );
  }

  Widget _linkedClaimRow({
    required IdentityClaim claim,
    required Set<String> verifiedKeys,
    required String? removingKey,
    required VoidCallback onRemove,
    required VoidCallback? onSignInAgain,
  }) {
    final key = VerifyState.keyOf(claim);
    return VerifyClaimRow(
      claim: claim,
      isVerified: verifiedKeys.contains(key),
      isRemoving: removingKey == key,
      onRemove: removingKey != null ? null : onRemove,
      // Renewing publishes over the same links an unlink is rewriting.
      onSignInAgain: removingKey != null ? null : onSignInAgain,
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
    final navigator = Navigator.of(context);
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: l10n.verifyUnlinkConfirmTitle(verifyPlatformLabel(claim.platform)),
      subtitle: l10n.verifyUnlinkConfirmSubtitle(claim.identity),
      primaryButtonText: l10n.verifyUnlinkConfirmCta,
      primaryButtonType: DivineButtonType.error,
      onPrimaryPressed: () => navigator.pop(true),
      secondaryButtonText: l10n.commonCancel,
      onSecondaryPressed: () => navigator.pop(false),
    );
    // The prompt outlives a cubit that an identity change closed under it.
    if (confirmed != true || cubit.isClosed) return;
    await cubit.removeClaim(claim);
  }

  /// Opens the connect flow for [platformKey]. With [replacing], the flow
  /// renews that sign-in link, and a sign-in under another handle takes the
  /// link's place.
  Future<void> _openConnect(
    BuildContext context,
    String platformKey, {
    IdentityClaim? replacing,
  }) async {
    final cubit = context.read<VerifyCubit>();
    final result = await VerifyConnectRouteData(
      platform: platformKey,
      replacing: replacing?.identity,
    ).push<VerifyConnectResult>(context);
    if (result == null || !context.mounted) return;
    final linked = result.linked;

    // Only the link the flow actually replaced loses its row: a proof post
    // linked from here, or a renewal under the same handle, leaves it.
    cubit.claimLinked(
      linked,
      replacing: result.replacedIdentity == null ? null : replacing,
    );
    final message = context.l10n.verifyLinkedConfirmation(
      verifyPlatformLabel(linked.platform),
    );
    announceDetached(
      context,
      message,
      description: 'announce linked identity',
      logName: 'VerifyView',
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
