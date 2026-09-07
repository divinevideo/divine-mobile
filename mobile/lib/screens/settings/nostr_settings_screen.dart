// ABOUTME: Nostr settings hub screen for relays, media servers, keys, and account
// ABOUTME: Organizes network and account settings with danger zone actions

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_client/nostr_client.dart' show Nip89ClientTag;
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/signature_verification_policy_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:openvine/widgets/delete_account_action.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:openvine/widgets/modal_progress_overlay.dart';
import 'package:unified_logger/unified_logger.dart';

class NostrSettingsScreen extends ConsumerWidget {
  static const routeName = 'nostr-settings';
  static const String path = RoutePaths.nostrSettings;

  const NostrSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAdvancedRelaySettings = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.advancedRelaySettings),
    );
    final authState = ref.watch(currentAuthStateProvider);
    final isAuthenticated = authState == AuthState.authenticated;

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsNostrSettings,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  context.l10n.nostrSettingsIntro,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.mutedText,
                  ),
                ),
              ),

              // Network section
              DivineSectionHeader(context.l10n.nostrSettingsSectionNetwork),
              if (showAdvancedRelaySettings) ...[
                DivineListTile(
                  leading: Icon(
                    Icons.hub,
                    size: DivineIcon.scaleSize(context, 24),
                    color: context.vineColors.accentPositive,
                  ),
                  title: context.l10n.nostrSettingsRelays,
                  subtitle: context.l10n.nostrSettingsRelaysSubtitle,
                  onTap: () => context.push(RelaySettingsScreen.path),
                ),
                DivineListTile(
                  leading: Icon(
                    Icons.troubleshoot,
                    size: DivineIcon.scaleSize(context, 24),
                    color: context.vineColors.accentPositive,
                  ),
                  title: context.l10n.nostrSettingsRelayDiagnostics,
                  subtitle: context.l10n.nostrSettingsRelayDiagnosticsSubtitle,
                  onTap: () => context.push(RelayDiagnosticScreen.path),
                ),
              ],
              DivineListTile(
                leading: Icon(
                  Icons.cloud_upload,
                  size: DivineIcon.scaleSize(context, 24),
                  color: context.vineColors.accentPositive,
                ),
                title: context.l10n.nostrSettingsMediaServers,
                subtitle: context.l10n.nostrSettingsMediaServersSubtitle,
                onTap: () => context.push(BlossomSettingsScreen.path),
              ),
              const _SignatureVerificationTile(),

              // Account section
              if (isAuthenticated) ...[
                DivineSectionHeader(context.l10n.nostrSettingsSectionAccount),
                DivineListTile(
                  icon: DivineIconName.key,
                  iconColor: context.vineColors.accentPositive,
                  title: context.l10n.nostrSettingsKeyManagement,
                  subtitle: context.l10n.nostrSettingsKeyManagementSubtitle,
                  semanticIdentifier: SemanticIds.settingsKeyManagementRow,
                  onTap: () => context.push(KeyManagementScreen.path),
                ),
                const _ClientAttributionToggle(),
                DivineListTile(
                  leading: Icon(
                    Icons.alternate_email,
                    size: DivineIcon.scaleSize(context, 24),
                    color: context.vineColors.accentPositive,
                  ),
                  title: context.l10n.nostrSettingsNip05Address,
                  subtitle: context.l10n.nostrSettingsNip05AddressSubtitle,
                  onTap: () => context.pushNamed(Nip05SettingsScreen.routeName),
                ),
                DivineListTile(
                  icon: DivineIconName.downloadSimple,
                  iconColor: context.vineColors.accentPositive,
                  title: context.l10n.nostrSettingsMoveAccount,
                  subtitle: context.l10n.nostrSettingsMoveAccountSubtitle,
                  semanticIdentifier: SemanticIds.settingsMoveAccountRow,
                  onTap: () => openExternalLink(
                    context,
                    AppConstants.accountPortabilityUrl,
                  ),
                ),
                _RemoveKeysTile(ref: ref),
                DivineSectionHeader(
                  context.l10n.nostrSettingsSectionDangerZone,
                ),
                DivineListTile(
                  icon: DivineIconName.trash,
                  title: context.l10n.nostrSettingsDeleteAccount,
                  subtitle: context.l10n.nostrSettingsDeleteAccountSubtitle,
                  iconColor: VineTheme.error,
                  titleColor: VineTheme.error,
                  trailingColor: VineTheme.error,
                  onTap: () => startAccountDeletionFlow(
                    context: context,
                    ref: ref,
                    screenName: 'NostrSettingsScreen',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveKeysTile extends StatelessWidget {
  const _RemoveKeysTile({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return DivineListTile(
      leading: Icon(
        Icons.key_off,
        size: DivineIcon.scaleSize(context, 24),
        color: VineTheme.warning,
      ),
      title: context.l10n.nostrSettingsRemoveKeys,
      subtitle: context.l10n.nostrSettingsRemoveKeysSubtitle,
      semanticIdentifier: SemanticIds.settingsRemoveKeysRow,
      onTap: () => _handleRemoveLocalAccount(context, ref),
      trailingColor: VineTheme.warning,
      titleColor: VineTheme.warning,
    );
  }

  Future<void> _handleRemoveLocalAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final authService = ref.read(authServiceProvider);
    final couldNotRemoveKeysMessage =
        context.l10n.nostrSettingsCouldNotRemoveKeys;

    final confirmed = await showRemoveKeysWarningSheet(context);
    if (!confirmed || !context.mounted) return;

    // Resolved before the await: the spinner is an overlay entry, not a
    // route, so a back press during sign-out pops this screen instead of
    // the spinner. The app-level messenger outlives that pop; a
    // post-await `ScaffoldMessenger.of(context)` would not, and the user
    // would be left with no word on a key deletion that failed.
    final messenger = ScaffoldMessenger.of(context);
    final progressOverlay = ModalProgressOverlay.show(context);

    try {
      await authService.signOut(
        deleteKeys: true,
        abortOnKeyDeletionFailure: true,
      );
      progressOverlay.dismiss();
      if (!context.mounted) return;
      context.go(WelcomeScreen.path);
    } on SecureKeyStorageException {
      progressOverlay.dismiss();
      // Platform key deletion failed — user stays signed in and can
      // retry without having to log back in.
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          couldNotRemoveKeysMessage,
          error: true,
        ),
      );
    } catch (e) {
      Log.error(
        'Local account removal failed: $e',
        name: 'NostrSettingsScreen',
        category: LogCategory.ui,
      );
      progressOverlay.dismiss();
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          couldNotRemoveKeysMessage,
          error: true,
        ),
      );
    }
  }
}

class _ClientAttributionToggle extends ConsumerWidget {
  const _ClientAttributionToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(nip89ClientTagEnabledProvider);
    final enabled = enabledAsync.value ?? true;

    return DivineSwitchTile(
      leadingIcon: DivineIconName.globe,
      title: context.l10n.nostrSettingsClientAttribution,
      subtitle: context.l10n.nostrSettingsClientAttributionSubtitle,
      value: enabled,
      onChanged: enabledAsync.isLoading
          ? null
          : (value) async {
              await Nip89ClientTag.setEnabled(enabled: value);
              ref.invalidate(nip89ClientTagEnabledProvider);
            },
    );
  }
}

class _SignatureVerificationTile extends ConsumerWidget {
  const _SignatureVerificationTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(nostrSignatureVerificationPolicyProvider);

    return DivineListTile(
      icon: DivineIconName.shieldCheck,
      iconColor: context.vineColors.accentPositive,
      title: context.l10n.nostrSettingsSignatureVerification,
      subtitle: signatureVerificationPolicySubtitle(context, policy),
      onTap: () =>
          context.pushNamed(SignatureVerificationPolicyScreen.routeName),
    );
  }
}
