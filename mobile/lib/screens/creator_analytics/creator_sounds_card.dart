// ABOUTME: Creator Analytics card ranking the creator's sounds by reuse.
// ABOUTME: Owns its loading, empty and error states through CreatorSoundsCubit.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/creator_sounds/creator_sounds_cubit.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/creator_analytics_providers.dart';
import 'package:openvine/screens/creator_analytics/analytics_widgets.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// The creator's most used sounds, as a Creator Analytics card.
///
/// Keyed on [loadedAt] as well as the repository and [pubkey], so every
/// dashboard load — pull-to-refresh included — reloads the sounds with it.
///
/// Kept alive so scrolling the dashboard away and back does not rebuild the
/// cubit and fetch the sounds again.
class CreatorSoundsSection extends ConsumerStatefulWidget {
  const CreatorSoundsSection({
    required this.pubkey,
    required this.loadedAt,
    super.key,
  });

  /// The creator whose sounds are listed.
  final String pubkey;

  /// When the surrounding dashboard data was loaded.
  final DateTime loadedAt;

  @override
  ConsumerState<CreatorSoundsSection> createState() =>
      _CreatorSoundsSectionState();
}

class _CreatorSoundsSectionState extends ConsumerState<CreatorSoundsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final repository = ref.watch(creatorAnalyticsRepositoryProvider);
    final pubkey = widget.pubkey;
    return BlocProvider(
      key: ValueKey((repository, pubkey, widget.loadedAt)),
      create: (_) {
        final cubit = CreatorSoundsCubit(
          repository: repository,
          pubkey: pubkey,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const CreatorSoundsCard(),
    );
  }
}

/// Renders [CreatorSoundsCubit]'s state inside an [AnalyticsCard].
class CreatorSoundsCard extends StatelessWidget {
  @visibleForTesting
  const CreatorSoundsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CreatorSoundsCubit>().state;
    return AnalyticsCard(
      title: context.l10n.analyticsYourSounds,
      child: switch (state.status) {
        CreatorSoundsStatus.initial ||
        CreatorSoundsStatus.loading => const _CreatorSoundsLoading(),
        CreatorSoundsStatus.failure => _CreatorSoundsError(
          failureKind:
              state.failureKind ?? CreatorAnalyticsFailureKind.unableToLoad,
        ),
        CreatorSoundsStatus.success when state.sounds.isEmpty =>
          const _CreatorSoundsEmpty(),
        CreatorSoundsStatus.success => _CreatorSoundsList(
          sounds: state.sounds,
        ),
      },
    );
  }
}

class _CreatorSoundsLoading extends StatelessWidget {
  const _CreatorSoundsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: BrandedLoadingIndicator(size: 48),
      ),
    );
  }
}

class _CreatorSoundsEmpty extends StatelessWidget {
  const _CreatorSoundsEmpty();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.analyticsYourSoundsEmpty,
      style: VineTheme.bodySmallFont(color: context.vineColors.onSurfaceMuted),
    );
  }
}

class _CreatorSoundsError extends StatelessWidget {
  const _CreatorSoundsError({required this.failureKind});

  final CreatorAnalyticsFailureKind failureKind;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          failureKind.localizedMessage(context.l10n),
          style: VineTheme.bodySmallFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        DivineButton(
          label: context.l10n.analyticsRetry,
          type: DivineButtonType.secondary,
          size: DivineButtonSize.small,
          onPressed: () => context.read<CreatorSoundsCubit>().load(),
        ),
      ],
    );
  }
}

class _CreatorSoundsList extends StatelessWidget {
  const _CreatorSoundsList({required this.sounds});

  final List<SoundStats> sounds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          context.l10n.analyticsYourSoundsExplainer,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        for (var i = 0; i < sounds.length; i++)
          _CreatorSoundRow(rank: i + 1, sound: sounds[i]),
      ],
    );
  }
}

class _CreatorSoundRow extends StatelessWidget {
  const _CreatorSoundRow({required this.rank, required this.sound});

  final int rank;
  final SoundStats sound;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = sound.title.trim().isEmpty
        ? l10n.videoEditorAudioUntitledSound
        : sound.title;
    final countText = sound.usageCount == 0
        ? l10n.soundNoVideoCount
        : l10n.soundVideoCount(sound.usageCount);
    final age = LocalizedTimeFormatter.formatRelativeVerbose(
      l10n,
      sound.createdAt.millisecondsSinceEpoch ~/ 1000,
    );

    Future<void> openSound() =>
        context.push(SoundDetailScreen.pathForId(sound.id));

    return Semantics(
      button: true,
      label: '$title, $countText, $age',
      onTap: openSound,
      excludeSemantics: true,
      child: InkWell(
        onTap: openSound,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            spacing: 10,
            children: [
              AnalyticsRankBadge(rank: rank),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    Text(
                      age,
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                countText,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.accentBrand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
