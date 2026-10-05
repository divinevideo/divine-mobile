// ABOUTME: Task-oriented Settings destinations for viewing, creating, connections, and help.
// ABOUTME: Reuses the existing controls so moving them does not change stored preferences.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/settings/account_content_labels_tile.dart';
import 'package:openvine/screens/settings/appearance_settings_screen.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/crossposting_settings_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/monetization_links_settings_screen.dart';
import 'package:openvine/screens/settings/storage/storage_management_page.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/utils/nostr_apps_platform_support.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _SettingsCategoryScaffold extends StatelessWidget {
  const _SettingsCategoryScaffold({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: DiVineAppBar(
      title: title,
      showBackButton: true,
      onBackPressed: () => context.safePop(fallback: RoutePaths.settings),
    ),
    backgroundColor: context.vineColors.background,
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(children: children),
      ),
    ),
  );
}

class ViewingSettingsScreen extends StatelessWidget {
  const ViewingSettingsScreen({super.key});

  static const routeName = 'settings-viewing';
  static const String path = RoutePaths.settingsViewing;

  @override
  Widget build(BuildContext context) => _SettingsCategoryScaffold(
    title: context.l10n.settingsWhatYouSeeTitle,
    children: [
      DivineSectionHeader(context.l10n.generalSettingsSectionViewing),
      const ContentLanguageSetting(),
      const ClosedCaptionsSetting(),
      const SquareVideosSetting(),
      const StatsVisibilitySettings(),
      DivineListTile(
        icon: DivineIconName.funnelSimple,
        title: context.l10n.contentPreferencesContentFilters,
        subtitle: context.l10n.contentPreferencesContentFiltersSubtitle,
        onTap: () => context.push(ContentFiltersScreen.path),
      ),
    ],
  );
}

class CreatingSettingsScreen extends ConsumerWidget {
  const CreatingSettingsScreen({super.key});

  static const routeName = 'settings-creating';
  static const String path = RoutePaths.settingsCreating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated =
        ref.watch(currentAuthStateProvider) == AuthState.authenticated;
    final monetizationEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.profileMonetizationLinks),
    );
    final blueskyEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.blueskyPublishing),
    );
    final crosspostingEnabled =
        ref.watch(crosspostingAvailabilityProvider) !=
        CrosspostingAvailability.unavailable;
    return _SettingsCategoryScaffold(
      title: context.l10n.settingsCreateShareTitle,
      children: [
        DivineSectionHeader(context.l10n.generalSettingsSectionCreating),
        const HoldToRecordSetting(),
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android))
          const MusicModeSetting(),
        if (!kIsWeb && defaultTargetPlatform != TargetPlatform.linux)
          const AudioDeviceSetting(),
        const AudioSharingSetting(),
        if (crosspostingEnabled || blueskyEnabled)
          DivineSectionHeader(context.l10n.generalSettingsSectionIntegrations),
        if (crosspostingEnabled)
          DivineListTile(
            icon: DivineIconName.shareNetwork,
            title: context.l10n.settingsCrosspostingTitle,
            subtitle: context.l10n.settingsCrosspostingSubtitle,
            onTap: () => context.push(CrosspostingSettingsScreen.path),
          ),
        if (blueskyEnabled)
          DivineListTile(
            icon: DivineIconName.shareNetwork,
            title: context.l10n.settingsBlueskyPublishing,
            subtitle: context.l10n.settingsBlueskyPublishingSubtitle,
            onTap: () => context.push(BlueskySettingsScreen.path),
          ),
        DivineSectionHeader(context.l10n.settingsCreatorToolsSection),
        DivineListTile(
          icon: DivineIconName.trendUp,
          title: context.l10n.settingsCreatorAnalytics,
          onTap: () => context.push(CreatorAnalyticsScreen.path),
        ),
        DivineListTile(
          icon: DivineIconName.sealCheck,
          title: context.l10n.settingsBadgesTitle,
          subtitle: context.l10n.settingsBadgesSubtitle,
          onTap: () => context.push(BadgesScreen.path),
        ),
        if (isAuthenticated && monetizationEnabled)
          DivineListTile(
            icon: DivineIconName.heart,
            title: usesAppleAppStoreTipPolicy
                ? context.l10n.monetizationTipsSettingsTitle
                : context.l10n.monetizationSettingsTitle,
            subtitle: usesAppleAppStoreTipPolicy
                ? context.l10n.monetizationTipsSettingsSubtitle
                : context.l10n.monetizationSettingsSubtitle,
            onTap: () => context.push(MonetizationLinksSettingsScreen.path),
          ),
        DivineSectionHeader(context.l10n.contentPreferencesAccountLabels),
        const AccountContentLabelsTile(),
      ],
    );
  }
}

class AppPreferencesSettingsScreen extends ConsumerWidget {
  const AppPreferencesSettingsScreen({super.key});

  static const routeName = 'settings-app-preferences';
  static const String path = RoutePaths.settingsAppPreferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeveloperMode = ref.watch(isDeveloperModeEnabledProvider);
    return _SettingsCategoryScaffold(
      title: context.l10n.settingsAppPreferencesTitle,
      children: [
        DivineSectionHeader(context.l10n.generalSettingsSectionApp),
        const AppLanguageSetting(),
        DivineListTile(
          icon: DivineIconName.sun,
          title: context.l10n.appearanceSettingsTitle,
          subtitle: context.l10n.appearanceSettingsSubtitle,
          onTap: () => context.push(AppearanceSettingsScreen.path),
        ),
        DivineListTile(
          icon: DivineIconName.stackSimple,
          title: context.l10n.settingsStorageTitle,
          onTap: () => context.push(StorageManagementPage.path),
        ),
        DivineSectionHeader(context.l10n.settingsAdvancedSection),
        DivineListTile(
          icon: DivineIconName.bracketsAngle,
          title: context.l10n.settingsExperimentalFeatures,
          subtitle: context.l10n.settingsExperimentalFeaturesSubtitle,
          semanticIdentifier: SemanticIds.settingsExperimentalFeaturesRow,
          onTap: () => context.push(FeatureFlagScreen.path),
        ),
        if (isDeveloperMode)
          DivineListTile(
            icon: DivineIconName.bracketsAngle,
            title: context.l10n.settingsDeveloperOptions,
            subtitle: context.l10n.settingsDeveloperOptionsSubtitle,
            onTap: () => context.push(DeveloperOptionsScreen.path),
          ),
      ],
    );
  }
}

class ConnectionsSettingsScreen extends StatelessWidget {
  const ConnectionsSettingsScreen({super.key});

  static const routeName = 'settings-connections';
  static const String path = RoutePaths.settingsConnections;

  @override
  Widget build(BuildContext context) => _SettingsCategoryScaffold(
    title: context.l10n.settingsConnectionsTitle,
    children: [
      DivineSectionHeader(context.l10n.generalSettingsSectionIntegrations),
      if (nostrAppsSandboxSupported)
        DivineListTile(
          icon: DivineIconName.graph,
          title: context.l10n.settingsIntegratedApps,
          subtitle: context.l10n.settingsIntegratedAppsSubtitle,
          onTap: () => context.push(AppsDirectoryScreen.path),
        ),
      DivineListTile(
        icon: DivineIconName.shieldCheck,
        title: context.l10n.settingsIntegrationPermissions,
        subtitle: context.l10n.settingsIntegrationPermissionsSubtitle,
        onTap: () => context.push(AppsPermissionsScreen.path),
      ),
      DivineSectionHeader(context.l10n.settingsNostrNetworkSection),
      DivineListTile(
        icon: DivineIconName.graph,
        title: context.l10n.settingsNostrSettings,
        subtitle: context.l10n.nostrSettingsIntro,
        semanticIdentifier: SemanticIds.settingsNostrRow,
        onTap: () => context.push(RoutePaths.settingsNostrNetwork),
      ),
    ],
  );
}

class HelpAboutSettingsScreen extends StatelessWidget {
  const HelpAboutSettingsScreen({super.key});

  static const routeName = 'settings-help-about';
  static const String path = RoutePaths.settingsHelpAbout;

  @override
  Widget build(BuildContext context) => _SettingsCategoryScaffold(
    title: context.l10n.settingsHelpAboutTitle,
    children: [
      DivineListTile(
        icon: DivineIconName.question,
        title: context.l10n.settingsSupportCenter,
        onTap: () => context.push(SupportCenterScreen.path),
      ),
      DivineSectionHeader(context.l10n.settingsAboutDivineSection),
      DivineListTile(
        icon: DivineIconName.shareNetwork,
        title: context.l10n.settingsShareDivine,
        onTap: () => showShareSheet(
          context,
          ShareParams(text: AppConstants.downloadUrl),
        ),
      ),
      DivineListTile(
        icon: DivineIconName.globe,
        title: context.l10n.settingsLegal,
        onTap: () => context.push(LegalScreen.path),
      ),
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              info == null
                  ? context.l10n.settingsVersionEmpty
                  : context.l10n.settingsVersion(
                      '${info.version}+${info.buildNumber}',
                    ),
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.mutedText,
              ),
            ),
          );
        },
      ),
    ],
  );
}
