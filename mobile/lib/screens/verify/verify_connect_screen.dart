// ABOUTME: Links one platform — OAuth login where the verifier offers it,
// ABOUTME: a proof post otherwise. Publishes the claim once it checks out.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/oauth/app_oauth_callback.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:profile_repository/profile_repository.dart';

/// Route host for linking a single platform.
class VerifyConnectPage extends ConsumerWidget {
  /// Creates a [VerifyConnectPage] for [platformKey].
  const VerifyConnectPage({required this.platformKey, super.key});

  /// Route name used by GoRouter.
  static const routeName = 'verify-connect';

  /// Route path used by GoRouter, relative to the verify dashboard.
  static const path = 'connect/:platform';

  /// NIP-39 platform key being linked.
  final String platformKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(identityClaimsRepositoryProvider);
    // See VerifyPage: the auth service instance itself never changes, so the
    // identity has to be watched separately for the pubkey to stay current.
    ref.watch(currentAuthStateProvider);
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    // iOS below 17.4 can report a completed OAuth session as a cancel, so the
    // one-tap route is hidden there and the proof post carries the flow.
    final oauthUsable = ref.watch(appOAuthSupportProvider).value ?? false;

    if (pubkey == null || pubkey.isEmpty) {
      return _ConnectScaffold(
        title: verifyPlatformLabel(platformKey),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.verifySignedOutMessage,
              textAlign: TextAlign.center,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.mutedText,
              ),
            ),
          ),
        ),
      );
    }

    final platform = VerifierPlatform(
      key: platformKey,
      label: verifyPlatformLabel(platformKey),
      supported: true,
    );

    return BlocProvider(
      key: ValueKey((repository, pubkey, platformKey)),
      create: (_) => VerifyConnectCubit(
        repository: repository,
        pubkey: pubkey,
        platform: platform,
        launchOAuth: launchAppOAuth,
        oauthReturnUrl: appOAuthCallbackUrl,
        // A plain Provider whose identity never changes, so it is read rather
        // than watched and stays out of the ValueKey above.
        analytics: ref.read(analyticsEventSinkProvider),
      ),
      child: VerifyConnectView(
        npub: NostrKeyUtils.encodePubKey(pubkey),
        oauthAvailable: oauthUsable,
      ),
    );
  }
}

/// The link form for one platform.
class VerifyConnectView extends StatelessWidget {
  /// Creates a [VerifyConnectView].
  @visibleForTesting
  const VerifyConnectView({
    required this.npub,
    this.oauthAvailable = true,
    super.key,
  });

  /// The signed-in npub, shown so the user can paste it into a proof post.
  final String npub;

  /// Whether this platform's OAuth route can complete here.
  final bool oauthAvailable;

  @override
  Widget build(BuildContext context) {
    final platform = context.select(
      (VerifyConnectCubit cubit) => cubit.state.platform,
    );
    // Held while an attempt runs: leaving during its write would let an
    // unlink on the dashboard read the links before the write lands, and
    // publish over it.
    final busy = context.select(
      (VerifyConnectCubit cubit) => cubit.state.isBusy,
    );
    return BlocListener<VerifyConnectCubit, VerifyConnectState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.errorAttempt != current.errorAttempt,
      listener: _onStateChanged,
      child: PopScope(
        canPop: !busy,
        child: _ConnectScaffold(
          title: verifyPlatformLabel(platform.key),
          canLeave: !busy,
          body: _ConnectForm(npub: npub, oauthAvailable: oauthAvailable),
        ),
      ),
    );
  }

  void _onStateChanged(BuildContext context, VerifyConnectState state) {
    final l10n = context.l10n;
    if (state.status == VerifyConnectStatus.linked) {
      // Hand the claim back rather than a bare flag, so the dashboard can draw
      // the new row from what was published instead of waiting on relays.
      context.pop(state.linkedClaim);
      return;
    }
    final error = state.error;
    final account = state.signedInAccount;
    // The card replaces the start button that had focus when the browser
    // returned, so nothing else tells a screen reader it arrived. A failure
    // that keeps the sign-in comes back here with an error, which the
    // snackbar speaks for.
    if (state.status == VerifyConnectStatus.awaitingApproval &&
        error == null &&
        account != null) {
      announceDetached(
        context,
        l10n.verifyConnectSignedInTitle(
          verifyPlatformLabel(state.platform.key),
          account,
        ),
        description: 'announce the signed-in account',
        logName: 'VerifyConnectView',
      );
      return;
    }
    if (error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(switch (error) {
        VerifyConnectError.proofRejected => l10n.verifyErrorProofRejected,
        VerifyConnectError.proofMissingNpub => l10n.verifyErrorProofMissingNpub,
        VerifyConnectError.discordDmLink => l10n.verifyErrorDiscordDmLink,
        VerifyConnectError.discordChannelLink =>
          l10n.verifyErrorDiscordChannelLink,
        VerifyConnectError.discordMessageNotFound =>
          l10n.verifyErrorDiscordMessageNotFound,
        VerifyConnectError.discordBotNoAccess =>
          l10n.verifyErrorDiscordBotNoAccess,
        VerifyConnectError.discordAuthorMismatch =>
          l10n.verifyErrorDiscordAuthorMismatch,
        VerifyConnectError.discordContentUnavailable =>
          l10n.verifyErrorDiscordContentUnavailable,
        VerifyConnectError.verifierUnreachable =>
          l10n.verifyErrorVerifierUnreachable,
        VerifyConnectError.oauthFailed => l10n.verifyErrorOauthFailed,
        VerifyConnectError.signInNotConfirmed =>
          l10n.verifyErrorSignInNotConfirmed,
        VerifyConnectError.notSigned => l10n.verifyErrorNotSigned,
        VerifyConnectError.oauthUnavailable => l10n.verifyErrorOauthUnavailable,
        VerifyConnectError.telegramNotPublic =>
          l10n.verifyErrorTelegramNotPublic,
        VerifyConnectError.handleRequired => l10n.verifyErrorHandleRequired,
        VerifyConnectError.publishFailed => l10n.verifyErrorPublishFailed,
        VerifyConnectError.linksUnreadable => l10n.verifyErrorLinksUnreadable,
      }, error: true),
    );
  }
}

class _ConnectScaffold extends StatelessWidget {
  const _ConnectScaffold({
    required this.title,
    required this.body,
    this.canLeave = true,
  });

  final String title;
  final Widget body;

  /// False while an attempt runs. The back button pops directly, which a
  /// [PopScope] does not stop, so it checks this itself.
  final bool canLeave;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: title,
        showBackButton: true,
        onBackPressed: () {
          if (canLeave) context.safePop(fallback: '/verify');
        },
      ),
      body: body,
    );
  }
}

class _ConnectForm extends StatelessWidget {
  const _ConnectForm({required this.npub, required this.oauthAvailable});

  final String npub;
  final bool oauthAvailable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<VerifyConnectCubit>().state;
    final showOAuth = state.supportsOAuth && oauthAvailable;
    final signedInAccount = state.signedInAccount;
    // One link at a time: while a sign-in waits, the person links that
    // account or cancels it first. One already signed carries the links as
    // they were, so a proof linked meanwhile would be dropped once that
    // sign-in is published.
    final inputsEnabled = !state.isBusy && signedInAccount == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (showOAuth) ...[
          Text(
            l10n.verifyConnectOauthExplainer(
              verifyPlatformLabel(state.platform.key),
            ),
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          const SizedBox(height: 16),
          if (state.platform.key == 'bluesky') ...[
            // Same key as the copy in the proof block below: this field moves
            // between the two when appOAuthSupportProvider resolves, and the
            // key is what carries the typed handle across the move. It has to
            // sit on the child the list matches, not on the DivineTextField
            // inside — keying the inner field leaves this element to be
            // rebuilt by position, which loses the text anyway. It stays while
            // a sign-in waits for the same reason: a cancel brings back the
            // start button, and the handle has to still be in the field.
            _IdentityField(
              key: const ValueKey('verify-identity-field'),
              state: state,
              enabled: inputsEnabled,
            ),
            const SizedBox(height: 12),
          ],
          if (signedInAccount != null) ...[
            Text(
              l10n.verifyConnectSignedInTitle(
                verifyPlatformLabel(state.platform.key),
                signedInAccount,
              ),
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            DivineButton(
              label: l10n.verifyConnectSignedInCta,
              expanded: true,
              isLoading: state.status == VerifyConnectStatus.publishing,
              onPressed: state.isBusy
                  ? null
                  : context.read<VerifyConnectCubit>().approveSignIn,
            ),
            const SizedBox(height: 8),
            DivineButton(
              label: l10n.verifyConnectSignedInCancel,
              type: DivineButtonType.secondary,
              expanded: true,
              onPressed: state.isBusy
                  ? null
                  : context.read<VerifyConnectCubit>().cancelSignIn,
            ),
            const SizedBox(height: 24),
          ] else ...[
            DivineButton(
              label: l10n.verifyConnectOauthCta(
                verifyPlatformLabel(state.platform.key),
              ),
              expanded: true,
              isLoading: state.status == VerifyConnectStatus.authorizing,
              onPressed: state.isBusy
                  ? null
                  : context.read<VerifyConnectCubit>().connectWithOAuth,
            ),
            const SizedBox(height: 24),
          ],
        ],
        _SectionLabel(l10n.verifyConnectProofTitle),
        // Bluesky's note says a sign-in above is all it takes, which reads
        // wrong while the card above still asks to link the account.
        if (!(signedInAccount != null && state.platform.key == 'bluesky')) ...[
          Text(
            verifyProofExplainer(l10n, state.platform.key),
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _NpubCard(npub: npub),
        const SizedBox(height: 16),
        // Skipped when the pasted link already carries the account, and when
        // the OAuth block above is already asking for it.
        if (state.needsIdentityInput &&
            !(showOAuth && state.platform.key == 'bluesky')) ...[
          _IdentityField(
            key: const ValueKey('verify-identity-field'),
            state: state,
            enabled: inputsEnabled,
          ),
          const SizedBox(height: 12),
        ],
        // Keyed because the account field above is inserted and removed as the
        // typed proof starts and stops parsing. Without a key the list matches
        // these children by position, so the shift hands this slot to a
        // different widget, the field is rebuilt from scratch, and the text and
        // the keyboard go with it.
        DivineTextField(
          key: const ValueKey('verify-proof-field'),
          labelText: l10n.verifyProofLabel,
          hintText: verifyProofHint(state.platform.key),
          filled: true,
          enabled: inputsEnabled,
          textInputAction: .send,
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          onChanged: context.read<VerifyConnectCubit>().proofChanged,
          onSubmitted: (_) => !inputsEnabled || !state.canSubmitProof
              ? null
              : context.read<VerifyConnectCubit>().submitProof(),
        ),
        const SizedBox(height: 16),
        DivineButton(
          label: l10n.verifyConnectProofCta,
          expanded: true,
          // A sign-in being linked shows its own progress above.
          isLoading:
              signedInAccount == null &&
              (state.status == VerifyConnectStatus.verifying ||
                  state.status == VerifyConnectStatus.publishing),
          onPressed: !inputsEnabled || !state.canSubmitProof
              ? null
              : context.read<VerifyConnectCubit>().submitProof,
        ),
      ],
    );
  }
}

class _IdentityField extends StatelessWidget {
  const _IdentityField({
    required this.state,
    required this.enabled,
    super.key,
  });

  final VerifyConnectState state;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DivineTextField(
      labelText: verifyIdentityFieldLabel(context.l10n, state.platform.key),
      hintText: verifyIdentityHint(state.platform.key),
      filled: true,
      enabled: enabled,
      textInputAction: .next,
      textCapitalization: TextCapitalization.none,
      onChanged: context.read<VerifyConnectCubit>().identityChanged,
    );
  }
}

class _NpubCard extends StatelessWidget {
  const _NpubCard({required this.npub});

  final String npub;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    l10n.verifyNpubLabel,
                    style: VineTheme.labelMediumFont(
                      color: context.vineColors.mutedText,
                    ),
                  ),
                  Text(
                    npub,
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
            DivineIconButton(
              icon: DivineIconName.copy,
              type: .secondary,
              size: .small,
              semanticLabel: l10n.verifyCopyNpubSemanticLabel,
              onPressed: () => ClipboardUtils.copyVerified(
                context,
                npub,
                message: l10n.verifyNpubCopied,
              ),
            ),
          ],
        ),
      ),
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
