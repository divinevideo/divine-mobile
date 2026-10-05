import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/feed_viewer_preference_hints.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/services/geo_blocking_service.dart';
import 'package:openvine/services/language_preference_service.dart';

class _TestLanguagePreferenceService extends LanguagePreferenceService {
  _TestLanguagePreferenceService(this._contentLanguage);

  final String _contentLanguage;

  @override
  Future<void> initialize() async {}

  @override
  String get contentLanguage => _contentLanguage;
}

class _InitializingLanguagePreferenceService extends LanguagePreferenceService {
  _InitializingLanguagePreferenceService(this._initializeCompleter);

  final Completer<void> _initializeCompleter;
  var _initialized = false;

  @override
  Future<void> initialize() async {
    await _initializeCompleter.future;
    _initialized = true;
  }

  @override
  String get contentLanguage => _initialized ? 'es' : 'en';
}

class _TestGeoBlockingService extends GeoBlockingService {
  _TestGeoBlockingService(this._response);

  final GeoBlockResponse _response;

  @override
  Future<GeoBlockResponse> getGeoInfo() async => _response;
}

void main() {
  group('buildPreferredFeedLanguages', () {
    test(
      'builds ordered unique language hints from content app and device languages',
      () {
        final languages = buildPreferredFeedLanguages(
          contentLanguage: 'pt-BR',
          appLocale: 'es',
          deviceLocales: const [Locale('en', 'US'), Locale('pt', 'PT')],
        );

        expect(languages, equals(['pt', 'es', 'en']));
      },
    );
  });

  group('readFeedViewerPreferenceHints', () {
    test(
      'reads content language and viewer country hints for feed requests',
      () async {
        final container = ProviderContainer(
          overrides: [
            languagePreferenceServiceProvider.overrideWithValue(
              _TestLanguagePreferenceService('pt'),
            ),
            geoBlockingServiceProvider.overrideWithValue(
              _TestGeoBlockingService(
                GeoBlockResponse(
                  blocked: false,
                  country: 'BR',
                  region: 'UNKNOWN',
                  city: 'UNKNOWN',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final hints = await readFeedViewerPreferenceHints(container.read);

        expect(hints.preferredLanguages.first, equals('pt'));
        expect(hints.viewerCountry, equals('BR'));
      },
    );

    test(
      'waits for content language initialization before reading hints',
      () async {
        final initializeCompleter = Completer<void>();
        final container = ProviderContainer(
          overrides: [
            languagePreferenceServiceProvider.overrideWithValue(
              _InitializingLanguagePreferenceService(initializeCompleter),
            ),
            geoBlockingServiceProvider.overrideWithValue(
              _TestGeoBlockingService(
                GeoBlockResponse(
                  blocked: false,
                  country: 'US',
                  region: 'UNKNOWN',
                  city: 'UNKNOWN',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final hintsFuture = readFeedViewerPreferenceHints(container.read);
        var completed = false;
        unawaited(
          hintsFuture.then<void>((_) {
            completed = true;
          }),
        );
        await pumpEventQueue();

        expect(completed, isFalse);

        initializeCompleter.complete();
        final hints = await hintsFuture;

        expect(hints.preferredLanguages.first, equals('es'));
      },
    );

    test('omits unknown viewer country', () async {
      final container = ProviderContainer(
        overrides: [
          languagePreferenceServiceProvider.overrideWithValue(
            _TestLanguagePreferenceService('en'),
          ),
          geoBlockingServiceProvider.overrideWithValue(
            _TestGeoBlockingService(
              GeoBlockResponse(
                blocked: false,
                country: 'UNKNOWN',
                region: 'UNKNOWN',
                city: 'UNKNOWN',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final hints = await readFeedViewerPreferenceHints(container.read);

      expect(hints.preferredLanguages.first, equals('en'));
      expect(hints.viewerCountry, isNull);
    });
  });
}
