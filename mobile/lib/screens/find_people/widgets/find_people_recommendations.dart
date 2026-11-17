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
    this.onAction,
    this.onAvailabilityChanged,
    super.key,
  });
  final String source;
  final int limit;
  final FindPeopleCubit? cubit;
  final bool isActive;
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
    this.onAction,
    this.onAvailabilityChanged,
    super.key,
  });
  final bool isActive;
  final bool showPagination;
  final FindPeopleSuggestionsLayout layout;
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
    return BlocBuilder<FindPeopleCubit, FindPeopleState>(
      builder: (context, state) {
        _notify(state);
        final cubit = context.read<FindPeopleCubit>();
        return Column(
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
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(14) > 20;
                  final columns = !largeText && available >= 332 ? 2 : 1;
                  final width = carousel
                      ? (available * .84).clamp(200.0, 340.0)
                      : (available - (columns - 1) * 12) / columns;
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
                    child: Wrap(spacing: 12, runSpacing: 16, children: cards),
                  );
                },
              ),
            if (state.status == FindPeopleStatus.loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: BrandedLoadingIndicator()),
              )
            else if (state.status == FindPeopleStatus.failure) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.commonSomethingWentWrong),
              ),
              DivineButton(
                label: context.l10n.commonRetry,
                onPressed: () => unawaited(cubit.retry()),
              ),
            ] else if (widget.showPagination && state.nextCursor != null)
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
    );
  }
}

/// Shared image-led creator card. Keeping one keyed state per creator prevents
/// a carousel peek, prefetch or a layout rebuild from creating an exposure.
class _CreatorCard extends StatefulWidget {
  const _CreatorCard({
    required this.suggestion,
    required this.position,
    required this.isActive,
    required this.isPending,
    this.onAction,
    super.key,
  });
  final FollowSuggestion suggestion;
  final int position;
  final bool isActive;
  final bool isPending;
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
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
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
                      type: DivineIconButtonType.ghost,
                      semanticLabel: context.l10n.findPeopleDismiss,
                      tooltip: context.l10n.findPeopleDismiss,
                      onPressed: widget.isPending
                          ? null
                          : () async {
                              final callback = widget.onAction;
                              final position = widget.position;
                              if (await context.read<FindPeopleCubit>().dismiss(
                                suggestion,
                              )) {
                                callback?.call(
                                  'dismissed',
                                  suggestion,
                                  position,
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(
                        imageUrl: profile.picture,
                        name: name,
                        size: 28,
                        placeholderSeed: suggestion.pubkey,
                        onTap: openProfile,
                        semanticLabel: name,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: openProfile,
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
                  const SizedBox(height: 8),
                  Text(
                    suggestion.isClassic
                        ? context.l10n.findPeopleArchive
                        : context.l10n.findPeopleSuggested,
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  if (profile.about case final about?
                      when about.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      sanitizeForDisplay(about),
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
              child: DivineIcon(
                icon: DivineIconName.play,
                color: VineTheme.whiteText,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
