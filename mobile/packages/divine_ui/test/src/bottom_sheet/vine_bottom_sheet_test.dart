// ABOUTME: Tests for VineBottomSheet component
// ABOUTME: Verifies structure and behavior of the bottom sheet

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Matches the unkeyed 64x4 rounded Container the header paints as the drag
// handle. Asserting the rendered tree, rather than the forwarded
// showDragHandle flag, is what catches a header that stops honouring it.
final Finder _dragHandle = find.byWidgetPredicate((widget) {
  if (widget is! Container) return false;
  final constraints = widget.constraints;
  return constraints?.maxWidth == 64 && constraints?.maxHeight == 4;
});

void main() {
  group('VineBottomSheet', () {
    testWidgets('renders with required props', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              body: Column(children: [Text('Content 1'), Text('Content 2')]),
            ),
          ),
        ),
      );

      // Verify header with title (which includes the drag handle)
      expect(find.byType(VineBottomSheetHeader), findsOneWidget);
      expect(find.text('Test Sheet'), findsOneWidget);

      // Verify content is rendered
      expect(find.text('Content 1'), findsOneWidget);
      expect(find.text('Content 2'), findsOneWidget);
    });

    testWidgets('renders with trailing widget', (tester) async {
      const trailingWidget = Icon(Icons.settings, key: Key('trailing'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              trailing: trailingWidget,
              body: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('trailing')), findsOneWidget);
    });

    testWidgets('renders with bottom input', (tester) async {
      const inputWidget = TextField(
        key: Key('input'),
        decoration: InputDecoration(hintText: 'Add comment...'),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              bottomInput: inputWidget,
              body: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('input')), findsOneWidget);
    });

    testWidgets('keeps bottomInput above the keyboard inset', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const keyboardHeight = 240.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            // Inject a keyboard inset directly so the test can assert layout
            // without needing a real platform keyboard.
            data: MediaQueryData(
              size: Size(400, 800),
              viewInsets: EdgeInsets.only(bottom: keyboardHeight),
            ),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: VineBottomSheet(
                title: Text('Test Sheet'),
                body: Text('Content'),
                bottomInput: SizedBox(
                  key: Key('keyboard-safe-input'),
                  height: 56,
                  child: TextField(),
                ),
              ),
            ),
          ),
        ),
      );

      final inputRect = tester.getRect(
        find.byKey(const Key('keyboard-safe-input')),
      );

      // The animated padding should move the entire bottom input above the
      // keyboard, not just add space below it.
      expect(inputRect.bottom, lessThanOrEqualTo(800 - keyboardHeight));
    });

    testWidgets(
      'modal sheet keeps multiline bottomInput and its action buttons fully '
      'above the keyboard',
      (tester) async {
        tester.view
          ..physicalSize = const Size(400, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);

        const keyboardHeight = 300.0;
        final draggableController = DraggableScrollableController();
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: GestureDetector(
                    onTap: () {
                      // Mirror the comments sheet: draggable modal with snap
                      // sizes and a multiline composer row (text field +
                      // trailing action buttons) in the bottomInput slot.
                      unawaited(
                        VineBottomSheet.show<void>(
                          context: context,
                          snap: true,
                          snapSizes: const [0.7, 0.93],
                          initialChildSize: 0.7,
                          minChildSize: 0.5,
                          maxChildSize: 0.93,
                          draggableController: draggableController,
                          title: const Text('0 Comments'),
                          bottomInput: Padding(
                            key: const Key('composer-input'),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const Key('composer-field'),
                                    focusNode: focusNode,
                                    maxLines: 5,
                                    minLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const SizedBox(
                                  key: Key('send-button'),
                                  width: 40,
                                  height: 40,
                                ),
                              ],
                            ),
                          ),
                          buildScrollBody: (scrollController) => ListView(
                            controller: scrollController,
                            children: const [SizedBox(height: 400)],
                          ),
                        ),
                      );
                    },
                    child: const Text('open sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open sheet'));
        await tester.pumpAndSettle();

        // Grow the composer to several lines like a long comment draft.
        await tester.enterText(
          find.byKey(const Key('composer-field')),
          'line one\nline two\nline three\nline four\nline five',
        );
        await tester.pumpAndSettle();

        // Keyboard opens.
        tester.view.viewInsets = const FakeViewPadding(
          bottom: keyboardHeight,
        );
        focusNode.requestFocus();
        await tester.pumpAndSettle();

        final inputRect = tester.getRect(
          find.byKey(const Key('composer-input')),
        );
        final fieldRect = tester.getRect(
          find.byKey(const Key('composer-field')),
        );
        final sendRect = tester.getRect(find.byKey(const Key('send-button')));
        const keyboardTop = 800 - keyboardHeight;

        // The composer must not sit flush against the keyboard: real devices
        // show keyboard-height variance (predictive bar appearing, inset
        // animation lag), and a flush composer puts its bottom-anchored
        // action buttons under the keyboard. Require visible clearance.
        const keyboardClearance = 12.0;
        expect(
          inputRect.bottom,
          lessThanOrEqualTo(keyboardTop - keyboardClearance),
          reason:
              'composer bottom ${inputRect.bottom} sits flush at the keyboard '
              'top $keyboardTop with less than ${keyboardClearance}px '
              'clearance, so its action buttons can slip under the keyboard',
        );
        expect(
          fieldRect.bottom,
          lessThanOrEqualTo(keyboardTop),
          reason:
              'composer text field bottom ${fieldRect.bottom} dips under the '
              'keyboard top $keyboardTop',
        );
        expect(
          sendRect.bottom,
          lessThanOrEqualTo(keyboardTop),
          reason:
              'send button bottom ${sendRect.bottom} dips under the keyboard '
              'top $keyboardTop',
        );
      },
    );

    testWidgets('content is scrollable when expanded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: const Text('Test Sheet'),
              body: ListView(
                children: List.generate(
                  50,
                  (index) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Item $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify first item is visible
      expect(find.text('Item 0'), findsOneWidget);

      // Last item should not be visible initially
      expect(find.text('Item 49'), findsNothing);

      // Scroll to bottom
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      // Now last item should be visible
      expect(find.text('Item 49'), findsOneWidget);
    });

    testWidgets('wraps content when expanded is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              expanded: false,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Item 1'), Text('Item 2')],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('renders fixed mode with scrollable false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              title: Text('Fixed Sheet'),
              children: [Text('Fixed Content')],
            ),
          ),
        ),
      );

      expect(find.text('Fixed Sheet'), findsOneWidget);
      expect(find.text('Fixed Content'), findsOneWidget);
    });

    testWidgets('renders contentTitle in fixed mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              contentTitle: 'Content Title',
              children: [Text('Content')],
            ),
          ),
        ),
      );

      expect(find.text('Content Title'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders contentTitle in scrollable mode', (tester) async {
      final scrollController = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              contentTitle: 'Scrollable Title',
              scrollController: scrollController,
              children: const [Text('Scrollable Content')],
            ),
          ),
        ),
      );

      expect(find.text('Scrollable Title'), findsOneWidget);
      expect(find.text('Scrollable Content'), findsOneWidget);
    });

    // `contentTitle` used to be rendered only inside the fallback `children`
    // ListView/Column, so passing `body` or `buildScrollBody` silently
    // dropped it.
    testWidgets('renders contentTitle alongside body in fixed mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              contentTitle: 'Body Title',
              body: Text('Body Content'),
            ),
          ),
        ),
      );

      expect(find.text('Body Title'), findsOneWidget);
      expect(find.text('Body Content'), findsOneWidget);
    });

    testWidgets('renders contentTitle alongside body in scrollable mode', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              contentTitle: 'Scrollable Body Title',
              scrollController: scrollController,
              body: const Text('Scrollable Body Content'),
            ),
          ),
        ),
      );

      expect(find.text('Scrollable Body Title'), findsOneWidget);
      expect(find.text('Scrollable Body Content'), findsOneWidget);
    });

    testWidgets('renders contentTitle alongside buildScrollBody', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              contentTitle: 'Custom Scroll Title',
              scrollController: scrollController,
              buildScrollBody: (controller) => ListView(
                controller: controller,
                children: const [Text('Custom Scroll Content')],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Scroll Title'), findsOneWidget);
      expect(find.text('Custom Scroll Content'), findsOneWidget);
    });

    testWidgets('renders contentTitleTrailing on the title row', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              contentTitle: 'Pick some',
              contentTitleTrailing: const Text('Clear all'),
              scrollController: scrollController,
              buildScrollBody: (controller) => ListView(
                controller: controller,
                children: const [Text('Option')],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Clear all'), findsOneWidget);
      // Same row as the title, not stranded in the header above the divider.
      expect(
        tester.getCenter(find.text('Clear all')).dy,
        tester.getCenter(find.text('Pick some')).dy,
      );
      expect(
        tester.getCenter(find.text('Clear all')).dx,
        greaterThan(tester.getCenter(find.text('Pick some')).dx),
      );
    });

    testWidgets('does not duplicate contentTitle in the children path', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              contentTitle: 'Only Once',
              scrollController: scrollController,
              children: const [Text('Child')],
            ),
          ),
        ),
      );

      expect(find.text('Only Once'), findsOneWidget);
    });

    testWidgets('renders bottomInput in fixed mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              bottomInput: TextField(key: Key('fixed-input')),
              children: [Text('Content')],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('fixed-input')), findsOneWidget);
    });

    testWidgets(
      'hides header and shows only drag handle when showHeader is false',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VineBottomSheet(showHeader: false, body: Text('Content')),
            ),
          ),
        );

        expect(find.byType(VineBottomSheetHeader), findsNothing);
        expect(find.byType(VineBottomSheetDragHandle), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
      },
    );

    testWidgets(
      'showHeader: false renders a 1 px divider below the drag handle '
      'when showHeaderDivider is true',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VineBottomSheet(
                showHeader: false,
                body: Text('Content'),
              ),
            ),
          ),
        );

        // The chrome divider is a 1 px Container gated by
        // showHeaderDivider, which defaults to true.
        expect(
          find.byWidgetPredicate((w) {
            if (w is! Container) return false;
            return w.color == const Color(0x0DFFFFFF) &&
                w.constraints?.maxHeight == 1;
          }),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'showHeader: false omits the divider when showHeaderDivider is false',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VineBottomSheet(
                showHeader: false,
                showHeaderDivider: false,
                body: Text('Content'),
              ),
            ),
          ),
        );

        expect(
          find.byWidgetPredicate((w) {
            if (w is! Container) return false;
            return w.color == const Color(0x0DFFFFFF) &&
                w.constraints?.maxHeight == 1;
          }),
          findsNothing,
        );
      },
    );

    testWidgets(
      'showHeader: false divider follows the light palette',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.lightTheme,
            home: const Scaffold(
              body: VineBottomSheet(
                showHeader: false,
                body: Text('Content'),
              ),
            ),
          ),
        );

        expect(
          find.byWidgetPredicate((w) {
            if (w is! Container) return false;
            return w.color == VineTheme.lightColors.outlineDisabled &&
                w.constraints?.maxHeight == 1;
          }),
          findsOneWidget,
        );
      },
    );

    testWidgets('hides header in fixed mode when showHeader is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              showHeader: false,
              children: [Text('Fixed Content')],
            ),
          ),
        ),
      );

      expect(find.byType(VineBottomSheetHeader), findsNothing);
      expect(find.byType(VineBottomSheetDragHandle), findsOneWidget);
      expect(find.text('Fixed Content'), findsOneWidget);
    });

    group('VineBottomSheet.show', () {
      testWidgets('shows modal bottom sheet', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Modal Sheet'),
                      children: const [Text('Modal Content')],
                    );
                  },
                  child: const Text('Show Sheet'),
                ),
              ),
            ),
          ),
        );

        // Tap to show sheet
        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        // Verify sheet is shown
        expect(find.text('Modal Sheet'), findsOneWidget);
        expect(find.text('Modal Content'), findsOneWidget);
      });

      testWidgets('shows fixed mode sheet with scrollable false', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Fixed Modal'),
                      children: const [Text('Fixed Modal Content')],
                    );
                  },
                  child: const Text('Show Fixed Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Fixed Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Fixed Modal'), findsOneWidget);
        expect(find.text('Fixed Modal Content'), findsOneWidget);
      });

      testWidgets('calls onShow callback when showing sheet', (tester) async {
        var onShowCalled = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Callback Sheet'),
                      onShow: () => onShowCalled = true,
                      children: const [Text('Content')],
                    );
                  },
                  child: const Text('Show Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(onShowCalled, isTrue);
      });

      testWidgets('shows sheet with body parameter', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      body: const Text('Body Content'),
                    );
                  },
                  child: const Text('Show Body Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Body Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Body Content'), findsOneWidget);
      });

      testWidgets('forwards headerPadding to header in scrollable mode', (
        tester,
      ) async {
        const customPadding = EdgeInsetsDirectional.only(
          start: 12,
          end: 12,
          top: 8,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Padded Sheet'),
                      headerPadding: customPadding,
                      children: const [Text('Content')],
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        final header = tester.widget<VineBottomSheetHeader>(
          find.byType(VineBottomSheetHeader),
        );
        expect(header.padding, customPadding);
      });

      testWidgets('forwards headerPadding to header in fixed mode', (
        tester,
      ) async {
        const customPadding = EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          top: 4,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Fixed Padded Sheet'),
                      headerPadding: customPadding,
                      children: const [Text('Content')],
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        final header = tester.widget<VineBottomSheetHeader>(
          find.byType(VineBottomSheetHeader),
        );
        expect(header.padding, customPadding);
      });
    });

    group('tapOutsideToDismiss', () {
      Future<void> showDraggable(
        WidgetTester tester, {
        required bool tapOutsideToDismiss,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      tapOutsideToDismiss: tapOutsideToDismiss,
                      initialChildSize: 0.5,
                      title: const Text('Draggable Sheet'),
                      children: const [Text('Sheet Body')],
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Sheet Body'), findsOneWidget);
      }

      testWidgets(
        'dismisses on tap above the sheet when tapOutsideToDismiss is true',
        (tester) async {
          await showDraggable(tester, tapOutsideToDismiss: true);

          // Tap near the top of the screen, above the sheet.
          await tester.tapAt(const Offset(200, 20));
          await tester.pumpAndSettle();

          expect(find.text('Sheet Body'), findsNothing);
        },
      );

      testWidgets(
        'does not dismiss on tap above the sheet when tapOutsideToDismiss '
        'is false',
        (tester) async {
          await showDraggable(tester, tapOutsideToDismiss: false);

          await tester.tapAt(const Offset(200, 20));
          await tester.pumpAndSettle();

          expect(find.text('Sheet Body'), findsOneWidget);
        },
      );

      testWidgets('does not dismiss on tap on non-interactive sheet body', (
        tester,
      ) async {
        await showDraggable(tester, tapOutsideToDismiss: true);

        // Tap directly on the sheet's body text — a non-interactive area.
        await tester.tap(find.text('Sheet Body'));
        await tester.pumpAndSettle();

        expect(find.text('Sheet Body'), findsOneWidget);
      });

      testWidgets('interactive children inside the sheet still receive taps', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      initialChildSize: 0.5,
                      title: const Text('Interactive Sheet'),
                      children: [
                        ElevatedButton(
                          onPressed: () => tapped = true,
                          child: const Text('Inner Button'),
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Inner Button'));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
        // Sheet should still be visible after tapping an inner button.
        expect(find.text('Inner Button'), findsOneWidget);
      });

      testWidgets('fixed mode still dismisses on barrier tap (unchanged)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Fixed Sheet'),
                      children: const [Text('Fixed Body')],
                    );
                  },
                  child: const Text('Open Fixed'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Fixed'));
        await tester.pumpAndSettle();
        expect(find.text('Fixed Body'), findsOneWidget);

        // Tap well above the fixed sheet — hits the modal scrim.
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();

        expect(find.text('Fixed Body'), findsNothing);
      });
    });

    group('new parameters', () {
      test('snap without scrollable fails an assertion', () {
        expect(
          () => VineBottomSheet.show<void>(
            context: _FakeContext(),
            scrollable: false,
            snap: true,
            children: const [Text('x')],
          ),
          throwsAssertionError,
        );
      });

      test('snapSizes without snap fails an assertion', () {
        expect(
          () => VineBottomSheet.show<void>(
            context: _FakeContext(),
            snapSizes: const [0.5, 0.9],
            children: const [Text('x')],
          ),
          throwsAssertionError,
        );
      });

      testWidgets(
        'contentWrapper is applied around the sheet inside the modal route',
        (tester) async {
          ModalRoute<dynamic>? callerRoute;
          ModalRoute<void>? wrapperRoute;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    callerRoute = ModalRoute.of(context);
                    return ElevatedButton(
                      onPressed: () async {
                        await VineBottomSheet.show<void>(
                          context: context,
                          title: const Text('Wrapped'),
                          children: const [Text('Body')],
                          contentWrapper: (wrapperContext, child) {
                            wrapperRoute = ModalRoute.of<void>(wrapperContext);
                            return _WrapperMarker(child: child);
                          },
                        );
                      },
                      child: const Text('Open'),
                    );
                  },
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          // Wrapper wraps the real sheet content.
          expect(find.byType(_WrapperMarker), findsOneWidget);
          expect(find.text('Body'), findsOneWidget);
          // The wrapper's context resolves to the sheet's OWN route, not the
          // route it was opened from. Callers dismiss a sheet by identity from
          // here (`ModalRoute.of(wrapperContext)`); applying the wrapper above
          // the modal route instead would hand them the caller's page route,
          // and removing that takes the user's screen down with it.
          expect(wrapperRoute, isA<ModalBottomSheetRoute<void>>());
          expect(callerRoute, isNotNull);
          expect(wrapperRoute, isNot(same(callerRoute)));
        },
      );

      testWidgets(
        'draggableController animates the sheet between sizes '
        '(tapOutsideToDismiss path)',
        (tester) async {
          final controller = DraggableScrollableController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheet.show<void>(
                        context: context,
                        initialChildSize: 0.4,
                        minChildSize: 0.2,
                        maxChildSize: 0.95,
                        title: const Text('Resizable'),
                        children: const [
                          SizedBox(height: 200, child: Text('Body')),
                        ],
                        draggableController: controller,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(controller.isAttached, isTrue);
          expect(controller.size, closeTo(0.4, 0.001));

          controller
              .animateTo(
                0.95,
                duration: const Duration(milliseconds: 100),
                curve: Curves.linear,
              )
              .ignore();
          await tester.pumpAndSettle();

          expect(controller.size, closeTo(0.95, 0.001));
        },
      );

      testWidgets(
        'draggableController is forwarded when tapOutsideToDismiss is false',
        (tester) async {
          final controller = DraggableScrollableController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheet.show<void>(
                        context: context,
                        tapOutsideToDismiss: false,
                        initialChildSize: 0.5,
                        title: const Text('Resizable'),
                        children: const [Text('Body')],
                        draggableController: controller,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(controller.isAttached, isTrue);
          expect(controller.size, closeTo(0.5, 0.001));
        },
      );

      testWidgets(
        'contentWrapper is applied in fixed (non-scrollable) mode too',
        (tester) async {
          ModalRoute<dynamic>? callerRoute;
          ModalRoute<void>? wrapperRoute;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    callerRoute = ModalRoute.of(context);
                    return ElevatedButton(
                      onPressed: () async {
                        await VineBottomSheet.show<void>(
                          context: context,
                          scrollable: false,
                          title: const Text('Wrapped Fixed'),
                          children: const [Text('Fixed Body')],
                          contentWrapper: (wrapperContext, child) {
                            wrapperRoute = ModalRoute.of<void>(wrapperContext);
                            return _WrapperMarker(child: child);
                          },
                        );
                      },
                      child: const Text('Open Fixed'),
                    );
                  },
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open Fixed'));
          await tester.pumpAndSettle();

          expect(find.byType(_WrapperMarker), findsOneWidget);
          expect(find.text('Fixed Body'), findsOneWidget);
          // Same route-identity contract as the scrollable path above.
          expect(wrapperRoute, isA<ModalBottomSheetRoute<void>>());
          expect(callerRoute, isNotNull);
          expect(wrapperRoute, isNot(same(callerRoute)));
        },
      );

      testWidgets(
        'forwards headerLeadingAction to VineBottomSheetHeader',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheet.show<void>(
                        context: context,
                        title: const Text('With Leading'),
                        headerLeadingAction: DivineIconButton(
                          key: const Key('leading'),
                          icon: DivineIconName.x,
                          onPressed: () {},
                        ),
                        children: const [Text('Body')],
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('leading')), findsOneWidget);
        },
      );

      testWidgets(
        'forwards headerTrailingAction to VineBottomSheetHeader',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheet.show<void>(
                        context: context,
                        title: const Text('With Trailing'),
                        headerTrailingAction: DivineIconButton(
                          key: const Key('trailing'),
                          icon: DivineIconName.check,
                          onPressed: () {},
                        ),
                        children: const [Text('Body')],
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('trailing')), findsOneWidget);
        },
      );

      testWidgets(
        'forwards header actions in fixed (non-scrollable) mode',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheet.show<void>(
                        context: context,
                        scrollable: false,
                        title: const Text('Fixed Title'),
                        headerLeadingAction: DivineIconButton(
                          key: const Key('fixed_leading'),
                          icon: DivineIconName.x,
                          onPressed: () {},
                        ),
                        children: const [Text('Body')],
                      );
                    },
                    child: const Text('Open Fixed'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open Fixed'));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('fixed_leading')), findsOneWidget);
        },
      );

      testWidgets(
        'showDragHandle: false hides the drag handle when no header',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheet.show<void>(
                        context: context,
                        showHeader: false,
                        showDragHandle: false,
                        children: const [Text('Body')],
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          // Drag handle is a 64x4 rounded Container; with no header and
          // showDragHandle: false there must be none in the sheet subtree.
          expect(
            find.byWidgetPredicate((w) {
              if (w is! Container) return false;
              final c = w.constraints;
              return c?.maxWidth == 64 && c?.maxHeight == 4;
            }),
            findsNothing,
          );
        },
      );

      testWidgets(
        'showDragHandle: false hides the drag handle in fixed mode',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheet.show<void>(
                        context: context,
                        scrollable: false,
                        showHeader: false,
                        showDragHandle: false,
                        children: const [Text('Body')],
                      );
                    },
                    child: const Text('Open Fixed'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open Fixed'));
          await tester.pumpAndSettle();

          expect(
            find.byWidgetPredicate((w) {
              if (w is! Container) return false;
              final c = w.constraints;
              return c?.maxWidth == 64 && c?.maxHeight == 4;
            }),
            findsNothing,
          );
        },
      );

      testWidgets(
        'enableDrag: false hides the drag handle in fixed mode by default',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      enableDrag: false,
                      children: const [Text('Body')],
                    ),
                    child: const Text('Open Fixed Without Handle'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open Fixed Without Handle'));
          await tester.pumpAndSettle();

          expect(_dragHandle, findsNothing);
        },
      );

      testWidgets(
        'enableDrag: false hides the drag handle in scrollable mode by default',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      enableDrag: false,
                      children: const [Text('Body')],
                    ),
                    child: const Text('Open Scrollable Without Handle'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open Scrollable Without Handle'));
          await tester.pumpAndSettle();

          expect(_dragHandle, findsNothing);
        },
      );

      testWidgets(
        'an explicit drag handle overrides enableDrag: false',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      enableDrag: false,
                      showDragHandle: true,
                      children: const [Text('Body')],
                    ),
                    child: const Text('Open With Handle'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open With Handle'));
          await tester.pumpAndSettle();

          expect(_dragHandle, findsOneWidget);
        },
      );

      testWidgets(
        'a draggable sheet shows the drag handle by default',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      children: const [Text('Body')],
                    ),
                    child: const Text('Open Draggable'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open Draggable'));
          await tester.pumpAndSettle();

          expect(_dragHandle, findsOneWidget);
        },
      );
    });
    group('onComplete', () {
      testWidgets(
        'shows close and check buttons in header when onComplete is provided',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: VineBottomSheet(
                  scrollable: false,
                  title: const Text('Create'),
                  onComplete: () async {},
                  body: const Text('Body'),
                ),
              ),
            ),
          );

          // Close (X) button and check button should both be present.
          expect(find.byType(DivineIconButton), findsNWidgets(2));
          // Trailing slot is not used when onComplete overrides it.
          expect(find.byType(VineBottomSheetHeader), findsOneWidget);
        },
      );

      testWidgets(
        'close button dismisses the sheet',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Create'),
                      onComplete: () async {},
                      body: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(find.text('Sheet body'), findsOneWidget);

          // The first DivineIconButton is the close (X) button.
          await tester.tap(find.byType(DivineIconButton).first);
          await tester.pumpAndSettle();

          expect(find.text('Sheet body'), findsNothing);
        },
      );

      testWidgets(
        'close button in scrollable mode dismisses the sheet',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Create'),
                      onComplete: () async {},
                      body: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(find.text('Sheet body'), findsOneWidget);

          await tester.tap(find.byType(DivineIconButton).first);
          await tester.pumpAndSettle();

          expect(find.text('Sheet body'), findsNothing);
        },
      );

      testWidgets(
        'check button invokes onComplete then dismisses the sheet',
        (tester) async {
          var completed = false;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Create'),
                      onComplete: () async {
                        completed = true;
                      },
                      body: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(find.text('Sheet body'), findsOneWidget);

          // The last DivineIconButton is the check button.
          await tester.tap(find.byType(DivineIconButton).last);
          await tester.pumpAndSettle();

          expect(completed, isTrue);
          expect(find.text('Sheet body'), findsNothing);
        },
      );

      testWidgets(
        'check button shows loading indicator while onComplete runs',
        (tester) async {
          // Use a completer so we can pause mid-callback and inspect UI.
          var resumeCallback = false;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Create'),
                      onComplete: () async {
                        // Spin until test unblocks us.
                        while (!resumeCallback) {
                          await Future<void>.delayed(
                            const Duration(milliseconds: 10),
                          );
                        }
                      },
                      body: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          // Tap the check button — callback starts but doesn't finish yet.
          await tester.tap(find.byType(DivineIconButton).last);
          await tester.pump();

          // Loading indicator should be visible instead of the check button.
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          // Only one DivineIconButton remains (the close button).
          expect(find.byType(DivineIconButton), findsOneWidget);

          // Unblock the callback and let the sheet dismiss.
          resumeCallback = true;
          await tester.pumpAndSettle();

          expect(find.text('Sheet body'), findsNothing);
        },
      );

      testWidgets(
        'check button in scrollable mode invokes onComplete then dismisses',
        (tester) async {
          var completed = false;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Create'),
                      onComplete: () async {
                        completed = true;
                      },
                      body: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          // Both close (X) and check buttons present in scrollable mode.
          expect(find.byType(DivineIconButton), findsNWidgets(2));

          // Tap check button — last DivineIconButton is the check.
          await tester.tap(find.byType(DivineIconButton).last);
          await tester.pumpAndSettle();

          expect(completed, isTrue);
          expect(find.text('Sheet body'), findsNothing);
        },
      );
    });

    group('accessibility', () {
      testWidgets(
        'onComplete header buttons carry an accessible name',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            MaterialApp(
              theme: VineTheme.theme,
              home: Scaffold(
                body: VineBottomSheet(
                  scrollable: false,
                  title: const Text('Create'),
                  onComplete: () async {},
                  body: const Text('Body'),
                ),
              ),
            ),
          );

          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );

      testWidgets(
        'onComplete header buttons meet the tap-target guidelines',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            MaterialApp(
              theme: VineTheme.theme,
              home: Scaffold(
                body: VineBottomSheet(
                  scrollable: false,
                  title: const Text('Create'),
                  onComplete: () async {},
                  body: const Text('Body'),
                ),
              ),
            ),
          );

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          handle.dispose();
        },
      );

      testWidgets('header button labels are caller-overridable', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: VineBottomSheet(
                scrollable: false,
                title: const Text('Create'),
                onComplete: () async {},
                closeSemanticLabel: 'Abbrechen',
                completeSemanticLabel: 'Fertig',
                body: const Text('Body'),
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Abbrechen'), findsOneWidget);
        expect(find.bySemanticsLabel('Fertig'), findsOneWidget);
        expect(find.bySemanticsLabel('Close'), findsNothing);
        expect(find.bySemanticsLabel('Done'), findsNothing);
      });

      testWidgets('loading spinner keeps the complete button label', (
        tester,
      ) async {
        final completer = Completer<void>();
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: VineBottomSheet(
                scrollable: false,
                title: const Text('Create'),
                onComplete: () => completer.future,
                completeSemanticLabel: 'Save list',
                body: const Text('Body'),
              ),
            ),
          ),
        );

        await tester.tap(find.bySemanticsLabel('Save list'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.bySemanticsLabel('Save list'), findsOneWidget);

        completer.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('modal sheet leaves no unlabeled tappable scrim node', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => VineBottomSheet.show<void>(
                    context: context,
                    title: const Text('Create'),
                    onComplete: () async {},
                    body: const Text('Body'),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });
  });
}

/// in the widget tree exactly once.
class _WrapperMarker extends StatelessWidget {
  const _WrapperMarker({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Minimal BuildContext stand-in used for constructor-time assertion tests
/// that never reach actual widget inflation.
class _FakeContext extends StatelessElement {
  _FakeContext() : super(const _FakeWidget());
}

class _FakeWidget extends StatelessWidget {
  const _FakeWidget();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
