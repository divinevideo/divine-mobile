import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/widgets/video_editor/effects_editor/video_editor_effects_bottom_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoEffectType;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoEditorEffectsBottomBar, () {
    late VideoEditorEffectsCubit cubit;

    setUp(() => cubit = VideoEditorEffectsCubit()..startEditing());
    tearDown(() => cubit.close());

    /// [navigationBarHeight] is the system navigation bar the bar reaches
    /// under, set inside the Scaffold, which adjusts the padding it hands its
    /// body.
    Widget buildWidget({
      double textScale = 1,
      double navigationBarHeight = 0,
      bool reduceMotion = false,
    }) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  viewPadding: EdgeInsets.only(bottom: navigationBarHeight),
                  disableAnimations: reduceMotion,
                ),
                child: Align(
                  alignment: .bottomCenter,
                  child: BlocProvider.value(
                    value: cubit,
                    child: const VideoEditorEffectsBottomBar(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    void usePhoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(402, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    final categoryLabels = {
      EditorEffectCategory.retro: l10n.videoEditorEffectCategoryRetro,
      EditorEffectCategory.art: l10n.videoEditorEffectCategoryArt,
      EditorEffectCategory.glitch: l10n.videoEditorEffectCategoryGlitch,
      EditorEffectCategory.distort: l10n.videoEditorEffectCategoryDistort,
      EditorEffectCategory.light: l10n.videoEditorEffectCategoryLight,
      EditorEffectCategory.motion: l10n.videoEditorEffectCategoryMotion,
      EditorEffectCategory.time: l10n.videoEditorEffectCategoryTime,
      EditorEffectCategory.particles: l10n.videoEditorEffectCategoryParticles,
      EditorEffectCategory.looks: l10n.videoEditorEffectCategoryLooks,
      EditorEffectCategory.intro: l10n.videoEditorEffectCategoryIntro,
      EditorEffectCategory.outro: l10n.videoEditorEffectCategoryOutro,
    };

    Finder grid() => find.byType(CustomScrollView);

    Finder tab(EditorEffectCategory category) => find.descendant(
      of: find.byType(TabBar),
      matching: find.text(categoryLabels[category]!),
    );

    // Titles and tiles can share a name: the Glitch section holds the Glitch
    // effect.
    // Offstage too: a title just scrolled out above the grid is still laid
    // out, and the scroll test measures it there.
    Finder header(EditorEffectCategory category) => find.descendant(
      of: find.byType(SliverToBoxAdapter, skipOffstage: false),
      matching: find.text(categoryLabels[category]!, skipOffstage: false),
      skipOffstage: false,
    );

    Finder tile(String label) => find.descendant(
      of: find.byType(SliverGrid),
      matching: find.text(label),
    );

    bool isTabHighlighted(WidgetTester tester, EditorEffectCategory category) =>
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index ==
        category.index;

    bool tabsCastShadow(WidgetTester tester) =>
        tester
            .widget<AnimatedOpacity>(
              find.descendant(
                of: find.byType(VideoEditorEffectsBottomBar),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity ==
        1;

    /// Scrolls the grid by [dy] with a finger that stops before it lifts, so
    /// the grid does not fling on past the target.
    Future<void> scrollGridBy(WidgetTester tester, double dy) async {
      final gesture = await tester.startGesture(tester.getCenter(grid()));
      await gesture.moveBy(Offset(0, dy.sign * kDragSlopDefault));
      await gesture.moveBy(Offset(0, dy));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    Future<void> tapTab(
      WidgetTester tester,
      EditorEffectCategory category,
    ) async {
      await tester.ensureVisible(tab(category));
      await tester.pumpAndSettle();
      await tester.tap(tab(category));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a category scrolls to its section, highlights it and '
        'shows its effects under its title', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(buildWidget());
      final context = tester.element(find.byType(VideoEditorEffectsBottomBar));
      final gridRect = tester.getRect(grid());

      for (final category in EditorEffectCategory.values) {
        await tapTab(tester, category);

        expect(isTabHighlighted(tester, category), isTrue);
        for (final other in EditorEffectCategory.values) {
          if (other != category) {
            expect(isTabHighlighted(tester, other), isFalse);
          }
        }
        final title = tester.getRect(header(category));
        final position = tester
            .widget<CustomScrollView>(grid())
            .controller!
            .position;
        // The last sections are too short to scroll to the top: their jump
        // stops at the end of the grid.
        if (position.pixels < position.maxScrollExtent) {
          expect(title.top - gridRect.top, inInclusiveRange(0, 10));
        }
        final nextIndex = category.index + 1;
        final next = nextIndex < EditorEffectCategory.values.length
            ? header(EditorEffectCategory.values[nextIndex])
            : null;
        for (final type in category.types) {
          final label = videoEffectLabel(context, type);
          final rect = tester.getRect(tile(label));
          expect(gridRect.contains(rect.center), isTrue, reason: label);
          expect(rect.top, greaterThanOrEqualTo(title.bottom), reason: label);
          if (next != null && tester.any(next)) {
            expect(
              rect.bottom,
              lessThanOrEqualTo(tester.getRect(next).top),
              reason: label,
            );
          }
        }
      }
    });

    testWidgets('makes every category a full-size tap target', (tester) async {
      await tester.pumpWidget(buildWidget());

      for (final category in EditorEffectCategory.values) {
        final target = find
            .ancestor(of: tab(category), matching: find.byType(InkWell))
            .first;
        expect(
          tester.getSize(target).height,
          greaterThanOrEqualTo(kMinInteractiveDimension),
          reason: category.name,
        );
      }
    });

    testWidgets('jumps to a tapped category at once when the system asks '
        'for reduced motion', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(buildWidget(reduceMotion: true));
      final gridTop = tester.getRect(grid()).top;
      await tester.ensureVisible(tab(EditorEffectCategory.light));
      await tester.pumpAndSettle();

      await tester.tap(tab(EditorEffectCategory.light));
      await tester.pump();

      expect(
        tester.getRect(header(EditorEffectCategory.light)).top - gridTop,
        inInclusiveRange(0, 10),
      );
    });

    testWidgets('follows the scroll again once the user scrolls after a tap, '
        'up to the last section at the end', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(buildWidget());
      await tapTab(tester, EditorEffectCategory.glitch);

      await tester.drag(grid(), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(
        isTabHighlighted(tester, EditorEffectCategory.values.last),
        isTrue,
      );

      await tester.drag(grid(), const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(isTabHighlighted(tester, EditorEffectCategory.retro), isTrue);
    });

    testWidgets('scrolling the grid highlights the section at its top, and '
        'the tabs cast a shadow on the effects under them', (
      tester,
    ) async {
      usePhoneSize(tester);
      await tester.pumpWidget(buildWidget());
      final gridTop = tester.getRect(grid()).top;
      expect(tabsCastShadow(tester), isFalse);

      for (var i = 0; i < 20; i++) {
        if (tester.getRect(header(EditorEffectCategory.glitch)).top <=
            gridTop) {
          break;
        }
        await scrollGridBy(tester, -40);
      }
      expect(
        tester.getRect(header(EditorEffectCategory.glitch)).top,
        lessThanOrEqualTo(gridTop),
      );
      expect(isTabHighlighted(tester, EditorEffectCategory.glitch), isTrue);
      expect(tabsCastShadow(tester), isTrue);

      await tester.drag(grid(), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(isTabHighlighted(tester, EditorEffectCategory.retro), isTrue);
      expect(isTabHighlighted(tester, EditorEffectCategory.glitch), isFalse);
      expect(tabsCastShadow(tester), isFalse);
    });

    testWidgets('scrolling through the grid highlights every category in '
        'turn, the last ones too short to reach the top included', (
      tester,
    ) async {
      usePhoneSize(tester);
      await tester.pumpWidget(buildWidget());
      final position = tester
          .widget<CustomScrollView>(grid())
          .controller!
          .position;

      final highlighted = <EditorEffectCategory>[
        EditorEffectCategory.values[tester
            .widget<TabBar>(find.byType(TabBar))
            .controller!
            .index],
      ];
      while (position.pixels < position.maxScrollExtent) {
        await scrollGridBy(tester, -20);
        final current =
            EditorEffectCategory.values[tester
                .widget<TabBar>(find.byType(TabBar))
                .controller!
                .index];
        if (current != highlighted.last) highlighted.add(current);
      }

      expect(highlighted, EditorEffectCategory.values);
    });

    for (final (type, label) in [
      (EditorEffectType.tiltShift, l10n.videoEditorEffectTiltShift),
      (EditorEffectType.sparkles, l10n.videoEditorEffectSparkles),
    ]) {
      testWidgets('opening on a timeline "$label" effect starts at its '
          'section', (tester) async {
        usePhoneSize(tester);
        cubit
          ..syncApplied([
            EditorVideoEffect.of(id: 'edited', type: type, intensity: 1),
          ])
          ..startEditing(effectId: 'edited');

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(isTabHighlighted(tester, type.category), isTrue);
        final tabRect = tester.getRect(tab(type.category));
        expect(tabRect.left, greaterThanOrEqualTo(0));
        expect(tabRect.right, lessThanOrEqualTo(402));
        final gridRect = tester.getRect(grid());
        expect(gridRect.contains(tester.getCenter(tile(label))), isTrue);
      });
    }

    testWidgets('scrolls on under the system navigation bar, and lets the '
        'last row clear it', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(buildWidget(navigationBarHeight: 48));

      final bar = find.byType(VideoEditorEffectsBottomBar);
      expect(
        tester.getSize(bar).height,
        moreOrLessEquals(
          VideoEditorEffectsBottomBar.heightOf(tester.element(bar)) + 48,
        ),
      );
      expect(tester.getRect(grid()).bottom, 600);
      await tester.drag(grid(), const Offset(0, -5000));
      await tester.pumpAndSettle();
      final lastRowBottom = [
        for (final type in EditorEffectCategory.values.last.types)
          tester
              .getRect(
                tile(
                  videoEffectLabel(
                    tester.element(find.byType(VideoEditorEffectsBottomBar)),
                    type,
                  ),
                ),
              )
              .bottom,
      ].reduce(max);
      expect(lastRowBottom, lessThanOrEqualTo(600 - 48));
    });

    testWidgets('tapping an effect picks it', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(tile(l10n.videoEditorEffectVhs));
      expect(cubit.state.selectedType?.builtIn, VideoEffectType.vhs);

      await tester.tap(tile(l10n.videoEditorEffectCrt));
      expect(cubit.state.selectedType?.builtIn, VideoEffectType.crt);
    });

    group('a picked effect', () {
      const navigationBarHeight = 48.0;
      const navigationBarTop = 600 - navigationBarHeight;

      /// The whole tile of the effect named [label], not only its name.
      Finder wholeTile(String label) => find
          .ancestor(of: tile(label), matching: find.byType(GestureDetector))
          .first;

      /// The name of the first effect whose tile the navigation bar cuts.
      String tileUnderNavigationBar(WidgetTester tester) {
        final context = tester.element(
          find.byType(VideoEditorEffectsBottomBar),
        );
        return EditorEffectType.values
            .map((type) => videoEffectLabel(context, type))
            .firstWhere((label) {
              if (!tester.any(tile(label))) return false;
              final rect = tester.getRect(wholeTile(label));
              return rect.top < navigationBarTop &&
                  rect.bottom > navigationBarTop;
            });
      }

      testWidgets('scrolls fully clear of the system navigation bar', (
        tester,
      ) async {
        usePhoneSize(tester);
        await tester.pumpWidget(
          buildWidget(navigationBarHeight: navigationBarHeight),
        );
        final label = tileUnderNavigationBar(tester);
        final before = tester.getRect(wholeTile(label));

        await tester.tapAt(
          Offset(before.center.dx, (before.top + navigationBarTop) / 2),
        );
        await tester.pumpAndSettle();

        expect(cubit.state.selectedType, isNotNull);
        expect(
          tester.getRect(wholeTile(label)).bottom,
          moreOrLessEquals(navigationBarTop),
        );
      });

      testWidgets('does not pull the grid back once the user scrolls it '
          'away', (tester) async {
        usePhoneSize(tester);
        await tester.pumpWidget(buildWidget());
        await tester.tap(tile(l10n.videoEditorEffectVhs));
        await tester.pumpAndSettle();

        // Scrolling under the tabs rebuilds the grid with VHS still picked.
        await scrollGridBy(tester, -60);

        expect(tabsCastShadow(tester), isTrue);
        expect(
          tester.getRect(wholeTile(l10n.videoEditorEffectVhs)).top,
          lessThan(tester.getRect(grid()).top),
        );
      });
    });

    testWidgets('names every effect differently', (tester) async {
      await tester.pumpWidget(buildWidget());
      final context = tester.element(find.byType(VideoEditorEffectsBottomBar));

      final labels = [
        for (final type in EditorEffectType.values)
          videoEffectLabel(context, type),
      ];

      expect(labels.toSet(), hasLength(labels.length));
      expect(
        labels,
        containsAll([
          l10n.videoEditorEffectTimeSplit,
          l10n.videoEditorEffectLongExposure,
          l10n.videoEditorEffectMotionOnly,
          l10n.videoEditorEffectStutter,
          l10n.videoEditorEffectTimeWarp,
          l10n.videoEditorEffectEightBit,
          l10n.videoEditorEffectAnaglyph,
          l10n.videoEditorEffectRiso,
          l10n.videoEditorEffectWatercolor,
          l10n.videoEditorEffectOilPaint,
          l10n.videoEditorEffectPencilSketch,
          l10n.videoEditorEffectNeonEdges,
          l10n.videoEditorEffectAscii,
          l10n.videoEditorEffectStainedGlass,
          l10n.videoEditorEffectThermal,
          l10n.videoEditorEffectNightVision,
          l10n.videoEditorEffectXRay,
          l10n.videoEditorEffectPopArt,
          l10n.videoEditorEffectPaperCut,
          l10n.videoEditorEffectCrossStitch,
          l10n.videoEditorEffectBricks,
          l10n.videoEditorEffectLightRays,
          l10n.videoEditorEffectAnamorphic,
          l10n.videoEditorEffectPrism,
          l10n.videoEditorEffectWindowLight,
          l10n.videoEditorEffectSpotlight,
          l10n.videoEditorEffectDisco,
          l10n.videoEditorEffectLaser,
          l10n.videoEditorEffectLightning,
          l10n.videoEditorEffectShockwave,
          l10n.videoEditorEffectSubwoofer,
          l10n.videoEditorEffectPlasma,
          l10n.videoEditorEffectEnergyWave,
          l10n.videoEditorEffectSmokeBurst,
          l10n.videoEditorEffectTealOrange,
          l10n.videoEditorEffectBleachBypass,
          l10n.videoEditorEffectSilver,
          l10n.videoEditorEffectFadeIn,
          l10n.videoEditorEffectFadeOut,
          l10n.videoEditorEffectCircleOpen,
          l10n.videoEditorEffectCircleClose,
          l10n.videoEditorEffectCinemaOpen,
          l10n.videoEditorEffectCinemaClose,
          l10n.videoEditorEffectCurtainOpen,
          l10n.videoEditorEffectCurtainClose,
          l10n.videoEditorEffectFocusIn,
          l10n.videoEditorEffectFocusOut,
        ]),
      );
    });

    test('draws the tile of every effect Divine renders but the echo and the '
        'stutter with its shader', () {
      for (final type in EditorEffectType.values) {
        final tile = shaderTileOf(type);
        if (type.builtIn != null ||
            type == EditorEffectType.echo ||
            type == EditorEffectType.stutter) {
          expect(tile, isNull, reason: type.name);
        } else {
          expect(tile?.asset, startsWith('shaders/'), reason: type.name);
          expect(tile?.values, isNotEmpty, reason: type.name);
        }
      }
      // One shader draws every particle style, told apart by its last value.
      expect(
        [
          EditorEffectType.snow,
          EditorEffectType.confetti,
          EditorEffectType.hearts,
          EditorEffectType.sparkles,
          EditorEffectType.rain,
          EditorEffectType.leaves,
          EditorEffectType.blossoms,
          EditorEffectType.bubbles,
          EditorEffectType.bokeh,
          EditorEffectType.notes,
          EditorEffectType.stars,
          EditorEffectType.fireflies,
          EditorEffectType.embers,
          EditorEffectType.money,
          EditorEffectType.balloons,
        ].map((type) => shaderTileOf(type)!.values.last),
        [for (var style = 0; style < 15; style++) style],
      );
      // One shader paints watercolour and oil, told apart by its last value.
      expect(
        [
          EditorEffectType.watercolor,
          EditorEffectType.oilPaint,
        ].map(shaderTileOf),
        everyElement(
          isA<ShaderTile>().having(
            (tile) => tile.asset,
            'asset',
            'shaders/paint.frag',
          ),
        ),
      );
      expect(shaderTileOf(EditorEffectType.watercolor)!.values.last, 0);
      expect(shaderTileOf(EditorEffectType.oilPaint)!.values.last, 1);
      // One shader draws every look, from the look's own table.
      for (final type in EditorEffectCategory.looks.types) {
        expect(
          shaderTileOf(type)?.asset,
          'shaders/look.frag',
          reason: type.name,
        );
        expect(
          shaderTileTextureOf(type),
          lookTableAssets[type.customId],
          reason: type.name,
        );
      }
      // The ASCII tile reads the glyphs the native effect draws from; no
      // other effect reads a second texture.
      expect(shaderTileTextureOf(EditorEffectType.ascii), asciiGlyphsAsset);
      for (final type in EditorEffectType.values) {
        if (type == EditorEffectType.ascii ||
            EditorEffectCategory.looks.types.contains(type)) {
          continue;
        }
        expect(shaderTileTextureOf(type), isNull, reason: type.name);
      }
      // One shader draws both tunnels, the spiral one told apart by its last
      // value.
      final tunnels = [EditorEffectType.tunnel, EditorEffectType.spiralTunnel];
      expect(tunnels.map((type) => shaderTileOf(type)!.asset), [
        'shaders/tunnel.frag',
        'shaders/tunnel.frag',
      ]);
      expect(tunnels.map((type) => shaderTileOf(type)!.values.last), [
        0.0,
        1.0,
      ]);
      // One shader draws both bass hits, the subwoofer told apart by its third
      // value: the shockwave with its ring on the way out, the subwoofer
      // bulged out right as it hits.
      final bassHits = [EditorEffectType.shockwave, EditorEffectType.subwoofer];
      expect(bassHits.map((type) => shaderTileOf(type)!.asset), [
        'shaders/bass_hit.frag',
        'shaders/bass_hit.frag',
      ]);
      // Full strength, the moment, the style, then the default look:
      // reach, where it hits, shake, punch and the shockwave's fringes.
      expect(shaderTileOf(EditorEffectType.shockwave)!.values, [
        1.0,
        0.12,
        0.0,
        1.0,
        0.5,
        0.5,
        1.0,
        1.0,
        1.0,
      ]);
      expect(shaderTileOf(EditorEffectType.subwoofer)!.values.take(3), [
        1.0,
        0.0,
        1.0,
      ]);
      // One shader draws every blast, told apart by its third value.
      final blasts = [
        EditorEffectType.plasma,
        EditorEffectType.energyWave,
        EditorEffectType.smokeBurst,
      ];
      expect(
        blasts.map((type) => shaderTileOf(type)!.asset),
        everyElement('shaders/blast.frag'),
      );
      // The style third, and each blast's own colour last.
      expect(blasts.map((type) => shaderTileOf(type)!.values[2]), [
        0.0,
        1.0,
        2.0,
      ]);
      expect(shaderTileOf(EditorEffectType.energyWave)!.values.skip(8), [
        1.0,
        41 / 255,
        15 / 255,
      ]);
      // One shader draws every intro and outro: halfway covered, at its
      // look's starting structure, the look told apart by its third value,
      // which an intro shares with the outro of the same look.
      for (final type in EditorEffectType.values.where((t) => t.isIntroOutro)) {
        final look = type.introOutroLook!;
        final tile = shaderTileOf(type)!;
        expect(tile.asset, 'shaders/intro_outro.frag', reason: type.name);
        expect(tile.values, [
          0.5,
          look.startingIntensity,
          look.index.toDouble(),
          0.0,
        ], reason: type.name);
      }
      expect(
        introOutroTileValues(
          EditorEffectType.outroCurtain,
          amount: 0.8,
          swing: 0.3,
        ),
        [0.8, IntroOutroLook.curtain.startingIntensity, 3.0, 0.3],
      );
      // The lightning tile fills the shader's four vec4 uniforms: how bright
      // the flash and the bolt are, then the shape of the first bolt.
      final lightning = shaderTileOf(EditorEffectType.lightning)!;
      expect(lightning.values, hasLength(2 + lightningBoltValueCount));
      expect(lightning.values.skip(2), lightningBolt(0));
    });

    test('holds a tile where its effect starts, plays it, and holds it '
        'where it ends', () {
      expect(introOutroTileProgress(0), 0);
      expect(introOutroTileProgress(0.1), 0);
      expect(introOutroTileProgress(0.375), closeTo(0.5, 1e-9));
      expect(introOutroTileProgress(0.7), 1);
      expect(introOutroTileProgress(0.99), 1);
    });

    for (final reduceMotion in [false, true]) {
      testWidgets(
        'plays an intro or outro tile over and over unless motion is '
        'reduced (reduceMotion: $reduceMotion)',
        (tester) async {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: const IntroOutroTile(
                path: 'missing.jpg',
                type: EditorEffectType.outroFade,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));

          expect(tester.hasRunningAnimations, !reduceMotion);
        },
      );
    }

    test('pans the stutter tile in held steps, from side to side', () {
      final shifts = [
        for (var step = 0; step < 36; step++) stutterTileShift(step / 36),
      ];
      // Two moments of the same step show the same shift: the pan holds.
      for (var step = 0; step < 36; step += 2) {
        expect(shifts[step + 1], shifts[step], reason: 'step $step');
      }
      expect(shifts.toSet().length, greaterThan(8));
      expect(shifts.reduce(max), closeTo(0.08, 0.01));
      expect(shifts.reduce(min), closeTo(-0.08, 0.01));
    });

    for (final reduceMotion in [false, true]) {
      testWidgets(
        'pans the stutter tile unless motion is reduced '
        '(reduceMotion: $reduceMotion)',
        (tester) async {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: const StutterTile(path: 'missing.jpg'),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));

          expect(tester.hasRunningAnimations, !reduceMotion);
        },
      );
    }

    testWidgets('marks the picked effect and the shown category as selected '
        'for screen readers, and titles each section', (tester) async {
      usePhoneSize(tester);
      // Not in the first section, which the tabs show anyway.
      cubit.selectType(
        const EditorEffectType.builtIn(VideoEffectType.vignette),
      );
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(
          find.bySemanticsLabel(l10n.videoEditorEffectVignette),
        ),
        matchesSemantics(
          label: l10n.videoEditorEffectVignette,
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(tab(EditorEffectCategory.light)),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(tab(EditorEffectCategory.retro)),
        isSemantics(isSelected: false),
      );
      expect(
        tester
            .getSemantics(header(EditorEffectCategory.light))
            .flagsCollection
            .isHeader,
        isTrue,
      );
    });

    testWidgets('stops growing with the text past 125%', (tester) async {
      final bar = find.byType(VideoEditorEffectsBottomBar);
      final heights = <double>[];
      for (final textScale in [1.0, 1.25, 3.0]) {
        await tester.pumpWidget(buildWidget(textScale: textScale));
        heights.add(tester.getSize(bar).height);
      }

      expect(heights[1], greaterThan(heights[0]));
      expect(heights[2], heights[1]);
    });

    for (final textScale in [1.0, 3.0]) {
      testWidgets('is as tall as the editor reserves for it, and fits, at text '
          'scale $textScale', (tester) async {
        await tester.pumpWidget(buildWidget(textScale: textScale));

        expect(tester.takeException(), isNull);
        final bar = find.byType(VideoEditorEffectsBottomBar);
        expect(
          tester.getSize(bar).height,
          moreOrLessEquals(
            VideoEditorEffectsBottomBar.heightOf(tester.element(bar)),
          ),
        );
      });
    }
  });
}
