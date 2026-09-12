import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_support.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  String? launchedUrl;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrl = url;
    return true;
  }

  @override
  LinkDelegate? get linkDelegate => null;
}

class _MockProfileRepository extends Mock implements ProfileRepository {}

const _testHexPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

const _mentionedHexPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

void main() {
  group('LinkifiedText', () {
    late UrlLauncherPlatform originalUrlLauncherPlatform;
    late _FakeUrlLauncherPlatform fakeUrlLauncherPlatform;

    setUp(() {
      originalUrlLauncherPlatform = UrlLauncherPlatform.instance;
      fakeUrlLauncherPlatform = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fakeUrlLauncherPlatform;
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalUrlLauncherPlatform;
    });

    final strings = AppLocalizationsEn();

    group('wrapper compatibility', () {
      testWidgets('renders plain text as a simple Text widget', (tester) async {
        const plainText = 'This is a simple text without hashtags';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: plainText)),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        expect(text.data, equals(plainText));
        expect(text.textSpan, isNull);
      });

      testWidgets('keeps URL spans tappable and normalizes bare domains', (
        tester,
      ) async {
        const textWithLink = 'Read more at example.com/docs';

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: LinkifiedText(text: textWithLink)),
            ),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();
        final linkSpan = spans.firstWhere(
          (span) => span.text == 'example.com/docs',
        );

        expect(linkSpan.recognizer, isA<TapGestureRecognizer>());

        final recognizer = linkSpan.recognizer! as TapGestureRecognizer;
        recognizer.onTap!();
        await tester.pump();

        expect(fakeUrlLauncherPlatform.launchedUrl, 'https://example.com/docs');
      });

      testWidgets('keeps trailing punctuation outside URL spans', (
        tester,
      ) async {
        const textWithLink = 'Visit violetblue.com.!';

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: LinkifiedText(text: textWithLink)),
            ),
          ),
        );

        final text = tester.widget<Text>(find.byType(Text));
        final textSpan = text.textSpan! as TextSpan;
        final spans = textSpan.children!.cast<TextSpan>();
        final linkSpan = spans.firstWhere(
          (span) => span.text == 'violetblue.com',
        );
        final punctuationSpan = spans.firstWhere((span) => span.text == '.!');

        expect(linkSpan.recognizer, isA<TapGestureRecognizer>());
        expect(punctuationSpan.recognizer, isNull);
      });
    });

    testWidgets('displays plain text without hashtags correctly', (
      tester,
    ) async {
      const plainText = 'This is a simple text without hashtags';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LinkifiedText(text: plainText)),
        ),
      );

      expect(find.text(plainText), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('displays text with single hashtag', (tester) async {
      const textWithHashtag = 'Check out this #vine';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LinkifiedText(text: textWithHashtag)),
        ),
      );

      // The Text.rich widget should contain the full text
      // Note: Text.rich with spans doesn't match find.text(), find by type instead
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('displays text with multiple hashtags', (tester) async {
      const textWithHashtags = '#trending videos on #vine are #amazing';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LinkifiedText(text: textWithHashtags)),
        ),
      );

      // Text.rich with spans doesn't match find.text()
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('handles hashtags at end of text', (tester) async {
      const textWithTrailingHashtag = 'This is awesome #vine';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LinkifiedText(text: textWithTrailingHashtag),
          ),
        ),
      );

      // Text.rich with spans doesn't match find.text()
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('handles hashtags with underscores and numbers', (
      tester,
    ) async {
      const textWithComplexHashtags = 'Testing #vine_2024 and #test_123';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LinkifiedText(text: textWithComplexHashtags),
          ),
        ),
      );

      // Text.rich with spans doesn't match find.text()
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('respects maxLines property', (tester) async {
      const longText =
          'This is a very long text with #hashtag1 and #hashtag2 '
          'that should be truncated based on maxLines property. '
          'Here is more text with #hashtag3 and #hashtag4 '
          'that might not be visible due to line limits.';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LinkifiedText(text: longText, maxLines: 2),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 2);
    });

    testWidgets('handles empty text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LinkifiedText(text: '')),
        ),
      );

      // Empty text should render as SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('handles text with only spaces', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LinkifiedText(text: '   ')),
        ),
      );

      // Text with only spaces should still render
      expect(find.text('   '), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('widget builds without errors', (tester) async {
      // Test various edge cases to ensure no crashes
      final testCases = [
        'Normal text',
        '#hashtag',
        'Text with #hashtag in middle',
        'Multiple #hashtags #here',
        '#start with hashtag',
        'End with hashtag #end',
        '##double#hashtag',
        'Special chars #test!',
        '#',
        '# space after hash',
        'URL https://example.com/#anchor should not be hashtag',
      ];

      for (final testText in testCases) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: testText)),
          ),
        );

        // Should not crash
        expect(find.byType(LinkifiedText), findsOneWidget);

        // Clear the widget tree before next test
        await tester.pumpWidget(Container());
      }
    });

    testWidgets('launches bare domains as external links', (tester) async {
      const textWithLink = 'Read more at example.com/docs';

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: textWithLink)),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      final textSpan = text.textSpan! as TextSpan;
      final spans = textSpan.children!.cast<TextSpan>();
      final linkSpan = spans.firstWhere(
        (span) => span.text == 'example.com/docs',
      );

      expect(linkSpan.recognizer, isNotNull);

      final recognizer = linkSpan.recognizer! as TapGestureRecognizer;
      recognizer.onTap!();
      await tester.pump();

      expect(fakeUrlLauncherPlatform.launchedUrl, 'https://example.com/docs');
    });

    testWidgets('opens exact profile match for plain mention before search', (
      tester,
    ) async {
      const mention = 'shutupphia';
      final profile = UserProfile(
        pubkey: _mentionedHexPubkey,
        name: mention,
        displayName: 'Sophia',
        rawData: const {'name': mention, 'display_name': 'Sophia'},
        createdAt: DateTime.utc(2026, 6, 21),
        eventId:
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
      );
      final profileRepository = _MockProfileRepository();
      when(
        () => profileRepository.searchUsersLocally(
          query: mention,
          limit: 10,
        ),
      ).thenAnswer((_) async => [profile]);
      when(
        () => profileRepository.searchUsers(query: mention, limit: 10),
      ).thenAnswer((_) async => const []);

      final expectedNpub = NostrKeyUtils.encodePubKey(_mentionedHexPubkey);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: LinkifiedText(text: '@shutupphia FOLLOW HER.'),
            ),
          ),
          GoRoute(
            path: OtherProfileScreen.pathWithNpub,
            builder: (context, state) =>
                Text('profile:${state.pathParameters['npub']}'),
          ),
          GoRoute(
            path: SearchResultsPage.path,
            builder: (context, state) =>
                Text('search:${state.pathParameters['query']}'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(profileRepository),
            profileReadRepositoryProvider.overrideWithValue(profileRepository),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      final textSpan = text.textSpan! as TextSpan;
      final spans = textSpan.children!.cast<TextSpan>();
      final mentionSpan = spans.firstWhere((span) => span.text == '@$mention');

      final recognizer = mentionSpan.recognizer! as TapGestureRecognizer;
      recognizer.onTap!();
      await tester.pumpAndSettle();

      expect(find.text('profile:$expectedNpub'), findsOneWidget);
      expect(find.text('search:$mention'), findsNothing);
      verify(
        () => profileRepository.searchUsersLocally(
          query: mention,
          limit: 10,
        ),
      ).called(1);
      verifyNever(
        () => profileRepository.searchUsers(query: mention, limit: 10),
      );
    });

    test(
      'resolves remote exact profile match when local cache misses',
      () async {
        const mention = 'shutupphia';
        final profile = UserProfile(
          pubkey: _mentionedHexPubkey,
          name: mention,
          rawData: const {'name': mention},
          createdAt: DateTime.utc(2026, 6, 21),
          eventId: 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
        );
        final profileRepository = _MockProfileRepository();
        when(
          () => profileRepository.searchUsersLocally(
            query: mention,
            limit: 10,
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => profileRepository.searchUsers(query: mention, limit: 10),
        ).thenAnswer((_) async => [profile]);

        final pubkey =
            await LinkifiedTextSupport.resolveProfilePubkeyForMention(
              profileRepository,
              mention,
            );

        expect(pubkey, _mentionedHexPubkey);
        verify(
          () => profileRepository.searchUsersLocally(
            query: mention,
            limit: 10,
          ),
        ).called(1);
        verify(
          () => profileRepository.searchUsers(query: mention, limit: 10),
        ).called(1);
      },
    );

    testWidgets('parses bare npub mentions as tappable profile spans', (
      tester,
    ) async {
      final npub = NostrKeyUtils.encodePubKey(_testHexPubkey);
      final textWithMention = 'Find me at $npub';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: textWithMention)),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan, isNotNull);

      final textSpan = text.textSpan! as TextSpan;
      final spans = textSpan.children!.cast<TextSpan>();
      final fallbackName = UserProfile.defaultDisplayNameFor(_testHexPubkey);
      final mentionSpan = spans.firstWhere(
        (span) => span.text == '@$fallbackName',
      );

      expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());
    });

    testWidgets('renders labeled hex event references as video links', (
      tester,
    ) async {
      const eventId =
          'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
      const textWithEvent = 'Content Report\nEvent: $eventId';

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LinkifiedText(text: textWithEvent)),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      final textSpan = text.textSpan! as TextSpan;

      expect(textSpan.toPlainText(), isNot(contains(eventId)));
      expect(
        textSpan.toPlainText(),
        contains(strings.clickableTextViewVideoLink),
      );

      final spans = textSpan.children!.cast<TextSpan>();
      final videoSpan = spans.firstWhere(
        (span) => span.text == strings.clickableTextViewVideoLink,
      );

      expect(videoSpan.recognizer, isA<TapGestureRecognizer>());
    });

    testWidgets('prefers onUrlTap over launching directly when provided', (
      tester,
    ) async {
      final tappedUrls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LinkifiedText(
              text: 'Visit https://example.com',
              onUrlTap: (url) async => tappedUrls.add(url),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      final textSpan = text.textSpan! as TextSpan;
      final spans = textSpan.children!.cast<TextSpan>();
      final urlSpan = spans.firstWhere(
        (span) => span.text == 'https://example.com',
      );

      final recognizer = urlSpan.recognizer! as TapGestureRecognizer;
      recognizer.onTap!();
      await tester.pump();

      expect(tappedUrls, ['https://example.com']);
      expect(fakeUrlLauncherPlatform.launchedUrl, isNull);
    });

    testWidgets('parses bare nprofile mentions as tappable profile spans', (
      tester,
    ) async {
      final nprofile = NIP19Tlv.encodeNprofile(
        Nprofile(pubkey: _testHexPubkey),
      );
      final textWithMention = 'Find me at $nprofile';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: textWithMention)),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan, isNotNull);

      final textSpan = text.textSpan! as TextSpan;
      final spans = textSpan.children!.cast<TextSpan>();
      final fallbackName = UserProfile.defaultDisplayNameFor(_testHexPubkey);
      final mentionSpan = spans.firstWhere(
        (span) => span.text == '@$fallbackName',
      );

      expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());
    });

    testWidgets('uses display nip05 when no profile name is available', (
      tester,
    ) async {
      final npub = NostrKeyUtils.encodePubKey(_testHexPubkey);
      final textWithMention = 'Find me at $npub';
      final profile = UserProfile(
        pubkey: _testHexPubkey,
        nip05: '_@alice.divine.video',
        rawData: const {},
        createdAt: DateTime.utc(2026, 4, 16),
        eventId:
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileReactiveProvider(
              _testHexPubkey,
            ).overrideWith((ref) => Stream.value(profile)),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LinkifiedText(text: textWithMention)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan, isNotNull);

      final textSpan = text.textSpan! as TextSpan;
      final spans = textSpan.children!.cast<TextSpan>();
      final mentionSpan = spans.firstWhere(
        (span) => span.text == '@alice',
      );

      expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());
    });

    // Note: Testing tap functionality and navigation requires integration testing
    // or mocking the navigation system, which is complex in this context.
    // The tap functionality would be tested in integration tests.
  });
}
