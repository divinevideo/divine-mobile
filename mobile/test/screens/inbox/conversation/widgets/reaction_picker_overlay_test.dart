// ABOUTME: Widget tests for ReactionPickerOverlay.
// ABOUTME: Verifies the combined sheet renders the expected controls and
// ABOUTME: dismisses when an action is selected.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
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
    bool isEncryptedVideo = false,
    SenderBlockOption? senderBlock,
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
                      isEncryptedVideo: isEncryptedVideo,
                      senderBlock: senderBlock,
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

    testWidgets('shows play and save actions for an encrypted video', (
      tester,
    ) async {
      await openOverlay(tester, isEncryptedVideo: true);

      expect(find.text(l10n.videoPlayerPlayVideo), findsOneWidget);
      expect(find.text(l10n.shareSheetSaveVideo), findsOneWidget);
      expect(find.text(l10n.dmMessageActionCopyVideoUrl), findsNothing);
    });

    testWidgets('offers no copy action for an encrypted video', (tester) async {
      await openOverlay(tester, isEncryptedVideo: true);

      // Copy text would place the ciphertext URL on the clipboard, which the
      // encrypted card deliberately never renders.
      expect(find.text(l10n.dmMessageActionCopyText), findsNothing);
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

    testWidgets('returns addToClips when adding to clips is offered', (
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
                      isEncryptedVideo: true,
                      canAddToClips: true,
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

      await tester.tap(find.text(l10n.shareSheetAddToClips));
      await tester.pumpAndSettle();

      expect(result?.action, MessageAction.addToClips);
    });

    testWidgets('offers no add-to-clips action unless it is offered', (
      tester,
    ) async {
      await openOverlay(tester, isEncryptedVideo: true);

      expect(find.text(l10n.shareSheetAddToClips), findsNothing);
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

    group('sender block row', () {
      const alice = SenderBlockOption(displayName: 'Alice', isBlocked: false);
      const blockedAlice = SenderBlockOption(
        displayName: 'Alice',
        isBlocked: true,
      );

      Finder blockRows() => find.textContaining(l10n.inboxActionBlock(''));
      Finder unblockRows() => find.textContaining(l10n.inboxActionUnblock(''));

      DivineIconName iconOf(WidgetTester tester, String label) => tester
          .widget<DivineIcon>(
            find.descendant(
              of: find.ancestor(
                of: find.text(label),
                matching: find.byType(ListTile),
              ),
              matching: find.byType(DivineIcon),
            ),
          )
          .icon;

      Future<ReactionPickerResult?> tapRow(
        WidgetTester tester,
        SenderBlockOption option,
        String label,
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
                        senderBlock: option,
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
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        return result;
      }

      testWidgets('is absent unless a sender is passed', (tester) async {
        await openOverlay(tester);

        // Report is on screen, so the list rendered and Block is not merely
        // hidden behind a missing sheet.
        expect(find.text(l10n.dmMessageActionReport), findsOneWidget);
        expect(blockRows(), findsNothing);
        expect(unblockRows(), findsNothing);
      });

      testWidgets('offers Block <name> beside Report', (tester) async {
        await openOverlay(tester, senderBlock: alice);

        expect(find.text(l10n.inboxActionBlock('Alice')), findsOneWidget);
        expect(find.text(l10n.dmMessageActionReport), findsOneWidget);
        expect(unblockRows(), findsNothing);
        expect(
          iconOf(tester, l10n.inboxActionBlock('Alice')),
          DivineIconName.prohibit,
        );
      });

      testWidgets('offers Unblock <name> for an already blocked member', (
        tester,
      ) async {
        await openOverlay(tester, senderBlock: blockedAlice);

        expect(find.text(l10n.inboxActionUnblock('Alice')), findsOneWidget);
        expect(blockRows(), findsNothing);
        expect(
          iconOf(tester, l10n.inboxActionUnblock('Alice')),
          DivineIconName.prohibitInset,
        );
      });

      testWidgets('does not name a deleted account by its stand-in label', (
        tester,
      ) async {
        final deletedName = l10n.profileDeletedAccountName;
        await openOverlay(
          tester,
          senderBlock: SenderBlockOption(
            displayName: deletedName,
            isBlocked: false,
            isVanished: true,
          ),
        );

        expect(
          find.text(l10n.inboxActionBlockVanishedAccount),
          findsOneWidget,
        );
        expect(find.textContaining(deletedName), findsNothing);
      });

      testWidgets('offers Unblock this account for a blocked deleted account', (
        tester,
      ) async {
        await openOverlay(
          tester,
          senderBlock: SenderBlockOption(
            displayName: l10n.profileDeletedAccountName,
            isBlocked: true,
            isVanished: true,
          ),
        );

        expect(
          find.text(l10n.inboxActionUnblockVanishedAccount),
          findsOneWidget,
        );
      });

      testWidgets('returns blockSender after selecting Block', (tester) async {
        final result = await tapRow(
          tester,
          alice,
          l10n.inboxActionBlock('Alice'),
        );

        expect(result?.action, MessageAction.blockSender);
      });

      testWidgets('returns unblockSender after selecting Unblock', (
        tester,
      ) async {
        final result = await tapRow(
          tester,
          blockedAlice,
          l10n.inboxActionUnblock('Alice'),
        );

        expect(result?.action, MessageAction.unblockSender);
      });
    });

    testWidgets('omits picker row when showPicker is false', (tester) async {
      await openOverlay(tester, showPicker: false);

      expect(find.text('🔥'), findsNothing);
      expect(find.bySemanticsLabel('Add custom emoji reaction'), findsNothing);
      expect(find.text('Copy text'), findsOneWidget);
    });
  });
}
