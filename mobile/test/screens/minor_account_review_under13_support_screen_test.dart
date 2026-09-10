import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';

import '../helpers/finders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MinorAccountReviewUnder13SupportScreen', () {
    testWidgets('shows copy affordances and copies values', (tester) async {
      // Pin a tall surface so the scrollable guidance content fits and no
      // button sits at the obscured bottom edge of the default 800x600
      // viewport (flaky off-screen/ignore-pointer tap in CI).
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              return const MinorAccountReviewStatus(
                restrictionStatus:
                    AccountRestrictionStatus.restrictedMinorReview,
                currentCase: MinorReviewCase(
                  id: 'case-under13',
                  state: MinorReviewCaseState.restrictedPendingSupportEmail,
                  suspectedAgeBand: SuspectedAgeBand.under13,
                  allowedResolution: MinorReviewResolutionType.supportEmailOnly,
                  instructions: MinorReviewInstructions(
                    title: 'Under-13 review',
                    body: 'Parent support is required.',
                  ),
                  supportEmail: 'support@divine.video',
                ),
              );
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MinorAccountReviewUnder13SupportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(findByTooltip('Copy support email'), findsOneWidget);
      expect(findByTooltip('Copy case ID'), findsOneWidget);

      await tester.ensureVisible(findByTooltip('Copy support email'));
      await tester.pumpAndSettle();
      await tester.tap(findByTooltip('Copy support email'));
      await tester.pumpAndSettle();

      expect(copiedText, 'support@divine.video');
    });

    testWidgets('opens email with the prepared under-13 guidance', (
      tester,
    ) async {
      // See the surface-size note above: keeps "Open email app" (a bottom
      // button in a scrollable ListView) fully hittable in CI.
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? sentToEmail;
      String? sentSubject;
      String? sentBody;
      Rect? sentOrigin;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              return const MinorAccountReviewStatus(
                restrictionStatus:
                    AccountRestrictionStatus.restrictedMinorReview,
                currentCase: MinorReviewCase(
                  id: 'case-under13',
                  state: MinorReviewCaseState.restrictedPendingSupportEmail,
                  suspectedAgeBand: SuspectedAgeBand.under13,
                  allowedResolution: MinorReviewResolutionType.supportEmailOnly,
                  instructions: MinorReviewInstructions(
                    title: 'Under-13 review',
                    body: 'Parent support is required.',
                  ),
                  supportEmail: 'support@divine.video',
                ),
              );
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MinorAccountReviewUnder13SupportScreen(
              composeEmail:
                  ({
                    required String toEmail,
                    required String subject,
                    required String body,
                    Rect? sharePositionOrigin,
                  }) async {
                    sentToEmail = toEmail;
                    sentSubject = subject;
                    sentBody = body;
                    sentOrigin = sharePositionOrigin;
                  },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open email app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open email app'));
      await tester.pumpAndSettle();

      expect(sentToEmail, 'support@divine.video');
      expect(sentSubject, 'Under-13 account review for case case-under13');
      expect(sentBody, contains('I am the parent or guardian'));
      // The composer's share-sheet fallback is refused on iPad without an
      // anchor, so the screen has to resolve one (#7506).
      expect(sentOrigin, isNotNull);
      expect(sentOrigin!.isEmpty, isFalse);
    });
  });
}
