// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $settingsRouteData,
  $settingsAccountRouteData,
  $viewingSettingsRouteData,
  $appPreferencesSettingsRouteData,
  $creatingSettingsRouteData,
  $connectionsSettingsRouteData,
  $nostrNetworkSettingsRouteData,
  $helpAboutSettingsRouteData,
  $badgesRouteData,
  $badgeCreateRouteData,
  $badgeDetailRouteData,
  $badgeVideosRouteData,
  $badgeEditRouteData,
  $badgeAwardRouteData,
  $accountStatusRouteData,
  $supportCenterRouteData,
  $bugReportRouteData,
  $featureRequestRouteData,
  $legalRouteData,
  $contentPreferencesRouteData,
  $generalSettingsRouteData,
  $appearanceSettingsRouteData,
  $storageManagementRouteData,
  $monetizationLinksSettingsRouteData,
  $supporterRouteData,
  $appLanguageRouteData,
  $blueskySettingsRouteData,
  $crosspostingSettingsRouteData,
  $nostrSettingsRouteData,
  $relaySettingsRouteData,
  $blossomSettingsRouteData,
  $notificationSettingsRouteData,
  $keyManagementRouteData,
  $relayDiagnosticRouteData,
  $safetySettingsRouteData,
  $privacySettingsRouteData,
  $contentFiltersRouteData,
  $clipRecoveryRouteData,
  $developerOptionsRouteData,
];

RouteBase get $settingsRouteData => GoRouteData.$route(
  path: '/settings',
  name: 'settings',
  hasOverriddenOnExit: false,
  factory: $SettingsRouteData._fromState,
  routes: [
    GoRouteData.$route(
      path: 'feature-flags',
      name: 'feature-flags',
      hasOverriddenOnExit: false,
      factory: $FeatureFlagRouteData._fromState,
    ),
  ],
);

mixin $SettingsRouteData on GoRouteData {
  static SettingsRouteData _fromState(GoRouterState state) =>
      const SettingsRouteData();

  @override
  String get location => GoRouteData.$location('/settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $FeatureFlagRouteData on GoRouteData {
  static FeatureFlagRouteData _fromState(GoRouterState state) =>
      const FeatureFlagRouteData();

  @override
  String get location => GoRouteData.$location('/settings/feature-flags');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $settingsAccountRouteData => GoRouteData.$route(
  path: '/settings/account',
  name: 'settings-account',
  hasOverriddenOnExit: false,
  factory: $SettingsAccountRouteData._fromState,
);

mixin $SettingsAccountRouteData on GoRouteData {
  static SettingsAccountRouteData _fromState(GoRouterState state) =>
      const SettingsAccountRouteData();

  @override
  String get location => GoRouteData.$location('/settings/account');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $viewingSettingsRouteData => GoRouteData.$route(
  path: '/settings/viewing',
  name: 'settings-viewing',
  hasOverriddenOnExit: false,
  factory: $ViewingSettingsRouteData._fromState,
);

mixin $ViewingSettingsRouteData on GoRouteData {
  static ViewingSettingsRouteData _fromState(GoRouterState state) =>
      const ViewingSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/settings/viewing');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $appPreferencesSettingsRouteData => GoRouteData.$route(
  path: '/settings/app-preferences',
  name: 'settings-app-preferences',
  hasOverriddenOnExit: false,
  factory: $AppPreferencesSettingsRouteData._fromState,
);

mixin $AppPreferencesSettingsRouteData on GoRouteData {
  static AppPreferencesSettingsRouteData _fromState(GoRouterState state) =>
      const AppPreferencesSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/settings/app-preferences');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $creatingSettingsRouteData => GoRouteData.$route(
  path: '/settings/creating',
  name: 'settings-creating',
  hasOverriddenOnExit: false,
  factory: $CreatingSettingsRouteData._fromState,
);

mixin $CreatingSettingsRouteData on GoRouteData {
  static CreatingSettingsRouteData _fromState(GoRouterState state) =>
      const CreatingSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/settings/creating');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $connectionsSettingsRouteData => GoRouteData.$route(
  path: '/settings/connections',
  name: 'settings-connections',
  hasOverriddenOnExit: false,
  factory: $ConnectionsSettingsRouteData._fromState,
);

mixin $ConnectionsSettingsRouteData on GoRouteData {
  static ConnectionsSettingsRouteData _fromState(GoRouterState state) =>
      const ConnectionsSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/settings/connections');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $nostrNetworkSettingsRouteData => GoRouteData.$route(
  path: '/settings/connections/nostr',
  name: 'settings-nostr-network',
  hasOverriddenOnExit: false,
  factory: $NostrNetworkSettingsRouteData._fromState,
);

mixin $NostrNetworkSettingsRouteData on GoRouteData {
  static NostrNetworkSettingsRouteData _fromState(GoRouterState state) =>
      const NostrNetworkSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/settings/connections/nostr');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $helpAboutSettingsRouteData => GoRouteData.$route(
  path: '/settings/help-about',
  name: 'settings-help-about',
  hasOverriddenOnExit: false,
  factory: $HelpAboutSettingsRouteData._fromState,
);

mixin $HelpAboutSettingsRouteData on GoRouteData {
  static HelpAboutSettingsRouteData _fromState(GoRouterState state) =>
      const HelpAboutSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/settings/help-about');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $badgesRouteData => GoRouteData.$route(
  path: '/badges',
  name: 'badges',
  hasOverriddenOnExit: false,
  factory: $BadgesRouteData._fromState,
);

mixin $BadgesRouteData on GoRouteData {
  static BadgesRouteData _fromState(GoRouterState state) =>
      const BadgesRouteData();

  @override
  String get location => GoRouteData.$location('/badges');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $badgeCreateRouteData => GoRouteData.$route(
  path: '/badges/new',
  name: 'badgeCreate',
  hasOverriddenOnExit: false,
  factory: $BadgeCreateRouteData._fromState,
);

mixin $BadgeCreateRouteData on GoRouteData {
  static BadgeCreateRouteData _fromState(GoRouterState state) =>
      const BadgeCreateRouteData();

  @override
  String get location => GoRouteData.$location('/badges/new');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $badgeDetailRouteData => GoRouteData.$route(
  path: '/badges/b/:naddr',
  name: 'badgeDetail',
  hasOverriddenOnExit: false,
  factory: $BadgeDetailRouteData._fromState,
);

mixin $BadgeDetailRouteData on GoRouteData {
  static BadgeDetailRouteData _fromState(GoRouterState state) =>
      BadgeDetailRouteData(naddr: state.pathParameters['naddr']!);

  BadgeDetailRouteData get _self => this as BadgeDetailRouteData;

  @override
  String get location =>
      GoRouteData.$location('/badges/b/${Uri.encodeComponent(_self.naddr)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $badgeVideosRouteData => GoRouteData.$route(
  path: '/badges/b/:naddr/videos',
  name: 'badgeVideos',
  hasOverriddenOnExit: false,
  factory: $BadgeVideosRouteData._fromState,
);

mixin $BadgeVideosRouteData on GoRouteData {
  static BadgeVideosRouteData _fromState(GoRouterState state) =>
      BadgeVideosRouteData(
        naddr: state.pathParameters['naddr']!,
        $extra: state.extra as Object?,
      );

  BadgeVideosRouteData get _self => this as BadgeVideosRouteData;

  @override
  String get location => GoRouteData.$location(
    '/badges/b/${Uri.encodeComponent(_self.naddr)}/videos',
  );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $badgeEditRouteData => GoRouteData.$route(
  path: '/badges/b/:naddr/edit',
  name: 'badgeEdit',
  hasOverriddenOnExit: false,
  factory: $BadgeEditRouteData._fromState,
);

mixin $BadgeEditRouteData on GoRouteData {
  static BadgeEditRouteData _fromState(GoRouterState state) =>
      BadgeEditRouteData(naddr: state.pathParameters['naddr']!);

  BadgeEditRouteData get _self => this as BadgeEditRouteData;

  @override
  String get location => GoRouteData.$location(
    '/badges/b/${Uri.encodeComponent(_self.naddr)}/edit',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $badgeAwardRouteData => GoRouteData.$route(
  path: '/badges/b/:naddr/award',
  name: 'badgeAward',
  hasOverriddenOnExit: false,
  factory: $BadgeAwardRouteData._fromState,
);

mixin $BadgeAwardRouteData on GoRouteData {
  static BadgeAwardRouteData _fromState(GoRouterState state) =>
      BadgeAwardRouteData(naddr: state.pathParameters['naddr']!);

  BadgeAwardRouteData get _self => this as BadgeAwardRouteData;

  @override
  String get location => GoRouteData.$location(
    '/badges/b/${Uri.encodeComponent(_self.naddr)}/award',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $accountStatusRouteData => GoRouteData.$route(
  path: '/settings/account-status',
  name: 'account-status',
  hasOverriddenOnExit: false,
  factory: $AccountStatusRouteData._fromState,
);

mixin $AccountStatusRouteData on GoRouteData {
  static AccountStatusRouteData _fromState(GoRouterState state) =>
      AccountStatusRouteData($extra: state.extra as Object?);

  AccountStatusRouteData get _self => this as AccountStatusRouteData;

  @override
  String get location => GoRouteData.$location('/settings/account-status');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $supportCenterRouteData => GoRouteData.$route(
  path: '/support-center',
  name: 'support-center',
  hasOverriddenOnExit: false,
  factory: $SupportCenterRouteData._fromState,
);

mixin $SupportCenterRouteData on GoRouteData {
  static SupportCenterRouteData _fromState(GoRouterState state) =>
      const SupportCenterRouteData();

  @override
  String get location => GoRouteData.$location('/support-center');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $bugReportRouteData => GoRouteData.$route(
  path: '/support-center/report-bug',
  name: 'support-report-bug',
  hasOverriddenOnExit: false,
  factory: $BugReportRouteData._fromState,
);

mixin $BugReportRouteData on GoRouteData {
  static BugReportRouteData _fromState(GoRouterState state) =>
      BugReportRouteData(entry: state.uri.queryParameters['entry']);

  BugReportRouteData get _self => this as BugReportRouteData;

  @override
  String get location => GoRouteData.$location(
    '/support-center/report-bug',
    queryParams: {if (_self.entry != null) 'entry': _self.entry},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $featureRequestRouteData => GoRouteData.$route(
  path: '/support-center/request-feature',
  name: 'support-request-feature',
  hasOverriddenOnExit: false,
  factory: $FeatureRequestRouteData._fromState,
);

mixin $FeatureRequestRouteData on GoRouteData {
  static FeatureRequestRouteData _fromState(GoRouterState state) =>
      const FeatureRequestRouteData();

  @override
  String get location =>
      GoRouteData.$location('/support-center/request-feature');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $legalRouteData => GoRouteData.$route(
  path: '/legal',
  name: 'legal',
  hasOverriddenOnExit: false,
  factory: $LegalRouteData._fromState,
);

mixin $LegalRouteData on GoRouteData {
  static LegalRouteData _fromState(GoRouterState state) =>
      const LegalRouteData();

  @override
  String get location => GoRouteData.$location('/legal');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $contentPreferencesRouteData => GoRouteData.$route(
  path: '/content-preferences',
  name: 'content-preferences',
  hasOverriddenOnExit: false,
  factory: $ContentPreferencesRouteData._fromState,
);

mixin $ContentPreferencesRouteData on GoRouteData {
  static ContentPreferencesRouteData _fromState(GoRouterState state) =>
      const ContentPreferencesRouteData();

  @override
  String get location => GoRouteData.$location('/content-preferences');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $generalSettingsRouteData => GoRouteData.$route(
  path: '/general-settings',
  name: 'general-settings',
  hasOverriddenOnExit: false,
  factory: $GeneralSettingsRouteData._fromState,
  routes: [
    GoRouteData.$route(
      path: 'change-email',
      name: 'change-email',
      hasOverriddenOnExit: false,
      factory: $ChangeEmailRouteData._fromState,
    ),
    GoRouteData.$route(
      path: 'change-password',
      name: 'change-password',
      hasOverriddenOnExit: false,
      factory: $ChangePasswordRouteData._fromState,
    ),
  ],
);

mixin $GeneralSettingsRouteData on GoRouteData {
  static GeneralSettingsRouteData _fromState(GoRouterState state) =>
      const GeneralSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/general-settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ChangeEmailRouteData on GoRouteData {
  static ChangeEmailRouteData _fromState(GoRouterState state) =>
      const ChangeEmailRouteData();

  @override
  String get location =>
      GoRouteData.$location('/general-settings/change-email');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ChangePasswordRouteData on GoRouteData {
  static ChangePasswordRouteData _fromState(GoRouterState state) =>
      const ChangePasswordRouteData();

  @override
  String get location =>
      GoRouteData.$location('/general-settings/change-password');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $appearanceSettingsRouteData => GoRouteData.$route(
  path: '/appearance-settings',
  name: 'appearance-settings',
  hasOverriddenOnExit: false,
  factory: $AppearanceSettingsRouteData._fromState,
);

mixin $AppearanceSettingsRouteData on GoRouteData {
  static AppearanceSettingsRouteData _fromState(GoRouterState state) =>
      const AppearanceSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/appearance-settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $storageManagementRouteData => GoRouteData.$route(
  path: '/storage-management',
  name: 'storage-management',
  hasOverriddenOnExit: false,
  factory: $StorageManagementRouteData._fromState,
);

mixin $StorageManagementRouteData on GoRouteData {
  static StorageManagementRouteData _fromState(GoRouterState state) =>
      const StorageManagementRouteData();

  @override
  String get location => GoRouteData.$location('/storage-management');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $monetizationLinksSettingsRouteData => GoRouteData.$route(
  path: '/settings/monetization-links',
  name: 'monetization-links-settings',
  hasOverriddenOnExit: false,
  factory: $MonetizationLinksSettingsRouteData._fromState,
);

mixin $MonetizationLinksSettingsRouteData on GoRouteData {
  static MonetizationLinksSettingsRouteData _fromState(GoRouterState state) =>
      const MonetizationLinksSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/settings/monetization-links');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $supporterRouteData => GoRouteData.$route(
  path: '/settings/supporter',
  name: 'supporter',
  hasOverriddenOnExit: false,
  factory: $SupporterRouteData._fromState,
);

mixin $SupporterRouteData on GoRouteData {
  static SupporterRouteData _fromState(GoRouterState state) =>
      const SupporterRouteData();

  @override
  String get location => GoRouteData.$location('/settings/supporter');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $appLanguageRouteData => GoRouteData.$route(
  path: '/app-language',
  name: 'app-language',
  hasOverriddenOnExit: false,
  factory: $AppLanguageRouteData._fromState,
);

mixin $AppLanguageRouteData on GoRouteData {
  static AppLanguageRouteData _fromState(GoRouterState state) =>
      const AppLanguageRouteData();

  @override
  String get location => GoRouteData.$location('/app-language');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $blueskySettingsRouteData => GoRouteData.$route(
  path: '/bluesky-settings',
  name: 'bluesky-settings',
  hasOverriddenOnExit: false,
  factory: $BlueskySettingsRouteData._fromState,
);

mixin $BlueskySettingsRouteData on GoRouteData {
  static BlueskySettingsRouteData _fromState(GoRouterState state) =>
      const BlueskySettingsRouteData();

  @override
  String get location => GoRouteData.$location('/bluesky-settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $crosspostingSettingsRouteData => GoRouteData.$route(
  path: '/crossposting-settings',
  name: 'crossposting-settings',
  hasOverriddenOnExit: false,
  factory: $CrosspostingSettingsRouteData._fromState,
);

mixin $CrosspostingSettingsRouteData on GoRouteData {
  static CrosspostingSettingsRouteData _fromState(GoRouterState state) =>
      const CrosspostingSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/crossposting-settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $nostrSettingsRouteData => GoRouteData.$route(
  path: '/nostr-settings',
  name: 'nostr-settings',
  hasOverriddenOnExit: false,
  factory: $NostrSettingsRouteData._fromState,
  routes: [
    GoRouteData.$route(
      path: 'nip05',
      name: 'nip05-settings',
      hasOverriddenOnExit: false,
      factory: $Nip05SettingsRouteData._fromState,
    ),
    GoRouteData.$route(
      path: 'signature-verification',
      name: 'signature-verification',
      hasOverriddenOnExit: false,
      factory: $SignatureVerificationPolicyRouteData._fromState,
    ),
  ],
);

mixin $NostrSettingsRouteData on GoRouteData {
  static NostrSettingsRouteData _fromState(GoRouterState state) =>
      const NostrSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/nostr-settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $Nip05SettingsRouteData on GoRouteData {
  static Nip05SettingsRouteData _fromState(GoRouterState state) =>
      const Nip05SettingsRouteData();

  @override
  String get location => GoRouteData.$location('/nostr-settings/nip05');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SignatureVerificationPolicyRouteData on GoRouteData {
  static SignatureVerificationPolicyRouteData _fromState(GoRouterState state) =>
      const SignatureVerificationPolicyRouteData();

  @override
  String get location =>
      GoRouteData.$location('/nostr-settings/signature-verification');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $relaySettingsRouteData => GoRouteData.$route(
  path: '/relay-settings',
  name: 'relay-settings',
  hasOverriddenOnExit: false,
  factory: $RelaySettingsRouteData._fromState,
);

mixin $RelaySettingsRouteData on GoRouteData {
  static RelaySettingsRouteData _fromState(GoRouterState state) =>
      const RelaySettingsRouteData();

  @override
  String get location => GoRouteData.$location('/relay-settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $blossomSettingsRouteData => GoRouteData.$route(
  path: '/blossom-settings',
  name: 'blossom-settings',
  hasOverriddenOnExit: false,
  factory: $BlossomSettingsRouteData._fromState,
);

mixin $BlossomSettingsRouteData on GoRouteData {
  static BlossomSettingsRouteData _fromState(GoRouterState state) =>
      const BlossomSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/blossom-settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $notificationSettingsRouteData => GoRouteData.$route(
  path: '/notification-settings',
  name: 'notification-settings',
  hasOverriddenOnExit: false,
  factory: $NotificationSettingsRouteData._fromState,
);

mixin $NotificationSettingsRouteData on GoRouteData {
  static NotificationSettingsRouteData _fromState(GoRouterState state) =>
      const NotificationSettingsRouteData();

  @override
  String get location => GoRouteData.$location('/notification-settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $keyManagementRouteData => GoRouteData.$route(
  path: '/key-management',
  name: 'key-management',
  hasOverriddenOnExit: false,
  factory: $KeyManagementRouteData._fromState,
);

mixin $KeyManagementRouteData on GoRouteData {
  static KeyManagementRouteData _fromState(GoRouterState state) =>
      const KeyManagementRouteData();

  @override
  String get location => GoRouteData.$location('/key-management');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $relayDiagnosticRouteData => GoRouteData.$route(
  path: '/relay-diagnostic',
  name: 'relay-diagnostic',
  hasOverriddenOnExit: false,
  factory: $RelayDiagnosticRouteData._fromState,
);

mixin $RelayDiagnosticRouteData on GoRouteData {
  static RelayDiagnosticRouteData _fromState(GoRouterState state) =>
      const RelayDiagnosticRouteData();

  @override
  String get location => GoRouteData.$location('/relay-diagnostic');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $safetySettingsRouteData => GoRouteData.$route(
  path: '/safety-settings',
  name: 'safety-settings',
  hasOverriddenOnExit: false,
  factory: $SafetySettingsRouteData._fromState,
);

mixin $SafetySettingsRouteData on GoRouteData {
  static SafetySettingsRouteData _fromState(GoRouterState state) =>
      const SafetySettingsRouteData();

  @override
  String get location => GoRouteData.$location('/safety-settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $privacySettingsRouteData => GoRouteData.$route(
  path: '/settings/privacy',
  name: 'privacy-settings',
  hasOverriddenOnExit: false,
  factory: $PrivacySettingsRouteData._fromState,
);

mixin $PrivacySettingsRouteData on GoRouteData {
  static PrivacySettingsRouteData _fromState(GoRouterState state) =>
      const PrivacySettingsRouteData();

  @override
  String get location => GoRouteData.$location('/settings/privacy');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $contentFiltersRouteData => GoRouteData.$route(
  path: '/content-filters',
  name: 'content-filters',
  hasOverriddenOnExit: false,
  factory: $ContentFiltersRouteData._fromState,
);

mixin $ContentFiltersRouteData on GoRouteData {
  static ContentFiltersRouteData _fromState(GoRouterState state) =>
      const ContentFiltersRouteData();

  @override
  String get location => GoRouteData.$location('/content-filters');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $clipRecoveryRouteData => GoRouteData.$route(
  path: '/clip-recovery',
  name: 'clip-recovery',
  hasOverriddenOnExit: false,
  factory: $ClipRecoveryRouteData._fromState,
);

mixin $ClipRecoveryRouteData on GoRouteData {
  static ClipRecoveryRouteData _fromState(GoRouterState state) =>
      const ClipRecoveryRouteData();

  @override
  String get location => GoRouteData.$location('/clip-recovery');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $developerOptionsRouteData => GoRouteData.$route(
  path: '/developer-options',
  name: 'developer-options',
  hasOverriddenOnExit: false,
  factory: $DeveloperOptionsRouteData._fromState,
);

mixin $DeveloperOptionsRouteData on GoRouteData {
  static DeveloperOptionsRouteData _fromState(GoRouterState state) =>
      const DeveloperOptionsRouteData();

  @override
  String get location => GoRouteData.$location('/developer-options');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
