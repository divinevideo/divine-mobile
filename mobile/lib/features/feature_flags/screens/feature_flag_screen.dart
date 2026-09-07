// ABOUTME: Settings screen for managing feature flag states and overrides
// ABOUTME: Provides UI for toggling flags, viewing descriptions, and resetting to defaults

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/environment_provider.dart';

class FeatureFlagScreen extends ConsumerWidget {
  const FeatureFlagScreen({super.key});

  static const routeName = 'feature-flags';
  static const subpath = 'feature-flags';
  static const path = '/settings/$subpath';
  static const fallbackPath = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(featureFlagServiceProvider);
    final state = ref.watch(featureFlagStateProvider);
    final showInternalFlags = ref.watch(isDeveloperModeEnabledProvider);
    final visibleFlags = FeatureFlag.values
        .where((flag) => !flag.isInternal || showInternalFlags)
        .toList(growable: false);

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.featureFlagTitle,
        showBackButton: true,
        onBackPressed: () => context.safePop(fallback: fallbackPath),
        actions: [
          DiVineAppBarAction(
            icon: SvgIconSource(DivineIconName.arrowCounterClockwise.assetPath),
            onPressed: () async {
              await service.resetAllFlags();
            },
            tooltip: context.l10n.featureFlagResetAllTooltip,
            semanticLabel: context.l10n.featureFlagResetAllTooltip,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView.builder(
            padding: .fromLTRB(
              16,
              12,
              16,
              MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: visibleFlags.length,
            itemBuilder: (context, index) {
              final flag = visibleFlags[index];
              final isEnabled = state[flag] ?? false;

              return Semantics(
                identifier: flag == FeatureFlag.accountSwitching
                    ? SemanticIds.featureFlagAccountSwitching
                    : null,
                child: Card(
                  clipBehavior: .hardEdge,
                  margin: const .only(bottom: 12.0),
                  child: ListTile(
                    contentPadding: const .fromLTRB(16, 0, 12, 0),
                    title: Text(
                      flag.displayName,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    subtitle: Text(
                      flag.description,
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                    trailing: DivineSwitch(
                      value: isEnabled,
                      onChanged: (value) async {
                        await service.setFlag(flag, value);
                      },
                    ),
                    onTap: () async {
                      await service.setFlag(flag, !isEnabled);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
