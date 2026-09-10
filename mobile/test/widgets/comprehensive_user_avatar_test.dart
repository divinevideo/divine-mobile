// ABOUTME: Comprehensive widget test for UserAvatar covering image loading,
// ABOUTME: generated placeholders, geometry, and interactions

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

const _transparentImageBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0x18,
  0xDD,
  0x8D,
  0xB1,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

ClipRRect _clipRRect(WidgetTester tester) =>
    tester.widget<ClipRRect>(find.byType(ClipRRect));

Size _clipSize(WidgetTester tester) => tester.getSize(find.byType(ClipRRect));

Finder _borderFinder() => find.byWidgetPredicate((widget) {
  if (widget is! DecoratedBox) return false;
  final decoration = widget.decoration;
  return decoration is BoxDecoration && decoration.border != null;
}, description: 'DecoratedBox with avatar border');

Finder _gradientFinder() => find.byWidgetPredicate((widget) {
  if (widget is! DecoratedBox) return false;
  final decoration = widget.decoration;
  return decoration is BoxDecoration && decoration.gradient != null;
}, description: 'DecoratedBox with gradient placeholder');

double _borderWidth(WidgetTester tester) {
  final borderDecoration =
      tester.widget<DecoratedBox>(_borderFinder()).decoration as BoxDecoration;
  final border = borderDecoration.border! as Border;
  return border.top.width;
}

void main() {
  group('UserAvatar - Comprehensive Tests', () {
    group('Basic Widget Structure', () {
      testWidgets('creates default structure without tap wrapper', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar()),
          ),
        );

        expect(find.byType(Semantics), findsWidgets);
        expect(find.byType(GestureDetector), findsNothing);
        expect(find.byType(ClipRRect), findsOneWidget);
        expect(_clipSize(tester), const Size.square(44));
        expect(_clipRRect(tester).borderRadius, BorderRadius.circular(17.6));
        expect(_borderFinder(), findsOneWidget);
        expect(_borderWidth(tester), 1);
      });

      testWidgets('wraps avatar in GestureDetector when onTap is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(onTap: () {})),
          ),
        );

        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('applies custom size and large-avatar border radius', (
        tester,
      ) async {
        const customSize = 144.0;

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(size: customSize)),
          ),
        );

        expect(_clipSize(tester), const Size.square(customSize));
        expect(_clipRRect(tester).borderRadius, BorderRadius.circular(56));
        expect(_borderWidth(tester), 3);
      });
    });

    group('Image Loading States', () {
      testWidgets('uses placeholder for an insecure archive avatar URL', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(
                imageUrl: 'http://web.archive.org/avatar.jpg',
                placeholderSeed: 'stable-user',
              ),
            ),
          ),
        );

        expect(find.byType(VineCachedImage), findsNothing);
        expect(_gradientFinder(), findsWidgets);
      });

      testWidgets('shows VineCachedImage when imageUrl is provided', (
        tester,
      ) async {
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(imageUrl: testImageUrl)),
          ),
        );

        expect(find.byType(VineCachedImage), findsOneWidget);

        final image = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        expect(image.imageUrl, testImageUrl);
        expect(image.fit, BoxFit.cover);
        expect(_clipSize(tester), const Size.square(44));
      });

      testWidgets(
        'renders the placeholder without requesting an insecure URL',
        (tester) async {
          const deadUrl = 'http://images.example/avatar.jpg';

          await tester.pumpWidget(
            const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: UserAvatar(imageUrl: deadUrl)),
            ),
          );

          // Profile metadata is untrusted, so cleartext image requests are
          // rejected before constructing the cached-image widget.
          expect(find.byType(VineCachedImage), findsNothing);
          expect(_gradientFinder(), findsWidgets);
        },
      );

      testWidgets(
        'renders the placeholder without requesting a dead https vine.co URL',
        (tester) async {
          const deadUrl = 'https://v.cdn.vine.co/v/avatars/dead.jpg';

          await tester.pumpWidget(
            const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: UserAvatar(imageUrl: deadUrl)),
            ),
          );

          expect(find.byType(VineCachedImage), findsNothing);
          expect(_gradientFinder(), findsWidgets);
        },
      );

      testWidgets('shows generated placeholder when imageUrl is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(name: 'Test User')),
          ),
        );

        expect(find.byType(VineCachedImage), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(_gradientFinder(), findsAtLeastNWidgets(1));
      });

      testWidgets('shows generated placeholder when imageUrl is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(imageUrl: '', name: 'Test User'),
            ),
          ),
        );

        expect(find.byType(VineCachedImage), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(_gradientFinder(), findsAtLeastNWidgets(1));
      });

      testWidgets('renders the provided imageProvider', (tester) async {
        final provider = MemoryImage(
          Uint8List.fromList(_transparentImageBytes),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(imageProvider: provider, name: 'Local User'),
            ),
          ),
        );

        expect(find.byType(VineCachedImage), findsNothing);
        expect(find.byType(Image), findsOneWidget);
        final image = tester.widget<Image>(find.byType(Image));
        // Wrapped for a bounded decode, but still resolving the caller's
        // provider — see the 'Decode size' group for the bound itself.
        expect(image.image, isA<ResizeImage>());
        expect((image.image as ResizeImage).imageProvider, same(provider));
      });

      testWidgets('uses explicit placeholder tone when provided', (
        tester,
      ) async {
        final blueGradientFinder = find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoration = widget.decoration;
          if (decoration is! BoxDecoration) return false;
          final gradient = decoration.gradient;
          if (gradient is! LinearGradient || gradient.colors.length != 3) {
            return false;
          }
          return gradient.colors[1] == VineTheme.accentBlue;
        }, description: 'blue placeholder background');

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(placeholderTone: UserAvatarPlaceholderTone.blue),
            ),
          ),
        );

        expect(blueGradientFinder, findsOneWidget);
      });
    });

    group('Image Error Handling', () {
      testWidgets('shows error widget when image fails to load', (
        tester,
      ) async {
        const failingImageUrl = 'https://example.com/nonexistent.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(imageUrl: failingImageUrl, name: 'Test User'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final image = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        expect(image.errorWidget, isNotNull);
      });

      testWidgets('shows placeholder while image is loading', (tester) async {
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(imageUrl: testImageUrl, name: 'Test User'),
            ),
          ),
        );

        final image = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        expect(image.placeholder, isNotNull);
      });
    });

    group('Tap Interactions', () {
      testWidgets('calls onTap when avatar is tapped', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(onTap: () => tapped = true)),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('does not respond to taps when onTap is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar()),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();
      });

      testWidgets('onTap works with image avatar', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(
                imageUrl: 'https://example.com/avatar.jpg',
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('onTap works with placeholder avatar', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(name: 'Test User', onTap: () => tapped = true),
            ),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });
    });

    group('Size Variations', () {
      testWidgets('uses compact corner radius for very small sizes', (
        tester,
      ) async {
        const smallSize = 16.0;

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(size: smallSize, name: 'Test'),
            ),
          ),
        );

        expect(_clipSize(tester), const Size.square(smallSize));
        expect(
          _clipRRect(tester).borderRadius,
          BorderRadius.circular(smallSize / 3),
        );
      });

      testWidgets('caps corner radius for very large sizes', (tester) async {
        const largeSize = 200.0;

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(size: largeSize, name: 'Test'),
            ),
          ),
        );

        expect(_clipSize(tester), const Size.square(largeSize));
        expect(_clipRRect(tester).borderRadius, BorderRadius.circular(56));
      });

      testWidgets('network avatar respects outer size parameter', (
        tester,
      ) async {
        const customSize = 60.0;
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(size: customSize, imageUrl: testImageUrl),
            ),
          ),
        );

        expect(_clipSize(tester), const Size.square(customSize));
      });
    });

    group('Semantics', () {
      testWidgets('provides correct semantics with name', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(name: 'Test User', size: 50)),
          ),
        );

        expect(find.bySemanticsLabel('Test User avatar'), findsOneWidget);
      });

      testWidgets('provides default semantics without name', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(size: 50)),
          ),
        );

        expect(find.bySemanticsLabel('User avatar'), findsOneWidget);
      });

      testWidgets('uses custom semantic label when provided', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(
                name: 'Test User',
                semanticLabel: 'Custom label',
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Custom label'), findsOneWidget);
      });
    });

    group('Edge Cases and Robustness', () {
      testWidgets('handles zero size gracefully', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(size: 0)),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('handles names with special characters', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(name: 'José María')),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(_gradientFinder(), findsAtLeastNWidgets(1));
      });

      testWidgets('handles names with numbers', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(name: 'User123 Test456')),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(_gradientFinder(), findsAtLeastNWidgets(1));
      });

      testWidgets('handles whitespace-only names', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(name: '   ')),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(_gradientFinder(), findsAtLeastNWidgets(1));
      });

      testWidgets('handles malformed URLs gracefully', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(
                imageUrl: 'not-a-valid-url',
                name: 'Fallback User',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(UserAvatar), findsOneWidget);
      });
    });

    group('Decode size', () {
      testWidgets('bounds the network decode to the slot in device pixels', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(
                imageUrl: 'https://example.com/avatar.jpg',
                size: 32,
              ),
            ),
          ),
        );

        final image = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        // 32pt slot at 3x. Without this hint Flutter decodes the source at
        // full resolution, which is how a 32x32 avatar costs tens of MB.
        expect(image.memCacheWidth, equals(96));
        // Left null so ResizeImage preserves the source aspect ratio.
        expect(image.memCacheHeight, isNull);
      });

      testWidgets('scales the decode hint with the slot size', (tester) async {
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(
                imageUrl: 'https://example.com/avatar.jpg',
                size: 120,
              ),
            ),
          ),
        );

        expect(
          tester
              .widget<VineCachedImage>(find.byType(VineCachedImage))
              .memCacheWidth,
          equals(240),
        );
      });

      testWidgets('bounds a caller-supplied ImageProvider too', (tester) async {
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(
                imageProvider: MemoryImage(
                  Uint8List.fromList(_transparentImageBytes),
                ),
                size: 40,
              ),
            ),
          ),
        );

        final provider = tester.widget<Image>(find.byType(Image)).image;
        expect(provider, isA<ResizeImage>());
        expect((provider as ResizeImage).width, equals(120));
        expect(provider.height, isNull);
      });

      testWidgets('leaves the decode unbounded for a non-finite size', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 40,
                height: 40,
                child: UserAvatar(
                  imageProvider: MemoryImage(
                    Uint8List.fromList(_transparentImageBytes),
                  ),
                  size: double.infinity,
                ),
              ),
            ),
          ),
        );

        // An infinite slot must not reach (size * dpr).ceil(), which throws.
        // The provider is used unwrapped so the framework decodes natively.
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<Image>(find.byType(Image)).image,
          isA<MemoryImage>(),
        );
      });
    });

    group('Multiple Avatars', () {
      testWidgets('renders multiple avatars correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  UserAvatar(name: 'User One', size: 40),
                  UserAvatar(name: 'User Two', size: 50),
                  UserAvatar(
                    imageUrl: 'https://example.com/avatar.jpg',
                    size: 60,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(UserAvatar), findsNWidgets(3));
        expect(find.byType(VineCachedImage), findsOneWidget);
      });
    });
  });
}
