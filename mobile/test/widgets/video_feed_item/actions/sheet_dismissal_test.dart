// ABOUTME: Tests for dismissing a bottom sheet and presenting a follow-up.
// ABOUTME: Runs against a real VineBottomSheet opened on a real navigator.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_feed_item/actions/sheet_dismissal.dart';

import '../../../helpers/test_provider_overrides.dart';

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.onPresent});

  final Future<void> Function(BuildContext sheetContext) onPresent;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => onPresent(context),
      child: const Text('present'),
    );
  }
}

void main() {
  group('presentAfterSheetDismiss', () {
    testWidgets('closes the sheet, then runs the presenter on a live host', (
      tester,
    ) async {
      var presenterCalls = 0;
      BuildContext? host;
      late BuildContext opener;

      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              opener = context;
              return const SizedBox();
            },
          ),
        ),
      );

      unawaited(
        VineBottomSheet.show<void>(
          context: opener,
          body: _SheetBody(
            onPresent: (sheetContext) => presentAfterSheetDismiss<void>(
              sheetContext,
              (hostContext) async {
                presenterCalls++;
                host = hostContext;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('present'), findsOneWidget);

      await tester.tap(find.text('present'));
      await tester.pumpAndSettle();

      expect(find.text('present'), findsNothing);
      expect(presenterCalls, equals(1));
      // The root navigator's context, which outlives the sheet; the sheet's
      // own context is still mounted here, so a mounted check alone would not
      // tell the two apart.
      expect(host, same(Navigator.of(opener, rootNavigator: true).context));
    });

    testWidgets('presents nothing once the sheet is already gone', (
      tester,
    ) async {
      var presenterCalls = 0;
      late BuildContext opener;
      late BuildContext sheetContext;

      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              opener = context;
              return const SizedBox();
            },
          ),
        ),
      );
      unawaited(
        VineBottomSheet.show<void>(
          context: opener,
          body: Builder(
            builder: (context) {
              sheetContext = context;
              return const Text('sheet');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(sheetContext).pop();
      await tester.pumpAndSettle();
      expect(sheetContext.mounted, isFalse);

      await presentAfterSheetDismiss<void>(sheetContext, (_) async {
        presenterCalls++;
      });

      expect(presenterCalls, equals(0));
      expect(tester.takeException(), isNull);
    });
  });
}
