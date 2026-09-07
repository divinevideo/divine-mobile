// ABOUTME: Shows the signed-in account's enforcement state in plain language,
// ABOUTME: with the paths to contest it and to take the account elsewhere.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/account_enforcement_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:openvine/utils/mounted_post_frame.dart';

/// Account status surface for s-t-s#200.
///
/// Reachable from settings without a failed post, so a restricted user can
/// find out what happened rather than discovering it by failing repeatedly.
///
/// Renders from [AccountEnforcementKind] alone. Funnelcake deliberately omits
/// moderation reasons and administrative metadata from the self-status API.
class AccountStatusScreen extends ConsumerStatefulWidget {
  static const routeName = 'account-status';
  static const String path = RoutePaths.accountStatus;

  const AccountStatusScreen({
    this.publishRestrictionConfirmed = false,
    super.key,
  });

  /// Whether an authoritative publish response just confirmed enforcement.
  ///
  /// The publish result cannot distinguish suspended from banned, so it uses
  /// generic restriction copy while the status refresh resolves.
  final bool publishRestrictionConfirmed;

  @override
  ConsumerState<AccountStatusScreen> createState() =>
      _AccountStatusScreenState();
}

class _AccountStatusScreenState extends ConsumerState<AccountStatusScreen> {
  @override
  void initState() {
    super.initState();
    // Refetch on every visit. autoDispose alone is not enough: Settings stays
    // mounted underneath a pushed route and keeps watching
    // isAccountEnforcedProvider, so the status provider is never released and
    // would serve a value cached before the user was suspended. This is the
    // screen someone opens *to* check, so it must not show a stale answer.
    //
    // Guarded against unmount because a post-frame `ref` touch on a disposed
    // widget throws. Skipped entirely when nothing is cached yet (a cold deep
    // link), where the first watch has already started a fetch that
    // invalidating would only throw away and repeat.
    addPostFrameCallbackIfMounted(() {
      // Refetch anything already settled, success or failure alike: a first
      // fetch that failed (cold start offline) survives this screen's disposal
      // because Settings keeps the provider alive, and would otherwise render
      // stale on the next visit without ever retrying. Only an in-flight first
      // fetch is left alone, since invalidating would discard and repeat it.
      final current = ref.read(accountEnforcementStatusProvider);
      if (!current.isLoading) {
        ref.invalidate(accountEnforcementStatusProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(accountEnforcementStatusProvider);
    final publishRestriction = widget.publishRestrictionConfirmed
        ? AccountEnforcementKind.unknownRestriction
        : null;
    AccountEnforcementKind effectiveKind(AccountEnforcementKind kind) {
      if (kind.isEnforced || kind == AccountEnforcementKind.signedOut) {
        return kind;
      }
      return publishRestriction ?? kind;
    }

    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.accountStatusTitle,
        showBackButton: true,
        // safePop: this screen has a registered path, so it can be reached by
        // deep link with nothing beneath it to pop back to.
        onBackPressed: () => context.safePop(fallback: SettingsScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: async.when(
            // Show the spinner while refreshing rather than Riverpod's default
            // of holding the previous value on screen. A status cached before
            // the user was suspended must not remain visible while the refetch
            // is in flight; not knowing yet is the honest state.
            skipLoadingOnRefresh: false,
            loading: () => publishRestriction == null
                ? const Center(child: DivineCircularProgressIndicator())
                : _StatusBody(kind: publishRestriction),
            // Keep a confirmed restriction through a failed read so its appeal
            // and exit paths survive a bad connection. Without a confirmed
            // result, report that the lookup is indeterminate rather than
            // presenting an all-clear that Funnelcake never returned.
            error: (_, _) {
              final cachedKind = async.value?.kind;
              final retainedKind = cachedKind?.isEnforced ?? false
                  ? cachedKind
                  : publishRestriction;
              if (retainedKind == null) {
                return _UnavailableBody(
                  onRetry: () =>
                      ref.invalidate(accountEnforcementStatusProvider),
                );
              }
              return _StatusBody(
                kind: retainedKind,
                isLastKnown: true,
                onRetry: () => ref.invalidate(accountEnforcementStatusProvider),
              );
            },
            data: (status) => _StatusBody(kind: effectiveKind(status.kind)),
          ),
        ),
      ),
    );
  }
}

class _UnavailableBody extends StatelessWidget {
  const _UnavailableBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          Text(
            l10n.accountStatusUnavailableHeading,
            style: VineTheme.headlineSmallFont(color: colors.primaryText),
            textAlign: TextAlign.center,
          ),
          Text(
            l10n.accountStatusUnavailableBody,
            style: VineTheme.bodyMediumFont(color: colors.secondaryText),
            textAlign: TextAlign.center,
          ),
          DivineButton(
            label: l10n.accountStatusRetry,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({this.kind, this.isLastKnown = false, this.onRetry});

  final AccountEnforcementKind? kind;
  final bool isLastKnown;
  final VoidCallback? onRetry;

  /// Whether relay enforcement has anything to say about this account.
  ///
  /// A null kind and [AccountEnforcementKind.noRestrictionReported] mean no
  /// restriction to report; the relay reports a real one at the moment of
  /// action, so neither is worth telling the user Divine does not know.
  bool get _hasEnforcementToReport =>
      kind != null && kind != AccountEnforcementKind.noRestrictionReported;

  @override
  Widget build(BuildContext context) {
    if (!_hasEnforcementToReport) return const _AllClearBody();

    final l10n = context.l10n;
    final isEnforced = kind!.isEnforced;
    final colors = context.vineColors;
    final body = l10n.accountEnforcementBody(kind!);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.accountEnforcementHeading(kind!),
          style: VineTheme.headlineSmallFont(color: colors.primaryText),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body,
            style: VineTheme.bodyMediumFont(color: colors.primaryText),
          ),
        ],
        if (isLastKnown) ...[
          const SizedBox(height: 16),
          Text(
            l10n.accountStatusLastKnownBody,
            style: VineTheme.bodyMediumFont(color: colors.secondaryText),
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          DivineButton(
            label: l10n.accountStatusRetry,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: onRetry,
          ),
        ],
        if (isEnforced) ...[
          const SizedBox(height: 32),
          Text(
            l10n.accountStatusKeysUnaffectedHeading,
            style: VineTheme.titleMediumFont(color: colors.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.accountStatusKeysUnaffectedBody,
            style: VineTheme.bodyMediumFont(color: colors.primaryText),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.accountStatusAppealHeading,
            style: VineTheme.titleMediumFont(color: colors.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.accountStatusAppealBody,
            style: VineTheme.bodyMediumFont(color: colors.primaryText),
          ),
          const SizedBox(height: 16),
          DivineButton(
            label: l10n.accountStatusContactSupport,
            expanded: true,
            onPressed: () => context.push(SupportCenterScreen.path),
          ),
          const SizedBox(height: 8),
          DivineButton(
            label: l10n.accountStatusMoveAccount,
            type: DivineButtonType.secondary,
            expanded: true,
            // openExternalLink rather than a raw launchUrl: it checks the URL
            // can be handled and routes divine.video links in-app, so the exit
            // path does not silently do nothing on a device without a browser.
            onPressed: () =>
                openExternalLink(context, AppConstants.accountPortabilityUrl),
          ),
        ],
      ],
    );
  }
}

/// Shown when there is no restriction to report.
///
/// Sticker and heading only. A second line here could only describe how
/// Divine checks an account, and the screen exists to stay out of that.
class _AllClearBody extends StatelessWidget {
  const _AllClearBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 24,
        children: [
          // Decorative: the heading below carries the whole message.
          ExcludeSemantics(
            child: SvgPicture.asset(
              'assets/stickers/hang_loose.svg',
              height: 132,
              width: 132,
            ),
          ),
          Text(
            context.l10n.accountStatusAllClearHeading,
            style: VineTheme.headlineSmallFont(
              color: context.vineColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
