// ABOUTME: Tests for the report sheet's post-submission confirmation state.
// ABOUTME: Pins the safety-link semantics so the URL is announced once.
// ABOUTME: Also covers the contact-moderation push and its failure handling.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/widgets/report_content_confirmation.dart';

import '../helpers/go_router.dart';
import '../helpers/test_provider_overrides.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Widget buildSubject() => const MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ReportConfirmationBody(),
    ),
  );

  group(ReportConfirmationBody, () {
    testWidgets('renders the thank-you copy', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportReceivedThankYou), findsOneWidget);
    });

    testWidgets('safety link is a button that announces its label once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final link = tester.getSemantics(
        find.textContaining(l10n.reportSafetyUrl),
      );

      // A `label:` on the Semantics annotation is prepended to the child
      // Text's own label rather than replacing it, so a redundant one makes
      // a screen reader read the URL twice.
      expect(link.label, '${l10n.reportLearnMoreAt} ${l10n.reportSafetyUrl}');
      expect(link.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(link.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });
  });

  group(ReportConfirmationActions, () {
    const userPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const moderationPubkey = ModerationLabelService.fallbackModerationPubkeyHex;
    final conversationPath = ConversationPage.pathForId(
      DmRepository.computeConversationId([userPubkey, moderationPubkey]),
    );

    late MockGoRouter router;

    setUp(() {
      router = MockGoRouter();
    });

    // The actions sit on a pushed route so popping the sheet leaves a
    // launcher page behind instead of emptying the navigator.
    Future<void> openActions(WidgetTester tester) async {
      await tester.pumpWidget(
        testProviderScope(
          mockAuthService: createMockAuthService(
            currentPublicKeyHex: userPubkey,
          ),
          child: MockGoRouterProvider(
            goRouter: router,
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          body: ReportConfirmationActions(
                            isFromShareMenu: false,
                          ),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'contact moderation closes the sheet and opens the moderation '
      'conversation',
      (tester) async {
        when(
          () => router.push<void>(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async {});

        await openActions(tester);
        await tester.tap(find.text(l10n.reportContactModeration));
        await tester.pumpAndSettle();

        verify(
          () => router.push<void>(
            conversationPath,
            extra: const [moderationPubkey],
          ),
        ).called(1);
        expect(find.byType(ReportConfirmationActions), findsNothing);
      },
    );

    testWidgets(
      'a failed moderation conversation push is observed, not left unhandled',
      (tester) async {
        when(
          () => router.push<void>(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) => Future<void>.error(StateError('route failed')));

        await openActions(tester);
        await tester.tap(find.text(l10n.reportContactModeration));
        await tester.pumpAndSettle();

        verify(
          () => router.push<void>(
            conversationPath,
            extra: const [moderationPubkey],
          ),
        ).called(1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
