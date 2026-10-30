// ABOUTME: Videos-tab state for a profile whose videos failed to load, with a
// ABOUTME: retry; the rest of the profile stays on screen around it (#9773).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shown in the Videos tab when the profile's videos failed to load and none
/// are cached, so "no videos" and "videos didn't load" never look the same.
///
/// Built like [ProfileTabEmptyState] so the tab still scrolls into the
/// profile's pull-to-refresh, but anchored to the top: the profile's header
/// leaves little of the tab above the bottom nav, and Retry has to fit in it.
class ProfileVideosLoadFailed extends StatefulWidget {
  const ProfileVideosLoadFailed({super.key});

  @override
  State<ProfileVideosLoadFailed> createState() =>
      _ProfileVideosLoadFailedState();
}

class _ProfileVideosLoadFailedState extends State<ProfileVideosLoadFailed> {
  @override
  void initState() {
    super.initState();
    // The error replaces the skeleton with no focus change, so a screen reader
    // would otherwise say nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      runDetached(
        SemanticsService.sendAnnouncement(
          View.of(context),
          context.l10n.profileFeedError,
          Directionality.of(context),
        ),
        'announce the failed profile video load',
        logName: 'ProfileVideosLoadFailed',
        category: LogCategory.ui,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRetrying = context.select(
      (ProfileFeedCubit cubit) => cubit.state.isRefreshing,
    );
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 48),
            child: Column(
              spacing: 16,
              children: [
                Text(
                  context.l10n.profileFeedError,
                  textAlign: TextAlign.center,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                DivineButton(
                  label: context.l10n.profileRetryButton,
                  type: DivineButtonType.secondary,
                  isLoading: isRetrying,
                  onPressed: isRetrying
                      ? null
                      : () => context.read<ProfileFeedCubit>().add(
                          const ProfileFeedRetryRequested(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
