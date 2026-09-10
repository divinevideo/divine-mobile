import 'dart:async';
import 'dart:ui' as ui;

import 'package:blurhash_service/blurhash_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_cache/media_cache.dart' show MediaCacheImageLoadException;
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart'
    show AuthService, AuthState;
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart'
    show createMockMediaCacheManager, testMaterialApp;
import '../test_data/video_test_data.dart';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

double _thumbnailAspectRatio(WidgetTester tester) =>
    tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio;

/// An [ImageProvider] that synchronously yields a pre-built [ui.Image] so a
/// widget test can drive the image stream without an async decode.
///
/// The framework takes ownership of whatever [ImageInfo] receives and disposes
/// it, so this hands over a clone and leaves the caller's [image] to the
/// caller. Passing the original instead lets the test's own `dispose` close
/// the last handle while the process-global [ImageCache] still holds the
/// completer; the cache's deferred eviction then trips
/// `ImageInfo.dispose`'s open-handle assertion inside whichever unrelated test
/// pumps the next frame.
class _SyncImageProvider extends ImageProvider<_SyncImageProvider> {
  _SyncImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_SyncImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_SyncImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _SyncImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())),
  );
}

class _MockMediaAuthInterceptor extends Mock implements MediaAuthInterceptor {}

class _MockAuthService extends Mock implements AuthService {}

class _MockMediaViewerAuthService extends Mock
    implements MediaViewerAuthService {}

class _TestContentFilterVersion extends ContentFilterVersion {
  @override
  int build() => 0;
}

List<Override> _passiveAuthProviderOverrides(
  MediaAuthInterceptor mediaAuthInterceptor,
) => [
  mediaAuthInterceptorProvider.overrideWithValue(mediaAuthInterceptor),
  currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
  contentFilterVersionProvider.overrideWith(_TestContentFilterVersion.new),
];

List<Override> _passiveAuthProviderOverridesWithRealServices({
  required MediaViewerAuthService mediaViewerAuthService,
  required SharedPreferences sharedPreferences,
}) => [
  mediaViewerAuthServiceProvider.overrideWithValue(mediaViewerAuthService),
  currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
  sharedPreferencesProvider.overrideWithValue(sharedPreferences),
];

/// Creates a [ui.Image] of exactly [width] x [height] without an async decode.
ui.Image _syncImage(int width, int height) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder);
  return recorder.endRecording().toImageSync(width, height);
}

/// Builds a [_SyncImageProvider] for [image] and drops its [ImageCache] entry
/// when the test ends, so the resolved completer does not outlive the suite.
_SyncImageProvider _syncImageProvider(ui.Image image) {
  final provider = _SyncImageProvider(image);
  addTearDown(provider.evict);
  return provider;
}

void main() {
  group('VideoThumbnailWidget', () {
    late VideoEvent videoWithThumbnail;
    late VideoEvent videoWithBlurhash;
    late VideoEvent videoWithBoth;
    late VideoEvent videoWithNeither;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PassiveAuthThumbnailImage.debugClearUnauthorizedCache();
      // Video with only thumbnail URL
      videoWithThumbnail = createTestVideoEvent(
        id: 'test1',
        thumbnailUrl: 'https://example.com/thumb1.jpg',
      );

      // Video with only blurhash
      videoWithBlurhash = createTestVideoEvent(
        id: 'test2',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      // Video with both thumbnail and blurhash
      videoWithBoth = createTestVideoEvent(
        id: 'test3',
        thumbnailUrl: 'https://example.com/thumb3.jpg',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      // Video with neither
      videoWithNeither = createTestVideoEvent(id: 'test4');
    });

    tearDown(PassiveAuthThumbnailImage.debugClearUnauthorizedCache);

    // Stub the image cache (#5158 seam) so VineCachedImage does no real
    // path_provider / cache-manager work that could settle after the test and
    // cascade in the merged VGV optimizer isolate (#5159).
    setUp(() => debugImageCacheOverride = createMockMediaCacheManager());
    tearDown(() => debugImageCacheOverride = null);

    testWidgets('builds widget tree correctly when thumbnail URL exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Widget should build without error
      expect(find.byType(VideoThumbnailWidget), findsOneWidget);

      // Should create a VineCachedImage widget when thumbnail URL exists.
      expect(find.byType(VineCachedImage), findsOneWidget);
    });

    testWidgets(
      'renders blurhash without image load for dead media thumbnail',
      (
        tester,
      ) async {
        const blurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
        final videoWithDeadThumbnail = createTestVideoEvent(
          id: 'test-dead-thumbnail',
          thumbnailUrl: 'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/thumbnail.jpg',
          blurhash: blurhash,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: videoWithDeadThumbnail,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        expect(find.byType(PassiveAuthThumbnailImage), findsNothing);
        expect(find.byType(VineCachedImage), findsNothing);
        expect(
          tester.widget<BlurhashDisplay>(find.byType(BlurhashDisplay)).blurhash,
          blurhash,
        );
      },
    );

    testWidgets(
      'updates missing metadata aspect ratio from the displayed cached image',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: videoWithThumbnail,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        expect(_thumbnailAspectRatio(tester), equals(2 / 3));

        final cachedImage = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        cachedImage.onImageDimensionsResolved!(640, 360);
        await tester.pump();

        expect(_thumbnailAspectRatio(tester), equals(640 / 360));
      },
    );

    testWidgets(
      'updates partial metadata aspect ratio from the displayed cached image',
      (tester) async {
        final videoWithPartialDimensions = createTestVideoEvent(
          id: 'test-partial-dimensions',
          thumbnailUrl: 'https://example.com/thumb-partial.jpg',
          dimensions: '640x',
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: videoWithPartialDimensions,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        expect(_thumbnailAspectRatio(tester), equals(2 / 3));

        final cachedImage = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        cachedImage.onImageDimensionsResolved!(640, 360);
        await tester.pump();

        expect(_thumbnailAspectRatio(tester), equals(640 / 360));
      },
    );

    testWidgets('ignores stale image dimensions after thumbnail URL changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      final staleCallback = tester
          .widget<VineCachedImage>(find.byType(VineCachedImage))
          .onImageDimensionsResolved!;

      final nextVideo = createTestVideoEvent(
        id: 'test-next',
        thumbnailUrl: 'https://example.com/thumb-next.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: nextVideo,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      staleCallback(640, 360);
      await tester.pump();

      expect(_thumbnailAspectRatio(tester), equals(2 / 3));
    });

    testWidgets(
      'uses Image.network for Divine-hosted thumbnails to avoid cache-manager stalls',
      (tester) async {
        final divineHostedVideo = createTestVideoEvent(
          id: 'test-divine',
          thumbnailUrl: 'https://media.divine.video/72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995.jpg',
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: divineHostedVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets(
      'resolves aspect ratio via the Image.network path for Divine thumbnails',
      (tester) async {
        final divineHostedVideo = createTestVideoEvent(
          id: 'test-divine-dims',
          thumbnailUrl: 'https://media.divine.video/72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995.jpg',
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: divineHostedVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        expect(_thumbnailAspectRatio(tester), equals(2 / 3));

        // The Image.network path has no built-in dimension callback, so it
        // wraps the image in an ImageWithDimensionsListener to recover the
        // aspect ratio from the displayed image.
        final listener = tester.widget<ImageWithDimensionsListener>(
          find.byType(ImageWithDimensionsListener),
        );
        listener.onImageDimensionsResolved!(640, 360);
        await tester.pump();

        expect(_thumbnailAspectRatio(tester), equals(640 / 360));
      },
    );

    testWidgets(
      'Divine Image.network path honors caller placeholder and error widget',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';

        await tester.pumpWidget(
          ProviderScope(
            overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
            child: MaterialApp(
              home: PassiveAuthThumbnailImage(
                url: url,
                placeholder: (_, _) =>
                    const Text('caller thumbnail placeholder'),
                errorWidget: (_, _, _) => const Text('caller thumbnail error'),
              ),
            ),
          ),
        );

        expect(find.text('caller thumbnail placeholder'), findsOneWidget);

        final image = tester.widget<Image>(find.byType(Image));
        final errorResult = image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 500, uri: Uri.parse(url)),
          StackTrace.current,
        );

        await tester.pumpWidget(MaterialApp(home: errorResult));

        expect(find.text('caller thumbnail error'), findsOneWidget);
        verifyNever(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        );
      },
    );

    testWidgets(
      'retries Divine-hosted thumbnails with passive BUD-01 auth after 401',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';
        when(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async =>
              const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoThumbnailWidget(
                  video: createTestVideoEvent(
                    id: 'test-auth-thumb',
                    thumbnailUrl: url,
                  ),
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        final image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );

        await tester.pump();
        await tester.pump();

        final retriedImage = tester.widget<Image>(find.byType(Image));
        final resizedProvider = retriedImage.image as ResizeImage;
        final networkProvider = resizedProvider.imageProvider as NetworkImage;
        expect(
          networkProvider.headers,
          equals({'Authorization': 'Nostr token'}),
        );
        verify(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: hash,
            serverUrl: 'https://media.divine.video',
          ),
        ).called(1);
      },
    );

    testWidgets('does not retry non-Divine thumbnails with passive auth', (
      tester,
    ) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      const hash =
          '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
      const url = 'https://evil.example/$hash.jpg';

      await tester.pumpWidget(
        ProviderScope(
          overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: createTestVideoEvent(
                  id: 'test-host-gated-thumb',
                  thumbnailUrl: url,
                ),
                width: 200,
                height: 200,
              ),
            ),
          ),
        ),
      );

      final cachedImage = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      cachedImage.errorWidget!(
        tester.element(find.byType(VineCachedImage)),
        url,
        const MediaCacheImageLoadException(url),
      );

      await tester.pump();

      verifyNever(
        () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
    });

    testWidgets(
      'clears passive auth headers when adult media access is revoked',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';
        when(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async =>
              const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoThumbnailWidget(
                  video: createTestVideoEvent(
                    id: 'test-revoked-auth-thumb',
                    thumbnailUrl: url,
                  ),
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        var image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();

        image = tester.widget<Image>(find.byType(Image));
        var resizedProvider = image.image as ResizeImage;
        var networkProvider = resizedProvider.imageProvider as NetworkImage;
        expect(
          networkProvider.headers,
          equals({'Authorization': 'Nostr token'}),
        );

        ProviderScope.containerOf(
          tester.element(find.byType(VideoThumbnailWidget)),
          listen: false,
        ).read(adultMediaAccessRevocationVersionProvider.notifier).increment();
        await tester.pump();

        image = tester.widget<Image>(find.byType(Image));
        resizedProvider = image.image as ResizeImage;
        networkProvider = resizedProvider.imageProvider as NetworkImage;
        expect(networkProvider.headers, isNull);
      },
    );

    testWidgets(
      'ignores passive auth result that resolves after adult access is revoked',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';
        final authHeaders = Completer<ViewerAuthResult>();
        when(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) => authHeaders.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoThumbnailWidget(
                  video: createTestVideoEvent(
                    id: 'test-stale-auth-result-thumb',
                    thumbnailUrl: url,
                  ),
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        var image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();

        ProviderScope.containerOf(
          tester.element(find.byType(VideoThumbnailWidget)),
          listen: false,
        ).read(adultMediaAccessRevocationVersionProvider.notifier).increment();
        await tester.pump();

        authHeaders.complete(
          const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
        );
        await tester.pump();

        image = tester.widget<Image>(find.byType(Image));
        final resizedProvider = image.image as ResizeImage;
        final networkProvider = resizedProvider.imageProvider as NetworkImage;
        expect(networkProvider.headers, isNull);
        verify(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: hash,
            serverUrl: 'https://media.divine.video',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'retries same mounted Divine thumbnail after adult preferences change from hide to show',
      (tester) async {
        final sharedPreferences = await SharedPreferences.getInstance();
        final mediaViewerAuthService = _MockMediaViewerAuthService();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';
        when(
          () => mediaViewerAuthService.canCreatePassiveHeaders,
        ).thenReturn(true);
        when(
          () => mediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async =>
              const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
        );
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(
          '1111111111111111111111111111111111111111111111111111111111111111',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._passiveAuthProviderOverridesWithRealServices(
                mediaViewerAuthService: mediaViewerAuthService,
                sharedPreferences: sharedPreferences,
              ),
              authServiceProvider.overrideWithValue(authService),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoThumbnailWidget(
                  video: createTestVideoEvent(
                    id: 'test-adult-preference-rearm-thumb',
                    thumbnailUrl: url,
                  ),
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(VideoThumbnailWidget)),
          listen: false,
        );
        final ageVerificationService = container.read(
          ageVerificationServiceProvider,
        );
        await ageVerificationService.setAdultContentVerified(true);
        final filterService = container.read(contentFilterServiceProvider);
        await filterService.initialized;

        var image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();

        verifyNever(
          () => mediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        );

        await filterService.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.show,
        );
        await filterService.setPreference(
          ContentLabel.sexual,
          ContentFilterPreference.show,
        );
        await tester.pump();

        image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();

        final retriedImage = tester.widget<Image>(find.byType(Image));
        final resizedProvider = retriedImage.image as ResizeImage;
        final networkProvider = resizedProvider.imageProvider as NetworkImage;
        expect(
          networkProvider.headers,
          equals({'Authorization': 'Nostr token'}),
        );
        verify(
          () => mediaViewerAuthService.createAuthHeaders(
            sha256Hash: hash,
            serverUrl: 'https://media.divine.video',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'does not retry non-content-addressed Divine thumbnail URLs with auth',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const url = 'https://media.divine.video/not-a-hash.jpg';

        await tester.pumpWidget(
          ProviderScope(
            overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoThumbnailWidget(
                  video: createTestVideoEvent(
                    id: 'test-no-hash-thumb',
                    thumbnailUrl: url,
                  ),
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        final image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );

        await tester.pump();

        verifyNever(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        );
      },
    );

    testWidgets(
      'records unavailable non-content-addressed thumbnails without rebuilding during build',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const url = 'https://media.divine.video/not-a-hash.jpg';
        late StateSetter rebuild;
        var reportErrorDuringBuild = false;
        Image? image;

        await tester.pumpWidget(
          ProviderScope(
            overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
            child: MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return Row(
                    children: [
                      const PassiveAuthThumbnailImage(url: url),
                      Builder(
                        builder: (context) {
                          if (reportErrorDuringBuild) {
                            image!.errorBuilder!(
                              tester.element(find.byType(Image)),
                              NetworkImageLoadException(
                                statusCode: 401,
                                uri: Uri.parse(url),
                              ),
                              StackTrace.current,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        image = tester.widget<Image>(find.byType(Image));

        rebuild(() => reportErrorDuringBuild = true);
        await tester.pump();

        expect(tester.takeException(), isNull);
        verifyNever(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        );
      },
    );

    testWidgets(
      'suppresses repeated unauthenticated Divine thumbnail requests after passive auth is unavailable',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';
        when(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => const ViewerAuthUnavailable());

        final container = ProviderContainer(
          overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
        );
        addTearDown(container.dispose);

        Widget buildSubject() => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PassiveAuthThumbnailImage(
              url: url,
              errorWidget: (_, _, error) => Text('fallback: $error'),
            ),
          ),
        );

        await tester.pumpWidget(buildSubject());

        final image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(Image), findsNothing);
        expect(find.textContaining('fallback:'), findsOneWidget);
        verify(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: hash,
            serverUrl: 'https://media.divine.video',
          ),
        ).called(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(buildSubject());

        expect(find.byType(Image), findsNothing);
        expect(find.textContaining('fallback:'), findsOneWidget);
        verifyNoMoreInteractions(mediaAuthInterceptor);
      },
    );

    testWidgets(
      'suppresses repeated unauthenticated Divine thumbnail requests after passive auth is blocked by preference',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';
        when(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => const ViewerAuthBlockedByPreference());

        final container = ProviderContainer(
          overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
        );
        addTearDown(container.dispose);

        Widget buildSubject() => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PassiveAuthThumbnailImage(
              url: url,
              errorWidget: (_, _, error) => Text('fallback: $error'),
            ),
          ),
        );

        await tester.pumpWidget(buildSubject());

        final image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(Image), findsNothing);
        expect(find.textContaining('fallback:'), findsOneWidget);
        verify(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: hash,
            serverUrl: 'https://media.divine.video',
          ),
        ).called(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(buildSubject());

        expect(find.byType(Image), findsNothing);
        expect(find.textContaining('fallback:'), findsOneWidget);
        verifyNoMoreInteractions(mediaAuthInterceptor);
      },
    );

    testWidgets(
      'retries a suppressed thumbnail after a transient signer timeout',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';
        when(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => const ViewerAuthSignerUnreachable());
        final container = ProviderContainer(
          overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
        );
        addTearDown(container.dispose);

        Widget buildSubject() => UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PassiveAuthThumbnailImage(url: url)),
        );

        await tester.pumpWidget(buildSubject());
        var image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(buildSubject());
        image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();

        verify(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: hash,
            serverUrl: 'https://media.divine.video',
          ),
        ).called(2);
      },
    );

    testWidgets('does not retry a signer timeout on a retained-state rebuild', (
      tester,
    ) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      const hash =
          '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
      const url = 'https://media.divine.video/$hash.jpg';
      when(
        () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer((_) async => const ViewerAuthSignerUnreachable());
      final container = ProviderContainer(
        overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
      );
      addTearDown(container.dispose);

      Widget buildSubject(double width) => UncontrolledProviderScope(
        container: container,
        child: testMaterialApp(
          home: PassiveAuthThumbnailImage(url: url, width: width),
        ),
      );

      await tester.pumpWidget(buildSubject(100));
      var image = tester.widget<Image>(find.byType(Image));
      image.errorBuilder!(
        tester.element(find.byType(Image)),
        NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
        StackTrace.current,
      );
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(buildSubject(101));
      image = tester.widget<Image>(find.byType(Image));
      image.errorBuilder!(
        tester.element(find.byType(Image)),
        NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
        StackTrace.current,
      );
      await tester.pump();
      await tester.pump();

      verify(
        () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
          sha256Hash: hash,
          serverUrl: 'https://media.divine.video',
        ),
      ).called(1);
    });

    testWidgets(
      'retries a suppressed thumbnail after filters change while unmounted',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';
        when(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => const ViewerAuthUnavailable());
        final container = ProviderContainer(
          overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
        );
        addTearDown(container.dispose);

        Widget buildSubject() => UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PassiveAuthThumbnailImage(url: url)),
        );

        await tester.pumpWidget(buildSubject());
        final image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(Image), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        container.read(contentFilterVersionProvider.notifier).increment();
        await tester.pumpWidget(buildSubject());

        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets(
      'keeps one container suppressed when another container changes filters',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';
        when(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => const ViewerAuthUnavailable());
        final containerA = ProviderContainer(
          overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
        );
        final containerB = ProviderContainer(
          overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
        );
        addTearDown(containerA.dispose);
        addTearDown(containerB.dispose);

        Widget buildSubject(ProviderContainer container) =>
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: PassiveAuthThumbnailImage(url: url),
              ),
            );

        await tester.pumpWidget(buildSubject(containerB));
        final image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(Image), findsNothing);

        await tester.pumpWidget(buildSubject(containerA));
        containerA.read(contentFilterVersionProvider.notifier).increment();
        await tester.pump();
        await tester.pumpWidget(buildSubject(containerB));

        expect(find.byType(Image), findsNothing);
        verify(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: hash,
            serverUrl: 'https://media.divine.video',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'retries and suppresses again after cache expiry while mounted',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        const hash =
            '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';
        const url = 'https://media.divine.video/$hash.jpg';
        when(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => const ViewerAuthUnavailable());
        final container = ProviderContainer(
          overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
        );
        addTearDown(container.dispose);

        Widget buildSubject(double width) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PassiveAuthThumbnailImage(url: url, width: width),
          ),
        );

        await tester.pumpWidget(buildSubject(100));
        var image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(Image), findsNothing);

        PassiveAuthThumbnailImage.debugExpireUnauthorizedCache();
        await tester.pumpWidget(buildSubject(101));
        image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(Image), findsNothing);
        verify(
          () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
            sha256Hash: hash,
            serverUrl: 'https://media.divine.video',
          ),
        ).called(2);
      },
    );

    testWidgets('bounds the unavailable thumbnail cache', (tester) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final container = ProviderContainer(
        overrides: _passiveAuthProviderOverrides(mediaAuthInterceptor),
      );
      addTearDown(container.dispose);

      for (var index = 0; index < 129; index++) {
        final url = 'https://media.divine.video/not-a-hash-$index.jpg';
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: PassiveAuthThumbnailImage(url: url)),
          ),
        );
        final image = tester.widget<Image>(find.byType(Image));
        image.errorBuilder!(
          tester.element(find.byType(Image)),
          NetworkImageLoadException(statusCode: 401, uri: Uri.parse(url)),
          StackTrace.current,
        );
        await tester.pump();
      }

      expect(PassiveAuthThumbnailImage.debugUnauthorizedCacheLength, 128);
      verifyNever(
        () => mediaAuthInterceptor.createPassiveAuthHeadersForAdultMedia(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
    });

    testWidgets(
      'ImageWithDimensionsListener reports decoded image dimensions',
      (tester) async {
        final image = _syncImage(640, 360);
        addTearDown(image.dispose);

        int? width;
        int? height;
        await tester.pumpWidget(
          MaterialApp(
            home: ImageWithDimensionsListener(
              imageProvider: _syncImageProvider(image),
              onImageDimensionsResolved: (w, h) {
                width = w;
                height = h;
              },
              child: const SizedBox.shrink(),
            ),
          ),
        );

        expect(width, equals(640));
        expect(height, equals(360));
      },
    );

    testWidgets(
      'ImageWithDimensionsListener defers synchronous parent state updates',
      (tester) async {
        final image = _syncImage(640, 360);
        addTearDown(image.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: _DimensionCallbackParent(
              imageProvider: _syncImageProvider(image),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('640x360'), findsOneWidget);
      },
    );

    testWidgets(
      'ImageWithDimensionsListener leaves the framework its own image handle',
      (tester) async {
        final image = _syncImage(640, 360);
        addTearDown(image.dispose);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ImageWithDimensionsListener(
              imageProvider: _syncImageProvider(image),
              onImageDimensionsResolved: (_, _) {},
              child: const SizedBox.shrink(),
            ),
          ),
        );

        // More than one open handle means the framework got a clone of its
        // own, so the `image.dispose` above is not the last one. Drop the
        // clone from [_SyncImageProvider] and this reads exactly one: the
        // cache's deferred disposal then trips `ImageInfo.dispose`'s
        // open-handle assertion inside whichever unrelated test pumps the
        // next frame.
        expect(
          image.debugGetOpenHandleStackTraces(),
          hasLength(greaterThan(1)),
        );
      },
    );

    testWidgets(
      'a cached sync image outlives the test disposing its original handle',
      (tester) async {
        // Regression for #8652: ImageInfo owns the handle it is given, so the
        // completer must hold its own clone. Sharing the test's handle put the
        // cache's deferred disposal onto an already-disposed image and failed
        // whichever later test pumped that frame.
        final image = _syncImage(8, 8);
        final provider = _SyncImageProvider(image);
        await tester.pumpWidget(
          ImageWithDimensionsListener(
            imageProvider: provider,
            child: const SizedBox.shrink(),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        final cache = PaintingBinding.instance.imageCache;
        expect(cache.containsKey(provider), isTrue);

        image.dispose();
        expect(cache.evict(provider), isTrue);
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('displays flat placeholder when only blurhash is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show Container with surfaceContainer color as placeholder
      // (current implementation uses flat color instead of blurhash)
      expect(find.byType(Container), findsWidgets);

      // Should not show VineCachedImage since no thumbnail URL.
      expect(find.byType(VineCachedImage), findsNothing);
    });

    testWidgets('displays thumbnail with flat background when both exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBoth,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Should show VineCachedImage for thumbnail.
      expect(find.byType(VineCachedImage), findsOneWidget);
      expect(find.byType(Stack), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'displays flat placeholder when neither thumbnail nor blurhash exists',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: videoWithNeither,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show Container with surfaceContainer color as placeholder
        expect(find.byType(Container), findsWidgets);

        // Should not show VineCachedImage since no thumbnail URL.
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets('shows play icon when requested', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
              showPlayIcon: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show play icon
      expect(_divineIcon(DivineIconName.play), findsOneWidget);

      // Default badge keeps the full-size glyph (two-thirds of 48).
      final icon = tester.widget<DivineIcon>(_divineIcon(DivineIconName.play));
      expect(icon.size, 32);
    });

    testWidgets('applies border radius when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );

      // Should have ClipRRect with border radius
      expect(find.byType(ClipRRect), findsOneWidget);
      final ClipRRect clipRRect = tester.widget(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, equals(BorderRadius.circular(16)));
    });

    testWidgets('updates when video changes', (tester) async {
      // Start with video that has thumbnail
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Initially shows VineCachedImage for thumbnail.
      expect(find.byType(VineCachedImage), findsOneWidget);

      // Update to video with only blurhash (no thumbnail)
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should now show flat placeholder (no VineCachedImage).
      expect(find.byType(VineCachedImage), findsNothing);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets(
      'updates blurhash placeholder when enrichment returns same id new instance',
      (tester) async {
        const enrichedBlurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
        final unenrichedVideo = createTestVideoEvent(
          id: 'same-id',
          hashtags: const ['dance'],
        );
        final enrichedVideo = createTestVideoEvent(
          id: 'same-id',
          blurhash: enrichedBlurhash,
          hashtags: const ['dance'],
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: unenrichedVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(
          tester.widget<BlurhashDisplay>(find.byType(BlurhashDisplay)).blurhash,
          isNull,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: enrichedVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          tester.widget<BlurhashDisplay>(find.byType(BlurhashDisplay)).blurhash,
          enrichedBlurhash,
        );
      },
    );

    testWidgets(
      'updates derived content-type placeholder when metadata changes',
      (tester) async {
        final unknownVideo = createTestVideoEvent(
          id: 'same-id',
          hashtags: const ['random'],
          title: 'plain title',
          content: 'nothing special',
        );
        final danceVideo = createTestVideoEvent(
          id: 'same-id',
          hashtags: const ['dance'],
          title: 'plain title',
          content: 'nothing special',
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: unknownVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(
          tester
              .widget<BlurhashDisplay>(find.byType(BlurhashDisplay))
              .contentType,
          isNull,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: danceVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          tester
              .widget<BlurhashDisplay>(find.byType(BlurhashDisplay))
              .contentType,
          VineContentType.dance,
        );
      },
    );

    testWidgets('does not try to generate thumbnails when URL is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show flat placeholder, not loading indicator or image
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(VineCachedImage), findsNothing);
    });

    testWidgets('handles empty thumbnail URL as null', (tester) async {
      final videoWithEmptyUrl = createTestVideoEvent(
        id: 'test5',
        thumbnailUrl: '',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithEmptyUrl,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should treat empty URL as null and show flat placeholder
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(VineCachedImage), findsNothing);
    });
  });
}

class _DimensionCallbackParent extends StatefulWidget {
  const _DimensionCallbackParent({required this.imageProvider});

  final ImageProvider<Object> imageProvider;

  @override
  State<_DimensionCallbackParent> createState() =>
      _DimensionCallbackParentState();
}

class _DimensionCallbackParentState extends State<_DimensionCallbackParent> {
  int? _width;
  int? _height;

  @override
  Widget build(BuildContext context) {
    return ImageWithDimensionsListener(
      imageProvider: widget.imageProvider,
      onImageDimensionsResolved: (width, height) {
        setState(() {
          _width = width;
          _height = height;
        });
      },
      child: Text('${_width ?? 0}x${_height ?? 0}'),
    );
  }
}
