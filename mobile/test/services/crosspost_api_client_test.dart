import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/atproto_provisioning_state.dart';
import 'package:openvine/services/crosspost_api_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group(CrosspostApiClient, () {
    late _MockHttpClient httpClient;
    late CrosspostApiClient client;

    // The token the injected account-bound reader returns, and how many times
    // it was consulted. #8825.
    String? boundToken;
    var readerCalls = 0;

    const serverUrl = 'https://login.divine.video';
    const pubkey = 'abc123def456';
    const accessToken = 'session-access-token';

    // Real keycast AtprotoStatusResponse shape.
    const statusJson = {
      'enabled': true,
      'state': 'ready',
      'did': 'did:plc:test123',
      'username': 'testuser',
    };

    setUpAll(() {
      registerFallbackValue(Uri());
    });

    setUp(() {
      httpClient = _MockHttpClient();
      boundToken = accessToken;
      readerCalls = 0;
      client = CrosspostApiClient(
        accessTokenReader: () async {
          readerCalls++;
          return boundToken;
        },
        serverUrl: serverUrl,
        httpClient: httpClient,
      );
    });

    group('getStatus', () {
      test('calls GET /api/user/atproto/status with bearer token', () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(jsonEncode(statusJson), 200));

        await client.getStatus();

        final captured = verify(
          () => httpClient.get(
            captureAny(),
            headers: captureAny(named: 'headers'),
          ),
        ).captured;
        final uri = captured[0] as Uri;
        final headers = captured[1] as Map<String, String>;

        expect(uri.toString(), '$serverUrl/api/user/atproto/status');
        expect(headers['Authorization'], 'Bearer $accessToken');
      });

      test('maps keycast response keys to status fields', () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(jsonEncode(statusJson), 200));

        final status = await client.getStatus();

        expect(status.crosspostEnabled, isTrue);
        expect(status.provisioningState, AtprotoProvisioningState.ready);
        expect(status.did, 'did:plc:test123');
        expect(status.handle, 'testuser.divine.video');
      });

      test(
        'returns disabled defaults when not enabled with null state',
        () async {
          when(
            () => httpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response(
              jsonEncode(const {
                'enabled': false,
                'state': null,
                'did': null,
                'username': null,
              }),
              200,
            ),
          );

          final status = await client.getStatus();

          expect(status.crosspostEnabled, isFalse);
          expect(
            status.provisioningState,
            AtprotoProvisioningState.notLinked,
          );
          expect(status.handle, isNull);
          expect(status.did, isNull);
        },
      );

      test('maps failed state without requiring a DID', () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode(const {
              'enabled': false,
              'state': 'failed',
              'did': null,
              'error': 'PDS quota exhausted',
              'username': 'testuser',
            }),
            200,
          ),
        );

        final status = await client.getStatus();

        expect(status.provisioningState, AtprotoProvisioningState.failed);
        expect(status.provisioningError, 'PDS quota exhausted');
        expect(status.did, isNull);
      });

      test('returns disabled default on 404', () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('', 404));

        final status = await client.getStatus();

        expect(status.crosspostEnabled, isFalse);
        expect(status.provisioningState, AtprotoProvisioningState.notLinked);
      });

      test('throws CrosspostApiException on non-200 (non-404)', () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('error', 500));

        expect(() => client.getStatus(), throwsA(isA<CrosspostApiException>()));
      });

      test('throws CrosspostApiException when no session token', () async {
        boundToken = null;

        expect(
          () => client.getStatus(),
          throwsA(
            isA<CrosspostApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              401,
            ),
          ),
        );
      });
    });

    group('setCrosspost', () {
      test(
        'calls PUT /api/account/{pubkey}/crosspost with enabled body',
        () async {
          when(
            () => httpClient.put(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => http.Response(jsonEncode(statusJson), 200));

          await client.setCrosspost(pubkey: pubkey, enabled: true);

          final captured = verify(
            () => httpClient.put(
              captureAny(),
              headers: any(named: 'headers'),
              body: captureAny(named: 'body'),
            ),
          ).captured;
          final uri = captured[0] as Uri;
          final body =
              jsonDecode(captured[1] as String) as Map<String, dynamic>;

          expect(uri.toString(), '$serverUrl/api/account/$pubkey/crosspost');
          expect(body, {'enabled': true});
        },
      );

      test('maps keycast response keys on toggle', () async {
        when(
          () => httpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode(const {
              'enabled': false,
              'state': 'disabled',
              'did': 'did:plc:test123',
              'username': 'testuser',
            }),
            200,
          ),
        );

        final status = await client.setCrosspost(
          pubkey: pubkey,
          enabled: false,
        );

        expect(status.crosspostEnabled, isFalse);
        expect(status.provisioningState, AtprotoProvisioningState.disabled);
        expect(status.handle, 'testuser.divine.video');
      });

      test('throws CrosspostApiException on non-200', () async {
        when(
          () => httpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('error', 500));

        expect(
          () => client.setCrosspost(pubkey: pubkey, enabled: true),
          throwsA(
            isA<CrosspostApiException>().having(
              (e) => e.kind,
              'kind',
              CrosspostApiErrorKind.generic,
            ),
          ),
        );
      });

      for (final status in const [400]) {
        test('maps $status to usernameNotClaimed', () async {
          when(
            () => httpClient.put(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => http.Response('nope', status));

          await expectLater(
            () => client.setCrosspost(pubkey: pubkey, enabled: true),
            throwsA(
              isA<CrosspostApiException>().having(
                (e) => e.kind,
                'kind',
                CrosspostApiErrorKind.usernameNotClaimed,
              ),
            ),
          );
        });
      }

      test('maps 404 to generic because keycast has no user row', () async {
        when(
          () => httpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('nope', 404));

        await expectLater(
          () => client.setCrosspost(pubkey: pubkey, enabled: true),
          throwsA(
            isA<CrosspostApiException>().having(
              (e) => e.kind,
              'kind',
              CrosspostApiErrorKind.generic,
            ),
          ),
        );
      });

      test('maps 503 to unavailable', () async {
        when(
          () => httpClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('down', 503));

        await expectLater(
          () => client.setCrosspost(pubkey: pubkey, enabled: true),
          throwsA(
            isA<CrosspostApiException>().having(
              (e) => e.kind,
              'kind',
              CrosspostApiErrorKind.unavailable,
            ),
          ),
        );
      });
    });

    group('CrosspostStatus.fromJson', () {
      test('exposes the bare username alongside the derived handle', () {
        final status = CrosspostStatus.fromJson(const {
          'enabled': true,
          'state': 'ready',
          'username': 'testuser',
        });

        expect(status.username, 'testuser');
        expect(status.handle, 'testuser.divine.video');
      });

      test('leaves username and handle null when unclaimed', () {
        final status = CrosspostStatus.fromJson(const {
          'enabled': false,
          'state': null,
        });

        expect(status.username, isNull);
        expect(status.handle, isNull);
      });
    });

    group('account-bound token (#8825)', () {
      test(
        'authenticates with the token from the injected bound reader',
        () async {
          // Pins the account-bound reader as the token source. Goes red if the
          // client reverts to an unbound session read (the header would then
          // carry the session token, not the bound reader's).
          boundToken = 'bound-token-xyz';
          when(
            () => httpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => http.Response(jsonEncode(statusJson), 200));

          await client.getStatus();

          final headers =
              verify(
                    () => httpClient.get(
                      any(),
                      headers: captureAny(named: 'headers'),
                    ),
                  ).captured.single
                  as Map<String, String>;
          expect(readerCalls, 1);
          expect(headers['Authorization'], 'Bearer bound-token-xyz');
        },
      );

      test('exception diagnostics omit the raw message', () {
        const e = CrosspostApiException(
          'connect failed for https://host?token=SECRETVALUE',
          statusCode: 500,
        );

        final text = e.toString();
        expect(text, isNot(contains('SECRETVALUE')));
        expect(text, isNot(contains('https://host')));
        expect(text, contains('500'));
      });
    });
  });
}
