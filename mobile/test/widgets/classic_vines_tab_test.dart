// Regression test for issue #6157: ClassicVinesTab._refreshClassics used `ref`
// after `await` gaps without a `mounted` guard. If the tab was disposed while a
// throttled-network refresh was still in flight, the resumed refresh called
// `ref.invalidate` on the unmounted widget and threw
// `Bad state: Using "ref" when a widget ... has been unmounted is unsafe`.
//
// This drives the REAL ClassicVinesTab: its empty/unavailable auto-refresh fires
// `_refreshClassics`, which is then held mid-`await` on a gated funnelcake future.
// The tree is disposed, then the future is completed so `_refreshClassics` resumes
// on a disposed widget. Without the guard this fails with the StateError above
// (flutter_test surfaces the unhandled async error); with the guard the refresh
// returns cleanly.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/classic_vines_tab.dart';

// A funnelcake future the test controls, so it can dispose the widget while
// `_refreshClassics` is suspended on `await ref.read(funnelcakeAvailableProvider.future)`.
late Completer<bool> availabilityGate;
int funnelcakeBuildCount = 0;

class _ControlledFunnelcakeAvailable extends FunnelcakeAvailable {
  @override
  Future<bool> build() async {
    funnelcakeBuildCount++;
    // First build resolves false so ClassicVinesTab renders its unavailable
    // state, whose autoRefresh fires _refreshClassics. Once _refreshClassics
    // calls refresh() -> invalidateSelf, the next build stays pending on the
    // gate, holding the widget in the disposal-vulnerable await.
    if (funnelcakeBuildCount == 1) return false;
    return availabilityGate.future;
  }
}

class _EmptyClassicVinesFeed extends ClassicVinesFeed {
  @override
  Future<VideoFeedState> build() async =>
      const VideoFeedState(videos: [], hasMoreContent: false);
}

Widget _host() => ProviderScope(
  overrides: [
    funnelcakeAvailableProvider.overrideWith(
      _ControlledFunnelcakeAvailable.new,
    ),
    classicVinesFeedProvider.overrideWith(_EmptyClassicVinesFeed.new),
  ],
  child: const MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ClassicVinesTab()),
  ),
);

void main() {
  group(ClassicVinesTab, () {
    testWidgets(
      'ClassicVinesTab does not throw when disposed mid-refresh (#6157)',
      (tester) async {
        availabilityGate = Completer<bool>();
        funnelcakeBuildCount = 0;

        await tester.pumpWidget(_host());
        // Resolve providers, render the unavailable state, then run the post-frame
        // autoRefresh -> _refreshClassics -> funnelcake refresh() -> await the
        // (now gated, pending) funnelcake future.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        // The refresh must actually be in flight: _refreshClassics invalidated
        // funnelcake, triggering a second (pending) build.
        expect(
          funnelcakeBuildCount,
          greaterThanOrEqualTo(2),
          reason: '_refreshClassics should have re-invalidated funnelcake',
        );

        // Dispose the tree while _refreshClassics is suspended on the future.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        // Completing the future resumes _refreshClassics after the widget is gone.
        // Without the mounted guard, ref.invalidate throws an unhandled StateError
        // that flutter_test surfaces as a test failure; with it, the refresh bails.
        availabilityGate.complete(false);
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));

        expect(tester.takeException(), isNull);
      },
    );
  });
}
