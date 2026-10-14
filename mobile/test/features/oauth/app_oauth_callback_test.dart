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

    for (final fragment in const ['#_', '#_=_']) {
      test('drops a provider-added $fragment fragment', () {
        // Instagram appends `#_` and Facebook `#_=_` to their redirect, and a
        // browser carries that fragment across the server's own 302 to this
        // callback. Nothing is read from a fragment, so it is not a reason to
        // throw away the outcome the query carries.
        final uri = parseAppOAuthCallback(
          '$appOAuthCallbackUrl'
          '?app_state=nonce&connection=failed&platform=instagram'
          '$fragment',
        );

        expect(uri.hasFragment, isFalse);
        expect(
          uri.toString(),
          equals(
            '$appOAuthCallbackUrl'
            '?app_state=nonce&connection=failed&platform=instagram',
          ),
        );
      });
    }

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

    test('returns the callback without a provider-added fragment', () async {
      final uri = await launchAppOAuth(
        Uri.parse('https://crosspost.divine.video/connect/instagram'),
        authenticate: ({
          required String url,
          required String callbackUrlScheme,
          required FlutterWebAuth2Options options,
        }) async => '$appOAuthCallbackUrl?connection=failed#_',
      );

      expect(uri?.hasFragment, isFalse);
      expect(uri?.queryParameters['connection'], equals('failed'));
    });

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

  group('the verifier sign-in code', () {
    const code = 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC';

    test('keeps a code sent after the # as a query value', () {
      final uri = parseAppOAuthCallback(
        'https://divine.video/app/callback?signin=abc&platform=bluesky'
        '#oauth_confirm=$code',
      );
      expect(uri.hasFragment, isFalse);
      expect(uri.queryParameters['oauth_confirm'], equals(code));
      expect(uri.queryParameters['signin'], equals('abc'));
    });

    test('prefers the code after the # to one in the query', () {
      final uri = parseAppOAuthCallback(
        'https://divine.video/app/callback?oauth_confirm=old'
        '#oauth_confirm=$code',
      );
      expect(uri.queryParameters['oauth_confirm'], equals(code));
    });

    test('still reads a code sent in the query', () {
      final uri = parseAppOAuthCallback(
        'https://divine.video/app/callback?signin=abc&oauth_confirm=$code',
      );
      expect(uri.queryParameters['oauth_confirm'], equals(code));
    });

    test('reads the code next to a provider junk fragment', () {
      final uri = parseAppOAuthCallback(
        'https://divine.video/app/callback?signin=abc'
        '#oauth_confirm=$code&_=_',
      );
      expect(uri.queryParameters['oauth_confirm'], equals(code));
    });

    test('takes no code from a fragment that does not decode', () {
      final uri = parseAppOAuthCallback(
        'https://divine.video/app/callback?signin=abc#oauth_confirm=%E0',
      );
      expect(uri.hasFragment, isFalse);
      expect(uri.queryParameters, equals({'signin': 'abc'}));
    });

    test('keeps repeated query keys when it adds the code', () {
      final uri = parseAppOAuthCallback(
        'https://divine.video/app/callback?a=1&a=2#oauth_confirm=$code',
      );
      expect(uri.queryParametersAll['a'], equals(['1', '2']));
      expect(uri.queryParameters['oauth_confirm'], equals(code));
    });

    test('lets an empty code after the # leave the query code alone', () {
      final uri = parseAppOAuthCallback(
        'https://divine.video/app/callback?oauth_confirm=$code#oauth_confirm=',
      );
      expect(uri.queryParameters['oauth_confirm'], equals(code));
    });

    test('treats an empty code in the query as no code', () {
      final uri = parseAppOAuthCallback(
        'https://divine.video/app/callback?signin=abc&oauth_confirm=',
      );
      expect(uri.queryParameters, equals({'signin': 'abc'}));
    });

    test('drops a junk fragment with no code, as before', () {
      final uri = parseAppOAuthCallback(
        'https://divine.video/app/callback?code=k#_=_',
      );
      expect(uri.hasFragment, isFalse);
      expect(uri.queryParameters, equals({'code': 'k'}));
    });
  });
}
