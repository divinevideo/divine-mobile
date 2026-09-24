// ABOUTME: Benefit-forward CTA shown in crossposting settings when nothing
// ABOUTME: is connected yet, routing to native OAuth or the web fallback.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/crossposting_settings/crossposting_settings_cubit.dart';
import 'package:openvine/features/crossposting/crossposting_analytics.dart';
import 'package:openvine/features/crossposting/crossposting_navigation.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';

/// Encourages a creator with no connected platform to connect one.
class CrosspostingBenefitCard extends ConsumerWidget {
  const CrosspostingBenefitCard({required this.platform, super.key});

  final CrosspostingPlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DivineInfoCard(
        icon: DivineIconName.shareNetwork,
        title: context.l10n.crosspostingBenefitTitle,
        message: context.l10n.crosspostingBenefitBody,
        footer: DivineButton(
          label: context.l10n.crosspostingBenefitConnect(platform.displayName),
          expanded: true,
          onPressed: () => unawaited(_connect(context, ref)),
        ),
      ),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    unawaited(
      logCrosspostCtaTapped(
        ref.read(analyticsEventSinkProvider),
        'settings',
      ),
    );
    final container = ProviderScope.containerOf(context, listen: false);
    if (await openCrosspostingWebSetupIfRequired(container)) return;
    if (!context.mounted) return;
    unawaited(context.read<CrosspostingSettingsCubit>().connect(platform));
  }
}
