// ABOUTME: Pure StatelessWidget View for the video engagement (likers/reposters) list.
// ABOUTME: Consumes VideoEngagementBloc via BlocBuilder — zero Riverpod dependency.
// ABOUTME: Provided and owned by VideoEngagementListScreen (the Page layer).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Inner View for the video engagement list screen.
///
/// Pure [StatelessWidget] — reads state exclusively from [VideoEngagementBloc]
/// via [BlocBuilder]/[context.select]. Has no Riverpod dependency.
///
/// See also: [VideoEngagementListScreen], which is the [ConsumerWidget] Page
/// that wires Riverpod dependencies into [VideoEngagementBloc] and provides
/// this view.
class VideoEngagementListView extends StatelessWidget {
  const VideoEngagementListView({super.key});

  @override
  Widget build(BuildContext context) {
    final type = context.select(
      (VideoEngagementBloc bloc) => bloc.state.type,
    );
    final title = switch (type) {
      VideoEngagementType.likers => context.l10n.videoEngagementLikersTitle,
      VideoEngagementType.reposters =>
        context.l10n.videoEngagementRepostersTitle,
    };

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        titleWidget: Text(
          title,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
        backButtonSemanticLabel: context.l10n.commonBack,
      ),
      body: BlocBuilder<VideoEngagementBloc, VideoEngagementState>(
        builder: (context, state) {
          return switch (state.status) {
            VideoEngagementStatus.initial ||
            VideoEngagementStatus.loading => const Center(
              child: DivineCircularProgressIndicator(),
            ),
            VideoEngagementStatus.success when state.pubkeys.isEmpty =>
              _EngagementEmptyState(type: state.type),
            VideoEngagementStatus.success => _EngagementListBody(
              pubkeys: state.pubkeys,
            ),
            VideoEngagementStatus.failure => const _EngagementErrorBody(),
          };
        },
      ),
    );
  }
}

class _EngagementListBody extends StatelessWidget {
  const _EngagementListBody({required this.pubkeys});

  final List<String> pubkeys;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        context.read<VideoEngagementBloc>().add(
          const VideoEngagementLoadRequested(),
        );
      },
      child: ListView.builder(
        itemCount: pubkeys.length,
        itemBuilder: (context, index) {
          final pubkey = pubkeys[index];
          return UserProfileTile(
            pubkey: pubkey,
            onTap: () => context.pushOtherProfile(pubkey),
            showFollowButton: false,
            index: index,
          );
        },
      ),
    );
  }
}

class _EngagementEmptyState extends StatelessWidget {
  const _EngagementEmptyState({required this.type});

  final VideoEngagementType type;

  @override
  Widget build(BuildContext context) {
    final message = switch (type) {
      VideoEngagementType.likers => context.l10n.videoEngagementLikersEmpty,
      VideoEngagementType.reposters =>
        context.l10n.videoEngagementRepostersEmpty,
    };
    final icon = switch (type) {
      VideoEngagementType.likers => DivineIconName.heart,
      VideoEngagementType.reposters => DivineIconName.repeat,
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DivineIcon(icon: icon, size: 64, color: context.vineColors.mutedText),
          const SizedBox(height: 16),
          Text(
            message,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementErrorBody extends StatelessWidget {
  const _EngagementErrorBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DivineIcon(
            icon: DivineIconName.warningCircle,
            size: 64,
            color: context.vineColors.mutedText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.videoEngagementLoadFailed,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.read<VideoEngagementBloc>().add(
              const VideoEngagementLoadRequested(),
            ),
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
