// ABOUTME: Conversation detail page that provides BLoC dependencies.
// ABOUTME: Sets up ConversationBloc from DmRepository for a specific
// ABOUTME: conversation ID derived from participant pubkeys.

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/blocs/dm/conversation/conversation_participants_cubit.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/blocs/dm/restore_status/dm_restore_status_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';

/// Conversation detail page (single DM thread).
///
/// Provides [ConversationBloc] to the widget tree, backed by [DmRepository].
/// The conversation ID is computed deterministically from the sorted
/// participant pubkeys.
class ConversationPage extends ConsumerWidget {
  const ConversationPage({
    required this.conversationId,
    required this.participantPubkeys,
    this.subject,
    super.key,
  });

  /// Deterministic conversation ID (SHA-256 of sorted pubkeys).
  final String conversationId;

  /// Pubkeys of the other participants (excludes current user).
  ///
  /// Only a hint: the route has it after in-app navigation and not after a
  /// deep link or a browser refresh, so [ConversationParticipantsCubit]
  /// resolves it from the conversation row when it is empty (#3335).
  final List<String> participantPubkeys;

  /// Subject carried from an inbox row to avoid a second read before render.
  final String? subject;

  /// Route name for this screen.
  static const routeName = 'conversation';

  /// Path pattern for GoRouter.
  static const pathPattern = '/inbox/conversation/:id';

  /// Build a path for a specific conversation.
  static String pathForId(String id) => RoutePaths.conversationForId(id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';
    // Route guard (#176): a DM-restricted user (protected minor, or an
    // unresolved status that fails closed) must not open a conversation with a
    // non-approved counterparty, even via a deep link or a stale route (the
    // send gate and the inbox list already block those paths).
    //
    // Watched, not read: the restriction resolves asynchronously and can flip
    // for an account that is already signed in, and this screen used to
    // re-evaluate the guard on every rebuild. Both signals are part of the key
    // so a flip rebuilds the cubit and re-runs the gate rather than leaving an
    // open thread behind.
    final isDmRestricted = ref.watch(isDmRestrictedProvider);
    final officialAccounts = ref.watch(officialAccountsServiceProvider);

    return BlocProvider(
      // Also keyed on the captured dependencies: a stale dmRepository would
      // resolve participants against the previous account.
      key: ValueKey((
        dmRepository,
        currentPubkey,
        isDmRestricted,
        officialAccounts,
      )),
      create: (_) => ConversationParticipantsCubit(
        dmRepository: dmRepository,
        conversationId: conversationId,
        initialParticipantPubkeys: participantPubkeys,
        isDmRestricted: () => isDmRestricted,
        isApprovedRecipient: officialAccounts.isReadableByProtectedMinor,
      )..load(),
      child: _ConversationPageContent(
        conversationId: conversationId,
        subject: subject,
      ),
    );
  }
}

class _ConversationPageContent extends ConsumerWidget {
  const _ConversationPageContent({required this.conversationId, this.subject});

  final String conversationId;
  final String? subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<
      ConversationParticipantsCubit,
      ConversationParticipantsState
    >(
      builder: (context, state) {
        return switch (state.status) {
          ConversationParticipantsStatus.denied => const _DeniedConversation(),
          ConversationParticipantsStatus.loading => const Scaffold(
            body: Center(child: DivineCircularProgressIndicator()),
          ),
          ConversationParticipantsStatus.ready => _ConversationBlocScope(
            conversationId: conversationId,
            participantPubkeys: state.participantPubkeys,
            subject: subject,
          ),
        };
      },
    );
  }
}

/// Bounces a DM-restricted user back to the inbox, where the filtered
/// conversation list still reaches anything they may access (#176).
class _DeniedConversation extends StatefulWidget {
  const _DeniedConversation();

  @override
  State<_DeniedConversation> createState() => _DeniedConversationState();
}

class _DeniedConversationState extends State<_DeniedConversation> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(InboxPage.path);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

class _ConversationBlocScope extends ConsumerWidget {
  const _ConversationBlocScope({
    required this.conversationId,
    required this.participantPubkeys,
    this.subject,
  });

  final String conversationId;
  final List<String> participantPubkeys;
  final String? subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);
    final reactionsRepository = ref.watch(dmReactionsRepositoryProvider);
    final inviteStateStore = ref.watch(collaboratorInviteStateStoreProvider);
    final inviteResponseService = ref.watch(
      collaboratorResponseServiceProvider,
    );
    final confirmationRepository = ref.watch(
      collaboratorConfirmationRepositoryProvider,
    );
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    return MultiBlocProvider(
      providers: [
        // Key tracks the captured Riverpod-provided dependencies so the
        // bloc is recreated when their identity flips (auth flip, account
        // switch, sign-out). Without this key, a stale `dmRepository`
        // captured during a brief unauthenticated window would scope all
        // reads/writes by an empty/wrong `_userPubkey` for the lifetime of
        // the bloc, causing sent messages to "disappear" on re-entry.
        // See `state_management.md` → "Bridging Riverpod-provided
        // dependencies into BlocProvider" and the canonical four sites in
        // `video_feed_page.dart` / `pooled_fullscreen_video_feed_screen.dart`.
        BlocProvider<ConversationBloc>(
          key: ValueKey((dmRepository, currentPubkey)),
          create: (_) => ConversationBloc(
            dmRepository: dmRepository,
            conversationId: conversationId,
          )..add(const ConversationStarted()),
        ),
        // Qualifies the empty state: `watchMessages` is a local DB stream, so
        // an unsynced thread reaches `loaded` with zero rows and would
        // otherwise assert "no messages" while gift wraps are still arriving
        // or decrypting. Same identity-keying as ConversationBloc.
        BlocProvider<DmRestoreStatusCubit>(
          key: ValueKey((dmRepository, currentPubkey, 'restoreStatus')),
          create: (_) => DmRestoreStatusCubit(dmRepository: dmRepository),
        ),
        // Reactions cubit; same identity-keying as ConversationBloc.
        BlocProvider<ConversationReactionsCubit>(
          key: ValueKey((reactionsRepository, currentPubkey, 'reactions')),
          create: (_) => ConversationReactionsCubit(
            reactionsRepository: reactionsRepository,
            ownerPubkey: currentPubkey,
          )..add(ConversationReactionsStarted(conversationId: conversationId)),
        ),
        // Same identity-keying as ConversationBloc above: the response
        // service composes `authServiceProvider` + `nostrServiceProvider`
        // (`app_providers.dart`), so its identity flips on auth changes.
        // Without the key, accept-invite would publish through whichever
        // signer/relay the cubit captured at first build, even after
        // auth flipped.
        BlocProvider<CollaboratorInviteActionsCubit>(
          key: ValueKey((
            inviteStateStore,
            inviteResponseService,
            confirmationRepository,
            currentPubkey,
          )),
          create: (_) => CollaboratorInviteActionsCubit(
            stateStore: inviteStateStore,
            responseService: inviteResponseService,
            currentUserPubkey: currentPubkey,
            confirmationRepository: confirmationRepository,
          ),
        ),
      ],
      child: ConversationView(
        participantPubkeys: participantPubkeys,
        subject: subject,
      ),
    );
  }
}
