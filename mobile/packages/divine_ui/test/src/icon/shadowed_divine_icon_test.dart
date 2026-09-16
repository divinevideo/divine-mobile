import 'dart:async';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _squareSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
    'viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16"/></svg>';

/// Compiles [_squareSvg] the way the asset loader would, but only once the
/// test opens [gate], so a bake can be held pending on purpose.
///
/// The string loader needs no context, and none is forwarded: by the time
/// the gate opens the widget under test may already be gone, and the
/// production asset loader reads its context synchronously anyway.
class _GatedLoader extends BytesLoader {
  const _GatedLoader(this.gate);

  final Completer<void> gate;

  @override
  Future<ByteData> loadBytes(BuildContext? context) async {
    await gate.future;
    return const SvgStringLoader(_squareSvg).loadBytes(null);
  }
}

class _ThrowingLoader extends BytesLoader {
  const _ThrowingLoader();

  @override
  Future<ByteData> loadBytes(BuildContext? context) =>
      Future.error(StateError('no bytes'));
}

Widget _host(Widget child, {double devicePixelRatio = 3}) => MediaQuery(
  data: MediaQueryData(devicePixelRatio: devicePixelRatio),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

ShadowedIconRasterKey _keyFor(
  WidgetTester tester, {
  Color color = const Color(0xFFFFFFFF),
}) {
  final context = tester.element(find.byType(ShadowedDivineIcon));
  return ShadowedIconRasterKey(
    icon: DivineIconName.heart,
    color: color,
    dimension: DivineIcon.scaleSize(context, 24),
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    shadows: divineIconButtonShadows,
  );
}

void main() {
  group(DivineIconShadow, () {
    test('compares by offset, sigma and colour', () {
      const a = DivineIconShadow(offset: Offset(1, 1), blurSigma: 1);
      const b = DivineIconShadow(offset: Offset(1, 1), blurSigma: 1);
      const c = DivineIconShadow(
        offset: Offset(1, 1),
        blurSigma: 1,
        color: Color(0xFF000000),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(
        a,
        isNot(
          equals(const DivineIconShadow(offset: Offset(1, 1), blurSigma: 2)),
        ),
      );
    });

    test('reach covers the offset plus three sigmas', () {
      const shadow = DivineIconShadow(offset: Offset(-2, 1), blurSigma: 0.5);
      expect(shadow.reach, closeTo(3.5, 1e-9));
    });
  });

  group(ShadowedIconRasterKey, () {
    ShadowedIconRasterKey key({
      Color color = const Color(0xFFFFFFFF),
      List<DivineIconShadow> shadows = divineIconButtonShadows,
    }) => ShadowedIconRasterKey(
      icon: DivineIconName.heart,
      color: color,
      dimension: 24,
      devicePixelRatio: 3,
      shadows: shadows,
    );

    test('equal keys share a hash and differ on any field', () {
      expect(key(), equals(key()));
      expect(key().hashCode, equals(key().hashCode));
      expect(key(), isNot(equals(key(color: const Color(0xFF00FF00)))));
      expect(key(), isNot(equals(key(shadows: const []))));
    });

    test('pads the glyph by the furthest shadow reach, rounded up', () {
      final k = key();
      expect(k.margin, equals(4));
      expect(k.extent, equals(32));
      expect(k.pixelExtent, equals(96));
      expect(key(shadows: const []).margin, equals(0));
    });
  });

  group(ShadowedDivineIcon, () {
    late Completer<void> gate;
    late ShadowedIconRasterCache cache;

    setUp(() {
      gate = Completer<void>();
      cache = ShadowedIconRasterCache(loaderFor: (_) => _GatedLoader(gate));
    });

    Widget subject({Color color = const Color(0xFFFFFFFF)}) => _host(
      ShadowedDivineIcon(
        icon: DivineIconName.heart,
        color: color,
        cache: cache,
      ),
    );

    // Pumps [subject] and drives its bake to completion inside one real
    // async zone: a bake started under fake async and finished under
    // runAsync straddles two zones and never settles.
    Future<ui.Image?> pumpResolved(
      WidgetTester tester, {
      Color color = const Color(0xFFFFFFFF),
    }) async {
      final image = await tester.runAsync<ui.Image?>(() async {
        await tester.pumpWidget(subject(color: color));
        if (!gate.isCompleted) gate.complete();
        return cache.rasterize(
          _keyFor(tester, color: color),
          tester.element(find.byType(ShadowedDivineIcon)),
        );
      });
      await tester.pump();
      return image;
    }

    testWidgets('draws the live layers until the raster is ready', (
      tester,
    ) async {
      await tester.pumpWidget(subject());

      expect(find.byType(ImageFiltered), findsNWidgets(2));
      expect(find.byType(DivineIcon), findsNWidgets(3));
      expect(find.byType(RawImage), findsNothing);
    });

    testWidgets('paints one bitmap sized for glyph plus shadow margin once '
        'the raster resolves', (tester) async {
      final image = await pumpResolved(tester);
      final key = _keyFor(tester);

      expect(image, isNotNull);
      expect(image!.width, equals(key.pixelExtent));
      expect(image.height, equals(key.pixelExtent));
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byType(RawImage), findsOneWidget);
      expect(
        tester.getSize(find.byType(ShadowedDivineIcon)),
        equals(const Size.square(24)),
      );
      expect(
        tester.getSize(find.byType(RawImage)),
        equals(const Size.square(32)),
      );
    });

    testWidgets('reuses the cached bitmap on the next mount', (tester) async {
      await pumpResolved(tester);
      expect(find.byType(RawImage), findsOneWidget);

      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpWidget(subject());

      expect(find.byType(RawImage), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('goes back to the live layers while a new colour bakes', (
      tester,
    ) async {
      await pumpResolved(tester);
      expect(find.byType(RawImage), findsOneWidget);

      await tester.pumpWidget(subject(color: const Color(0xFFFF0000)));

      expect(find.byType(RawImage), findsNothing);
      expect(find.byType(ImageFiltered), findsNWidgets(2));
    });

    testWidgets('ignores a bake that lands after the key moved on', (
      tester,
    ) async {
      final held = Completer<void>();
      final firstGate = gate;
      var loads = 0;
      cache = ShadowedIconRasterCache(
        loaderFor: (_) => _GatedLoader(loads++ == 0 ? firstGate : held),
      );

      final image = await tester.runAsync<ui.Image?>(() async {
        await tester.pumpWidget(subject());
        final firstKey = _keyFor(tester);
        await tester.pumpWidget(subject(color: const Color(0xFFFF0000)));
        firstGate.complete();
        return cache.rasterize(
          firstKey,
          tester.element(find.byType(ShadowedDivineIcon)),
        );
      });
      await tester.pump();

      expect(image, isNotNull);
      expect(cache.imageFor(_keyFor(tester)), same(image));
      expect(find.byType(RawImage), findsNothing);
      expect(find.byType(ImageFiltered), findsNWidgets(2));
    });

    testWidgets('ignores a bake that lands after unmount', (tester) async {
      final image = await tester.runAsync<ui.Image?>(() async {
        await tester.pumpWidget(subject());
        final key = _keyFor(tester);
        final context = tester.element(find.byType(ShadowedDivineIcon));
        await tester.pumpWidget(_host(const SizedBox()));
        gate.complete();
        return cache.rasterize(key, context);
      });
      await tester.pump();

      expect(image, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the live layers when the SVG cannot be loaded', (
      tester,
    ) async {
      cache = ShadowedIconRasterCache(
        loaderFor: (_) => const _ThrowingLoader(),
      );

      final image = await tester.runAsync<ui.Image?>(() async {
        await tester.pumpWidget(subject());
        return cache.rasterize(
          _keyFor(tester),
          tester.element(find.byType(ShadowedDivineIcon)),
        );
      });
      await tester.pump();

      expect(image, isNull);
      expect(cache.imageFor(_keyFor(tester)), isNull);
      expect(find.byType(ImageFiltered), findsNWidgets(2));
    });
  });

  group(ShadowedIconRasterCache, () {
    testWidgets('shares one in-flight bake per key and serves it from the '
        'cache afterwards', (tester) async {
      final gate = Completer<void>();
      final cache = ShadowedIconRasterCache(
        loaderFor: (_) => _GatedLoader(gate),
      );
      await tester.pumpWidget(_host(const SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      final key = ShadowedIconRasterKey(
        icon: DivineIconName.heart,
        color: const Color(0xFFFFFFFF),
        dimension: 24,
        devicePixelRatio: 2,
        shadows: divineIconButtonShadows,
      );

      final result = await tester.runAsync(() async {
        final first = cache.rasterize(key, context);
        final second = cache.rasterize(key, context);
        gate.complete();
        return (sharedInFlight: identical(first, second), image: await first);
      });
      final image = result!.image;
      expect(result.sharedInFlight, isTrue);
      expect(image, isNotNull);
      expect(cache.imageFor(key), same(image));
      expect(
        await tester.runAsync(() => cache.rasterize(key, context)),
        same(image),
      );

      cache.clear();
      expect(cache.imageFor(key), isNull);
    });

    testWidgets('drops the least recently drawn bake past maxEntries', (
      tester,
    ) async {
      final cache = ShadowedIconRasterCache(
        loaderFor: (_) => const SvgStringLoader(_squareSvg),
      );
      await tester.pumpWidget(_host(const SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      ShadowedIconRasterKey key(int tint) => ShadowedIconRasterKey(
        icon: DivineIconName.heart,
        color: Color(0xFF000000 | tint),
        dimension: 8,
        devicePixelRatio: 1,
        shadows: divineIconButtonShadows,
      );

      for (var i = 0; i <= ShadowedIconRasterCache.maxEntries; i++) {
        expect(
          await tester.runAsync(() => cache.rasterize(key(i), context)),
          isNotNull,
          reason: 'bake $i should resolve',
        );
      }
      // One past the cap dropped the first, least recently drawn bake.
      expect(cache.imageFor(key(0)), isNull);
      expect(cache.imageFor(key(1)), isNotNull);

      // A hit is a use, so the next overflow drops the next-oldest instead.
      expect(
        await tester.runAsync(
          () => cache.rasterize(
            key(ShadowedIconRasterCache.maxEntries + 1),
            context,
          ),
        ),
        isNotNull,
      );
      expect(
        cache.imageFor(key(1)),
        isNotNull,
        reason: 'the refreshed entry survives the next overflow',
      );
      expect(cache.imageFor(key(2)), isNull);
    });

    test(
      'the default loader is the asset lookup DivineIcon renders through',
      () {
        final loader = ShadowedIconRasterCache.assetLoaderFor(
          DivineIconName.heart,
        );

        expect(loader, isA<SvgAssetLoader>());
        expect(
          (loader as SvgAssetLoader).assetName,
          equals(DivineIconName.heart.assetPath),
        );
        expect(ShadowedIconRasterCache.instance, isNotNull);
      },
    );
  });
}
