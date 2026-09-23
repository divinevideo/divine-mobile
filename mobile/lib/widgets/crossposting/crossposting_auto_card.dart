// ABOUTME: Encourages switching a connected platform to automatic
// ABOUTME: crossposting, with an honest forward-looking-only qualifier.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/crossposting_settings/crossposting_settings_cubit.dart';
import 'package:openvine/features/crossposting/crossposting_analytics.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';

/// Promotes automatic mode for a connected platform currently off or manual.
class CrosspostingAutoCard extends ConsumerWidget {
  const CrosspostingAutoCard({required this.platform, super.key});

  final CrosspostingPlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DivineInfoCard(
        icon: DivineIconName.arrowsClockwise,
        title: context.l10n.crosspostingAutoTitle,
        message: context.l10n.crosspostingAutoBody(platform.displayName),
        footer: DivineButton(
          label: context.l10n.crosspostingAutoEnable,
          expanded: true,
          onPressed: () => _enableAutomatic(context, ref),
        ),
      ),
    );
  }

  void _enableAutomatic(BuildContext context, WidgetRef ref) {
    unawaited(
      logCrosspostCtaTapped(
        ref.read(analyticsEventSinkProvider),
        'settings',
      ),
    );
    unawaited(
      context.read<CrosspostingSettingsCubit>().setMode(
        platform,
        CrosspostingMode.automatic,
      ),
    );
  }
}
