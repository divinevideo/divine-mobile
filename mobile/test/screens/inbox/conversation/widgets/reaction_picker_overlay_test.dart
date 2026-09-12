// ABOUTME: Widget tests for ReactionPickerOverlay.
// ABOUTME: Verifies the combined sheet renders the expected controls and
// ABOUTME: dismisses when an action is selected.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_actions_sheet.dart';
import 'package:openvine/screens/inbox/conversation/widgets/reaction_picker_overlay.dart';

import '../../../../helpers/test_provider_overrides.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> openOverlay(
    WidgetTester tester, {
    bool isSent = false,
    bool showPicker = true,
    bool isVideoShare = false,
  }) async {
    await tester.pumpWidget(
      testMaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    ReactionPickerOverlay.show(
                      context: context,
                      isSent: isSent,
                      showPicker: showPicker,
                      isVideoShare: isVideoShare,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('ReactionPickerOverlay', () {
    testWidgets('renders quick reactions and delete action for sent messages', (
      tester,
    ) async {
      await openOverlay(tester, isSent: true);

      expect(find.text('🔥'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Add custom emoji reaction'),
        findsOneWidget,
      );
      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text(l10n.dmMessageActionCopyVideoUrl), findsNothing);
      expect(find.text(l10n.shareSheetSaveVideo), findsNothing);
      expect(find.text('Delete for everyone'), findsOneWidget);
    });

    testWidgets('shows copy and save actions for a shared video', (
      tester,
    ) async {
      await openOverlay(tester, isVideoShare: true);

      expect(find.text(l10n.dmMessageActionCopyVideoUrl), findsOneWidget);
      expect(find.text(l10n.shareSheetSaveVideo), findsOneWidget);
    });

    testWidgets('returns saveVideo after selecting Save video', (tester) async {
      ReactionPickerResult? result;
      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await ReactionPickerOverlay.show(
                      context: context,
                      isSent: false,
                      isVideoShare: true,
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.shareSheetSaveVideo));
      await tester.pumpAndSettle();

      expect(result?.action, MessageAction.saveVideo);
    });

    testWidgets('dismisses after selecting a quick reaction', (tester) async {
      await openOverlay(tester);

      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();

      expect(find.text('🔥'), findsNothing);
      expect(find.text('Copy text'), findsNothing);
    });

    testWidgets('"+" affordance dismisses and pops openFullPicker', (
      tester,
    ) async {
      ReactionPickerResult? result;
      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await ReactionPickerOverlay.show(
                      context: context,
                      isSent: false,
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Add custom emoji reaction'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Add custom emoji reaction'), findsNothing);
      expect(result?.openFullPicker, isTrue);
    });

    testWidgets('"+" affordance renders a proportional 18px muted glyph', (
      tester,
    ) async {
      await openOverlay(tester);

      // The "+" sits in a 48px tap target but renders a smaller (18px) muted
      // glyph so it stays in proportion with the 28px emoji glyphs beside it,
      // not the oversized default-size icon. Regression guard keeping the
      // long-press overlay aligned with the in-player reply bar's picker.
      final plusIcon = tester.widget<DivineIcon>(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.plus,
        ),
      );
      expect(plusIcon.size, 18);
      expect(plusIcon.color, VineTheme.onSurfaceMuted);
    });

    testWidgets('omits picker row when showPicker is false', (tester) async {
      await openOverlay(tester, showPicker: false);

      expect(find.text('🔥'), findsNothing);
      expect(find.bySemanticsLabel('Add custom emoji reaction'), findsNothing);
      expect(find.text('Copy text'), findsOneWidget);
    });
  });
}
