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
      var hostMounted = false;
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
                hostMounted = hostContext.mounted;
                return;
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
      expect(hostMounted, isTrue);
    });
  });
}
