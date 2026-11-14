// ABOUTME: Settings-cluster routes (settings, apps-adjacent settings, diagnostics, dev)
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:badge_repository/badge_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/router/go_router_page_name.dart';
import 'package:openvine/router/ios_modal_page.dart';
import 'package:openvine/router/providers/support_route_trail_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/dm_inbox_prototype_routes.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/badges/badge_award_screen.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/screens/badges/badge_editor_screen.dart';
import 'package:openvine/screens/badges/badge_videos_screen.dart';
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
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';
import 'package:openvine/screens/settings/appearance_settings_screen.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/crossposting_settings_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/monetization_links_settings_screen.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/privacy_settings_screen.dart';
import 'package:openvine/screens/settings/settings_categories_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/signature_verification_policy_screen.dart';
import 'package:openvine/screens/settings/storage/storage_management_page.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';

part 'settings_routes.g.dart';

/// The settings screens, with the badge, support and diagnostics routes.
///
/// The debug-only DM inbox prototype is appended after the generated routes.
/// It cannot be interleaved without naming every generated route, and no
/// other route here can capture its path.
List<RouteBase> settingsRoutes() => [
  ...$appRoutes,
  // A const gate here, not only the default parameter, is what lets a
  // release build drop the prototype's code and fixtures entirely.
  if (kDebugMode) ...dmInboxPrototypeRoutes(),
];

/// The Settings hub, with the feature-flag screen nested under it so back
/// from a cold entry returns to Settings.
@TypedGoRoute<SettingsRouteData>(
  path: SettingsScreen.path,
  name: SettingsScreen.routeName,
  routes: [
    TypedGoRoute<FeatureFlagRouteData>(
      path: FeatureFlagScreen.subpath,
      name: FeatureFlagScreen.routeName,
    ),
  ],
)
class SettingsRouteData extends GoRouteData with $SettingsRouteData {
  const SettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsScreen();
}

class FeatureFlagRouteData extends GoRouteData with $FeatureFlagRouteData {
  const FeatureFlagRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const FeatureFlagScreen();
}

/// The Account destination: the Settings screen showing only the account
/// switcher.
@TypedGoRoute<SettingsAccountRouteData>(
  path: RoutePaths.settingsAccount,
  name: SettingsScreen.accountRouteName,
)
class SettingsAccountRouteData extends GoRouteData
    with $SettingsAccountRouteData {
  const SettingsAccountRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsScreen(accountOnly: true);
}

@TypedGoRoute<ViewingSettingsRouteData>(
  path: ViewingSettingsScreen.path,
  name: ViewingSettingsScreen.routeName,
)
class ViewingSettingsRouteData extends GoRouteData
    with $ViewingSettingsRouteData {
  const ViewingSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ViewingSettingsScreen();
}

@TypedGoRoute<AppPreferencesSettingsRouteData>(
  path: AppPreferencesSettingsScreen.path,
  name: AppPreferencesSettingsScreen.routeName,
)
class AppPreferencesSettingsRouteData extends GoRouteData
    with $AppPreferencesSettingsRouteData {
  const AppPreferencesSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AppPreferencesSettingsScreen();
}

@TypedGoRoute<CreatingSettingsRouteData>(
  path: CreatingSettingsScreen.path,
  name: CreatingSettingsScreen.routeName,
)
class CreatingSettingsRouteData extends GoRouteData
    with $CreatingSettingsRouteData {
  const CreatingSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const CreatingSettingsScreen();
}

@TypedGoRoute<ConnectionsSettingsRouteData>(
  path: ConnectionsSettingsScreen.path,
  name: ConnectionsSettingsScreen.routeName,
)
class ConnectionsSettingsRouteData extends GoRouteData
    with $ConnectionsSettingsRouteData {
  const ConnectionsSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ConnectionsSettingsScreen();
}

/// The Nostr settings reached from Connections, without the account actions.
@TypedGoRoute<NostrNetworkSettingsRouteData>(
  path: RoutePaths.settingsNostrNetwork,
  name: NostrSettingsScreen.networkRouteName,
)
class NostrNetworkSettingsRouteData extends GoRouteData
    with $NostrNetworkSettingsRouteData {
  const NostrNetworkSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NostrSettingsScreen(networkOnly: true);
}

@TypedGoRoute<HelpAboutSettingsRouteData>(
  path: HelpAboutSettingsScreen.path,
  name: HelpAboutSettingsScreen.routeName,
)
class HelpAboutSettingsRouteData extends GoRouteData
    with $HelpAboutSettingsRouteData {
  const HelpAboutSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const HelpAboutSettingsScreen();
}

@TypedGoRoute<BadgesRouteData>(
  path: BadgesScreen.path,
  name: BadgesScreen.routeName,
)
class BadgesRouteData extends GoRouteData with $BadgesRouteData {
  const BadgesRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const BadgesScreen();
}

/// The badge editor with no badge, which creates one.
@TypedGoRoute<BadgeCreateRouteData>(
  path: BadgeEditorScreen.createPath,
  name: BadgeEditorScreen.createRouteName,
)
class BadgeCreateRouteData extends GoRouteData with $BadgeCreateRouteData {
  const BadgeCreateRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const BadgeEditorScreen();
}

@TypedGoRoute<BadgeDetailRouteData>(
  path: BadgeDetailScreen.path,
  name: BadgeDetailScreen.routeName,
)
class BadgeDetailRouteData extends GoRouteData with $BadgeDetailRouteData {
  const BadgeDetailRouteData({required this.naddr});

  final String naddr;

  @override
  Widget build(BuildContext context, GoRouterState state) => _badgeScreen(
    naddr,
    (coordinate) => BadgeDetailScreen(coordinate: coordinate),
  );
}

/// Videos from a badge’s accepted holders, with optional in-session holder data.
@TypedGoRoute<BadgeVideosRouteData>(
  path: BadgeVideosScreen.path,
  name: BadgeVideosScreen.routeName,
)
class BadgeVideosRouteData extends GoRouteData with $BadgeVideosRouteData {
  const BadgeVideosRouteData({required this.naddr, this.$extra});

  final String naddr;
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => _badgeScreen(
    naddr,
    (coordinate) => BadgeVideosScreen(
      coordinate: coordinate,
      seed: extraAs<BadgeVideosSeed>($extra),
    ),
  );
}

@TypedGoRoute<BadgeEditRouteData>(
  path: BadgeEditorScreen.editPath,
  name: BadgeEditorScreen.editRouteName,
)
class BadgeEditRouteData extends GoRouteData with $BadgeEditRouteData {
  const BadgeEditRouteData({required this.naddr});

  final String naddr;

  @override
  Widget build(BuildContext context, GoRouterState state) => _badgeScreen(
    naddr,
    (coordinate) => BadgeEditorScreen(coordinate: coordinate),
  );
}

@TypedGoRoute<BadgeAwardRouteData>(
  path: BadgeAwardScreen.path,
  name: BadgeAwardScreen.routeName,
)
class BadgeAwardRouteData extends GoRouteData with $BadgeAwardRouteData {
  const BadgeAwardRouteData({required this.naddr});

  final String naddr;

  @override
  Widget build(BuildContext context, GoRouterState state) => _badgeScreen(
    naddr,
    (coordinate) => BadgeAwardScreen(coordinate: coordinate),
  );
}

/// Builds a badge route's screen from its `naddr` path parameter.
///
/// A reference that does not decode to a badge definition coordinate — a
/// truncated share link, or an `naddr` for another kind — falls back to the
/// badge dashboard rather than rendering an empty screen.
Widget _badgeScreen(
  String naddr,
  Widget Function(BadgeCoordinate coordinate) builder,
) {
  final coordinate = BadgeCoordinate.tryParse(naddr);
  if (coordinate == null) return const BadgesScreen();
  return builder(coordinate);
}

@TypedGoRoute<AccountStatusRouteData>(
  path: AccountStatusScreen.path,
  name: AccountStatusScreen.routeName,
)
class AccountStatusRouteData extends GoRouteData with $AccountStatusRouteData {
  const AccountStatusRouteData({this.$extra});

  /// `true` when a rejected publish has just confirmed the restriction, read
  /// through [extraAs]; absent after a deep link, which opens unconfirmed.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AccountStatusScreen(
        publishRestrictionConfirmed: extraAs<bool>($extra) == true,
      );
}

/// The Support Center, which anyone may open, signed in or not.
@TypedGoRoute<SupportCenterRouteData>(
  path: SupportCenterScreen.path,
  name: SupportCenterScreen.routeName,
)
class SupportCenterRouteData extends GoRouteData with $SupportCenterRouteData {
  const SupportCenterRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SupportCenterScreen();
}

/// The bug report form, with the screens visited before Support was opened.
@TypedGoRoute<BugReportRouteData>(
  path: BugReportScreen.path,
  name: BugReportScreen.routeName,
)
class BugReportRouteData extends GoRouteData with $BugReportRouteData {
  const BugReportRouteData({
    @TypedQueryParameter(name: RoutePaths.supportReportBugEntryParameter)
    this.entry,
  });

  /// How the form was opened; [RoutePaths.supportReportBugProfileHoldEntry]
  /// marks the Profile-tab hold, and the form then skips its tip about it.
  final String? entry;

  /// Presents as a full-screen modal on iOS, so the edge swipe cannot dismiss
  /// a half-written report.
  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    // A typed route has no `Ref`, so the providers are read through the tree.
    final container = ProviderScope.containerOf(context, listen: false);
    final routeSnapshot = container
        .read(supportRouteTrailProvider.notifier)
        .snapshot;
    return iosModalPage(
      state: state,
      child: BugReportScreen(
        bugReportService: container.read(bugReportServiceProvider),
        currentScreen: routeSnapshot.currentScreen,
        recentScreens: routeSnapshot.recentScreens,
        userPubkey: container.read(authServiceProvider).currentPublicKeyHex,
        showProfileHoldTip:
            entry != RoutePaths.supportReportBugProfileHoldEntry,
      ),
    );
  }
}

@TypedGoRoute<FeatureRequestRouteData>(
  path: FeatureRequestScreen.path,
  name: FeatureRequestScreen.routeName,
)
class FeatureRequestRouteData extends GoRouteData
    with $FeatureRequestRouteData {
  const FeatureRequestRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      FeatureRequestScreen(
        userPubkey: ProviderScope.containerOf(
          context,
          listen: false,
        ).read(authServiceProvider).currentPublicKeyHex,
      );
}

@TypedGoRoute<LegalRouteData>(
  path: LegalScreen.path,
  name: LegalScreen.routeName,
)
class LegalRouteData extends GoRouteData with $LegalRouteData {
  const LegalRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LegalScreen();
}

@TypedGoRoute<ContentPreferencesRouteData>(
  path: ContentPreferencesScreen.path,
  name: ContentPreferencesScreen.routeName,
)
class ContentPreferencesRouteData extends GoRouteData
    with $ContentPreferencesRouteData {
  const ContentPreferencesRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ContentPreferencesScreen();
}

/// General Settings, with the credential screens nested under it.
@TypedGoRoute<GeneralSettingsRouteData>(
  path: GeneralSettingsScreen.path,
  name: GeneralSettingsScreen.routeName,
  routes: [
    TypedGoRoute<ChangeEmailRouteData>(
      path: ChangeEmailScreen.subpath,
      name: ChangeEmailScreen.routeName,
    ),
    TypedGoRoute<ChangePasswordRouteData>(
      path: ChangePasswordScreen.subpath,
      name: ChangePasswordScreen.routeName,
    ),
  ],
)
class GeneralSettingsRouteData extends GoRouteData
    with $GeneralSettingsRouteData {
  const GeneralSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const GeneralSettingsScreen();
}

class ChangeEmailRouteData extends GoRouteData with $ChangeEmailRouteData {
  const ChangeEmailRouteData();

  @override
  String? redirect(BuildContext context, GoRouterState state) =>
      accountCredentialsRedirectIfUnavailable(
        ProviderScope.containerOf(context, listen: false),
      );

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ChangeEmailScreen();
}

class ChangePasswordRouteData extends GoRouteData
    with $ChangePasswordRouteData {
  const ChangePasswordRouteData();

  @override
  String? redirect(BuildContext context, GoRouterState state) =>
      accountCredentialsRedirectIfUnavailable(
        ProviderScope.containerOf(context, listen: false),
      );

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ChangePasswordScreen();
}

@TypedGoRoute<AppearanceSettingsRouteData>(
  path: AppearanceSettingsScreen.path,
  name: AppearanceSettingsScreen.routeName,
)
class AppearanceSettingsRouteData extends GoRouteData
    with $AppearanceSettingsRouteData {
  const AppearanceSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AppearanceSettingsScreen();
}

@TypedGoRoute<StorageManagementRouteData>(
  path: StorageManagementPage.path,
  name: StorageManagementPage.routeName,
)
class StorageManagementRouteData extends GoRouteData
    with $StorageManagementRouteData {
  const StorageManagementRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const StorageManagementPage();
}

@TypedGoRoute<MonetizationLinksSettingsRouteData>(
  path: MonetizationLinksSettingsScreen.path,
  name: MonetizationLinksSettingsScreen.routeName,
)
class MonetizationLinksSettingsRouteData extends GoRouteData
    with $MonetizationLinksSettingsRouteData {
  const MonetizationLinksSettingsRouteData();

  @override
  String? redirect(BuildContext context, GoRouterState state) =>
      monetizationLinksRedirectIfDisabled(
        ProviderScope.containerOf(context, listen: false),
      );

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MonetizationLinksSettingsScreen();
}

@TypedGoRoute<SupporterRouteData>(
  path: SupporterScreen.path,
  name: SupporterScreen.routeName,
)
class SupporterRouteData extends GoRouteData with $SupporterRouteData {
  const SupporterRouteData();

  @override
  String? redirect(BuildContext context, GoRouterState state) =>
      supporterRedirectIfUnavailable(
        ProviderScope.containerOf(context, listen: false),
      );

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SupporterScreen();
}

@TypedGoRoute<AppLanguageRouteData>(
  path: AppLanguageScreen.path,
  name: AppLanguageScreen.routeName,
)
class AppLanguageRouteData extends GoRouteData with $AppLanguageRouteData {
  const AppLanguageRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AppLanguageScreen();
}

@TypedGoRoute<BlueskySettingsRouteData>(
  path: BlueskySettingsScreen.path,
  name: BlueskySettingsScreen.routeName,
)
class BlueskySettingsRouteData extends GoRouteData
    with $BlueskySettingsRouteData {
  const BlueskySettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const BlueskySettingsScreen();
}

@TypedGoRoute<CrosspostingSettingsRouteData>(
  path: CrosspostingSettingsScreen.path,
  name: CrosspostingSettingsScreen.routeName,
)
class CrosspostingSettingsRouteData extends GoRouteData
    with $CrosspostingSettingsRouteData {
  const CrosspostingSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const CrosspostingSettingsScreen();
}

/// The Nostr settings with the account actions, and the account screens
/// nested under it.
@TypedGoRoute<NostrSettingsRouteData>(
  path: NostrSettingsScreen.path,
  name: NostrSettingsScreen.routeName,
  routes: [
    TypedGoRoute<Nip05SettingsRouteData>(
      path: Nip05SettingsScreen.subpath,
      name: Nip05SettingsScreen.routeName,
    ),
    TypedGoRoute<SignatureVerificationPolicyRouteData>(
      path: SignatureVerificationPolicyScreen.subpath,
      name: SignatureVerificationPolicyScreen.routeName,
    ),
  ],
)
class NostrSettingsRouteData extends GoRouteData with $NostrSettingsRouteData {
  const NostrSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NostrSettingsScreen();
}

class Nip05SettingsRouteData extends GoRouteData with $Nip05SettingsRouteData {
  const Nip05SettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const Nip05SettingsScreen();
}

class SignatureVerificationPolicyRouteData extends GoRouteData
    with $SignatureVerificationPolicyRouteData {
  const SignatureVerificationPolicyRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SignatureVerificationPolicyScreen();
}

@TypedGoRoute<RelaySettingsRouteData>(
  path: RelaySettingsScreen.path,
  name: RelaySettingsScreen.routeName,
)
class RelaySettingsRouteData extends GoRouteData with $RelaySettingsRouteData {
  const RelaySettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const RelaySettingsScreen();
}

@TypedGoRoute<BlossomSettingsRouteData>(
  path: BlossomSettingsScreen.path,
  name: BlossomSettingsScreen.routeName,
)
class BlossomSettingsRouteData extends GoRouteData
    with $BlossomSettingsRouteData {
  const BlossomSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const BlossomSettingsScreen();
}

@TypedGoRoute<NotificationSettingsRouteData>(
  path: NotificationSettingsScreen.path,
  name: NotificationSettingsScreen.routeName,
)
class NotificationSettingsRouteData extends GoRouteData
    with $NotificationSettingsRouteData {
  const NotificationSettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NotificationSettingsScreen();
}

@TypedGoRoute<KeyManagementRouteData>(
  path: KeyManagementScreen.path,
  name: KeyManagementScreen.routeName,
)
class KeyManagementRouteData extends GoRouteData with $KeyManagementRouteData {
  const KeyManagementRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const KeyManagementScreen();
}

@TypedGoRoute<RelayDiagnosticRouteData>(
  path: RelayDiagnosticScreen.path,
  name: RelayDiagnosticScreen.routeName,
)
class RelayDiagnosticRouteData extends GoRouteData
    with $RelayDiagnosticRouteData {
  const RelayDiagnosticRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const RelayDiagnosticScreen();
}

@TypedGoRoute<SafetySettingsRouteData>(
  path: SafetySettingsScreen.path,
  name: SafetySettingsScreen.routeName,
)
class SafetySettingsRouteData extends GoRouteData
    with $SafetySettingsRouteData {
  const SafetySettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SafetySettingsScreen();
}

@TypedGoRoute<PrivacySettingsRouteData>(
  path: PrivacySettingsScreen.path,
  name: PrivacySettingsScreen.routeName,
)
class PrivacySettingsRouteData extends GoRouteData
    with $PrivacySettingsRouteData {
  const PrivacySettingsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const PrivacySettingsScreen();
}

@TypedGoRoute<ContentFiltersRouteData>(
  path: ContentFiltersScreen.path,
  name: ContentFiltersScreen.routeName,
)
class ContentFiltersRouteData extends GoRouteData
    with $ContentFiltersRouteData {
  const ContentFiltersRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ContentFiltersScreen();
}

@TypedGoRoute<ClipRecoveryRouteData>(
  path: ClipRecoveryScreen.path,
  name: ClipRecoveryScreen.routeName,
)
class ClipRecoveryRouteData extends GoRouteData with $ClipRecoveryRouteData {
  const ClipRecoveryRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ClipRecoveryScreen();
}

/// Developer options, which slide in from the right on a custom page.
@TypedGoRoute<DeveloperOptionsRouteData>(
  path: DeveloperOptionsScreen.path,
  name: DeveloperOptionsScreen.routeName,
)
class DeveloperOptionsRouteData extends GoRouteData
    with $DeveloperOptionsRouteData {
  const DeveloperOptionsRouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      CustomTransitionPage<void>(
        key: state.pageKey,
        name: goRouterPageName(state),
        arguments: <String, String>{
          ...state.pathParameters,
          ...state.uri.queryParameters,
        },
        restorationId: state.pageKey.value,
        child: const DeveloperOptionsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
      );
}

String? monetizationLinksRedirectIfDisabled(ProviderContainer container) {
  final enabled = container.read(
    isFeatureEnabledProvider(FeatureFlag.profileMonetizationLinks),
  );
  if (enabled) return null;
  return SettingsScreen.path;
}

String? supporterRedirectIfUnavailable(ProviderContainer container) {
  if (container.read(supporterApiConfiguredProvider)) return null;
  return SettingsScreen.path;
}

/// Keeps the email/password screens off accounts that have neither.
///
/// Only an account created through the Divine login service has credentials
/// Keycast can change; every other identity signs with a key. General Settings
/// hides the rows for them, and this closes the deep link.
String? accountCredentialsRedirectIfUnavailable(ProviderContainer container) {
  final source = container.read(authServiceProvider).authenticationSource;
  if (source == AuthenticationSource.divineOAuth) return null;
  return GeneralSettingsScreen.path;
}
