// ABOUTME: Guards the branded loading spinner — pins the sprite sheet to the
// ABOUTME: current Divine brand mark and to the frame count the slicer assumes.

import 'dart:io';
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:yaml/yaml.dart';

import '../helpers/brand_silhouette.dart';

/// Source of truth for the standalone brand mark, also shipped as
/// `DivineIconName.divineMark`. The sprite sheet is its animated white
/// derivative, so a brand refresh has to move both together.
const _markAssetKey = 'assets/icon/divine_mark.svg';

/// Pinned as a literal rather than read from [BrandedLoadingIndicator] so a
/// rename of the constant's target is a test failure, not a silent redirect.
const _spriteAssetKey = 'assets/loading-brand-sprite.png';

/// Overlap the mark's rest pose must reach in the sprite sheet.
///
/// Measured against this sheet: best frame `0.982`, mid-flap frames bottom out
/// at `0.647` (the wings move, so only the rest pose matches). Wrong-mark
/// candidates all land far below — 3D mascot `0.803`, current 3D app icon
/// `0.477`, retired `old_app_icon.png` `0.335`, cursive wordmark `0.195`.
const _minMarkOverlap = 0.90;

/// Extracts frame [index] of the vertically stacked sheet.
DecodedImage _frameAt(DecodedImage sheet, int index) {
  final size = sheet.width;
  final frame = Uint8List(size * size * 4);
  final start = index * size * size * 4;
  RangeError.checkValidRange(start, start + frame.length, sheet.rgba.length);
  frame.setRange(0, frame.length, sheet.rgba, start);
  return (width: size, height: size, rgba: frame);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(BrandedLoadingIndicator, () {
    final en = lookupAppLocalizations(const Locale('en'));

    Future<void> pumpIndicator(
      WidgetTester tester, {
      ThemeData? theme,
      Widget indicator = const BrandedLoadingIndicator(),
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: theme ?? VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: indicator),
        ),
      );
    }

    testWidgets('configures the branded sprite sheet', (tester) async {
      await pumpIndicator(tester);

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, equals(_spriteAssetKey));
      expect(BrandedLoadingIndicator.spriteAsset, equals(_spriteAssetKey));
    });

    testWidgets('draws the mark alone in dark mode', (tester) async {
      await pumpIndicator(tester);

      // White on the dark palette needs no help, so the shadow layer — and
      // its per-frame blur — stays out of the tree entirely.
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('backs the mark with a shadow in light mode', (tester) async {
      await pumpIndicator(tester, theme: VineTheme.lightTheme);

      // Untinted, the white mark all but vanishes on the light surfaces.
      expect(find.byType(ImageFiltered), findsOneWidget);
      final layers = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(layers, hasLength(2));
      // Only the layer behind carries the tint; the mark stays pure white.
      expect(layers.first.color?.a, closeTo(0.4, 0.001));
      expect(layers.last.color, isNull);
    });

    // Without this the spinner is silent: a screen reader user gets no signal
    // that the screen — or the control the indicator replaced — is busy.
    testWidgets('announces that something is loading', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpIndicator(tester);

      expect(find.semantics.byLabel(en.commonLoading), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('announces a caller-supplied label instead', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpIndicator(
        tester,
        indicator: const BrandedLoadingIndicator(
          semanticsLabel: 'Rendering your video',
        ),
      );

      expect(find.semantics.byLabel('Rendering your video'), findsOneWidget);
      expect(find.semantics.byLabel(en.commonLoading), findsNothing);

      semantics.dispose();
    });

    // The sprite sheet is an unlabelled [Image]; left in the tree it reaches
    // the reader as a second, meaningless "image" node beside the label.
    testWidgets('keeps the sprite itself out of the semantics tree', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpIndicator(tester, theme: VineTheme.lightTheme);

      // Light mode stacks two sprite layers, so an unexcluded sheet would
      // show up twice over.
      final node = tester.getSemantics(find.byType(BrandedLoadingIndicator));
      expect(node.label, equals(en.commonLoading));
      expect(node.flagsCollection.isImage, isFalse);
      expect(node.childrenCount, isZero);

      semantics.dispose();
    });

    testWidgets('advances through the sheet while loading', (tester) async {
      await pumpIndicator(tester);

      // Storage index 13 is the matrix's y translation — how far up the sheet
      // has been scrolled to expose the current frame.
      double spriteY() => tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(BrandedLoadingIndicator),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .storage[13];

      final atStart = spriteY();
      // A third of the way through the 1800ms cycle: several frames on.
      await tester.pump(const Duration(milliseconds: 600));
      expect(spriteY(), isNot(equals(atStart)));

      // Still cycling two periods later — a loading spinner must not stall.
      await tester.pump(const Duration(milliseconds: 3000));
      final afterTwoCycles = spriteY();
      await tester.pump(const Duration(milliseconds: 600));
      expect(spriteY(), isNot(equals(afterTwoCycles)));

      // Leaves no live ticker behind for the merged VGV isolate.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });

  group('reduced motion', () {
    // The sprite animation runs on AnimationController.repeat(), which never
    // settles. XCUITest blocks every UI query until the app under test reaches
    // quiescence, so a perpetual animation makes each query wait out XCUITest's
    // internal timeout — measured at a fixed 3m31s on the Explore screen, where
    // this indicator is the `loading:` state (#7204).
    //
    // pumpAndSettle fails the same way for the same reason, which makes it a
    // faithful proxy: if it can settle, the app can go idle.
    Widget wrap({required bool disableAnimations}) {
      return MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: BrandedLoadingIndicator()),
        ),
      );
    }

    testWidgets('settles when the platform asks for reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(disableAnimations: true));

      // Throws on timeout if anything is still scheduling frames.
      await tester.pumpAndSettle();

      expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
    });

    testWidgets('still renders the mark when motion is reduced', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(disableAnimations: true));
      await tester.pumpAndSettle();

      // A static frame, not an empty box: the indicator still has to read as
      // "something is loading".
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('animates when reduced motion is off', (tester) async {
      await tester.pumpWidget(wrap(disableAnimations: false));
      await tester.pump();

      // The control: without the setting the animation must still run, so the
      // fix cannot be "stop animating always".
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });
  });

  group('sprite sheet asset', () {
    late DecodedImage sheet;

    // `flutter test` runs with CWD = package root (mobile/).
    setUpAll(() async {
      sheet = await decodeRgba(await File(_spriteAssetKey).readAsBytes());
    });

    test('is declared in the Flutter asset bundle', () async {
      final pubspec =
          loadYaml(await File('pubspec.yaml').readAsString()) as YamlMap;
      final flutterAssets =
          (pubspec['flutter'] as YamlMap)['assets'] as YamlList;

      expect(
        flutterAssets,
        contains(_spriteAssetKey),
        reason:
            'the widget falls back to a plain progress indicator when the '
            'sprite exists on disk but is missing from pubspec.yaml',
      );
    });

    test('stacks exactly frameCount square frames', () {
      expect(
        sheet.height,
        equals(sheet.width * BrandedLoadingIndicator.frameCount),
        reason:
            'the slicer steps by one frame width; a sheet with a different '
            'frame count would be sliced mid-frame',
      );
    });

    test('draws the mark in pure white on transparency', () {
      var solid = 0;
      var sumR = 0;
      var sumG = 0;
      var sumB = 0;
      var transparent = 0;
      for (var i = 0; i < sheet.rgba.length; i += 4) {
        final alpha = sheet.rgba[i + 3];
        if (alpha == 0) transparent++;
        // Only fully-opaque pixels: rawRgba is premultiplied, so anti-aliased
        // edges carry attenuated colour that would drag the average down.
        if (alpha != 255) continue;
        solid++;
        sumR += sheet.rgba[i];
        sumG += sheet.rgba[i + 1];
        sumB += sheet.rgba[i + 2];
      }

      expect(solid, greaterThan(1000), reason: 'mark should have a body');
      expect(
        transparent,
        greaterThan(solid),
        reason: 'the mark sits on transparency, not a baked-in backdrop',
      );
      // The sheet ships white so it reads on the dark palette; the widget
      // reuses it as an alpha mask for the light-mode shadow. The retired
      // brand pack is cream (blue channel ~234).
      expect(sumR / solid, greaterThan(250));
      expect(sumG / solid, greaterThan(250));
      expect(sumB / solid, greaterThan(250));
    });

    test('animates the current Divine brand mark', () async {
      final mark = normalizedSilhouette(
        await rasterizeSvg(
          await File(_markAssetKey).readAsString(),
          width: sheet.width,
        ),
      );

      var best = 0.0;
      var bestFrame = -1;
      for (var i = 0; i < BrandedLoadingIndicator.frameCount; i++) {
        final score = silhouetteOverlap(
          mark,
          normalizedSilhouette(_frameAt(sheet, i)),
        );
        if (score > best) {
          best = score;
          bestFrame = i;
        }
      }

      // Only the rest pose lines up — the wings move through the cycle.
      expect(
        best,
        greaterThanOrEqualTo(_minMarkOverlap),
        reason:
            'no frame matches $_markAssetKey (best was frame $bestFrame at '
            '${best.toStringAsFixed(3)}); the spinner and the brand mark have '
            'drifted apart',
      );
    });
  });
}
