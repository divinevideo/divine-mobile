// ABOUTME: Widget tests for ContentFiltersScreen — verifies the loaded
// ABOUTME: category controls, the age-gate banner, and that tapping a segment
// ABOUTME: persists the preference through ContentFilterService.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';

import '../helpers/scroll.dart';
import '../helpers/test_provider_overrides.dart';

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

void main() {
  setUpAll(() {
    registerFallbackValue(ContentLabel.nudity);
    registerFallbackValue(ContentFilterPreference.show);
  });

  group(ContentFiltersScreen, () {
    late _MockContentFilterService filterService;
    late _MockAgeVerificationService ageService;

    setUp(() {
      filterService = _MockContentFilterService();
      ageService = _MockAgeVerificationService();
      when(filterService.initialize).thenAnswer((_) async {});
      when(
        () => filterService.getPreference(any()),
      ).thenReturn(ContentFilterPreference.show);
      when(
        () => filterService.setPreference(any(), any()),
      ).thenAnswer((_) async {});
      when(ageService.initialize).thenAnswer((_) async {});
      when(() => ageService.isAdultContentVerified).thenReturn(false);
    });

    Widget buildSubject() => testMaterialApp(
      additionalOverrides: [
        contentFilterServiceProvider.overrideWithValue(filterService),
        ageVerificationServiceProvider.overrideWithValue(ageService),
      ],
      home: const ContentFiltersScreen(),
    );

    AppLocalizations l10nOf(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(ContentFiltersScreen)));

    testWidgets('renders the category groups once loaded', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      expect(find.text(l10n.contentFiltersAdultContent), findsOneWidget);
      expect(find.text(l10n.contentFiltersViolenceGore), findsNothing);
      expect(find.text(l10n.contentFiltersSubstances), findsOneWidget);
      expect(find.text(l10n.contentFiltersOther), findsOneWidget);
    });

    testWidgets('hides categories that are always filtered out', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      expect(find.text(l10n.contentLabelPornography), findsNothing);
      expect(find.text(l10n.contentLabelGraphicMedia), findsNothing);
      expect(find.text(l10n.contentLabelViolence), findsNothing);
      expect(find.text(l10n.contentLabelSelfHarm), findsNothing);
      expect(find.text(l10n.contentLabelDrugUse), findsNothing);
      expect(find.text(l10n.contentLabelHateSpeech), findsNothing);
      expect(find.text(l10n.contentLabelHarassment), findsNothing);
      expect(find.text(l10n.contentLabelAiGenerated), findsNothing);
      expect(find.text(l10n.contentLabelDeepfake), findsNothing);
      expect(find.text(l10n.contentLabelSpam), findsNothing);
      expect(find.text(l10n.contentLabelScam), findsNothing);
    });

    testWidgets('moves gambling under Other while substances stay visible', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      expect(find.text(l10n.contentLabelAlcohol), findsOneWidget);
      expect(find.text(l10n.contentLabelTobacco), findsOneWidget);

      await tester.scrollUntilVisible(find.text(l10n.contentLabelGambling), 80);
      await tester.pumpAndSettle();

      expect(find.text(l10n.contentFiltersOther), findsOneWidget);
      expect(find.text(l10n.contentLabelGambling), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(l10n.contentFiltersOther)).dy,
        lessThan(tester.getTopLeft(find.text(l10n.contentLabelGambling)).dy),
      );
    });

    testWidgets('shows the age-gate banner when not verified', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(l10nOf(tester).contentFiltersAgeGateMessage),
        findsOneWidget,
      );
    });

    testWidgets(
      'locks alcohol tobacco profanity and gambling when not verified',
      (tester) async {
        when(
          () => filterService.getPreference(ContentLabel.alcohol),
        ).thenReturn(ContentFilterPreference.hide);
        when(
          () => filterService.getPreference(ContentLabel.tobacco),
        ).thenReturn(ContentFilterPreference.hide);
        when(
          () => filterService.getPreference(ContentLabel.profanity),
        ).thenReturn(ContentFilterPreference.hide);
        when(
          () => filterService.getPreference(ContentLabel.gambling),
        ).thenReturn(ContentFilterPreference.hide);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        Future<void> tapShowFor(ContentLabel label) async {
          final row = find.byKey(ValueKey('content-filter-${label.value}'));
          final showButton = find.descendant(
            of: row,
            matching: find.text(l10nOf(tester).contentFiltersShow),
          );
          await scrollUntilTappable(tester, row, 80);
          await tester.tap(showButton);
          await tester.pump();
        }

        await tapShowFor(ContentLabel.alcohol);
        await tapShowFor(ContentLabel.tobacco);
        await tapShowFor(ContentLabel.profanity);
        await tapShowFor(ContentLabel.gambling);

        verifyNever(() => filterService.setPreference(any(), any()));
      },
    );

    testWidgets('hides the age-gate banner when verified', (tester) async {
      when(() => ageService.isAdultContentVerified).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(l10nOf(tester).contentFiltersAgeGateMessage),
        findsNothing,
      );
    });

    testWidgets('tapping a segment persists the preference via the service', (
      tester,
    ) async {
      when(() => ageService.isAdultContentVerified).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10nOf(tester).contentFiltersWarn).first);
      await tester.pump();

      verify(
        () => filterService.setPreference(any(), ContentFilterPreference.warn),
      ).called(1);
    });

    testWidgets('announces each filter segment as a selectable button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      when(() => ageService.isAdultContentVerified).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      expect(
        tester.getSemantics(find.text(l10n.contentFiltersShow).first),
        isSemantics(
          // The label rides up from the child Text rather than being repeated
          // in `label:`, so it cannot drift from the rendered string.
          label: l10n.contentFiltersShow,
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('announces a locked segment as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      when(() => ageService.isAdultContentVerified).thenReturn(false);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      expect(
        tester.getSemantics(find.text(l10n.contentFiltersWarn).first),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });
  });
}
