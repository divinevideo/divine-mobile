import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/avatar_svg_repository_provider.dart';
import 'package:openvine/repositories/avatar_svg_repository.dart';
import 'package:openvine/widgets/avatar_failure_cache.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

final Uint8List _transparentImageBytes = Uint8List.fromList(<int>[
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
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
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
]);

void main() {
  final validSvgBytes = Uint8List.fromList(
    utf8.encode(
      '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1" />',
    ),
  );

  Widget buildAvatar({
    String? imageUrl,
    AvatarSvgRepository? avatarSvgRepository,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: UserAvatar(
          imageUrl: imageUrl,
          name: 'Test User',
          avatarSvgRepository: avatarSvgRepository,
        ),
      ),
    );
  }

  Future<void> pumpAvatarWithSvgRepository(
    WidgetTester tester, {
    required String imageUrl,
    required AvatarSvgRepository repository,
  }) async {
    await tester.pumpWidget(
      buildAvatar(imageUrl: imageUrl, avatarSvgRepository: repository),
    );
    await tester.pump();
  }

  Finder gradientPlaceholderFinder() => find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox) return false;
    final decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.gradient != null;
  }, description: 'generated avatar placeholder');

  setUp(() {
    AvatarFailureCache.instance.clear();
    AvatarFailureCache.instance.resetClockForTesting();
  });

  tearDown(() {
    AvatarFailureCache.instance.clear();
    AvatarFailureCache.instance.resetClockForTesting();
  });

  group('UserAvatar.isSvgImageUrl', () {
    test('returns true for svg URLs', () {
      expect(
        UserAvatar.isSvgImageUrl('https://divine.video/divine-logo.svg'),
        isTrue,
      );
      expect(
        UserAvatar.isSvgImageUrl(
          'https://divine.video/divine-logo.svg?size=128',
        ),
        isTrue,
      );
      expect(
        UserAvatar.isSvgImageUrl(
          'https://divine.video/assets/DIVINE-LOGO.SVG#avatar',
        ),
        isTrue,
      );
    });

    test('returns false for non-svg or invalid URLs', () {
      expect(
        UserAvatar.isSvgImageUrl('https://divine.video/avatar.png'),
        isFalse,
      );
      expect(UserAvatar.isSvgImageUrl('not a url'), isFalse);
      expect(UserAvatar.isSvgImageUrl(null), isFalse);
      expect(UserAvatar.isSvgImageUrl(''), isFalse);
    });
  });

  group('UserAvatar rendering', () {
    testWidgets('skips SvgPicture for cached failed SVG avatar URLs', (
      tester,
    ) async {
      const failedUrl = 'https://divine.video/divine-logo.svg';
      AvatarFailureCache.instance.recordFailure(
        failedUrl,
        ttl: AvatarFailureCache.deterministicFailureTtl,
      );

      await tester.pumpWidget(buildAvatar(imageUrl: failedUrl));

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.byType(VineCachedImage), findsNothing);
      expect(gradientPlaceholderFinder(), findsAtLeastNWidgets(1));
    });

    testWidgets('skips VineCachedImage for cached failed raster avatar URLs', (
      tester,
    ) async {
      const failedUrl = 'https://divine.video/avatar.png';
      AvatarFailureCache.instance.recordFailure(
        failedUrl,
        ttl: AvatarFailureCache.deterministicFailureTtl,
      );

      await tester.pumpWidget(buildAvatar(imageUrl: failedUrl));

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.byType(VineCachedImage), findsNothing);
      expect(gradientPlaceholderFinder(), findsAtLeastNWidgets(1));
    });

    testWidgets('cached failures are scoped to the exact avatar URL', (
      tester,
    ) async {
      const failedUrl = 'https://divine.video/broken-avatar.png';
      const workingUrl = 'https://divine.video/avatar.png';
      AvatarFailureCache.instance.recordFailure(
        failedUrl,
        ttl: AvatarFailureCache.deterministicFailureTtl,
      );

      await tester.pumpWidget(buildAvatar(imageUrl: failedUrl));
      expect(find.byType(VineCachedImage), findsNothing);

      await tester.pumpWidget(buildAvatar(imageUrl: workingUrl));
      expect(find.byType(VineCachedImage), findsOneWidget);
      expect(
        tester.widget<VineCachedImage>(find.byType(VineCachedImage)).imageUrl,
        workingUrl,
      );
    });

    testWidgets('raster deterministic failures are cached', (tester) async {
      const failedUrl = 'https://divine.video/avatar.png';

      await tester.pumpWidget(buildAvatar(imageUrl: failedUrl));
      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );

      image.errorWidget!(
        tester.element(find.byType(VineCachedImage)),
        failedUrl,
        Exception('Invalid image data'),
      );

      expect(AvatarFailureCache.instance.isFailed(failedUrl), isTrue);
    });

    testWidgets(
      'resolves the SVG repository from the container when none is injected',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              avatarSvgRepositoryProvider.overrideWithValue(
                _FakeAvatarSvgRepository(validSvgBytes),
              ),
            ],
            child: buildAvatar(
              imageUrl: 'https://divine.video/divine-logo.svg',
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(SvgPicture), findsOneWidget);
      },
    );

    testWidgets('SVG render failures are cached briefly', (tester) async {
      const failedUrl = 'https://divine.video/divine-logo.svg';

      await pumpAvatarWithSvgRepository(
        tester,
        imageUrl: failedUrl,
        repository: _FakeAvatarSvgRepository(validSvgBytes),
      );
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));

      svg.errorBuilder!(
        tester.element(find.byType(SvgPicture)),
        Exception('HTTP 503'),
        StackTrace.current,
      );

      expect(AvatarFailureCache.instance.isFailed(failedUrl), isTrue);
    });

    testWidgets('caches malformed SVG errors from the real parser', (
      tester,
    ) async {
      const failedUrl = 'https://divine.video/malformed-avatar.svg';
      Object? parsingError;

      await tester.pumpWidget(
        SvgPicture.string(
          '<!-- invalid svg -->',
          errorBuilder: (context, error, stackTrace) {
            parsingError = error;
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(parsingError, isNotNull);
      expect(
        AvatarFailureCache.classifyFailure(parsingError!),
        AvatarFailureKind.deterministic,
      );

      await pumpAvatarWithSvgRepository(
        tester,
        imageUrl: failedUrl,
        repository: _FakeAvatarSvgRepository(validSvgBytes),
      );
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      svg.errorBuilder!(
        tester.element(find.byType(SvgPicture)),
        parsingError!,
        StackTrace.current,
      );

      expect(AvatarFailureCache.instance.isFailed(failedUrl), isTrue);
    });

    testWidgets('HTML returned for a .svg URL renders placeholder only', (
      tester,
    ) async {
      const failedUrl = 'https://divine.video/html-error.svg';

      await pumpAvatarWithSvgRepository(
        tester,
        imageUrl: failedUrl,
        repository: const _FakeAvatarSvgRepository(null),
      );

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.byType(VineCachedImage), findsNothing);
      expect(gradientPlaceholderFinder(), findsAtLeastNWidgets(1));
    });

    testWidgets('rejected .svg URL does not raise a zone error', (
      tester,
    ) async {
      const failedUrl = 'https://divine.video/html-error.svg';
      Object? zoneError;

      await runZonedGuarded(
        () async {
          await pumpAvatarWithSvgRepository(
            tester,
            imageUrl: failedUrl,
            repository: const _FakeAvatarSvgRepository(null),
          );
          await tester.pumpAndSettle();
        },
        (error, stackTrace) {
          zoneError = error;
        },
      );

      expect(zoneError, isNull);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('raster completed download failures are cached', (
      tester,
    ) async {
      const failedUrl = 'https://blotcdn.com/broken-avatar.png';

      await tester.pumpWidget(buildAvatar(imageUrl: failedUrl));
      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );

      image.errorWidget!(
        tester.element(find.byType(VineCachedImage)),
        failedUrl,
        const MediaCacheImageLoadException(failedUrl),
      );

      expect(AvatarFailureCache.instance.isFailed(failedUrl), isTrue);
    });

    testWidgets('caches a broken raster URL through the real image provider', (
      tester,
    ) async {
      const brokenUrl = 'https://blotcdn.com/dead-avatar.png';
      final cache = _MockMediaCacheManager();
      when(() => cache.getFileFromCache(any())).thenAnswer((_) async => null);
      when(
        () => cache.cacheFileCancellable(
          any(),
          key: any(named: 'key'),
          aliasKey: any(named: 'aliasKey'),
          authHeaders: any(named: 'authHeaders'),
        ),
        // An empty stream resolves the download to a null file — exactly
        // what a dead URL (non-2xx / DNS failure) produces in production.
      ).thenReturn(
        CancellableCacheOperation.fromStream(
          const Stream<FileResponse>.empty(),
        ),
      );
      debugImageCacheOverride = cache;
      addTearDown(() => debugImageCacheOverride = null);

      await tester.pumpWidget(buildAvatar(imageUrl: brokenUrl));
      await tester.pumpAndSettle();

      expect(AvatarFailureCache.instance.isFailed(brokenUrl), isTrue);
    });

    testWidgets('keeps raster avatar URLs on VineCachedImage', (tester) async {
      await tester.pumpWidget(
        buildAvatar(imageUrl: 'https://divine.video/avatar.png'),
      );

      expect(find.byType(VineCachedImage), findsOneWidget);
    });

    testWidgets('renders direct image providers without network widgets', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              imageProvider: MemoryImage(_transparentImageBytes),
              name: 'Test User',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(VineCachedImage), findsNothing);
    });

    testWidgets('contentOverride wins over the remote picture', (tester) async {
      // The Divine Moderation row (#6283) supplies its own bundled artwork
      // because that account's kind-0 picture renders black under
      // flutter_svg. The override has to beat a perfectly valid picture URL,
      // not just fill in for a missing one.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              imageUrl: 'https://divine.video/avatar.png',
              name: 'Divine Moderation',
              contentOverride: Text('brand-mark'),
            ),
          ),
        ),
      );

      expect(find.text('brand-mark'), findsOneWidget);
      expect(find.byType(VineCachedImage), findsNothing);
      expect(gradientPlaceholderFinder(), findsNothing);
    });
  });
}

class _FakeAvatarSvgRepository implements AvatarSvgRepository {
  const _FakeAvatarSvgRepository(this.bytes);

  @override
  Future<Uint8List?> load(String url) async => bytes;

  final Uint8List? bytes;
}
