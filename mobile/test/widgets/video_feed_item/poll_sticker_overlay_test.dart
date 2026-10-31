// ABOUTME: Tests a poll sticker on a playing video: it reads its poll only on
// ABOUTME: the active video, takes a vote on an answer and shows the votes.

import 'package:divine_ui/divine_ui.dart' show DivineIcon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_editor/social_sticker/poll_sticker_card.dart';
import 'package:openvine/widgets/video_feed_item/poll_sticker_overlay.dart';
import 'package:poll_repository/poll_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPollRepository extends Mock implements PollRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _Session extends NostrSession {
  _Session(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;

  void become(NostrSessionReadiness next) => state = next;
}

final String _author = 'a' * 64;
final String _viewer = 'b' * 64;
final String _pollId = 'c' * 64;

final VideoStickerRegion _region = VideoStickerRegion(
  kind: VideoStickerKind.poll,
  target: _pollId,
  centerX: 0.5,
  centerY: 0.5,
  width: 0.8,
  height: 0.5,
  style: 'light',
  label: 'Which one?\nRed\nBlue',
);

final VideoEvent _video = VideoEvent(
  id: 'd' * 64,
  pubkey: _author,
  createdAt: 1778120201,
  content: '',
  timestamp: DateTime.utc(2026),
  stickerRegions: [_region],
);

final Poll _poll = Poll(
  id: _pollId,
  authorPubkey: _author,
  question: 'Which one?',
  options: const [
    PollOption(id: '0', label: 'Red'),
    PollOption(id: '1', label: 'Blue'),
  ],
);

final VideoStickerRegion _quizRegion = VideoStickerRegion(
  kind: VideoStickerKind.quiz,
  target: _pollId,
  centerX: 0.5,
  centerY: 0.5,
  width: 0.8,
  height: 0.5,
  style: 'light',
  label: 'Which one?\nRed\nBlue',
);

final Poll _quiz = Poll(
  id: _pollId,
  authorPubkey: _author,
  question: 'Which one?',
  kind: PollKind.quiz,
  answerId: '1',
  options: const [
    PollOption(id: '0', label: 'Red'),
    PollOption(id: '1', label: 'Blue'),
  ],
);

void main() {
  group(PollStickerOverlay, () {
    late _MockPollRepository repository;
    late SharedPreferences preferences;
    late int interactions;
    late int playerTaps;

    setUpAll(() => registerFallbackValue(_poll));

    setUp(() async {
      repository = _MockPollRepository();
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      interactions = 0;
      playerTaps = 0;
      when(
        () => repository.fetchPoll(_pollId, authorPubkey: _author),
      ).thenAnswer(
        (_) async => PollSnapshot(
          poll: _poll,
          results: const PollResults(counts: {'0': 3}),
        ),
      );
      when(() => repository.vote(any(), any())).thenAnswer((_) async {});
    });

    NostrSessionReadiness ready(String pubkey) {
      final client = _MockNostrClient();
      when(() => client.hasKeys).thenReturn(true);
      when(() => client.publicKey).thenReturn(pubkey);
      return NostrSessionReadiness.nostrReady(pubkey: pubkey, client: client);
    }

    Future<void> pump(
      WidgetTester tester, {
      bool isActive = true,
      NostrSessionReadiness? session,
      _Session? sessionNotifier,
      VideoStickerRegion? region,
    }) async {
      final shown = region ?? _region;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pollRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            nostrSessionProvider.overrideWith(
              () => sessionNotifier ?? _Session(session ?? ready(_viewer)),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              // The player's gesture surface is the sticker's sibling in the
              // feed, beneath it.
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => playerTaps++,
                    ),
                  ),
                  Center(
                    child: SizedBox(
                      width: 300,
                      height: 240,
                      child: PollStickerOverlay(
                        region: shown,
                        video: _video,
                        data: SocialStickerData.ofRegion(shown)!,
                        isActive: isActive,
                        onInteraction: () => interactions++,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    group('renders', () {
      testWidgets('draws the poll of a video the feed only loads ahead, '
          'without reading it', (tester) async {
        await pump(tester, isActive: false);

        expect(find.text('Red'), findsOneWidget);
        verifyNever(
          () => repository.fetchPoll(
            any(),
            authorPubkey: any(named: 'authorPubkey'),
          ),
        );
      });

      testWidgets('shows the creator the votes without a vote of theirs', (
        tester,
      ) async {
        await pump(tester, session: ready(_author));

        expect(find.text('100%'), findsOneWidget);
        expect(
          find.text(
            lookupAppLocalizations(const Locale('en'))
                .videoStickerPollVoteCount(3),
          ),
          findsOneWidget,
        );
        // The creator's answers are no buttons; the tap reaches the player.
        await tester.tapAt(tester.getCenter(find.text('Blue')));
        verifyNever(() => repository.vote(any(), any()));
        expect(playerTaps, equals(1));
      });
    });

    group('interactions', () {
      testWidgets('votes for the answer tapped and shows how everyone voted', (
        tester,
      ) async {
        await pump(tester);
        // The votes read 100% on Red until the viewer's own moves them.
        expect(find.text('100%'), findsNothing);

        await tester.tap(find.text('Blue'));
        await tester.pump();

        verify(() => repository.vote(_poll, '1')).called(1);
        expect(find.text('75%'), findsOneWidget);
        expect(find.text('25%'), findsOneWidget);
        // How many voted is the creator's to see.
        expect(
          find.text(
            lookupAppLocalizations(const Locale('en'))
                .videoStickerPollVoteCount(4),
          ),
          findsNothing,
        );
        expect(interactions, equals(1));
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('en'),
            ).videoStickerPollVotesArePublic,
          ),
          findsOneWidget,
        );
      });

      testWidgets('lets a tap off the answers reach the player beneath', (
        tester,
      ) async {
        await pump(tester);

        await tester.tapAt(tester.getCenter(find.text('Which one?')));
        await tester.tap(find.text('Red'));
        await tester.pump();

        expect(playerTaps, equals(1));
        verify(() => repository.vote(_poll, '0')).called(1);
      });

      testWidgets('reads the poll again once the relays are up', (
        tester,
      ) async {
        when(
          () => repository.fetchPoll(_pollId, authorPubkey: _author),
        ).thenAnswer((_) async => null);
        final session = _Session(
          NostrSessionReadiness.identityKnown(pubkey: _viewer),
        );
        await pump(tester, sessionNotifier: session);
        await tester.pump();

        when(
          () => repository.fetchPoll(_pollId, authorPubkey: _author),
        ).thenAnswer(
          (_) async => PollSnapshot(poll: _poll, results: const PollResults()),
        );
        session.become(ready(_viewer));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Red'));
        await tester.pump();

        verify(() => repository.vote(_poll, '0')).called(1);
      });

      testWidgets('keeps a quiz right answer back until it is answered, and '
          'takes no second answer', (tester) async {
        when(
          () => repository.fetchPoll(_pollId, authorPubkey: _author),
        ).thenAnswer(
          (_) async => PollSnapshot(poll: _quiz, results: const PollResults()),
        );
        await pump(tester, region: _quizRegion);
        expect(find.byType(DivineIcon), findsNothing);

        await tester.tap(find.text('Red'));
        await tester.pump();
        expect(find.byType(DivineIcon), findsNWidgets(2));

        await tester.tap(find.text('Blue'), warnIfMissed: false);
        await tester.pump();

        verify(() => repository.vote(_quiz, '0')).called(1);
        verifyNever(() => repository.vote(_quiz, '1'));
        expect(playerTaps, equals(1));
      });

      testWidgets('votes when a screen reader activates an answer', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pump(tester);
        await tester.pump();

        tester.semantics.tap(find.semantics.byLabel('Red'));
        await tester.pump();
        handle.dispose();

        verify(() => repository.vote(_poll, '0')).called(1);
      });

      testWidgets('rates a slider where the emoji is let go', (tester) async {
        final slider = Poll.slider(question: 'Hungry?', emoji: '😋');
        when(
          () => repository.fetchPoll(_pollId, authorPubkey: _author),
        ).thenAnswer(
          (_) async => PollSnapshot(
            poll: Poll(
              id: _pollId,
              authorPubkey: _author,
              question: slider.question,
              options: slider.options,
              kind: PollKind.slider,
              emoji: slider.emoji,
            ),
            results: const PollResults(),
          ),
        );
        await pump(
          tester,
          region: VideoStickerRegion(
            kind: VideoStickerKind.slider,
            target: _pollId,
            centerX: 0.5,
            centerY: 0.5,
            width: 0.8,
            height: 0.2,
            style: 'light',
            label: 'Hungry?\n😋',
          ),
        );
        // The card is 720 wide, its bar's ends 90 in from either side.
        final card = tester.getRect(find.byType(PollStickerCard));
        double at(double value) =>
            card.left + (90 + value * 540) / 720 * card.width;

        // Every move lands before the emoji is drawn again.
        await tester.dragFrom(
          Offset(at(0), tester.getCenter(find.text('😋')).dy),
          Offset(at(0.7) - at(0), 0),
        );
        await tester.pump();

        verify(() => repository.vote(any(), '70')).called(1);
      });

      testWidgets('asks a viewer who is not signed in to sign in', (
        tester,
      ) async {
        await pump(tester, session: const NostrSessionReadiness.signedOut());

        await tester.tap(find.text('Red'));
        await tester.pump();

        verifyNever(() => repository.vote(any(), any()));
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('en'),
            ).videoStickerPollSignInToVote,
          ),
          findsOneWidget,
        );
      });
    });
  });
}
