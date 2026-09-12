// ABOUTME: Loader widget for sound detail screen
// ABOUTME: Fetches sound by ID before displaying SoundDetailScreen

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:unified_logger/unified_logger.dart';

/// Loader widget that fetches a sound by ID before displaying SoundDetailScreen.
/// Used when navigating via deep link without the sound object.
class SoundDetailLoader extends ConsumerWidget {
  const SoundDetailLoader({required this.soundId, super.key});

  final String soundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundAsync = ref.watch(soundByIdProvider(soundId));

    return soundAsync.when(
      data: (sound) {
        if (sound == null) {
          return Scaffold(
            backgroundColor: context.vineColors.background,
            appBar: DiVineAppBar(title: context.l10n.soundDetailNotFoundTitle),
            body: Center(
              child: Text(
                context.l10n.soundDetailNotFoundMessage,
                style: TextStyle(color: context.vineColors.primaryText),
              ),
            ),
          );
        }
        return SoundDetailScreen(sound: sound);
      },
      loading: () => const BrandedLoadingScaffold(),
      error: (error, stack) {
        Log.error(
          'Failed to load sound: $error',
          name: 'SoundDetailLoader',
          category: LogCategory.ui,
        );
        return Scaffold(
          backgroundColor: context.vineColors.background,
          appBar: DiVineAppBar(title: context.l10n.featureFlagError),
          body: Center(
            child: Text(
              context.l10n.soundDetailLoadError,
              style: TextStyle(color: context.vineColors.primaryText),
            ),
          ),
        );
      },
    );
  }
}
