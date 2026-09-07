// ABOUTME: Settings-cluster routes (settings, apps-adjacent settings, diagnostics, dev)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:badge_repository/badge_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_tabs_prototype_screen.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/invite_availability_providers.dart';
import 'package:openvine/router/go_router_page_name.dart';
import 'package:openvine/router/invite_availability_redirects.dart';
import 'package:openvine/screens/badges/badge_award_screen.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/screens/badges/badge_editor_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/clip_recovery_screen.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings/account/change_email_screen.dart';
import 'package:openvine/screens/settings/account/change_password_screen.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';
import 'package:openvine/screens/settings/appearance_settings_screen.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/crossposting_settings_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/monetization_links_settings_screen.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/signature_verification_policy_screen.dart';
import 'package:openvine/screens/settings/storage/storage_management_page.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';

List<RouteBase> settingsRoutes(Ref ref) {
  return [
    GoRoute(
      path: SettingsScreen.path,
      name: SettingsScreen.routeName,
      builder: (_, _) => const SettingsScreen(),
      routes: [
        GoRoute(
          path: FeatureFlagScreen.subpath,
          name: FeatureFlagScreen.routeName,
          builder: (_, _) => const FeatureFlagScreen(),
        ),
      ],
    ),
    GoRoute(
      path: BadgesScreen.path,
      name: BadgesScreen.routeName,
      builder: (_, _) => const BadgesScreen(),
    ),
    GoRoute(
      path: BadgeEditorScreen.createPath,
      name: BadgeEditorScreen.createRouteName,
      builder: (_, _) => const BadgeEditorScreen(),
    ),
    GoRoute(
      path: BadgeDetailScreen.path,
      name: BadgeDetailScreen.routeName,
      builder: (_, state) => _badgeRouteScreen(
        state,
        (coordinate) => BadgeDetailScreen(coordinate: coordinate),
      ),
    ),
    GoRoute(
      path: BadgeEditorScreen.editPath,
      name: BadgeEditorScreen.editRouteName,
      builder: (_, state) => _badgeRouteScreen(
        state,
        (coordinate) => BadgeEditorScreen(coordinate: coordinate),
      ),
    ),
    GoRoute(
      path: BadgeAwardScreen.path,
      name: BadgeAwardScreen.routeName,
      builder: (_, state) => _badgeRouteScreen(
        state,
        (coordinate) => BadgeAwardScreen(coordinate: coordinate),
      ),
    ),
    GoRoute(
      path: InvitesScreen.path,
      name: InvitesScreen.routeName,
      redirect: (_, state) => invitesScreenRedirectIfDisabled(
        ref.read(inviteAvailabilityCubitProvider),
        state,
      ),
      builder: (_, _) => const InvitesScreen(),
    ),
    GoRoute(
      path: SupportCenterScreen.path,
      name: SupportCenterScreen.routeName,
      builder: (_, _) => const SupportCenterScreen(),
    ),
    GoRoute(
      path: BugReportScreen.path,
      name: BugReportScreen.routeName,
      builder: (_, _) => BugReportScreen(
        bugReportService: ref.read(bugReportServiceProvider),
        currentScreen: 'SupportCenterScreen',
        userPubkey: ref.read(authServiceProvider).currentPublicKeyHex,
      ),
    ),
    GoRoute(
      path: FeatureRequestScreen.path,
      name: FeatureRequestScreen.routeName,
      builder: (_, _) => FeatureRequestScreen(
        userPubkey: ref.read(authServiceProvider).currentPublicKeyHex,
      ),
    ),
    GoRoute(
      path: LegalScreen.path,
      name: LegalScreen.routeName,
      builder: (_, _) => const LegalScreen(),
    ),
    GoRoute(
      path: ContentPreferencesScreen.path,
      name: ContentPreferencesScreen.routeName,
      builder: (_, _) => const ContentPreferencesScreen(),
    ),
    GoRoute(
      path: GeneralSettingsScreen.path,
      name: GeneralSettingsScreen.routeName,
      builder: (_, _) => const GeneralSettingsScreen(),
      routes: [
        GoRoute(
          path: ChangeEmailScreen.subpath,
          name: ChangeEmailScreen.routeName,
          redirect: (_, _) => accountCredentialsRedirectIfUnavailable(ref),
          builder: (_, _) => const ChangeEmailScreen(),
        ),
        GoRoute(
          path: ChangePasswordScreen.subpath,
          name: ChangePasswordScreen.routeName,
          redirect: (_, _) => accountCredentialsRedirectIfUnavailable(ref),
          builder: (_, _) => const ChangePasswordScreen(),
        ),
      ],
    ),
    GoRoute(
      path: AppearanceSettingsScreen.path,
      name: AppearanceSettingsScreen.routeName,
      builder: (_, _) => const AppearanceSettingsScreen(),
    ),
    GoRoute(
      path: StorageManagementPage.path,
      name: StorageManagementPage.routeName,
      builder: (_, _) => const StorageManagementPage(),
    ),
    GoRoute(
      path: MonetizationLinksSettingsScreen.path,
      name: MonetizationLinksSettingsScreen.routeName,
      redirect: (_, _) => monetizationLinksRedirectIfDisabled(ref),
      builder: (_, _) => const MonetizationLinksSettingsScreen(),
    ),
    GoRoute(
      path: SupporterScreen.path,
      name: SupporterScreen.routeName,
      redirect: (_, _) => supporterRedirectIfDisabled(ref),
      builder: (_, _) => const SupporterScreen(),
    ),
    GoRoute(
      path: AppLanguageScreen.path,
      name: AppLanguageScreen.routeName,
      builder: (_, _) => const AppLanguageScreen(),
    ),
    GoRoute(
      path: BlueskySettingsScreen.path,
      name: BlueskySettingsScreen.routeName,
      builder: (_, _) => const BlueskySettingsScreen(),
    ),
    GoRoute(
      path: CrosspostingSettingsScreen.path,
      name: CrosspostingSettingsScreen.routeName,
      builder: (_, _) => const CrosspostingSettingsScreen(),
    ),
    GoRoute(
      path: NostrSettingsScreen.path,
      name: NostrSettingsScreen.routeName,
      builder: (_, _) => const NostrSettingsScreen(),
      routes: [
        GoRoute(
          path: Nip05SettingsScreen.subpath,
          name: Nip05SettingsScreen.routeName,
          builder: (_, _) => const Nip05SettingsScreen(),
        ),
        GoRoute(
          path: SignatureVerificationPolicyScreen.subpath,
          name: SignatureVerificationPolicyScreen.routeName,
          builder: (_, _) => const SignatureVerificationPolicyScreen(),
        ),
      ],
    ),
    GoRoute(
      path: RelaySettingsScreen.path,
      name: RelaySettingsScreen.routeName,
      builder: (_, _) => const RelaySettingsScreen(),
    ),
    GoRoute(
      path: BlossomSettingsScreen.path,
      name: BlossomSettingsScreen.routeName,
      builder: (_, _) => const BlossomSettingsScreen(),
    ),
    GoRoute(
      path: NotificationSettingsScreen.path,
      name: NotificationSettingsScreen.routeName,
      builder: (_, _) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: KeyManagementScreen.path,
      name: KeyManagementScreen.routeName,
      builder: (_, _) => const KeyManagementScreen(),
    ),
    GoRoute(
      path: RelayDiagnosticScreen.path,
      name: RelayDiagnosticScreen.routeName,
      builder: (_, _) => const RelayDiagnosticScreen(),
    ),
    GoRoute(
      path: SafetySettingsScreen.path,
      name: SafetySettingsScreen.routeName,
      builder: (_, _) => const SafetySettingsScreen(),
    ),
    GoRoute(
      path: ContentFiltersScreen.path,
      name: ContentFiltersScreen.routeName,
      builder: (_, _) => const ContentFiltersScreen(),
    ),
    GoRoute(
      path: ClipRecoveryScreen.path,
      name: ClipRecoveryScreen.routeName,
      builder: (_, _) => const ClipRecoveryScreen(),
    ),
    // PROTOTYPE (#8076): four-tab DM inbox on fixture data. Remove with it.
    GoRoute(
      path: DmInboxTabsPrototypeScreen.path,
      name: DmInboxTabsPrototypeScreen.routeName,
      builder: (_, _) => const DmInboxTabsPrototypeScreen(),
    ),
    GoRoute(
      path: DeveloperOptionsScreen.path,
      name: DeveloperOptionsScreen.routeName,
      pageBuilder: (_, state) => CustomTransitionPage(
        key: state.pageKey,
        name: goRouterPageName(state),
        arguments: <String, String>{
          ...state.pathParameters,
          ...state.uri.queryParameters,
        },
        restorationId: state.pageKey.value,
        child: const DeveloperOptionsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    ),
  ];
}

/// Builds a badge route's screen from its `naddr` path parameter.
///
/// A reference that does not decode to a badge definition coordinate — a
/// truncated share link, or an `naddr` for another kind — falls back to the
/// badge dashboard rather than rendering an empty screen.
Widget _badgeRouteScreen(
  GoRouterState state,
  Widget Function(BadgeCoordinate coordinate) builder,
) {
  final coordinate = BadgeCoordinate.tryParse(
    state.pathParameters['naddr'] ?? '',
  );
  if (coordinate == null) return const BadgesScreen();
  return builder(coordinate);
}

String? monetizationLinksRedirectIfDisabled(Ref ref) {
  final enabled = ref.read(
    isFeatureEnabledProvider(FeatureFlag.profileMonetizationLinks),
  );
  if (enabled) return null;
  return SettingsScreen.path;
}

String? supporterRedirectIfDisabled(Ref ref) {
  final enabled = ref.read(
    isFeatureEnabledProvider(FeatureFlag.divineSupporters),
  );
  if (enabled) return null;
  return SettingsScreen.path;
}

/// Keeps the email/password screens off accounts that have neither.
///
/// Only an account created through the Divine login service has credentials
/// Keycast can change; every other identity signs with a key. General Settings
/// hides the rows for them, and this closes the deep link.
String? accountCredentialsRedirectIfUnavailable(Ref ref) {
  final source = ref.read(authServiceProvider).authenticationSource;
  if (source == AuthenticationSource.divineOAuth) return null;
  return GeneralSettingsScreen.path;
}
