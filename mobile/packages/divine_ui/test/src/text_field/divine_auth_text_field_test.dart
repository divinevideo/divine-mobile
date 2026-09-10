import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/accessibility_guidelines.dart';

void main() {
  group(DivineAuthTextField, () {
    Widget buildTestWidget({
      String label = 'Test Label',
      TextEditingController? controller,
      FocusNode? focusNode,
      bool readOnly = false,
      bool obscureText = false,
      bool enabled = true,
      TextInputType? keyboardType,
      TextInputAction? textInputAction,
      ValueChanged<String>? onChanged,
      ValueChanged<String>? onSubmitted,
      VoidCallback? onTap,
      String? errorText,
      FormFieldValidator<String>? validator,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: DivineAuthTextField(
                label: label,
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
                obscureText: obscureText,
                enabled: enabled,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                onTap: onTap,
                errorText: errorText,
                validator: validator,
              ),
            ),
          ),
        ),
      );
    }

    group('accessibility', () {
      testWidgets('password field meets the accessibility guidelines', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(label: 'Password', obscureText: true),
        );

        await expectMeetsAccessibilityGuidelines(tester);
      });

      testWidgets('text field meets the accessibility guidelines', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(label: 'Email'));

        await expectMeetsAccessibilityGuidelines(tester);
      });
    });

    group('renders', () {
      testWidgets('renders with label text', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(label: 'Username'),
        );

        expect(find.text('Username'), findsOneWidget);
      });

      testWidgets('renders with container styling', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        final container = tester.widget<Container>(
          find.ancestor(
            of: find.byType(TextField),
            matching: find.byType(Container),
          ),
        );
        final decoration = container.decoration as BoxDecoration?;
        expect(
          decoration?.color,
          equals(VineTheme.surfaceContainer),
        );
        expect(
          decoration?.borderRadius,
          equals(BorderRadius.circular(24)),
        );
      });

      testWidgets(
        'renders visibility toggle when obscureText is true',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(obscureText: true),
          );

          expect(find.byType(DivineIcon), findsOneWidget);
        },
      );

      testWidgets('dims the visibility toggle while the field is empty', (
        tester,
      ) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          buildTestWidget(obscureText: true, controller: controller),
        );

        expect(
          tester.widget<DivineIcon>(find.byType(DivineIcon)).color,
          VineTheme.darkColors.onSurfaceMuted,
        );

        controller.text = 'hunter2';
        await tester.pump();

        expect(
          tester.widget<DivineIcon>(find.byType(DivineIcon)).color,
          VineTheme.darkColors.onSurface,
        );
      });

      testWidgets(
        'does not render visibility toggle '
        'when obscureText is false',
        (tester) async {
          await tester.pumpWidget(buildTestWidget());

          expect(find.byType(DivineIcon), findsNothing);
        },
      );

      testWidgets('uses asterisk as obscuring character', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(obscureText: true),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(
          textField.obscuringCharacter,
          equals('✱'),
        );
      });

      testWidgets('label floats when text is entered', (
        tester,
      ) async {
        final controller = TextEditingController();
        await tester.pumpWidget(
          buildTestWidget(controller: controller),
        );

        await tester.enterText(
          find.byType(TextField),
          'Test',
        );
        await tester.pump();

        expect(find.text('Test Label'), findsOneWidget);
      });

      testWidgets('positions text row below the floating label', (
        tester,
      ) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          buildTestWidget(label: 'Email', focusNode: focusNode),
        );

        final containerFinder = find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first;

        double textRowTop() {
          return tester.getTopLeft(find.byType(EditableText)).dy -
              tester.getTopLeft(containerFinder).dy;
        }

        expect(textRowTop(), equals(26));

        focusNode.requestFocus();
        await tester.pumpAndSettle();

        expect(textRowTop(), equals(36));

        focusNode.dispose();
      });

      testWidgets('positions prefilled text below the floating label', (
        tester,
      ) async {
        final controller = TextEditingController(text: 'liz@example.com');
        await tester.pumpWidget(
          buildTestWidget(label: 'Email', controller: controller),
        );
        await tester.pumpAndSettle();

        final containerFinder = find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first;
        final textTop =
            tester.getTopLeft(find.byType(EditableText)).dy -
            tester.getTopLeft(containerFinder).dy;

        expect(textTop, equals(36));

        controller.dispose();
      });
    });

    group('interactions', () {
      testWidgets('accepts text input', (tester) async {
        final controller = TextEditingController();
        await tester.pumpWidget(
          buildTestWidget(controller: controller),
        );

        await tester.enterText(
          find.byType(TextField),
          'Hello World',
        );
        expect(controller.text, equals('Hello World'));
      });

      testWidgets('calls onChanged when text changes', (
        tester,
      ) async {
        String? changedValue;
        await tester.pumpWidget(
          buildTestWidget(
            onChanged: (value) => changedValue = value,
          ),
        );

        await tester.enterText(
          find.byType(TextField),
          'Test',
        );
        expect(changedValue, equals('Test'));
      });

      testWidgets('calls onSubmitted when submitted', (
        tester,
      ) async {
        String? submittedValue;
        await tester.pumpWidget(
          buildTestWidget(
            onSubmitted: (value) => submittedValue = value,
          ),
        );

        await tester.enterText(
          find.byType(TextField),
          'Submit Test',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(submittedValue, equals('Submit Test'));
      });

      testWidgets('calls onTap when tapped', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          buildTestWidget(onTap: () => tapped = true),
        );

        await tester.tap(find.byType(DivineAuthTextField));
        await tester.pump();
        expect(tapped, isTrue);
      });

      testWidgets(
        'focuses field when container area is tapped',
        (tester) async {
          final focusNode = FocusNode();
          await tester.pumpWidget(
            buildTestWidget(focusNode: focusNode),
          );

          expect(focusNode.hasFocus, isFalse);

          // The TextField fills the 76px container for tap coverage, while
          // content padding keeps the visible text row lower in the field.
          final containerFinder = find.byType(Container).first;
          final topLeft = tester.getTopLeft(containerFinder);
          await tester.tapAt(topLeft + const Offset(30, 5));
          await tester.pump();

          expect(focusNode.hasFocus, isTrue);

          focusNode.dispose();
        },
      );

      testWidgets(
        'requests focus when a read-only field is tapped',
        (tester) async {
          // readOnly only gates the input connection (no soft keyboard) and
          // the cut/paste toolbar — TextFormField still grants focus on tap.
          final focusNode = FocusNode();
          await tester.pumpWidget(
            buildTestWidget(focusNode: focusNode, readOnly: true),
          );

          expect(focusNode.hasFocus, isFalse);

          await tester.tap(find.byType(DivineAuthTextField));
          await tester.pump();

          expect(focusNode.hasFocus, isTrue);

          focusNode.dispose();
        },
      );

      testWidgets('does not focus when disabled', (
        tester,
      ) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          buildTestWidget(
            focusNode: focusNode,
            enabled: false,
          ),
        );

        await tester.tap(find.byType(DivineAuthTextField));
        await tester.pump();

        expect(focusNode.hasFocus, isFalse);

        focusNode.dispose();
      });

      testWidgets('does not call onTap when disabled', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          buildTestWidget(
            onTap: () => tapped = true,
            enabled: false,
          ),
        );

        await tester.tap(find.byType(DivineAuthTextField));
        await tester.pump();

        expect(tapped, isFalse);
      });

      testWidgets(
        'toggles password visibility when eye icon tapped',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(obscureText: true),
          );

          var textField = tester.widget<TextField>(
            find.byType(TextField),
          );
          expect(textField.obscureText, isTrue);

          await tester.tap(
            find
                .ancestor(
                  of: find.byType(DivineIcon),
                  matching: find.byType(GestureDetector),
                )
                .first,
          );
          await tester.pump();

          textField = tester.widget<TextField>(
            find.byType(TextField),
          );
          expect(textField.obscureText, isFalse);
        },
      );
    });

    group('properties', () {
      testWidgets('respects readOnly property', (
        tester,
      ) async {
        final controller = TextEditingController(text: 'Initial');
        await tester.pumpWidget(
          buildTestWidget(
            controller: controller,
            readOnly: true,
          ),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.readOnly, isTrue);
      });

      testWidgets('respects enabled property', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(enabled: false),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.enabled, isFalse);
      });

      testWidgets('respects obscureText for passwords', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(obscureText: true),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.obscureText, isTrue);
      });

      testWidgets('respects keyboardType property', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            keyboardType: TextInputType.emailAddress,
          ),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(
          textField.keyboardType,
          equals(TextInputType.emailAddress),
        );
      });

      testWidgets('respects textInputAction property', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            textInputAction: TextInputAction.search,
          ),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(
          textField.textInputAction,
          equals(TextInputAction.search),
        );
      });

      testWidgets('uses focus node when provided', (
        tester,
      ) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          buildTestWidget(focusNode: focusNode),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.focusNode, equals(focusNode));

        focusNode.dispose();
      });

      testWidgets('uses controller when provided', (
        tester,
      ) async {
        final controller = TextEditingController(text: 'Initial Value');
        await tester.pumpWidget(
          buildTestWidget(controller: controller),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.controller, equals(controller));
        expect(controller.text, equals('Initial Value'));

        controller.dispose();
      });
    });

    group('accessibility', () {
      testWidgets(
        'visibility toggle has semantic label for obscured',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(obscureText: true),
          );

          expect(
            find.bySemanticsLabel('Show password'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'visibility toggle has semantic label for visible',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(obscureText: true),
          );

          await tester.tap(
            find
                .ancestor(
                  of: find.byType(DivineIcon),
                  matching: find.byType(GestureDetector),
                )
                .first,
          );
          await tester.pump();

          expect(
            find.bySemanticsLabel('Hide password'),
            findsOneWidget,
          );
        },
      );
    });

    group('error state', () {
      testWidgets(
        'renders error border when errorText is provided',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              errorText: 'Invalid code. Please try again.',
            ),
          );

          final container = tester.widget<Container>(
            find.ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            ),
          );
          final decoration = container.decoration! as BoxDecoration;
          expect(decoration.border, isNotNull);
          final border = decoration.border! as Border;
          expect(border.top.color, equals(VineTheme.error));
          expect(border.top.width, equals(2));
        },
      );

      testWidgets(
        'renders error overlay background when errorText is '
        'provided',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              errorText: 'Invalid code. Please try again.',
            ),
          );

          final container = tester.widget<Container>(
            find.ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            ),
          );
          final decoration = container.decoration! as BoxDecoration;
          expect(
            decoration.color,
            equals(VineTheme.errorOverlay),
          );
        },
      );

      testWidgets(
        'renders error supporting text with warning icon',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              errorText: 'Invalid code. Please try again.',
            ),
          );

          expect(
            find.text('Invalid code. Please try again.'),
            findsOneWidget,
          );
          expect(find.byType(DivineIcon), findsOneWidget);
        },
      );

      testWidgets(
        'does not render error elements when errorText is null',
        (tester) async {
          await tester.pumpWidget(buildTestWidget());

          final container = tester.widget<Container>(
            find.ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            ),
          );
          final decoration = container.decoration! as BoxDecoration;
          expect(decoration.border, isNull);
          expect(
            decoration.color,
            equals(VineTheme.surfaceContainer),
          );
        },
      );

      testWidgets(
        'renders floating label in error color when errorText '
        'is provided',
        (tester) async {
          final controller = TextEditingController(text: 'abc');
          await tester.pumpWidget(
            buildTestWidget(
              controller: controller,
              errorText: 'Invalid code. Please try again.',
            ),
          );
          await tester.pump();

          final labelText = tester.widget<AnimatedDefaultTextStyle>(
            find
                .ancestor(
                  of: find.text('Test Label'),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          );
          expect(
            labelText.style.color,
            equals(VineTheme.error),
          );

          controller.dispose();
        },
      );

      testWidgets(
        'renders cursor in error color when errorText '
        'is provided',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              errorText: 'Invalid code. Please try again.',
            ),
          );

          final textField = tester.widget<TextField>(
            find.byType(TextField),
          );
          expect(
            textField.cursorColor,
            equals(VineTheme.error),
          );
        },
      );
    });

    group('validator', () {
      testWidgets(
        'displays error from validator after validation',
        (tester) async {
          final formKey = GlobalKey<FormState>();
          await tester.pumpWidget(
            MaterialApp(
              theme: VineTheme.theme,
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DivineAuthTextField(
                    label: 'Email',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email is required';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          );

          // Trigger validation with empty field.
          formKey.currentState!.validate();
          await tester.pump();
          // Post-frame callback fires on next pump.
          await tester.pump();

          // Two Text widgets: the hidden TextFormField error
          // (zero-size) and the visible _ErrorSupportingText.
          expect(
            find.text('Email is required'),
            findsNWidgets(2),
          );
          // Verify warning icon appears (from _ErrorSupportingText).
          expect(find.byType(DivineIcon), findsOneWidget);
        },
      );

      testWidgets(
        'clears validator error when user edits the field',
        (tester) async {
          final formKey = GlobalKey<FormState>();
          final controller = TextEditingController();
          await tester.pumpWidget(
            MaterialApp(
              theme: VineTheme.theme,
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DivineAuthTextField(
                    label: 'Email',
                    controller: controller,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email is required';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          );

          // Trigger validation to show error.
          formKey.currentState!.validate();
          await tester.pump();
          await tester.pump();

          expect(
            find.text('Email is required'),
            findsNWidgets(2),
          );

          // Type text to clear the validator error.
          await tester.enterText(
            find.byType(TextField),
            'a',
          );
          await tester.pump();

          // The visible _ErrorSupportingText and its warning
          // icon should be gone.
          expect(find.byType(DivineIcon), findsNothing);

          controller.dispose();
        },
      );
    });

    group('didUpdateWidget', () {
      testWidgets('updates when focusNode changes', (
        tester,
      ) async {
        final focusNode1 = FocusNode();
        final focusNode2 = FocusNode();

        await tester.pumpWidget(
          buildTestWidget(focusNode: focusNode1),
        );

        var textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.focusNode, equals(focusNode1));

        await tester.pumpWidget(
          buildTestWidget(focusNode: focusNode2),
        );
        await tester.pump();

        textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.focusNode, equals(focusNode2));

        focusNode1.dispose();
        focusNode2.dispose();
      });

      testWidgets('updates when controller changes', (
        tester,
      ) async {
        final controller1 = TextEditingController(text: 'First');
        final controller2 = TextEditingController(text: 'Second');

        await tester.pumpWidget(
          buildTestWidget(controller: controller1),
        );

        var textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.controller, equals(controller1));

        await tester.pumpWidget(
          buildTestWidget(controller: controller2),
        );
        await tester.pump();

        textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.controller, equals(controller2));

        controller1.dispose();
        controller2.dispose();
      });
    });

    group('dispose', () {
      testWidgets('stops listening to a caller-owned controller', (
        tester,
      ) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(buildTestWidget(controller: controller));

        // The caller keeps the controller; only the field leaves the tree.
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        controller.text = 'typed after the field was disposed';

        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('renders a prefix affix inside the field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineAuthTextField(label: 'Username', prefixText: '@'),
          ),
        ),
      );

      expect(find.text('@'), findsOneWidget);
    });

    testWidgets('renders a suffix affix inside the field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineAuthTextField(
              label: 'Username',
              suffixText: '.divine.video',
            ),
          ),
        ),
      );

      expect(find.text('.divine.video'), findsOneWidget);
    });

    testWidgets('renders no affixes when none are given', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DivineAuthTextField(label: 'Username')),
        ),
      );

      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(decorator.decoration.prefixText, isNull);
      expect(decorator.decoration.suffixText, isNull);
      expect(decorator.decoration.hintText, isNull);
    });

    testWidgets('shows the hint once the label has floated', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineAuthTextField(
              label: 'Address',
              hintText: 'you@example.com',
            ),
          ),
        ),
      );

      // Unfocused and empty: the label still occupies the field, so the hint
      // is laid out but transparent.
      expect(find.text('you@example.com'), findsOneWidget);

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      expect(find.text('you@example.com'), findsOneWidget);
      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(decorator.decoration.hintText, 'you@example.com');
    });
  });
}
