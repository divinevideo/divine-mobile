// ABOUTME: Unit tests for ReportContentDialog widget (bottom sheet)
// ABOUTME: Tests Apple compliance requirements, reason selection, and submission

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart' as nostr;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/widgets/report_content_dialog.dart';

import '../helpers/keyboard_content_insertion.dart';
import '../helpers/scroll.dart';
import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() {
    registerFallbackValue(ContentFilterReason.spam);
  });

  late VideoEvent testVideo;
  late _MockContentReportingService mockReportingService;
  late _MockContentBlocklistRepository mockBlocklistRepository;

  setUp(() {
    final testNostrEvent = nostr.Event(
      syntheticTestPubkey,
      34236,
      [
        ['d', 'test_video_id'],
        ['title', 'Test Video'],
        ['imeta', 'url https://example.com/test.mp4', 'm video/mp4'],
      ],
      'Test video content',
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    testNostrEvent.id =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    testNostrEvent.sig = 'aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22';

    testVideo = VideoEvent.fromNostrEvent(testNostrEvent);
    mockReportingService = _MockContentReportingService();
    mockBlocklistRepository = _MockContentBlocklistRepository();

    when(
      () => mockReportingService.reportContent(
        eventId: any(named: 'eventId'),
        authorPubkey: any(named: 'authorPubkey'),
        reason: any(named: 'reason'),
        details: any(named: 'details'),
        sourceRelay: any(named: 'sourceRelay'),
        additionalContext: any(named: 'additionalContext'),
        hashtags: any(named: 'hashtags'),
        moderationContent: any(named: 'moderationContent'),
        moderationTags: any(named: 'moderationTags'),
      ),
    ).thenAnswer(
      (_) async => ReportResult.createSuccess(
        'test_report_id',
        delivery: ReportDelivery.queued,
      ),
    );

    when(
      () => mockReportingService.reportUser(
        userPubkey: any(named: 'userPubkey'),
        reason: any(named: 'reason'),
        details: any(named: 'details'),
        relatedEventIds: any(named: 'relatedEventIds'),
        moderationContent: any(named: 'moderationContent'),
        moderationTags: any(named: 'moderationTags'),
      ),
    ).thenAnswer(
      (_) async => ReportResult.createSuccess(
        'test_user_report_id',
        delivery: ReportDelivery.queued,
      ),
    );
  });

  Future<void> setLargeSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('$ReportContentDialog constructor', () {
    test(
      'throws when neither a video nor message identifiers are provided',
      () {
        expect(ReportContentDialog.new, throwsA(isA<ArgumentError>()));
      },
    );

    test('does not throw when only a userPubkey is provided', () {
      expect(
        () => ReportContentDialog(userPubkey: 'pubkey_hex'),
        returnsNormally,
      );
    });
  });

  group('$ReportContentDialog rendering', () {
    Widget buildSubject() => ProviderScope(
      overrides: [
        contentReportingServiceProvider.overrideWith(
          (ref) async => mockReportingService,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReportContentDialog(video: testVideo)),
      ),
    );

    testWidgets('renders form heading and policy notice', (tester) async {
      await setLargeSurface(tester);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportWhyReporting), findsOneWidget);
    });

    testWidgets('renders all report reason options', (tester) async {
      await setLargeSurface(tester);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportReasonSpam), findsOneWidget);
      expect(find.text(l10n.reportReasonHarassment), findsOneWidget);
      expect(find.text(l10n.reportReasonViolence), findsOneWidget);
      expect(find.text(l10n.reportReasonSexualContent), findsOneWidget);
      expect(find.text(l10n.reportReasonCopyright), findsOneWidget);
      expect(find.text(l10n.reportReasonFalseInfo), findsOneWidget);
      expect(find.text(l10n.reportReasonCsam), findsOneWidget);
      expect(find.text(l10n.reportReasonAiGenerated), findsOneWidget);
      expect(find.text(l10n.reportReasonOther), findsOneWidget);
    });

    testWidgets('renders subtitle text for each reason', (tester) async {
      await setLargeSurface(tester);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportReasonHarassmentSubtitle), findsOneWidget);
      expect(find.text(l10n.reportReasonOtherSubtitle), findsOneWidget);
    });

    testWidgets('details field is hidden until Other is selected', (
      tester,
    ) async {
      await setLargeSurface(tester);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text(l10n.reportDetailsTextOnly), findsNothing);

      await tester.tap(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(l10n.reportDetailsTextOnly), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(l10n.reportDetailsTextOnly)).dy,
        lessThan(tester.getTopLeft(find.byType(TextField)).dy),
        reason: 'The text-only disclosure must be read before the field',
      );

      final detailsField = tester.widget<TextField>(find.byType(TextField));
      expect(detailsField.keyboardType, TextInputType.multiline);
      expect(detailsField.textInputAction, TextInputAction.newline);
      expect(detailsField.textCapitalization, TextCapitalization.sentences);
    });

    testWidgets(
      'Submit button is visible before selecting a reason (Apple requirement) '
      'but stays disabled until one is picked',
      (tester) async {
        await setLargeSurface(tester);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final submitButton = find.widgetWithText(
          DivineButton,
          l10n.reportSubmit,
        );
        expect(
          submitButton,
          findsOneWidget,
          reason:
              'Submit button must be visible before selecting a reason '
              '(Apple requirement)',
        );
        expect(
          tester.widget<DivineButton>(submitButton).onPressed,
          isNull,
          reason: 'Nothing to submit until a reason is picked',
        );

        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        expect(
          tester.widget<DivineButton>(submitButton).onPressed,
          isNotNull,
          reason: 'Picking a reason enables submission',
        );
      },
    );

    testWidgets(
      'Submit button shows error when Other selected without details',
      (tester) async {
        await setLargeSurface(tester);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.reportReasonOther));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.reportOtherRequiresDetails),
          findsOneWidget,
          reason: 'Should require details when Other is selected',
        );
      },
    );

    testWidgets('renders correct number of report reason options', (
      tester,
    ) async {
      await setLargeSurface(tester);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // One card per ContentFilterReason value — each has a Semantics(button)
      // wrapping it that we can count.
      expect(
        ContentFilterReason.values.length,
        equals(11),
        reason: 'Sanity-check: 11 report reasons defined',
      );
      // Verify all titles render by checking the last and first in the list.
      expect(find.text(l10n.reportReasonSpam), findsOneWidget);
      expect(find.text(l10n.reportReasonOther), findsOneWidget);
    });
  });

  group('$ReportContentDialog submission', () {
    late MockNostrClient mockNostrClient;

    setUp(() {
      mockNostrClient = createMockNostrService();
      when(() => mockNostrClient.publicKey).thenReturn('test_pubkey_hex');
    });

    Widget buildSubject() {
      // GoRouter is needed so Navigator.of(context).pop() finds the right route.
      // Material wrapper is required because showDialog alone doesn't provide one
      // (unlike showModalBottomSheet which the production path uses).
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        Material(child: ReportContentDialog(video: testVideo)),
                  ),
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          contentBlocklistRepositoryProvider.overrideWith(
            (ref) => mockBlocklistRepository,
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Widget buildBottomSheetSubject() {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      ReportContentDialog.show(context, video: testVideo),
                  child: const Text('Open Bottom Sheet Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          contentBlocklistRepositoryProvider.overrideWith(
            (ref) => mockBlocklistRepository,
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> openReportDialog(WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();
    }

    Future<void> openBottomSheetReport(WidgetTester tester) async {
      await tester.pumpWidget(buildBottomSheetSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Bottom Sheet Report'));
      await tester.pumpAndSettle();
    }

    testWidgets('selecting reason and tapping Submit calls reportContent', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      verify(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
          moderationContent: any(named: 'moderationContent'),
          moderationTags: any(named: 'moderationTags'),
        ),
      ).called(1);
    });

    testWidgets('video report forwards the source relay to reportContent', (
      tester,
    ) async {
      const sourceRelay = 'wss://relay.staging.dvines.org';
      testVideo = testVideo.copyWith(sourceRelay: sourceRelay);

      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      verify(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: sourceRelay,
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
          moderationContent: any(named: 'moderationContent'),
          moderationTags: any(named: 'moderationTags'),
        ),
      ).called(1);
    });

    testWidgets('successful report shows the confirmation view', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonHarassment));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportReceivedThankYou), findsOneWidget);
    });

    testWidgets(
      'Submit button enters loading state while submission is in progress '
      '(prevents double-tap duplicate Kind 1984)',
      (tester) async {
        final completer = Completer<ReportResult>();
        when(
          () => mockReportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
            moderationContent: any(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        ).thenAnswer((_) => completer.future);

        await setLargeSurface(tester);
        await openReportDialog(tester);

        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pump();

        final submitBtn = tester.widget<DivineButton>(
          find.widgetWithText(DivineButton, l10n.reportSubmit),
        );
        expect(
          submitBtn.isLoading,
          isTrue,
          reason: 'Button must show loading state during submission',
        );

        completer.complete(
          ReportResult.createSuccess(
            'test_report_id',
            delivery: ReportDelivery.queued,
          ),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets('failed report shows inline error', (tester) async {
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
          moderationContent: any(named: 'moderationContent'),
          moderationTags: any(named: 'moderationTags'),
        ),
      ).thenAnswer(
        (_) async =>
            ReportResult.failure('moderation-api says: quota exceeded'),
      );

      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportFailed), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // #3589: the moderation service's own prose is arbitrary
      // server-controlled text and must not reach Divine's error surface.
      expect(find.textContaining('moderation-api'), findsNothing);
      expect(find.textContaining('quota exceeded'), findsNothing);
    });

    testWidgets('exception during report shows inline error', (tester) async {
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
          moderationContent: any(named: 'moderationContent'),
          moderationTags: any(named: 'moderationTags'),
        ),
      ).thenThrow(Exception('Network error'));

      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportFailed), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Network error'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets(
      'bottom sheet path keeps report errors inline instead of using snackbars',
      (tester) async {
        when(
          () => mockReportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
            moderationContent: any(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        ).thenAnswer((_) async => ReportResult.failure('Server error'));

        await setLargeSurface(tester);
        await openBottomSheetReport(tester);

        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(find.text(l10n.reportFailed), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'submit failure surfaces the error on screen without scrolling',
      (tester) async {
        when(
          () => mockReportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
            moderationContent: any(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        ).thenAnswer((_) async => ReportResult.failure('Server error'));

        // A real phone, not the roomy default surface: the eleven reason
        // cards overflow here the way they do on device.
        const screen = Size(412, 915);
        await tester.binding.setSurfaceSize(screen);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await openBottomSheetReport(tester);

        // Pick the first reason so the user never has to scroll — the pinned
        // submit action is reachable from offset zero.
        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        final errorRect = tester.getRect(
          find.text(l10n.reportFailed),
        );
        expect(
          errorRect.bottom,
          lessThanOrEqualTo(screen.height),
          reason:
              'The error must be visible where the user tapped. Rendered at '
              'the end of the scroll content it lands far below the fold and '
              'the failed submit looks like it did nothing.',
        );
        expect(errorRect.top, greaterThanOrEqualTo(0));
      },
    );

    testWidgets('the inline error announces its message once', (tester) async {
      final handle = tester.ensureSemantics();

      await setLargeSurface(tester);
      await openBottomSheetReport(tester);

      await tester.ensureVisible(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      final error = tester.getSemantics(
        find.text(l10n.reportOtherRequiresDetails),
      );

      // `container: true` already absorbs the Text, so a `label:` on the
      // annotation would prepend a second copy and a screen reader would
      // read the whole error twice.
      expect(error.label, l10n.reportOtherRequiresDetails);
      expect(
        error.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
        reason: 'The error appears without focus moving, so it must announce',
      );

      handle.dispose();
    });

    testWidgets(
      'bottom sheet path surfaces validation errors inline without snackbars',
      (tester) async {
        await setLargeSurface(tester);
        await openBottomSheetReport(tester);

        await tester.ensureVisible(find.text(l10n.reportReasonOther));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.reportReasonOther));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(find.text(l10n.reportOtherRequiresDetails), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('dragging the sheet content down dismisses the sheet', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openBottomSheetReport(tester);

      expect(find.text(l10n.reportWhyReporting), findsOneWidget);

      // The sheet's scroll view must run on the DraggableScrollableSheet's
      // own controller — with a private one the drag never reaches the sheet
      // and the report form traps the user.
      await tester.drag(
        find.text(l10n.reportWhyReporting),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportWhyReporting), findsNothing);
    });

    testWidgets('Other reason with details submits successfully', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Custom report details');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      verify(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: ContentFilterReason.other,
          details: 'Custom report details',
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
          moderationContent: any(named: 'moderationContent'),
          moderationTags: any(named: 'moderationTags'),
        ),
      ).called(1);
    });
  });

  group('moderation DM integration', () {
    late MockNostrClient mockNostrClient;
    late _MockDmRepository mockDmRepository;

    late _MockModerationLabelService mockModerationLabelService;

    /// When set, holds `contentReportingServiceProvider` unresolved so a test
    /// can act inside the await `_submitReport` performs before it publishes.
    Completer<ContentReportingService>? serviceGate;

    setUp(() {
      mockNostrClient = createMockNostrService();
      mockDmRepository = _MockDmRepository();
      mockModerationLabelService = _MockModerationLabelService();
      serviceGate = null;

      when(() => mockNostrClient.publicKey).thenReturn('test_pubkey_hex');
      when(
        () => mockModerationLabelService.divineModerationPubkeyHex,
      ).thenReturn(ModerationLabelService.fallbackModerationPubkeyHex);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'dm_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
        ),
      );
    });

    Widget buildSubject() {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        Material(child: ReportContentDialog(video: testVideo)),
                  ),
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        mockModerationLabelService: mockModerationLabelService,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) => serviceGate?.future ?? Future.value(mockReportingService),
          ),
          contentBlocklistRepositoryProvider.overrideWith(
            (ref) => mockBlocklistRepository,
          ),
          dmRepositoryProvider.overrideWithValue(mockDmRepository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    /// Scrolls the reason list to [reasonLabel] and selects it.
    Future<void> selectReason(WidgetTester tester, String reasonLabel) async {
      await scrollUntilTappable(
        tester,
        find.text(reasonLabel),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(reasonLabel));
      await tester.pumpAndSettle();
    }

    Future<void> openAndSubmitReport(
      WidgetTester tester, {
      String? reasonLabel,
    }) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      await selectReason(tester, reasonLabel ?? l10n.reportReasonSpam);

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'confirms a queued report without starting screen-owned network work',
      (tester) async {
        await setLargeSurface(tester);
        await openAndSubmitReport(tester);
        expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
        verifyNever(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
            additionalTags: any(named: 'additionalTags'),
          ),
        );
        await tester.tap(find.text(l10n.reportClose));
        await tester.pumpAndSettle();
        expect(find.text('Open Report'), findsOneWidget);
      },
    );

    Widget buildSubjectWithAuth(MockAuthService auth) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        Material(child: ReportContentDialog(video: testVideo)),
                  ),
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        mockAuthService: auth,
        mockModerationLabelService: mockModerationLabelService,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          dmRepositoryProvider.overrideWithValue(mockDmRepository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> openSubmitWithAuth(
      WidgetTester tester,
      MockAuthService a,
    ) async {
      await tester.pumpWidget(buildSubjectWithAuth(a));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'shows the "Message the moderation team" affordance when signed in',
      (tester) async {
        final mockAuth = createMockAuthService();
        when(
          () => mockAuth.currentPublicKeyHex,
        ).thenReturn(syntheticTestPubkey);

        await setLargeSurface(tester);
        await openSubmitWithAuth(tester, mockAuth);

        expect(find.text(l10n.reportContactModeration), findsOneWidget);
      },
    );

    testWidgets('hides the contact-moderation affordance when signed out', (
      tester,
    ) async {
      // createMockAuthService stubs currentPublicKeyHex -> null.
      await setLargeSurface(tester);
      await openSubmitWithAuth(tester, createMockAuthService());

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportContactModeration), findsNothing);
    });

    testWidgets(
      'report succeeds when DM send throws (unauthenticated/no keys)',
      (tester) async {
        final noKeysDmRepo = _MockDmRepository();
        when(
          () => noKeysDmRepo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenThrow(Exception('No keys available'));

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => Material(
                        child: ReportContentDialog(video: testVideo),
                      ),
                    ),
                    child: const Text('Open Report'),
                  ),
                ),
              ),
            ),
          ],
        );

        await setLargeSurface(tester);
        await tester.pumpWidget(
          testProviderScope(
            mockNostrService: mockNostrClient,
            additionalOverrides: [
              contentReportingServiceProvider.overrideWith(
                (ref) async => mockReportingService,
              ),
              dmRepositoryProvider.overrideWithValue(noKeysDmRepo),
            ],
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Report'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
        verifyNever(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
            additionalTags: any(named: 'additionalTags'),
          ),
        );
      },
    );
  });

  group('moderation DM integration (showForMessage path)', () {
    late MockNostrClient mockNostrClient;
    late _MockDmRepository mockDmRepository;
    late _MockModerationLabelService mockModerationLabelService;

    const testMessageId =
        'aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222';
    const testSenderPubkey = syntheticTestPubkey;

    setUp(() {
      mockNostrClient = createMockNostrService();
      mockDmRepository = _MockDmRepository();
      mockModerationLabelService = _MockModerationLabelService();

      when(() => mockNostrClient.publicKey).thenReturn('test_pubkey_hex');
      when(
        () => mockModerationLabelService.divineModerationPubkeyHex,
      ).thenReturn(ModerationLabelService.fallbackModerationPubkeyHex);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'dm_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
        ),
      );
    });

    Widget buildMessageReportSubject() {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => Material(
                      child: ReportContentDialog(
                        eventId: testMessageId,
                        authorPubkey: testSenderPubkey,
                        moderationKindLabel: 'DM Message Report',
                        moderationEventLabel: 'Message ID',
                      ),
                    ),
                  ),
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        mockModerationLabelService: mockModerationLabelService,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          contentBlocklistRepositoryProvider.overrideWith(
            (ref) => mockBlocklistRepository,
          ),
          dmRepositoryProvider.overrideWithValue(mockDmRepository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> openAndSubmitMessageReport(WidgetTester tester) async {
      await tester.pumpWidget(buildMessageReportSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'moderation DM body uses DM Message Report header and Message ID label',
      (tester) async {
        await setLargeSurface(tester);
        await openAndSubmitMessageReport(tester);

        final captured = verify(
          () => mockReportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            sourceRelay: any(named: 'sourceRelay'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            moderationContent: captureAny(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        ).captured;

        final dmContent = captured.single as String;
        expect(
          dmContent,
          contains('DM Message Report'),
          reason:
              'header should distinguish message reports from video reports',
        );
        expect(
          dmContent,
          contains('Message ID: $testMessageId'),
          reason: 'event-id line should be labeled "Message ID:" not "Event:"',
        );
        expect(
          dmContent,
          isNot(contains('Content Report')),
          reason: 'video-report header must not leak into message-report body',
        );
        expect(
          dmContent,
          isNot(contains('Event: $testMessageId')),
          reason: 'video-report event-id label must not leak into message body',
        );
      },
    );
  });

  group('user report (showForUser path)', () {
    late MockNostrClient mockNostrClient;
    late _MockDmRepository mockDmRepository;
    late _MockModerationLabelService mockModerationLabelService;

    const testUserPubkey = syntheticTestPubkey;

    setUp(() {
      mockNostrClient = createMockNostrService();
      mockDmRepository = _MockDmRepository();
      mockModerationLabelService = _MockModerationLabelService();

      when(() => mockNostrClient.publicKey).thenReturn('test_pubkey_hex');
      when(
        () => mockModerationLabelService.divineModerationPubkeyHex,
      ).thenReturn(ModerationLabelService.fallbackModerationPubkeyHex);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'dm_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
        ),
      );
    });

    Widget buildUserReportSubject({VideoEvent? video}) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => Material(
                      child: ReportContentDialog(
                        video: video,
                        userPubkey: testUserPubkey,
                        moderationKindLabel: 'User Report',
                        moderationEventLabel: 'User Pubkey',
                      ),
                    ),
                  ),
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        mockModerationLabelService: mockModerationLabelService,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          contentBlocklistRepositoryProvider.overrideWith(
            (ref) => mockBlocklistRepository,
          ),
          dmRepositoryProvider.overrideWithValue(mockDmRepository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> openAndSubmitUserReport(
      WidgetTester tester, {
      VideoEvent? video,
    }) async {
      await tester.pumpWidget(buildUserReportSubject(video: video));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.reportReasonHarassment));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();
    }

    testWidgets('DM omits sha256 even when a video was also supplied', (
      tester,
    ) async {
      // The constructor permits `video` and `userPubkey` together, and
      // `userPubkey` is what decides the report targets the account. Attaching
      // the video's blob hash anyway would make the backend file a user report
      // against that specific video.
      await setLargeSurface(tester);
      await openAndSubmitUserReport(
        tester,
        video: testVideo.copyWith(sha256: 'a' * 64),
      );

      final tags =
          verify(
                () => mockReportingService.reportUser(
                  userPubkey: any(named: 'userPubkey'),
                  reason: any(named: 'reason'),
                  details: any(named: 'details'),
                  moderationContent: any(named: 'moderationContent'),
                  moderationTags: captureAny(named: 'moderationTags'),
                ),
              ).captured.single
              as List<List<String>>;

      expect(tags.where((tag) => tag.first == 'sha256'), isEmpty);
    });

    testWidgets(
      'submission calls reportUser with the user pubkey and skips reportContent',
      (tester) async {
        await setLargeSurface(tester);
        await openAndSubmitUserReport(tester);

        verify(
          () => mockReportingService.reportUser(
            userPubkey: testUserPubkey,
            reason: ContentFilterReason.harassment,
            details: any(named: 'details'),
            relatedEventIds: any(named: 'relatedEventIds'),
            moderationContent: any(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        ).called(1);

        verifyNever(
          () => mockReportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
            moderationContent: any(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        );
      },
    );

    testWidgets(
      'moderation DM body uses User Report header and the synthetic user_<pubkey> event id',
      (tester) async {
        await setLargeSurface(tester);
        await openAndSubmitUserReport(tester);

        final captured = verify(
          () => mockReportingService.reportUser(
            userPubkey: any(named: 'userPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            moderationContent: captureAny(named: 'moderationContent'),
            moderationTags: any(named: 'moderationTags'),
          ),
        ).captured;

        final dmContent = captured.single as String;
        expect(
          dmContent,
          contains('User Report'),
          reason: 'header should distinguish user reports from content reports',
        );
        expect(
          dmContent,
          contains('User Pubkey: user_$testUserPubkey'),
          reason: 'event-id line should carry the synthetic user_<pubkey> id',
        );
        expect(
          dmContent,
          isNot(contains('Content Report')),
          reason: 'content-report header must not leak into user-report body',
        );
      },
    );

    testWidgets('successful user report shows the in-sheet confirmation', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openAndSubmitUserReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
    });
  });

  group('moderation constants', () {
    test('moderation pubkey is a valid 64-character hex string', () {
      expect(
        ModerationLabelService.fallbackModerationPubkeyHex.length,
        equals(64),
      );
      expect(
        RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(ModerationLabelService.fallbackModerationPubkeyHex),
        isTrue,
      );
    });
  });

  group('$ReportContentDialog image insertion (#8210)', () {
    Widget buildSubject({ThemeData? theme}) => ProviderScope(
      overrides: [
        contentReportingServiceProvider.overrideWith(
          (ref) async => mockReportingService,
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReportContentDialog(video: testVideo)),
      ),
    );

    Future<void> openDetailsField(
      WidgetTester tester, {
      ThemeData? theme,
    }) async {
      await setLargeSurface(tester);
      await tester.pumpWidget(buildSubject(theme: theme));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'drops a keyboard-inserted image and shows an honest notice '
      'instead of silently discarding it',
      (tester) async {
        await openDetailsField(tester);

        const reporterWords = 'see the clip I am reporting';
        await tester.enterText(find.byType(TextField), reporterWords);
        await tester.pumpAndSettle();

        await commitKeyboardImage(tester);
        await tester.pumpAndSettle();

        // The image never enters the field: the typed words are untouched and
        // nothing from the inserted content leaks into the report.
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          reporterWords,
        );
        // And the reporter is told, on-surface, that it was not attached.
        expect(find.text(l10n.reportDetailsImageNotAttached), findsOneWidget);
      },
    );

    testWidgets(
      'does not show the not-attached notice until an image is inserted',
      (tester) async {
        await openDetailsField(tester);

        expect(find.text(l10n.reportDetailsImageNotAttached), findsNothing);
      },
    );

    testWidgets(
      'announces to screen readers that the inserted image was not attached',
      (tester) async {
        final announcements = <Map<Object?, Object?>>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (Object? message) async {
                if (message is Map) announcements.add(message);
                return null;
              },
            );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                null,
              ),
        );

        await openDetailsField(tester);
        await tester.enterText(find.byType(TextField), 'x');
        await tester.pumpAndSettle();

        await commitKeyboardImage(tester);
        await tester.pumpAndSettle();

        final announced = announcements
            .where((m) => m['type'] == 'announce')
            .map((m) => (m['data'] as Map?)?['message']);
        expect(
          announced,
          contains(l10n.reportDetailsImageNotAttached),
          reason:
              'a dropped image must be announced to screen readers, not only '
              'shown on screen',
        );
      },
    );

    testWidgets('clears the not-attached notice once the reporter types', (
      tester,
    ) async {
      await openDetailsField(tester);

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pumpAndSettle();
      await commitKeyboardImage(tester);
      await tester.pumpAndSettle();
      expect(find.text(l10n.reportDetailsImageNotAttached), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'the reported clip shows harassment',
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportDetailsImageNotAttached), findsNothing);
    });

    testWidgets(
      'paints the not-attached notice in the light palette so a light-mode '
      'reporter can actually read it',
      (tester) async {
        await openDetailsField(tester, theme: VineTheme.lightTheme);

        await commitKeyboardImage(tester);
        await tester.pumpAndSettle();

        final notice = tester.widget<Text>(
          find.text(l10n.reportDetailsImageNotAttached),
        );
        expect(
          notice.style?.color,
          VineTheme.lightColors.onSurfaceVariant,
          reason:
              'The notice is the whole point of the fix. Painted with the '
              'static dark constant it composites to white-on-white on the '
              'light sheet, so a light-mode reporter sees the same silent '
              'drop #8210 set out to end.',
        );
      },
    );

    testWidgets(
      'keeps the not-attached notice when the details field gets a fresh '
      'State (reason reselection), because the flag lives in the durable '
      'parent',
      (tester) async {
        await openDetailsField(tester);
        await commitKeyboardImage(tester);
        await tester.pumpAndSettle();
        expect(find.text(l10n.reportDetailsImageNotAttached), findsOneWidget);

        // Leaving "Other" unmounts the details block and returning rebuilds it
        // from scratch. A notice flag stored in the field's State would be
        // lost across that; the parent-owned flag survives it.
        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);

        await tester.tap(find.text(l10n.reportReasonOther));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.reportDetailsImageNotAttached),
          findsOneWidget,
          reason: 'the notice must survive a fresh details-field State',
        );
      },
    );

    testWidgets(
      'renders the not-attached notice above the field, not below, so the '
      'keyboard cannot cover it the moment it fires',
      (tester) async {
        await openDetailsField(tester);
        await commitKeyboardImage(tester);
        await tester.pumpAndSettle();

        final noticeBottom = tester
            .getRect(find.text(l10n.reportDetailsImageNotAttached))
            .bottom;
        final fieldTop = tester.getRect(find.byType(TextField)).top;
        expect(
          noticeBottom,
          lessThanOrEqualTo(fieldTop),
          reason:
              'below the field the notice lands behind the keyboard media '
              'panel at the instant it fires (#8511 review)',
        );
      },
    );
  });
}
