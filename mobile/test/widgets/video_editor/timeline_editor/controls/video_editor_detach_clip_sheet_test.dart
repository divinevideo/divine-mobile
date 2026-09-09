// ABOUTME: Widget tests for the detach-clip chooser sheet.
// ABOUTME: Covers the options offered, the lone-clip case, and what it returns.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_detach_clip_sheet.dart';

/// Opens the sheet from a real route so the production entry point — and the
/// `context.pop` each option uses to answer — is what the test exercises.
class _Host extends StatefulWidget {
  const _Host({required this.canRemoveSlot, required this.onResult});

  final bool canRemoveSlot;
  final void Function(DetachClipChoice? choice) onResult;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          final choice = await showDetachClipSheet(
            context,
            canRemoveSlot: widget.canRemoveSlot,
          );
          widget.onResult(choice);
        },
        child: const Text('open'),
      ),
    ),
  );
}

Widget _buildSubject({
  required bool canRemoveSlot,
  required void Function(DetachClipChoice? choice) onResult,
}) => MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            _Host(canRemoveSlot: canRemoveSlot, onResult: onResult),
      ),
    ],
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('showDetachClipSheet', () {
    group('renders', () {
      testWidgets('explains what detaching does', (tester) async {
        await tester.pumpWidget(
          _buildSubject(canRemoveSlot: true, onResult: (_) {}),
        );
        await _open(tester);

        expect(find.text(l10n.videoEditorDetachTitle), findsOneWidget);
        expect(find.text(l10n.videoEditorDetachDescription), findsOneWidget);
        // Proves the copy comes from l10n rather than a hardcoded string.
        expect(
          find.text(
            lookupAppLocalizations(const Locale('de')).videoEditorDetachTitle,
          ),
          findsNothing,
        );
      });

      testWidgets('offers all three options with several clips', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSubject(canRemoveSlot: true, onResult: (_) {}),
        );
        await _open(tester);

        expect(find.text(l10n.videoEditorDetachReplaceRemove), findsOneWidget);
        expect(find.text(l10n.videoEditorDetachReplaceColor), findsOneWidget);
        expect(find.text(l10n.videoEditorDetachReplaceImage), findsOneWidget);
      });

      testWidgets('hides the close-the-gap option for a lone clip', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSubject(canRemoveSlot: false, onResult: (_) {}),
        );
        await _open(tester);

        // Closing the gap on the only clip would leave the composition with
        // no track, so the option is not offered rather than rejected.
        expect(find.text(l10n.videoEditorDetachReplaceRemove), findsNothing);
        expect(find.text(l10n.videoEditorDetachReplaceColor), findsOneWidget);
        expect(find.text(l10n.videoEditorDetachReplaceImage), findsOneWidget);
      });

      testWidgets('describes what each option leaves behind', (tester) async {
        await tester.pumpWidget(
          _buildSubject(canRemoveSlot: true, onResult: (_) {}),
        );
        await _open(tester);

        expect(
          find.text(l10n.videoEditorDetachReplaceRemoveDetail),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorDetachReplaceColorDetail),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorDetachReplaceImageDetail),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('returns removeSlot when the gap option is tapped', (
        tester,
      ) async {
        DetachClipChoice? result;
        var answered = false;
        await tester.pumpWidget(
          _buildSubject(
            canRemoveSlot: true,
            onResult: (choice) {
              result = choice;
              answered = true;
            },
          ),
        );
        await _open(tester);

        await tester.tap(find.text(l10n.videoEditorDetachReplaceRemove));
        await tester.pumpAndSettle();

        expect(answered, isTrue);
        expect(result, DetachClipChoice.removeSlot);
      });

      testWidgets('returns color when the colour option is tapped', (
        tester,
      ) async {
        DetachClipChoice? result;
        await tester.pumpWidget(
          _buildSubject(
            canRemoveSlot: true,
            onResult: (choice) => result = choice,
          ),
        );
        await _open(tester);

        await tester.tap(find.text(l10n.videoEditorDetachReplaceColor));
        await tester.pumpAndSettle();

        expect(result, DetachClipChoice.color);
      });

      testWidgets('returns image when the photo option is tapped', (
        tester,
      ) async {
        DetachClipChoice? result;
        await tester.pumpWidget(
          _buildSubject(
            canRemoveSlot: true,
            onResult: (choice) => result = choice,
          ),
        );
        await _open(tester);

        await tester.tap(find.text(l10n.videoEditorDetachReplaceImage));
        await tester.pumpAndSettle();

        expect(result, DetachClipChoice.image);
      });

      testWidgets('returns null when the sheet is dismissed', (tester) async {
        DetachClipChoice? result;
        var answered = false;
        await tester.pumpWidget(
          _buildSubject(
            canRemoveSlot: true,
            onResult: (choice) {
              result = choice;
              answered = true;
            },
          ),
        );
        await _open(tester);

        // Dismissing has to cancel the whole detach: nothing is committed
        // until the user says what fills the slot.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(answered, isTrue);
        expect(result, isNull);
      });
    });

    group('accessibility', () {
      testWidgets('announces each option with its explanation', (tester) async {
        await tester.pumpWidget(
          _buildSubject(canRemoveSlot: true, onResult: (_) {}),
        );
        await _open(tester);

        // The detail line is a second Text under the same tap target, which a
        // screen reader would otherwise read as an unrelated node.
        expect(
          find.bySemanticsLabel(
            '${l10n.videoEditorDetachReplaceColor}. '
            '${l10n.videoEditorDetachReplaceColorDetail}',
          ),
          findsOneWidget,
        );
      });
    });
  });
}
