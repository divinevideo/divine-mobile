// ABOUTME: Widget tests for the upload failure bottom sheet.
// ABOUTME: Verifies retry, save-to-drafts actions and UI rendering.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/publish_error_kind_l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/widgets/upload_failure_sheet.dart';

import '../helpers/go_router.dart';

class _MockDivineVideoDraft extends Mock implements DivineVideoDraft {}

class _MockDivineVideoClip extends Mock implements DivineVideoClip {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

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

  setUp(() {
    mockDraft = _MockDivineVideoDraft();
    mockClip = _MockDivineVideoClip();
    mockBloc = _MockBackgroundPublishBloc();

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
  }) {
    final app = MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<BackgroundPublishBloc>.value(
        value: mockBloc,
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showUploadFailureSheet(context, upload),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );
    return goRouter == null
        ? app
        : MockGoRouterProvider(goRouter: goRouter, child: app);
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
        final goRouter = MockGoRouter();
        when(
          () => goRouter.push<Object?>(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async => null);
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError(PublishErrorKind.accountRestricted),
        );

        await tester.pumpWidget(
          buildSubject(upload: upload, goRouter: goRouter),
        );
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(l10n.uploadFailureSheetAccountStatusButton),
        );
        await tester.pumpAndSettle();

        verify(
          () => goRouter.push<Object?>(RoutePaths.accountStatus, extra: true),
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
    });
  });
}
