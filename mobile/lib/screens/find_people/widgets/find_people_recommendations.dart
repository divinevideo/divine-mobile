// ABOUTME: Shared recommendations for the permanent page and optional feed card.
// ABOUTME: Exposure fires only when a row is visible on an active surface.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/find_people/find_people_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/find_people_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:text_sanitizer/text_sanitizer.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Supplies an account-scoped cubit; a supplied cubit is owned by its caller.
class FindPeopleScope extends ConsumerWidget {
  const FindPeopleScope({
    required this.child,
    this.limit = 20,
    this.cubit,
    super.key,
  });
  final Widget child;
  final int limit;
  final FindPeopleCubit? cubit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cubit case final existing?) {
      return BlocProvider.value(value: existing, child: child);
    }
    final repository = ref.watch(findPeopleRepositoryProvider);
    final follows = ref.watch(followRepositoryProvider);
    return BlocProvider(
      key: ObjectKey(repository),
      create: (_) {
        final cubit = FindPeopleCubit(
          repository: repository,
          followRepository: follows,
        );
        unawaited(cubit.load(limit: limit));
        return cubit;
      },
      child: child,
    );
  }
}

/// A small recommendation section that can reuse a preloaded feed cubit.
class FindPeopleRecommendations extends ConsumerWidget {
  const FindPeopleRecommendations({
    this.source = 'feed',
    this.limit = 3,
    this.cubit,
    this.isActive = true,
    this.maxCarouselHeight,
    this.onAction,
    this.onAvailabilityChanged,
    super.key,
  });
  final String source;
  final int limit;
  final FindPeopleCubit? cubit;
  final bool isActive;
  final double? maxCarouselHeight;
  final FindPeopleActionCallback? onAction;
  final ValueChanged<bool>? onAvailabilityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callback =
        onAction ?? ref.watch(findPeopleActionRecorderProvider)(source);
    return FindPeopleScope(
      cubit: cubit,
      limit: limit,
      child: FindPeopleSuggestionsList(
        isActive: isActive,
        layout: FindPeopleSuggestionsLayout.carousel,
        showPagination: false,
        maxCarouselHeight: maxCarouselHeight,
        onAvailabilityChanged: onAvailabilityChanged,
        onAction: callback,
      ),
    );
  }
}

/// How a discovery surface arranges its shared video-led creator cards.
enum FindPeopleSuggestionsLayout { grid, carousel }

/// Thin presentation over the shared cubit's final, eligible creators.
class FindPeopleSuggestionsList extends ConsumerStatefulWidget {
  const FindPeopleSuggestionsList({
    this.isActive = true,
    this.showPagination = true,
    this.layout = FindPeopleSuggestionsLayout.grid,
    this.maxCarouselHeight,
    this.onAction,
    this.onAvailabilityChanged,
    super.key,
  });

  /// Keeps standalone grids and their page within a readable desktop width.
  static const double maxContentWidth = 1040;

  final bool isActive;
  final bool showPagination;
  final FindPeopleSuggestionsLayout layout;

  /// Optional height bound when rendered inside a non-scrolling feed card.
  final double? maxCarouselHeight;
  final FindPeopleActionCallback? onAction;
  final ValueChanged<bool>? onAvailabilityChanged;

  @override
  ConsumerState<FindPeopleSuggestionsList> createState() =>
      _FindPeopleSuggestionsListState();
}

class _FindPeopleSuggestionsListState
    extends ConsumerState<FindPeopleSuggestionsList> {
  bool? _available;

  void _notify(FindPeopleState state) {
    final available = state.suggestions.isNotEmpty;
    if (_available == available) return;
    _available = available;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAvailabilityChanged?.call(available);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive && ref.watch(appForegroundProvider);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.layout == FindPeopleSuggestionsLayout.grid
              ? FindPeopleSuggestionsList.maxContentWidth
              : double.infinity,
        ),
        child: BlocBuilder<FindPeopleCubit, FindPeopleState>(
          builder: (context, state) {
            _notify(state);
            final cubit = context.read<FindPeopleCubit>();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.actionFailed)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.l10n.commonSomethingWentWrong,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                  ),
                if (state.suggestions.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final available = constraints.maxWidth > 32
                          ? constraints.maxWidth - 32
                          : constraints.maxWidth;
                      final carousel =
                          widget.layout == FindPeopleSuggestionsLayout.carousel;
                      final textScale =
                          MediaQuery.textScalerOf(
                            context,
                          ).scale(14) /
                          14;
                      final largeText = textScale > 20 / 14;
                      // Preserve phone pairs; add columns before desktop cards
                      // exceed 320px, with one readable column at large text.
                      final columns = largeText || available < 332
                          ? 1
                          : ((available + 12) / 332).ceil().clamp(2, 4);
                      final width = carousel
                          ? (available * .84).clamp(200.0, 340.0)
                          : largeText
                          ? available.clamp(0.0, 480.0)
                          : (available - (columns - 1) * 12) / columns;
                      final boundedCarouselHeight = carousel
                          ? widget.maxCarouselHeight
                          : null;
                      // When inside a feed interstitial card, cap the preview
                      // height so the carousel fits without a nested vertical
                      // scrollable that would trap vertical feed swipes.
                      final bannerReserve = state.actionFailed
                          ? 32 + 22 * textScale
                          : 0.0;
                      final compactMetadataReserve = 160 * textScale + 44;
                      final fullMetadataReserve = 204 * textScale + 44;
                      double? previewHeight;
                      var showBio = true;
                      if (boundedCarouselHeight != null) {
                        final availableForCard =
                            boundedCarouselHeight - 24 - bannerReserve;
                        final withBio = availableForCard - fullMetadataReserve;
                        if (withBio >= 120) {
                          previewHeight = withBio.clamp(120.0, width);
                        } else {
                          showBio = false;
                          final compact =
                              availableForCard - compactMetadataReserve;
                          previewHeight = compact >= 72
                              ? compact.clamp(72.0, width)
                              : 0;
                        }
                      }
                      final cards = [
                        for (
                          var index = 0;
                          index < state.suggestions.length;
                          index++
                        )
                          SizedBox(
                            key: ValueKey(state.suggestions[index].pubkey),
                            width: width,
                            child: _CreatorCard(
                              key: ValueKey(
                                'creator-card:${state.suggestions[index].pubkey}',
                              ),
                              suggestion: state.suggestions[index],
                              position: index,
                              isActive: isActive,
                              isPending: state.pendingPubkeys.contains(
                                state.suggestions[index].pubkey,
                              ),
                              previewHeight: previewHeight,
                              showBio: showBio,
                              onAction: widget.onAction,
                            ),
                          ),
                      ];
                      if (carousel) {
                        return SingleChildScrollView(
                          key: const ValueKey('people-carousel'),
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 12,
                            children: cards,
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Wrap(
                          alignment: largeText
                              ? WrapAlignment.center
                              : WrapAlignment.start,
                          spacing: 12,
                          runSpacing: 16,
                          children: cards,
                        ),
                      );
                    },
                  ),
                if (state.status == FindPeopleStatus.loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: BrandedLoadingIndicator()),
                  )
                else if (state.status == FindPeopleStatus.failure)
                  _PeopleSuggestionsError(
                    onRetry: () => unawaited(cubit.retry()),
                  )
                else if (widget.showPagination && state.nextCursor != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DivineButton(
                      label: context.l10n.findPeopleLoadMore,
                      onPressed: () => unawaited(cubit.loadMore()),
                    ),
                  )
                else if (state.suggestions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.l10n.findPeopleEmpty,
                      textAlign: TextAlign.center,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.secondaryText,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Uses the existing compact search-error presentation without a new message.
class _PeopleSuggestionsError extends StatelessWidget {
  const _PeopleSuggestionsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            DivineIcon(
              icon: DivineIconName.warningCircle,
              color: context.vineColors.secondaryText,
              size: 48,
            ),
            Text(
              context.l10n.commonSomethingWentWrong,
              textAlign: TextAlign.center,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: DivineButton(
                label: context.l10n.commonRetry,
                type: DivineButtonType.secondary,
                size: DivineButtonSize.small,
                maxLines: 2,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shared image-led creator card. Keeping one keyed state per creator prevents
/// a carousel peek, prefetch or a layout rebuild from creating an exposure.
class _CreatorCard extends StatefulWidget {
  const _CreatorCard({
    required this.suggestion,
    required this.position,
    required this.isActive,
    required this.isPending,
    this.previewHeight,
    this.showBio = true,
    this.onAction,
    super.key,
  });
  final FollowSuggestion suggestion;
  final int position;
  final bool isActive;
  final bool isPending;
  final double? previewHeight;
  final bool showBio;
  final FindPeopleActionCallback? onAction;

  @override
  State<_CreatorCard> createState() => _CreatorCardState();
}

class _CreatorCardState extends State<_CreatorCard> {
  final Key _visibilityKey = UniqueKey();
  bool _visible = false;
  bool _exposed = false;

  void _recordExposure() {
    if (!_exposed && _visible && widget.isActive) {
      _exposed = true;
      widget.onAction?.call('exposed', widget.suggestion, widget.position);
    }
  }

  @override
  void didUpdateWidget(covariant _CreatorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recordExposure();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = widget.suggestion;
    final profile = suggestion.profile;
    final name = sanitizeForDisplay(
      profile.displayName ??
          profile.name ??
          Nip19.encodePubKey(suggestion.pubkey),
    );
    void openProfile() => unawaited(
      OtherProfileRouteData(
        npub: Nip19.encodePubKey(suggestion.pubkey),
        $extra: {'displayName': name, 'avatarUrl': profile.picture},
      ).push<void>(context),
    );
    final showPreview = widget.previewHeight != 0;
    Future<void> handleDismiss() async {
      final callback = widget.onAction;
      final position = widget.position;
      if (await context.read<FindPeopleCubit>().dismiss(suggestion)) {
        callback?.call('dismissed', suggestion, position);
      }
    }

    final previewStack = Stack(
      fit: StackFit.expand,
      children: [
        _CreatorPreview(
          suggestion: suggestion,
          name: name,
          onProfile: openProfile,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: DivineIconButton(
            icon: DivineIconName.x,
            type: DivineIconButtonType.ghostOverMedia,
            semanticLabel: context.l10n.findPeopleDismiss,
            tooltip: context.l10n.findPeopleDismiss,
            onPressed: widget.isPending ? null : handleDismiss,
          ),
        ),
      ],
    );
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        _visible = info.visibleFraction >= .5;
        _recordExposure();
      },
      child: Material(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showPreview)
              if (widget.previewHeight case final height?)
                SizedBox(height: height, child: previewStack)
              else
                AspectRatio(aspectRatio: 1, child: previewStack),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: name,
                          child: InkWell(
                            onTap: openProfile,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Row(
                                children: [
                                  ExcludeSemantics(
                                    child: UserAvatar(
                                      imageUrl: profile.picture,
                                      name: name,
                                      size: 32,
                                      placeholderSeed: suggestion.pubkey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ExcludeSemantics(
                                      child: Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: VineTheme.titleMediumFont(
                                          color: context.vineColors.primaryText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!showPreview)
                        DivineIconButton(
                          icon: DivineIconName.x,
                          type: DivineIconButtonType.ghost,
                          semanticLabel: context.l10n.findPeopleDismiss,
                          tooltip: context.l10n.findPeopleDismiss,
                          onPressed: widget.isPending ? null : handleDismiss,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    suggestion.isClassic
                        ? context.l10n.findPeopleArchive
                        : context.l10n.findPeopleSuggested,
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  if (widget.showBio &&
                      profile.about != null &&
                      profile.about!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      sanitizeForDisplay(profile.about!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.secondaryText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DivineButton(
                    label: context.l10n.profileFollowLabel,
                    expanded: true,
                    onPressed: widget.isPending
                        ? null
                        : () async {
                            final callback = widget.onAction;
                            final position = widget.position;
                            final outcome = await context
                                .read<FindPeopleCubit>()
                                .follow(suggestion);
                            if (outcome == FollowOutcome.published) {
                              callback?.call('followed', suggestion, position);
                            }
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Image-only preview. The explicit video route performs any video lookup
/// after a tap; rendering this widget never creates a decoder or video event.
class _CreatorPreview extends StatelessWidget {
  const _CreatorPreview({
    required this.suggestion,
    required this.name,
    required this.onProfile,
  });

  final FollowSuggestion suggestion;
  final String name;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final preview = suggestion.videoPreview;
    if (preview == null) {
      return ColoredBox(
        color: context.vineColors.surfaceContainerHigh,
        child: Center(
          child: UserAvatar(
            imageUrl: suggestion.profile.picture,
            name: name,
            size: 64,
            placeholderSeed: suggestion.pubkey,
            semanticLabel: name,
            onTap: onProfile,
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: context.l10n.videoPlayerPlayVideo,
      child: InkWell(
        key: ValueKey('creator-preview:${suggestion.pubkey}'),
        onTap: () => unawaited(
          VideoDetailRouteData(
            id: preview.id,
            author: suggestion.pubkey,
          ).push<void>(context),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            BlurhashDisplay(blurhash: preview.blurhash),
            PassiveAuthThumbnailImage(
              url: preview.thumbnailUrl,
              videoId: preview.id,
              alignment: Alignment.center,
              errorWidget: (_, _, _) =>
                  BlurhashDisplay(blurhash: preview.blurhash),
            ),
            const Center(
              child: SizedBox.square(
                dimension: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: VineTheme.scrim56,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: DivineIcon(
                      icon: DivineIconName.play,
                      color: VineTheme.whiteText,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
