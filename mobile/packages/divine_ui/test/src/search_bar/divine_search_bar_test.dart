import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/accessibility_guidelines.dart';

void main() {
  group(DivineSearchBar, () {
    Widget buildTestWidget({
      TextEditingController? controller,
      FocusNode? focusNode,
      String hintText = 'Find something cool...',
      bool isLoading = false,
      bool readOnly = false,
      VoidCallback? onTap,
      Widget? suffixIcon,
      ValueChanged<String>? onChanged,
      ValueChanged<String>? onSubmitted,
      String? semanticIdentifier,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: DivineSearchBar(
                controller: controller,
                focusNode: focusNode,
                hintText: hintText,
                isLoading: isLoading,
                readOnly: readOnly,
                onTap: onTap,
                suffixIcon: suffixIcon,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                semanticIdentifier: semanticIdentifier,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders with default hint text', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Find something cool...'), findsOneWidget);
    });

    testWidgets('exposes semanticIdentifier without hiding the hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(hintText: 'Search...', semanticIdentifier: 'search_x'),
      );

      expect(find.bySemanticsIdentifier('search_x'), findsOneWidget);
      expect(find.text('Search...'), findsOneWidget);
    });

    testWidgets('adds no semantics node when semanticIdentifier is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.bySemanticsIdentifier('search_x'), findsNothing);
    });

    testWidgets('renders with custom hint text', (tester) async {
      await tester.pumpWidget(buildTestWidget(hintText: 'Search videos...'));

      expect(find.text('Search videos...'), findsOneWidget);
    });

    testWidgets('shows search icon when not loading', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows spinner when loading', (tester) async {
      await tester.pumpWidget(buildTestWidget(isLoading: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('accepts text input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildTestWidget(controller: controller));

      await tester.enterText(find.byType(TextField), 'hello');

      expect(controller.text, equals('hello'));
    });

    testWidgets('respects readOnly', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        buildTestWidget(controller: controller, readOnly: true),
      );

      await tester.enterText(find.byType(TextField), 'hello');

      expect(controller.text, isEmpty);
    });

    testWidgets('calls onChanged when text changes', (tester) async {
      String? changedValue;
      await tester.pumpWidget(
        buildTestWidget(onChanged: (value) => changedValue = value),
      );

      await tester.enterText(find.byType(TextField), 'test');

      expect(changedValue, equals('test'));
    });

    testWidgets('uses search as the keyboard action', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final textField = tester.widget<TextField>(find.byType(TextField));

      // The keyboard action should advertise search explicitly so the widget
      // reads as a search field rather than a generic text box.
      expect(textField.textInputAction, TextInputAction.search);
    });

    testWidgets('calls onSubmitted and dismisses focus on submit', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      String? submittedValue;
      await tester.pumpWidget(
        buildTestWidget(
          focusNode: focusNode,
          onSubmitted: (value) => submittedValue = value,
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      final textField = tester.widget<TextField>(find.byType(TextField));
      // Trigger the callback directly to assert our submit/unfocus behavior
      // without depending on platform text-input integration in the test.
      textField.onSubmitted?.call('divine search');
      await tester.pump();

      expect(submittedValue, equals('divine search'));
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('dismisses focus on outside tap', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(buildTestWidget(focusNode: focusNode));

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      final textField = tester.widget<TextField>(find.byType(TextField));
      // Simulate Flutter's tap-outside dispatch so the test stays focused on
      // the widget contract rather than gesture hit-testing details.
      textField.onTapOutside?.call(const PointerDownEvent());
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestWidget(readOnly: true, onTap: () => tapped = true),
      );

      await tester.tap(find.byType(TextField));

      expect(tapped, isTrue);
    });

    testWidgets('renders suffixIcon when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(suffixIcon: const Icon(Icons.filter_list)),
      );

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('does not force suffixIcon to default minimum constraints', (
      tester,
    ) async {
      const suffixKey = Key('suffix');

      await tester.pumpWidget(
        buildTestWidget(
          suffixIcon: const SizedBox(
            key: suffixKey,
            width: 20,
            height: 12,
            child: ColoredBox(color: Colors.red),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(suffixKey)), const Size(20, 12));
    });

    testWidgets('renders no suffix when suffixIcon is null', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.clear), findsNothing);
      expect(find.byIcon(Icons.filter_list), findsNothing);
    });

    group('accessibility', () {
      testWidgets('meets the accessibility guidelines', (tester) async {
        await tester.pumpWidget(buildTestWidget(onChanged: (_) {}));

        await expectMeetsAccessibilityGuidelines(tester);
      });
    });
  });
}
