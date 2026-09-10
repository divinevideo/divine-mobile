// ABOUTME: Tests for NotificationCommentQuote — quoted text rendering and
// ABOUTME: optional inline timestamp suffix.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/notification_comment_quote.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

Future<void> _pump(
  WidgetTester tester, {
  required String text,
  String? timestamp,
  String? profileHex,
  UserProfile? profile,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (profileHex != null && profile != null)
          userProfileReactiveProvider(
            profileHex,
          ).overrideWith((ref) => Stream.value(profile)),
      ],
      child: MaterialApp(
        // The widget reads AppLocalizations for the video-reference label;
        // without the delegates it silently falls back to rendering the raw
        // reference, which masks link regressions.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NotificationCommentQuote(text: text, timestamp: timestamp),
        ),
      ),
    ),
  );
}

TextSpan? _findSpan(
  TextSpan root, {
  required bool Function(TextSpan) matching,
}) {
  if (matching(root)) return root;
  for (final child in root.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) {
      final found = _findSpan(child, matching: matching);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  group(NotificationCommentQuote, () {
    const profileHex =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    testWidgets('wraps text in curly quotes', (tester) async {
      await _pump(tester, text: 'Hello world');

      expect(find.textContaining('“Hello world”'), findsOneWidget);
    });

    testWidgets('appends timestamp inline when non-empty', (tester) async {
      await _pump(tester, text: 'Hello world', timestamp: '2d');

      // The Text.rich concatenates to "“Hello world” 2d" — find.text
      // matches Text widgets by their concatenated plaintext.
      expect(find.text('“Hello world” 2d'), findsOneWidget);
    });

    testWidgets('omits timestamp suffix when null', (tester) async {
      await _pump(tester, text: 'Hello world');

      expect(find.text('“Hello world”'), findsOneWidget);
    });

    testWidgets('omits timestamp suffix when empty string', (tester) async {
      await _pump(tester, text: 'Hello world', timestamp: '');

      expect(find.text('“Hello world”'), findsOneWidget);
    });

    testWidgets('caps at two lines for long quotes', (tester) async {
      // A long line will wrap; the widget's own maxLines should clamp.
      await _pump(
        tester,
        text:
            'This is a very long comment that will wrap to multiple lines '
            'when rendered in a constrained-width container, and we want to '
            'make sure the widget caps it at two lines.',
        timestamp: '5h',
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      expect(richText.maxLines, equals(2));
      expect(richText.overflow, equals(TextOverflow.ellipsis));
    });

    testWidgets('timestamp uses the muted on-surface color', (tester) async {
      await _pump(tester, text: 'Hi', timestamp: '2d');

      // Walk the rendered RichText's span tree to find the timestamp
      // suffix. Text.rich wraps our root TextSpan in another span to
      // apply the ambient text style, so our quote/timestamp children
      // sit one level deeper than the RichText's top-level children.
      final richText = tester.widget<RichText>(find.byType(RichText));
      final timestampSpan = _findSpan(
        richText.text as TextSpan,
        matching: (span) => span.text == ' 2d',
      );
      expect(timestampSpan, isNotNull);
      expect(
        timestampSpan!.style?.color,
        equals(VineTheme.darkColors.onSurfaceMuted),
      );
    });

    testWidgets('renders nostr profile references as tappable profile spans', (
      tester,
    ) async {
      final npub = NostrKeyUtils.encodePubKey(profileHex);
      final fallbackName = UserProfile.defaultDisplayNameFor(profileHex);

      await _pump(
        tester,
        text: 'hey nostr:$npub thanks',
        timestamp: '5h',
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      expect(rootSpan.toPlainText(), equals('“hey @$fallbackName thanks” 5h'));
      expect(rootSpan.toPlainText(), isNot(contains(npub)));

      final profileSpan = _findSpan(
        rootSpan,
        matching: (span) => span.text == '@$fallbackName',
      );
      expect(profileSpan, isNotNull);
      expect(profileSpan!.recognizer, isA<TapGestureRecognizer>());
    });

    testWidgets('renders an undecodable npub as raw text (#6346 mode)', (
      tester,
    ) async {
      // The symptom users reported: a bech32 token whose checksum does not
      // verify — which is what slicing one produces — cannot be decoded, so
      // the linkifier leaves it as literal text. This pins *why*
      // NotificationRepository must never split a reference; without it,
      // nothing at this layer fails when truncation regresses.
      final malformed = 'npub1${'q' * 40}';

      await _pump(tester, text: 'hey nostr:$malformed');

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      expect(rootSpan.toPlainText(), contains(malformed));
      expect(rootSpan.toPlainText(), isNot(contains('@')));
    });

    testWidgets('renders an intact 64-hex reference as a tappable link', (
      tester,
    ) async {
      // The linkifier decodes a bare 64-char hex reference as well as bech32,
      // resolving it to a labelled video link. This is why
      // NotificationRepository must protect hex from the preview cut: a hex
      // reference is 64 chars, so an unprotected one was always sliced.
      await _pump(tester, text: 'hey $profileHex thanks');

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      expect(
        rootSpan.toPlainText(),
        equals('“hey ${_l10n.clickableTextViewVideoLink} thanks”'),
      );
      expect(rootSpan.toPlainText(), isNot(contains(profileHex)));

      final linkSpan = _findSpan(
        rootSpan,
        matching: (span) => span.text == _l10n.clickableTextViewVideoLink,
      );
      expect(linkSpan, isNotNull);
      expect(linkSpan!.recognizer, isA<TapGestureRecognizer>());
    });

    testWidgets('renders a partial hex reference as raw text', (tester) async {
      // The other half of the pair above: anything short of 64 hex chars is
      // not a reference, so a sliced one is dumped verbatim into the row.
      // That is the user-visible damage the repository cut used to cause.
      final partialHex = 'a1b2c3d4e5' * 5; // 50 chars — below the 64 needed

      await _pump(tester, text: 'hey $partialHex thanks');

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      expect(rootSpan.toPlainText(), contains(partialHex));
      expect(
        rootSpan.toPlainText(),
        isNot(contains(_l10n.clickableTextViewVideoLink)),
      );
    });

    testWidgets('uses cached profile names for nostr profile references', (
      tester,
    ) async {
      final npub = NostrKeyUtils.encodePubKey(profileHex);
      const displayName = 'Alice Divine';
      final profile = UserProfile(
        pubkey: profileHex,
        displayName: displayName,
        rawData: const {},
        createdAt: DateTime.utc(2026, 6, 16),
        eventId:
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
      );

      await _pump(
        tester,
        text: 'hey nostr:$npub thanks',
        timestamp: '5h',
        profileHex: profileHex,
        profile: profile,
      );
      await tester.pump();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richText.text as TextSpan;
      expect(rootSpan.toPlainText(), equals('“hey @$displayName thanks” 5h'));
      expect(
        rootSpan.toPlainText(),
        isNot(contains(UserProfile.defaultDisplayNameFor(profileHex))),
      );

      final profileSpan = _findSpan(
        rootSpan,
        matching: (span) => span.text == '@$displayName',
      );
      expect(profileSpan, isNotNull);
      expect(profileSpan!.recognizer, isA<TapGestureRecognizer>());
    });
  });
}
