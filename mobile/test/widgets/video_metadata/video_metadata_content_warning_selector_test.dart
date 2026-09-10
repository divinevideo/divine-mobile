import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_content_warning_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

import '../../helpers/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoMetadataContentWarningSelector, () {
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockGoRouter = MockGoRouter();
      when(mockGoRouter.canPop).thenReturn(true);
      when(() => mockGoRouter.pop<Object?>(any())).thenAnswer((_) async {});
      when(
        () => mockGoRouter.pop<Set<ContentLabel>>(any()),
      ).thenAnswer((_) async {});
    });

    Widget buildWidget({
      VideoEditorProviderState? state,
      _MockVideoEditorNotifier? notifier,
    }) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () =>
                notifier ??
                _MockVideoEditorNotifier(state ?? VideoEditorProviderState()),
          ),
        ],
        child: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataContentWarningSelector()),
          ),
        ),
      );
    }

    testWidgets('renders $VideoMetadataContentWarningSelector', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataContentWarningSelector), findsOneWidget);
    });

    testWidgets('renders $VideoMetadataSelectionTile', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataSelectionTile), findsOneWidget);
    });

    testWidgets('shows empty value when no content warnings are selected', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      expect(find.text(l10n.contentWarningNone), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is EditableText && w.controller.text.isEmpty,
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays content warning label', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DivineTextField &&
              w.labelText == l10n.videoMetadataContentWarningLabel,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows warning name when one content warning is selected', (
      tester,
    ) async {
      final state = VideoEditorProviderState(
        contentWarnings: {ContentLabel.nudity},
      );
      await tester.pumpWidget(buildWidget(state: state));

      expect(find.text('Nudity'), findsOneWidget);
    });

    testWidgets(
      'shows comma-joined names when multiple warnings are selected',
      (tester) async {
        final state = VideoEditorProviderState(
          contentWarnings: {ContentLabel.nudity, ContentLabel.violence},
        );
        await tester.pumpWidget(buildWidget(state: state));

        // The displayed text combines both labels. Since Set iteration order
        // follows enum declaration order, "Nudity" comes before "Violence".
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is EditableText &&
                w.controller.text.contains('Nudity') &&
                w.controller.text.contains('Violence'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('opens bottom sheet when tapped', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoMetadataSelectContentWarningsSemanticLabel,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.videoMetadataContentWarnings), findsOneWidget);
    });

    testWidgets('bottom sheet shows all ContentLabel options', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(buildWidget());

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoMetadataSelectContentWarningsSemanticLabel,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nudity'), findsOneWidget);
      expect(find.text('Violence'), findsOneWidget);
      expect(find.text('Alcohol'), findsOneWidget);
    });

    testWidgets('bottom sheet header describes cancel and apply actions', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoMetadataSelectContentWarningsSemanticLabel,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          l10n.videoMetadataContentWarningsPickerCancelSemanticLabel,
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          l10n.videoMetadataContentWarningsPickerConfirmSemanticLabel,
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping confirm button pops with selected labels', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(buildWidget());

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoMetadataSelectContentWarningsSemanticLabel,
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Tap "Nudity" in the list.
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Nudity'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the check (confirm) icon button.
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.icon == DivineIconName.check,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The bottom sheet pops via go_router with the selected labels.
      verify(() => mockGoRouter.pop<Set<ContentLabel>>(any())).called(1);
    });

    testWidgets('can clear all selected content warnings', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;

      final state = VideoEditorProviderState(
        contentWarnings: {ContentLabel.nudity},
      );
      await tester.pumpWidget(buildWidget(state: state));

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoMetadataSelectContentWarningsSemanticLabel,
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Nudity'),
        ),
      );
      await tester.pumpAndSettle();

      final confirmButton = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byWidgetPredicate(
          (w) => w is DivineIconButton && w.icon == DivineIconName.check,
        ),
      );
      expect(
        tester.widget<DivineIconButton>(confirmButton).onPressed,
        isNotNull,
      );

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      verify(
        () => mockGoRouter.pop<Set<ContentLabel>>(<ContentLabel>{}),
      ).called(1);
    });

    testWidgets('announces each option as a checkbox with its checked state', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(buildWidget());

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoMetadataSelectContentWarningsSemanticLabel,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Nudity')),
        isSemantics(
          // The label rides up from the child Text rather than being repeated
          // in `label:`, so it cannot drift from the rendered string.
          label: 'Nudity',
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.text('Nudity'));
      await tester.pump();

      expect(
        tester.getSemantics(find.text('Nudity')),
        isSemantics(label: 'Nudity', hasCheckedState: true, isChecked: true),
      );

      handle.dispose();
    });

    testWidgets('tapping an option toggles its checkbox state', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(buildWidget());

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoMetadataSelectContentWarningsSemanticLabel,
        ),
      );
      await tester.pumpAndSettle();

      final unchecked = find.byWidgetPredicate(
        (w) =>
            w is DivineSpriteCheckbox &&
            w.state == DivineCheckboxState.unselected,
      );
      expect(unchecked, findsWidgets);

      // Tap the first label ("Nudity").
      await tester.tap(find.text('Nudity'));
      await tester.pump();

      final checked = find.byWidgetPredicate(
        (w) =>
            w is DivineSpriteCheckbox &&
            w.state == DivineCheckboxState.selected,
      );
      expect(checked, findsOneWidget);
    });
  });
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void setContentWarnings(Set<ContentLabel> labels) {
    state = state.copyWith(contentWarnings: Set.of(labels));
  }
}
