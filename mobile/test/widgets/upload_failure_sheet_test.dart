// ABOUTME: Widget tests for the upload failure bottom sheet.
// ABOUTME: Verifies retry, save-to-drafts actions and UI rendering.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/publish_error_kind_l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/upload_failure_sheet.dart';

import '../helpers/go_router.dart';

class _MockDivineVideoDraft extends Mock implements DivineVideoDraft {}

class _MockDivineVideoClip extends Mock implements DivineVideoClip {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _RecordingCrashReporter implements CrashReporter {
  final reports = <({Object error, String? reason})>[];

  @override
  void log(String message) {}

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    reports.add((error: error, reason: reason));
  }
}

// Matches the unkeyed 64x4 rounded Container the header paints as the drag
// handle. Asserting the rendered tree, rather than the forwarded
// showDragHandle flag, is what catches a header that stops honouring it.
final Finder _dragHandle = find.byWidgetPredicate((widget) {
  if (widget is! Container) return false;
  final constraints = widget.constraints;
  return constraints?.maxWidth == 64 && constraints?.maxHeight == 4;
});

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  late _MockDivineVideoDraft mockDraft;
  late _MockDivineVideoClip mockClip;
  late _MockBackgroundPublishBloc mockBloc;
  Future<void>? sheetFuture;

  setUp(() {
    mockDraft = _MockDivineVideoDraft();
    mockClip = _MockDivineVideoClip();
    mockBloc = _MockBackgroundPublishBloc();
    sheetFuture = null;

    when(() => mockDraft.id).thenReturn('draft-1');
    when(() => mockDraft.title).thenReturn('Test Video');
    when(() => mockDraft.clips).thenReturn([mockClip]);

    when(() => mockClip.thumbnailPath).thenReturn(null);
    when(
      () => mockClip.targetAspectRatio,
    ).thenReturn(model.AspectRatio.vertical);
  });

  Widget buildSubject({
    required BackgroundUpload upload,
    MockGoRouter? goRouter,
    ValueListenable<bool>? openerVisible,
  }) {
    final opener = Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => sheetFuture = showUploadFailureSheet(context, upload),
        child: const Text('Open Sheet'),
      ),
    );
    final app = MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<BackgroundPublishBloc>.value(
        value: mockBloc,
        child: Scaffold(
          body: openerVisible == null
              ? opener
              : ValueListenableBuilder<bool>(
                  valueListenable: openerVisible,
                  builder: (_, visible, child) =>
                      visible ? child! : const SizedBox.shrink(),
                  child: opener,
                ),
        ),
      ),
    );
    return goRouter == null
        ? app
        : MockGoRouterProvider(goRouter: goRouter, child: app);
  }

  // Rejects only the push to [failingPath], so each navigation site can be
  // checked on its own.
  MockGoRouter buildGoRouter({String? failingPath}) {
    final goRouter = MockGoRouter();
    when(
      () => goRouter.push<void>(any(), extra: any(named: 'extra')),
    ).thenAnswer((invocation) {
      final location = invocation.positionalArguments.first as String;
      return location == failingPath
          ? Future<void>.error(StateError('push failed'))
          : Future<void>.value();
    });
    return goRouter;
  }

  Future<void> openFailureSheet(
    WidgetTester tester, {
    required PublishErrorKind kind,
    required MockGoRouter goRouter,
    ValueListenable<bool>? openerVisible,
  }) async {
    final upload = BackgroundUpload(
      draft: mockDraft,
      progress: 1,
      result: PublishError(kind),
    );

    await tester.pumpWidget(
      buildSubject(
        upload: upload,
        goRouter: goRouter,
        openerVisible: openerVisible,
      ),
    );
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();
  }

  group('showUploadFailureSheet', () {
    group('renders', () {
      testWidgets('Upload Failed title', (tester) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError(PublishErrorKind.generic),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.uploadFailureSheetTitle), findsOneWidget);
        expect(_dragHandle, findsNothing);
      });

      testWidgets('localized error message from $PublishError kind', (
        tester,
      ) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError(PublishErrorKind.serverUnreachable),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            l10n.publishErrorMessage(PublishErrorKind.serverUnreachable),
          ),
          findsOneWidget,
        );
        // Proves the body reads from l10n, not a hardcoded string.
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('de'),
            ).publishErrorMessage(PublishErrorKind.serverUnreachable),
          ),
          findsNothing,
        );
      });

      testWidgets('renders rawFallback verbatim when present', (tester) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError(
            PublishErrorKind.generic,
            rawFallback: 'Upstream already-friendly message.',
          ),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.text('Upstream already-friendly message.'),
          findsOneWidget,
        );
      });

      testWidgets('no error message when result is not $PublishError', (
        tester,
      ) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: null,
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.uploadFailureSheetTitle), findsOneWidget);
        // Only the title, no additional error text
        expect(
          find.byType(Text),
          findsNWidgets(
            // 'Open Sheet' button + 'Upload Failed' title + button labels
            4,
          ),
        );
      });

      testWidgets('$DivineButton with Try Again label', (tester) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError(PublishErrorKind.generic),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(DivineButton), findsAtLeastNWidgets(1));
        expect(
          find.text(l10n.uploadFailureSheetTryAgainButton),
          findsOneWidget,
        );
      });

      testWidgets('account restriction replaces retry with Account status', (
        tester,
      ) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError(PublishErrorKind.accountRestricted),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.uploadFailureSheetAccountStatusButton),
          findsOneWidget,
        );
        expect(find.text(l10n.uploadFailureSheetTryAgainButton), findsNothing);
      });

      testWidgets('$DivineButton with Save to Drafts label', (tester) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError(PublishErrorKind.generic),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(DivineButton), findsAtLeastNWidgets(1));
        expect(
          find.text(l10n.uploadFailureSheetSaveToDraftsButton),
          findsOneWidget,
        );
      });

      testWidgets('fallback image when clip has no thumbnail', (tester) async {
        when(() => mockClip.thumbnailPath).thenReturn(null);

        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError(PublishErrorKind.generic),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(SvgPicture), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('Account status action removes retry and opens status', (
        tester,
      ) async {
        final goRouter = buildGoRouter();
        await openFailureSheet(
          tester,
          kind: PublishErrorKind.accountRestricted,
          goRouter: goRouter,
        );
        await tester.tap(
          find.text(l10n.uploadFailureSheetAccountStatusButton),
        );
        await tester.pumpAndSettle();

        verify(
          () => goRouter.push<void>(RoutePaths.accountStatus, extra: true),
        ).called(1);
        verify(
          () => mockBloc.add(
            BackgroundPublishVanished(draftId: 'draft-1'),
          ),
        ).called(1);
        verifyNever(
          () => mockBloc.add(
            BackgroundPublishRetryRequested(draftId: 'draft-1'),
          ),
        );
        expect(
          find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
          findsOneWidget,
        );
      });

      testWidgets(
        'tapping Try Again dispatches $BackgroundPublishRetryRequested',
        (tester) async {
          final upload = BackgroundUpload(
            draft: mockDraft,
            progress: 1,
            result: const PublishError(PublishErrorKind.generic),
          );

          await tester.pumpWidget(buildSubject(upload: upload));
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          await tester.tap(find.text(l10n.uploadFailureSheetTryAgainButton));
          await tester.pumpAndSettle();

          // Sheet should be dismissed
          expect(find.text(l10n.uploadFailureSheetTitle), findsNothing);

          // Snackbar shown
          expect(
            find.text(l10n.uploadFailureSheetRetryingSnackbar),
            findsOneWidget,
          );

          // Bloc received retry event
          verify(
            () => mockBloc.add(
              BackgroundPublishRetryRequested(draftId: 'draft-1'),
            ),
          ).called(1);
        },
      );

      testWidgets(
        'tapping Save to Drafts dispatches $BackgroundPublishVanished',
        (tester) async {
          final upload = BackgroundUpload(
            draft: mockDraft,
            progress: 1,
            result: const PublishError(PublishErrorKind.generic),
          );

          await tester.pumpWidget(buildSubject(upload: upload));
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          await tester.tap(
            find.text(l10n.uploadFailureSheetSaveToDraftsButton),
          );
          await tester.pumpAndSettle();

          // Sheet should be dismissed
          expect(find.text(l10n.uploadFailureSheetTitle), findsNothing);

          // Snackbar shown with View action
          expect(
            find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
            findsOneWidget,
          );
          expect(find.text(l10n.contentWarningView), findsOneWidget);

          // Bloc received vanish event
          verify(
            () => mockBloc.add(BackgroundPublishVanished(draftId: 'draft-1')),
          ).called(1);
        },
      );

      group('snackbar View action', () {
        Future<MockGoRouter> showSavedToDraftsSnackBar(
          WidgetTester tester, {
          required PublishErrorKind kind,
          required String sheetAction,
        }) async {
          final goRouter = buildGoRouter();
          await openFailureSheet(tester, kind: kind, goRouter: goRouter);
          await tester.tap(find.text(sheetAction));
          await tester.pumpAndSettle();
          return goRouter;
        }

        testWidgets('after Save to Drafts opens drafts', (tester) async {
          final goRouter = await showSavedToDraftsSnackBar(
            tester,
            kind: PublishErrorKind.generic,
            sheetAction: l10n.uploadFailureSheetSaveToDraftsButton,
          );

          await tester.tap(find.text(l10n.contentWarningView));
          await tester.pumpAndSettle();

          verify(() => goRouter.push<void>(RoutePaths.libraryDrafts)).called(1);
        });

        testWidgets('after Save to Drafts dismisses the snackbar', (
          tester,
        ) async {
          await showSavedToDraftsSnackBar(
            tester,
            kind: PublishErrorKind.generic,
            sheetAction: l10n.uploadFailureSheetSaveToDraftsButton,
          );
          expect(
            find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
            findsOneWidget,
          );

          await tester.tap(find.text(l10n.contentWarningView));
          await tester.pumpAndSettle();

          expect(
            find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
            findsNothing,
          );
        });

        testWidgets('after Account status opens drafts', (tester) async {
          final goRouter = await showSavedToDraftsSnackBar(
            tester,
            kind: PublishErrorKind.accountRestricted,
            sheetAction: l10n.uploadFailureSheetAccountStatusButton,
          );

          await tester.tap(find.text(l10n.contentWarningView));
          await tester.pumpAndSettle();

          verify(() => goRouter.push<void>(RoutePaths.libraryDrafts)).called(1);
        });

        testWidgets('after Account status dismisses the snackbar', (
          tester,
        ) async {
          await showSavedToDraftsSnackBar(
            tester,
            kind: PublishErrorKind.accountRestricted,
            sheetAction: l10n.uploadFailureSheetAccountStatusButton,
          );
          expect(
            find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
            findsOneWidget,
          );

          await tester.tap(find.text(l10n.contentWarningView));
          await tester.pumpAndSettle();

          expect(
            find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
            findsNothing,
          );
        });
      });

      // GoRouter.push completes only when the pushed route pops. Awaiting it
      // would hold the listener's sheet queue until the user leaves Account
      // status, so later upload failures would get no sheet.
      testWidgets('Account status returns without waiting for the status '
          'screen to close', (tester) async {
        final goRouter = MockGoRouter();
        when(
          () => goRouter.push<void>(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) => Completer<void>().future);
        await openFailureSheet(
          tester,
          kind: PublishErrorKind.accountRestricted,
          goRouter: goRouter,
        );
        var sheetReturned = false;
        unawaited(sheetFuture!.then((_) => sheetReturned = true));

        await tester.tap(find.text(l10n.uploadFailureSheetAccountStatusButton));
        await tester.pumpAndSettle();

        verify(
          () => goRouter.push<void>(RoutePaths.accountStatus, extra: true),
        ).called(1);
        expect(sheetReturned, isTrue);
      });

      // The snackbar outlives the widget that opened the sheet; its action
      // must not resolve anything through that widget's context.
      testWidgets('View opens drafts after the sheet opener is gone', (
        tester,
      ) async {
        final openerVisible = ValueNotifier<bool>(true);
        addTearDown(openerVisible.dispose);
        final goRouter = buildGoRouter();
        await openFailureSheet(
          tester,
          kind: PublishErrorKind.generic,
          goRouter: goRouter,
          openerVisible: openerVisible,
        );
        await tester.tap(find.text(l10n.uploadFailureSheetSaveToDraftsButton));
        await tester.pumpAndSettle();
        openerVisible.value = false;
        await tester.pump();

        await tester.tap(find.text(l10n.contentWarningView));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        verify(() => goRouter.push<void>(RoutePaths.libraryDrafts)).called(1);
      });

      group('when navigation is rejected', () {
        late CrashReporter originalReporter;
        late _RecordingCrashReporter reporter;

        setUp(() {
          originalReporter = detachedFailureReporter;
          reporter = _RecordingCrashReporter();
          detachedFailureReporter = reporter;
        });

        tearDown(() => detachedFailureReporter = originalReporter);

        // The rejection is a StateError, which runDetached forwards to the
        // crash reporter. Reaching it proves the failure was supervised
        // rather than dropped.
        void expectPushFailureReported(WidgetTester tester) {
          expect(tester.takeException(), isNull);
          final report = reporter.reports.single;
          expect(report.reason, equals('runDetached UploadFailureSheet'));
          expect(
            report.error,
            isA<Reportable<Object>>().having(
              (r) => r.unwrap(),
              'unwrap',
              isA<StateError>(),
            ),
          );
        }

        testWidgets('Account status push failure is reported, not left '
            'unhandled', (tester) async {
          final goRouter = buildGoRouter(failingPath: RoutePaths.accountStatus);
          await openFailureSheet(
            tester,
            kind: PublishErrorKind.accountRestricted,
            goRouter: goRouter,
          );

          await tester.tap(
            find.text(l10n.uploadFailureSheetAccountStatusButton),
          );
          await tester.pumpAndSettle();

          verify(
            () => goRouter.push<void>(RoutePaths.accountStatus, extra: true),
          ).called(1);
          expectPushFailureReported(tester);
        });

        testWidgets('View after Save to Drafts failure is reported, not '
            'left unhandled', (tester) async {
          final goRouter = buildGoRouter(failingPath: RoutePaths.libraryDrafts);
          await openFailureSheet(
            tester,
            kind: PublishErrorKind.generic,
            goRouter: goRouter,
          );
          await tester.tap(
            find.text(l10n.uploadFailureSheetSaveToDraftsButton),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text(l10n.contentWarningView));
          await tester.pumpAndSettle();

          verify(() => goRouter.push<void>(RoutePaths.libraryDrafts)).called(1);
          expectPushFailureReported(tester);
        });

        testWidgets('View after Account status failure is reported, not '
            'left unhandled', (tester) async {
          final goRouter = buildGoRouter(failingPath: RoutePaths.libraryDrafts);
          await openFailureSheet(
            tester,
            kind: PublishErrorKind.accountRestricted,
            goRouter: goRouter,
          );
          await tester.tap(
            find.text(l10n.uploadFailureSheetAccountStatusButton),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text(l10n.contentWarningView));
          await tester.pumpAndSettle();

          verify(() => goRouter.push<void>(RoutePaths.libraryDrafts)).called(1);
          expectPushFailureReported(tester);
        });
      });
    });
  });
}
