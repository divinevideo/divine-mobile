// ABOUTME: Tests the shared Divine OAuth callback parser and session adapter.
// ABOUTME: Pins that only the exact return route is accepted.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:openvine/features/oauth/app_oauth_callback.dart';

void main() {
  group('parseAppOAuthCallback', () {
    test('accepts the canonical callback and keeps its query', () {
      final uri = parseAppOAuthCallback(
        '$appOAuthCallbackUrl?oauth_verified=true&identity=jack',
      );

      expect(uri.host, equals(appOAuthCallbackHost));
      expect(uri.path, equals(appOAuthCallbackPath));
      expect(uri.queryParameters['identity'], equals('jack'));
    });

    test('rejects another host', () {
      expect(
        () => parseAppOAuthCallback('https://evil.example/app/callback'),
        throwsFormatException,
      );
    });

    test('rejects a look-alike subdomain', () {
      expect(
        () => parseAppOAuthCallback(
          'https://divine.video.evil.example/app/callback',
        ),
        throwsFormatException,
      );
    });

    test('rejects embedded user info', () {
      expect(
        () => parseAppOAuthCallback(
          'https://divine.video@evil.example/app/callback',
        ),
        throwsFormatException,
      );
    });

    test('rejects an explicit port', () {
      expect(
        () => parseAppOAuthCallback('https://divine.video:8443/app/callback'),
        throwsFormatException,
      );
    });

    test('rejects another path', () {
      expect(
        () => parseAppOAuthCallback('https://divine.video/app/other'),
        throwsFormatException,
      );
    });

    test('rejects a malformed percent escape', () {
      expect(
        () => parseAppOAuthCallback('https://divine.video/app/callback?a=%zz'),
        throwsFormatException,
      );
    });

    test('keeps the OAuth code and state out of the rejection', () {
      // Carried over from the crossposting parser this replaced. The rejection
      // is logged with the whole callback in scope, so the exception must not
      // carry the grant back into a log line.
      const secretCode = 'oauth-code-super-secret';
      const secretState = 'oauth-state-super-secret';
      FormatException? caught;

      try {
        parseAppOAuthCallback(
          'https://divine.video:443/app/callback'
          '?code=$secretCode&state=$secretState',
        );
      } on FormatException catch (error) {
        caught = error;
      }

      expect(caught, isNotNull);
      expect(caught?.source, isNull);
      expect(caught.toString(), isNot(contains(secretCode)));
      expect(caught.toString(), isNot(contains(secretState)));
    });
  });

  group('launchAppOAuth', () {
    test(
      'passes the authorization URL and callback route to the session',
      () async {
        late String seenUrl;
        final uri = await launchAppOAuth(
          Uri.parse('https://verifier.divine.video/auth/twitter/start'),
          authenticate:
              ({
                required String url,
                required String callbackUrlScheme,
                required FlutterWebAuth2Options options,
              }) async {
                seenUrl = url;
                expect(callbackUrlScheme, equals(appOAuthCallbackScheme));
                expect(options.httpsHost, equals(appOAuthCallbackHost));
                expect(options.httpsPath, equals(appOAuthCallbackPath));
                return '$appOAuthCallbackUrl?ok=1';
              },
        );

        expect(
          seenUrl,
          equals('https://verifier.divine.video/auth/twitter/start'),
        );
        expect(uri?.queryParameters['ok'], equals('1'));
      },
    );

    test('reports a dismissed session as null', () async {
      final uri = await launchAppOAuth(
        Uri.parse('https://verifier.divine.video/auth/twitter/start'),
        authenticate: ({
          required String url,
          required String callbackUrlScheme,
          required FlutterWebAuth2Options options,
        }) async => throw PlatformException(code: 'CANCELED'),
      );

      expect(uri, isNull);
    });

    test('rethrows a platform failure that is not a cancel', () async {
      await expectLater(
        () => launchAppOAuth(
          Uri.parse('https://verifier.divine.video/auth/twitter/start'),
          authenticate: ({
            required String url,
            required String callbackUrlScheme,
            required FlutterWebAuth2Options options,
          }) async => throw PlatformException(code: 'BOOM'),
        ),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
