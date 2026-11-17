// ABOUTME: Shared recommendations for the permanent page and optional feed card.
// ABOUTME: Exposure fires only when a row is visible on an active surface.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/find_people/find_people_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/find_people_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/user_avatar.dart';
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
        showPagination: false,
        onAvailabilityChanged: onAvailabilityChanged,
        onAction: callback,
      ),
    );
  }
}

/// Thin presentation over the shared cubit's final, eligible rows.
class FindPeopleSuggestionsList extends StatefulWidget {
  const FindPeopleSuggestionsList({
    this.isActive = true,
    this.showPagination = true,
    this.onAction,
    this.onAvailabilityChanged,
    super.key,
  });
  final bool isActive;
  final bool showPagination;
  final FindPeopleActionCallback? onAction;
  final ValueChanged<bool>? onAvailabilityChanged;

  @override
  State<FindPeopleSuggestionsList> createState() =>
      _FindPeopleSuggestionsListState();
}

class _FindPeopleSuggestionsListState extends State<FindPeopleSuggestionsList> {
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
  Widget build(BuildContext context) =>
      BlocBuilder<FindPeopleCubit, FindPeopleState>(
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
                    style: TextStyle(color: context.vineColors.primaryText),
                  ),
                ),
              for (var index = 0; index < state.suggestions.length; index++)
                _SuggestionTile(
                  key: ValueKey(state.suggestions[index].pubkey),
                  suggestion: state.suggestions[index],
                  position: index,
                  isActive: widget.isActive,
                  isPending: state.pendingPubkeys.contains(
                    state.suggestions[index].pubkey,
                  ),
                  onAction: widget.onAction,
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
                    style: TextStyle(color: context.vineColors.secondaryText),
                  ),
                ),
            ],
          );
        },
      );
}

class _SuggestionTile extends StatefulWidget {
  const _SuggestionTile({
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
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
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
  void didUpdateWidget(covariant _SuggestionTile oldWidget) {
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
    final reason = suggestion.isClassic
        ? context.l10n.findPeopleArchive
        : context.l10n.findPeopleSuggested;
    void openProfile() => unawaited(
      OtherProfileRouteData(
        npub: Nip19.encodePubKey(suggestion.pubkey),
        $extra: {'displayName': name, 'avatarUrl': profile.picture},
      ).push<void>(context),
    );
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        _visible = info.visibleFraction >= 0.5;
        _recordExposure();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UserAvatar(
                  imageUrl: profile.picture,
                  name: name,
                  placeholderSeed: suggestion.pubkey,
                  onTap: openProfile,
                  semanticLabel: name,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: openProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VineTheme.titleSmallFont(
                            color: context.vineColors.primaryText,
                          ),
                        ),
                        Text(
                          reason,
                          style: VineTheme.bodySmallFont(
                            color: context.vineColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DivineIconButton(
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
                            callback?.call('dismissed', suggestion, position);
                          }
                        },
                ),
              ],
            ),
            if (profile.about case final about? when about.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  sanitizeForDisplay(about),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.vineColors.secondaryText),
                ),
              ),
            const SizedBox(height: 12),
            DivineButton(
              label: context.l10n.profileFollowLabel,
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
    );
  }
}
