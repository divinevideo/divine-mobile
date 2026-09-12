// ABOUTME: Settings screen for profile support and subscription links.
// ABOUTME: Persists normalized outbound monetization links in Kind 0 metadata.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/monetization_links_settings/monetization_links_settings_cubit.dart';
import 'package:openvine/blocs/monetization_links_settings/monetization_links_settings_state.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/monetization/monetization_analytics.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/settings/settings_screen.dart';

class MonetizationLinksSettingsScreen extends ConsumerWidget {
  static const routeName = 'monetization-links-settings';
  static const String subpath = RoutePaths.monetizationLinksSettingsSubpath;
  static const String path = RoutePaths.monetizationLinksSettings;

  const MonetizationLinksSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    final profileAsync = pubkey == null
        ? const AsyncValue<UserProfile?>.data(null)
        : ref.watch(userProfileReactiveProvider(pubkey));
    final profile = profileAsync.asData?.value;
    final repository = ref.watch(profileRepositoryProvider);
    final appStoreTipPolicy = usesAppleAppStoreTipPolicy;
    final providers = monetizationProvidersForCurrentStorefront();
    final analytics = ref.watch(analyticsEventSinkProvider);

    return BlocProvider(
      key: ValueKey((
        pubkey,
        profile?.eventId,
        repository,
        appStoreTipPolicy,
      )),
      create: (_) => MonetizationLinksSettingsCubit(
        repository: repository,
        profile: profile,
        visibleProviders: providers,
        trackConfiguredLink: (link) =>
            trackMonetizationLinkConfigured(analytics: analytics, link: link),
        onProfileSaved: (saved) {
          ref
            ..invalidate(userProfileReactiveProvider(saved.pubkey))
            ..invalidate(fetchUserProfileProvider(saved.pubkey));
        },
      ),
      child: MonetizationLinksSettingsView(
        appStoreTipPolicy: appStoreTipPolicy,
      ),
    );
  }
}

class MonetizationLinksSettingsView extends StatefulWidget {
  const MonetizationLinksSettingsView({
    required this.appStoreTipPolicy,
    super.key,
  });

  final bool appStoreTipPolicy;

  @override
  State<MonetizationLinksSettingsView> createState() =>
      _MonetizationLinksSettingsViewState();
}

class _MonetizationLinksSettingsViewState
    extends State<MonetizationLinksSettingsView> {
  late final Map<MonetizationLinkProvider, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final provider in MonetizationLinkProvider.values)
        provider: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      MonetizationLinksSettingsCubit,
      MonetizationLinksSettingsState
    >(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.savedProfile?.eventId != current.savedProfile?.eventId,
      listener: _onStateChanged,
      builder: (context, state) {
        _syncControllers(state);
        return _buildScaffold(context, state);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    MonetizationLinksSettingsState state,
  ) {
    final appStoreTipPolicy = widget.appStoreTipPolicy;
    final providers = state.visibleProviders;
    final tipProviders = providers
        .where((provider) => provider.category == MonetizationLinkCategory.tip)
        .toList(growable: false);
    final subscriptionProviders = providers
        .where(
          (provider) =>
              provider.category == MonetizationLinkCategory.subscription,
        )
        .toList(growable: false);

    return Scaffold(
      appBar: DiVineAppBar(
        title: appStoreTipPolicy
            ? context.l10n.monetizationTipsSettingsTitle
            : context.l10n.monetizationSettingsTitle,
        showBackButton: true,
        // safePop: this screen has a registered path, so the back stack
        // can be empty on a cold entry and a raw pop would throw GoError.
        onBackPressed: () => context.safePop(fallback: SettingsScreen.path),
      ),
      backgroundColor: context.vineColors.surface,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SectionIntro(
                profile: state.currentProfile,
                appStoreTipPolicy: appStoreTipPolicy,
              ),
              const SizedBox(height: 20),
              DivineSectionHeader(
                context.l10n.monetizationSettingsTipSection,
                padding: const EdgeInsets.only(top: 8, bottom: 8),
              ),
              for (final provider in tipProviders)
                _ProviderEditor(
                  provider: provider,
                  controller: _controllers[provider]!,
                  enabled: state.isEnabled(provider),
                  errorText: _errorTextFor(context, state.errorFor(provider)),
                  onEnabledChanged: (value) => context
                      .read<MonetizationLinksSettingsCubit>()
                      .setEnabled(provider, value),
                  onChanged: (value) => context
                      .read<MonetizationLinksSettingsCubit>()
                      .setValue(provider, value),
                ),
              if (subscriptionProviders.isNotEmpty) ...[
                const SizedBox(height: 16),
                DivineSectionHeader(
                  context.l10n.monetizationSettingsSubscriptionSection,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                ),
                for (final provider in subscriptionProviders)
                  _ProviderEditor(
                    provider: provider,
                    controller: _controllers[provider]!,
                    enabled: state.isEnabled(provider),
                    errorText: _errorTextFor(
                      context,
                      state.errorFor(provider),
                    ),
                    onEnabledChanged: (value) => context
                        .read<MonetizationLinksSettingsCubit>()
                        .setEnabled(provider, value),
                    onChanged: (value) => context
                        .read<MonetizationLinksSettingsCubit>()
                        .setValue(provider, value),
                  ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.vineColors.surface,
            border: Border(
              top: BorderSide(color: context.vineColors.outlineMuted),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: DivineButton(
                  label: state.isSaving
                      ? context.l10n.monetizationSettingsSaving
                      : appStoreTipPolicy
                      ? context.l10n.monetizationTipsSettingsSave
                      : context.l10n.monetizationSettingsSave,
                  leadingIcon: .check,
                  expanded: true,
                  onPressed: state.canSave
                      ? () => context
                            .read<MonetizationLinksSettingsCubit>()
                            .save()
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _syncControllers(MonetizationLinksSettingsState state) {
    for (final provider in MonetizationLinkProvider.values) {
      final controller = _controllers[provider]!;
      final value = state.valueFor(provider);
      if (controller.text != value) {
        controller.text = value;
      }
    }
  }

  void _onStateChanged(
    BuildContext context,
    MonetizationLinksSettingsState state,
  ) {
    switch (state.status) {
      case MonetizationLinksSettingsSaveStatus.success:
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            widget.appStoreTipPolicy
                ? context.l10n.monetizationTipsSettingsSaved
                : context.l10n.monetizationSettingsSaved,
          ),
        );
      case MonetizationLinksSettingsSaveStatus.failure:
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            _failureTextFor(context, state.failure),
            error: true,
          ),
        );
      case MonetizationLinksSettingsSaveStatus.idle:
      case MonetizationLinksSettingsSaveStatus.saving:
        break;
    }
  }

  String? _errorTextFor(
    BuildContext context,
    MonetizationLinkInputInvalidReason? reason,
  ) {
    return switch (reason) {
      MonetizationLinkInputInvalidReason.empty =>
        context.l10n.monetizationSettingsErrorEmpty,
      MonetizationLinkInputInvalidReason.invalidFormat =>
        context.l10n.monetizationSettingsErrorInvalid,
      MonetizationLinkInputInvalidReason.wrongProvider =>
        context.l10n.monetizationSettingsErrorWrongProvider,
      null => null,
    };
  }

  String _failureTextFor(
    BuildContext context,
    MonetizationLinksSettingsSaveFailure? failure,
  ) {
    return switch (failure) {
      MonetizationLinksSettingsSaveFailure.noRelays =>
        context.l10n.profileSetupNoRelaysConnected,
      MonetizationLinksSettingsSaveFailure.publishFailed ||
      null => context.l10n.monetizationSettingsSaveFailed,
    };
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.profile, required this.appStoreTipPolicy});

  final UserProfile? profile;
  final bool appStoreTipPolicy;

  @override
  Widget build(BuildContext context) {
    final configured = monetizationLinksForCurrentStorefront(
      profile?.enabledMonetizationLinks ?? const [],
    ).length;
    return DivineInfoCard(
      icon: null,
      tone: DivineInfoCardTone.neutral,
      title: appStoreTipPolicy
          ? context.l10n.monetizationTipsSettingsIntroTitle
          : context.l10n.monetizationSettingsIntroTitle,
      message: appStoreTipPolicy
          ? context.l10n.monetizationTipsSettingsIntroBody
          : context.l10n.monetizationSettingsIntroBody,
      footer: Text(
        appStoreTipPolicy
            ? context.l10n.monetizationTipsSettingsConfiguredCount(configured)
            : context.l10n.monetizationSettingsConfiguredCount(configured),
        style: VineTheme.bodySmallFont(
          color: context.vineColors.accentPositive,
        ),
      ),
    );
  }
}

class _ProviderEditor extends StatelessWidget {
  const _ProviderEditor({
    required this.provider,
    required this.controller,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onChanged,
    this.errorText,
  });

  final MonetizationLinkProvider provider;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      // The tile's ink has to stay inside the rounded border.
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.vineColors.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DivineSwitchTile(
            title: provider.displayName,
            value: enabled,
            onChanged: onEnabledChanged,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: DivineAuthTextField(
              label: _hintForProvider(context, provider),
              controller: controller,
              enabled: enabled,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              errorText: errorText,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  String _hintForProvider(
    BuildContext context,
    MonetizationLinkProvider provider,
  ) {
    return switch (provider) {
      MonetizationLinkProvider.cashApp =>
        context.l10n.monetizationSettingsHintCashApp,
      MonetizationLinkProvider.paypal =>
        context.l10n.monetizationSettingsHintPayPal,
      MonetizationLinkProvider.venmo =>
        context.l10n.monetizationSettingsHintVenmo,
      MonetizationLinkProvider.patreon =>
        context.l10n.monetizationSettingsHintPatreon,
      MonetizationLinkProvider.substack =>
        context.l10n.monetizationSettingsHintSubstack,
      MonetizationLinkProvider.medium =>
        context.l10n.monetizationSettingsHintMedium,
      MonetizationLinkProvider.openCollective =>
        context.l10n.monetizationSettingsHintOpenCollective,
    };
  }
}
