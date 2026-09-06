// ABOUTME: Tests for CrosspostingApiClient against the crossposter API shapes
// ABOUTME: Covers auth headers, parsing, error envelope, and edge cases

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group(CrosspostingApiClient, () {
    late _MockHttpClient httpClient;
    late CrosspostingApiClient client;
    late String? currentAccessToken;
    late Object? accessTokenError;

    const accessToken = 'session-access-token';

    setUpAll(() {
      registerFallbackValue(Uri());
    });

    setUp(() {
      httpClient = _MockHttpClient();
      currentAccessToken = accessToken;
      accessTokenError = null;
      client = CrosspostingApiClient(
        accessTokenReader: () async {
          final error = accessTokenError;
          if (error != null) throw error;
          return currentAccessToken;
        },
        httpClient: httpClient,
      );
    });

    void stubGet(String body, {int statusCode = 200}) {
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(body, statusCode));
    }

    group('getPlatforms', () {
      test('sends the Keycast bearer token and JSON content type', () async {
        stubGet(jsonEncode({'platforms': <Object>[]}));

        await client.getPlatforms();

        final captured = verify(
          () => httpClient.get(
            captureAny(),
            headers: captureAny(named: 'headers'),
          ),
        ).captured;
        final uri = captured[0] as Uri;
        final headers = captured[1] as Map<String, String>;
        expect(uri.path, equals('/platforms'));
        expect(headers['Authorization'], equals('Bearer $accessToken'));
        expect(headers['Content-Type'], equals('application/json'));
      });

      test('uses the production HTTPS origin by default', () async {
        stubGet(jsonEncode({'platforms': <Object>[]}));

        await client.getPlatforms();

        final uri =
            verify(
                  () => httpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.origin, equals('https://crossposter.divine.video'));
      });

      test('parses live /platforms response shape', () async {
        stubGet(
          jsonEncode({
            'platforms': [
              {
                'platform': 'instagram',
                'enabled': true,
                'supportsAutomatic': true,
              },
              {
                'platform': 'tiktok',
                'enabled': false,
                'supportsAutomatic': true,
              },
              {'platform': 'x', 'enabled': true, 'supportsAutomatic': true},
            ],
          }),
        );

        final platforms = await client.getPlatforms();

        expect(platforms, hasLength(3));
        expect(platforms.first.platform, CrosspostingPlatform.instagram);
        expect(platforms.first.enabled, isTrue);
        expect(platforms.first.supportsAutomatic, isTrue);
        expect(platforms[1].enabled, isFalse);
      });

      test('requests /platforms?format=json', () async {
        stubGet(jsonEncode({'platforms': <Object>[]}));

        await client.getPlatforms();

        final uri =
            verify(
                  () => httpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.path, equals('/platforms'));
        expect(uri.queryParameters['format'], equals('json'));
      });

      test('skips unknown platforms', () async {
        stubGet(
          jsonEncode({
            'platforms': [
              {'platform': 'myspace', 'enabled': true},
              {'platform': 'x', 'enabled': true, 'supportsAutomatic': false},
            ],
          }),
        );

        final platforms = await client.getPlatforms();

        expect(platforms, hasLength(1));
        expect(platforms.single.platform, CrosspostingPlatform.x);
        expect(platforms.single.supportsAutomatic, isFalse);
      });

      test('rejects a malformed platforms collection', () async {
        stubGet(jsonEncode({'platforms': <String, dynamic>{}}));

        await expectLater(
          client.getPlatforms(),
          throwsA(isA<CrosspostingApiException>()),
        );
      });

      test('rejects a missing platforms collection', () async {
        stubGet(jsonEncode(<String, dynamic>{}));

        await expectLater(
          client.getPlatforms(),
          throwsA(isA<CrosspostingApiException>()),
        );
      });

      for (final booleanField in const ['enabled', 'supportsAutomatic']) {
        test(
          'skips a platform entry with a non-boolean $booleanField',
          () async {
            stubGet(
              jsonEncode({
                'platforms': [
                  {
                    'platform': 'instagram',
                    'enabled': true,
                    'supportsAutomatic': true,
                    booleanField: 'not-a-boolean',
                  },
                  {
                    'platform': 'x',
                    'enabled': true,
                    'supportsAutomatic': false,
                  },
                ],
              }),
            );

            final platforms = await client.getPlatforms();

            expect(platforms, hasLength(1));
            expect(platforms.single.platform, CrosspostingPlatform.x);
          },
        );
      }

      test('skips a platform entry with a non-string platform field', () async {
        stubGet(
          jsonEncode({
            'platforms': [
              {'platform': 42, 'enabled': true},
              {'platform': 'x', 'enabled': true, 'supportsAutomatic': false},
            ],
          }),
        );

        final platforms = await client.getPlatforms();

        expect(platforms, hasLength(1));
        expect(platforms.single.platform, CrosspostingPlatform.x);
      });

      test('skips malformed fields on an unknown platform', () async {
        stubGet(
          jsonEncode({
            'platforms': [
              {'platform': 'myspace', 'enabled': 'not-a-boolean'},
            ],
          }),
        );

        await expectLater(client.getPlatforms(), completion(isEmpty));
      });
    });

    group('getConnections', () {
      test('sends bearer token and parses connections', () async {
        stubGet(
          jsonEncode({
            'connections': [
              {
                'id': 'conn-1',
                'platform': 'instagram',
                'externalAccountId': 'ig-123',
                'externalAccountName': 'divine.creator',
                'status': 'connected',
                'tokenExpiresAt': 1785542400,
              },
              {'id': 'conn-2', 'platform': 'x', 'status': 'needs_reauth'},
            ],
          }),
        );

        final connections = await client.getConnections();

        final captured = verify(
          () => httpClient.get(
            captureAny(),
            headers: captureAny(named: 'headers'),
          ),
        ).captured;
        final uri = captured[0] as Uri;
        final headers = captured[1] as Map<String, String>;
        expect(uri.path, equals('/connections'));
        expect(headers['Authorization'], equals('Bearer $accessToken'));
        expect(headers['Content-Type'], equals('application/json'));

        expect(connections, hasLength(2));
        expect(connections.first.id, equals('conn-1'));
        expect(connections.first.externalAccountId, equals('ig-123'));
        expect(
          connections.first.status,
          CrosspostingConnectionStatus.connected,
        );
        expect(connections.first.externalAccountName, equals('divine.creator'));
        expect(connections[1].status, CrosspostingConnectionStatus.needsReauth);
      });

      // The server sends more fields than this client models — tokenExpiresAt,
      // grantedScopes, createdAt, updatedAt, lastRefreshAt. Reading one it does
      // not model must never cost the user the connection: _optionalJsonField
      // throws on a type mismatch and getConnections turns that into a skipped
      // entry, so a connected account would silently render as "Not connected"
      // (#7802).
      test(
        'keeps a connection carrying server fields it does not model',
        () async {
          stubGet(
            jsonEncode({
              'connections': [
                {
                  'id': 'conn-1',
                  'platform': 'instagram',
                  'status': 'connected',
                  'externalAccountName': 'divine.creator',
                  // Epoch seconds today; an ISO-8601 string is the shape a
                  // server-side change would plausibly take.
                  'tokenExpiresAt': '2026-07-22T00:00:00Z',
                  'grantedScopes': 'publish',
                  'lastRefreshAt': null,
                },
              ],
            }),
          );

          final connections = await client.getConnections();

          expect(connections, hasLength(1));
          expect(connections.single.id, equals('conn-1'));
          expect(
            connections.single.status,
            CrosspostingConnectionStatus.connected,
          );
          expect(
            connections.single.externalAccountName,
            equals('divine.creator'),
          );
        },
      );

      test('skips connections for unknown server platforms', () async {
        stubGet(
          jsonEncode({
            'connections': [
              {'id': 'conn-1', 'platform': 'myspace', 'status': 'connected'},
              {'id': 'conn-2', 'platform': 'x', 'status': 'connected'},
            ],
          }),
        );

        final connections = await client.getConnections();

        expect(connections, hasLength(1));
        expect(connections.single.platform, CrosspostingPlatform.x);
      });

      test('maps unknown status to disconnected', () async {
        stubGet(
          jsonEncode({
            'connections': [
              {'id': 'conn-1', 'platform': 'x', 'status': 'mystery'},
            ],
          }),
        );

        final connections = await client.getConnections();

        expect(
          connections.single.status,
          CrosspostingConnectionStatus.disconnected,
        );
      });

      test('throws $CrosspostingApiException with parsed error envelope '
          'on 401', () async {
        stubGet(
          jsonEncode({
            'error': {
              'code': 'unauthorized',
              'message': 'missing bearer token',
            },
          }),
          statusCode: 401,
        );

        expect(
          () => client.getConnections(),
          throwsA(
            isA<CrosspostingApiException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having((e) => e.code, 'code', 'unauthorized')
                .having(
                  (e) => e.message,
                  'message',
                  'missing bearer token',
                )
                .having(
                  (e) => e.kind,
                  'kind',
                  CrosspostingApiErrorKind.unauthorized,
                ),
          ),
        );
      });

      test('throws unauthorized when there is no session', () async {
        currentAccessToken = null;

        expect(
          () => client.getConnections(),
          throwsA(
            isA<CrosspostingApiException>().having(
              (e) => e.kind,
              'kind',
              CrosspostingApiErrorKind.unauthorized,
            ),
          ),
        );
        verifyNever(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        );
      });

      test(
        'translates token refresh network failures to unauthorized',
        () async {
          accessTokenError = OAuthNetworkException('offline');

          expect(
            () => client.getConnections(),
            throwsA(
              isA<CrosspostingApiException>()
                  .having(
                    (e) => e.kind,
                    'kind',
                    CrosspostingApiErrorKind.unauthorized,
                  )
                  .having(
                    (e) => e.cause,
                    'cause',
                    isA<OAuthNetworkException>(),
                  ),
            ),
          );
          verifyNever(
            () => httpClient.get(any(), headers: any(named: 'headers')),
          );
        },
      );

      test('rejects a malformed connections collection', () async {
        stubGet(jsonEncode({'connections': 'not-a-list'}));

        await expectLater(
          client.getConnections(),
          throwsA(isA<CrosspostingApiException>()),
        );
      });

      test('rejects a missing connections collection', () async {
        stubGet(jsonEncode(<String, dynamic>{}));

        await expectLater(
          client.getConnections(),
          throwsA(isA<CrosspostingApiException>()),
        );
      });

      for (final malformedField in const {
        'id': 42,
        'status': false,
        'externalAccountId': 42,
        'externalAccountName': <String>[],
      }.entries) {
        test(
          'skips a connection with a malformed ${malformedField.key}',
          () async {
            stubGet(
              jsonEncode({
                'connections': [
                  {
                    'id': 'conn-1',
                    'platform': 'instagram',
                    'status': 'connected',
                    malformedField.key: malformedField.value,
                  },
                  {'id': 'conn-2', 'platform': 'x', 'status': 'connected'},
                ],
              }),
            );

            final connections = await client.getConnections();

            expect(connections, hasLength(1));
            expect(connections.single.platform, CrosspostingPlatform.x);
          },
        );
      }
    });

    group('startConnection', () {
      for (final returnHost in const [
        'divine.video',
        'www.divine.video',
        'crossposter.divine.video',
      ]) {
        test('POSTs the exact returnUrl payload for $returnHost', () async {
          when(
            () => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer(
            (_) async => http.Response(
              jsonEncode({
                'authorizationUrl': 'https://instagram.example/oauth?x=1',
                'state': 'state-token',
              }),
              200,
            ),
          );
          final returnUrl = 'https://$returnHost/app/callback';

          final start = await client.startConnection(
            CrosspostingPlatform.instagram,
            returnUrl: Uri.parse(returnUrl),
          );

          final captured = verify(
            () => httpClient.post(
              captureAny(),
              headers: captureAny(named: 'headers'),
              body: captureAny(named: 'body'),
            ),
          ).captured;
          final uri = captured[0] as Uri;
          expect(uri.path, equals('/connections/instagram/start'));
          final headers = captured[1] as Map<String, String>;
          expect(headers['Authorization'], equals('Bearer $accessToken'));
          expect(headers['Content-Type'], equals('application/json'));
          final body = jsonDecode(captured[2] as String);
          expect(body, equals(<String, dynamic>{'returnUrl': returnUrl}));

          expect(
            start.authorizationUrl,
            equals(Uri.parse('https://instagram.example/oauth?x=1')),
          );
          expect(start.state, equals('state-token'));
        });
      }

      test('throws when authorization URL is missing', () async {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode({'state': 's'}), 200),
        );

        expect(
          () => client.startConnection(
            CrosspostingPlatform.x,
            returnUrl: Uri.parse('https://divine.video/app/callback'),
          ),
          throwsA(isA<CrosspostingApiException>()),
        );
      });

      for (final stateCase in const [
        ('missing', <String, dynamic>{}),
        ('empty', <String, dynamic>{'state': ''}),
        ('wrong type', <String, dynamic>{'state': 42}),
      ]) {
        test('accepts a ${stateCase.$1} state', () async {
          when(
            () => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer(
            (_) async => http.Response(
              jsonEncode({
                'authorizationUrl': 'https://instagram.example/oauth',
                ...stateCase.$2,
              }),
              200,
            ),
          );

          final start = await client.startConnection(
            CrosspostingPlatform.instagram,
            returnUrl: Uri.parse('https://divine.video/app/callback'),
          );
          expect(
            start.authorizationUrl,
            Uri.parse('https://instagram.example/oauth'),
          );
          expect(start.state, isNull);
        });
      }

      test('rejects a non-string authorizationUrl', () async {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'authorizationUrl': 42, 'state': 's'}),
            200,
          ),
        );

        await expectLater(
          client.startConnection(
            CrosspostingPlatform.instagram,
            returnUrl: Uri.parse('https://divine.video/app/callback'),
          ),
          throwsA(isA<CrosspostingApiException>()),
        );
      });

      test('rejects a non-HTTPS authorization URL', () async {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'authorizationUrl': 'http://instagram.example/oauth',
              'state': 's',
            }),
            200,
          ),
        );

        expect(
          () => client.startConnection(
            CrosspostingPlatform.instagram,
            returnUrl: Uri.parse('https://divine.video/app/callback'),
          ),
          throwsA(isA<CrosspostingApiException>()),
        );
      });

      for (final invalidReturnUrl in const {
        'custom scheme': 'divine://divine.video/app/callback',
        'HTTP scheme': 'http://divine.video/app/callback',
        'lookalike host': 'https://divine.video.evil.example/app/callback',
      }.entries) {
        test(
          'rejects a ${invalidReturnUrl.key} returnUrl before sending HTTP',
          () async {
            when(
              () => httpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ),
            ).thenAnswer(
              (_) async => http.Response(
                jsonEncode({
                  'authorizationUrl': 'https://instagram.example/oauth',
                  'state': 's',
                }),
                200,
              ),
            );
            Object? error;

            try {
              await client.startConnection(
                CrosspostingPlatform.instagram,
                returnUrl: Uri.parse(invalidReturnUrl.value),
              );
            } on Object catch (caught) {
              error = caught;
            }

            verifyNever(
              () => httpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ),
            );
            expect(error, isA<CrosspostingApiException>());
          },
        );
      }
    });

    group('disconnect', () {
      test('DELETEs the connection path', () async {
        when(
          () => httpClient.delete(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode({'disconnected': true}), 200),
        );

        await client.disconnect(CrosspostingPlatform.instagram, 'conn-1');

        final captured = verify(
          () => httpClient.delete(
            captureAny(),
            headers: captureAny(named: 'headers'),
          ),
        ).captured;
        final uri = captured[0] as Uri;
        final headers = captured[1] as Map<String, String>;
        expect(uri.path, equals('/connections/instagram/conn-1'));
        expect(headers['Authorization'], equals('Bearer $accessToken'));
        expect(headers['Content-Type'], equals('application/json'));
      });

      test('encodes a dynamic connection ID as one path segment', () async {
        when(
          () => httpClient.delete(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode({'disconnected': true}), 200),
        );

        await client.disconnect(
          CrosspostingPlatform.instagram,
          'account/with spaces?#',
        );

        final uri =
            verify(
                  () => httpClient.delete(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.pathSegments, [
          'connections',
          'instagram',
          'account/with spaces?#',
        ]);
        expect(uri.hasQuery, isFalse);
        expect(uri.hasFragment, isFalse);
      });

      test('accepts an empty successful response', () async {
        when(
          () => httpClient.delete(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('', 204));

        await expectLater(
          client.disconnect(CrosspostingPlatform.instagram, 'conn-1'),
          completes,
        );
      });
    });

    group('getPreferences', () {
      test('parses preferences with modes', () async {
        stubGet(
          jsonEncode({
            'preferences': [
              {
                'platform': 'instagram',
                'connectionId': 'conn-1',
                'mode': 'automatic',
              },
              {'platform': 'x', 'mode': 'manual'},
            ],
          }),
        );

        final preferences = await client.getPreferences();

        final captured = verify(
          () => httpClient.get(
            captureAny(),
            headers: captureAny(named: 'headers'),
          ),
        ).captured;
        expect((captured[0] as Uri).path, equals('/preferences'));
        final headers = captured[1] as Map<String, String>;
        expect(headers['Authorization'], equals('Bearer $accessToken'));
        expect(headers['Content-Type'], equals('application/json'));
        expect(preferences, hasLength(2));
        expect(preferences.first.mode, CrosspostingMode.automatic);
        expect(preferences.first.connectionId, equals('conn-1'));
        expect(preferences[1].mode, CrosspostingMode.manual);
      });

      test('skips preferences for unknown server platforms', () async {
        stubGet(
          jsonEncode({
            'preferences': [
              {'platform': 'myspace', 'mode': 'automatic'},
              {'platform': 'x', 'mode': 'manual'},
            ],
          }),
        );

        final preferences = await client.getPreferences();

        expect(preferences, hasLength(1));
        expect(preferences.single.platform, CrosspostingPlatform.x);
      });

      test('maps an unknown mode to disabled', () async {
        stubGet(
          jsonEncode({
            'preferences': [
              {'platform': 'x', 'mode': 'surprise'},
            ],
          }),
        );

        final preferences = await client.getPreferences();

        expect(preferences.single.mode, CrosspostingMode.disabled);
      });

      test('rejects a malformed preferences collection', () async {
        stubGet(jsonEncode({'preferences': false}));

        await expectLater(
          client.getPreferences(),
          throwsA(isA<CrosspostingApiException>()),
        );
      });

      test('rejects a missing preferences collection', () async {
        stubGet(jsonEncode(<String, dynamic>{}));

        await expectLater(
          client.getPreferences(),
          throwsA(isA<CrosspostingApiException>()),
        );
      });

      for (final malformedField in const {
        'mode': 42,
        'connectionId': false,
      }.entries) {
        test(
          'skips a preference with malformed ${malformedField.key}',
          () async {
            stubGet(
              jsonEncode({
                'preferences': [
                  {
                    'platform': 'x',
                    'mode': 'manual',
                    malformedField.key: malformedField.value,
                  },
                  {'platform': 'instagram', 'mode': 'automatic'},
                ],
              }),
            );

            final preferences = await client.getPreferences();

            expect(preferences, hasLength(1));
            expect(preferences.single.platform, CrosspostingPlatform.instagram);
          },
        );
      }
    });

    group('setMode', () {
      test('PUTs the mode payload', () async {
        when(
          () => httpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(jsonEncode({'ok': true}), 200));

        await client.setMode(CrosspostingPlatform.x, CrosspostingMode.manual);

        final captured = verify(
          () => httpClient.put(
            captureAny(),
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;
        expect((captured[0] as Uri).path, equals('/preferences/x'));
        final headers = captured[1] as Map<String, String>;
        expect(headers['Authorization'], equals('Bearer $accessToken'));
        expect(headers['Content-Type'], equals('application/json'));
        final body = jsonDecode(captured[2] as String) as Map<String, dynamic>;
        expect(body['mode'], equals('manual'));
      });

      for (final mode in const [
        CrosspostingMode.automatic,
        CrosspostingMode.disabled,
      ]) {
        test('PUTs the ${mode.wireName} mode payload', () async {
          when(
            () => httpClient.put(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer(
            (_) async => http.Response(jsonEncode({'ok': true}), 200),
          );

          await client.setMode(CrosspostingPlatform.x, mode);

          final body =
              verify(
                    () => httpClient.put(
                      any(),
                      headers: any(named: 'headers'),
                      body: captureAny(named: 'body'),
                    ),
                  ).captured.single
                  as String;
          expect(
            jsonDecode(body),
            equals(<String, dynamic>{'mode': mode.wireName}),
          );
        });
      }

      test('accepts an empty 204 response', () async {
        when(
          () => httpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('', 204));

        await expectLater(
          client.setMode(CrosspostingPlatform.x, CrosspostingMode.automatic),
          completes,
        );
      });

      test(
        'surfaces not_connected as $CrosspostingApiErrorKind.notConnected',
        () async {
          when(
            () => httpClient.put(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer(
            (_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'not_connected',
                  'message': 'platform is not connected',
                },
              }),
              400,
            ),
          );

          expect(
            () => client.setMode(
              CrosspostingPlatform.instagram,
              CrosspostingMode.automatic,
            ),
            throwsA(
              isA<CrosspostingApiException>().having(
                (e) => e.kind,
                'kind',
                CrosspostingApiErrorKind.notConnected,
              ),
            ),
          );
        },
      );

      test('handles non-JSON error bodies', () async {
        when(
          () => httpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('<html>bad edge</html>', 502));

        expect(
          () => client.setMode(
            CrosspostingPlatform.instagram,
            CrosspostingMode.manual,
          ),
          throwsA(
            isA<CrosspostingApiException>()
                .having((e) => e.statusCode, 'statusCode', 502)
                .having((e) => e.code, 'code', isNull),
          ),
        );
      });

      for (final malformedField in const {
        'code': 42,
        'message': false,
      }.entries) {
        test('wraps a malformed error ${malformedField.key}', () async {
          when(
            () => httpClient.put(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer(
            (_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'not_connected',
                  'message': 'platform is not connected',
                  malformedField.key: malformedField.value,
                },
              }),
              400,
            ),
          );

          await expectLater(
            client.setMode(
              CrosspostingPlatform.instagram,
              CrosspostingMode.automatic,
            ),
            throwsA(
              isA<CrosspostingApiException>().having(
                (error) => error.statusCode,
                'statusCode',
                400,
              ),
            ),
          );
        });
      }
    });

    test('wraps malformed successful JSON as $CrosspostingApiException', () {
      stubGet('not JSON');

      expect(
        () => client.getConnections(),
        throwsA(isA<CrosspostingApiException>()),
      );
    });

    test('times out an HTTP request after 20 seconds', () {
      fakeAsync((async) {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) => Completer<http.Response>().future);
        Object? error;
        client.getConnections().then<void>((_) {}).catchError((Object caught) {
          error = caught;
        });

        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 19))
          ..flushMicrotasks();
        expect(error, isNull);

        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();
        expect(
          error,
          isA<CrosspostingApiException>()
              .having(
                (exception) => exception.message,
                'message',
                contains('timed out'),
              )
              .having(
                (exception) => (exception as dynamic).cause,
                'cause',
                isA<TimeoutException>(),
              ),
        );
      });
    });

    test('wraps an HTTP client transport failure', () async {
      final transportError = http.ClientException(
        'connection reset',
        Uri.parse('https://crossposter.divine.video/preferences/x'),
      );
      when(
        () => httpClient.put(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(transportError);

      await expectLater(
        client.setMode(CrosspostingPlatform.x, CrosspostingMode.manual),
        throwsA(
          isA<CrosspostingApiException>()
              .having(
                (exception) => exception.message,
                'message',
                contains('connection reset'),
              )
              .having(
                (exception) => (exception as dynamic).cause,
                'cause',
                same(transportError),
              ),
        ),
      );
    });

    test('diagnostic text omits raw messages and transport causes', () {
      final exception = CrosspostingApiException(
        'https://secret.example/connection/private-id',
        statusCode: 500,
        code: 'server_error',
        cause: StateError('Bearer private-token'),
      );

      expect(exception.toString(), contains('server_error'));
      expect(exception.toString(), isNot(contains('secret.example')));
      expect(exception.toString(), isNot(contains('private-id')));
      expect(exception.toString(), isNot(contains('private-token')));
    });

    group('crosspost jobs', () {
      // Migrated from the deleted CrossposterApiClient suite (#7802): the job
      // endpoints moved onto this client, so their coverage moves with them.
      const eventId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaa';

      const postedJobJson = {
        'id': 'job-1',
        'platform': 'instagram',
        'status': 'posted',
        'externalPostId': 'ig-post-1',
        'externalPostUrl': 'https://www.instagram.com/reel/abc/',
        'errorCode': null,
        'errorMessage': null,
      };

      void stubPost(String body, {int statusCode = 200}) {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(body, statusCode));
      }

      group('createCrossposts', () {
        test('POSTs the platform list and parses jobs', () async {
          stubPost(
            jsonEncode({
              'jobs': [postedJobJson],
            }),
          );

          final jobs = await client.createCrossposts(
            eventId: eventId,
            platforms: ['instagram'],
          );

          final captured = verify(
            () => httpClient.post(
              captureAny(),
              headers: any(named: 'headers'),
              body: captureAny(named: 'body'),
            ),
          ).captured;
          expect(
            (captured.first as Uri).path,
            equals('/videos/$eventId/crossposts'),
          );
          expect(
            jsonDecode(captured.last as String),
            equals({
              'platforms': ['instagram'],
            }),
          );
          expect(jobs.single.status, equals(CrosspostJobStatus.posted));
          expect(
            jobs.single.externalPostUrl,
            equals('https://www.instagram.com/reel/abc/'),
          );
        });

        test('surfaces the not_eligible error code', () async {
          stubPost(
            jsonEncode({
              'error': {
                'code': 'not_eligible',
                'message': 'video is not eligible',
              },
            }),
            statusCode: 409,
          );

          expect(
            () => client.createCrossposts(
              eventId: eventId,
              platforms: ['instagram'],
            ),
            throwsA(
              isA<CrosspostingApiException>().having(
                (e) => e.code,
                'code',
                equals('not_eligible'),
              ),
            ),
          );
        });

        test('wraps a malformed success body as '
            '$CrosspostingApiException', () {
          stubPost('<html>bad</html>');

          expect(
            () => client.createCrossposts(
              eventId: eventId,
              platforms: ['instagram'],
            ),
            throwsA(
              isA<CrosspostingApiException>()
                  .having((e) => e.statusCode, 'statusCode', equals(200))
                  .having((e) => e.code, 'code', equals('malformed_response'))
                  .having((e) => e.cause, 'cause', isA<FormatException>()),
            ),
          );
        });
      });

      group('getCrossposts', () {
        test('parses pending job statuses from the wire', () async {
          stubGet(
            jsonEncode({
              'jobs': [
                {'id': 'j1', 'platform': 'instagram', 'status': 'queued'},
                {'id': 'j2', 'platform': 'tiktok', 'status': 'uploading'},
                {
                  'id': 'j3',
                  'platform': 'x',
                  'status': 'needs_reauth',
                  'errorCode': 'needs_reauth',
                },
              ],
            }),
          );

          final jobs = await client.getCrossposts(eventId: eventId);

          expect(jobs, hasLength(3));
          expect(jobs[0].status, equals(CrosspostJobStatus.queued));
          expect(jobs[0].status.isPending, isTrue);
          expect(jobs[1].status, equals(CrosspostJobStatus.uploading));
          expect(jobs[2].status, equals(CrosspostJobStatus.needsReauth));
          expect(jobs[2].status.isPending, isFalse);
        });

        test('maps an unknown wire status to '
            '${CrosspostJobStatus.unknown}', () async {
          stubGet(
            jsonEncode({
              'jobs': [
                {
                  'id': 'j1',
                  'platform': 'instagram',
                  'status': 'brand-new-status',
                },
              ],
            }),
          );

          final jobs = await client.getCrossposts(eventId: eventId);

          expect(jobs.single.status, equals(CrosspostJobStatus.unknown));
        });

        test(
          'falls back to a generic message on a non-JSON error body',
          () async {
            stubGet('<html>bad</html>', statusCode: 502);

            expect(
              () => client.getCrossposts(eventId: eventId),
              throwsA(
                isA<CrosspostingApiException>()
                    .having((e) => e.statusCode, 'statusCode', equals(502))
                    .having((e) => e.code, 'code', isNull),
              ),
            );
          },
        );
      });
    });

    test('close closes the owned HTTP client', () {
      client.close();

      verify(() => httpClient.close()).called(1);
    });
  });
}
