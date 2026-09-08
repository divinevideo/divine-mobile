// ABOUTME: Widget tests for the combined reaction pill (ReactionsRow).
// ABOUTME: Covers distinct-glyph rendering, reactor avatars, the
// ABOUTME: "see who reacted" semantic label, and tap-opens-sheet.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/reactions_row.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../../../helpers/test_provider_overrides.dart';

class _MockConversationReactionsCubit
    extends MockBloc<ConversationReactionsEvent, ConversationReactionsState>
    implements ConversationReactionsCubit {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  const ownerPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const otherPubkey =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  const conversationId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const messageId =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const messageIdB =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  DmReaction makeReaction({
    required String id,
    required String reactorPubkey,
    required String emoji,
    int createdAt = 1_700_000_000,
    DmReactionPublishStatus publishStatus = DmReactionPublishStatus.sent,
  }) {
    return DmReaction(
      id: id,
      conversationId: conversationId,
      targetMessageId: messageId,
      targetMessageAuthor: otherPubkey,
      reactorPubkey: reactorPubkey,
      emoji: emoji,
      createdAt: createdAt,
      ownerPubkey: ownerPubkey,
      publishStatus: publishStatus,
    );
  }

  ConversationReactionsState stateWith(List<DmReaction> reactions) {
    return ConversationReactionsState(
      reactionsByMessageId: {messageId: reactions},
    );
  }

  Widget buildSubject(
    _MockConversationReactionsCubit cubit, {
    Set<String> blockedPubkeys = const <String>{},
    List<Override> additionalOverrides = const <Override>[],
    bool removalEnabled = true,
  }) {
    return testMaterialApp(
      additionalOverrides: additionalOverrides,
      home: Scaffold(
        body: BlocProvider<ConversationReactionsCubit>.value(
          value: cubit,
          child: ReactionsRow(
            conversationId: conversationId,
            messageId: messageId,
            messageAuthorPubkey: otherPubkey,
            ownerPubkey: ownerPubkey,
            isSentByMe: false,
            blockedPubkeys: blockedPubkeys,
            removalEnabled: removalEnabled,
          ),
        ),
      ),
    );
  }

  group('ReactionsRow', () {
    late _MockConversationReactionsCubit cubit;

    setUp(() {
      cubit = _MockConversationReactionsCubit();
    });

    void primeState(ConversationReactionsState state) {
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, Stream.value(state), initialState: state);
    }

    testWidgets('renders one pill with the distinct emoji glyphs', (
      tester,
    ) async {
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
          makeReaction(
            id: '2',
            reactorPubkey: otherPubkey,
            emoji: '😂',
            createdAt: 1_700_000_001,
            publishStatus: DmReactionPublishStatus.received,
          ),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      // Distinct glyphs both render in the single pill.
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('😂'), findsOneWidget);
      // One avatar per reactor.
      expect(find.byType(UserAvatar), findsNWidgets(2));
    });

    testWidgets('a refused own removal renders the error warning pill', (
      tester,
    ) async {
      primeState(
        stateWith([
          makeReaction(
            id: '1',
            reactorPubkey: ownerPubkey,
            emoji: '🔥',
            publishStatus: DmReactionPublishStatus.removalRefused,
          ),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>();
      expect(
        decorations.any(
          (decoration) => decoration.border?.top.color == VineTheme.error,
        ),
        isTrue,
      );
    });

    testWidgets('a refused removal on a closed thread is not warning-styled', (
      tester,
    ) async {
      primeState(
        stateWith([
          makeReaction(
            id: '1',
            reactorPubkey: ownerPubkey,
            emoji: '🔥',
            publishStatus: DmReactionPublishStatus.removalRefused,
          ),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit, removalEnabled: false));
      await tester.pump();

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>();
      expect(
        decorations.any(
          (decoration) => decoration.border?.top.color == VineTheme.error,
        ),
        isFalse,
      );
    });

    testWidgets('reactor avatar is vertically centered against the emoji', (
      tester,
    ) async {
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      // The avatar box and the emoji box share a vertical centre. This guards
      // the avatar-stack centering (a sub-`_size` avatar otherwise pins to the
      // top edge). Real colour-emoji ink offset is engine-level and not
      // reproducible with the placeholder test font, so this checks box
      // alignment, not glyph ink.
      final emojiCenter = tester.getCenter(find.text('🔥')).dy;
      final avatarCenter = tester.getCenter(find.byType(UserAvatar)).dy;
      expect(avatarCenter, closeTo(emojiCenter, 0.5));
    });

    testWidgets('reactor avatar renders as a circle (no cut border)', (
      tester,
    ) async {
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      // cornerRadius == size / 2 keeps UserAvatar's own border circular, so it
      // is not sliced into arcs by the surrounding circular outline.
      final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
      expect(avatar.cornerRadius, avatar.size / 2);
    });

    testWidgets('pill exposes the "see who reacted" semantic label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      expect(
        find.bySemanticsLabel(l10n.dmReactionsViewA11yLabel),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('renders nothing when there are no reactions', (tester) async {
      primeState(stateWith(const []));

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      expect(find.text('🔥'), findsNothing);
      expect(find.byType(UserAvatar), findsNothing);
    });

    testWidgets(
      'filters reactions from blockedPubkeys out of the pill (#5418)',
      (tester) async {
        primeState(
          stateWith([
            makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
            makeReaction(
              id: '2',
              reactorPubkey: otherPubkey,
              emoji: '😂',
              createdAt: 1_700_000_001,
              publishStatus: DmReactionPublishStatus.received,
            ),
          ]),
        );

        await tester.pumpWidget(
          buildSubject(cubit, blockedPubkeys: const {otherPubkey}),
        );
        await tester.pump();

        // The blocked reactor's glyph and avatar are gone; the owner's remain.
        expect(find.text('🔥'), findsOneWidget);
        expect(find.text('😂'), findsNothing);
        expect(find.byType(UserAvatar), findsOneWidget);
      },
    );

    testWidgets('renders nothing when every reactor is blocked (#5418)', (
      tester,
    ) async {
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: otherPubkey, emoji: '😂'),
        ]),
      );

      await tester.pumpWidget(
        buildSubject(cubit, blockedPubkeys: const {otherPubkey}),
      );
      await tester.pump();

      expect(find.text('😂'), findsNothing);
      expect(find.byType(UserAvatar), findsNothing);
    });

    testWidgets('tapping the pill opens the who-reacted sheet', (tester) async {
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      // Settle the glyph pop-in so the emoji is at full scale and hittable.
      await tester.pumpAndSettle();

      // Sheet not open yet.
      expect(find.text(l10n.dmReactionsSheetTitle), findsNothing);

      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();

      // The sheet (re-providing the same cubit via contentWrapper) is shown.
      expect(find.text(l10n.dmReactionsSheetTitle), findsOneWidget);
    });

    testWidgets(
      'renders the own optimistic pill with NO persisted rows (#5389)',
      (tester) async {
        // No persisted reactions; the chip exists only because of the
        // synchronous optimistic overlay — i.e. before any Drift round-trip.
        final state = ConversationReactionsState(
          optimistic: {
            const ReactionPublishKey(
              messageId: messageId,
              emoji: '🔥',
            ): OptimisticReactionAdded(
              makeReaction(
                id: 'optimistic:$messageId:🔥',
                reactorPubkey: ownerPubkey,
                emoji: '🔥',
                publishStatus: DmReactionPublishStatus.pending,
              ),
            ),
          },
        );
        when(() => cubit.state).thenReturn(state);
        whenListen(cubit, Stream.value(state), initialState: state);

        await tester.pumpWidget(buildSubject(cubit));
        await tester.pump();

        expect(find.text('🔥'), findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.dmReactionsViewA11yLabel),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a reaction present at mount renders settled (no pop on open / scroll-in)',
      (tester) async {
        primeState(
          stateWith([
            makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '❤️'),
          ]),
        );

        await tester.pumpWidget(buildSubject(cubit));
        await tester.pump();

        // A reaction that already exists when the pill first builds must not
        // grow in — otherwise every reacted message pops on conversation open
        // and each time it scrolls back into view.
        expect(_emojiScale(tester, '❤️'), closeTo(1, 0.01));
        expect(find.text('❤️'), findsOneWidget);
      },
    );

    testWidgets(
      'a reaction added while the pill is mounted grows in and settles',
      (tester) async {
        final controller =
            StreamController<ConversationReactionsState>.broadcast();
        addTearDown(controller.close);

        final initial = stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '❤️'),
        ]);
        when(() => cubit.state).thenReturn(initial);
        whenListen(cubit, controller.stream, initialState: initial);

        await tester.pumpWidget(buildSubject(cubit));
        await tester.pump();

        // The pre-existing glyph is settled — the mount is silent.
        expect(_emojiScale(tester, '❤️'), closeTo(1, 0.01));

        // A new reactor's glyph arrives on the live stream while the pill stays
        // mounted → it grows in (the gentle "small heart appearing" feel).
        controller.add(
          stateWith([
            makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '❤️'),
            makeReaction(
              id: '2',
              reactorPubkey: otherPubkey,
              emoji: '🔥',
              createdAt: 1_700_000_001,
              publishStatus: DmReactionPublishStatus.received,
            ),
          ]),
        );
        // Two pumps: one flushes the stream event, one builds the frame that
        // mounts the new glyph (its controller starts at 0 → below full scale).
        await tester.pump();
        await tester.pump();

        expect(_emojiScale(tester, '🔥'), lessThan(1));
        // The existing ❤️ keeps its element and does NOT re-pop.
        expect(_emojiScale(tester, '❤️'), closeTo(1, 0.01));

        await tester.pumpAndSettle();
        expect(_emojiScale(tester, '🔥'), closeTo(1, 0.01));
        expect(find.text('🔥'), findsOneWidget);
      },
    );

    testWidgets(
      'the first like on a never-reacted message grows in (double-tap flagship)',
      (tester) async {
        final controller =
            StreamController<ConversationReactionsState>.broadcast();
        addTearDown(controller.close);

        // The message starts with zero reactions: the row is mounted (and
        // captures an empty baseline) but no pill is shown yet.
        const empty = ConversationReactionsState();
        when(() => cubit.state).thenReturn(empty);
        whenListen(cubit, controller.stream, initialState: empty);

        await tester.pumpWidget(buildSubject(cubit));
        await tester.pump();
        expect(find.text('❤️'), findsNothing);

        // The user double-taps → the cubit paints the optimistic own ❤️. It is
        // absent from the mount-time baseline, so it must grow in — this is the
        // whole point of the double-tap-to-like animation, and it must survive
        // the "no prior reactions" path that mounts the pill for the first time.
        controller.add(
          ConversationReactionsState(
            optimistic: {
              const ReactionPublishKey(
                messageId: messageId,
                emoji: '❤️',
              ): OptimisticReactionAdded(
                makeReaction(
                  id: 'optimistic:$messageId:❤️',
                  reactorPubkey: ownerPubkey,
                  emoji: '❤️',
                  publishStatus: DmReactionPublishStatus.pending,
                ),
              ),
            },
          ),
        );
        // Two pumps: one flushes the stream event, one builds the frame that
        // mounts the heart (its controller starts at 0 → below full scale).
        await tester.pump();
        await tester.pump();

        expect(_emojiScale(tester, '❤️'), lessThan(1));

        await tester.pumpAndSettle();
        expect(_emojiScale(tester, '❤️'), closeTo(1, 0.01));
        expect(find.text('❤️'), findsOneWidget);

        // The optimistic pending ❤️ reconciles to a persisted `sent` row — same
        // emoji, same keyed glyph — so it must NOT re-pop on the swap.
        controller.add(
          stateWith([
            makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '❤️'),
          ]),
        );
        await tester.pump();
        await tester.pump();
        expect(_emojiScale(tester, '❤️'), closeTo(1, 0.01));
      },
    );

    testWidgets(
      'recaptures the baseline when the row is rebound to another message '
      '(list recycling)',
      (tester) async {
        // Both messages already have a reaction; neither should pop at mount.
        primeState(
          ConversationReactionsState(
            reactionsByMessageId: {
              messageId: [
                makeReaction(id: 'a', reactorPubkey: otherPubkey, emoji: '❤️'),
              ],
              messageIdB: [
                makeReaction(id: 'b', reactorPubkey: otherPubkey, emoji: '🔥'),
              ],
            },
          ),
        );

        Widget rowFor(String id) => testMaterialApp(
          home: Scaffold(
            body: BlocProvider<ConversationReactionsCubit>.value(
              value: cubit,
              child: ReactionsRow(
                conversationId: conversationId,
                messageId: id,
                messageAuthorPubkey: otherPubkey,
                ownerPubkey: ownerPubkey,
                isSentByMe: false,
              ),
            ),
          ),
        );

        await tester.pumpWidget(rowFor(messageId));
        await tester.pump();
        expect(_emojiScale(tester, '❤️'), closeTo(1, 0.01));

        // Re-pump the SAME element position with a different messageId — the
        // shape a ListView takes when it recycles a row onto another message.
        // didUpdateWidget must drop the stale baseline so message B's reaction,
        // present at rebind, does NOT spuriously pop. Without the reset the
        // {❤️} baseline lingers and 🔥 (absent from it) grows in.
        await tester.pumpWidget(rowFor(messageIdB));
        await tester.pump();
        expect(find.text('❤️'), findsNothing);
        expect(_emojiScale(tester, '🔥'), closeTo(1, 0.01));
      },
    );

    group('deleted accounts', () {
      const picture = 'https://example.com/alice.jpg';

      Future<void> pumpPill(
        WidgetTester tester, {
        required bool vanished,
      }) async {
        primeState(
          stateWith([
            makeReaction(
              id: 'other1',
              reactorPubkey: otherPubkey,
              emoji: '😂',
              publishStatus: DmReactionPublishStatus.received,
            ),
          ]),
        );

        await tester.pumpWidget(
          buildSubject(
            cubit,
            additionalOverrides: [
              userProfileReactiveProvider(otherPubkey).overrideWith(
                (ref) => Stream.value(
                  UserProfile(
                    pubkey: otherPubkey,
                    displayName: 'Alice',
                    picture: picture,
                    rawData: const {},
                    createdAt: DateTime(2026),
                    eventId:
                        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
                  ),
                ),
              ),
              profileVanishedProvider(
                otherPubkey,
              ).overrideWith((ref) => vanished),
            ],
          ),
        );
        await tester.pump();
      }

      testWidgets("drops a vanished reactor's picture and initial", (
        tester,
      ) async {
        await pumpPill(tester, vanished: true);

        // The pill is what opens the reactor sheet. Leaving the photo here
        // would put the account's face directly above a row that reads
        // "Deleted account".
        final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
        expect(avatar.imageUrl, isNull);
        // The placeholder initial comes from `name`, so a stale row would
        // still leak the account's first letter with the photo suppressed.
        expect(avatar.name, l10n.profileDeletedAccountName);
      });

      testWidgets('leaves a live reactor untouched', (tester) async {
        await pumpPill(tester, vanished: false);

        final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
        expect(avatar.imageUrl, picture);
        expect(avatar.name, 'Alice');
      });
    });
  });
}

/// Current scale of the `_PoppingEmoji` [ScaleTransition] wrapping the [emoji]
/// glyph, read straight off the animation value.
double _emojiScale(WidgetTester tester, String emoji) {
  final scaleTransition = tester.widget<ScaleTransition>(
    find.ancestor(of: find.text(emoji), matching: find.byType(ScaleTransition)),
  );
  return scaleTransition.scale.value;
}
