// ABOUTME: Boots the real app on a device and proves that a widget which
// ABOUTME: throws during build is replaced by the branded "tangled vine" surface
// ABOUTME: main() installs as ErrorWidget.builder (#8647).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/widgets/global_error_widget.dart';

import '../helpers/test_setup.dart';

/// A page whose build always fails, pushed on top of whatever the app shows.
class _ThrowsOnBuild extends StatelessWidget {
  const _ThrowsOnBuild();

  @override
  Widget build(BuildContext context) {
    throw StateError('#8647: deliberate widget build failure');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorWidget.builder installed by main()', () {
    testWidgets(
      'a widget that throws during build renders the tangled vine surface',
      (tester) async {
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));

        launchAppGuarded(app.main);

        // The blocking startup sequence ends in runApp; the root navigator
        // exists once the router has built. pumpAndSettle never returns here
        // because the app keeps polling timers alive.
        var navigator = NavigatorKeys.root.currentState;
        for (var i = 0; i < 120 && navigator == null; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          navigator = NavigatorKeys.root.currentState;
        }
        expect(
          navigator,
          isNotNull,
          reason: 'the app never reached its root navigator',
        );

        unawaited(
          navigator!.push(
            MaterialPageRoute<void>(builder: (_) => const _ThrowsOnBuild()),
          ),
        );
        await pumpUntilSettled(tester, maxSeconds: 2);

        final showsStartupSurface = find
            .text('Oops, something went wrong')
            .evaluate()
            .isNotEmpty;
        expect(
          find.text('got a bit tangled'),
          findsOneWidget,
          reason:
              'the branded error surface must replace the failing widget '
              '(minimal startup surface rendered instead: '
              '$showsStartupSurface)',
        );
        expect(
          ErrorWidget.builder,
          same(buildGlobalErrorWidget),
          reason: 'main() must install buildGlobalErrorWidget',
        );

        navigator.pop();
        await pumpUntilSettled(tester, maxSeconds: 1);

        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
