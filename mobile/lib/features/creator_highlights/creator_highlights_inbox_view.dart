// ABOUTME: Bridges account dependencies into an account-keyed highlights Cubit.
// ABOUTME: Loads on visible Inbox visits without blocking the notification feed.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/creator_highlights/creator_highlight_card.dart';
import 'package:openvine/features/creator_highlights/creator_highlights_cubit.dart';
import 'package:openvine/features/creator_highlights/creator_highlights_repository.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

final creatorHighlightsRepositoryProvider =
    Provider<CreatorHighlightsRepository>((ref) {
      final preferences = ref.watch(sharedPreferencesProvider);
      return FunnelcakeCreatorHighlightsRepository(
        client: ref.watch(funnelcakeApiClientProvider),
        preferences: preferences,
        locallyDeletedAddresses: () => {
          for (final entry in ContentDeletionService.parseDeletionHistory(
            preferences.getString(ContentDeletionService.deletionsStorageKey),
          ))
            ?entry.addressableId:
                entry.deletedAt.millisecondsSinceEpoch ~/ 1000,
        },
        locallyDeletedEventIds: () => {
          for (final entry in ContentDeletionService.parseDeletionHistory(
            preferences.getString(ContentDeletionService.deletionsStorageKey),
          ))
            entry.originalEventId,
        },
      );
    });

class CreatorHighlightsInboxView extends ConsumerWidget {
  const CreatorHighlightsInboxView({required this.isVisible, super.key});
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentAuthStateProvider);
    ref.watch(currentAccountActivationReceiptProvider);
    final auth = ref.watch(authServiceProvider);
    final owner = auth.isAuthenticated ? auth.currentPublicKeyHex : null;
    if (owner == null || owner.isEmpty) return const NotificationsView();
    final repository = ref.watch(creatorHighlightsRepositoryProvider);
    return BlocProvider(
      key: ValueKey((owner, repository)),
      create: (_) =>
          CreatorHighlightsCubit(repository: repository, owner: owner),
      child: _HighlightsInboxBody(
        isVisible: isVisible && !ref.watch(shellObscuredProvider),
      ),
    );
  }
}

class _HighlightsInboxBody extends StatefulWidget {
  const _HighlightsInboxBody({required this.isVisible});
  final bool isVisible;

  @override
  State<_HighlightsInboxBody> createState() => _HighlightsInboxBodyState();
}

class _HighlightsInboxBodyState extends State<_HighlightsInboxBody>
    with WidgetsBindingObserver {
  Timer? _dayBoundary;
  bool _foreground = true;
  bool get _isVisible => widget.isVisible && _foreground;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (_isVisible) _refresh();
  }

  @override
  void didUpdateWidget(_HighlightsInboxBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isVisible) _dayBoundary?.cancel();
    if (!oldWidget.isVisible && _isVisible) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground != foreground) setState(() => _foreground = foreground);
    if (_isVisible) {
      _refresh();
    } else {
      _dayBoundary?.cancel();
    }
  }

  void _refresh() {
    if (!_isVisible) return;
    _dayBoundary?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    // Refresh the dated copy at the next local calendar boundary, not every 24h.
    _dayBoundary = Timer(midnight.difference(now), () {
      if (mounted && _isVisible) _refresh();
    });
    runDetached(
      context.read<CreatorHighlightsCubit>().refresh(),
      'refresh private creator highlights',
      logName: 'CreatorHighlights',
      category: LogCategory.ui,
    );
  }

  void _open(String path, {Object? extra}) => runDetached(
    context.push<void>(path, extra: extra),
    'open creator highlight action',
    logName: 'CreatorHighlights',
    category: LogCategory.ui,
  );

  @override
  void dispose() {
    _dayBoundary?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<CreatorHighlightsCubit, CreatorHighlightsState>(
    builder: (context, state) => NotificationsView(
      onRefresh: _refresh,
      header: state.card == null
          ? null
          : CreatorHighlightCard(
              highlight: state.card!,
              isVisible: _isVisible,
              onPresented: () => runDetached(
                context.read<CreatorHighlightsCubit>().presented(state.card!),
                'record creator highlight presentation',
                logName: 'CreatorHighlights',
                category: LogCategory.ui,
              ),
              onCreate: () => _open(RoutePaths.videoRecorder),
              onAnalytics: () => _open(RoutePaths.creatorAnalytics),
              onWatch: () {
                final video = state.card?.topVideo;
                if (video != null) {
                  _open(
                    RoutePaths.videoDetailForId(video.id),
                    extra: VideoDetailRouteExtra(initialVideo: video),
                  );
                }
              },
            ),
    ),
  );
}
