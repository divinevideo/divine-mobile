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
import 'package:openvine/blocs/dm/conversation_mute/conversation_mute_cubit.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
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
    final prefs = ref.watch(sharedPreferencesProvider);
    final reportingService = ref.watch(contentReportingServiceProvider).value;
    // Read once for constructor seeding; subsequent changes are handled by
    // ref.listen below via _InboxRepositorySync, avoiding page rebuild on
    // profileRepository null → instance transition at cold start.
    final profileRepository = ref.read(profileRepositoryProvider);
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
      //
      // reportingService is deliberately NOT in this tuple: it resolves
      // from null asynchronously shortly after every inbox mount, and
      // keying the whole MultiBlocProvider on it tore down and recreated
      // all five blocs (double ConversationListStarted + list reload)
      // right after every open. Only its consumer — the
      // ConversationActionsCubit provider below — is re-keyed on it.
      key: ValueKey((
        dmRepository,
        followRepository,
        blocklistRepository,
        currentUserPubkey,
        protectedMinorInboxGate,
      )),
      providers: [
        BlocProvider(
          // Deliberately unkeyed on profileRepository. A key here would NOT
          // narrow anything: `providers[0]` is the OUTERMOST entry in the
          // nested chain, so keying it re-inflates every provider below plus
          // the whole InboxView subtree — losing the tab selection, scroll
          // offset and search text. The nullable-gated instance is delivered
          // in place by ConversationListProfileRepositoryChanged from
          // _InboxRepositorySync below, refreshing only this bloc's
          // dependency. The constructor still carries the initial value.
          create: (_) => ConversationListBloc(
            dmRepository: dmRepository,
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
            profileRepository: profileRepository,
            protectedMinorInboxGate: protectedMinorInboxGate,
            // Pinned Divine Moderation support row (#6283). The identity is
            // the release-pinned one — the same anchor the protected-minor
            // gate resolves against — so the row can never point somewhere
            // the gate would not approve.
            supportRowPubkey: kModerationPubkeyHex,
            moderationAccount: isModerationAccount,
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
          )..add(const MyFollowingListLoadRequested()),
        ),
        BlocProvider(create: (_) => ConversationMuteCubit(prefs: prefs)),
        // Re-keyed on the async-resolving reportingService alone (last in
        // the list so the swap recreates the smallest possible subtree):
        // the actions cubit is action-only state and cheap to rebuild,
        // and without the key it would capture the pre-resolution null
        // forever, silently failing every report.
        BlocProvider(
          key: ValueKey(reportingService),
          create: (_) => ConversationActionsCubit(
            contentReportingService: reportingService,
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

/// Forwards late-resolving repositories to the blocs that need them, without
/// re-keying any provider.
///
/// Both of these dependencies resolve after mount, and both are consumed by a
/// single bloc. Pushing them in as a setter/event refreshes only that bloc —
/// whereas a `ValueKey` on the owning `BlocProvider` would tear down the entire
/// downstream provider chain and the `InboxView` subtree with it.
class _InboxRepositorySync extends ConsumerWidget {
  const _InboxRepositorySync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationRepositoryProvider, (_, repository) {
      context.read<NotificationBadgeCubit>().setRepository(repository);
    });
    ref.listen(profileRepositoryProvider, (_, repository) {
      context.read<ConversationListBloc>().add(
        ConversationListProfileRepositoryChanged(repository),
      );
    });
    return child;
  }
}
