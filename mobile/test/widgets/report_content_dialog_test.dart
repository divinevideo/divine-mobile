// ABOUTME: Unit tests for ReportContentDialog widget (bottom sheet)
// ABOUTME: Tests Apple compliance requirements, reason selection, and submission

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart' as nostr;
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/l10n/content_filter_reason_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
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
      ),
    ).thenAnswer(
      (_) async => ReportResult.createSuccess(
        'test_report_id',
        delivery: ReportDelivery.reached,
      ),
    );

    when(
      () => mockReportingService.reportUser(
        userPubkey: any(named: 'userPubkey'),
        reason: any(named: 'reason'),
        details: any(named: 'details'),
        relatedEventIds: any(named: 'relatedEventIds'),
      ),
    ).thenAnswer(
      (_) async => ReportResult.createSuccess(
        'test_user_report_id',
        delivery: ReportDelivery.reached,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
            delivery: ReportDelivery.reached,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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

    /// The `additionalTags` the dialog attached to the single moderation DM.
    List<List<String>> captureDmTags() {
      final captured = verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: captureAny(named: 'additionalTags'),
        ),
      ).captured;

      return captured.single as List<List<String>>;
    }

    testWidgets('sends DM to moderation team after successful report', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
    });

    testWidgets('caps and reports a truncated paste in details', (
      tester,
    ) async {
      // The details field feeds the same main-isolate sanitizer as the other
      // two support forms, so it carries the same cap - and the same duty to
      // say when the cap dropped part of a paste.
      await setLargeSurface(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportFieldLimitReached), findsNothing);

      await tester.enterText(
        find.byType(TextField),
        'a' * (BugReportConfig.maxFreeTextFieldLength + 500),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .length,
        BugReportConfig.maxFreeTextFieldLength,
      );
      expect(find.text(l10n.supportFieldLimitReached), findsOneWidget);
    });

    testWidgets('DM content redacts a credential typed into details', (
      tester,
    ) async {
      // The moderation DM is a private channel, and the policy requires
      // private channels to redact the same secrets as public ones. The
      // details field is free text, so a pasted credential reaches it.
      await setLargeSurface(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      // The details field only renders for the Other reason.
      await tester.tap(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'they DMed me my password: hunter2',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: captureAny(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).captured;

      final dmContent = captured.single as String;
      expect(dmContent, contains('[REDACTED]'));
      expect(dmContent, isNot(contains('hunter2')));
    });

    testWidgets('DM content includes report reason and event ID', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      final captured = verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: captureAny(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).captured;

      final dmContent = captured.single as String;
      expect(
        dmContent,
        contains('Content Report'),
        reason: 'DM should be labeled as a content report',
      );
      expect(
        dmContent,
        contains('Spam or Unwanted Content'),
        reason: 'DM should include the report reason',
      );
      expect(
        dmContent,
        contains(testVideo.id),
        reason: 'DM should include the reported event ID',
      );
    });

    // The tag values themselves are pinned in
    // test/services/content_reporting_service_test.dart. What only a widget
    // test can catch is the dialog feeding the wrong inputs into the builder:
    // the reason the user actually picked, and the reported video's hash.
    testWidgets('DM tags carry the selected reason and the video blob hash', (
      tester,
    ) async {
      testVideo = testVideo.copyWith(sha256: 'a' * 64);

      await setLargeSurface(tester);
      // Not the default first option, so a dialog that ignored the selection
      // and reported spam would fail here. aiGenerated is also the reason
      // NIP-56 collapses to 'other' while the label stays granular — the
      // regression this change exists to prevent (#6593).
      await openAndSubmitReport(
        tester,
        reasonLabel: l10n.reportReasonTitle(ContentFilterReason.aiGenerated),
      );

      expect(
        captureDmTags(),
        equals([
          ['L', kReportLabelNamespace],
          ['l', 'NS-aiGenerated', kReportLabelNamespace],
          ['report_type', 'other'],
          ['sha256', 'a' * 64],
        ]),
      );
    });

    testWidgets('DM recovers the video blob hash from the URL fallback', (
      tester,
    ) async {
      testVideo = testVideo.copyWith(
        videoUrl: 'https://blossom.example/${'b' * 64}.mp4',
      );
      expect(testVideo.sha256, isNull);

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(
        captureDmTags(),
        equals([
          ['L', kReportLabelNamespace],
          ['l', 'NS-spam', kReportLabelNamespace],
          ['report_type', 'spam'],
          ['sha256', 'b' * 64],
        ]),
      );
    });

    testWidgets('DM omits sha256 when the video has no blob hash', (
      tester,
    ) async {
      // The default fixture's imeta tag has no x sub-value, matching a
      // video published without one.
      expect(testVideo.sha256, isNull);

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      final tags = captureDmTags();
      expect(
        tags.where((t) => t.first == 'sha256'),
        isEmpty,
        reason:
            'user_reports.sha256 is NOT NULL server-side; a blank tag would '
            'let a malformed report through instead of degrading cleanly to '
            'no report row',
      );
    });

    testWidgets('report succeeds even if moderation DM fails', (tester) async {
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenThrow(Exception('DM relay unreachable'));

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(
        find.text(l10n.reportReceivedTitle),
        findsOneWidget,
        reason: 'Report should succeed even if DM fails',
      );
      // C9: the swallowed DM failure is now surfaced as a calm notice
      // instead of only a log line.
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('moderation DM opts out of the NIP-04 fallback (privacy)', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      // C8: moderation reports carry user identity + reported content and
      // must never degrade to a metadata-leaking NIP-04 plaintext duplicate.
      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: true,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
    });

    testWidgets('does not show the DM-delayed notice when the DM succeeds', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsNothing);
    });

    // #6387: sendMessage signals non-delivery by RETURNING a failure, never
    // by throwing, so the sibling `thenThrow` test above exercises a shape
    // production cannot produce. These pin the shapes it actually produces.
    void stubDmResult(NIP17SendResult result) {
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer((_) async => result);
    }

    testWidgets('shows the DM-delayed notice when the send is blocked', (
      tester,
    ) async {
      // The #176 protected-minor send gate returns before the outgoing
      // queue row is written, so this is the one branch with no retry.
      stubDmResult(
        const NIP17SendResult.blocked(
          'blocked: recipient not permitted by send policy',
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('shows the DM-delayed notice on a hard send failure', (
      tester,
    ) async {
      stubDmResult(
        const NIP17SendResult.failure('Message publish failed to relays'),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('shows the DM-delayed notice when the device is offline', (
      tester,
    ) async {
      // Verbatim the value NIP17MessageService returns when its
      // connectivity probe reports offline — the most common instance.
      stubDmResult(
        const NIP17SendResult.failure('Message not sent: device offline'),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('shows the DM-delayed notice when the send is unconfirmed', (
      tester,
    ) async {
      // Recipient frame written but no relay OK inside the window. The
      // durable queue re-drives it, so the notice is pessimistic rather
      // than wrong — but silence would be a claim we cannot support.
      stubDmResult(
        const NIP17SendResult.failure(
          'Message publish timed out',
          retryablePending: true,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('does not confirm when the report reached no channel', (
      tester,
    ) async {
      // #6387/R2: reportContent returns success even when the kind-1984
      // publish failed on every relay AND the Zendesk ticket failed. The
      // confirmation screen would then be false in four places at once, so
      // the flow must surface the failure instead of confirming.
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer(
        (_) async => ReportResult.createSuccess(
          'test_report_id',
          delivery: ReportDelivery.localOnly,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsNothing);
      expect(find.text(l10n.reportNotSent), findsOneWidget);
      // The DM still goes out: sendMessage writes a durable outgoing_dms
      // row before any I/O, and OutgoingDmRetryService replays it on
      // reconnect. It is the only report channel with a retry, so skipping
      // it would make an offline report deliver less often than before.
      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
    });

    testWidgets('handles unawaited moderation DM preflight failures', (
      tester,
    ) async {
      // The localOnly path fires the moderation DM unawaited. Provider reads
      // and DM formatting must still be inside _dispatchModerationDm's catch,
      // otherwise a preflight error escapes to the zone handler.
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer(
        (_) async => ReportResult.createSuccess(
          'test_report_id',
          delivery: ReportDelivery.localOnly,
        ),
      );
      when(
        () => mockModerationLabelService.divineModerationPubkeyHex,
      ).thenThrow(StateError('moderation labels unavailable'));

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);
      await tester.pump();

      expect(find.text(l10n.reportNotSent), findsOneWidget);
      expect(tester.takeException(), isNull);
      verifyNever(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      );
    });

    testWidgets('does not queue a second moderation DM on a repeat submit', (
      tester,
    ) async {
      // Submit stays live on the undelivered path so retrying is one tap.
      // Each tap must not stack another identical row for the sweep to
      // deliver — the user is being invited to retry, not to spam.
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer(
        (_) async => ReportResult.createSuccess(
          'test_report_id',
          delivery: ReportDelivery.localOnly,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      verify(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(2);
      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
    });

    /// Stubs `reportContent` to walk [deliveries], one per successive call,
    /// holding the last entry once exhausted.
    void stubReportDeliveries(List<ReportDelivery> deliveries) {
      var call = 0;
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer((_) async {
        final delivery = deliveries[call.clamp(0, deliveries.length - 1)];
        call++;
        return ReportResult.createSuccess('test_report_id', delivery: delivery);
      });
    }

    testWidgets('both channels label one submit with the reason it started on', (
      tester,
    ) async {
      // The kind-1984 publish and the moderation DM sit a relay round trip
      // apart, and the reason cards stay tappable across it — `_isSubmitting`
      // does not swap the form out. If each channel reads the selection on its
      // own side of that gap, one report gets two different NIP-32 labels,
      // which is the divergence this whole change exists to prevent. Needs no
      // failure or parked row: it is the ordinary success path.
      final handle = tester.ensureSemantics();
      try {
        serviceGate = Completer<ContentReportingService>();
        final publish = Completer<ReportResult>();
        when(
          () => mockReportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            hashtags: any(named: 'hashtags'),
          ),
        ).thenAnswer((_) => publish.future);

        await setLargeSurface(tester);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Report'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        // Not pumpAndSettle: the submit spinner animates for as long as the
        // submit is outstanding, so nothing settles until it completes.
        await tester.pump();

        // Change of mind inside the FIRST await — `_submitReport` resolves the
        // reporting service before it publishes, so this is the window where the
        // kind-1984 side could pick up a reason the DM side never sees.
        // harassment is the second card, so it needs no scroll while the sheet
        // is mid-submit, and NIP-56 maps it to 'profanity' rather than 'spam'.
        await tester.tap(
          find.text(l10n.reportReasonTitle(ContentFilterReason.harassment)),
        );
        await tester.pump();

        // State the premise the assertions below rely on. Everything this test
        // discriminates comes from that tap having actually moved the selection;
        // if a later change stops it landing — an `_isSubmitting` guard on
        // `_onReasonSelected`, an AbsorbPointer over the form — both channels
        // would report spam, the test would stay green, and it would be checking
        // nothing.
        final harassmentSelected = tester
            .getSemantics(
              find.text(l10n.reportReasonTitle(ContentFilterReason.harassment)),
            )
            .getSemanticsData()
            .flagsCollection
            .isSelected;
        expect(
          harassmentSelected,
          Tristate.isTrue,
          reason:
              'the mid-submit reason tap must land for this test to mean '
              'anything',
        );

        serviceGate!.complete(mockReportingService);
        await tester.pump();

        publish.complete(
          ReportResult.createSuccess(
            'test_report_id',
            delivery: ReportDelivery.reached,
          ),
        );
        await tester.pumpAndSettle();

        final reportedReason =
            verify(
                  () => mockReportingService.reportContent(
                    eventId: any(named: 'eventId'),
                    authorPubkey: any(named: 'authorPubkey'),
                    reason: captureAny(named: 'reason'),
                    details: any(named: 'details'),
                    sourceRelay: any(named: 'sourceRelay'),
                    hashtags: any(named: 'hashtags'),
                  ),
                ).captured.single
                as ContentFilterReason;
        final tags =
            verify(
                  () => mockDmRepository.sendMessage(
                    recipientPubkey: any(named: 'recipientPubkey'),
                    content: any(named: 'content'),
                    replyToId: any(named: 'replyToId'),
                    skipNip04Fallback: any(named: 'skipNip04Fallback'),
                    additionalTags: captureAny(named: 'additionalTags'),
                  ),
                ).captured.single
                as List<List<String>>;

        // Whichever reason the submit committed to, both channels carry it.
        expect(reportedReason, ContentFilterReason.spam);
        expect(
          tags,
          equals([
            ['L', kReportLabelNamespace],
            ['l', 'NS-spam', kReportLabelNamespace],
            ['report_type', 'spam'],
          ]),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('both channels use the details text the submit started on', (
      tester,
    ) async {
      serviceGate = Completer<ContentReportingService>();

      await setLargeSurface(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'First details');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Edited details');
      await tester.pump();

      serviceGate!.complete(mockReportingService);
      await tester.pumpAndSettle();

      final reportedDetails =
          verify(
                () => mockReportingService.reportContent(
                  eventId: any(named: 'eventId'),
                  authorPubkey: any(named: 'authorPubkey'),
                  reason: any(named: 'reason'),
                  details: captureAny(named: 'details'),
                  sourceRelay: any(named: 'sourceRelay'),
                  hashtags: any(named: 'hashtags'),
                ),
              ).captured.single
              as String;
      final dmContent =
          verify(
                () => mockDmRepository.sendMessage(
                  recipientPubkey: any(named: 'recipientPubkey'),
                  content: captureAny(named: 'content'),
                  replyToId: any(named: 'replyToId'),
                  skipNip04Fallback: any(named: 'skipNip04Fallback'),
                  additionalTags: any(named: 'additionalTags'),
                ),
              ).captured.single
              as String;

      expect(reportedDetails, 'First details');
      expect(dmContent, contains('Details: First details'));
      expect(dmContent, isNot(contains('Edited details')));
    });

    testWidgets('re-drives the parked DM when a later submit gets through', (
      tester,
    ) async {
      // #6610: the undelivered submit parks a durable outgoing_dms row for
      // the sweep. A later submit that does reach a relay must re-drive
      // THAT row — calling sendMessage again mints a fresh rumor and a
      // second row, so the sweep delivers one copy of the report and the
      // retry delivers another. Receiver-side gift-wrap dedup keys on the
      // rumor id and cannot collapse two of them.
      stubReportDeliveries([ReportDelivery.localOnly, ReportDelivery.reached]);
      stubDmResult(
        const NIP17SendResult.failure(
          'No relays connected',
          queuedRumorId: 'parked_rumor_id',
        ),
      );
      when(
        () => mockDmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'parked_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);
      expect(find.text(l10n.reportNotSent), findsOneWidget);

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      // Exactly one row ever existed, and the second submit drove it.
      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
      verify(
        () => mockDmRepository.recoverFullSend(
          rumorId: 'parked_rumor_id',
          // An explicit resubmit re-arms a budget the sweep may already
          // have spent, so coalescing can't turn a duplicate into a drop.
          resetRetryBudget: true,
        ),
      ).called(1);
      // The team got it, so the confirmation carries no delayed caveat.
      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsNothing);
    });

    testWidgets('sends a changed resubmit after an earlier DM delivered', (
      tester,
    ) async {
      stubReportDeliveries([ReportDelivery.localOnly, ReportDelivery.reached]);
      stubDmResult(
        NIP17SendResult.success(
          rumorEventId: 'dm_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);
      expect(find.text(l10n.reportNotSent), findsOneWidget);

      await selectReason(
        tester,
        l10n.reportReasonTitle(ContentFilterReason.csam),
      );
      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      final capturedTags =
          verify(
                () => mockDmRepository.sendMessage(
                  recipientPubkey: any(named: 'recipientPubkey'),
                  content: any(named: 'content'),
                  replyToId: any(named: 'replyToId'),
                  skipNip04Fallback: any(named: 'skipNip04Fallback'),
                  additionalTags: captureAny(named: 'additionalTags'),
                ),
              ).captured
              as List<Object?>;

      expect(capturedTags, hasLength(2));
      expect(
        capturedTags.last,
        equals([
          ['L', kReportLabelNamespace],
          ['l', 'NS-csam', kReportLabelNamespace],
          ['report_type', 'illegal'],
        ]),
      );
    });

    testWidgets('replaces the parked DM when the user changes the reason', (
      tester,
    ) async {
      // A parked rumor's tags are frozen at build time and replayed verbatim
      // by recoverFullSend, so re-driving it after the user picked a different
      // reason would ship the OLD NIP-32 label while the kind-1984 republish
      // carries the new one. `user_reports` is INSERT OR IGNORE on
      // (sha256, reporter_pubkey), so the first write to land would pin the
      // superseded reason permanently.
      stubReportDeliveries([ReportDelivery.localOnly, ReportDelivery.reached]);
      stubDmResult(
        const NIP17SendResult.failure(
          'No relays connected',
          queuedRumorId: 'parked_rumor_id',
        ),
      );
      when(
        () =>
            mockDmRepository.cancelOutgoingSend(rumorId: any(named: 'rumorId')),
      ).thenAnswer((_) async => true);

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);
      expect(find.text(l10n.reportNotSent), findsOneWidget);

      // Change of mind: spam -> csam. NIP-56 collapses csam to 'illegal'
      // while spam stays 'spam', so a stale re-drive is visible in both tags.
      await selectReason(
        tester,
        l10n.reportReasonTitle(ContentFilterReason.csam),
      );
      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      // The superseded row is dropped rather than re-driven...
      verify(
        () => mockDmRepository.cancelOutgoingSend(rumorId: 'parked_rumor_id'),
      ).called(1);
      verifyNever(
        () => mockDmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      );

      // ...and the replacement DM carries the reason the user actually ended
      // on, not the one the parked rumor froze.
      final tags =
          verify(
                () => mockDmRepository.sendMessage(
                  recipientPubkey: any(named: 'recipientPubkey'),
                  content: any(named: 'content'),
                  replyToId: any(named: 'replyToId'),
                  skipNip04Fallback: any(named: 'skipNip04Fallback'),
                  additionalTags: captureAny(named: 'additionalTags'),
                ),
              ).captured.last
              as List<List<String>>;
      expect(
        tags,
        equals([
          ['L', kReportLabelNamespace],
          ['l', 'NS-csam', kReportLabelNamespace],
          // NIP-56 collapses csam to 'illegal'; spam would have stayed 'spam'.
          ['report_type', 'illegal'],
        ]),
      );
    });

    testWidgets(
      'does not keep retrying a stale cancel after the row becomes ambiguous',
      (tester) async {
        stubReportDeliveries([ReportDelivery.localOnly]);
        stubDmResult(
          const NIP17SendResult.failure(
            'No relays connected',
            queuedRumorId: 'parked_rumor_id',
          ),
        );
        when(
          () => mockDmRepository.cancelOutgoingSend(
            rumorId: any(named: 'rumorId'),
          ),
        ).thenThrow(
          ArgumentError.value(
            'parked_rumor_id',
            'rumorId',
            'no queued outgoing DM with this id',
          ),
        );

        await setLargeSurface(tester);
        await openAndSubmitReport(tester);

        await selectReason(
          tester,
          l10n.reportReasonTitle(ContentFilterReason.csam),
        );

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        verify(
          () => mockDmRepository.cancelOutgoingSend(rumorId: 'parked_rumor_id'),
        ).called(1);
        verifyNever(
          () => mockDmRepository.recoverFullSend(
            rumorId: any(named: 'rumorId'),
            resetRetryBudget: any(named: 'resetRetryBudget'),
          ),
        );
        verify(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
            additionalTags: any(named: 'additionalTags'),
          ),
        ).called(1);
        expect(find.text(l10n.reportNotSent), findsOneWidget);
      },
    );

    testWidgets('replaces the parked DM when the reason changed mid-send', (
      tester,
    ) async {
      // Same divergence as the test above, through the narrower window the
      // offline path opens: it fires the dispatch unawaited and leaves the
      // reason cards live, so the selection can move while the send is still
      // in flight. The parked row must be recorded under the reason its rumor
      // actually carries, not whatever is selected when the await returns.
      stubReportDeliveries([ReportDelivery.localOnly, ReportDelivery.reached]);
      final firstSend = Completer<NIP17SendResult>();
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer(
        (_) => firstSend.isCompleted
            ? Future.value(
                NIP17SendResult.success(
                  rumorEventId: 'replacement_rumor_id',
                  messageEventId: 'dm_event_id',
                  recipientPubkey:
                      ModerationLabelService.fallbackModerationPubkeyHex,
                ),
              )
            : firstSend.future,
      );
      when(
        () =>
            mockDmRepository.cancelOutgoingSend(rumorId: any(named: 'rumorId')),
      ).thenAnswer((_) async => true);

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      // The send is still pending here — change the reason before it parks.
      await selectReason(
        tester,
        l10n.reportReasonTitle(ContentFilterReason.csam),
      );

      firstSend.complete(
        const NIP17SendResult.failure(
          'No relays connected',
          queuedRumorId: 'parked_rumor_id',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      // The parked row was built with spam, so it is superseded and must not
      // be re-driven, even though csam was already selected when it parked.
      verify(
        () => mockDmRepository.cancelOutgoingSend(rumorId: 'parked_rumor_id'),
      ).called(1);
      verifyNever(
        () => mockDmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      );

      final tags =
          verify(
                () => mockDmRepository.sendMessage(
                  recipientPubkey: any(named: 'recipientPubkey'),
                  content: any(named: 'content'),
                  replyToId: any(named: 'replyToId'),
                  skipNip04Fallback: any(named: 'skipNip04Fallback'),
                  additionalTags: captureAny(named: 'additionalTags'),
                ),
              ).captured.last
              as List<List<String>>;
      expect(
        tags,
        equals([
          ['L', kReportLabelNamespace],
          ['l', 'NS-csam', kReportLabelNamespace],
          ['report_type', 'illegal'],
        ]),
      );
    });

    testWidgets("a resubmit does not inherit an in-flight send's reason", (
      tester,
    ) async {
      // The narrowest window of the three: resubmit while the FIRST send is
      // still pending. Returning that outstanding future would report its
      // spam-labelled result as this submit's outcome and never run the
      // replacement pass at all, so the team keeps only the superseded label.
      // The queued submit has to wait for the row to park, then replace it.
      stubReportDeliveries([ReportDelivery.localOnly, ReportDelivery.reached]);
      final firstSend = Completer<NIP17SendResult>();
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer(
        (_) => firstSend.isCompleted
            ? Future.value(
                NIP17SendResult.success(
                  rumorEventId: 'replacement_rumor_id',
                  messageEventId: 'dm_event_id',
                  recipientPubkey:
                      ModerationLabelService.fallbackModerationPubkeyHex,
                ),
              )
            : firstSend.future,
      );
      when(
        () =>
            mockDmRepository.cancelOutgoingSend(rumorId: any(named: 'rumorId')),
      ).thenAnswer((_) async => true);

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      await selectReason(
        tester,
        l10n.reportReasonTitle(ContentFilterReason.csam),
      );

      // Resubmit BEFORE the first send settles.
      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pump();

      firstSend.complete(
        const NIP17SendResult.failure(
          'No relays connected',
          queuedRumorId: 'parked_rumor_id',
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => mockDmRepository.cancelOutgoingSend(rumorId: 'parked_rumor_id'),
      ).called(1);

      final tags =
          verify(
                () => mockDmRepository.sendMessage(
                  recipientPubkey: any(named: 'recipientPubkey'),
                  content: any(named: 'content'),
                  replyToId: any(named: 'replyToId'),
                  skipNip04Fallback: any(named: 'skipNip04Fallback'),
                  additionalTags: captureAny(named: 'additionalTags'),
                ),
              ).captured.last
              as List<List<String>>;
      expect(
        tags,
        equals([
          ['L', kReportLabelNamespace],
          ['l', 'NS-csam', kReportLabelNamespace],
          ['report_type', 'illegal'],
        ]),
      );
    });

    testWidgets(
      'keeps the delayed caveat when recovery cannot prove delivery',
      (tester) async {
        // The sweep can land between two submits and delete the row, but
        // recoverFullSend also throws ArgumentError when the user deleted the
        // failed DM or the row belongs to another account. The dialog cannot
        // distinguish those cases, so it must coalesce (no fresh sendMessage)
        // without claiming this DM definitely reached moderation.
        stubReportDeliveries([
          ReportDelivery.localOnly,
          ReportDelivery.reached,
        ]);
        stubDmResult(
          const NIP17SendResult.failure(
            'No relays connected',
            queuedRumorId: 'parked_rumor_id',
          ),
        );
        when(
          () => mockDmRepository.recoverFullSend(
            rumorId: any(named: 'rumorId'),
            resetRetryBudget: any(named: 'resetRetryBudget'),
          ),
        ).thenThrow(
          ArgumentError.value(
            'parked_rumor_id',
            'rumorId',
            'no queued outgoing DM with this id',
          ),
        );

        await setLargeSurface(tester);
        await openAndSubmitReport(tester);

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        verify(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
            additionalTags: any(named: 'additionalTags'),
          ),
        ).called(1);
        expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
        expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
      },
    );

    testWidgets('never mints a second DM after recovery loses the row', (
      tester,
    ) async {
      // Losing track of the parked row must not re-arm the fresh-send path.
      // Submit stays live on the undelivered path, so an ambiguous
      // ArgumentError followed by one more tap is a third dispatch — and
      // that one has no row to re-drive. Minting a rumor there is the #6610
      // duplicate wearing a different hat: two kind-1059 wraps, two reports
      // to triage, and no correlator to collapse them receiver-side.
      stubReportDeliveries([ReportDelivery.localOnly]);
      stubDmResult(
        const NIP17SendResult.failure(
          'No relays connected',
          queuedRumorId: 'parked_rumor_id',
        ),
      );
      when(
        () => mockDmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      ).thenThrow(
        ArgumentError.value(
          'parked_rumor_id',
          'rumorId',
          'no queued outgoing DM with this id',
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
      // Coalescing spent the row, so the re-drive is not retried either.
      verify(
        () => mockDmRepository.recoverFullSend(
          rumorId: 'parked_rumor_id',
          resetRetryBudget: true,
        ),
      ).called(1);
    });

    testWidgets('keeps the delayed caveat when the re-drive also fails', (
      tester,
    ) async {
      // Coalescing must not launder a still-undelivered DM into silence:
      // the row survives for the sweep, but the team does not have the
      // report yet, so the confirmation still has to say so.
      stubReportDeliveries([ReportDelivery.localOnly, ReportDelivery.reached]);
      stubDmResult(
        const NIP17SendResult.failure(
          'No relays connected',
          queuedRumorId: 'parked_rumor_id',
        ),
      );
      when(
        () => mockDmRepository.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      ).thenAnswer((_) async => const NIP17SendResult.failure('Still offline'));

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
    });

    testWidgets('leaves the report resubmittable after it reached no channel', (
      tester,
    ) async {
      // Leaving Submit live is the whole reason this branch shows an inline
      // error instead of the confirmation, so pin it: a second tap must
      // reach the service again. That also proves the reason selection
      // survived, since _handleSubmitReport short-circuits to
      // reportSelectReason when _selectedReason is null.
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer(
        (_) async => ReportResult.createSuccess(
          'test_report_id',
          delivery: ReportDelivery.localOnly,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportNotSent), findsOneWidget);

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportSelectReason), findsNothing);
      verify(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(2);
    });

    testWidgets('stays silent when only the sender self-wrap failed', (
      tester,
    ) async {
      // The moderation team DID receive the report; only the sender's own
      // cross-device copy is missing. Claiming we couldn't reach the team
      // would be false, so this must NOT show the notice.
      stubDmResult(
        NIP17SendResult.success(
          rumorEventId: 'dm_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
          selfWrapPublished: false,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsNothing);
    });

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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: captureAny(named: 'content'),
            replyToId: any(named: 'replyToId'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
            additionalTags: any(named: 'additionalTags'),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
                () => mockDmRepository.sendMessage(
                  recipientPubkey: any(named: 'recipientPubkey'),
                  content: any(named: 'content'),
                  replyToId: any(named: 'replyToId'),
                  skipNip04Fallback: any(named: 'skipNip04Fallback'),
                  additionalTags: captureAny(named: 'additionalTags'),
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
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: captureAny(named: 'content'),
            replyToId: any(named: 'replyToId'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
            additionalTags: any(named: 'additionalTags'),
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
