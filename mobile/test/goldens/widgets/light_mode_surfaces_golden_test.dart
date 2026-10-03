// ABOUTME: Light-mode image references for shared controls and the Explore and
// ABOUTME: Profile chrome that frame user-generated media.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/explore/widgets/explore_tab_bar.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';

const _surfaceKey = ValueKey<String>('light-mode-surface');

void main() {
  group('light-mode surfaces', () {
    testWidgets('shared controls in light mode', (tester) async {
      await _pumpLightSurface(
        tester,
        size: const Size(390, 220),
        child: _sharedControls,
      );
      await expectLater(
        find.byKey(_surfaceKey),
        matchesGoldenFile('goldens/light_shared_controls.png'),
      );
    }, tags: ['golden']);

    testWidgets('shared controls with enlarged text in light mode', (
      tester,
    ) async {
      await _pumpLightSurface(
        tester,
        size: const Size(390, 260),
        textScale: 1.5,
        child: _sharedControls,
      );
      await expectLater(
        find.byKey(_surfaceKey),
        matchesGoldenFile('goldens/light_shared_controls_large_text.png'),
      );
    }, tags: ['golden']);

    testWidgets('Explore chrome in light mode', (tester) async {
      const tabs = ExploreTabsState(classicsAvailable: true);
      await _pumpLightSurface(
        tester,
        size: const Size(390, 180),
        child: DefaultTabController(
          length: tabs.tabCount,
          initialIndex: tabs.newVideosIndex,
          child: Builder(
            builder: (context) => Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: DivineSearchBar(hintText: 'Search...', readOnly: true),
                ),
                ColoredBox(
                  color: context.vineColors.surface,
                  child: ExploreTabBar(
                    controller: DefaultTabController.of(context),
                    tabsState: tabs,
                    onTap: _noopTab,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(_surfaceKey),
        matchesGoldenFile('goldens/light_explore_chrome.png'),
      );
    }, tags: ['golden']);

    testWidgets('Profile keeps a custom banner color in light mode', (
      tester,
    ) async {
      await _pumpLightSurface(
        tester,
        size: const Size(390, 340),
        child: const Column(
          children: [
            ProfileBanner(profileColor: Color(0xFF8568FF), height: 220),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: DivineButton(
                      label: 'My Library',
                      type: DivineButtonType.secondary,
                      onPressed: _noop,
                    ),
                  ),
                  DivineIconButton(
                    icon: DivineIconName.shareFat,
                    type: DivineIconButtonType.secondary,
                    semanticLabel: 'Share',
                    onPressed: _noop,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      await expectLater(
        find.byKey(_surfaceKey),
        matchesGoldenFile('goldens/light_profile_chrome.png'),
      );
    }, tags: ['golden']);
  });
}

void _noop() {}

void _noopTab(int _) {}

const _sharedControls = Padding(
  padding: EdgeInsets.all(20),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 16,
    children: [
      DivineSearchBar(hintText: 'Search...', readOnly: true),
      Row(
        spacing: 8,
        children: [
          Expanded(
            child: DivineButton(
              label: 'My Library',
              type: DivineButtonType.secondary,
              onPressed: _noop,
            ),
          ),
          DivineIconButton(
            icon: DivineIconName.pencilSimpleLine,
            type: DivineIconButtonType.secondary,
            semanticLabel: 'Edit',
            onPressed: _noop,
          ),
        ],
      ),
    ],
  ),
);

Future<void> _pumpLightSurface(
  WidgetTester tester, {
  required Size size,
  required Widget child,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: VineTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: RepaintBoundary(
              key: _surfaceKey,
              child: ColoredBox(
                color: VineTheme.lightColors.surface,
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pumpAndSettle();
}
