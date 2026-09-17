// ABOUTME: Tests the GoRouter extra codec that keeps non-JSON route arguments
// ABOUTME: alive when the router re-reads its own route state (#9292).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_extra_codec.dart';

class _FeedArgs {
  _FeedArgs(this.label);

  final String label;
}

void main() {
  group(RouteExtraCodec, () {
    late RouteExtraCodec codec;

    setUp(() {
      codec = RouteExtraCodec();
    });

    group('encode', () {
      test('produces JSON-encodable output for a non-JSON object', () {
        final encoded = codec.encode(_FeedArgs('feed'));

        expect(() => jsonEncode(encoded), returnsNormally);
      });

      test('produces JSON-encodable output for a map holding objects', () {
        final encoded = codec.encode({'sound': _FeedArgs('sound')});

        expect(() => jsonEncode(encoded), returnsNormally);
      });

      test('gives the same object the same encoding every time', () {
        final args = _FeedArgs('feed');

        expect(codec.encode(args), equals(codec.encode(args)));
      });

      test('gives different objects different encodings', () {
        expect(
          codec.encode(_FeedArgs('a')),
          isNot(equals(codec.encode(_FeedArgs('b')))),
        );
      });
    });

    group('decode', () {
      test('returns the same object that was encoded', () {
        final args = _FeedArgs('feed');

        expect(codec.decode(codec.encode(args)), same(args));
      });

      test('keeps JSON-native values when a fresh codec decodes them', () {
        const values = <Object?>[
          null,
          true,
          42,
          1.5,
          'text',
          ['a', 1],
          {
            'participants': ['p1'],
            'nested': {'count': 2},
          },
        ];

        // A fresh codec has an empty registry, as after a web page reload, so
        // only values stored by value can come back.
        final reloaded = RouteExtraCodec();
        for (final value in values) {
          final roundTripped = reloaded.decode(
            jsonDecode(jsonEncode(codec.encode(value))),
          );
          expect(roundTripped, equals(value), reason: 'value: $value');
        }
      });

      test('returns null for an object registered by another codec', () {
        // Route state can outlive the codec that wrote it: browser history
        // after a page reload, or after an account switch builds a new router.
        final live = _FeedArgs('live');
        codec.encode(live);
        final encoded = RouteExtraCodec().encode(_FeedArgs('stale'));

        expect(codec.decode(encoded), isNull);
      });

      test('returns null for malformed state instead of throwing', () {
        const malformed = <Object?>[
          'garbage',
          42,
          <String, Object?>{},
          {'kind': 'ref'},
          {'kind': 'ref', 'id': 7},
          {'kind': 'unknown', 'value': 'x'},
        ];

        for (final input in malformed) {
          expect(codec.decode(input), isNull, reason: 'input: $input');
        }
      });

      test('returns null for a record, which cannot be held weakly', () {
        const record = (1, 'two');

        expect(codec.decode(codec.encode(record)), isNull);
      });

      test('returns null for a non-finite number instead of throwing', () {
        for (final value in [double.nan, double.infinity]) {
          expect(codec.decode(codec.encode(value)), isNull, reason: '$value');
        }
      });
    });

    group('with $GoRouter', () {
      testWidgets(
        'keeps a pushed route non-JSON extra when the router refreshes',
        (tester) async {
          final seenExtras = <Object?>[];
          final router = GoRouter(
            initialLocation: '/',
            extraCodec: codec,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const SizedBox.shrink(),
              ),
              GoRoute(
                path: '/feed',
                builder: (context, state) {
                  seenExtras.add(state.extra);
                  return const SizedBox.shrink();
                },
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          );

          final args = _FeedArgs('feed');
          unawaited(router.push<void>('/feed', extra: args));
          await tester.pumpAndSettle();
          expect(seenExtras.last, same(args));
          final buildsBeforeRefresh = seenExtras.length;

          router.refresh();
          await tester.pumpAndSettle();

          expect(seenExtras.length, greaterThan(buildsBeforeRefresh));
          expect(seenExtras.last, same(args));
        },
      );
    });
  });
}
