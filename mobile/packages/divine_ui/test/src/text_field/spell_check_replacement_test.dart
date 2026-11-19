import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('spell-check replacement', () {
    Future<EditableTextState> pumpField(
      WidgetTester tester,
      TextEditingController controller, {
      SpellCheckService? service,
    }) async {
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(
            body: DivineTextField(
              controller: controller,
              spellCheckConfiguration: DivineTextField
                  .defaultSpellCheckConfiguration
                  .copyWith(spellCheckService: service),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.state<EditableTextState>(find.byType(EditableText));
    }

    CupertinoSpellCheckSuggestionsToolbar toolbar(EditableTextState state) {
      final builder =
          state
              .widget
              .spellCheckConfiguration!
              .spellCheckSuggestionsToolbarBuilder ??
          TextField.defaultSpellCheckSuggestionsToolbarBuilder;
      return builder(state.context, state)
          as CupertinoSpellCheckSuggestionsToolbar;
    }

    void seedResults(EditableTextState state) {
      state.spellCheckResults = const SpellCheckResults('hello wrld', [
        SuggestionSpan(TextRange(start: 6, end: 10), ['world']),
      ]);
    }

    testWidgets('replaces a valid suggestion and moves the caret', (
      tester,
    ) async {
      final controller = TextEditingController.fromValue(
        const TextEditingValue(
          text: 'hello wrld',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      final state = await pumpField(tester, controller);
      seedResults(state);
      toolbar(state).buttonItems.single.onPressed!();
      expect(controller.text, 'hello world');
      expect(controller.selection, const TextSelection.collapsed(offset: 11));
      await tester.pump();
    }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

    for (final changedText in ['hi', 'hello frog']) {
      testWidgets(
        'ignores a retained suggestion after changing to $changedText',
        (
          tester,
        ) async {
          final controller = TextEditingController.fromValue(
            const TextEditingValue(
              text: 'hello wrld',
              selection: TextSelection.collapsed(offset: 8),
            ),
          );
          final state = await pumpField(tester, controller);
          seedResults(state);
          final replace = toolbar(state).buttonItems.single.onPressed!;
          controller.text = changedText;
          expect(replace, returnsNormally);
          expect(controller.text, changedText);
          await tester.pump();
        },
        variant: const TargetPlatformVariant({TargetPlatform.iOS}),
      );
    }

    testWidgets('keeps Android suggestion replacement working', (tester) async {
      final controller = TextEditingController.fromValue(
        const TextEditingValue(
          text: 'hello wrld',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      final state = await pumpField(tester, controller);
      seedResults(state);
      final builder = state
          .widget
          .spellCheckConfiguration!
          .spellCheckSuggestionsToolbarBuilder!;
      final menu =
          builder(state.context, state) as SpellCheckSuggestionsToolbar;
      menu.buttonItems.firstWhere((item) => item.label == 'world').onPressed!();
      expect(controller.text, 'hello world');
      await tester.pump();
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('keeps the disabled no-replacements item', (tester) async {
      final controller = TextEditingController.fromValue(
        const TextEditingValue(
          text: 'hello wrld',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      final state = await pumpField(tester, controller);
      state.spellCheckResults = const SpellCheckResults('hello wrld', [
        SuggestionSpan(TextRange(start: 6, end: 10), []),
      ]);
      final item = toolbar(state).buttonItems.single;
      expect(item.label, 'No Replacements Found');
      expect(item.onPressed, isNull);
    }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

    testWidgets('ignores a retained callback after the field is removed', (
      tester,
    ) async {
      final controller = TextEditingController.fromValue(
        const TextEditingValue(
          text: 'hello wrld',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      final state = await pumpField(tester, controller);
      seedResults(state);
      final replace = toolbar(state).buttonItems.single.onPressed!;
      await tester.pumpWidget(const SizedBox.shrink());
      expect(replace, returnsNormally);
      expect(controller.text, 'hello wrld');
    }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

    testWidgets('does not offer delayed results for older text', (
      tester,
    ) async {
      final service = _DelayedSpellCheckService();
      final controller = TextEditingController();
      final state = await pumpField(tester, controller, service: service);
      await tester.enterText(find.byType(TextField), 'hello wrld');
      expect(service.requestedText, 'hello wrld');
      controller.value = const TextEditingValue(
        text: 'hello frog',
        selection: TextSelection.collapsed(offset: 8),
      );
      service.result.complete(const [
        SuggestionSpan(TextRange(start: 6, end: 10), ['world']),
      ]);
      await tester.pump();
      expect(state.spellCheckResults?.spellCheckedText, 'hello wrld');
      expect(toolbar(state).buttonItems, isEmpty);
      expect(controller.text, 'hello frog');
    }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
  });
}

class _DelayedSpellCheckService implements SpellCheckService {
  final result = Completer<List<SuggestionSpan>?>();
  String? requestedText;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) {
    requestedText = text;
    return result.future;
  }
}
