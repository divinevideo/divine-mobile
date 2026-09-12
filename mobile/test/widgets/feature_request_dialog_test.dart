// ABOUTME: Widget tests for the feature request support flow
// ABOUTME: Tests UI rendering, user interaction, and form validation

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/feature_request/feature_request_cubit.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';
import 'package:openvine/widgets/support_public_submission_notice.dart';

import '../helpers/keyboard_content_insertion.dart';

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

Future<bool> _submitSucceeds({
  required String subject,
  required String description,
  required String usefulness,
  required String whenToUse,
  String? userPubkey,
}) async => true;

Future<bool> _submitFails({
  required String subject,
  required String description,
  required String usefulness,
  required String whenToUse,
  String? userPubkey,
}) async => false;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('feature request flow', () {
    Future<void> openFlow(
      WidgetTester tester, {
      SubmitFeatureRequestAction submitFeatureRequest = _submitFails,
    }) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => DivineButton(
                  label: 'Open',
                  onPressed: () => context.push(FeatureRequestScreen.path),
                ),
              ),
            ),
          ),
          GoRoute(
            path: FeatureRequestScreen.path,
            builder: (context, state) => FeatureRequestScreen(
              userPubkey: _pubkeyHex,
              submitFeatureRequest: submitFeatureRequest,
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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('caps every pasted free-text field', (tester) async {
      // Same cap, same reason, same form family as the bug report screen:
      // sanitization runs on the main isolate and its cost scales with field
      // size, so an uncapped paste freezes submission. Every field is asserted
      // individually - a loop over only the first one passes with the other
      // three uncapped.
      await openFlow(tester);

      const overflow = 500;
      final expectedCaps = <int, int>{
        0: BugReportConfig.maxSubjectLength,
        1: BugReportConfig.maxFreeTextFieldLength,
        2: BugReportConfig.maxFreeTextFieldLength,
        3: BugReportConfig.maxFreeTextFieldLength,
      };

      for (final entry in expectedCaps.entries) {
        final field = find.byType(TextField).at(entry.key);
        await tester.enterText(field, 'a' * (entry.value + overflow));
        await tester.pump();

        expect(
          tester.widget<TextField>(field).controller!.text.length,
          entry.value,
          reason: 'field ${entry.key} is not capped',
        );
      }
    });

    testWidgets('says so when a paste hit the cap', (tester) async {
      // The formatter drops the tail of a long paste, and that tail can be the
      // detail the user meant to send. Silence would look like acceptance.
      await openFlow(tester);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.supportFieldLimitReached), findsNothing);

      await tester.enterText(
        find.byType(TextField).at(1),
        'a' * (BugReportConfig.maxFreeTextFieldLength + 500),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportFieldLimitReached), findsOneWidget);
    });

    testWidgets('gives all fields feature-request image insertion feedback', (
      tester,
    ) async {
      await openFlow(tester);

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, hasLength(4));
      expect(
        fields.every(
          (field) => field.contentInsertionConfiguration != null,
        ),
        isTrue,
      );

      const requesterWords = 'Let people save favorite search filters.';
      final description = find.byType(TextField).at(1);
      await tester.tap(description);
      await tester.enterText(description, requesterWords);
      await commitKeyboardImage(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.featureRequestImageInsertionRejected),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(description).controller!.text,
        requesterWords,
      );
    });

    DivineButton buttonFor(WidgetTester tester, String label) {
      return tester.widget<DivineButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(DivineButton),
        ),
      );
    }

    Future<void> fillRequiredFields(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'Dark mode toggle');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Let me switch themes from settings',
      );
      await tester.pump();
    }

    testWidgets('displays public submission warning and form fields', (
      tester,
    ) async {
      await openFlow(tester);

      expect(find.text(l10n.supportRequestFeature), findsOneWidget);
      expect(find.text(l10n.supportPublicSubmissionTitle), findsOneWidget);
      expect(find.text(l10n.supportPublicSubmissionMessage), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text(l10n.supportSubjectRequiredLabel), findsOneWidget);
      expect(
        find.text(l10n.featureRequestDescriptionRequiredLabel),
        findsOneWidget,
      );
      expect(find.text(l10n.featureRequestUsefulnessLabel), findsOneWidget);
      expect(find.text(l10n.featureRequestWhenLabel), findsOneWidget);
    });

    testWidgets('renders the public submission warning above the form', (
      tester,
    ) async {
      await openFlow(tester);

      // The warning only works if it is read before anything is typed, so
      // pin it above the first field rather than merely present.
      final warning = tester.getTopLeft(
        find.byType(SupportPublicSubmissionNotice),
      );
      final subject = tester.getTopLeft(
        find.text(l10n.supportSubjectRequiredLabel),
      );
      expect(warning.dy, lessThan(subject.dy));
    });

    testWidgets('keeps actions out of the scrollable form', (tester) async {
      await openFlow(tester);

      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text(l10n.featureRequestSendRequest),
        ),
        findsNothing,
      );
    });

    testWidgets('does not discard typed content when the form is dragged', (
      tester,
    ) async {
      await openFlow(tester);
      await fillRequiredFields(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportRequestFeature), findsOneWidget);
      expect(find.text('Dark mode toggle'), findsOneWidget);
      expect(find.text('Let me switch themes from settings'), findsOneWidget);
    });

    testWidgets('advances from the subject to the description', (tester) async {
      await openFlow(tester);

      final subject = tester.widget<TextField>(find.byType(TextField).first);
      expect(subject.textInputAction, TextInputAction.next);

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      final fields = tester.widgetList<EditableText>(find.byType(EditableText));
      expect(fields.elementAt(1).focusNode.hasFocus, isTrue);
      expect(fields.first.focusNode.hasFocus, isFalse);
    });

    testWidgets('disables Send button when required fields are empty', (
      tester,
    ) async {
      await openFlow(tester);

      expect(
        buttonFor(tester, l10n.featureRequestSendRequest).onPressed,
        isNull,
      );
    });

    testWidgets('enables Send button when required fields are filled', (
      tester,
    ) async {
      await openFlow(tester);
      await fillRequiredFields(tester);

      expect(
        buttonFor(tester, l10n.featureRequestSendRequest).onPressed,
        isNotNull,
      );
    });

    testWidgets('shows loading indicator while submitting', (tester) async {
      final completer = Completer<bool>();

      Future<bool> submitWaits({
        required String subject,
        required String description,
        required String usefulness,
        required String whenToUse,
        String? userPubkey,
      }) {
        return completer.future;
      }

      await openFlow(tester, submitFeatureRequest: submitWaits);
      await fillRequiredFields(tester);

      await tester.tap(find.text(l10n.featureRequestSendRequest));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(false);
      await tester.pumpAndSettle();
    });

    testWidgets('keeps the flow open and reports why sending failed', (
      tester,
    ) async {
      await openFlow(tester);
      await fillRequiredFields(tester);

      await tester.tap(find.text(l10n.featureRequestSendRequest));
      await tester.pumpAndSettle();

      expect(find.text(l10n.featureRequestSendFailed), findsOneWidget);
      expect(find.text(l10n.supportRequestFeature), findsOneWidget);
    });

    testWidgets('closes and confirms via snackbar on success', (tester) async {
      await openFlow(tester, submitFeatureRequest: _submitSucceeds);
      await fillRequiredFields(tester);

      await tester.tap(find.text(l10n.featureRequestSendRequest));
      await tester.pumpAndSettle();

      expect(find.text(l10n.featureRequestSendRequest), findsNothing);
      expect(find.text(l10n.featureRequestSuccessMessage), findsOneWidget);
    });

    testWidgets('closes the flow on Cancel', (tester) async {
      await openFlow(tester);

      expect(find.text(l10n.supportRequestFeature), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportRequestFeature), findsNothing);
    });
  });
}
