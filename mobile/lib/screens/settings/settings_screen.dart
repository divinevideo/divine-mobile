// ABOUTME: Task-based settings hub and account destination.
// ABOUTME: Shares the account switcher and urgent account warnings across both views.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart'
    show SessionExpiredException;
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/settings_account/settings_account_cubit.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/developer_mode_tap_provider.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/providers/swap_account.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/settings/account/change_email_screen.dart';
import 'package:openvine/screens/settings/account/change_password_screen.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/privacy_settings_screen.dart';
import 'package:openvine/screens/settings/settings_categories_screen.dart';
import 'package:openvine/screens/verify/verify_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/deferred_login_options_navigator.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/utils/user_identifier_line_resolver.dart';
import 'package:openvine/widgets/supporter_membership.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unified_logger/unified_logger.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  static const routeName = 'settings';
  static const String path = RoutePaths.settings;

  const SettingsScreen({this.accountOnly = false, super.key});

  /// Reuses the account switcher for the Account destination and deep links.
  final bool accountOnly;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';
  late final SettingsAccountCubit _accountCubit;
  final _deferredLoginOptionsNavigator = DeferredLoginOptionsNavigator();

  @override
  void initState() {
    super.initState();
    unawaited(_loadAppVersion());
    _accountCubit = SettingsAccountCubit(
      authService: ref.read(authServiceProvider),
      draftStorageService: ref.read(draftStorageServiceProvider),
      featureFlagService: ref.read(featureFlagServiceProvider),
    );
    runDetached(
      _accountCubit.load(),
      'load account settings',
      logName: 'SettingsScreen',
      category: LogCategory.ui,
    );
  }

  @override
  void dispose() {
    _deferredLoginOptionsNavigator.dispose();
    runDetached(
      _accountCubit.close(),
      'close account settings',
      logName: 'SettingsScreen',
      category: LogCategory.ui,
    );
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _handleSessionExpired() async {
    final authService = ref.read(authServiceProvider);
    final refreshed = await authService.tryRefreshExpiredSession();
    if (!mounted) return;
    if (refreshed) return;

    _deferredLoginOptionsNavigator.goAfterUploadsComplete(
      context: context,
      publishBloc: context.read(),
    );
  }

  /// Confirmation sheet shown before an account switch that would disturb
  /// unfinished work, or that has to sign the current account out to recover
  /// the target one. Returns true when the user chose to proceed.
  Future<bool> _confirmSwitch({
    required String title,
    required String message,
    required String confirmLabel,
    DivineButtonType confirmType = DivineButtonType.error,
  }) async {
    final navigator = Navigator.of(context);
    final proceed = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: title,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            message,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: context.l10n.settingsCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => navigator.pop(false),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: confirmLabel,
                  type: confirmType,
                  expanded: true,
                  onPressed: () => navigator.pop(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return proceed ?? false;
  }

  /// Offers a fresh sign-in when [account]'s stored credentials turn out to be
  /// unusable — an OAuth session with nothing left to refresh from, or a
  /// restore that resolved to a different identity.
  ///
  /// The in-place swap cannot recover on its own: it needs credentials that
  /// already work. Recovery is the route the welcome flow takes for these same
  /// two failures — remember the account, sign out, and let the router land on
  /// the welcome screen with that account pre-selected. Signing the working
  /// account out is the user's call, so it is confirmed first.
  Future<void> _offerReauthentication(
    KnownAccount account,
    Object error,
  ) async {
    Log.warning(
      'Account switch to ${pubkeyForLogs(account.pubkeyHex)} has no usable session '
      '($error) — offering re-authentication',
      name: 'SettingsScreen',
      category: LogCategory.auth,
    );
    if (!mounted) return;
    final isRestoreFailure = error is AccountRestoreFailedException;
    final proceed = await _confirmSwitch(
      title: isRestoreFailure
          ? context.l10n.settingsAccountRestoreFailed
          : context.l10n.settingsSessionExpired,
      message: isRestoreFailure
          ? context.l10n.settingsAccountRestoreFailedSwitchMessage
          : context.l10n.settingsSessionExpiredSwitchMessage,
      confirmLabel: context.l10n.authSignInTitle,
      confirmType: DivineButtonType.primary,
    );
    if (!proceed || !mounted) return;

    final authService = ref.read(authServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final cleanupFailedMessage = context.l10n.authAccountCleanupFailed;
    final previousPendingTarget = authService.pendingAccountSwitchPubkey;
    final leavingOwner = authService.currentPublicKeyHex;
    final leavingIdentity = authService.currentIdentity;
    final leavingReceipt = authService.committedAccountActivationReceipt;
    authService.pendingAccountSwitchPubkey = account.pubkeyHex;
    try {
      await authService.signOut();
    } catch (error, stackTrace) {
      Log.error(
        'Account reauthentication could not complete sign-out',
        name: 'SettingsScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted &&
          identical(ref.read(authServiceProvider), authService) &&
          authService.isAuthenticated &&
          leavingOwner != null &&
          authService.currentPublicKeyHex == leavingOwner &&
          identical(authService.currentIdentity, leavingIdentity) &&
          authService.pendingAccountSwitchPubkey == account.pubkeyHex) {
        final receipt = authService.committedAccountActivationReceipt;
        if (receipt == null || identical(receipt, leavingReceipt)) {
          authService.pendingAccountSwitchPubkey = previousPendingTarget;
        }
      }
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(cleanupFailedMessage, error: true),
      );
    }
  }

  Future<bool> _parkUploadsBeforeAccountChange(
    BackgroundPublishBloc publishBloc,
  ) async {
    try {
      await publishBloc.parkInFlight();
      return true;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to park uploads before account change',
        name: 'SettingsScreen',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.settingsAccountSwitchFailed,
          error: true,
        ),
      );
      return false;
    }
  }

  Future<void> _handleSwitchAccount() async {
    final accountState = _accountCubit.state;
    final publishBloc = context.read<BackgroundPublishBloc>();

    // An in-flight upload cannot survive the switch — the leaving account's
    // container owns the UploadManager and is torn down. Say so here; the
    // videos are parked back as drafts of the account they were recorded on
    // only once a target account is actually picked, since confirming this
    // sheet still leaves the user free to back out of the picker below.
    final inFlightCount = publishBloc.state.uploads
        .where((upload) => upload.result == null)
        .length;
    if (inFlightCount > 0) {
      final proceed = await _confirmSwitch(
        title: context.l10n.settingsUploadInProgressTitle,
        message: context.l10n.settingsUploadInProgressMessage(inFlightCount),
        confirmLabel: context.l10n.settingsSwitchAnyway,
      );
      if (!proceed) return;
    } else if (accountState.hasDrafts) {
      final proceed = await _confirmSwitch(
        title: context.l10n.settingsUnsavedDraftsTitle,
        message: context.l10n.settingsUnsavedDraftsMessage(
          accountState.draftCount,
        ),
        confirmLabel: context.l10n.settingsSwitchAnyway,
      );
      if (!proceed) return;
    }

    if (!mounted) return;

    final navigator = Navigator.of(context);
    await VineBottomSheet.show<void>(
      context: context,
      children: [
        ...accountState.accounts.map(
          (account) => _AccountSwitchTile(
            account: account,
            isCurrentAccount: account.pubkeyHex == accountState.currentPubkey,
            onTap: () async {
              navigator.pop();
              if (account.pubkeyHex == accountState.currentPubkey) return;

              // Park now that a switch is actually committed, and await it:
              // `swapAccount` disposes the container this bloc lives in, so a
              // fire-and-forget event would race the teardown and lose the
              // video. Parking reads the queue now rather than reusing the ids
              // the warning was built from, so an upload that finished while
              // the picker was open is left alone.
              if (!await _parkUploadsBeforeAccountChange(publishBloc)) return;
              if (!mounted) return;

              final deviceScope = ref.read(deviceScopeProvider);
              try {
                // In-place swap: no sign-out, no welcome-screen bounce. On
                // failure the current account is left untouched.
                await swapAccount(
                  deviceScope: deviceScope,
                  controller: deviceScope.switchController,
                  currentAuthService: ref.read(authServiceProvider),
                  account: account,
                );
              } on SessionExpiredException catch (e) {
                await _offerReauthentication(account, e);
              } on AccountRestoreFailedException catch (e) {
                await _offerReauthentication(account, e);
              } on UserDataCleanupException {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  DivineSnackbarContainer.snackBar(
                    context.l10n.authAccountCleanupFailed,
                    error: true,
                  ),
                );
              } catch (e, stackTrace) {
                Log.error(
                  'Account switch failed',
                  name: 'SettingsScreen',
                  error: e,
                  stackTrace: stackTrace,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  DivineSnackbarContainer.snackBar(
                    context.l10n.settingsAccountSwitchFailed,
                    error: true,
                  ),
                );
              }
            },
          ),
        ),
        _AddAccountTile(
          onTap: () async {
            navigator.pop();

            // Adding an account ends this session too — `addNewAccount` signs
            // out to reach the sign-in flow. It keeps the local rows, but an
            // in-flight upload's copy would be stranded at
            // `PublishStatus.publishing`, which the drafts library filters out,
            // so the video would be missing from both the queue and the library
            // until a later launch swept it up. Park it for the same reason the
            // switch above does, under the same warning this sheet opened with.
            if (!await _parkUploadsBeforeAccountChange(publishBloc)) return;
            if (!mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            final cleanupFailedMessage = context.l10n.authAccountCleanupFailed;
            try {
              await _accountCubit.addNewAccount();
            } catch (error, stackTrace) {
              Log.error(
                'Adding an account could not complete sign-out',
                name: 'SettingsScreen',
                error: error,
                stackTrace: stackTrace,
              );
              if (!messenger.mounted) return;
              messenger.showSnackBar(
                DivineSnackbarContainer.snackBar(
                  cleanupFailedMessage,
                  error: true,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final accountEnforced = ref.watch(isAccountEnforcedProvider);
    final authState = ref.watch(currentAuthStateProvider);
    final isAuthenticated = authState == AuthState.authenticated;
    final accountSwitchingEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.accountSwitching),
    );
    final supporterVerificationAvailable = ref.watch(
      supporterApiConfiguredProvider,
    );
    return BlocProvider.value(
      value: _accountCubit,
      child: Scaffold(
        appBar: DiVineAppBar(
          title: widget.accountOnly
              ? context.l10n.settingsAccountTitle
              : context.l10n.settingsTitle,
          showBackButton: true,
          onBackPressed: widget.accountOnly
              ? () => context.safePop(fallback: RoutePaths.settings)
              : context.safePop,
        ),
        backgroundColor: context.vineColors.surface,
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              children: [
                // Account header
                if (isAuthenticated) ...[
                  _AccountHeader(
                    onSwitchAccount: _handleSwitchAccount,
                    accountSwitchingEnabled: accountSwitchingEnabled,
                  ),
                  if (authService.isAnonymous)
                    DivineListTile(
                      icon: DivineIconName.shieldCheck,
                      title: context.l10n.settingsSecureAccount,
                      onTap: () => context.push(SecureAccountScreen.path),
                    ),
                  if (!authService.isAnonymous &&
                      authService.hasExpiredOAuthSession)
                    DivineListTile(
                      icon: DivineIconName.arrowClockwise,
                      title: context.l10n.settingsSessionExpired,
                      subtitle: context.l10n.settingsSessionExpiredSubtitle,
                      onTap: _handleSessionExpired,
                      iconColor: VineTheme.accentOrange,
                    ),
                  if (accountEnforced)
                    DivineListTile(
                      icon: DivineIconName.userFocus,
                      title: context.l10n.accountStatusTitle,
                      subtitle:
                          context.l10n.accountStatusTileSubtitleRestricted,
                      iconColor: VineTheme.accentOrange,
                      onTap: () => context.push(AccountStatusScreen.path),
                    ),
                ],

                if (widget.accountOnly) ...[
                  if (!isAuthenticated)
                    DivineListTile(
                      icon: DivineIconName.userPlus,
                      title: context.l10n.authSignInTitle,
                      onTap: () => context.go(WelcomeScreen.path),
                    ),
                  if (isAuthenticated &&
                      authService.authenticationSource ==
                          AuthenticationSource.divineOAuth) ...[
                    DivineListTile(
                      icon: DivineIconName.envelope,
                      title: context.l10n.accountSettingsChangeEmail,
                      subtitle: context.l10n.accountSettingsChangeEmailSubtitle,
                      onTap: () => context.push(ChangeEmailScreen.path),
                    ),
                    DivineListTile(
                      icon: DivineIconName.lockSimple,
                      title: context.l10n.accountSettingsChangePassword,
                      subtitle:
                          context.l10n.accountSettingsChangePasswordSubtitle,
                      onTap: () => context.push(ChangePasswordScreen.path),
                    ),
                  ],
                  if (isAuthenticated)
                    DivineListTile(
                      icon: DivineIconName.sealCheck,
                      title: context.l10n.verifyTitle,
                      subtitle: context.l10n.verifyIntro,
                      onTap: () => context.pushNamed(VerifyPage.routeName),
                    ),
                  if (supporterVerificationAvailable)
                    const SupporterMembership(),
                  const NostrAccountSettingsSection(),
                ] else ...[
                  DivineListTile(
                    icon: DivineIconName.userFocus,
                    title: context.l10n.settingsAccountTitle,
                    subtitle: context.l10n.settingsAccountSubtitle,
                    semanticIdentifier: SemanticIds.settingsAccountRow,
                    onTap: () => context.push(RoutePaths.settingsAccount),
                  ),
                  DivineListTile(
                    icon: DivineIconName.play,
                    title: context.l10n.settingsWhatYouSeeTitle,
                    subtitle: context.l10n.settingsWhatYouSeeSubtitle,
                    onTap: () => context.push(ViewingSettingsScreen.path),
                  ),
                  DivineListTile(
                    icon: DivineIconName.cameraRetro,
                    title: context.l10n.settingsCreateShareTitle,
                    subtitle: context.l10n.settingsCreateShareSubtitle,
                    onTap: () => context.push(CreatingSettingsScreen.path),
                  ),
                  DivineListTile(
                    icon: DivineIconName.bellSimple,
                    title: context.l10n.settingsNotifications,
                    onTap: () => context.push(NotificationSettingsScreen.path),
                  ),
                  DivineListTile(
                    icon: DivineIconName.shieldCheck,
                    title: context.l10n.settingsPrivacySafetyTitle,
                    subtitle: context.l10n.settingsPrivacySafetySubtitle,
                    onTap: () => context.push(PrivacySettingsScreen.path),
                  ),
                  DivineListTile(
                    icon: DivineIconName.sun,
                    title: context.l10n.settingsAppPreferencesTitle,
                    subtitle: context.l10n.settingsAppPreferencesSubtitle,
                    semanticIdentifier: SemanticIds.settingsAppPreferencesRow,
                    onTap: () =>
                        context.push(AppPreferencesSettingsScreen.path),
                  ),
                  DivineListTile(
                    icon: DivineIconName.graph,
                    title: context.l10n.settingsConnectionsTitle,
                    subtitle: context.l10n.settingsConnectionsSubtitle,
                    semanticIdentifier: SemanticIds.settingsConnectionsRow,
                    onTap: () => context.push(ConnectionsSettingsScreen.path),
                  ),
                  DivineListTile(
                    icon: DivineIconName.question,
                    title: context.l10n.settingsHelpAboutTitle,
                    subtitle: context.l10n.settingsHelpAboutSubtitle,
                    onTap: () => context.push(HelpAboutSettingsScreen.path),
                  ),
                ],
                const SizedBox(height: 24),
                _VersionTile(appVersion: _appVersion),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.onSwitchAccount,
    required this.accountSwitchingEnabled,
  });

  final VoidCallback onSwitchAccount;
  final bool accountSwitchingEnabled;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsAccountCubit, SettingsAccountState>(
      builder: (context, accountState) {
        final pubkey = accountState.currentPubkey;
        if (pubkey == null) return const SizedBox.shrink();

        final hasMultipleAccounts = accountState.hasMultipleAccounts;
        final buttonLabel = hasMultipleAccounts
            ? context.l10n.settingsSwitchAccount
            : context.l10n.settingsAddAnotherAccount;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            spacing: 16,
            children: [
              _AccountHeaderProfile(pubkey: pubkey),
              const _ShareDivineButton(),
              if (accountSwitchingEnabled)
                Semantics(
                  button: true,
                  label: buttonLabel,
                  identifier: SemanticIds.settingsAccountSwitchAction,
                  child: InkWell(
                    onTap: onSwitchAccount,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.vineColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.vineColors.outlineMuted,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          if (!hasMultipleAccounts)
                            DivineIcon(
                              icon: DivineIconName.userPlus,
                              color: context.vineColors.accentPositive,
                            ),
                          Text(
                            buttonLabel,
                            style: VineTheme.titleMediumFont(
                              color: context.vineColors.accentPositive,
                            ),
                          ),
                          if (hasMultipleAccounts)
                            DivineIcon(
                              icon: DivineIconName.caretDown,
                              color: context.vineColors.accentPositive,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ShareDivineButton extends StatelessWidget {
  const _ShareDivineButton();

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.settingsShareDivine;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () => showShareSheet(
          context,
          ShareParams(text: AppConstants.downloadUrl),
        ),
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.vineColors.outlineMuted,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                DivineIcon(
                  icon: DivineIconName.shareNetwork,
                  color: context.vineColors.accentPositive,
                ),
                // A sentence-length label, unlike the single word this slot
                // used to hold: it has to wrap rather than overflow the pill
                // on a narrow phone or at a large text scale.
                Flexible(
                  child: Text(
                    label,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.accentPositive,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile avatar, name, and identifier for the account header.
///
/// Uses Riverpod providers for reactive profile data while the parent
/// [_AccountHeader] reads account state from the Cubit.
class _AccountHeaderProfile extends ConsumerWidget {
  const _AccountHeaderProfile({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey);

    final claimedNip05 = profile?.displayNip05;
    final verificationStatus = claimedNip05 != null && claimedNip05.isNotEmpty
        ? ref
              .watch(nip05VerificationProvider(pubkey))
              .whenOrNull(data: (status) => status)
        : null;
    // Always the signed-in account, so a failed check never hides the handle:
    // the owner needs to see what they claimed in order to fix it.
    //
    // No social proof either. This line answers "which account am I signed in
    // as", and the owner's own follower count does not identify an account —
    // passing it would shadow the npub below for everyone with a follower.
    final uniqueIdentifier =
        resolveUserIdentifierLine(
          l10n: context.l10n,
          locale: Localizations.localeOf(context).toLanguageTag(),
          handle: claimedNip05,
          verificationStatus: verificationStatus,
          isOwnProfile: true,
        ) ??
        NostrKeyUtils.npubOrHex(pubkey);

    return Column(
      children: [
        UserAvatar(
          imageUrl: profile?.picture,
          name: displayName,
          placeholderSeed: pubkey,
          size: 96,
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: VineTheme.headlineSmallFont(
            color: context.vineColors.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          uniqueIdentifier,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile({required String appVersion}) : _appVersion = appVersion;

  final String _appVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeveloperMode = ref.watch(isDeveloperModeEnabledProvider);
    final environmentService = ref.watch(environmentServiceProvider);
    // Watch the tap counter to keep the auto-dispose provider alive
    // between taps while this widget is mounted.
    ref.watch(developerModeTapCounterProvider);

    return Semantics(
      button: true,
      label: context.l10n.settingsAppVersionLabel,
      child: InkWell(
        onTap: () async {
          if (isDeveloperMode) {
            ScaffoldMessenger.of(context).showSnackBar(
              DivineSnackbarContainer.snackBar(
                context.l10n.settingsDeveloperModeAlreadyEnabled,
              ),
            );
            return;
          }

          final tapCount = ref
              .read(developerModeTapCounterProvider.notifier)
              .tap();

          Log.debug(
            'Dev mode count: $tapCount',
            name: 'SettingsScreen',
            category: LogCategory.ui,
          );

          if (tapCount >= 7) {
            await environmentService.enableDeveloperMode();
            ref.read(developerModeTapCounterProvider.notifier).reset();

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                DivineSnackbarContainer.snackBar(
                  context.l10n.settingsDeveloperModeEnabled,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            return;
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _appVersion.isEmpty
                          ? context.l10n.settingsVersionEmpty
                          : context.l10n.settingsVersion(_appVersion),
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.mutedText,
                      ),
                    ),
                  ),
                ),
                const SettingsUpdateAction(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single account row in the account-switcher bottom sheet.
class _AccountSwitchTile extends ConsumerWidget {
  const _AccountSwitchTile({
    required this.account,
    required this.isCurrentAccount,
    required this.onTap,
  });

  final KnownAccount account;
  final bool isCurrentAccount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileReactiveProvider(account.pubkeyHex))
        .value;
    final displayName =
        profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(account.pubkeyHex);
    final identifier =
        profile?.displayNip05 ?? NostrKeyUtils.npubOrHex(account.pubkeyHex);

    return Semantics(
      button: true,
      label: displayName,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCurrentAccount
                  ? VineTheme.vineGreen.withValues(alpha: 0.1)
                  : VineTheme.transparent,
            ),
            child: Row(
              spacing: 12,
              children: [
                UserAvatar(
                  imageUrl: profile?.picture,
                  name: displayName,
                  placeholderSeed: account.pubkeyHex,
                  size: 40,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: VineTheme.titleMediumFont(
                          color: context.vineColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        identifier,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isCurrentAccount)
                  DivineIcon(
                    icon: DivineIconName.check,
                    color: context.vineColors.accentPositive,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Add account" row at the bottom of the account-switcher sheet.
class _AddAccountTile extends StatelessWidget {
  const _AddAccountTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.settingsAddAnotherAccount,
      identifier: SemanticIds.settingsAddAccountAction,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              spacing: 12,
              children: [
                DivineIcon(
                  icon: DivineIconName.userPlus,
                  color: context.vineColors.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    context.l10n.settingsAddAnotherAccount,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.onSurface,
                    ),
                  ),
                ),
                DivineIcon(
                  icon: DivineIconName.caretRight,
                  color: context.vineColors.accentPositive,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
