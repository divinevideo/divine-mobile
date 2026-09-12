// ABOUTME: Tests for the standalone profile banner media widget
// ABOUTME: Verifies banner image fallback behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import '../../helpers/test_provider_overrides.dart';

void main() {
  group(ProfileBanner, () {
    testWidgets('bounds a 3:1 banner decode at cover resolution', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(800, 1600)
        ..devicePixelRatio = 2;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        testMaterialApp(
          theme: VineTheme.theme,
          home: const Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 400,
              height: 334,
              child: ProfileBanner(
                bannerUrl: 'https://cdn.example.com/banner.jpg',
                height: 334,
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      expect(image.memCacheWidth, 2004);
      expect(image.memCacheHeight, 668);
      expect(image.resizePolicy, ResizeImagePolicy.fit);
    });

    testWidgets('image load error renders the profile color fallback', (
      tester,
    ) async {
      const profileColor = Color(0xFF33CCBF);

      await tester.pumpWidget(
        testMaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: ProfileBanner(
              bannerUrl: 'https://cdn.example.com/missing-banner.jpg',
              profileColor: profileColor,
              height: 334,
            ),
          ),
        ),
      );

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      final imageContext = tester.element(find.byType(VineCachedImage));
      final fallback = image.errorWidget!(
        imageContext,
        image.imageUrl,
        Exception('load failed'),
      );

      await tester.pumpWidget(
        testMaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(body: fallback),
        ),
      );

      final fallbackFinder = find.byKey(
        const ValueKey('profile_banner_fallback'),
      );
      expect(fallbackFinder, findsOneWidget);
      expect(tester.getSize(fallbackFinder).height, 334);

      final container = tester.widget<Container>(fallbackFinder);
      final decoration = container.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, equals([profileColor, profileColor]));
    });
  });
}
