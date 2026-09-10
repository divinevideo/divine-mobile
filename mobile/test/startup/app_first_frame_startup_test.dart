import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/app/startup/startup_coordinator.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

class _FirstFrameStartupHarness extends StatefulWidget {
  const _FirstFrameStartupHarness({required this.startDeferredStartup});

  final Future<void> Function() startDeferredStartup;

  @override
  State<_FirstFrameStartupHarness> createState() =>
      _FirstFrameStartupHarnessState();
}

class _FirstFrameStartupHarnessState extends State<_FirstFrameStartupHarness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.startDeferredStartup());
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Text('first-frame-shell')),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(StartupCoordinator, () {
    testWidgets('renders the first frame before deferred startup completes', (
      tester,
    ) async {
      final coordinator = StartupCoordinator();
      final deferredStarted = Completer<void>();
      final deferredCompleter = Completer<void>();

      coordinator.registerService(
        name: 'EnvironmentService',
        phase: StartupPhase.critical,
        initialize: () async {},
      );
      coordinator.registerService(
        name: 'DeferredWarmup',
        phase: StartupPhase.deferred,
        initialize: () async {
          deferredStarted.complete();
          await deferredCompleter.future;
        },
      );

      await coordinator.initializeThrough(StartupPhase.critical);

      await tester.pumpWidget(
        _FirstFrameStartupHarness(
          startDeferredStartup: coordinator.initializeRemaining,
        ),
      );

      expect(find.text('first-frame-shell'), findsOneWidget);

      await tester.pump();

      expect(find.text('first-frame-shell'), findsOneWidget);
      expect(deferredStarted.isCompleted, isTrue);
      expect(deferredCompleter.isCompleted, isFalse);
    });
  });
}
