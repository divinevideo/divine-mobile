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
/// Styled like [ProfileTabEmptyState] with a retry under it, and centered in
/// the tab as the design shows. The tab is only the space left under the
/// header: about 165 points on an iPhone 17 without a bio, where the whole
/// block fits in English, and 89 under a NIP-05 and a two-line bio, where
/// Try again needs a scroll. Pull-to-refresh and the automatic retries cover
/// that case.
/// The top padding is smaller than the empty state's 64 because that would
/// push the subtitle below the fold in the short tab too.
class ProfileVideosLoadFailed extends StatefulWidget {
  const ProfileVideosLoadFailed({required this.isOwnProfile, super.key});

  /// Whether the viewer owns the profile, which picks "your videos" or
  /// "videos" in the title.
  final bool isOwnProfile;

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
          _title(context),
          Directionality.of(context),
        ),
        'announce the failed profile video load',
        logName: 'ProfileVideosLoadFailed',
        category: LogCategory.ui,
      );
    });
  }

  String _title(BuildContext context) => widget.isOwnProfile
      ? context.l10n.profileVideosLoadFailedTitle
      : context.l10n.profileVideosLoadFailedOtherTitle;

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
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _title(context),
                  textAlign: TextAlign.center,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.profileVideosLoadFailedSubtitle,
                  textAlign: TextAlign.center,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 32),
                DivineButton(
                  label: context.l10n.profileVideosLoadFailedRetry,
                  type: DivineButtonType.secondary,
                  size: DivineButtonSize.small,
                  isLoading: isRetrying,
                  onPressed: () => context.read<ProfileFeedCubit>().add(
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
