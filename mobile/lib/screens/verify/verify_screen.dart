// ABOUTME: The verify dashboard — every linked account, its verdict, and the
// ABOUTME: platforms still on offer. Replaces the verifier.divine.video trip.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/verify/confirmation_requirement.dart';
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/blocs/verify/verify_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/confirmation/confirmation_access_providers.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
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
    // Watched for drawing only; the cubit reads the flag once (see below).
    final confirmationSignIn = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.confirmationSignIn),
    );
    // Gates only the buy controls: a build no store can bill says where to get
    // Divine Confirmation in place of the renew button.
    final canBuy = ref.watch(supporterStoreBillingAvailableProvider);
    // Watched so that the developer override, which swaps the reader, makes a
    // new cubit. Tear-offs of one instance compare equal, so nothing else
    // re-keys it.
    final readConfirmationAccess = ref.watch(confirmationAccessReaderProvider);

    if (pubkey == null || pubkey.isEmpty) {
      return const _VerifyScaffold(body: _VerifySignedOut());
    }

    return BlocProvider(
      // Re-create on a repository swap: the captured signer and client belong
      // to the identity that was current when the flow opened. The reader is
      // in the key too, so changing the developer override starts over with
      // the new answer.
      key: ValueKey((repository, pubkey, readConfirmationAccess)),
      create: (_) {
        final cubit = VerifyCubit(
          repository: repository,
          pubkey: pubkey,
          // Read once and kept out of the ValueKey: turning the flag over
          // must not rebuild the list under the user.
          confirmationSignIn: ref.read(
            isFeatureEnabledProvider(FeatureFlag.confirmationSignIn),
          ),
          // In the ValueKey with the repository, so an account change makes a
          // new cubit with the new account's reader rather than keeping the
          // old account's remembered answer.
          readConfirmationAccess: readConfirmationAccess,
        );
        runDetached(
          cubit.load(),
          'load identity claims',
          logName: 'VerifyPage',
          category: LogCategory.auth,
        );
        return cubit;
      },
      child: VerifyView(
        oauthUsable: oauthUsable,
        confirmationSignIn: confirmationSignIn,
        canBuy: canBuy,
      ),
    );
  }
}

/// The verify dashboard itself.
class VerifyView extends StatelessWidget {
  /// Creates a [VerifyView].
  @visibleForTesting
  const VerifyView({
    this.oauthUsable = false,
    this.confirmationSignIn = false,
    this.canBuy = true,
    super.key,
  });

  /// Whether this device can run a platform sign-in.
  final bool oauthUsable;

  /// The internal `confirmationSignIn` flag. With it off there is no
  /// Confirmation badge or Renew action, but a link the verifier reports as
  /// needing Confirmation still says so on its pill.
  final bool confirmationSignIn;

  /// Whether this build can buy Divine Confirmation. Gates only the buy
  /// controls, never whether the requirement is mentioned.
  final bool canBuy;

  @override
  Widget build(BuildContext context) {
    return BlocListener<VerifyCubit, VerifyState>(
      listenWhen: (previous, current) =>
          previous.errorAttempt != current.errorAttempt,
      listener: _onError,
      child: _VerifyScaffold(
        body: _VerifyBody(
          oauthUsable: oauthUsable,
          confirmationSignIn: confirmationSignIn,
          canBuy: canBuy,
        ),
      ),
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
  const _VerifyBody({
    required this.oauthUsable,
    required this.confirmationSignIn,
    required this.canBuy,
  });

  final bool oauthUsable;
  final bool confirmationSignIn;
  final bool canBuy;

  @override
  Widget build(BuildContext context) {
    final status = context.select((VerifyCubit cubit) => cubit.state.status);

    return switch (status) {
      VerifyStatus.initial ||
      VerifyStatus.loading => const Center(child: BrandedLoadingIndicator()),
      VerifyStatus.failure => const _VerifyLoadFailure(),
      VerifyStatus.ready => _VerifyContent(
        oauthUsable: oauthUsable,
        confirmationSignIn: confirmationSignIn,
        canBuy: canBuy,
      ),
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
  const _VerifyContent({
    required this.oauthUsable,
    required this.confirmationSignIn,
    required this.canBuy,
  });

  final bool oauthUsable;
  final bool confirmationSignIn;
  final bool canBuy;

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
    final signInLapse = context.select(
      (VerifyCubit cubit) => cubit.state.signInLapse,
    );
    final canSignInAgain = context.select(
      (VerifyCubit cubit) => cubit.state.canSignInAgain,
    );
    final canRenewState = context.select(
      (VerifyCubit cubit) => cubit.state.canRenewConfirmation,
    );
    bool canRenewConfirmation(IdentityClaim claim) => canRenewState(
      claim,
      flagOn: confirmationSignIn,
      oauthUsable: oauthUsable,
    );
    final confirmationAccess = context.select(
      (VerifyCubit cubit) => cubit.state.confirmationAccess,
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
            VerifyClaimRow(
              claim: claim,
              isVerified: verifiedKeys.contains(VerifyState.keyOf(claim)),
              isRemoving: removingKey == VerifyState.keyOf(claim),
              onRemove: removingKey != null
                  ? null
                  : () => _confirmRemove(context, claim),
              lapse: signInLapse(claim),
              // Renewing publishes over the same links an unlink is rewriting.
              onSignInAgain:
                  removingKey == null && oauthUsable && canSignInAgain(claim)
                  ? () =>
                        _openConnect(context, claim.platform, replacing: claim)
                  : null,
              // Rules in canRenewConfirmation; where this build cannot buy,
              // the row shows the store note instead of the button.
              onRenewConfirmation: canRenewConfirmation(claim)
                  ? () => _openConfirmation(context)
                  : null,
              renewNeedsStore: !canBuy && canRenewConfirmation(claim),
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
              needsConfirmation: showsConfirmationUpsell(
                required: confirmationSignInRequired(
                  flagOn: confirmationSignIn,
                  platform: platform,
                  oauthUsable: oauthUsable,
                ),
                access: confirmationAccess,
              ),
              onTap: () => _openConnect(context, platform.key),
            ),
      ],
    );
  }

  /// Opens the Divine Confirmation screen, then re-reads the links and asks
  /// again whether the user holds it, skipping the remembered answer, so a
  /// purchase made there shows at once. The list stays on screen meanwhile.
  Future<void> _openConfirmation(BuildContext context) async {
    final cubit = context.read<VerifyCubit>();
    await const VerifyConfirmationRouteData().push<void>(context);
    if (cubit.isClosed) return;
    runDetached(
      cubit.refreshQuietly(),
      'refresh links after Divine Confirmation',
      logName: 'VerifyView',
      category: LogCategory.auth,
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
    // The flow may have re-checked Divine Confirmation (on coming back from
    // the Confirmation screen), whether or not it linked anything; the
    // badges take that answer from the repository.
    if (!cubit.isClosed) {
      runDetached(
        cubit.rereadConfirmationAccess(),
        'reread Divine Confirmation access after connect',
        logName: 'VerifyView',
        category: LogCategory.auth,
      );
    }
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
