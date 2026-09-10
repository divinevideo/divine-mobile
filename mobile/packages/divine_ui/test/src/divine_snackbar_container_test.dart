import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Size [text] takes on one unconstrained line, in the style it actually
/// rendered with.
///
/// The placement tests size their viewport from this rather than hardcoding
/// pixel widths. This suite runs in two font contexts: from the package it
/// falls back to a test font, and from `mobile/` — which is how the pre-push
/// hook runs it — it gets the bundled Inter. The same string measures about
/// twice as wide in one as the other, so any fixed viewport puts the two on
/// opposite sides of the wrap threshold.
Size _renderedTextSize(WidgetTester tester, String text) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: tester.widget<Text>(find.text(text)).style,
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

/// Viewport width that leaves the message exactly [labelWidth] to wrap in,
/// once the action column and the two 16px edge insets are accounted for.
double _viewportFor(double labelWidth, double actionWidth) =>
    labelWidth + math.max(72, actionWidth) + 4 + 16 + 16;

void main() {
  group('DivineSnackbarContainer', () {
    Widget buildTestWidget({
      required String label,
      bool error = false,
      String? actionLabel,
      VoidCallback? onActionPressed,
      String? secondaryActionLabel,
      VoidCallback? onSecondaryActionPressed,
      VoidCallback? onDismissPressed,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? VineTheme.theme,
        home: Scaffold(
          body: DivineSnackbarContainer(
            label: label,
            error: error,
            actionLabel: actionLabel,
            onActionPressed: onActionPressed,
            secondaryActionLabel: secondaryActionLabel,
            onSecondaryActionPressed: onSecondaryActionPressed,
            onDismissPressed: onDismissPressed,
          ),
        ),
      );
    }

    testWidgets('renders with label text', (tester) async {
      await tester.pumpWidget(buildTestWidget(label: 'Test message'));

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('renders non-error state correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget(label: 'Info message'));

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, VineTheme.surfaceContainerHigh);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(16)),
      );
      expect(decoration.boxShadow, VineTheme.depth1);
    });

    testWidgets('renders error state correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(label: 'Error message', error: true),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, VineTheme.errorContainer);
    });

    testWidgets('renders error text with red color', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(label: 'Error message', error: true),
      );

      final text = tester.widget<Text>(find.text('Error message'));
      expect(text.style?.color, VineTheme.error);
    });

    testWidgets('renders non-error text without red color', (tester) async {
      await tester.pumpWidget(buildTestWidget(label: 'Info message'));

      final text = tester.widget<Text>(find.text('Info message'));
      expect(text.style?.color, isNot(VineTheme.error));
    });

    testWidgets('does not render action button when actionLabel is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(label: 'Test message'));

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('does not render action button when onActionPressed is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(label: 'Test message', actionLabel: 'Retry'),
      );

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('renders action button when both actionLabel and '
        'onActionPressed are provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          label: 'Test message',
          actionLabel: 'Retry',
          onActionPressed: () {},
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('calls onActionPressed when action button is tapped', (
      tester,
    ) async {
      var actionPressed = false;
      await tester.pumpWidget(
        buildTestWidget(
          label: 'Test message',
          actionLabel: 'Retry',
          onActionPressed: () => actionPressed = true,
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(actionPressed, isTrue);
    });

    testWidgets('action button has green color in non-error state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          label: 'Test message',
          actionLabel: 'Retry',
          onActionPressed: () {},
        ),
      );

      final actionText = tester.widget<Text>(find.text('Retry'));
      expect(actionText.style?.color, VineTheme.vineGreen);
    });

    testWidgets('action button has red color in error state', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          label: 'Error message',
          error: true,
          actionLabel: 'Retry',
          onActionPressed: () {},
        ),
      );

      final actionText = tester.widget<Text>(find.text('Retry'));
      expect(actionText.style?.color, VineTheme.error);
    });

    testWidgets('action label uses the title/medium type ramp', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          label: 'Test message',
          actionLabel: 'Retry',
          onActionPressed: () {},
        ),
      );

      final actionStyle = tester.widget<Text>(find.text('Retry')).style;
      final reference = VineTheme.titleMediumFont();
      expect(actionStyle?.fontFamily, reference.fontFamily);
      expect(actionStyle?.fontSize, 16);
      expect(actionStyle?.fontWeight, FontWeight.w800);
      expect(actionStyle?.letterSpacing, 0.15);
    });

    testWidgets('a light custom surface darkens the action too', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(
            body: DivineSnackbarContainer(
              label: 'Switched to Staging',
              backgroundColor: const Color(0xFFFFF140),
              actionLabel: 'Undo',
              onActionPressed: () {},
            ),
          ),
        ),
      );

      final actionText = tester.widget<Text>(find.text('Undo'));
      expect(actionText.style?.color, VineTheme.primaryDarkGreen);
    });

    group('secondary action', () {
      testWidgets('renders both actions when a secondary is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Message not delivered',
            error: true,
            actionLabel: 'Resend',
            onActionPressed: () {},
            secondaryActionLabel: 'Delete',
            onSecondaryActionPressed: () {},
          ),
        );

        expect(find.text('Resend'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('primary stays green and secondary is red even in an '
          'error snackbar', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Message not delivered',
            error: true,
            actionLabel: 'Resend',
            onActionPressed: () {},
            secondaryActionLabel: 'Delete',
            onSecondaryActionPressed: () {},
          ),
        );

        expect(
          tester.widget<Text>(find.text('Resend')).style?.color,
          VineTheme.vineGreen,
        );
        expect(
          tester.widget<Text>(find.text('Delete')).style?.color,
          VineTheme.error,
        );
      });

      testWidgets('calls onSecondaryActionPressed when tapped', (tester) async {
        var deletePressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Message not delivered',
            actionLabel: 'Resend',
            onActionPressed: () {},
            secondaryActionLabel: 'Delete',
            onSecondaryActionPressed: () => deletePressed = true,
          ),
        );

        await tester.tap(find.text('Delete'));
        expect(deletePressed, isTrue);
      });

      testWidgets('omits the secondary when its callback is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Message not delivered',
            actionLabel: 'Resend',
            onActionPressed: () {},
            secondaryActionLabel: 'Delete',
          ),
        );

        expect(find.text('Delete'), findsNothing);
      });
    });

    group('snackBar factory', () {
      testWidgets('returns a $SnackBar wrapping $DivineSnackbarContainer', (
        tester,
      ) async {
        final snackBar = DivineSnackbarContainer.snackBar('Hello');

        expect(snackBar, isA<SnackBar>());
        expect(snackBar.backgroundColor, Colors.transparent);
        expect(snackBar.elevation, 0);
        expect(snackBar.behavior, SnackBarBehavior.floating);
        expect(snackBar.padding, EdgeInsets.zero);
        expect(snackBar.content, isA<DivineSnackbarContainer>());

        final container = snackBar.content as DivineSnackbarContainer;
        expect(container.label, 'Hello');
        expect(container.error, isFalse);
        expect(container.actionLabel, isNull);
        expect(container.onActionPressed, isNull);
      });

      testWidgets('passes error and action parameters through', (
        tester,
      ) async {
        void onAction() {}

        void onDelete() {}

        final snackBar = DivineSnackbarContainer.snackBar(
          'Error occurred',
          error: true,
          actionLabel: 'Retry',
          onActionPressed: onAction,
          secondaryActionLabel: 'Delete',
          onSecondaryActionPressed: onDelete,
        );

        final container = snackBar.content as DivineSnackbarContainer;
        expect(container.label, 'Error occurred');
        expect(container.error, isTrue);
        expect(container.actionLabel, 'Retry');
        expect(container.onActionPressed, equals(onAction));
        expect(container.secondaryActionLabel, 'Delete');
        expect(container.onSecondaryActionPressed, equals(onDelete));
      });

      testWidgets('passes the dismiss parameters through', (tester) async {
        void onDismiss() {}

        final snackBar = DivineSnackbarContainer.snackBar(
          'Saved',
          onDismissPressed: onDismiss,
          dismissSemanticLabel: 'Close',
        );

        final container = snackBar.content as DivineSnackbarContainer;
        expect(container.onDismissPressed, equals(onDismiss));
        expect(container.dismissSemanticLabel, 'Close');
      });
    });

    group('sizing', () {
      testWidgets('a one-line banner still clears the 48px touch target', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(label: 'Test message'));

        final banner = tester.getRect(find.byType(DecoratedBox));
        expect(banner.height, DivineSnackbarContainer.minHeight);
      });

      testWidgets('insets the label by 16px from the leading edge', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(label: 'Test message'));

        final banner = tester.getRect(find.byType(DecoratedBox));
        final label = tester.getRect(find.text('Test message'));
        expect(label.left - banner.left, 16);
      });

      testWidgets('stops growing at the max width on a wide viewport', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestWidget(label: 'Test message'));

        final banner = tester.getRect(find.byType(DecoratedBox));
        expect(banner.width, DivineSnackbarContainer.maxWidth);
        // …and stays centred rather than pinned to the leading edge.
        expect(banner.center.dx, 800);
      });

      testWidgets('tracks the viewport when it is narrower than the max', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestWidget(label: 'Test message'));

        final banner = tester.getRect(find.byType(DecoratedBox));
        expect(banner.width, 360);
      });
    });

    group('dismiss button', () {
      testWidgets('is absent when onDismissPressed is null', (tester) async {
        await tester.pumpWidget(buildTestWidget(label: 'Test message'));

        expect(find.byType(DivineIconButton), findsNothing);
      });

      testWidgets('renders and calls back when tapped', (tester) async {
        var dismissed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: DivineSnackbarContainer(
                label: 'Test message',
                onDismissPressed: () => dismissed = true,
              ),
            ),
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
        await tester.tap(find.byType(DivineIconButton));
        expect(dismissed, isTrue);
      });

      testWidgets('carries the accent colour and semantic label', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: DivineSnackbarContainer(
                label: 'Error message',
                error: true,
                dismissSemanticLabel: 'Close',
                onDismissPressed: () {},
              ),
            ),
          ),
        );

        final button = tester.widget<DivineIconButton>(
          find.byType(DivineIconButton),
        );
        expect(button.icon, DivineIconName.x);
        expect(button.foregroundColor, VineTheme.error);
        expect(button.semanticLabel, 'Close');
      });

      testWidgets('sits beside the label rather than below it', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: DivineSnackbarContainer(
                label: 'Test message',
                onDismissPressed: () {},
              ),
            ),
          ),
        );

        final label = tester.getRect(find.text('Test message'));
        final button = tester.getRect(find.byType(DivineIconButton));
        expect(button.left, greaterThan(label.right));
      });

      // The trailing inset drops from 16 to 4 when the dismiss button is
      // present, because the button carries the rest of the edge itself.
      //
      // This pins the inset rather than the button's absolute width: that
      // width is Flutter-version-dependent (3.44 renders the ghostSecondary
      // small variant at 52, current stable at 48), so asserting it here
      // pins the SDK rather than this component's contract.
      testWidgets('sits 4px inside the trailing edge', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(label: 'Test message', onDismissPressed: () {}),
        );

        final banner = tester.getRect(find.byType(DecoratedBox));
        final button = tester.getRect(find.byType(DivineIconButton));
        expect(banner.right - button.right, 4);
      });

      testWidgets('sits after the action when both are present', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Copied',
            actionLabel: 'Undo',
            onActionPressed: () {},
            onDismissPressed: () {},
          ),
        );

        final action = tester.getRect(find.text('Undo'));
        final dismiss = tester.getRect(find.byType(DivineIconButton));
        expect(dismiss.left, greaterThanOrEqualTo(action.right));
      });
    });

    group('light appearance', () {
      // The error label resolves through `onErrorContainer` rather than the
      // `VineTheme.error` constant, which is the dark value and holds only
      // 3.1:1 on the light error container — under the 4.5:1 floor its
      // Inter 14/600 needs as normal text.
      testWidgets('error label uses the light error token', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Error message',
            error: true,
            theme: VineTheme.lightTheme,
          ),
        );

        final text = tester.widget<Text>(find.text('Error message'));
        expect(text.style?.color, VineTheme.lightColors.onErrorContainer);
        expect(text.style?.color, isNot(VineTheme.error));
      });

      // `vineGreen` reads 1.76:1 on the light surface, so a light appearance
      // takes the dark green even without a caller-supplied background.
      testWidgets('action darkens its green on the light surface', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Copied',
            actionLabel: 'Undo',
            onActionPressed: () {},
            theme: VineTheme.lightTheme,
          ),
        );

        final text = tester.widget<Text>(find.text('Undo'));
        expect(text.style?.color, VineTheme.primaryDarkGreen);
        expect(text.style?.color, isNot(VineTheme.vineGreen));
      });
    });

    group('action placement', () {
      testWidgets('keeps a short action on the message row', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Copied',
            actionLabel: 'Undo',
            onActionPressed: () {},
          ),
        );

        final label = tester.getRect(find.text('Copied'));
        final action = tester.getRect(find.text('Undo'));
        expect(action.left, greaterThan(label.right));
        expect(action.center.dy, closeTo(label.center.dy, 1));
      });

      testWidgets('drops a long action onto its own right-aligned row', (
        tester,
      ) async {
        const message = 'We could not reach the relay just now';
        const action = 'Try that again';
        final widget = buildTestWidget(
          label: message,
          actionLabel: action,
          onActionPressed: () {},
        );

        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(widget);

        // A third of the message's own width leaves it needing four lines,
        // which is past the two it may take while sharing the row.
        final message1Line = _renderedTextSize(tester, message);
        tester.view.physicalSize = Size(
          _viewportFor(
            message1Line.width / 3,
            _renderedTextSize(tester, action).width,
          ),
          800,
        );
        await tester.pumpWidget(widget);

        expect(
          tester.getRect(find.text(action)).top,
          greaterThanOrEqualTo(tester.getRect(find.text(message)).bottom),
        );

        final banner = tester.getRect(find.byType(DecoratedBox));
        final button = tester.getRect(find.byType(TextButton));
        expect(banner.right - button.right, 16);
      });

      // The threshold is the design's two-line banner, not "the message fits
      // on one line" — a long message with a short action still wraps beside
      // it rather than spending a third row on an "Undo".
      testWidgets('keeps a short action beside a message that wraps to two '
          'lines', (tester) async {
        const message = 'We could not reach the relay just now';
        const action = 'Undo';
        final widget = buildTestWidget(
          label: message,
          actionLabel: action,
          onActionPressed: () {},
        );

        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(widget);

        // Three quarters of the message's own width: too narrow for one line,
        // wide enough for two. The old one-line measurement stacked this.
        final message1Line = _renderedTextSize(tester, message);
        tester.view.physicalSize = Size(
          _viewportFor(
            message1Line.width * 0.75,
            _renderedTextSize(tester, action).width,
          ),
          800,
        );
        await tester.pumpWidget(widget);

        final label = tester.getRect(find.text(message));
        expect(label.height, greaterThan(message1Line.height));
        expect(
          tester.getRect(find.text(action)).left,
          greaterThan(label.right),
        );
      });

      // On its own row the actions are Flexible, so one too wide even for the
      // full banner wraps inside it rather than running off the edge.
      testWidgets('wraps an over-wide action inside the banner', (
        tester,
      ) async {
        const action = 'Try reconnecting to the relay one more time now';
        final widget = buildTestWidget(
          label: 'We could not reach the relay just now',
          actionLabel: action,
          onActionPressed: () {},
        );

        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(widget);

        // Narrower than the action label alone, so it cannot fit on one line
        // even with the whole banner to itself.
        tester.view.physicalSize = Size(
          _renderedTextSize(tester, action).width * 0.7,
          800,
        );
        await tester.pumpWidget(widget);

        expect(tester.takeException(), isNull);
        final banner = tester.getRect(find.byType(DecoratedBox));
        final button = tester.getRect(find.byType(TextButton));
        expect(button.right, lessThanOrEqualTo(banner.right));
        expect(button.left, greaterThanOrEqualTo(banner.left));
      });
    });

    testWidgets('paints a custom surface colour when given one', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: DivineSnackbarContainer(
              label: 'Switched to staging',
              backgroundColor: Color(0xFF123456),
            ),
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      expect(
        (box.decoration as BoxDecoration).color,
        const Color(0xFF123456),
      );
    });

    testWidgets('a custom surface wins over the error surface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: DivineSnackbarContainer(
              label: 'Switched to production',
              error: true,
              backgroundColor: Color(0xFF123456),
            ),
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      expect(
        (box.decoration as BoxDecoration).color,
        const Color(0xFF123456),
      );
    });

    testWidgets('a light custom surface flips the label to dark ink', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: DivineSnackbarContainer(
              label: 'Switched to Staging',
              // The staging indicator yellow — white text is unreadable on it.
              backgroundColor: Color(0xFFFFF140),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Switched to Staging'));
      expect(text.style?.color, VineTheme.primaryDarkGreen);
    });

    testWidgets('a dark custom surface keeps the light label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: DivineSnackbarContainer(
              label: 'Switched to Production',
              backgroundColor: Color(0xFF123456),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Switched to Production'));
      expect(text.style?.color, VineTheme.primaryText);
    });

    testWidgets('snackBar forwards the custom surface colour', (tester) async {
      final snackBar = DivineSnackbarContainer.snackBar(
        'Switched to staging',
        backgroundColor: const Color(0xFF123456),
      );

      expect(
        (snackBar.content as DivineSnackbarContainer).backgroundColor,
        const Color(0xFF123456),
      );
    });

    group('accessibility', () {
      Widget host(ThemeData theme, {required bool error}) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: DivineSnackbarContainer(
              label: 'Upload finished',
              error: error,
              actionLabel: 'Retry',
              onActionPressed: () {},
              onDismissPressed: () {},
            ),
          ),
        ),
      );

      for (final (name, theme) in <(String, ThemeData)>[
        ('dark', VineTheme.theme),
        ('light', VineTheme.lightTheme),
      ]) {
        for (final error in [false, true]) {
          final variant = error ? 'error' : 'default';

          testWidgets('$name/$variant meets the tap-target guidelines', (
            tester,
          ) async {
            final handle = tester.ensureSemantics();
            await tester.pumpWidget(host(theme, error: error));

            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            handle.dispose();
          });

          testWidgets('$name/$variant leaves no unlabeled tappable node', (
            tester,
          ) async {
            final handle = tester.ensureSemantics();
            await tester.pumpWidget(host(theme, error: error));

            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            handle.dispose();
          });

          testWidgets('$name/$variant meets the text-contrast guideline', (
            tester,
          ) async {
            final handle = tester.ensureSemantics();
            await tester.pumpWidget(host(theme, error: error));

            await expectLater(tester, meetsGuideline(textContrastGuideline));
            handle.dispose();
          });
        }
      }
    });
  });
}
