import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/ui/back_on_escape.dart';
import 'package:openvine/ui/feed_keyboard_shortcuts.dart';
import 'package:openvine/ui/macos_menu_bar.dart';

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

/// Records the menus a [PlatformMenuBar] hands to the platform.
class _RecordingMenuDelegate extends PlatformMenuDelegate {
  List<PlatformMenuItem> menus = const [];

  @override
  void setMenus(List<PlatformMenuItem> topLevelMenus) => menus = topLevelMenus;

  @override
  void clearMenus() => menus = const [];

  @override
  bool debugLockDelegate(BuildContext context) => true;

  @override
  bool debugUnlockDelegate(BuildContext context) => true;
}

final _macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  group(MacosMenuBar, () {
    late PlatformMenuDelegate originalDelegate;
    late _RecordingMenuDelegate menuDelegate;
    late _MockVideoVolumeCubit volumeCubit;
    late StreamController<VideoVolumeState> volumeStates;
    late int supportCenterOpenings;

    setUp(() {
      originalDelegate = WidgetsBinding.instance.platformMenuDelegate;
      menuDelegate = _RecordingMenuDelegate();
      WidgetsBinding.instance.platformMenuDelegate = menuDelegate;
      volumeCubit = _MockVideoVolumeCubit();
      volumeStates = StreamController<VideoVolumeState>.broadcast();
      whenListen(
        volumeCubit,
        volumeStates.stream,
        initialState: const VideoVolumeState(),
      );
      supportCenterOpenings = 0;
    });

    tearDown(() async {
      WidgetsBinding.instance.platformMenuDelegate = originalDelegate;
      await volumeStates.close();
    });

    Future<void> pumpMenuBar(WidgetTester tester, Widget home) async {
      await tester.pumpWidget(
        BlocProvider<VideoVolumeCubit>.value(
          value: volumeCubit,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MacosMenuBar(
              onOpenSupportCenter: () => supportCenterOpenings++,
              child: Scaffold(body: home),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    PlatformMenu menu(String label) => menuDelegate.menus
        .whereType<PlatformMenu>()
        .singleWhere((menu) => menu.label == label);

    /// Every selectable item of [menu], with groups flattened.
    List<PlatformMenuItem> items(PlatformMenu menu) => [
      for (final entry in menu.menus)
        if (entry is PlatformMenuItemGroup) ...entry.members else entry,
    ];

    void select(PlatformMenu menu, String label) => items(
      menu,
    ).singleWhere((item) => item.label == label).onSelected!();

    AppLocalizations l10n(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(Scaffold)));

    testWidgets('shows the app, Edit, View, Video, Window and Help menus', (
      tester,
    ) async {
      await pumpMenuBar(tester, const SizedBox.expand());
      final strings = l10n(tester);

      expect(
        menuDelegate.menus.map((menu) => menu.label),
        equals([
          'Divine',
          strings.menuBarEdit,
          strings.menuBarView,
          strings.menuBarVideo,
          strings.menuBarWindow,
          strings.menuBarHelp,
        ]),
      );
    }, variant: _macOS);

    testWidgets('the Video menu runs the feed commands where the focus is', (
      tester,
    ) async {
      final invoked = <Intent>[];
      Action<T> record<T extends Intent>() =>
          CallbackAction<T>(onInvoke: invoked.add);
      await pumpMenuBar(
        tester,
        Actions(
          actions: {
            PreviousVideoIntent: record<PreviousVideoIntent>(),
            NextVideoIntent: record<NextVideoIntent>(),
            TogglePlaybackIntent: record<TogglePlaybackIntent>(),
            ToggleMuteIntent: record<ToggleMuteIntent>(),
            GoBackIntent: record<GoBackIntent>(),
          },
          child: const Focus(autofocus: true, child: SizedBox.expand()),
        ),
      );
      await tester.pump();
      final strings = l10n(tester);
      final video = menu(strings.menuBarVideo);

      select(video, strings.menuBarPreviousVideo);
      select(video, strings.menuBarNextVideo);
      select(video, strings.menuBarPlayPause);
      select(video, strings.menuBarMute);
      final back = items(video).singleWhere(
        (item) => item.label == strings.commonBack,
      );
      expect(back.shortcut, isNull);
      back.onSelected!();

      expect(
        invoked.map((intent) => intent.runtimeType),
        equals([
          PreviousVideoIntent,
          NextVideoIntent,
          TogglePlaybackIntent,
          ToggleMuteIntent,
          GoBackIntent,
        ]),
      );
    }, variant: _macOS);

    testWidgets('offers to unmute while muted', (tester) async {
      await pumpMenuBar(tester, const SizedBox.expand());
      final strings = l10n(tester);
      expect(
        items(menu(strings.menuBarVideo)).map((item) => item.label),
        contains(strings.menuBarMute),
      );

      when(() => volumeCubit.state)
          .thenReturn(const VideoVolumeState(volume: 0));
      volumeStates.add(const VideoVolumeState(volume: 0));
      await tester.pumpAndSettle();

      expect(
        items(menu(strings.menuBarVideo)).map((item) => item.label),
        allOf(
          contains(strings.menuBarUnmute),
          isNot(contains(strings.menuBarMute)),
        ),
      );
    }, variant: _macOS);

    testWidgets('the Edit menu works on the focused text field', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'hello');
      addTearDown(controller.dispose);
      await pumpMenuBar(
        tester,
        TextField(controller: controller, autofocus: true),
      );
      await tester.pump();
      final strings = l10n(tester);

      select(menu(strings.menuBarEdit), strings.menuBarSelectAll);
      await tester.pump();

      expect(
        controller.selection,
        equals(
          const TextSelection(baseOffset: 0, extentOffset: 'hello'.length),
        ),
      );
    }, variant: _macOS);

    testWidgets('the Help menu opens the support center', (tester) async {
      await pumpMenuBar(tester, const SizedBox.expand());
      final strings = l10n(tester);

      select(menu(strings.menuBarHelp), strings.supportTitle);

      expect(supportCenterOpenings, equals(1));
    }, variant: _macOS);

    testWidgets('leaves the menu bar alone on other platforms', (
      tester,
    ) async {
      await pumpMenuBar(tester, const SizedBox.expand());

      expect(find.byType(PlatformMenuBar), findsNothing);
      expect(menuDelegate.menus, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });
}
