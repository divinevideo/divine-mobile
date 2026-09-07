// ABOUTME: Privacy settings screen — the user-facing analytics consent control.
// ABOUTME: Reads and writes AnalyticsService's stored consent preference.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/analytics_consent/analytics_consent_cubit.dart';
import 'package:openvine/blocs/analytics_consent/analytics_consent_state.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';

/// Settings → Privacy.
///
/// Until #7982 the analytics consent preference had no affordance at all — it
/// could only be changed by calling `AnalyticsService.setAnalyticsEnabled`
/// from code. The switch governs every non-essential usage analytics path:
/// the first-party queue, the durable Kind 22236 view outbox, and Firebase
/// collection. What the shipped default should be is still decided in #7978.
class PrivacySettingsScreen extends StatelessWidget {
  static const routeName = 'privacy-settings';
  static const String path = RoutePaths.privacySettings;

  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsPrivacyTitle,
        showBackButton: true,
        // Reachable by deep link, where the stack has nothing to pop.
        onBackPressed: () => context.safePop(fallback: RoutePaths.settings),
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              DivineSectionHeader(context.l10n.privacySettingsAnalyticsSection),
              const _AnalyticsConsentToggle(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsConsentToggle extends ConsumerWidget {
  const _AnalyticsConsentToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `analyticsServiceProvider` rebuilds on an auth flip, so the Cubit is
    // re-keyed on the service identity rather than capturing the first one.
    final service = ref.watch(analyticsServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) => AnalyticsConsentCubit(service: service)..load(),
      child: const _AnalyticsConsentTile(),
    );
  }
}

class _AnalyticsConsentTile extends StatelessWidget {
  const _AnalyticsConsentTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AnalyticsConsentCubit>().state;
    final isReady = state.status == AnalyticsConsentStatus.ready;
    final isSaving = state.saveStatus == AnalyticsConsentSaveStatus.saving;
    return BlocListener<AnalyticsConsentCubit, AnalyticsConsentState>(
      listenWhen: (previous, current) =>
          previous.saveStatus != current.saveStatus &&
          current.saveStatus == AnalyticsConsentSaveStatus.failure,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.privacySettingsSaveFailed)),
          );
      },
      child: DivineSwitchTile(
        leadingIcon: DivineIconName.trendUp,
        title: context.l10n.privacySettingsShareUsage,
        subtitle: context.l10n.privacySettingsShareUsageSubtitle,
        value: state.isEnabled,
        // Disabled until the stored answer is known: a consent control must not
        // accept a flip away from a value the user has not been shown. Also
        // while a write is in flight, so a second flip cannot land on top of an
        // answer that has not come back yet.
        onChanged: isReady && !isSaving
            ? (value) => context.read<AnalyticsConsentCubit>().setEnabled(value)
            : null,
      ),
    );
  }
}
