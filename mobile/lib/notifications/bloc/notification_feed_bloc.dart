// ABOUTME: BLoC for the notification feed — subscribes to the repository's
// ABOUTME: snapshot stream, projects it into state, and forwards mutations
// ABOUTME: (mark-read, refresh, follow-back) to the repository.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/notifications/bloc/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/app_badge_service.dart';

part 'notification_feed_event.dart';
part 'notification_feed_state.dart';

/// BLoC for managing the notification feed.
///
/// Subscribes to [NotificationRepository.watchSnapshot] so the visible
/// list, unread counts, and per-row read state always reflect the single
/// source of truth shared with the badge cubit. Event handlers forward
/// mutations to the repository; the resulting snapshot emission drives
/// the next state.
class NotificationFeedBloc
    extends Bloc<NotificationFeedEvent, NotificationFeedState> {
  NotificationFeedBloc({
    required NotificationRepository notificationRepository,
    required FollowRepository followRepository,
    required AppBadgeClearer appBadgeClearer,
    NotificationKind? filter,
  }) : _notificationRepository = notificationRepository,
       _followRepository = followRepository,
       _appBadgeClearer = appBadgeClearer,
       _filter = filter,
       super(const NotificationFeedState()) {
    on<_SnapshotChanged>(_onSnapshotChanged);
    on<NotificationFeedStarted>(_onStarted, transformer: droppable());
    on<NotificationFeedLoadMore>(_onLoadMore, transformer: droppable());
    on<NotificationFeedRefreshed>(_onRefreshed, transformer: droppable());
    on<NotificationFeedBecameVisible>(
      _onBecameVisible,
      transformer: droppable(),
    );
    on<NotificationFeedItemTapped>(_onItemTapped);
    on<NotificationFeedFollowBack>(_onFollowBack, transformer: sequential());

    // Project the repository's snapshot stream into BLoC state via a
    // private event so emit() stays inside an event handler.
    _snapshotSubscription = _notificationRepository
        .watchSnapshot(filter: _filter)
        .listen((page) => addIfOpen(_SnapshotChanged(page)));
  }

  final NotificationRepository _notificationRepository;
  final FollowRepository _followRepository;
  final AppBadgeClearer _appBadgeClearer;
  final NotificationKind? _filter;
  late final StreamSubscription<NotificationPage> _snapshotSubscription;
  int _emptyPageContinuations = 0;
  bool _loadMoreFailed = false;
  bool _emptyPageContinuationPending = false;
  bool _markSeenInFlight = false;

  static const _maxEmptyPageContinuations = 3;

  /// Override [ActorNotification.isFollowingBack] for follow-type rows so the
  /// flag tracks the authoritative follow state in [FollowRepository] rather
  /// than a transient bloc mutation. Without this, the "Follow back" button
  /// reappears after the page is unmounted and remounted because the bloc is
  /// rebuilt with a fresh `isFollowingBack: false` from the repository.
  List<NotificationItem> _applyFollowState(Iterable<NotificationItem> items) {
    return items.map((item) {
      if (item is! ActorNotification || item.type != NotificationKind.follow) {
        return item;
      }
      final isFollowing = _followRepository.isFollowing(item.actor.pubkey);
      if (isFollowing == item.isFollowingBack) return item;
      return item.copyWith(isFollowingBack: isFollowing);
    }).toList();
  }

  /// Project each repository snapshot into BLoC state.
  void _onSnapshotChanged(
    _SnapshotChanged event,
    Emitter<NotificationFeedState> emit,
  ) {
    final notifications = _applyFollowState(event.page.items);
    emit(
      state.copyWith(
        notifications: notifications,
        unreadCount: event.page.unreadCount,
        hasMore: event.page.hasMore,
        refreshError: event.page.lastRefreshError,
      ),
    );
    _continuePastEmptyPageIfNeeded(notifications);
  }

  /// Keeps an all-filtered-out page paginating instead of rendering as an
  /// empty tab while the server still reports more rows.
  ///
  /// The repository emits the snapshot from inside `refreshFeed`, before it
  /// completes, so on the first open this runs while `_onStarted` still
  /// holds `isRefreshing: true` and `status: initial`. Dispatching a
  /// load-more there would race the refresh's cursor reset, but simply
  /// bailing strands the tab: no further snapshot follows, so it settles
  /// empty with `hasMore: true` and never paginates. Defer instead, and
  /// let [_flushPendingEmptyPageContinuation] pick it up once the refresh
  /// handler has settled.
  void _continuePastEmptyPageIfNeeded(List<NotificationItem> notifications) {
    if (notifications.isNotEmpty || !state.hasMore) {
      _emptyPageContinuations = 0;
      _loadMoreFailed = false;
      _emptyPageContinuationPending = false;
      return;
    }
    if (_loadMoreFailed ||
        _emptyPageContinuations >= _maxEmptyPageContinuations) {
      return;
    }
    if (state.status != NotificationFeedStatus.loaded ||
        state.isLoadingMore ||
        state.isRefreshing) {
      _emptyPageContinuationPending = true;
      return;
    }
    _emptyPageContinuationPending = false;
    _emptyPageContinuations += 1;
    add(const NotificationFeedLoadMore());
  }

  /// Re-runs a continuation that [_continuePastEmptyPageIfNeeded] had to
  /// defer because a refresh was still in flight when the empty page landed.
  void _flushPendingEmptyPageContinuation() {
    if (!_emptyPageContinuationPending) return;
    _emptyPageContinuationPending = false;
    _continuePastEmptyPageIfNeeded(state.notifications);
  }

  /// Handle initial load.
  ///
  /// Triggers `refresh()` on the repository. The resulting snapshot is
  /// translated into state by `_onSnapshotChanged`. Status transitions
  /// (loading -> loaded / failure) are emitted here so the UI can render
  /// the initial spinner and error states.
  ///
  /// After a successful refresh, sends the server mark-all write via
  /// [_markSeenOnOpen] so opening the notifications surface clears the unread
  /// badge and the badge thereafter reflects "new since last seen" rather than
  /// the accumulated untapped total (#4708). `_onStarted` fires once per open
  /// (it is dispatched from the keyed `BlocProvider.create` on every mount of
  /// the notifications surface) and is NOT dispatched on app resume. The
  /// unfiltered pull-to-refresh handler also marks seen after a successful
  /// refresh because the notifications surface is already deliberately open.
  Future<void> _onStarted(
    NotificationFeedStarted event,
    Emitter<NotificationFeedState> emit,
  ) async {
    _emptyPageContinuations = 0;
    _loadMoreFailed = false;
    _emptyPageContinuationPending = false;
    // Stale-while-revalidate: keep any hydrated/cached items rendered and
    // flag the in-flight refresh so the view shows a thin progress bar
    // instead of a blanking full-screen spinner.
    emit(state.copyWith(isRefreshing: true));

    try {
      await _notificationRepository.refreshFeed(_filter);
      var markSucceeded = false;
      if (_filter == null) {
        // `loaded` is what dismisses the cold-start full-screen spinner, and
        // it has to land with the data: holding it across the mark-all write
        // blanks an empty inbox for the whole sign + POST (15s client
        // timeout). `isRefreshing` stays up instead, because the revalidation
        // bar has to span the droppable handler's drop window so a second
        // pull is never dropped against an idle-looking UI.
        emit(state.copyWith(status: NotificationFeedStatus.loaded));
        markSucceeded = await _markSeenOnOpen();
      }
      emit(
        state.copyWith(
          status: NotificationFeedStatus.loaded,
          isRefreshing: false,
        ),
      );
      _flushPendingEmptyPageContinuation();
      if (markSucceeded) {
        unawaited(_clearAppBadge());
      }
    } on Exception catch (e, s) {
      // `NotificationRepository.refresh` propagates typed
      // `FunnelcakeException` (4xx/5xx/timeout; transient-retry
      // exhausted on first page). Per .claude/rules/error_handling.md
      // they are NOT Reportable — the UI either keeps cached items
      // with an inline `refreshError` banner or falls back to
      // `NotificationFeedStatus.failure`.
      //
      // Hard-failure only fires when the cache is also empty — the
      // repository surfaces `lastRefreshError` on the snapshot, and
      // the view renders an inline banner on top of cached items in
      // that case. `state.notifications` already reflects any hydrated
      // cache because `_onSnapshotChanged` runs before this catch arm
      // if the repository emitted before throwing.
      addError(e, s);
      final hasCachedItems = state.notifications.isNotEmpty;
      emit(
        state.copyWith(
          status: hasCachedItems
              ? NotificationFeedStatus.loaded
              : NotificationFeedStatus.failure,
          isRefreshing: false,
          refreshError: true,
        ),
      );
      return;
    } catch (e, s) {
      // Errors (StateError, TypeError, RangeError) escape `on Exception`
      // and reach here. Per .claude/rules/error_handling.md they are
      // matrix-YES invariant violations — wrap with Reportable so
      // DivineBlocObserver forwards to Crashlytics. Recovery emit
      // mirrors the matrix-NO arm so the UX is preserved.
      addError(
        Reportable(e, context: NotificationFeedBlocReportableSites.onStarted),
        s,
      );
      final hasCachedItems = state.notifications.isNotEmpty;
      emit(
        state.copyWith(
          status: hasCachedItems
              ? NotificationFeedStatus.loaded
              : NotificationFeedStatus.failure,
          isRefreshing: false,
          refreshError: true,
        ),
      );
      return;
    }
  }

  /// Marks notifications seen when the notifications surface is open.
  ///
  /// Reuses [NotificationRepository.markAllAsRead] — the single source of truth
  /// that sends the server mark-all write, optimistically flips the snapshot
  /// (so the badge clears immediately), and rolls back on failure.
  /// Going through the repository (not a widget lifecycle hook) is what keeps
  /// the badge convergent; the previous `MarkAllReadOnDispose` widget that
  /// marked-on-*leave* fought the snapshot and was removed in #4758. This marks
  /// while the notifications surface is deliberately open instead.
  ///
  /// A seen-advance failure must never blacken the feed, so every error is
  /// caught here and never rethrown — the repository has already restored the
  /// snapshot on failure, so the list stays usable.
  Future<bool> _markSeenOnOpen() async {
    if (_markSeenInFlight) return false;
    _markSeenInFlight = true;
    try {
      await _notificationRepository.markAllAsRead();
      return true;
    } on Exception catch (e, s) {
      // Typed `FunnelcakeException` (4xx/5xx/timeout) + Drift DAO failures the
      // repository rethrows after rolling the optimistic flip back. Per
      // .claude/rules/error_handling.md these are expected domain failures,
      // NOT Reportable.
      addError(e, s);
      return false;
    } catch (e, s) {
      // Errors (StateError, TypeError) — matrix-YES invariant violation.
      // A closed repository is an account switch, not an invariant break:
      // report failure (and leave the OS badge alone) instead of clearing it
      // for a mark-all that was never sent.
      if (_notificationRepository.isClosed) return false;
      addError(
        Reportable(
          e,
          context: NotificationFeedBlocReportableSites.markSeenOnOpen,
        ),
        s,
      );
      return false;
    } finally {
      _markSeenInFlight = false;
    }
  }

  /// Clears the platform app-icon badge once the seen watermark has advanced.
  ///
  /// Best-effort: a badge failure must never affect feed state, so nothing here
  /// is rethrown. [AppBadgeService] already absorbs `PlatformException` and
  /// `MissingPluginException` itself, so failures reaching these arms are
  /// surfaced through the observer rather than a direct warning log.
  Future<void> _clearAppBadge() async {
    try {
      await _appBadgeClearer.clear();
    } on Exception catch (e, s) {
      // Platform/plugin failures the service did not already absorb. Per
      // .claude/rules/error_handling.md these are expected domain failures,
      // NOT Reportable.
      addError(e, s);
    } catch (e, s) {
      // Errors (StateError, TypeError) — matrix-YES invariant violation.
      addError(
        Reportable(
          e,
          context: NotificationFeedBlocReportableSites.clearAppBadge,
        ),
        s,
      );
    }
  }

  /// Handle scroll pagination.
  ///
  /// Deliberately does NOT consult [_loadMoreFailed]: that flag only stops
  /// the automatic empty-page continuation from re-arming. A load-more
  /// failure emits no snapshot (`_markRefreshError` is first-page-only) and
  /// surfaces no error affordance, so gating this handler on it would leave
  /// a user who hit one transient 5xx at the bottom of the list unable to
  /// paginate for the rest of the session.
  Future<void> _onLoadMore(
    NotificationFeedLoadMore event,
    Emitter<NotificationFeedState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      await _notificationRepository.loadNextPageFor(_filter);
      emit(state.copyWith(isLoadingMore: false));
      // The page this call fetched lands on the snapshot while
      // `isLoadingMore` is still true, so a page that filters down to
      // nothing parks its continuation instead of dispatching it. Flush it
      // here — otherwise only the first of [_maxEmptyPageContinuations]
      // could ever fire, and a Comments feed whose pages are mostly video
      // mentions would get one extra page of runway instead of three.
      _flushPendingEmptyPageContinuation();
    } on Exception catch (e, s) {
      _loadMoreFailed = true;
      // `NotificationRepository.loadNextPage` (single-attempt
      // paginate-load-more) propagates typed `FunnelcakeException`
      // (4xx/5xx/timeout). Per .claude/rules/error_handling.md they
      // are NOT Reportable — the BLoC recovers `isLoadingMore: false`.
      addError(e, s);
      emit(state.copyWith(isLoadingMore: false));
    } catch (e, s) {
      _loadMoreFailed = true;
      // Errors (StateError, TypeError) — matrix-YES invariant.
      addError(
        Reportable(e, context: NotificationFeedBlocReportableSites.onLoadMore),
        s,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Handle pull-to-refresh.
  Future<void> _onRefreshed(
    NotificationFeedRefreshed event,
    Emitter<NotificationFeedState> emit,
  ) async {
    // Started and Refreshed have separate droppable transformers, so guard the
    // shared busy state explicitly to prevent the two handlers overlapping.
    if (state.isRefreshing) return;
    _emptyPageContinuations = 0;
    _loadMoreFailed = false;
    _emptyPageContinuationPending = false;
    emit(state.copyWith(isRefreshing: true));
    try {
      await _notificationRepository.refreshFeed(_filter);
      if (_filter == null) {
        // Same split as `_onStarted`, and it also matters here: a retry
        // dispatched from `_FailureBody` leaves `status: failure` until this
        // emit, so holding it would keep the error screen up over a refresh
        // that already succeeded.
        emit(state.copyWith(status: NotificationFeedStatus.loaded));
        await _markSeenOnOpen();
      }
      emit(
        state.copyWith(
          status: NotificationFeedStatus.loaded,
          isRefreshing: false,
        ),
      );
      _flushPendingEmptyPageContinuation();
    } on Exception catch (e, s) {
      // `NotificationRepository.refresh` propagates typed
      // `FunnelcakeException` (4xx/5xx/timeout). Per
      // .claude/rules/error_handling.md they are NOT Reportable —
      // the UI either keeps cached items with `refreshError: true`
      // or falls back to `NotificationFeedStatus.failure`.
      addError(e, s);
      final hasCachedItems = state.notifications.isNotEmpty;
      emit(
        state.copyWith(
          status: hasCachedItems
              ? NotificationFeedStatus.loaded
              : NotificationFeedStatus.failure,
          isRefreshing: false,
          refreshError: true,
        ),
      );
    } catch (e, s) {
      // Errors (StateError, TypeError) — matrix-YES invariant.
      // Recovery emit mirrors the matrix-NO arm so the UX is preserved.
      addError(
        Reportable(e, context: NotificationFeedBlocReportableSites.onRefreshed),
        s,
      );
      final hasCachedItems = state.notifications.isNotEmpty;
      emit(
        state.copyWith(
          status: hasCachedItems
              ? NotificationFeedStatus.loaded
              : NotificationFeedStatus.failure,
          isRefreshing: false,
          refreshError: true,
        ),
      );
    }
  }

  /// Handle the kept-alive inbox branch becoming visible again.
  Future<void> _onBecameVisible(
    NotificationFeedBecameVisible event,
    Emitter<NotificationFeedState> emit,
  ) async {
    if (_filter != null) return;
    final markSucceeded = await _markSeenOnOpen();
    if (markSucceeded) {
      unawaited(_clearAppBadge());
    }
  }

  /// Handle notification tap — forwards to the repository, which
  /// optimistically flips the row in the snapshot and writes to the
  /// server. The resulting snapshot emission updates this BLoC's state
  /// and the badge cubit's count atomically.
  Future<void> _onItemTapped(
    NotificationFeedItemTapped event,
    Emitter<NotificationFeedState> emit,
  ) async {
    try {
      await _notificationRepository.markAsRead([event.notificationId]);
    } on Exception catch (e, s) {
      // `NotificationRepository.markAsRead` propagates
      // `FunnelcakeException` and local Drift DAO write failures
      // after rolling the optimistic snapshot back. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, s);
    } catch (e, s) {
      // Errors (StateError, TypeError) — matrix-YES invariant. A closed
      // repository marks an account switch, not an invariant break.
      if (_notificationRepository.isClosed) return;
      addError(
        Reportable(
          e,
          context: NotificationFeedBlocReportableSites.onItemTapped,
        ),
        s,
      );
    }
  }

  /// Handle follow-back action.
  ///
  /// Calls the follow repository, then re-derives [isFollowingBack] from the
  /// repository's authoritative state. The flag is not stored on the bloc;
  /// the next [_applyFollowState] pass on a refresh/remount will reflect the
  /// same value, so the button stays hidden across navigation.
  Future<void> _onFollowBack(
    NotificationFeedFollowBack event,
    Emitter<NotificationFeedState> emit,
  ) async {
    try {
      await _followRepository.follow(event.pubkey);
      emit(
        state.copyWith(notifications: _applyFollowState(state.notifications)),
      );
    } on Exception catch (e, s) {
      // `FollowRepository.follow` propagates `Exception('User not
      // authenticated')` (auth/session) and relay-IO failures from
      // contact-list broadcast — the repo rolls back the optimistic
      // follow internally. Per .claude/rules/error_handling.md they
      // are NOT Reportable.
      addError(e, s);
    } catch (e, s) {
      if (e is ArgumentError && e.invalidValue == event.pubkey) {
        // `FollowRepository.follow` rejects a malformed follow target before
        // it can poison the Kind 3 list. The value comes off a
        // relay/FunnelCake payload, so this is input validation — matrix-NO,
        // not an invariant. Matching on the value keeps the arm to that one
        // throw: `RangeError` and `IndexError` extend `ArgumentError`, and
        // the Kind 3 broadcast throws the same type for our *own* pubkey.
        // `follow` returns early on self-follow, so the two cannot collide.
        addError(e, s);
        return;
      }
      // Any other `Error` — a signer `StateError` raised while broadcasting
      // the contact list, a `RangeError`, or an `ArgumentError` carrying our
      // own pubkey — is a matrix-YES invariant.
      addError(
        Reportable(
          e,
          context: NotificationFeedBlocReportableSites.onFollowBack,
        ),
        s,
      );
    }
  }

  @override
  Future<void> close() async {
    await _snapshotSubscription.cancel();
    _notificationRepository.resetPaginationDepth(filter: _filter);
    return super.close();
  }
}

/// Private event used to inject repository snapshot emissions into the
/// BLoC's event-handler pipeline.
final class _SnapshotChanged extends NotificationFeedEvent {
  const _SnapshotChanged(this.page);

  final NotificationPage page;

  @override
  List<Object?> get props => [page];
}
