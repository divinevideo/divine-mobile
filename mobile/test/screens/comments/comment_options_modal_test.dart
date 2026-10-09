// ABOUTME: Widget tests for the comment options modal (delete, flag).
// ABOUTME: Option-row taps, and Flag opening the shared report form.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/content_filter_reason_localizations.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/comments/widgets/comment_options_modal.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/widgets/report_content_dialog.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(CommentOptionsModal, () {
    testWidgets('delete option responds when tapping the icon-label gap', (
      tester,
    ) async {
      CommentOptionResult? result;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () async {
                      result = await CommentOptionsModal.showForOwnComment(
                        context,
                        commentId:
                            'comment0123456789abcdef0123456789abcdef01234567',
                        commentContent: 'test comment',
                      );
                    },
                    child: const Text('Open options'),
                  );
                },
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );

      await tester.tap(find.text('Open options'));
      await tester.pumpAndSettle();

      final deleteText = find.text('Delete');
      final deleteIcon = find.byType(SvgPicture).last;
      expect(deleteText, findsOneWidget);
      expect(deleteIcon, findsOneWidget);

      final textRect = tester.getRect(deleteText);
      final iconRect = tester.getRect(deleteIcon);

      await tester.tapAt(
        Offset(
          (iconRect.right + textRect.left) / 2,
          textRect.center.dy,
        ),
      );
      await tester.pumpAndSettle();

      expect(result, isA<CommentDeleteResult>());
    });

    testWidgets('option rows expose activatable button semantics', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      CommentOptionsModal.showForOtherUserIntegrated(
                        context,
                        commentId: 'c' * 64,
                        authorPubkey:
                            'author0123456789abcdef0123456789abcdef012'
                            '3456789ab',
                      ),
                  child: const Text('Open options'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );

      await tester.tap(find.text('Open options'));
      await tester.pumpAndSettle();

      // The Flag Content row gates the whole report flow, so it has to be
      // activatable by a screen reader — excludeSemantics drops the child
      // subtree, which otherwise leaves a button with no tap action.
      expect(
        tester.getSemantics(find.bySemanticsIdentifier('flag_content_option')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsIdentifier('block_user_option')),
        isSemantics(isButton: true, hasTapAction: true),
      );

      semanticsHandle.dispose();
    });

    group('Flag Content', () {
      // Full-length hex, never truncated.
      final commentId = 'c' * 64;
      final authorPubkey = 'a' * 64;
      late _MockContentReportingService reportingService;

      setUpAll(() => registerFallbackValue(ContentFilterReason.spam));

      setUp(() {
        reportingService = _MockContentReportingService();
        when(
          () => reportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
            moderationContent: any(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
            addressableCoordinate: any(named: 'addressableCoordinate'),
          ),
        ).thenAnswer(
          (_) async =>
              ReportResult.createSuccess('r', delivery: ReportDelivery.queued),
        );
      });

      Widget buildSubject({
        void Function(CommentOptionResult?)? onResult,
        TransitionBuilder? builder,
      }) {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      final result =
                          await CommentOptionsModal.showForOtherUserIntegrated(
                            context,
                            commentId: commentId,
                            authorPubkey: authorPubkey,
                          );
                      onResult?.call(result);
                    },
                    child: const Text('Open options'),
                  ),
                ),
              ),
            ),
          ],
        );
        return testProviderScope(
          mockNostrService: createMockNostrService(),
          additionalOverrides: [
            contentReportingServiceProvider.overrideWith(
              (ref) async => reportingService,
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: builder,
            routerConfig: router,
          ),
        );
      }

      testWidgets(
        'opens the shared report form, which names a comment and offers '
        'every reason with the note box',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(buildSubject());
          await tester.tap(find.text('Open options'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.commentOptionsFlagContentLabel));
          await tester.pumpAndSettle();

          expect(find.byType(ReportContentDialog), findsOneWidget);
          expect(find.text(l10n.reportWhyReportingComment), findsOneWidget);
          expect(find.text(l10n.reportWhyReporting), findsNothing);
          for (final reason in ContentFilterReason.values) {
            expect(
              find.text(l10n.reportReasonTitle(reason)),
              findsOneWidget,
              reason: '$reason',
            );
          }
          expect(find.byType(TextField), findsOneWidget);
        },
      );

      testWidgets('reports the comment with the note as typed, or empty', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var resultReported = false;
        CommentOptionResult? result;

        await tester.pumpWidget(
          buildSubject(
            onResult: (r) {
              resultReported = true;
              result = r;
            },
          ),
        );
        await tester.tap(find.text('Open options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.commentOptionsFlagContentLabel));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        final moderationContent =
            verify(
                  () => reportingService.reportContent(
                    eventId: commentId,
                    authorPubkey: authorPubkey,
                    reason: ContentFilterReason.spam,
                    details: '',
                    sourceRelay: any(named: 'sourceRelay'),
                    additionalContext: any(named: 'additionalContext'),
                    hashtags: any(named: 'hashtags'),
                    moderationContent: captureAny(named: 'moderationContent'),
                    moderationTags: any(named: 'moderationTags'),
                    addressableCoordinate: any(
                      named: 'addressableCoordinate',
                    ),
                  ),
                ).captured.single
                as String;
        expect(moderationContent, startsWith('Comment Report\n'));
        expect(moderationContent, contains('Comment ID: $commentId'));
        expect(find.text(l10n.reportReceivedTitle), findsOneWidget);

        // Closing the confirmation ends the options flow with nothing for
        // the comment row to do: the form already submitted the report.
        await tester.tap(find.text(l10n.reportClose));
        await tester.pumpAndSettle();
        expect(resultReported, isTrue);
        expect(result, isNull);
      });

      testWidgets(
        'keeps Submit on screen at large text scale with every reason',
        (tester) async {
          // On a phone-height viewport at the 1.35 accessibility text scale,
          // eleven reasons and the note box exceed the sheet. Submit is pinned
          // in the footer, so it stays reachable without scrolling.
          tester.view.physicalSize = const Size(1179, 2556); // iPhone 16 Pro
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            buildSubject(
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.35,
                maxScaleFactor: 1.35,
                child: child!,
              ),
            ),
          );
          await tester.tap(find.text('Open options'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.commentOptionsFlagContentLabel));
          await tester.pumpAndSettle();

          final submit = find.widgetWithText(DivineButton, l10n.reportSubmit);
          final viewportHeight =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          final submitRect = tester.getRect(submit);
          expect(submitRect.top, greaterThanOrEqualTo(0));
          expect(submitRect.bottom, lessThanOrEqualTo(viewportHeight));

          final lastReason = find.text(l10n.reportReasonOther);
          await tester.ensureVisible(lastReason);
          await tester.pumpAndSettle();
          expect(tester.getRect(submit), submitRect);
          expect(tester.getCenter(lastReason).dy, lessThan(submitRect.top));
        },
      );
    });
  });
}
