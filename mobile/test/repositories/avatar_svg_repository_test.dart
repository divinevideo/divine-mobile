import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/repositories/avatar_svg_repository.dart';

void main() {
  const url = 'https://divine.video/avatar.svg';
  // flutter_svg needs a viewport on the root element. Fixtures that assert
  // "flutter_svg renders this" have to carry one, or they fail for an
  // unrelated reason and the comparison stops meaning anything.
  const svgOpenTag =
      '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">';
  final validSvgBytes = Uint8List.fromList(
    utf8.encode(
      '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1" />',
    ),
  );

  HttpAvatarSvgRepository repositoryFor(http.Response response) {
    return HttpAvatarSvgRepository(
      client: MockClient((_) async => response),
      requestTimeout: const Duration(milliseconds: 20),
    );
  }

  group(HttpAvatarSvgRepository, () {
    group('load', () {
      group('payload validation', () {
        test('accepts well-formed SVG payloads', () async {
          final repository = repositoryFor(
            http.Response.bytes(
              validSvgBytes,
              200,
              headers: {'content-type': 'image/svg+xml; charset=utf-8'},
            ),
          );

          await expectLater(repository.load(url), completion(validSvgBytes));
        });

        test(
          'accepts SVG payloads by sniffing when content type is missing',
          () {
            final repository = repositoryFor(
              http.Response.bytes(validSvgBytes, 200),
            );

            expect(repository.load(url), completion(validSvgBytes));
          },
        );

        test('rejects HTML returned from a .svg URL', () {
          final repository = repositoryFor(
            http.Response(
              '<html><body>not an svg</body></html>',
              200,
              headers: {'content-type': 'text/html'},
            ),
          );

          expect(repository.load(url), completion(isNull));
        });

        test('rejects binary payloads without throwing while sniffing', () {
          final repository = repositoryFor(
            http.Response.bytes(
              Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
              200,
              headers: {'content-type': 'text/html'},
            ),
          );

          expect(repository.load(url), completion(isNull));
        });

        test('rejects malformed SVG before flutter_svg sees it', () {
          final repository = repositoryFor(
            http.Response(
              '<svg xmlns="http://www.w3.org/2000/svg"><path',
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          expect(repository.load(url), completion(isNull));
        });

        test('rejects markup that only breaks after the root element', () {
          // Crashlytics b97ccc46 shape: a well-formed <svg> root on line 1 and an
          // unterminated tag deep into line 2. A validator that stops once it has
          // seen the root element accepts this and hands the parse failure to
          // flutter_svg, where it escapes as an unhandled zone error (#7296).
          final repository = repositoryFor(
            http.Response(
              '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">\n'
              '<path d="M0 0 L1 1" ${'a' * 140} <circle r="1"/>\n'
              '</svg>',
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          expect(repository.load(url), completion(isNull));
        });

        test('rejects an end element sitting after the root element', () {
          // `SvgParser.endElement` reads `_parentDrawables.last` with no empty
          // check, so an end element outside the root throws `StateError: No
          // element` and escapes as the same orphaned future as a tokenizer
          // failure. Tokenizing alone does not catch this — only the document
          // structure does.
          final repository = repositoryFor(
            http.Response(
              '$svgOpenTag<rect width="10" height="10"/></svg></foo>',
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          expect(repository.load(url), completion(isNull));
        });

        test('rejects an end element sitting before the root element', () {
          final repository = repositoryFor(
            http.Response(
              '</foo>$svgOpenTag<rect width="10" height="10"/></svg>',
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          expect(repository.load(url), completion(isNull));
        });

        test(
          'rejects an end element after the root with a shape left open',
          () {
            // A `rect` is a shape, not a group, so flutter_svg never pushes it onto
            // `_parentDrawables`. Any guard that mirrors that stack instead of the
            // document desynchronises here and lets the payload through.
            final repository = repositoryFor(
              http.Response(
                '$svgOpenTag<rect width="4" height="4"></svg></rect>',
                200,
                headers: {'content-type': 'image/svg+xml'},
              ),
            );

            expect(repository.load(url), completion(isNull));
          },
        );

        test('accepts a nested svg element', () async {
          // `SvgParser` supports a nested `<svg>` and pushes its own group for it,
          // so the inner end tag must not be read as the root closing.
          final nested = Uint8List.fromList(
            utf8.encode(
              '$svgOpenTag$svgOpenTag<rect width="4" height="4"/></svg></svg>',
            ),
          );
          final repository = repositoryFor(
            http.Response.bytes(
              nested,
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          await expectLater(repository.load(url), completion(nested));
        });

        test('accepts an unbalanced end element inside the root', () async {
          // Only trips a debug `assert` in `vector_graphics_compiler`, and
          // flutter_svg never pops on a name mismatch, so the drawable stack cannot
          // underflow here. Rejecting it would blank an avatar that renders.
          final unbalanced = Uint8List.fromList(
            utf8.encode('$svgOpenTag<g></g></g></svg>'),
          );
          final repository = repositoryFor(
            http.Response.bytes(
              unbalanced,
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          await expectLater(repository.load(url), completion(unbalanced));
        });

        test('rejects mismatched nesting whose root end tag comes first', () {
          // Deliberately stricter than the consumer: `endElement` pops only on a
          // name match, so `</svg>` with a `<g>` still open never empties
          // `_parentDrawables` and this renders. Accepting it back would take
          // mirroring the compiler's push set, which is what the document rule
          // exists to avoid.
          final repository = repositoryFor(
            http.Response(
              '$svgOpenTag<g><rect/></svg></g>',
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          expect(repository.load(url), completion(isNull));
        });

        test('rejects well-formed XML whose root element is not svg', () {
          final repository = repositoryFor(
            http.Response(
              '<html><body>not an svg</body></html>',
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          expect(repository.load(url), completion(isNull));
        });

        test('accepts SVG payloads carrying non-UTF-8 bytes', () async {
          // flutter_svg decodes with `allowMalformed: true`, so a stray Latin-1 byte
          // renders fine. Rejecting it here would blank an avatar that works.
          final latin1InText = Uint8List.fromList([
            ...utf8.encode('$svgOpenTag<text>caf'),
            0xE9,
            ...utf8.encode('</text></svg>'),
          ]);
          final repository = repositoryFor(
            http.Response.bytes(
              latin1InText,
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          await expectLater(repository.load(url), completion(latin1InText));
        });

        test('accepts mismatched nesting that flutter_svg tolerates', () async {
          // `SvgParser` calls `parseEvents` without nesting validation, so sloppy
          // generator output still renders. Only tokenizer failures may be rejected.
          final mismatched = Uint8List.fromList(
            utf8.encode('$svgOpenTag<g><rect/></svg>'),
          );
          final repository = repositoryFor(
            http.Response.bytes(
              mismatched,
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          await expectLater(repository.load(url), completion(mismatched));
        });
      });

      group('response failures', () {
        test('rejects non-200 responses', () {
          final repository = repositoryFor(
            http.Response(
              '<svg xmlns="http://www.w3.org/2000/svg" />',
              503,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          expect(repository.load(url), completion(isNull));
        });

        test(
          'does not leave non-200 response stream errors unhandled',
          () async {
            final controller = StreamController<List<int>>();
            final repository = HttpAvatarSvgRepository(
              client: _StreamedAvatarClient(
                (_) async => http.StreamedResponse(
                  controller.stream,
                  503,
                  headers: {'content-type': 'image/svg+xml'},
                ),
              ),
              requestTimeout: const Duration(milliseconds: 20),
            );

            final result = await repository.load(url);
            controller.addError(
              Exception('socket reset while discarding body'),
            );

            expect(result, isNull);
            await controller.close();
          },
        );

        test('times out incomplete response bodies', () async {
          var bodyCanceled = false;
          final controller = StreamController<List<int>>(
            onCancel: () {
              bodyCanceled = true;
            },
          );
          final repository = HttpAvatarSvgRepository(
            client: _StreamedAvatarClient(
              (_) async => http.StreamedResponse(
                controller.stream,
                200,
                headers: {'content-type': 'image/svg+xml'},
              ),
            ),
            requestTimeout: const Duration(milliseconds: 20),
          );

          await expectLater(repository.load(url), completion(isNull));
          expect(bodyCanceled, isTrue);
        });

        test('rejects oversized responses', () {
          final oversized = Uint8List.fromList(
            utf8.encode(
              '<svg xmlns="http://www.w3.org/2000/svg"><text>${'x' * AvatarSvgRepositoryConfig.maxBytes}</text></svg>',
            ),
          );
          final repository = repositoryFor(
            http.Response.bytes(
              oversized,
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          expect(repository.load(url), completion(isNull));
        });
      });

      group('caching', () {
        test('caches negative results', () async {
          var requests = 0;
          final repository = HttpAvatarSvgRepository(
            client: MockClient((_) async {
              requests++;
              return http.Response('<html>gone</html>', 200);
            }),
            requestTimeout: const Duration(milliseconds: 20),
          );

          await repository.load(url);
          await repository.load(url);

          expect(requests, 1);
        });

        test(
          'expires cached positive results after the positive TTL',
          () async {
            var now = DateTime(2026);
            var requests = 0;
            final repository = HttpAvatarSvgRepository(
              client: MockClient((_) async {
                requests++;
                return http.Response.bytes(
                  validSvgBytes,
                  200,
                  headers: {'content-type': 'image/svg+xml'},
                );
              }),
              clock: () => now,
              requestTimeout: const Duration(milliseconds: 20),
            );

            await repository.load(url);
            now = now.add(const Duration(minutes: 30));
            await repository.load(url);
            now = now.add(const Duration(hours: 1, minutes: 1));
            await repository.load(url);

            expect(requests, 2);
          },
        );

        test(
          'expires cached negative results after the negative TTL',
          () async {
            var now = DateTime(2026);
            var requests = 0;
            final repository = HttpAvatarSvgRepository(
              client: MockClient((_) async {
                requests++;
                return http.Response('<html>gone</html>', 200);
              }),
              clock: () => now,
              requestTimeout: const Duration(milliseconds: 20),
            );

            await repository.load(url);
            now = now.add(const Duration(minutes: 5));
            await repository.load(url);
            now = now.add(const Duration(minutes: 11));
            await repository.load(url);

            expect(requests, 2);
          },
        );

        test('evicts least recently used cache entries', () async {
          var requests = 0;
          final repository = HttpAvatarSvgRepository(
            client: MockClient((_) async {
              requests++;
              return http.Response.bytes(
                validSvgBytes,
                200,
                headers: {'content-type': 'image/svg+xml'},
              );
            }),
            requestTimeout: const Duration(milliseconds: 20),
          );

          for (
            var index = 0;
            index <= AvatarSvgRepositoryConfig.maxCacheEntries;
            index++
          ) {
            await repository.load('https://divine.video/avatar-$index.svg');
          }
          await repository.load('https://divine.video/avatar-0.svg');

          expect(requests, AvatarSvgRepositoryConfig.maxCacheEntries + 2);
        });

        test('deduplicates concurrent requests for the same URL', () async {
          var requests = 0;
          final responseCompleter = Completer<http.Response>();
          final repository = HttpAvatarSvgRepository(
            client: MockClient((_) {
              requests++;
              return responseCompleter.future;
            }),
            requestTimeout: const Duration(milliseconds: 20),
          );

          final first = repository.load(url);
          final second = repository.load(url);
          responseCompleter.complete(
            http.Response.bytes(
              validSvgBytes,
              200,
              headers: {'content-type': 'image/svg+xml'},
            ),
          );

          await expectLater(
            Future.wait([first, second]),
            completion([validSvgBytes, validSvgBytes]),
          );
          expect(requests, 1);
        });
      });
    });
  });
}

class _StreamedAvatarClient extends http.BaseClient {
  _StreamedAvatarClient(this._send);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _send;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);
}
