// ABOUTME: Guards flat multi-segment routes against GoError on cold entry.
// ABOUTME: Their back buttons must use safePop, not a raw context.pop (#6481).

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/screens/settings/monetization_links_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';

/// Routes whose path has more than one segment but which are registered at the
/// top level of `GoRouter.routes`.
///
/// go_router nests by route *tree*, not by path string, so entering one of
/// these cold — an account swap re-seeds `routerInitialLocationProvider` with
/// the current location — produces a one-entry match list. `canPop()` is then
/// false and a raw `context.pop()` throws `GoError: There is nothing to pop`,
/// stranding the user on a dead back button (#6112, #6481).
const _flatMultiSegmentPaths = <String>[
  SupporterScreen.path,
  MonetizationLinksSettingsScreen.path,
  BugReportScreen.path,
  FeatureRequestScreen.path,
];

void main() {
  group('flat multi-segment routes', () {
    test('all still have more than one path segment', () {
      for (final path in _flatMultiSegmentPaths) {
        expect(
          path.split('/').where((s) => s.isNotEmpty).length,
          greaterThan(1),
          reason:
              '$path is listed as flat multi-segment but is not. Either it '
              'moved, or this guard needs updating.',
        );
      }
    });

    testWidgets('cold entry leaves nothing to pop', (tester) async {
      for (final path in _flatMultiSegmentPaths) {
        final router = GoRouter(
          initialLocation: path,
          routes: [
            GoRoute(
              path: SettingsScreen.path,
              builder: (_, _) => const Scaffold(body: Text('settings')),
            ),
            GoRoute(
              path: SupportCenterScreen.path,
              builder: (_, _) => const Scaffold(body: Text('support')),
            ),
            for (final p in _flatMultiSegmentPaths)
              GoRoute(
                path: p,
                builder: (_, _) => Scaffold(body: Text('screen:$p')),
              ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(
          router.canPop(),
          isFalse,
          reason:
              'Cold entry at $path is expected to leave a one-entry stack. If '
              'this now passes, the route was re-nested and its back button '
              'may no longer need safePop.',
        );
      }
    });
  });
}
