// ABOUTME: VerifierClient tests — batch + single + error mapping + caps.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

const _hex = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

IdentityClaim _claim({String platform = 'github'}) => IdentityClaim(
  pubkey: _hex,
  platform: platform,
  identity: 'octocat',
  proof: 'abc',
);

void main() {
  group(VerifierClient, () {
    group('verifyBatch', () {
      test('returns parsed results on 200', () async {
        final mock = MockClient((req) async {
          expect(req.method, equals('POST'));
          expect(req.url.toString(), equals('https://verifier.example/verify'));
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['claims'] as List, hasLength(1));
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'platform': 'github',
                  'identity': 'octocat',
                  'verified': true,
                  'checked_at': 1,
                  'cached': true,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        final results = await client.verifyBatch([_claim()]);
        expect(results, hasLength(1));
        expect(results.single.verified, isTrue);
      });

      test('returns empty list when given empty input', () async {
        final mock = MockClient((req) async {
          fail('client should not hit the network for an empty batch');
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        expect(await client.verifyBatch(const []), isEmpty);
      });

      test('throws VerifierApiException on 4xx', () async {
        final mock = MockClient((_) async => http.Response('bad', 400));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifyBatch([_claim()]),
          throwsA(isA<VerifierApiException>()),
        );
      });

      test('throws VerifierApiException on 429', () async {
        final mock = MockClient((_) async => http.Response('rl', 429));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifyBatch([_claim()]),
          throwsA(
            isA<VerifierApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              429,
            ),
          ),
        );
      });

      test('throws VerifierApiException on 5xx', () async {
        final mock = MockClient((_) async => http.Response('boom', 500));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifyBatch([_claim()]),
          throwsA(isA<VerifierApiException>()),
        );
      });

      test('rejects batches over the server cap', () async {
        final mock = MockClient((_) async {
          fail('client should reject before hitting the network');
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        final tooMany = List<IdentityClaim>.generate(11, (_) => _claim());
        await expectLater(
          () => client.verifyBatch(tooMany),
          throwsArgumentError,
        );
      });

      test('strips trailing slash from baseUrl', () async {
        final mock = MockClient((req) async {
          expect(req.url.toString(), equals('https://verifier.example/verify'));
          return http.Response(
            jsonEncode(<String, dynamic>{'results': <Object?>[]}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example/',
          httpClient: mock,
        );
        await client.verifyBatch([_claim()]);
      });
    });

    group('verifySingle', () {
      test('posts a flat object to /verify/single', () async {
        final mock = MockClient((req) async {
          expect(
            req.url.toString(),
            equals('https://verifier.example/verify/single'),
          );
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['platform'], equals('github'));
          expect(body['pubkey'], equals(_hex));
          return http.Response(
            jsonEncode({
              'platform': 'github',
              'identity': 'octocat',
              'verified': true,
              'checked_at': 1,
              'cached': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        final result = await client.verifySingle(_claim());
        expect(result.verified, isTrue);
      });

      test('throws VerifierApiException on non-2xx', () async {
        final mock = MockClient((_) async => http.Response('boom', 503));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifySingle(_claim()),
          throwsA(isA<VerifierApiException>()),
        );
      });

      test('maps ClientException to VerifierNetworkException', () async {
        final mock = MockClient((_) async {
          throw http.ClientException('boom');
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifySingle(_claim()),
          throwsA(isA<VerifierNetworkException>()),
        );
      });
    });

    group('fetchPlatforms', () {
      test('parses the platform map into entries', () async {
        final mock = MockClient((req) async {
          expect(req.method, equals('GET'));
          expect(
            req.url.toString(),
            equals('https://verifier.example/platforms'),
          );
          return http.Response(
            jsonEncode({
              'platforms': {
                'github': {'label': 'GitHub', 'supported': true},
                'discord': {'label': 'Discord', 'supported': false},
              },
            }),
            200,
          );
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        final platforms = await client.fetchPlatforms();

        expect(platforms, hasLength(2));
        final github = platforms.firstWhere((p) => p.key == 'github');
        expect(github.label, equals('GitHub'));
        expect(github.supported, isTrue);
        expect(github.supportsOAuth, isFalse);
        expect(
          platforms.firstWhere((p) => p.key == 'discord').supported,
          isFalse,
        );
      });

      test('returns an empty list when the response carries no map', () async {
        final mock = MockClient(
          (_) async => http.Response(jsonEncode(<String, dynamic>{}), 200),
        );
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        expect(await client.fetchPlatforms(), isEmpty);
      });

      test('maps a non-2xx response to VerifierApiException', () async {
        final mock = MockClient((_) async => http.Response('nope', 500));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        await expectLater(
          client.fetchPlatforms,
          throwsA(isA<VerifierApiException>()),
        );
      });
    });

    group('startSignIn', () {
      test(
        'posts the start with the start check and returns the provider page',
        () async {
          late http.Request sent;
          final mock = MockClient((req) async {
            sent = req;
            return http.Response(
              jsonEncode({'url': 'https://bsky.social/oauth/authorize?x=1'}),
              200,
            );
          });
          final client = VerifierClient(
            baseUrl: 'https://verifier.example',
            httpClient: mock,
          );

          final url = await client.startSignIn(
            platform: 'bluesky',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback?signin=abc',
            startCheck: 'G2CN_J8Es1JmsWz0QXd2Kc-4p-lCo8GCsR-tVw6vre4',
            handle: ' alice.bsky.social ',
          );

          expect(
            url,
            equals(Uri.parse('https://bsky.social/oauth/authorize?x=1')),
          );
          expect(sent.method, equals('POST'));
          expect(
            sent.url.toString(),
            equals('https://verifier.example/auth/bluesky/start'),
          );
          expect(sent.headers['content-type'], startsWith('application/json'));
          expect(sent.url.query, isEmpty);
          expect(
            jsonDecode(sent.body),
            equals({
              'pubkey': _hex,
              'return_url': 'https://divine.video/app/callback?signin=abc',
              'start_check': 'G2CN_J8Es1JmsWz0QXd2Kc-4p-lCo8GCsR-tVw6vre4',
              'handle': 'alice.bsky.social',
            }),
          );
        },
      );

      test('returns null when sign-in is not set up (503)', () async {
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient(
            (_) async => http.Response('{"error":"not configured"}', 503),
          ),
        );
        expect(
          await client.startSignIn(
            platform: 'twitter',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
            startCheck: 'x' * 43,
          ),
          isNull,
        );
      });

      test('throws other refusals as API errors', () async {
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient(
            (_) async => http.Response('{"error":"bad return_url"}', 400),
          ),
        );
        await expectLater(
          client.startSignIn(
            platform: 'twitter',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
            startCheck: 'x' * 43,
          ),
          throwsA(
            isA<VerifierApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              400,
            ),
          ),
        );
      });

      test('refuses a provider page that is not https', () async {
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient(
            (_) async =>
                http.Response(jsonEncode({'url': 'javascript:alert(1)'}), 200),
          ),
        );
        await expectLater(
          client.startSignIn(
            platform: 'twitter',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
            startCheck: 'x' * 43,
          ),
          throwsA(isA<VerifierApiException>()),
        );
      });

      for (final (name, answer) in [
        ('an http page', {'url': 'http://x.com/i/oauth2/authorize'}),
        ('an https address with no host', {'url': 'https:///authorize'}),
        ('no url', <String, String>{}),
      ]) {
        test('refuses an answer with $name', () async {
          final client = VerifierClient(
            baseUrl: 'https://verifier.example',
            httpClient: MockClient(
              (_) async => http.Response(jsonEncode(answer), 200),
            ),
          );
          await expectLater(
            client.startSignIn(
              platform: 'twitter',
              pubkey: _hex,
              returnUrl: 'https://divine.video/app/callback',
              startCheck: 'x' * 43,
            ),
            throwsA(
              isA<VerifierApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                200,
              ),
            ),
          );
        });
      }

      test('sends no handle for a platform other than bluesky', () async {
        late http.Request sent;
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient((req) async {
            sent = req;
            return http.Response(
              jsonEncode({'url': 'https://x.com/i/oauth2/authorize'}),
              200,
            );
          }),
        );

        await client.startSignIn(
          platform: 'twitter',
          pubkey: _hex,
          returnUrl: 'https://divine.video/app/callback?signin=abc',
          startCheck: 'G2CN_J8Es1JmsWz0QXd2Kc-4p-lCo8GCsR-tVw6vre4',
        );

        expect(
          jsonDecode(sent.body),
          equals({
            'pubkey': _hex,
            'return_url': 'https://divine.video/app/callback?signin=abc',
            'start_check': 'G2CN_J8Es1JmsWz0QXd2Kc-4p-lCo8GCsR-tVw6vre4',
          }),
        );
      });

      test(
        'throws a network error rather than opening anything when the '
        'verifier cannot be reached',
        () async {
          final client = VerifierClient(
            baseUrl: 'https://verifier.example',
            httpClient: MockClient(
              (_) async => throw http.ClientException('down'),
            ),
          );
          await expectLater(
            client.startSignIn(
              platform: 'twitter',
              pubkey: _hex,
              returnUrl: 'https://divine.video/app/callback',
              startCheck: 'x' * 43,
            ),
            throwsA(isA<VerifierNetworkException>()),
          );
        },
      );

      test('needs a handle for bluesky', () async {
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient((_) async => fail('no request')),
        );
        await expectLater(
          client.startSignIn(
            platform: 'bluesky',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
            startCheck: 'x' * 43,
          ),
          throwsArgumentError,
        );
      });

      test('refuses a platform without sign-in', () async {
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient((_) async => fail('no request')),
        );
        await expectLater(
          client.startSignIn(
            platform: 'github',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
            startCheck: 'x' * 43,
          ),
          throwsArgumentError,
        );
      });
    });

    group('confirmSignIn', () {
      final event = <String, dynamic>{'id': 'e' * 64, 'kind': 10011};

      test('posts the code, the start secret and the signed event', () async {
        late http.Request sent;
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient((req) async {
            sent = req;
            return http.Response(
              jsonEncode({
                'linked': true,
                'platform': 'twitter',
                'identity': 'jack',
              }),
              200,
            );
          }),
        );
        final confirmed = await client.confirmSignIn(
          code: 'C' * 43,
          startSecret: 'S' * 43,
          event: event,
        );
        expect(
          confirmed,
          equals(
            const SignInConfirmation(platform: 'twitter', identity: 'jack'),
          ),
        );
        expect(sent.method, equals('POST'));
        expect(
          sent.url.toString(),
          equals('https://verifier.example/auth/confirm'),
        );
        expect(sent.headers['content-type'], startsWith('application/json'));
        expect(
          jsonDecode(sent.body),
          equals({'code': 'C' * 43, 'start_secret': 'S' * 43, 'event': event}),
        );
      });

      test('throws the refusal the verifier names', () async {
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({'error': 'x', 'code': 'signin_used'}),
              409,
            ),
          ),
        );
        await expectLater(
          client.confirmSignIn(
            code: 'C' * 43,
            startSecret: 'S' * 43,
            event: event,
          ),
          throwsA(
            isA<SignInConfirmException>()
                .having((e) => e.refusal, 'refusal', SignInRefusal.used)
                .having((e) => e.statusCode, 'statusCode', 409),
          ),
        );
      });

      test('reads a refusal without a JSON body as other', () async {
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient((_) async => http.Response('nope', 429)),
        );
        await expectLater(
          client.confirmSignIn(
            code: 'C' * 43,
            startSecret: 'S' * 43,
            event: event,
          ),
          throwsA(
            isA<SignInConfirmException>()
                .having((e) => e.refusal, 'refusal', SignInRefusal.other)
                .having((e) => e.statusCode, 'statusCode', 429),
          ),
        );
      });

      // 500 is what an unhandled Worker error returns, so the boundary itself
      // has to read as a server error: the app resends the same event then.
      for (final status in [500, 502]) {
        test(
          'treats a $status as an API error, not a refusal',
          () async {
            final client = VerifierClient(
              baseUrl: 'https://verifier.example',
              httpClient: MockClient(
                (_) async => http.Response('oops', status),
              ),
            );
            await expectLater(
              client.confirmSignIn(
                code: 'C' * 43,
                startSecret: 'S' * 43,
                event: event,
              ),
              throwsA(
                isA<VerifierApiException>().having(
                  (e) => e.statusCode,
                  'statusCode',
                  status,
                ),
              ),
            );
          },
        );
      }

      test('does not count a 200 that does not say linked', () async {
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'linked': false,
                'platform': 'twitter',
                'identity': 'jack',
              }),
              200,
            ),
          ),
        );
        await expectLater(
          client.confirmSignIn(
            code: 'C' * 43,
            startSecret: 'S' * 43,
            event: event,
          ),
          throwsA(
            isA<SignInConfirmException>().having(
              (e) => e.refusal,
              'refusal',
              SignInRefusal.other,
            ),
          ),
        );
      });

      test(
        'treats a success without the linked account as an API error',
        () async {
          final client = VerifierClient(
            baseUrl: 'https://verifier.example',
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode({'linked': true, 'platform': 'twitter'}),
                200,
              ),
            ),
          );
          await expectLater(
            client.confirmSignIn(
              code: 'C' * 43,
              startSecret: 'S' * 43,
              event: event,
            ),
            throwsA(isA<VerifierApiException>()),
          );
        },
      );

      test(
        'throws a network error when the verifier cannot be reached',
        () async {
          final client = VerifierClient(
            baseUrl: 'https://verifier.example',
            httpClient: MockClient(
              (_) async => throw http.ClientException('down'),
            ),
          );
          await expectLater(
            client.confirmSignIn(
              code: 'C' * 43,
              startSecret: 'S' * 43,
              event: event,
            ),
            throwsA(isA<VerifierNetworkException>()),
          );
        },
      );

      test('never puts the code or secret in an exception message', () async {
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: MockClient(
            (_) async =>
                http.Response(jsonEncode({'code': 'signin_not_yours'}), 401),
          ),
        );
        try {
          await client.confirmSignIn(
            code: 'C' * 43,
            startSecret: 'S' * 43,
            event: event,
          );
          fail('expected a refusal');
        } on SignInConfirmException catch (e) {
          expect(e.refusal, SignInRefusal.notYours);
          expect(e.toString(), isNot(contains('C' * 43)));
          expect(e.toString(), isNot(contains('S' * 43)));
        }
      });
    });

    group('revokeOAuth', () {
      test('posts the claim and the NIP-98 event', () async {
        var called = false;
        final mock = MockClient((req) async {
          called = true;
          expect(req.method, equals('POST'));
          expect(
            req.url.toString(),
            equals('https://verifier.example/auth/oauth/revoke'),
          );
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['platform'], equals('twitter'));
          expect(body['identity'], equals('jack'));
          expect(body['pubkey'], equals(_hex));
          expect(
            (body['event']! as Map<String, dynamic>)['kind'],
            equals(27235),
          );
          return http.Response(jsonEncode({'revoked': true}), 200);
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        await client.revokeOAuth(
          platform: 'twitter',
          identity: 'jack',
          pubkey: _hex,
          nip98Event: const {'kind': 27235},
        );

        expect(called, isTrue);
      });

      test('surfaces a rejected revoke as VerifierApiException', () async {
        final mock = MockClient(
          (_) async => http.Response('{"error":"nope"}', 401),
        );
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        await expectLater(
          () => client.revokeOAuth(
            platform: 'twitter',
            identity: 'jack',
            pubkey: _hex,
            nip98Event: const {'kind': 27235},
          ),
          throwsA(isA<VerifierApiException>()),
        );
      });
    });

    group('oauthRevokeUrl', () {
      const revokePath = '/auth/oauth/revoke';
      const canonical = 'https://verifier.example$revokePath';

      // NIP-98 binds the signed `u` tag to the absolute request URL, and the
      // verifier compares the two with a strict `!==` against
      // `new URL(req.url).toString()`. The request URI goes through
      // `Uri.parse`, which lowercases the scheme and host, drops a default
      // port, resolves dot segments and decodes unreserved escapes. So the
      // signed string has to come from that same builder: composing it from
      // the raw base instead makes the two disagree for every base below, and
      // the revoke 401s while all the unauthenticated calls keep working.
      const bases = <(String, String)>[
        ('https://verifier.example', canonical),
        ('https://verifier.example/', canonical),
        ('https://VERIFIER.example', canonical),
        ('HTTPS://verifier.example', canonical),
        ('https://verifier.example:443', canonical),
        ('https://verifier.example/.', canonical),
        (
          'https://verifier.example/%7Ea',
          'https://verifier.example/~a$revokePath',
        ),
        (
          'https://verifier.example:8443',
          'https://verifier.example:8443$revokePath',
        ),
      ];

      for (final (base, expected) in bases) {
        test('signs the URL it posts to, for a base of $base', () async {
          late Uri posted;
          final mock = MockClient((req) async {
            posted = req.url;
            return http.Response(jsonEncode({'revoked': true}), 200);
          });
          final client = VerifierClient(baseUrl: base, httpClient: mock);

          await client.revokeOAuth(
            platform: 'twitter',
            identity: 'jack',
            pubkey: _hex,
            nip98Event: const {'kind': 27235},
          );

          expect(client.oauthRevokeUrl, equals(posted.toString()));
          // Pins the value as well as the coupling: both operands above come
          // from the object under test, so on their own they would still
          // match if the getter and the request both went wrong together.
          expect(client.oauthRevokeUrl, equals(expected));
        });
      }
    });
  });
}
