// ABOUTME: Tests for VineBottomSheetPrompt component
// ABOUTME: Verifies rendering, button interactions, and modal behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 1×1 transparent PNG bytes (from Flutter's test suite).
final _transparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
  0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
  0x42, 0x60, 0x82,
]);

class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle() {
    final manifest = <String, List<Map<String, Object>>>{
      for (final sticker in DivineStickerName.values)
        sticker.assetPath: [
          <String, Object>{'asset': sticker.assetPath},
        ],
    };
    _manifest = const StandardMessageCodec().encodeMessage(manifest)!;
  }

  late final ByteData _manifest;
  final ByteData _imageData = ByteData.sublistView(_transparentPng);

  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') {
      return SynchronousFuture<ByteData>(_manifest);
    }
    return SynchronousFuture<ByteData>(_imageData);
  }
}

// Matches the unkeyed 64x4 rounded Container the header paints as the drag
// handle. Asserting the rendered tree, rather than the forwarded
// showDragHandle flag, is what catches a header that stops honouring it.
final Finder _dragHandle = find.byWidgetPredicate((widget) {
  if (widget is! Container) return false;
  final constraints = widget.constraints;
  return constraints?.maxWidth == 64 && constraints?.maxHeight == 4;
});

void main() {
  late _TestAssetBundle bundle;

  setUp(() {
    bundle = _TestAssetBundle();
  });

  Widget buildSubject({
    DivineStickerName sticker = DivineStickerName.skeletonKey,
    String title = 'Test Title',
    String subtitle = 'Test subtitle text',
    String? additionalText,
    String? primaryButtonText,
    VoidCallback? onPrimaryPressed,
    DivineButtonType primaryButtonType = DivineButtonType.primary,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
    String? tertiaryButtonText,
    VoidCallback? onTertiaryPressed,
  }) {
    return MaterialApp(
      home: DefaultAssetBundle(
        bundle: bundle,
        child: Scaffold(
          body: VineBottomSheetPrompt(
            sticker: sticker,
            title: title,
            subtitle: subtitle,
            additionalText: additionalText,
            primaryButtonText: primaryButtonText,
            onPrimaryPressed: onPrimaryPressed,
            primaryButtonType: primaryButtonType,
            secondaryButtonText: secondaryButtonText,
            onSecondaryPressed: onSecondaryPressed,
            tertiaryButtonText: tertiaryButtonText,
            onTertiaryPressed: onTertiaryPressed,
          ),
        ),
      ),
    );
  }

  group(VineBottomSheetPrompt, () {
    group('renders', () {
      testWidgets('sticker illustration', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(DivineSticker), findsOneWidget);
      });

      testWidgets('title text', (tester) async {
        await tester.pumpWidget(
          buildSubject(title: 'Allow camera access'),
        );

        expect(find.text('Allow camera access'), findsOneWidget);
      });

      testWidgets('subtitle text', (tester) async {
        await tester.pumpWidget(
          buildSubject(subtitle: 'Capture and edit videos'),
        );

        expect(find.text('Capture and edit videos'), findsOneWidget);
      });

      testWidgets('primary button when provided', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            primaryButtonText: 'Go',
            onPrimaryPressed: () {},
          ),
        );

        expect(find.text('Go'), findsOneWidget);
      });

      testWidgets('secondary button when provided', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            secondaryButtonText: 'Cancel',
            onSecondaryPressed: () {},
          ),
        );

        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('additional text when provided', (tester) async {
        await tester.pumpWidget(
          buildSubject(additionalText: 'Enable in Settings'),
        );

        expect(find.text('Enable in Settings'), findsOneWidget);
      });

      testWidgets('no additional text when null', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('Test Title'), findsOneWidget);
        expect(find.text('Test subtitle text'), findsOneWidget);
      });

      testWidgets('no buttons when all null', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(DivineButton), findsNothing);
      });

      testWidgets('only primary button', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            primaryButtonText: 'OK',
            onPrimaryPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
      });

      testWidgets('only secondary button', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            secondaryButtonText: 'Skip',
            onSecondaryPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
      });

      testWidgets('only tertiary button', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            tertiaryButtonText: 'Learn more',
            onTertiaryPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
        expect(find.text('Learn more'), findsOneWidget);
      });

      testWidgets('primary button with default type', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            primaryButtonText: 'OK',
            onPrimaryPressed: () {},
          ),
        );

        final button = tester.widget<DivineButton>(find.byType(DivineButton));
        expect(button.type, equals(DivineButtonType.primary));
      });

      testWidgets('primary button with error type', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            primaryButtonText: 'Delete',
            onPrimaryPressed: () {},
            primaryButtonType: DivineButtonType.error,
          ),
        );

        final button = tester.widget<DivineButton>(find.byType(DivineButton));
        expect(button.type, equals(DivineButtonType.error));
      });

      testWidgets('all three buttons', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            primaryButtonText: 'Continue',
            onPrimaryPressed: () {},
            secondaryButtonText: 'Not now',
            onSecondaryPressed: () {},
            tertiaryButtonText: 'Learn more',
            onTertiaryPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsNWidgets(3));
      });
    });

    group('interactions', () {
      testWidgets('calls onPrimaryPressed when primary button tapped', (
        tester,
      ) async {
        var primaryTapped = false;

        await tester.pumpWidget(
          buildSubject(
            primaryButtonText: 'Continue',
            onPrimaryPressed: () => primaryTapped = true,
          ),
        );

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(primaryTapped, isTrue);
      });

      testWidgets('calls onSecondaryPressed when secondary button tapped', (
        tester,
      ) async {
        var secondaryTapped = false;

        await tester.pumpWidget(
          buildSubject(
            secondaryButtonText: 'Not now',
            onSecondaryPressed: () => secondaryTapped = true,
          ),
        );

        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();

        expect(secondaryTapped, isTrue);
      });

      testWidgets('calls onTertiaryPressed when tertiary button tapped', (
        tester,
      ) async {
        var tertiaryTapped = false;

        await tester.pumpWidget(
          buildSubject(
            tertiaryButtonText: 'Learn more',
            onTertiaryPressed: () => tertiaryTapped = true,
          ),
        );

        await tester.tap(find.text('Learn more'));
        await tester.pumpAndSettle();

        expect(tertiaryTapped, isTrue);
      });
    });

    group('show', () {
      testWidgets('shows as modal bottom sheet', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DefaultAssetBundle(
              bundle: bundle,
              child: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheetPrompt.show<void>(
                        context: context,
                        sticker: DivineStickerName.alert,
                        title: 'Modal Title',
                        subtitle: 'Modal subtitle',
                        primaryButtonText: 'OK',
                        onPrimaryPressed: () {},
                        secondaryButtonText: 'Cancel',
                        onSecondaryPressed: () => Navigator.pop(context),
                      );
                    },
                    child: const Text('Show Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Modal Title'), findsOneWidget);
        expect(find.text('Modal subtitle'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('shows with additional text', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DefaultAssetBundle(
              bundle: bundle,
              child: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheetPrompt.show<void>(
                        context: context,
                        sticker: DivineStickerName.alert,
                        title: 'Title',
                        subtitle: 'Subtitle',
                        additionalText: 'Extra info',
                        primaryButtonText: 'OK',
                        onPrimaryPressed: () {},
                        secondaryButtonText: 'Cancel',
                        onSecondaryPressed: () {},
                      );
                    },
                    child: const Text('Show Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Extra info'), findsOneWidget);
      });

      testWidgets('shows with tertiary button', (tester) async {
        var tertiaryTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: DefaultAssetBundle(
              bundle: bundle,
              child: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheetPrompt.show<void>(
                        context: context,
                        sticker: DivineStickerName.alert,
                        title: 'Title',
                        subtitle: 'Subtitle',
                        primaryButtonText: 'OK',
                        onPrimaryPressed: () {},
                        secondaryButtonText: 'Cancel',
                        onSecondaryPressed: () {},
                        tertiaryButtonText: 'Skip',
                        onTertiaryPressed: () => tertiaryTapped = true,
                      );
                    },
                    child: const Text('Show Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Skip'), findsOneWidget);

        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(tertiaryTapped, isTrue);
      });

      testWidgets('dismisses when tapping outside', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DefaultAssetBundle(
              bundle: bundle,
              child: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheetPrompt.show<void>(
                        context: context,
                        sticker: DivineStickerName.alert,
                        title: 'Dismissable',
                        subtitle: 'Tap outside',
                        primaryButtonText: 'OK',
                        onPrimaryPressed: () {},
                        secondaryButtonText: 'Cancel',
                        onSecondaryPressed: () {},
                      );
                    },
                    child: const Text('Show Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Dismissable'), findsOneWidget);

        // Tap outside the sheet to dismiss
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Dismissable'), findsNothing);
      });

      testWidgets(
        'stays open when isDismissible and enableDrag are false',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: DefaultAssetBundle(
                bundle: bundle,
                child: Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () async {
                        await VineBottomSheetPrompt.show<void>(
                          context: context,
                          sticker: DivineStickerName.alert,
                          title: 'Locked',
                          subtitle: 'Pick an action',
                          primaryButtonText: 'OK',
                          onPrimaryPressed: () {},
                          secondaryButtonText: 'Cancel',
                          onSecondaryPressed: () {},
                          isDismissible: false,
                          enableDrag: false,
                        );
                      },
                      child: const Text('Show Sheet'),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Show Sheet'));
          await tester.pumpAndSettle();

          expect(find.text('Locked'), findsOneWidget);

          // A barrier tap above the sheet must not dismiss it.
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          expect(find.text('Locked'), findsOneWidget);

          // enableDrag is threaded through to the modal so a downward drag
          // can't dismiss it either. The framework gates drag-dismissal on
          // BottomSheet.enableDrag; assert the forwarded flag directly, since
          // a simulated fling inside the scroll body is gesture-arena-flaky.
          final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
          expect(sheet.enableDrag, isFalse);
          expect(_dragHandle, findsNothing);
        },
      );
    });
  });
}
