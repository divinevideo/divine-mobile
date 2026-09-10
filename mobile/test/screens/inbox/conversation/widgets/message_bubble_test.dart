// ABOUTME: Widget tests for MessageBubble.
// ABOUTME: Tests rendering of message text, timestamp visibility,
// ABOUTME: alignment for sent vs received messages, URL linkification,
// ABOUTME: and long-press callback.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_bubble.dart';
import 'package:openvine/screens/inbox/dm_display_text.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:videos_repository/videos_repository.dart';

import '../../../../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

Finder _divineIcon(DivineIconName icon) => find.byWidgetPredicate(
  (widget) => widget is DivineIcon && widget.icon == icon,
);

String _longestRenderedText(WidgetTester tester) {
  final values = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText())
      .toList();
  values.sort((first, second) => second.length.compareTo(first.length));
  return values.first;
}

const _testHexPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _testEventId =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

GoRouter _messageRouter(String message) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: MessageBubble(
            message: message,
            timestamp: '2:30 PM',
            isSent: true,
          ),
        ),
      ),
      GoRoute(
        path: '/profile/:npub',
        builder: (context, state) =>
            Scaffold(body: Text('profile:${state.pathParameters['npub']}')),
      ),
      GoRoute(
        path: '/video/:id',
        builder: (context, state) =>
            Scaffold(body: Text('video:${state.pathParameters['id']}')),
      ),
    ],
  );
}

Widget _routerTestApp(
  GoRouter router, {
  List<Override>? additionalOverrides,
  MockNostrClient? mockNostrService,
}) {
  return testProviderScope(
    additionalOverrides: additionalOverrides,
    mockNostrService: mockNostrService,
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

TapGestureRecognizer _linkRecognizer(WidgetTester tester, String linkText) {
  final richText = tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(linkText),
    ),
  );
  final recognizer = _findRecognizer(richText.text, linkText);
  expect(recognizer, isNotNull);
  return recognizer!;
}

TapGestureRecognizer? _findRecognizer(InlineSpan span, String linkText) {
  if (span is TextSpan) {
    final recognizer = span.recognizer;
    if (span.text == linkText && recognizer is TapGestureRecognizer) {
      return recognizer;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      final match = _findRecognizer(child, linkText);
      if (match != null) return match;
    }
  }
  return null;
}

void main() {
  group('retraction status', () {
    testWidgets('shows a warning affordance for a failed retraction', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageBubble(
              message: 'Still recognizable',
              timestamp: '2:30 PM',
              isSent: true,
              retractionStatus: DmRetractionStatus.failed,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // The bubble is NOT dimmed: `Opacity` composites the text and its own
      // fill toward the page together, taking white-on-primaryAccessible from
      // 3.17:1 to 1.94:1 on the light message list. The warning icon carries
      // the state instead.
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity < 1,
        ),
        findsNothing,
      );
      final warning = _divineIcon(DivineIconName.warningCircle);
      expect(warning, findsOneWidget);

      await tester.tap(warning);
      expect(tapped, isTrue);
    });

    testWidgets('names the retry action rather than the resend one', (
      tester,
    ) async {
      // One onTap serves two sheets. A failed retraction opens "Couldn't
      // delete for everyone / Try again", so announcing the resend hint here
      // tells a screen-reader user the wrong thing about what will happen.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageBubble(
              message: 'Still recognizable',
              timestamp: '2:30 PM',
              isSent: true,
              retractionStatus: DmRetractionStatus.failed,
              onTap: () {},
            ),
          ),
        ),
      );

      final l10n = AppLocalizationsEn();
      final tapHints = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.hintOverrides?.onTapHint)
          .whereType<String>()
          .toList();
      expect(tapHints, contains(l10n.authTryAgain));
      expect(tapHints, isNot(contains(l10n.dmMessageBubbleFailedTapHint)));
    });

    testWidgets('names the retry action for a PENDING retraction too', (
      tester,
    ) async {
      // The tap is wired for any unconfirmed retraction, and both states open
      // the same Try again sheet — so keying the hint on `failed` alone left
      // a pending bubble announcing the resend hint.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageBubble(
              message: 'Still recognizable',
              timestamp: '2:30 PM',
              isSent: true,
              retractionStatus: DmRetractionStatus.pending,
              onTap: () {},
            ),
          ),
        ),
      );

      final l10n = AppLocalizationsEn();
      final tapHints = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.hintOverrides?.onTapHint)
          .whereType<String>()
          .toList();
      expect(tapHints, contains(l10n.authTryAgain));
      expect(tapHints, isNot(contains(l10n.dmMessageBubbleFailedTapHint)));
    });

    testWidgets('announces an in-flight retraction to assistive tech', (
      tester,
    ) async {
      // The spinner is the only visual signal; without a label the state is
      // conveyed to sighted users alone.
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageBubble(
              message: 'Still recognizable',
              timestamp: '2:30 PM',
              isSent: true,
              retractionStatus: DmRetractionStatus.pending,
            ),
          ),
        ),
      );

      // Asserted on the indicator's own label rather than through
      // find.bySemanticsLabel: the enclosing bubble Semantics absorbs it, so
      // the tree finder reports nothing even when the label is set.
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(
        indicator.semanticsLabel,
        equals(AppLocalizationsEn().dmDeletePendingLabel),
      );
    });

    testWidgets('shows progress without a warning while deletion is pending', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageBubble(
              message: 'Still recognizable',
              timestamp: '2:30 PM',
              isSent: true,
              retractionStatus: DmRetractionStatus.pending,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_divineIcon(DivineIconName.warningCircle), findsNothing);
    });
  });

  final strings = AppLocalizationsEn();

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  group(MessageBubble, () {
    group('renders', () {
      testWidgets('renders message text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Hello there',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.text('Hello there'), findsOneWidget);
      });

      testWidgets('renders only the bounded prefix of an oversized message', (
        tester,
      ) async {
        final prefix = 'a' * dmInitialDisplayCodeUnits;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageBubble(
                  message: '${prefix}hidden suffix',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          ),
        );

        expect(_longestRenderedText(tester), prefix);
        expect(find.textContaining('hidden suffix'), findsNothing);
        expect(find.text(strings.profileShowMore), findsOneWidget);
        expect(find.text(strings.profileShowLess), findsNothing);
      });

      testWidgets('gives Show more a 48 px minimum tap target on both axes', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageBubble(
                  message: 'a' * (dmInitialDisplayCodeUnits + 1),
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          ),
        );

        expect(
          find.ancestor(
            of: find.text(strings.profileShowMore),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ConstrainedBox &&
                  widget.constraints.minWidth == 48 &&
                  widget.constraints.minHeight == 48,
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('reveals one bounded increment and can collapse again', (
        tester,
      ) async {
        final first = 'a' * dmInitialDisplayCodeUnits;
        final second = 'b' * dmDisplayIncrementCodeUnits;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageBubble(
                  message: '$first${second}tail',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          ),
        );

        await tester.ensureVisible(find.text(strings.profileShowMore));
        await tester.tap(find.text(strings.profileShowMore));
        await tester.pump();

        expect(_longestRenderedText(tester), '$first$second');
        expect(find.textContaining('tail'), findsNothing);
        expect(find.text(strings.profileShowMore), findsNothing);
        expect(find.text(strings.profileShowLess), findsOneWidget);
        expect(
          find.text(strings.dmMessageDisplayLimitReached),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text(strings.profileShowLess));
        await tester.tap(find.text(strings.profileShowLess));
        await tester.pump();

        expect(_longestRenderedText(tester), first);
        expect(find.text(strings.profileShowLess), findsNothing);
      });

      testWidgets('stops expansion at the hard display ceiling', (
        tester,
      ) async {
        final visible = 'a' * dmMaxDisplayCodeUnits;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageBubble(
                  message: '${visible}hidden suffix',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          ),
        );

        await tester.ensureVisible(find.text(strings.profileShowMore));
        await tester.tap(find.text(strings.profileShowMore));
        await tester.pump();

        expect(_longestRenderedText(tester), visible);
        expect(find.textContaining('hidden suffix'), findsNothing);
        expect(
          find.text(strings.dmMessageDisplayLimitReached),
          findsOneWidget,
        );
        expect(find.text(strings.profileShowLess), findsOneWidget);
      });

      testWidgets('keeps the expansion controls white on a sent bubble', (
        tester,
      ) async {
        // The sent bubble keeps the fixed primaryAccessible green fill, where
        // the accent green would sit green-on-green (1.4:1 in dark mode).
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageBubble(
                  message: 'a' * (dmMaxDisplayCodeUnits + 1),
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          ),
        );

        await tester.ensureVisible(find.text(strings.profileShowMore));
        await tester.tap(find.text(strings.profileShowMore));
        await tester.pump();

        final showLess = tester.widget<Text>(
          find.text(strings.profileShowLess),
        );
        expect(showLess.style?.color, VineTheme.whiteText);
        final limitReached = tester.widget<Text>(
          find.text(strings.dmMessageDisplayLimitReached),
        );
        expect(
          limitReached.style?.color,
          VineTheme.whiteText.withValues(alpha: 0.7),
        );
      });

      testWidgets('uses the accent color for expansion controls on a received '
          'bubble', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageBubble(
                  message: 'a' * (dmInitialDisplayCodeUnits + 1),
                  timestamp: '2:30 PM',
                  isSent: false,
                ),
              ),
            ),
          ),
        );

        final showMore = tester.widget<Text>(
          find.text(strings.profileShowMore),
        );
        expect(showMore.style?.color, VineTheme.vineGreen);
        expect(showMore.style?.color, isNot(VineTheme.whiteText));
      });

      testWidgets('bounds painted hearts across markdown leaves', (
        tester,
      ) async {
        // Each plain markdown leaf builds its own linkifier, so a per-leaf
        // heart cap would reset at every emphasis boundary. The budget is
        // shared across the whole message instead.
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message:
                    '**x**$divineGreenHeart' * (kDivineHeartMaxPainted + 2),
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(
          _divineIcon(DivineIconName.heartFill),
          findsNWidgets(kDivineHeartMaxPainted),
        );
      });

      testWidgets('renders timestamp when isFirstInGroup is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Hello there',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.text('2:30 PM'), findsOneWidget);
      });

      testWidgets('does not render timestamp when isFirstInGroup is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Hello there',
                timestamp: '2:30 PM',
                isSent: true,
                isFirstInGroup: false,
              ),
            ),
          ),
        );

        expect(find.text('2:30 PM'), findsNothing);
      });

      testWidgets('aligns right for sent messages', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Sent message',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final align = tester.widget<Align>(find.byType(Align));

        expect(align.alignment, equals(AlignmentDirectional.centerEnd));
      });

      testWidgets('aligns left for received messages', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Received message',
                timestamp: '2:30 PM',
                isSent: false,
              ),
            ),
          ),
        );

        final align = tester.widget<Align>(find.byType(Align));

        expect(align.alignment, equals(AlignmentDirectional.centerStart));
      });

      testWidgets(
        'renders without crashing when message contains an unpaired '
        'UTF-16 surrogate',
        (tester) async {
          // Sender-controlled NIP-17 rumor bodies can deliver malformed
          // UTF-16 via JSON \uXXXX escapes; the renderer asserts on
          // well-formed UTF-16, so MessageBubble must sanitize before
          // painting. See https://github.com/divinevideo/divine-mobile/issues/4463.
          final malformed = 'before${String.fromCharCode(0xD83D)}after';
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageBubble(
                  message: malformed,
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('before\uFFFDafter'), findsOneWidget);
        },
      );
    });

    group('delivery status indicator', () {
      // Per-status icon mapping for sent bubbles. The bubble omits the
      // indicator entirely when `deliveryStatus == delivered`, so a
      // fully-delivered sent message renders identically to a received
      // message in this respect.

      testWidgets('renders no indicator for delivered status', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Done',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.access_time), findsNothing);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
        expect(_divineIcon(DivineIconName.warningCircle), findsNothing);
      });

      testWidgets('shows no indicator while pending (optimistic send)', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'In flight',
                timestamp: '2:30 PM',
                isSent: true,
                deliveryStatus: DmDeliveryStatus.pending,
              ),
            ),
          ),
        );

        // Optimistic: a pending send just looks sent — no clock, no caption.
        expect(find.byIcon(Icons.access_time), findsNothing);
        expect(_divineIcon(DivineIconName.warningCircle), findsNothing);
        expect(find.text(strings.dmStatusFailed), findsNothing);
      });

      testWidgets(
        'shows no indicator for deliveredSelfFailed (background self-heal)',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageBubble(
                  message: 'Half-delivered',
                  timestamp: '2:30 PM',
                  isSent: true,
                  deliveryStatus: DmDeliveryStatus.deliveredSelfFailed,
                ),
              ),
            ),
          );

          expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
          expect(_divineIcon(DivineIconName.warningCircle), findsNothing);
          expect(find.text(strings.dmStatusFailed), findsNothing);
        },
      );

      testWidgets('renders the Not-delivered caption for failed status', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Failed send',
                timestamp: '2:30 PM',
                isSent: true,
                deliveryStatus: DmDeliveryStatus.failed,
              ),
            ),
          ),
        );

        // The only surfaced state: an in-bubble error icon + caption.
        expect(_divineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(find.text(strings.dmStatusFailed), findsOneWidget);
      });

      testWidgets('renders closed-thread copy for blocked status', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Retained appeal',
                timestamp: '2:30 PM',
                isSent: true,
                deliveryStatus: DmDeliveryStatus.blocked,
              ),
            ),
          ),
        );

        expect(_divineIcon(DivineIconName.warningCircle), findsOneWidget);
        expect(
          find.text(strings.dmSendBlockedRetiredMessage),
          findsOneWidget,
        );
        expect(find.text(strings.dmStatusFailed), findsNothing);
      });

      testWidgets(
        'does not render indicator for received messages even when '
        'a non-delivered status is passed',
        (tester) async {
          // Received bubbles never read the outgoing queue; the parameter
          // defaults to delivered for them, and the caller in
          // `_MessageList` short-circuits the BlocSelector. Defensively
          // ignore the parameter when isSent is false.
          await tester.pumpWidget(
            const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageBubble(
                  message: 'From them',
                  timestamp: '2:30 PM',
                  isSent: false,
                  deliveryStatus: DmDeliveryStatus.failed,
                ),
              ),
            ),
          );

          expect(_divineIcon(DivineIconName.warningCircle), findsNothing);
          expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
          expect(find.byIcon(Icons.access_time), findsNothing);
        },
      );
    });

    group('URL linkification', () {
      testWidgets('renders plain text without $RichText', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'No links here',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.text('No links here'), findsOneWidget);
      });

      testWidgets('renders URL as tappable rich text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Check https://divine.video/terms',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('https://divine.video'),
        );
        expect(richTextFinder, findsOneWidget);
      });

      testWidgets('renders npub references as profile display names', (
        tester,
      ) async {
        final npub = NostrKeyUtils.encodePubKey(_testHexPubkey);
        final profile = UserProfile(
          pubkey: _testHexPubkey,
          displayName: 'Alice Divine',
          rawData: const {},
          createdAt: DateTime.utc(2026, 5, 7),
          eventId: _testEventId,
        );

        await tester.pumpWidget(
          _routerTestApp(
            _messageRouter('Reported profile $npub'),
            additionalOverrides: [
              userProfileReactiveProvider(
                _testHexPubkey,
              ).overrideWith((ref) => Stream.value(profile)),
            ],
          ),
        );
        await tester.pump();

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('@Alice Divine'),
          ),
        );

        expect(richText.text.toPlainText(), isNot(contains(npub)));
        expect(_findRecognizer(richText.text, '@Alice Divine'), isNotNull);
      });

      testWidgets('routes nevent references to decoded event ids', (
        tester,
      ) async {
        final nevent = NIP19Tlv.encodeNevent(Nevent(id: _testEventId));

        await tester.pumpWidget(
          _routerTestApp(_messageRouter('Watch $nevent')),
        );
        await tester.pump();

        final recognizer = _linkRecognizer(
          tester,
          strings.clickableTextViewVideoLink,
        );
        recognizer.onTap!();
        await tester.pumpAndSettle();

        expect(find.text('video:$_testEventId'), findsOneWidget);
      });

      testWidgets('routes naddr references as stable video links', (
        tester,
      ) async {
        final naddr = NIP19Tlv.encodeNaddr(
          Naddr(id: 'stable-video', author: _testHexPubkey, kind: 34236),
        );

        await tester.pumpWidget(_routerTestApp(_messageRouter('Watch $naddr')));
        await tester.pump();

        final recognizer = _linkRecognizer(
          tester,
          strings.clickableTextViewVideoLink,
        );
        recognizer.onTap!();
        await tester.pumpAndSettle();

        expect(find.text('video:$naddr'), findsOneWidget);
      });

      testWidgets('pushes search route on @mention tap so back returns', (
        tester,
      ) async {
        // Regression: tapping a `@username` mention used to call `context.go`
        // and replace the stack, which broke back navigation from the
        // resulting search page in a DM conversation. Pushing preserves the
        // DM under the search so the user can pop back.
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: MessageBubble(
                  message: 'Hey @hm21',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
            GoRoute(
              path: '/search-results/:query',
              builder: (context, state) => Scaffold(
                body: Text('search:${state.pathParameters['query']}'),
              ),
            ),
          ],
        );

        await tester.pumpWidget(_routerTestApp(router));
        await tester.pump();

        _linkRecognizer(tester, '@hm21').onTap!();
        await tester.pumpAndSettle();

        expect(find.text('search:hm21'), findsOneWidget);
        expect(router.canPop(), isTrue);
      });

      testWidgets('URL span has $TapGestureRecognizer', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Visit https://example.com today',
                timestamp: '2:30 PM',
                isSent: false,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('https://example.com'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        // Text.rich wraps our TextSpan in a parent; unwrap to reach
        // the actual URL spans built by _MessageText.
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpan = innerSpan.children!.firstWhere(
          (span) =>
              span is TextSpan &&
              (span.text?.contains('https://example.com') ?? false),
        ) as TextSpan;

        expect(urlSpan.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('renders multiple URLs in one message', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message:
                    'See https://divine.video/terms and '
                    'https://divine.video/support',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('divine.video'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpans = innerSpan.children!
            .whereType<TextSpan>()
            .where((s) => s.recognizer is TapGestureRecognizer)
            .toList();

        expect(urlSpans, hasLength(2));
      });

      testWidgets('renders bare domain as tappable link', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Visit google.com for info',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('google.com'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpan = innerSpan.children!.firstWhere(
          (span) =>
              span is TextSpan && (span.text?.contains('google.com') ?? false),
        ) as TextSpan;

        expect(urlSpan.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('renders bare domain with path as tappable link', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Check example.com/page today',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('example.com/page'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpan = innerSpan.children!.firstWhere(
          (span) =>
              span is TextSpan &&
              (span.text?.contains('example.com/page') ?? false),
        ) as TextSpan;

        expect(urlSpan.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('renders email address as tappable link', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Email me at user@example.com please',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('user@example.com'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        final innerSpan = textSpan.children!.first as TextSpan;
        final emailSpan = innerSpan.children!.firstWhere(
          (span) =>
              span is TextSpan &&
              (span.text?.contains('user@example.com') ?? false),
        ) as TextSpan;

        expect(emailSpan.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('URL-only message renders as link', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'https://example.com/some-page',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('https://example.com'),
        );
        expect(richTextFinder, findsOneWidget);
      });

      testWidgets('tapping Divine profile link navigates in-app', (
        tester,
      ) async {
        const npub =
            'npub1sn0wdenkukak0d9dfczzeacvhkrgz92ak56egt7vdgzn8pv2wfqqhrjdv9';
        final router = _messageRouter('https://divine.video/profile/$npub');
        addTearDown(router.dispose);

        await tester.pumpWidget(_routerTestApp(router));

        _linkRecognizer(tester, 'https://divine.video/profile/$npub').onTap!();
        await tester.pumpAndSettle();

        expect(find.text('profile:$npub'), findsOneWidget);
      });
    });

    group('video preview card', () {
      late _MockVideosRepository mockVideosRepository;
      late MockNostrClient mockNostrClient;

      final testVideo = VideoEvent(
        id:
            '0123456789abcdef0123456789abcdef'
            '0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789'
            'abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        title: 'My Cool Video',
      );

      setUp(() {
        mockVideosRepository = _MockVideosRepository();
        mockNostrClient = createMockNostrService();

        // Default: the repository resolves nothing (unavailable card).
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            any(),
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => null);
      });

      Widget buildWithVideoMessage({
        required String message,
        DmSharedVideoRef? sharedVideoRef,
        VoidCallback? onDoubleTap,
      }) => testMaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: message,
            timestamp: '2:30 PM',
            isSent: true,
            sharedVideoRef: sharedVideoRef,
            onDoubleTap: onDoubleTap,
          ),
        ),
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
        ],
      );

      testWidgets(
        'suppresses double-tap-to-like on a shared-video bubble '
        '(gesture-arena guard)',
        (tester) async {
          var doubleTapped = false;

          // Default stubs resolve the preview to "unavailable" — a static card
          // with no inner tap target and no pending timer.
          await tester.pumpWidget(
            buildWithVideoMessage(
              message: 'https://divine.video/video/abc123',
              onDoubleTap: () => doubleTapped = true,
            ),
          );
          await tester.pumpAndSettle();

          final center = tester.getCenter(find.byType(MessageBubble));
          await tester.tapAt(center);
          await tester.pump(kDoubleTapMinTime);
          await tester.tapAt(center);
          await tester.pumpAndSettle();

          // Double-tap is not wired on video bubbles: an ancestor onDoubleTap
          // would hold the gesture arena for ~kDoubleTapTimeout and delay
          // tap-to-open the reel. The text-bubble 'calls onDoubleTap' test is
          // the positive control.
          expect(doubleTapped, isFalse);
          expect(find.byType(MessageBubble), findsOneWidget);
        },
      );

      testWidgets('shows loading spinner before video resolves', (
        tester,
      ) async {
        // Use a Completer that never completes so the cubit stays in
        // the loading state without leaving a pending Timer.
        final neverCompletes = Completer<VideoEvent?>();
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            any(),
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) => neverCompletes.future);

        await tester.pumpWidget(
          buildWithVideoMessage(message: 'https://divine.video/video/abc123'),
        );
        // Single pump to build the widget tree (don't settle).
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(VideoThumbnailWidget), findsNothing);
      });

      testWidgets('renders $VideoThumbnailWidget when video is in cache', (
        tester,
      ) async {
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'abc123',
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(message: 'https://divine.video/video/abc123'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        expect(find.text('My Cool Video'), findsOneWidget);
      });

      testWidgets('renders from structured q-tag ref without a legacy URL', (
        tester,
      ) async {
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'abc123',
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(
            message:
                'watch this\n'
                'nostr:naddr1qqxnzd3cxqmrzv3exgmr2wfeqy',
            sharedVideoRef: const DmSharedVideoRef(
              coordinateOrId: '34236:$_testHexPubkey:abc123',
              videoKind: DmSharedVideoKind.addressableShortVideo,
              relayHint: 'wss://relay.example',
              authorPubkey: _testHexPubkey,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        expect(find.text('My Cool Video'), findsOneWidget);
        expect(find.text('watch this'), findsOneWidget);
        expect(find.textContaining('nostr:'), findsNothing);
        verify(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'abc123',
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets(
        'keeps a legacy URL beyond the initial display limit hidden until '
        'Show more',
        (tester) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);
          final note = 'a' * dmInitialDisplayCodeUnits;

          await tester.pumpWidget(
            testMaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MessageBubble(
                    message: '$note\nhttps://divine.video/video/abc123',
                    timestamp: '2:30 PM',
                    isSent: true,
                  ),
                ),
              ),
              mockNostrService: mockNostrClient,
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VideoThumbnailWidget), findsNothing);
          await tester.ensureVisible(find.text(strings.profileShowMore));
          await tester.tap(find.text(strings.profileShowMore));
          await tester.pumpAndSettle();
          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        },
      );

      // `divineVideoUrlRegex` has no right anchor, so a display bound that
      // lands inside the id would otherwise match a shortened id, resolve the
      // wrong video, and keep that cubit after Show more.
      testWidgets(
        'does not resolve a legacy URL that the initial display limit cuts',
        (tester) async {
          final fetchedIds = <String>[];
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              any(),
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((invocation) async {
            final id = invocation.positionalArguments.first as String;
            fetchedIds.add(id);
            return id == 'abc123' ? testVideo : null;
          });
          const urlPrefix = 'https://divine.video/video/';
          // One character of the id sits inside the bound; the rest is cut.
          final note = 'a' * (dmInitialDisplayCodeUnits - urlPrefix.length - 2);

          await tester.pumpWidget(
            testMaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MessageBubble(
                    message: '$note\n${urlPrefix}abc123',
                    timestamp: '2:30 PM',
                    isSent: true,
                  ),
                ),
              ),
              mockNostrService: mockNostrClient,
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          expect(fetchedIds, isEmpty);
          expect(find.byType(VideoThumbnailWidget), findsNothing);
          expect(
            find.text(strings.notificationsVideoUnavailable),
            findsNothing,
          );

          await tester.ensureVisible(find.text(strings.profileShowMore));
          await tester.tap(find.text(strings.profileShowMore));
          await tester.pumpAndSettle();

          expect(fetchedIds, ['abc123']);
          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        },
      );

      // divine-web put the share only in tags and allowed an empty draft, so
      // before #6224 this bubble rendered with no card — and mid-group, with
      // no text and no timestamp either, i.e. completely blank.
      testWidgets(
        'renders a legacy divine-web share that carries no content at all',
        (tester) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);

          await tester.pumpWidget(
            buildWithVideoMessage(
              message: '',
              sharedVideoRef: const DmSharedVideoRef(
                coordinateOrId: '34236:$_testHexPubkey:abc123',
                videoKind: DmSharedVideoKind.addressableShortVideo,
                authorPubkey: _testHexPubkey,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          expect(find.text('My Cool Video'), findsOneWidget);
        },
      );

      // A legacy share's body is not the share template — it is only what the
      // sender typed. Stripping the template's quoted-title line here would
      // swallow a comment the sender happened to wrap in quotes.
      testWidgets('keeps a quoted comment on a citation-only share', (
        tester,
      ) async {
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'abc123',
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(
            message: '"nice one"',
            sharedVideoRef: const DmSharedVideoRef(
              coordinateOrId: '34236:$_testHexPubkey:abc123',
              videoKind: DmSharedVideoKind.addressableShortVideo,
              authorPubkey: _testHexPubkey,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        expect(find.text('"nice one"'), findsOneWidget);
      });

      testWidgets('renders the shared-video bubble on a neutral dark frame', (
        tester,
      ) async {
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'abc123',
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(message: 'https://divine.video/video/abc123'),
        );
        await tester.pumpAndSettle();

        // The shared-video bubble uses VineTheme.neutral10 (#1B1C1C) — the
        // Figma `part/video thumbnail` share frame — not the bright sent-text
        // accent, so the thumbnail reads as a media card (isSent is true here).
        final bubble = tester.widget<Container>(
          find.ancestor(
            of: find.byType(VideoThumbnailWidget),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration,
            ),
          ),
        );
        final decoration = bubble.decoration! as BoxDecoration;
        expect(decoration.color, VineTheme.neutral10);
        expect(decoration.color, isNot(VineTheme.primaryAccessible));
      });

      testWidgets('shared-video card matches Figma geometry', (tester) async {
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'abc123',
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(message: 'https://divine.video/video/abc123'),
        );
        await tester.pumpAndSettle();

        // Thumbnail clips at 16 px corners (Figma `part/video thumbnail`
        // radius/16), not the previous 8 px.
        final clip = tester.widget<ClipRRect>(
          find.ancestor(
            of: find.byType(VideoThumbnailWidget),
            matching: find.byType(ClipRRect),
          ),
        );
        expect(clip.borderRadius, BorderRadius.circular(16));

        // Bubble frame uses 16 px horizontal / 12 px vertical padding
        // (Figma spacing/16 + spacing/12), matching the text bubbles.
        final bubble = tester.widget<Container>(
          find.ancestor(
            of: find.byType(VideoThumbnailWidget),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration,
            ),
          ),
        );
        expect(
          bubble.padding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      });

      testWidgets('drops the nostr: citation line beneath the card', (
        tester,
      ) async {
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'abc123',
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(
            // The q-tag share appends a NIP-21 citation after the URL; it must
            // not render as a redundant "View video" link beside the card.
            message:
                'https://divine.video/video/abc123\n'
                'nostr:naddr1qqxnzd3cxqmrzv3exgmr2wfeqy',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        final redundantLink = find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              (w.text.toPlainText().contains('nostr:') ||
                  w.text.toPlainText().contains(
                    AppLocalizationsEn().clickableTextViewVideoLink,
                  )),
        );
        expect(redundantLink, findsNothing);
      });

      testWidgets('shows the unavailable card when video not found', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWithVideoMessage(
            message: 'https://divine.video/video/unknown-id',
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().notificationsVideoUnavailable),
          findsOneWidget,
        );
        expect(find.byType(VideoThumbnailWidget), findsNothing);
        // The URL is no longer rendered as a tappable link.
        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains(
                'https://divine.video/video/unknown-id',
              ),
        );
        expect(richTextFinder, findsNothing);
      });

      testWidgets('unresolved video card is not a tappable link', (
        tester,
      ) async {
        final router = _messageRouter('https://divine.video/video/unknown-id');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _routerTestApp(
            router,
            mockNostrService: mockNostrClient,
            additionalOverrides: [
              videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // The unavailable card replaces the old tappable link — nothing to
        // tap, so navigation never happens.
        expect(
          find.text(AppLocalizationsEn().notificationsVideoUnavailable),
          findsOneWidget,
        );
        expect(find.text('video:unknown-id'), findsNothing);
      });

      testWidgets('preserves surrounding text alongside video preview', (
        tester,
      ) async {
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'abc123',
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(
            message:
                'hey check this out '
                'https://divine.video/video/abc123 what do you think?',
          ),
        );
        await tester.pumpAndSettle();

        // Preview card is rendered.
        expect(find.byType(VideoThumbnailWidget), findsOneWidget);

        // Surrounding text is preserved.
        expect(find.text('hey check this out'), findsOneWidget);
        expect(find.text('what do you think?'), findsOneWidget);
      });

      testWidgets('preserves text before video URL only', (tester) async {
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'abc123',
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(
            message: 'check this https://divine.video/video/abc123',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        expect(find.text('check this'), findsOneWidget);
      });

      testWidgets(
        'drops the share-template quoted title line ahead of the URL',
        (tester) async {
          // VideoSharingService composes the share body as
          //   [personal message?]
          //   "<title>"
          //   <blank>
          //   <URL>
          // The "<title>" line duplicates what the card's overlay
          // footer renders, so the bubble must NOT also show it as
          // bubble text. Pin that contract — without this, the title
          // can silently leak back above the thumbnail.
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);

          await tester.pumpWidget(
            buildWithVideoMessage(
              message:
                  '"Test Vine Title"\n\n'
                  'https://divine.video/video/abc123',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          expect(find.text('"Test Vine Title"'), findsNothing);
        },
      );

      testWidgets(
        'preserves the personal note when share body also carries a '
        'quoted title',
        (tester) async {
          // Real share format with a user-typed personal note. The note
          // must render under the thumbnail; the "<title>" line above
          // it (also part of the template) must NOT render.
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);

          await tester.pumpWidget(
            buildWithVideoMessage(
              message:
                  'You have to watch this 😂\n\n'
                  '"Test Vine Title"\n\n'
                  'https://divine.video/video/abc123',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          expect(find.text('You have to watch this 😂'), findsOneWidget);
          expect(find.text('"Test Vine Title"'), findsNothing);
        },
      );

      testWidgets(
        'drops a quoted title line even when the title itself contains '
        'embedded quotes',
        (tester) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);

          await tester.pumpWidget(
            buildWithVideoMessage(
              message:
                  '"Watch "Inception" trailer"\n\n'
                  'https://divine.video/video/abc123',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          expect(find.text('"Watch "Inception" trailer"'), findsNothing);
        },
      );

      group('failed send routes card taps to resend', () {
        // A hard-failed own video share must route taps on the dominant
        // 248x350 card surface to the outer resend/delete affordance — tap is
        // the sole resend path (long-press deliberately offers none). Without
        // the guard the card's own tap-to-open recognizer wins the arena and
        // swallows the resend affordance.
        GoRouter buildShareRouter({
          required DmDeliveryStatus deliveryStatus,
          VoidCallback? onTap,
        }) {
          return GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: MessageBubble(
                    message: 'https://divine.video/video/abc123',
                    timestamp: '2:30 PM',
                    isSent: true,
                    deliveryStatus: deliveryStatus,
                    onTap: onTap,
                  ),
                ),
              ),
              GoRoute(
                path: '/video/:id',
                builder: (context, state) => Scaffold(
                  body: Text('video:${state.pathParameters['id']}'),
                ),
              ),
            ],
          );
        }

        Future<void> pumpResolvedCard(
          WidgetTester tester,
          GoRouter router,
        ) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);
          await tester.pumpWidget(
            _routerTestApp(
              router,
              mockNostrService: mockNostrClient,
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();
        }

        testWidgets(
          'failed share routes a card tap to the resend affordance, not '
          'the reel',
          (tester) async {
            var tapped = 0;
            final router = buildShareRouter(
              deliveryStatus: DmDeliveryStatus.failed,
              onTap: () => tapped++,
            );
            addTearDown(router.dispose);

            await pumpResolvedCard(tester, router);

            expect(find.byType(VideoThumbnailWidget), findsOneWidget);
            await tester.tap(find.byType(VideoThumbnailWidget));
            await tester.pumpAndSettle();

            // The bubble's resend tap fired once and the reel never opened.
            expect(tapped, 1);
            expect(find.text('video:${testVideo.id}'), findsNothing);
          },
        );

        testWidgets('delivered share opens the reel on a card tap', (
          tester,
        ) async {
          final router = buildShareRouter(
            deliveryStatus: DmDeliveryStatus.delivered,
          );
          addTearDown(router.dispose);

          await pumpResolvedCard(tester, router);

          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          await tester.tap(find.byType(VideoThumbnailWidget));
          await tester.pumpAndSettle();

          // A non-failed bubble keeps the inner tap-to-open recognizer.
          expect(find.text('video:${testVideo.id}'), findsOneWidget);
        });
      });
    });

    group('quoted video reply preview', () {
      late _MockVideosRepository mockVideosRepository;
      late MockNostrClient mockNostrClient;

      final testVideo = VideoEvent(
        id:
            '0123456789abcdef0123456789abcdef'
            '0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789'
            'abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        title: 'My Cool Video',
      );

      const quotedRef = DmSharedVideoRef(
        coordinateOrId: '34236:$_testHexPubkey:abc123',
        videoKind: DmSharedVideoKind.addressableShortVideo,
        relayHint: 'wss://relay.example',
        authorPubkey: _testHexPubkey,
      );

      setUp(() {
        mockVideosRepository = _MockVideosRepository();
        mockNostrClient = createMockNostrService();

        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            any(),
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => null);
      });

      Widget buildWithQuotedReply({
        required String message,
        DmSharedVideoRef? quotedVideoRef,
        VoidCallback? onDoubleTap,
      }) => testMaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: message,
            timestamp: '2:30 PM',
            isSent: true,
            quotedVideoRef: quotedVideoRef,
            onDoubleTap: onDoubleTap,
          ),
        ),
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
        ],
      );

      testWidgets(
        'suppresses double-tap-to-like on a quoted-video reply bubble '
        '(gesture-arena guard)',
        (tester) async {
          var doubleTapped = false;

          // Default stubs resolve the quoted preview to "unavailable" — a
          // static frame with no pending timer.
          await tester.pumpWidget(
            buildWithQuotedReply(
              message: 'love this one',
              quotedVideoRef: quotedRef,
              onDoubleTap: () => doubleTapped = true,
            ),
          );
          await tester.pumpAndSettle();

          final center = tester.getCenter(find.byType(MessageBubble));
          await tester.tapAt(center);
          await tester.pump(kDoubleTapMinTime);
          await tester.tapAt(center);
          await tester.pumpAndSettle();

          // The quoted preview is itself a tap target (opens the cited reel),
          // so double-tap-to-like is suppressed to keep tap-to-open instant.
          expect(doubleTapped, isFalse);
          expect(find.byType(MessageBubble), findsOneWidget);
        },
      );

      testWidgets(
        'renders compact quoted thumbnail above the reply text and not the '
        'full share card',
        (tester) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);

          await tester.pumpWidget(
            buildWithQuotedReply(
              message: 'love this one',
              quotedVideoRef: quotedRef,
            ),
          );
          await tester.pumpAndSettle();

          // The compact quoted preview renders the resolved video as a small
          // thumbnail bounded to 40x56, not the full 248x350 share card.
          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          final compactThumb = find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 40 && w.height == 56,
          );
          expect(compactThumb, findsOneWidget);

          // No full 248x350 share-card SizedBox is present.
          final fullCard = find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 248 && w.height == 350,
          );
          expect(fullCard, findsNothing);

          // The reply text renders below the quoted preview.
          expect(find.text('love this one'), findsOneWidget);
          final thumbCenter = tester
              .getCenter(find.byType(VideoThumbnailWidget))
              .dy;
          final textCenter = tester.getCenter(find.text('love this one')).dy;
          expect(thumbCenter, lessThan(textCenter));

          // The compact thumbnail carries its own small play badge (an 11px
          // glyph) overlaid on the thumbnail, not the full-size 32px badge —
          // so it reads as a neat chip with margin on the 40-wide thumb.
          final playIcon = tester.widget<DivineIcon>(
            find.byWidgetPredicate(
              (w) => w is DivineIcon && w.icon == DivineIconName.play,
            ),
          );
          expect(playIcon.size, 11);

          // The preview is pinned to a fixed width so the bubble doesn't
          // reflow when the cited reel resolves out of its loading skeleton.
          expect(
            find.byWidgetPredicate((w) => w is SizedBox && w.width == 200),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'exposes the resolved quoted preview as a button with the reply hint',
        (tester) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);

          await tester.pumpWidget(
            buildWithQuotedReply(
              message: 'love this one',
              quotedVideoRef: quotedRef,
            ),
          );
          await tester.pumpAndSettle();

          // The tappable preview carries button semantics + the reply hint,
          // co-located on the frame so the tap target is always announced.
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  (w.properties.button ?? false) &&
                  w.properties.label ==
                      AppLocalizationsEn().dmMessageBubbleVideoReplyHint,
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders the full share card for a non-reply share '
        '(sharedVideoRef set, quotedVideoRef null)',
        (tester) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);

          await tester.pumpWidget(
            testMaterialApp(
              home: const Scaffold(
                body: MessageBubble(
                  message: 'watch this',
                  timestamp: '2:30 PM',
                  isSent: true,
                  sharedVideoRef: quotedRef,
                ),
              ),
              mockNostrService: mockNostrClient,
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          // The full share card renders a 248x350 thumbnail (default size),
          // not the compact 40x56 quoted thumbnail.
          final fullCard = find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 248 && w.height == 350,
          );
          expect(fullCard, findsOneWidget);
          final thumbnail = tester.widget<VideoThumbnailWidget>(
            find.byType(VideoThumbnailWidget),
          );
          expect(thumbnail.width, isNull);
          expect(thumbnail.height, isNull);
        },
      );

      testWidgets(
        'renders the compact unavailable chip when the quoted video is '
        'not found',
        (tester) async {
          // No cache hit, no relay event → VideoLinkPreviewNotFound.
          await tester.pumpWidget(
            buildWithQuotedReply(
              message: 'still good though',
              quotedVideoRef: quotedRef,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(AppLocalizationsEn().notificationsVideoUnavailable),
            findsOneWidget,
          );
          expect(find.byType(VideoThumbnailWidget), findsNothing);
          // The reply comment still renders alongside the unavailable chip.
          expect(find.text('still good though'), findsOneWidget);

          // The unavailable chip is pinned to the same fixed width as the
          // resolved card, so swapping states never reflows the bubble.
          expect(
            find.byWidgetPredicate((w) => w is SizedBox && w.width == 200),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'strips the trailing nostr: citation line from the displayed reply '
        'text when quotedVideoRef is set',
        (tester) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);

          await tester.pumpWidget(
            buildWithQuotedReply(
              // The reply self-carries a NIP-21 citation of the quoted video on
              // the wire; it must not render in the bubble text.
              message:
                  'this is hilarious\n'
                  'nostr:naddr1qqxnzd3cxqmrzv3exgmr2wfeqy',
              quotedVideoRef: quotedRef,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('this is hilarious'), findsOneWidget);
          expect(find.textContaining('nostr:'), findsNothing);
        },
      );

      group('failed send routes quoted-frame taps to resend', () {
        // Same gesture-arena guard as the full share card, applied to the
        // compact quoted-reply frame that opens the cited reel on tap.
        GoRouter buildQuotedRouter({
          required DmDeliveryStatus deliveryStatus,
          VoidCallback? onTap,
        }) {
          return GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: MessageBubble(
                    message: 'love this one',
                    timestamp: '2:30 PM',
                    isSent: true,
                    quotedVideoRef: quotedRef,
                    deliveryStatus: deliveryStatus,
                    onTap: onTap,
                  ),
                ),
              ),
              GoRoute(
                path: '/video/:id',
                builder: (context, state) => Scaffold(
                  body: Text('video:${state.pathParameters['id']}'),
                ),
              ),
            ],
          );
        }

        Future<void> pumpResolvedQuote(
          WidgetTester tester,
          GoRouter router,
        ) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'abc123',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);
          await tester.pumpWidget(
            _routerTestApp(
              router,
              mockNostrService: mockNostrClient,
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();
        }

        testWidgets(
          'failed reply routes a quoted-frame tap to the resend affordance, '
          'not the reel',
          (tester) async {
            var tapped = 0;
            final router = buildQuotedRouter(
              deliveryStatus: DmDeliveryStatus.failed,
              onTap: () => tapped++,
            );
            addTearDown(router.dispose);

            await pumpResolvedQuote(tester, router);

            // The compact thumb's centered play badge overlaps its exact
            // center, so tapAt the card surface rather than tap(finder).
            expect(find.byType(VideoThumbnailWidget), findsOneWidget);
            await tester.tapAt(
              tester.getCenter(find.byType(VideoThumbnailWidget)),
            );
            await tester.pumpAndSettle();

            expect(tapped, 1);
            expect(find.text('video:${testVideo.id}'), findsNothing);
          },
        );

        testWidgets('delivered reply opens the reel on a quoted-frame tap', (
          tester,
        ) async {
          final router = buildQuotedRouter(
            deliveryStatus: DmDeliveryStatus.delivered,
          );
          addTearDown(router.dispose);

          await pumpResolvedQuote(tester, router);

          // The compact thumb's centered play badge overlaps its exact
          // center, so tapAt the card surface rather than tap(finder).
          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          await tester.tapAt(
            tester.getCenter(find.byType(VideoThumbnailWidget)),
          );
          await tester.pumpAndSettle();

          expect(find.text('video:${testVideo.id}'), findsOneWidget);
        });
      });
    });

    group('long-press', () {
      testWidgets('calls onLongPress callback', (tester) async {
        var longPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Long press me',
                timestamp: '2:30 PM',
                isSent: true,
                onLongPress: () => longPressed = true,
              ),
            ),
          ),
        );

        await tester.longPress(find.text('Long press me'));
        await tester.pumpAndSettle();

        expect(longPressed, isTrue);
      });

      testWidgets('does not crash when onLongPress is null', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'No callback',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        await tester.longPress(find.text('No callback'));
        await tester.pumpAndSettle();

        expect(find.text('No callback'), findsOneWidget);
      });
    });

    group('double-tap', () {
      testWidgets('calls onDoubleTap', (tester) async {
        var doubleTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Double tap me',
                timestamp: '2:30 PM',
                isSent: true,
                onDoubleTap: () => doubleTapped = true,
              ),
            ),
          ),
        );

        final target = tester.getCenter(find.text('Double tap me'));
        await tester.tapAt(target);
        // Second tap within the double-tap window (>= min gap, < timeout).
        await tester.pump(kDoubleTapMinTime);
        await tester.tapAt(target);
        await tester.pumpAndSettle();

        expect(doubleTapped, isTrue);
      });

      testWidgets('does not crash when onDoubleTap is null', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'No double tap',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final target = tester.getCenter(find.text('No double tap'));
        await tester.tapAt(target);
        await tester.pump(kDoubleTapMinTime);
        await tester.tapAt(target);
        await tester.pumpAndSettle();

        expect(find.text('No double tap'), findsOneWidget);
      });

      testWidgets('suppresses double-tap-to-like on a truncated bubble', (
        tester,
      ) async {
        // An ancestor onDoubleTap would hold the gesture arena for
        // ~kDoubleTapTimeout, delaying the Show more link's first tap.
        var doubleTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageBubble(
                  message: 'a' * (dmInitialDisplayCodeUnits + 1),
                  timestamp: '2:30 PM',
                  isSent: true,
                  onDoubleTap: () => doubleTapped = true,
                ),
              ),
            ),
          ),
        );

        final target = tester.getCenter(find.text('2:30 PM'));
        await tester.tapAt(target);
        await tester.pump(kDoubleTapMinTime);
        await tester.tapAt(target);
        await tester.pumpAndSettle();

        expect(doubleTapped, isFalse);
        expect(find.text(strings.profileShowMore), findsOneWidget);
      });
    });

    group('message updates', () {
      testWidgets('renders the new content when the message changes in '
          'place', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'first body',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'second body',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.text('second body'), findsOneWidget);
        expect(find.text('first body'), findsNothing);
      });

      testWidgets('collapses an expanded bubble when the message changes in '
          'place', (tester) async {
        final first = 'a' * dmMaxDisplayCodeUnits;
        final second = 'b' * dmInitialDisplayCodeUnits;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageBubble(
                  message: '${first}x',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.text(strings.profileShowMore));
        await tester.tap(find.text(strings.profileShowMore));
        await tester.pump();
        expect(find.text(strings.profileShowLess), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageBubble(
                  message: '${second}y',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          ),
        );

        expect(_longestRenderedText(tester), second);
        expect(find.text(strings.profileShowLess), findsNothing);
        expect(find.text(strings.profileShowMore), findsOneWidget);
      });
    });

    group('markdown rendering', () {
      /// Walks the rendered span tree and collects every TextSpan that
      /// satisfies [predicate]. Used to assert on the inline-style
      /// flags applied to the rendered content.
      List<TextSpan> spansMatching(
        WidgetTester tester,
        bool Function(TextSpan span) predicate,
      ) {
        final hits = <TextSpan>[];
        final richTexts = tester
            .widgetList<RichText>(find.byType(RichText))
            .toList();
        for (final richText in richTexts) {
          void visit(InlineSpan span) {
            if (span is TextSpan) {
              if (predicate(span)) hits.add(span);
              (span.children ?? const <InlineSpan>[]).forEach(visit);
            }
          }

          visit(richText.text);
        }
        return hits;
      }

      Widget bubble(String message, {bool isSent = true}) {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: testProviderScope(
              child: MessageBubble(
                message: message,
                timestamp: '2:30 PM',
                isSent: isSent,
              ),
            ),
          ),
        );
      }

      testWidgets('bold span renders with FontWeight.w700', (tester) async {
        await tester.pumpWidget(bubble('say **hi** please'));

        final boldSpans = spansMatching(
          tester,
          (span) =>
              span.text == 'hi' && span.style?.fontWeight == FontWeight.w700,
        );
        expect(boldSpans, hasLength(1));
      });

      testWidgets('italic span renders with FontStyle.italic', (tester) async {
        await tester.pumpWidget(bubble('be _kind_ today'));

        final italicSpans = spansMatching(
          tester,
          (span) =>
              span.text == 'kind' && span.style?.fontStyle == FontStyle.italic,
        );
        expect(italicSpans, hasLength(1));
      });

      testWidgets('strikethrough span renders with lineThrough decoration', (
        tester,
      ) async {
        await tester.pumpWidget(bubble('that is ~~wrong~~ now'));

        final strikeSpans = spansMatching(
          tester,
          (span) =>
              span.text == 'wrong' &&
              span.style?.decoration == TextDecoration.lineThrough,
        );
        expect(strikeSpans, hasLength(1));
      });

      testWidgets('inline code renders with monospace + translucent bg', (
        tester,
      ) async {
        await tester.pumpWidget(bubble('run `flutter test` first'));

        final codeSpans = spansMatching(
          tester,
          (span) => span.text == 'flutter test',
        );
        expect(codeSpans, hasLength(1));
        final style = codeSpans.single.style!;
        // Chivo Mono comes through google_fonts so the fontFamily
        // string includes a hash suffix — match by prefix.
        expect(style.fontFamily, startsWith('ChivoMono'));
        expect(style.background, isNotNull);
      });

      testWidgets('received bubble uses a lighter code background', (
        tester,
      ) async {
        await tester.pumpWidget(bubble('try `x()`', isSent: false));

        final codeSpan = spansMatching(
          tester,
          (span) => span.text == 'x()',
        ).single;
        final bgAlpha = codeSpan.style!.background!.color.a;
        // Received variant uses 0.10 alpha; sent uses 0.18. Match the
        // received bucket here.
        expect(bgAlpha, closeTo(0.10, 0.02));
      });

      testWidgets('snake_case identifiers do not italicize', (tester) async {
        await tester.pumpWidget(bubble('try foo_bar_baz today'));

        final italicSpans = spansMatching(
          tester,
          (span) =>
              (span.text?.contains('bar') ?? false) &&
              span.style?.fontStyle == FontStyle.italic,
        );
        expect(italicSpans, isEmpty);
      });

      testWidgets('unmatched ** does not crash and renders as literal', (
        tester,
      ) async {
        await tester.pumpWidget(bubble('half **incomplete'));

        // No bold span emitted.
        final boldSpans = spansMatching(
          tester,
          (span) => span.style?.fontWeight == FontWeight.w700,
        );
        expect(boldSpans, isEmpty);
        // The literal markers reach the rendered text.
        expect(find.textContaining('**incomplete'), findsOneWidget);
      });

      testWidgets('plain message without markdown markers renders unchanged', (
        tester,
      ) async {
        await tester.pumpWidget(bubble('just regular text here'));

        // No span carries any of the markdown style overrides.
        expect(
          spansMatching(
            tester,
            (span) => span.style?.fontWeight == FontWeight.w700,
          ),
          isEmpty,
        );
        expect(
          spansMatching(
            tester,
            (span) => span.style?.fontStyle == FontStyle.italic,
          ),
          isEmpty,
        );
        expect(
          spansMatching(
            tester,
            (span) => span.style?.decoration == TextDecoration.lineThrough,
          ),
          isEmpty,
        );
        expect(find.textContaining('just regular text here'), findsOneWidget);
      });
    });
  });
}
