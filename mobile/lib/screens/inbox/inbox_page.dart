// ABOUTME: Inbox page that provides BLoC dependencies for the inbox view.
// ABOUTME: Sets up ConversationListBloc and MyFollowingBloc from Riverpod
// ABOUTME: providers. The DmRepository
// ABOUTME: gift-wrap subscription is auth-session-scoped via
// ABOUTME: dmRepositoryProvider, not driven by this screen's lifecycle.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/dm/conversation_actions/conversation_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';

/// Inbox page (DM conversation list + notifications).
///
/// Provides [ConversationListBloc] and [MyFollowingBloc] to the widget
/// tree. The gift-wrap subscription that
/// powers DM ingestion is owned by `dmRepositoryProvider` for the entire
/// authenticated session — this screen does NOT start or stop it (#2931).
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  /// Route name for this screen.
  static const routeName = 'inbox';

  /// Path for this route.
  static const String path = RoutePaths.inbox;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final currentUserPubkey =
        ref.watch(authServiceProvider).currentPublicKeyHex ?? '';
    final protectedMinorInboxGate = ref.watch(protectedMinorInboxGateProvider);

    // No status-bar override here: the inbox renders no app bar, so the
    // app-level AnnotatedRegion in main.dart — which picks its icon
    // brightness from the resolved appearance mode — is what should apply.
    // A hardcoded style would pin white icons onto the light-mode header.
    return MultiBlocProvider(
      // `dmRepositoryProvider` is keepAlive but its body rebuilds a
      // brand-new DmRepository whenever the nostr session advances
      // (identityKnown -> nostrReady) or on account switch. Both authenticated
      // instances are owner-scoped; only the ready one gets credentials and
      // starts listening. A
      // BlocProvider factory runs once and captures whichever instance was
      // current at mount; if the inbox is opened during the not-ready
      // window the ConversationListBloc stays wired to that owner-scoped but
      // non-listening repository, so it misses later ingestion. Re-key on the captured
      // repositories' identities so the blocs are rebuilt bound to the
      // fresh instances on every flip. The tuple carries EVERY watched
      // value a create: factory below captures whose identity can change
      // at runtime (currentUserPubkey flips on account switch) — or the
      // cubits capturing them silently keep the stale instance. See
      // .claude/rules/state_management.md ("Bridging Riverpod-provided
      // dependencies into BlocProvider").
      key: ValueKey((
        dmRepository,
        followRepository,
        blocklistRepository,
        currentUserPubkey,
        protectedMinorInboxGate,
      )),
      providers: [
        BlocProvider(
          // Lazy on purpose: only the Messages pane reads this bloc, and its
          // start event runs the DM history restore, so both wait until
          // Messages first opens (#11020). Do not read it outside that pane.
          //
          // Deliberately unkeyed on profileRepository. A key here would NOT
          // narrow anything: `providers[0]` is the OUTERMOST entry in the
          // nested chain, so keying it re-inflates every provider below plus
          // the whole InboxView subtree — losing the tab selection, scroll
          // offset and search text. The nullable-gated instance is read when
          // the bloc is created, which can be long after this page built, and
          // later changes arrive in place as
          // ConversationListProfileRepositoryChanged from
          // `_ConversationListSync` in inbox_view.dart.
          create: (_) => ConversationListBloc(
            dmRepository: dmRepository,
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
            profileRepository: ref.read(profileRepositoryProvider),
            protectedMinorInboxGate: protectedMinorInboxGate,
            // Pinned Divine Moderation support row (#6283). The identity is
            // the release-pinned one — the same anchor the protected-minor
            // gate resolves against — so the row can never point somewhere
            // the gate would not approve.
            supportRowPubkey: kModerationPubkeyHex,
            moderationPresentation: ref.read(
              moderationPresentationResolverProvider,
            ),
            retiredModerationAccount: isRetiredModerationAccount,
          )..add(const ConversationListStarted()),
        ),
        // Inbox-scope NotificationBadgeCubit feeds the segmented
        // toggle's notifications count. Mirrors the app-shell-scope
        // cubit provided in `main.dart` so `inbox_view.dart` can read
        // via `context.watch<NotificationBadgeCubit>()`.
        BlocProvider(
          create: (_) => NotificationBadgeCubit(
            repository: ref.read(notificationRepositoryProvider),
          ),
        ),
        BlocProvider(
          create: (_) => MyFollowingBloc(
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
            consumptionAnalytics: ref.read(consumptionAnalyticsTrackerProvider),
          )..add(const MyFollowingListLoadRequested()),
        ),
        BlocProvider(
          create: (_) => ConversationActionsCubit(
            contentBlocklistRepository: blocklistRepository,
            dmRepository: dmRepository,
            currentUserPubkey: currentUserPubkey,
          ),
        ),
      ],
      child: const _InboxRepositorySync(child: InboxView()),
    );
  }
}

/// Forwards the late-resolving notification repository to the badge cubit,
/// without re-keying any provider: a `ValueKey` on the owning `BlocProvider`
/// would tear down the entire downstream provider chain and the `InboxView`
/// subtree with it.
///
/// The conversation list's late dependencies are forwarded from inside the
/// Messages pane instead (`_ConversationListSync` in inbox_view.dart):
/// reading that bloc here would create it, and start the DM history restore,
/// before Messages opens (#11020).
class _InboxRepositorySync extends ConsumerWidget {
  const _InboxRepositorySync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationRepositoryProvider, (_, repository) {
      context.read<NotificationBadgeCubit>().setRepository(repository);
    });
    return child;
  }
}
