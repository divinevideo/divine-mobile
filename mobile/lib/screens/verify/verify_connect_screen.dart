// ABOUTME: Links one platform — OAuth login where the verifier offers it,
// ABOUTME: a proof post otherwise. Publishes the claim once it checks out.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/verify/confirmation_requirement.dart';
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/confirmation/confirmation_access_providers.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/oauth/app_oauth_callback.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:unified_logger/unified_logger.dart';

/// Route host for linking a single platform.
class VerifyConnectPage extends ConsumerWidget {
  /// Creates a [VerifyConnectPage] for [platformKey].
  const VerifyConnectPage({
    required this.platformKey,
    this.replacingIdentity,
    super.key,
  });

  /// Route name used by GoRouter.
  static const routeName = 'verify-connect';

  /// Route path used by GoRouter, relative to the verify dashboard.
  static const path = 'connect/:platform';

  /// NIP-39 platform key being linked.
  final String platformKey;

  /// Handle of the sign-in link this flow renews, if it renews one.
  final String? replacingIdentity;

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
    // Watched for drawing only. The cubit reads the flag once per flow (see
    // below), so turning it over here changes what is shown, never a sign-in
    // under way.
    final confirmationSignIn = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.confirmationSignIn),
    );
    // Gates only the buy buttons: a build no store can bill still says that
    // linking by signing in needs Divine Confirmation, with a note where the
    // button would be.
    final canBuy = ref.watch(supporterStoreBillingAvailableProvider);

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

    return BlocProvider(
      key: ValueKey((repository, pubkey, platformKey, replacingIdentity)),
      create: (_) {
        // Starts from the answer the platform list was drawn from, so this
        // screen offers the sign-in the list did. While that answer is being
        // refreshed it offers none until loadPlatform has the new one.
        final cubit = VerifyConnectCubit(
          repository: repository,
          pubkey: pubkey,
          platform: repository.startingPlatform(platformKey),
          replacingIdentity: replacingIdentity,
          launchOAuth: launchAppOAuth,
          oauthReturnUrl: appOAuthCallbackUrl,
          // A plain Provider whose identity never changes, so it is read
          // rather than watched and stays out of the ValueKey above.
          analytics: ref.read(analyticsEventSinkProvider),
          // Read once per flow and kept out of the ValueKey: turning the flag
          // over must not close a cubit holding a sign-in to approve.
          confirmationSignIn: ref.read(
            isFeatureEnabledProvider(FeatureFlag.confirmationSignIn),
          ),
          // The verifier's reader is the repository's own, and the repository
          // is in the ValueKey, so an account change (a new repository) makes
          // a new cubit reading the new account's answer rather than the old
          // one's remembered answer.
          readConfirmationAccess: ref.read(confirmationAccessReaderProvider),
        );
        runDetached(
          cubit.loadPlatform(),
          'load whether sign-in is on',
          logName: 'VerifyConnectPage',
          category: LogCategory.auth,
        );
        return cubit;
      },
      child: VerifyConnectView(
        npub: NostrKeyUtils.encodePubKey(pubkey),
        oauthAvailable: oauthUsable,
        confirmationSignIn: confirmationSignIn,
        canBuy: canBuy,
      ),
    );
  }
}

/// What the person picked in the sheet shown when a sign-in is refused for
/// Divine Confirmation.
enum _ConfirmationRefusalChoice { getConfirmation, useProof }

/// Opens the Divine Confirmation screen, then asks again whether the user
/// holds it, skipping the remembered answer, so a purchase made there shows
/// at once. Reads nothing with the `confirmationSignIn` flag off.
Future<void> _openConfirmation(
  BuildContext context,
  VerifyConnectCubit cubit,
) async {
  await const VerifyConfirmationRouteData().push<void>(context);
  if (cubit.isClosed) return;
  runDetached(
    cubit.refreshConfirmationAccess(),
    'refresh Divine Confirmation access',
    logName: 'VerifyConnectView',
    category: LogCategory.auth,
  );
}

/// The link form for one platform.
class VerifyConnectView extends StatefulWidget {
  /// Creates a [VerifyConnectView].
  @visibleForTesting
  const VerifyConnectView({
    required this.npub,
    this.oauthAvailable = true,
    this.confirmationSignIn = false,
    this.canBuy = true,
    super.key,
  });

  /// The signed-in npub, shown so the user can paste it into a proof post.
  final String npub;

  /// Whether this platform's OAuth route can complete here.
  final bool oauthAvailable;

  /// The internal `confirmationSignIn` flag. With it off there is no
  /// Confirmation card, sheet or heading, but a refusal for Confirmation
  /// still gets its own snackbar, and a refused renewal offers the proof post.
  final bool confirmationSignIn;

  /// Whether a store can bill this build, so a buy button can be offered.
  final bool canBuy;

  @override
  State<VerifyConnectView> createState() => _VerifyConnectViewState();
}

class _VerifyConnectViewState extends State<VerifyConnectView> {
  // On the proof section's label, so "Use a proof post" can bring it into
  // view.
  final GlobalKey _proofSectionKey = GlobalKey();

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
          body: _ConnectForm(
            npub: widget.npub,
            oauthAvailable: widget.oauthAvailable,
            confirmationSignIn: widget.confirmationSignIn,
            canBuy: widget.canBuy,
            proofSectionKey: _proofSectionKey,
          ),
        ),
      ),
    );
  }

  void _onStateChanged(BuildContext context, VerifyConnectState state) {
    final l10n = context.l10n;
    if (state.status == VerifyConnectStatus.linked) {
      // Hand the claim back rather than a bare flag, so the dashboard can draw
      // the new row from what was published instead of waiting on relays.
      final linked = state.linkedClaim;
      context.pop<VerifyConnectResult>(
        linked == null
            ? null
            : (linked: linked, replacedIdentity: state.replacedIdentity),
      );
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
    // With the flag on there is somewhere to go next, so the refusal asks
    // rather than tells. With it off there is nowhere to buy, and the
    // snackbar below says the proof post still works.
    if (error == VerifyConnectError.confirmationRequired &&
        widget.confirmationSignIn) {
      runDetached(
        _offerConfirmation(context),
        'offer Divine Confirmation after a refused sign-in',
        logName: 'VerifyConnectView',
        category: LogCategory.ui,
      );
      return;
    }
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
        VerifyConnectError.confirmationRequired =>
          l10n.verifyErrorConfirmationRequired,
        VerifyConnectError.confirmationUnavailable =>
          l10n.verifyErrorConfirmationUnavailable,
        VerifyConnectError.confirmationPending =>
          l10n.verifyErrorConfirmationPending,
      }, error: true),
    );
  }

  // The sign-in stays while this is up, so it can be approved once
  // Confirmation is bought without signing in at the platform again.
  Future<void> _offerConfirmation(BuildContext context) async {
    final cubit = context.read<VerifyConnectCubit>();
    final l10n = context.l10n;
    final canBuy = widget.canBuy;
    // VineBottomSheet shows on the root navigator, so it is closed there.
    final navigator = Navigator.of(context, rootNavigator: true);
    final choice = await VineBottomSheetPrompt.show<_ConfirmationRefusalChoice>(
      context: context,
      sticker: DivineStickerName.verified,
      title: l10n.verifyConfirmationSheetTitle,
      subtitle: l10n.verifyConfirmationSheetSubtitle,
      additionalText: canBuy ? null : l10n.verifyConfirmationStoreOnly,
      primaryButtonText: canBuy ? l10n.verifyGetConfirmation : null,
      onPrimaryPressed: canBuy
          ? () => navigator.pop(_ConfirmationRefusalChoice.getConfirmation)
          : null,
      secondaryButtonText: l10n.verifyConfirmationSheetUseProof,
      onSecondaryPressed: () =>
          navigator.pop(_ConfirmationRefusalChoice.useProof),
    );
    if (!mounted || cubit.isClosed) return;
    switch (choice) {
      case _ConfirmationRefusalChoice.getConfirmation:
        await _openConfirmation(this.context, cubit);
      case _ConfirmationRefusalChoice.useProof:
        // The kept sign-in holds the proof form closed, and in a renewal it
        // may be for another handle than the locked one the form shows.
        cubit.cancelSignIn();
        // After the frame that opens the form, so the label is laid out
        // where it ends up.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final label = _proofSectionKey.currentContext;
          if (label == null || !label.mounted) return;
          runDetached(
            Scrollable.ensureVisible(
              label,
              duration: const Duration(milliseconds: 300),
            ),
            'scroll to the proof post',
            logName: 'VerifyConnectView',
            category: LogCategory.ui,
          );
        });
      case null:
        // Dismissed: the sign-in stays to approve or cancel.
        break;
    }
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
          if (canLeave) {
            context.safePop(fallback: const VerifyRouteData().location);
          }
        },
      ),
      body: body,
    );
  }
}

class _ConnectForm extends StatelessWidget {
  const _ConnectForm({
    required this.npub,
    required this.oauthAvailable,
    required this.confirmationSignIn,
    required this.canBuy,
    required this.proofSectionKey,
  });

  final String npub;
  final bool oauthAvailable;
  final bool confirmationSignIn;
  final bool canBuy;
  final GlobalKey proofSectionKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<VerifyConnectCubit>().state;
    final signedInAccount = state.signedInAccount;
    // The card takes the place of the start button only. Access is read
    // after the screen opens, so it can answer once a sign-in has begun:
    // the browser's start button and a returned sign-in waiting for approval
    // stay, since the person is already past the point the card speaks to.
    final upsell =
        signedInAccount == null &&
        state.status != VerifyConnectStatus.authorizing &&
        showsConfirmationUpsell(
          required: confirmationSignInRequired(
            flagOn: confirmationSignIn,
            platform: state.platform,
            oauthUsable: oauthAvailable,
          ),
          access: state.confirmationAccess,
        );
    // The upsell implies sign-in would show here (the rule needs it usable
    // and offered). Hiding the sign-in block for it lets the Bluesky field
    // and the proof post below fall back exactly as where sign-in can't run.
    final showOAuth = state.supportsOAuth && oauthAvailable && !upsell;
    // One link at a time: while a sign-in waits, the person links that
    // account or cancels it first. One already signed carries the links as
    // they were, so a proof linked meanwhile would be dropped once that
    // sign-in is published.
    final inputsEnabled = !state.isBusy && signedInAccount == null;
    // Signing in again is the sign-in alone; the proof post adds nothing to
    // it. Kept when sign-in cannot run here (iOS below 17.4, a platform
    // without it, the list still loading, or a sign-in that failed to
    // start), else the page leaves nothing that can work.
    final showProof = !(state.renewsBySignInOnly && showOAuth);
    // A renewal's proof post is made for the renewed handle, so while it is
    // on offer the field shows that handle and cannot be changed: a post
    // under another handle would add a second link beside the lapsed one.
    final lockedIdentity = showProof ? state.replacingIdentity : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (upsell) ...[
          DivineInfoCard(
            title: l10n.verifyConfirmationCardTitle,
            message: l10n.verifyConfirmationCardBody,
            icon: DivineIconName.sealCheck,
            footer: canBuy
                ? DivineButton(
                    label: l10n.verifyGetConfirmation,
                    expanded: true,
                    // Held like the start button it replaces: the screen it
                    // opens would sit where the listener pops with a claim
                    // linked meanwhile, so the dashboard would never get it.
                    onPressed: state.isBusy
                        ? null
                        : () => runDetached(
                            _openConfirmation(
                              context,
                              context.read<VerifyConnectCubit>(),
                            ),
                            'open Divine Confirmation',
                            logName: 'VerifyConnectView',
                            category: LogCategory.ui,
                          ),
                  )
                : Text(
                    l10n.verifyConfirmationStoreOnly,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
        ],
        if (showOAuth) ...[
          Text(
            l10n.verifyConnectOauthExplainer(
              verifyPlatformLabel(state.platform.key),
            ),
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          // Shown only when the verifier reports a lifetime for this
          // platform. Platforms whose links last until unlinked omit the
          // field, and then no notice shows.
          if (state.platform.signinExpiresAfterDays case final days?) ...[
            const SizedBox(height: 8),
            Text(
              l10n.verifyConnectSignInLifetime(days),
              key: const ValueKey('verify-signin-lifetime'),
              style: VineTheme.bodySmallFont(
                color: context.vineColors.mutedText,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (state.platform.key == 'bluesky') ...[
            // Same key as the copy in the proof block below: this field moves
            // between the two when appOAuthSupportProvider resolves, and the
            // key is what keeps the field, its focus and cursor across the
            // move. It has to sit on the child the list matches, not on the
            // DivineTextField inside — keying the inner field leaves this
            // element to be rebuilt by position as a new field. It stays while
            // a sign-in waits for the same reason: a cancel brings back the
            // start button, and the handle has to still be in the field.
            _IdentityField(
              key: const ValueKey('verify-identity-field'),
              state: state,
              enabled: inputsEnabled,
              lockedIdentity: lockedIdentity,
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
        if (showProof) ...[
          // With the offer card in place of the sign-in button, the proof post
          // is the only way in, so its heading says it is always available.
          _SectionLabel(
            upsell
                ? l10n.verifyProofAlwaysAvailable
                : l10n.verifyConnectProofTitle,
            key: proofSectionKey,
          ),
          // Bluesky's note says a sign-in above is all it takes. That reads
          // wrong while a sign-in is held (the card still asks to link the
          // account), so the note is hidden then. It also reads wrong under
          // the offer card, where there is no sign-in above, so that state
          // gets the generic note.
          if (!(signedInAccount != null &&
              state.platform.key == 'bluesky')) ...[
            Text(
              upsell && state.platform.key == 'bluesky'
                  ? l10n.verifyConnectProofExplainer
                  : verifyProofExplainer(l10n, state.platform.key),
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
              lockedIdentity: lockedIdentity,
            ),
            const SizedBox(height: 12),
          ],
          // Keyed because the account field above is inserted and removed as
          // the typed proof starts and stops parsing. Without a key the list
          // matches these children by position, so the shift hands this slot
          // to a different widget, the field is rebuilt from scratch, and the
          // text and the keyboard go with it.
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
      ],
    );
  }
}

class _IdentityField extends StatefulWidget {
  const _IdentityField({
    required this.state,
    required this.enabled,
    this.lockedIdentity,
    super.key,
  });

  final VerifyConnectState state;
  final bool enabled;

  /// The handle this field is fixed to, shown and not editable. Null while
  /// the handle can be typed.
  final String? lockedIdentity;

  @override
  State<_IdentityField> createState() => _IdentityFieldState();
}

class _IdentityFieldState extends State<_IdentityField> {
  // Seeded from the cubit's handle when this field is built, which is the
  // linked one when a sign-in is renewed. From then on the typing feeds the
  // cubit.
  late final _controller = TextEditingController(
    text: widget.lockedIdentity ?? widget.state.identity,
  );

  @override
  void didUpdateWidget(_IdentityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The field outlives the lock coming on (Bluesky keeps it across a failed
    // start), so a handle typed before then is replaced by the locked one.
    final locked = widget.lockedIdentity;
    if (locked != null && _controller.text != locked) {
      _controller.text = locked;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformKey = widget.state.platform.key;
    return DivineTextField(
      controller: _controller,
      labelText: verifyIdentityFieldLabel(context.l10n, platformKey),
      hintText: verifyIdentityHint(platformKey),
      filled: true,
      enabled: widget.enabled && widget.lockedIdentity == null,
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
  const _SectionLabel(this.text, {super.key});

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
