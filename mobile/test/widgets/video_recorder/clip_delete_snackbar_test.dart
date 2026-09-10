import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/clip_delete_snackbar.dart';

/// Records [undoPendingDeletion] calls without touching the real
/// clip-manager dependencies. The base [ClipManagerNotifier.build] only
/// registers an `onDispose` hook and returns an empty state, so it is safe
/// to instantiate in isolation.
class _SpyClipManagerNotifier extends ClipManagerNotifier {
  int undoCalls = 0;

  @override
  Future<void> undoPendingDeletion() async {
    undoCalls++;
  }
}

/// Host that shows the snackbar and can navigate itself away, deactivating
/// its own [WidgetRef] while the app-level snackbar stays on screen.
class _HostPage extends ConsumerWidget {
  const _HostPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const Key('show'),
            onPressed: () => showClipDeleteSnackbar(context, ref),
            child: const Text('show'),
          ),
          ElevatedButton(
            key: const Key('navigate'),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const _OtherPage()),
            ),
            child: const Text('navigate'),
          ),
        ],
      ),
    );
  }
}

class _OtherPage extends StatelessWidget {
  const _OtherPage();

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

void main() {
  group(showClipDeleteSnackbar, () {
    late _SpyClipManagerNotifier spy;
    late String undoLabel;

    setUp(() {
      spy = _SpyClipManagerNotifier();
      undoLabel = lookupAppLocalizations(
        const Locale('en'),
      ).videoRecorderClipUndoLabel;
    });

    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [clipManagerProvider.overrideWith(() => spy)],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _HostPage(),
          ),
        ),
      );
    }

    testWidgets(
      'Undo still reaches the notifier after the host widget unmounts',
      (tester) async {
        await pumpHost(tester);

        await tester.tap(find.byKey(const Key('show')));
        await tester.pumpAndSettle();
        expect(find.text(undoLabel), findsOneWidget);

        // Navigate away: the recorder route (and its ref) is disposed while
        // the ScaffoldMessenger keeps the snackbar visible on the new route.
        await tester.tap(find.byKey(const Key('navigate')));
        await tester.pumpAndSettle();
        expect(find.byType(_HostPage), findsNothing);
        expect(find.text(undoLabel), findsOneWidget);

        await tester.tap(find.text(undoLabel));
        await tester.pump();

        // Before the fix this threw "Using ref when a widget is ... unmounted"
        // and never reached the notifier.
        expect(tester.takeException(), isNull);
        expect(spy.undoCalls, 1);
      },
    );

    testWidgets('Undo triggers the notifier on the recorder screen', (
      tester,
    ) async {
      await pumpHost(tester);

      await tester.tap(find.byKey(const Key('show')));
      await tester.pumpAndSettle();

      await tester.tap(find.text(undoLabel));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(spy.undoCalls, 1);
    });
  });
}
