// ABOUTME: Safety Settings screen - navigation hub for moderation and user safety
// ABOUTME: Provides age verification gate and navigation to sub-screens

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/safety_settings/safety_settings_cubit.dart';
import 'package:openvine/blocs/safety_settings/safety_settings_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/settings/account_content_labels_tile.dart';
import 'package:openvine/utils/dead_image_hosts.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Page: bridges the seven moderation services + repositories into
/// [SafetySettingsCubit].
class SafetySettingsScreen extends ConsumerWidget {
  const SafetySettingsScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'safety-settings';

  /// Path for this route.
  static const String path = RoutePaths.safetySettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ageVerificationService = ref.watch(ageVerificationServiceProvider);
    final contentFilterService = ref.watch(contentFilterServiceProvider);
    final videoEventService = ref.watch(videoEventServiceProvider);
    final divineHostFilterService = ref.watch(divineHostFilterServiceProvider);
    final moderationLabelService = ref.watch(moderationLabelServiceProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final contentBlocklistRepository = ref.watch(
      contentBlocklistRepositoryProvider,
    );
    final provenanceFilterService = ref.watch(
      videoProvenanceFilterServiceProvider,
    );
    final isAdultContentLocked = ref.watch(isProtectedMinorProvider);
    return BlocProvider(
      // Auth-flippable services are re-keyed so the Cubit reloads with the
      // fresh instances rather than operating on stale ones.
      key: ValueKey((
        ageVerificationService,
        contentFilterService,
        videoEventService,
        divineHostFilterService,
        provenanceFilterService,
        moderationLabelService,
        followRepository,
        contentBlocklistRepository,
        isAdultContentLocked,
      )),
      create: (_) => SafetySettingsCubit(
        ageVerificationService: ageVerificationService,
        contentFilterService: contentFilterService,
        videoEventService: videoEventService,
        divineHostFilterService: divineHostFilterService,
        provenanceFilterService: provenanceFilterService,
        moderationLabelService: moderationLabelService,
        followRepository: followRepository,
        contentBlocklistRepository: contentBlocklistRepository,
        isAdultContentLocked: isAdultContentLocked,
      )..load(),
      child: const SafetySettingsView(),
    );
  }
}

/// View: renders the moderation hub from the Cubit state.
class SafetySettingsView extends StatelessWidget {
  @visibleForTesting
  const SafetySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsContentSafetyTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<SafetySettingsCubit, SafetySettingsState>(
            builder: (context, state) {
              if (state.status == SafetySettingsStatus.loading) {
                return const Center(child: BrandedLoadingIndicator(size: 60));
              }
              return ListView(
                children: [
                  DivineSectionHeader(context.l10n.safetySettingsWhatYouSee),
                  const _ContentFiltersTile(),
                  DivineSectionHeader(
                    context.l10n.safetySettingsAgeVerification,
                  ),
                  const _AgeVerificationTile(),
                  const SizedBox(height: 8),
                  const _DivineHostedOnlyTile(),
                  const _VerifiedOnlyTile(),
                  DivineSectionHeader(context.l10n.safetySettingsModeration),
                  const _DivineProviderTile(),
                  const _PeopleIFollowProviderTile(),
                  const _CustomLabelersSection(),
                  DivineSectionHeader(context.l10n.safetySettingsBlockedUsers),
                  const _BlockedUsersSection(),
                  DivineSectionHeader(
                    context.l10n.safetySettingsWhatYouPublish,
                  ),
                  const AccountContentLabelsTile(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ContentFiltersTile extends StatelessWidget {
  const _ContentFiltersTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const DivineIcon(
        icon: DivineIconName.funnelSimple,
        color: VineTheme.vineGreen,
      ),
      title: Text(
        context.l10n.contentPreferencesContentFilters,
        style: VineTheme.bodyLargeFont(color: context.vineColors.primaryText),
      ),
      subtitle: Text(
        context.l10n.contentPreferencesContentFiltersSubtitle,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.secondaryText,
        ),
      ),
      trailing: DivineIcon(
        icon: DivineIconName.caretRight,
        color: context.vineColors.mutedText,
      ),
      onTap: () => context.push(ContentFiltersScreen.path),
    );
  }
}

class _AgeVerificationTile extends StatelessWidget {
  const _AgeVerificationTile();

  @override
  Widget build(BuildContext context) {
    final isAgeVerified = context.select(
      (SafetySettingsCubit cubit) => cubit.state.isAgeVerified,
    );
    final isLocked = context.select(
      (SafetySettingsCubit cubit) => cubit.state.isAdultContentLocked,
    );
    return DivineCheckboxTile(
      title: context.l10n.safetySettingsAgeConfirmation,
      subtitle: isLocked
          ? context.l10n.safetySettingsAgeLockedForMinor
          : context.l10n.safetySettingsAgeRequired,
      value: !isLocked && isAgeVerified,
      onChanged: isLocked
          ? null
          : (value) =>
                context.read<SafetySettingsCubit>().setAgeVerified(value),
    );
  }
}

class _DivineHostedOnlyTile extends StatelessWidget {
  const _DivineHostedOnlyTile();

  @override
  Widget build(BuildContext context) {
    final showDivineHostedOnly = context.select(
      (SafetySettingsCubit cubit) => cubit.state.showDivineHostedOnly,
    );
    return DivineSwitchTile(
      leadingIcon: DivineIconName.sealCheck,
      title: context.l10n.safetySettingsShowDivineHostedOnly,
      subtitle: context.l10n.safetySettingsShowDivineHostedOnlySubtitle,
      value: showDivineHostedOnly,
      onChanged: (value) =>
          context.read<SafetySettingsCubit>().setShowDivineHostedOnly(value),
    );
  }
}

class _VerifiedOnlyTile extends StatelessWidget {
  const _VerifiedOnlyTile();

  @override
  Widget build(BuildContext context) {
    final showVerifiedOnly = context.select(
      (SafetySettingsCubit cubit) => cubit.state.showVerifiedOnly,
    );
    return DivineSwitchTile(
      leadingIcon: DivineIconName.sealCheck,
      title: context.l10n.safetySettingsShowVerifiedOnly,
      subtitle: context.l10n.safetySettingsShowVerifiedOnlySubtitle,
      value: showVerifiedOnly,
      onChanged: (value) =>
          context.read<SafetySettingsCubit>().setShowVerifiedOnly(value),
    );
  }
}

class _DivineProviderTile extends StatelessWidget {
  const _DivineProviderTile();

  @override
  Widget build(BuildContext context) {
    // The built-in Divine moderation labeler is always on by product design.
    return DivineSwitchTile(
      leadingIcon: DivineIconName.shieldCheck,
      title: context.l10n.safetySettingsDivine,
      subtitle: context.l10n.safetySettingsDivineSubtitle,
      value: true,
      onChanged: null,
    );
  }
}

class _PeopleIFollowProviderTile extends StatelessWidget {
  const _PeopleIFollowProviderTile();

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (SafetySettingsCubit cubit) => cubit.state.isPeopleIFollowEnabled,
    );
    return DivineSwitchTile(
      leadingIcon: DivineIconName.users,
      title: context.l10n.safetySettingsPeopleIFollow,
      subtitle: context.l10n.safetySettingsPeopleIFollowSubtitle,
      value: isEnabled,
      onChanged: (value) =>
          context.read<SafetySettingsCubit>().setPeopleIFollowEnabled(value),
    );
  }
}

class _CustomLabelersSection extends StatelessWidget {
  const _CustomLabelersSection();

  @override
  Widget build(BuildContext context) {
    final customLabelers = context.select(
      (SafetySettingsCubit cubit) => cubit.state.customLabelers,
    );
    return Column(
      children: [
        ...customLabelers.map((pubkey) => _CustomLabelerTile(pubkey: pubkey)),
        ListTile(
          leading: DivineIcon(
            icon: DivineIconName.plus,
            color: context.vineColors.disabled,
          ),
          title: Text(
            context.l10n.safetySettingsAddCustomLabelerListTitle,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          subtitle: Text(
            context.l10n.safetySettingsAddCustomLabelerListSubtitle,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          onTap: () => _showAddLabelerDialog(context),
        ),
      ],
    );
  }

  Future<void> _showAddLabelerDialog(BuildContext context) async {
    final cubit = context.read<SafetySettingsCubit>();
    final result = await VineBottomSheet.show<String>(
      context: context,
      scrollable: false,
      contentTitle: context.l10n.safetySettingsAddCustomLabeler,
      body: const _AddLabelerSheet(),
    );
    if (result != null && result.isNotEmpty) {
      await cubit.addLabeler(result);
    }
  }
}

/// One subscribed labeler, identified by profile rather than by raw key.
///
/// Labelers are ordinary accounts with a kind 0, so the name and handle a
/// person recognises are available; a truncated npub told them nothing about
/// which service they had subscribed to.
class _CustomLabelerTile extends ConsumerWidget {
  const _CustomLabelerTile({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    final identifier =
        profile?.shortDisplayNip05 ?? NostrKeyUtils.npubOrHex(pubkey);

    return ListTile(
      leading: Icon(Icons.label_outline, color: context.vineColors.disabled),
      title: Text(
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey),
        style: VineTheme.bodyLargeFont(color: context.vineColors.primaryText),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        identifier,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.secondaryText,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: DivineIconButton(
        icon: DivineIconName.minus,
        backgroundColor: VineTheme.transparent,
        foregroundColor: context.vineColors.secondaryText,
        showShadow: false,
        tooltip: context.l10n.safetySettingsRemoveLabeler,
        onPressed: () =>
            context.read<SafetySettingsCubit>().removeLabeler(pubkey),
      ),
    );
  }
}

class _AddLabelerSheet extends StatefulWidget {
  const _AddLabelerSheet();

  @override
  State<_AddLabelerSheet> createState() => _AddLabelerSheetState();
}

class _AddLabelerSheetState extends State<_AddLabelerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        4 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          DivineTextField(
            controller: _controller,
            labelText: context.l10n.safetySettingsAddCustomLabelerHint,
            textCapitalization: TextCapitalization.none,
            autofocus: true,
            filled: true,
            textInputAction: .done,
            onSubmitted: (_) => Navigator.pop(context, _controller.text.trim()),
            spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
          ),
          Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: context.l10n.safetySettingsCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: context.l10n.safetySettingsAdd,
                  expanded: true,
                  onPressed: () =>
                      Navigator.pop(context, _controller.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlockedUsersSection extends ConsumerWidget {
  const _BlockedUsersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsers = context.select(
      (SafetySettingsCubit cubit) => cubit.state.blockedUsers,
    );
    if (blockedUsers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          context.l10n.safetySettingsNoBlockedUsers,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ).copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }
    ref.watch(blockedUserProfilesProvider(blockedUsers));
    return Column(
      children: blockedUsers
          .map(
            (pubkey) => _BlockedUserTile(
              pubkey: pubkey,
              onUnblock: () => _unblockUser(context, pubkey),
            ),
          )
          .toList(),
    );
  }

  Future<void> _unblockUser(BuildContext context, String pubkey) async {
    final cubit = context.read<SafetySettingsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await cubit.unblockUser(pubkey);
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        l10n.safetySettingsUserUnblocked,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Tile widget for displaying a blocked user with unblock option.
class _BlockedUserTile extends ConsumerWidget {
  const _BlockedUserTile({
    required this.pubkey,
    required this.onUnblock,
  });

  final String pubkey;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(blockedUserProfileProvider(pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey);
    // No relationship line here: "You follow" under an account you have
    // blocked reads as a contradiction, so the handle is the whole signal.
    final identifier =
        profile?.shortDisplayNip05 ?? NostrKeyUtils.npubOrHex(pubkey);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.vineColors.disabled),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child:
              profile?.picture != null &&
                  isUsableNetworkImageUrl(profile!.picture!)
              ? VineCachedImage(
                  imageUrl: profile.picture!,
                  width: 38,
                  height: 38,
                  placeholder: (context, url) => Image.asset(
                    'assets/icon/acid_avatar.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    'assets/icon/acid_avatar.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/icon/acid_avatar.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
        ),
      ),
      title: Text(
        displayName,
        style: VineTheme.bodyLargeFont(color: context.vineColors.primaryText),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        identifier,
        style: VineTheme.bodySmallFont(color: context.vineColors.secondaryText),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: DivineButton(
        label: context.l10n.safetySettingsUnblock,
        type: DivineButtonType.link,
        size: DivineButtonSize.small,
        onPressed: onUnblock,
      ),
    );
  }
}
