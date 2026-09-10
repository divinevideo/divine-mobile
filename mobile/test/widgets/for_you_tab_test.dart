// Pins the For You header's accessibility contract (#6852): the header strip
// is a single labelled button rather than a silent tap region wrapped around a
// second labelled button, and activating it opens the algorithm explainer.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/for_you_tab.dart';

import '../helpers/test_provider_overrides.dart';

class _AvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

class _EmptyForYouFeed extends ForYouFeed {
  @override
  Future<VideoFeedState> build() async =>
      const VideoFeedState(videos: [], hasMoreContent: false);
}

Widget _host({double textScale = 1}) => ProviderScope(
  overrides: [
    funnelcakeAvailableProvider.overrideWith(_AvailableFunnelcake.new),
    forYouFeedProvider.overrideWith(_EmptyForYouFeed.new),
    // ForYouTab hosts a ComposableVideoGrid, which resolves the viewer's
    // pubkey through the auth service to decide per-video ownership.
    sharedPreferencesProvider.overrideWithValue(createMockSharedPreferences()),
    authServiceProvider.overrideWithValue(createMockAuthService()),
    nostrServiceProvider.overrideWithValue(createMockNostrService()),
  ],
  child: MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: const Scaffold(body: ForYouTab()),
      ),
    ),
  ),
);

/// Narrowest screen the app targets, where the header has the least room.
const _narrowWidth = 320.0;

void _useNarrowScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(_narrowWidth, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(ForYouTab, () {
    testWidgets('header is one button named by its visible title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text(l10n.forYouAlgorithmTitle)),
        isSemantics(
          isButton: true,
          label: l10n.forYouAlgorithmTitle,
          hint: l10n.forYouAlgorithmHowItWorksTitle,
        ),
      );

      // The info icon opens the same sheet as the row, so it contributes no
      // node of its own — walking up from it lands on the header's button
      // rather than a second one announcing the same action.
      expect(
        tester.getSemantics(find.byType(DivineIconButton)),
        isSemantics(label: l10n.forYouAlgorithmTitle),
      );

      handle.dispose();
    });

    testWidgets('tapping the header opens the algorithm explainer', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // The subtitle renders only inside the explainer sheet, so it proves the
      // sheet opened instead of matching something in the header strip.
      expect(find.text(l10n.forYouAlgorithmSubtitle), findsNothing);

      await tester.tap(find.text(l10n.forYouAlgorithmTitle));
      await tester.pumpAndSettle();

      expect(find.text(l10n.forYouAlgorithmSubtitle), findsOneWidget);
    });

    // The largest scale is deliberate: at the default scale the title's
    // measured width depends on which font resolves in the test environment,
    // so that case would report on font loading rather than on layout.
    // Asserting geometry rather than a caught overflow exception keeps this
    // independent of the debug-only overflow reporter.
    testWidgets('header keeps the info button on screen at the largest text '
        'scale', (tester) async {
      _useNarrowScreen(tester);

      await tester.pumpWidget(_host(textScale: 3));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(DivineIconButton)).right,
        lessThanOrEqualTo(_narrowWidth),
      );
    });
  });
}
