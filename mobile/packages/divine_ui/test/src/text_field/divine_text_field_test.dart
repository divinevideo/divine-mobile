import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('DivineTextField', () {
    Widget buildTestWidget({
      String? labelText,
      TextEditingController? controller,
      FocusNode? focusNode,
      bool readOnly = false,
      bool obscureText = false,
      bool enabled = true,
      int? maxLength,
      int? minLines,
      int? maxLines,
      TextInputType? keyboardType,
      TextInputAction? textInputAction,
      ValueChanged<String>? onChanged,
      ValueChanged<String>? onSubmitted,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: DivineTextField(
            labelText: labelText,
            controller: controller,
            focusNode: focusNode,
            readOnly: readOnly,
            obscureText: obscureText,
            enabled: enabled,
            maxLength: maxLength,
            minLines: minLines,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('renders with label text', (tester) async {
      await tester.pumpWidget(buildTestWidget(labelText: 'Username'));

      expect(find.text('Username'), findsOneWidget);
    });

    testWidgets('renders without label text', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('accepts text input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildTestWidget(controller: controller));

      await tester.enterText(find.byType(TextField), 'Hello World');
      expect(controller.text, 'Hello World');
    });

    testWidgets('calls onChanged when text changes', (tester) async {
      String? changedValue;
      await tester.pumpWidget(
        buildTestWidget(onChanged: (value) => changedValue = value),
      );

      await tester.enterText(find.byType(TextField), 'Test');
      expect(changedValue, 'Test');
    });

    testWidgets('calls onSubmitted when submitted', (tester) async {
      String? submittedValue;
      await tester.pumpWidget(
        buildTestWidget(onSubmitted: (value) => submittedValue = value),
      );

      await tester.enterText(find.byType(TextField), 'Submit Test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submittedValue, 'Submit Test');
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTestWidget(onTap: () => tapped = true));

      await tester.tap(find.byType(TextField));
      expect(tapped, isTrue);
    });

    testWidgets('respects readOnly property', (tester) async {
      final controller = TextEditingController(text: 'Initial');
      await tester.pumpWidget(
        buildTestWidget(controller: controller, readOnly: true),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.readOnly, isTrue);
    });

    testWidgets('respects enabled property', (tester) async {
      await tester.pumpWidget(buildTestWidget(enabled: false));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('respects obscureText for passwords', (tester) async {
      await tester.pumpWidget(buildTestWidget(obscureText: true, maxLines: 1));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('respects maxLength property', (tester) async {
      await tester.pumpWidget(buildTestWidget(maxLength: 10));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLength, 10);
    });

    testWidgets('respects minLines and maxLines', (tester) async {
      await tester.pumpWidget(buildTestWidget(minLines: 2, maxLines: 5));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, 2);
      expect(textField.maxLines, 5);
    });

    testWidgets('respects keyboardType property', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(keyboardType: TextInputType.emailAddress),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('respects textInputAction property', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(textInputAction: TextInputAction.search),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textInputAction, TextInputAction.search);
    });

    testWidgets('forwards content insertion configuration', (tester) async {
      final configuration = ContentInsertionConfiguration(
        onContentInserted: (_) {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(
            body: DivineTextField(
              contentInsertionConfiguration: configuration,
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .contentInsertionConfiguration,
        same(configuration),
      );
    });

    testWidgets('does not advertise rich content by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .contentInsertionConfiguration,
        isNull,
      );
    });

    testWidgets('uses focus node when provided', (tester) async {
      final focusNode = FocusNode();
      await tester.pumpWidget(buildTestWidget(focusNode: focusNode));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode, focusNode);

      focusNode.dispose();
    });

    testWidgets('uses controller when provided', (tester) async {
      final controller = TextEditingController(text: 'Initial Value');
      await tester.pumpWidget(buildTestWidget(controller: controller));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller, controller);
      expect(controller.text, 'Initial Value');

      controller.dispose();
    });

    testWidgets('is not filled', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration!.filled, isFalse);
    });

    testWidgets('floating label changes color when focused', (tester) async {
      final focusNode = FocusNode();
      await tester.pumpWidget(
        buildTestWidget(
          labelText: 'Test Label',
          focusNode: focusNode,
        ),
      );

      // Get the floating label style and resolve it for unfocused state
      final textField = tester.widget<TextField>(find.byType(TextField));
      final floatingStyle = textField.decoration!.floatingLabelStyle;
      expect(floatingStyle, isA<WidgetStateTextStyle>());

      final unfocusedStyle = (floatingStyle! as WidgetStateTextStyle).resolve(
        <WidgetState>{},
      );
      expect(unfocusedStyle.color, VineTheme.onSurfaceVariant);

      // Resolve for focused state
      final focusedStyle = (floatingStyle as WidgetStateTextStyle).resolve(
        <WidgetState>{WidgetState.focused},
      );
      expect(focusedStyle.color, VineTheme.primary);

      focusNode.dispose();
    });

    group('primaryWhenFilled', () {
      Widget buildField({
        required TextEditingController controller,
        required bool primaryWhenFilled,
      }) {
        return MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(
            body: DivineTextField(
              labelText: 'Test Label',
              controller: controller,
              primaryWhenFilled: primaryWhenFilled,
            ),
          ),
        );
      }

      testWidgets(
        'unfocused floating label uses primary color when filled',
        (tester) async {
          final controller = TextEditingController(text: 'has content');
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            buildField(controller: controller, primaryWhenFilled: true),
          );

          final textField = tester.widget<TextField>(find.byType(TextField));
          final floatingStyle =
              textField.decoration!.floatingLabelStyle! as WidgetStateTextStyle;
          final unfocusedStyle = floatingStyle.resolve(<WidgetState>{});

          expect(unfocusedStyle.color, VineTheme.primary);
        },
      );

      testWidgets(
        'unfocused floating label uses variant color when empty',
        (tester) async {
          final controller = TextEditingController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            buildField(controller: controller, primaryWhenFilled: true),
          );

          final textField = tester.widget<TextField>(find.byType(TextField));
          final floatingStyle =
              textField.decoration!.floatingLabelStyle! as WidgetStateTextStyle;
          final unfocusedStyle = floatingStyle.resolve(<WidgetState>{});

          expect(unfocusedStyle.color, VineTheme.onSurfaceVariant);
        },
      );

      testWidgets(
        'unfocused floating label uses variant color when filled but '
        'primaryWhenFilled is false',
        (tester) async {
          final controller = TextEditingController(text: 'has content');
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            buildField(controller: controller, primaryWhenFilled: false),
          );

          final textField = tester.widget<TextField>(find.byType(TextField));
          final floatingStyle =
              textField.decoration!.floatingLabelStyle! as WidgetStateTextStyle;
          final unfocusedStyle = floatingStyle.resolve(<WidgetState>{});

          expect(unfocusedStyle.color, VineTheme.onSurfaceVariant);
        },
      );

      testWidgets(
        'defaults to false (no primary color when filled)',
        (tester) async {
          final controller = TextEditingController(text: 'has content');
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              theme: VineTheme.theme,
              home: Scaffold(
                body: DivineTextField(
                  labelText: 'Test Label',
                  controller: controller,
                ),
              ),
            ),
          );

          final textField = tester.widget<TextField>(find.byType(TextField));
          final floatingStyle =
              textField.decoration!.floatingLabelStyle! as WidgetStateTextStyle;
          final unfocusedStyle = floatingStyle.resolve(<WidgetState>{});

          expect(unfocusedStyle.color, VineTheme.onSurfaceVariant);
        },
      );
    });

    group('spellCheckConfiguration', () {
      test('default config is enabled and carries a spell check service', () {
        final config = DivineTextField.defaultSpellCheckConfiguration;

        expect(config, isNot(const SpellCheckConfiguration.disabled()));
        expect(config.spellCheckService, isNotNull);
      });

      testWidgets('enables spell check by default', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: DivineTextField()),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.spellCheckConfiguration,
          DivineTextField.defaultSpellCheckConfiguration,
        );
      });

      testWidgets('passes a provided config through unchanged', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DivineTextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.spellCheckConfiguration,
          const SpellCheckConfiguration.disabled(),
        );
      });
    });

    group('defaultContentPadding', () {
      test('exposes a 16px-all default for overlay alignment', () {
        expect(
          DivineTextField.defaultContentPadding,
          const EdgeInsets.all(16),
        );
      });
    });

    group('filled', () {
      InputDecoration decorationOf(WidgetTester tester) =>
          tester.widget<TextField>(find.byType(TextField)).decoration!;

      testWidgets('paints no surface by default', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(body: DivineTextField()),
          ),
        );

        final decoration = decorationOf(tester);
        expect(decoration.filled, isFalse);
        expect(decoration.fillColor, isNull);
        expect(decoration.border, InputBorder.none);
      });

      testWidgets('falls back to containerLow when filled', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(body: DivineTextField(filled: true)),
          ),
        );

        final decoration = decorationOf(tester);
        expect(decoration.filled, isTrue);
        expect(decoration.fillColor, VineTheme.darkColors.containerLow);
      });

      testWidgets('prefers an explicit fillColor', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(
              body: DivineTextField(filled: true, fillColor: VineTheme.error),
            ),
          ),
        );

        expect(decorationOf(tester).fillColor, VineTheme.error);
      });

      testWidgets('rounds the fill on every border state', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(body: DivineTextField(filled: true)),
          ),
        );

        // Material squares off the corners unless each border state carries
        // the radius, so all three must be the same rounded border.
        final decoration = decorationOf(tester);
        final expected = UnderlineInputBorder(
          borderRadius: BorderRadius.circular(
            DivineTextField.defaultFillBorderRadius,
          ),
          borderSide: BorderSide.none,
        );
        expect(decoration.border, expected);
        expect(decoration.enabledBorder, expected);
        expect(decoration.focusedBorder, expected);
      });

      testWidgets('rounds the fill to a caller-supplied radius', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(
              body: DivineTextField(filled: true, fillBorderRadius: 24),
            ),
          ),
        );

        final decoration = decorationOf(tester);
        final expected = UnderlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        );
        expect(decoration.border, expected);
        expect(decoration.enabledBorder, expected);
        expect(decoration.focusedBorder, expected);
      });

      testWidgets('keeps a floating label inside the fill', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(
              body: DivineTextField(filled: true, labelText: 'Relay'),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'wss://relay.test');
        await tester.pumpAndSettle();

        // An outline border notches the floating label onto the top edge,
        // which strands it above a borderless fill. The fill must contain it.
        final fill = tester.getRect(find.byType(TextField));
        final label = tester.getRect(find.text('Relay'));
        expect(label.top, greaterThanOrEqualTo(fill.top));
        expect(label.bottom, lessThanOrEqualTo(fill.bottom));
      });
    });

    group('suffixIcon', () {
      testWidgets('renders the suffix inside the field', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: DivineTextField(
                suffixIcon: DivineIconButton(
                  icon: DivineIconName.clipboard,
                  onPressed: () => pressed = true,
                ),
              ),
            ),
          ),
        );

        expect(
          find.descendant(
            of: find.byType(TextField),
            matching: find.byType(DivineIconButton),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byType(DivineIconButton));
        expect(pressed, isTrue);
      });

      testWidgets('leaves the slot empty when omitted', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(body: DivineTextField()),
          ),
        );

        final decoration = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        expect(decoration.suffixIcon, isNull);
      });
    });

    group('hint and helper', () {
      testWidgets('shows the helper text and the hint once the label floats', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(
              body: DivineTextField(
                labelText: 'Subject *',
                hintText: 'Brief summary of the issue',
                helperText: 'Required',
                autofocus: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Required'), findsOneWidget);
        expect(find.text('Brief summary of the issue'), findsOneWidget);
      });

      testWidgets('lets a long helper wrap onto helperMaxLines', (
        tester,
      ) async {
        const helper =
            'Part of the badge address, so it stays put once it exists.';
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(
              body: SizedBox(
                width: 220,
                child: DivineTextField(
                  labelText: 'Identifier',
                  helperText: helper,
                  helperMaxLines: 2,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final decoration = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        expect(decoration.helperMaxLines, equals(2));
        expect(find.text(helper), findsOneWidget);
      });

      testWidgets('leaves helperMaxLines unset by default', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(
              body: DivineTextField(helperText: 'Required'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final decoration = tester
            .widget<TextField>(find.byType(TextField))
            .decoration!;
        expect(decoration.helperMaxLines, isNull);
      });
    });

    group('affixes', () {
      InputDecoration decorationOf(WidgetTester tester) =>
          tester.widget<TextField>(find.byType(TextField)).decoration!;

      testWidgets('pins muted text around the input', (tester) async {
        late Color muted;
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  muted = context.vineColors.onSurfaceMuted;
                  return const DivineTextField(
                    prefixText: '@',
                    suffixText: '.divine.video',
                  );
                },
              ),
            ),
          ),
        );

        final decoration = decorationOf(tester);
        expect(decoration.prefixText, '@');
        expect(decoration.suffixText, '.divine.video');
        expect(decoration.prefixStyle?.color, muted);
        expect(decoration.suffixStyle?.color, muted);
      });

      testWidgets('leaves both slots empty when omitted', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(body: DivineTextField()),
          ),
        );

        final decoration = decorationOf(tester);
        expect(decoration.prefixText, isNull);
        expect(decoration.suffixText, isNull);
      });
    });
  });
}
