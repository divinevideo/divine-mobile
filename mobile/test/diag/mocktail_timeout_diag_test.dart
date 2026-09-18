// ABOUTME: Pinned regression tests for the mocktail + Future.timeout gotcha.
// ABOUTME: When mocktail's thenAnswer((_) async => value) infers a non-nullable
// ABOUTME: Future<T>, .timeout(onTimeout: () => fallback) throws a runtime TypeError
// ABOUTME: because the closure return type is inferred too narrowly. Production code
// ABOUTME: in signed_event_relay_publisher.dart sidesteps this with try/catch on
// ABOUTME: TimeoutException; this file locks the gotcha so future contributors
// ABOUTME: don't reach for onTimeout when stubbing publishEvent in tests.
// ABOUTME: Note: publishEvent now returns Future<PublishResult> (a non-nullable
// ABOUTME: sealed class), so the original Event? nullable flavour is gone, but
// ABOUTME: the try/catch shape remains the preferred pattern.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group('mocktail + Future.timeout interaction', () {
    late _MockNostrClient mock;
    late Event event;

    setUp(() {
      mock = _MockNostrClient();
      event = Event(
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
        1,
        const [],
        'diag',
      );
    });

    test(
      'plain mocktail thenAnswer + await returns the stubbed PublishSuccess',
      () async {
        final stubResult = PublishSuccess(event: event);
        when(
          () => mock.publishEvent(any()),
        ).thenAnswer((_) async => stubResult);

        final result = await mock.publishEvent(event);

        expect(result, equals(stubResult));
      },
    );

    test(
      'GOTCHA: mocktail thenAnswer((_) async => value) + .timeout(onTimeout: '
      '() => fallback) throws TypeError at runtime because the stubbed Future '
      'has lost nullability of the closure return type',
      () async {
        final stubResult = PublishSuccess(event: event);
        when(
          () => mock.publishEvent(any()),
        ).thenAnswer((_) async => stubResult);

        await expectLater(
          () async => mock
              .publishEvent(event)
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => const PublishFailed(),
              ),
          // With a non-nullable sealed class the TypeError manifests differently
          // than with Event? — the closure infers its return as PublishFailed,
          // which is not assignable to the inferred non-nullable PublishSuccess
          // type that mocktail bakes in. The safe workaround is try/catch.
          throwsA(
            isA<TypeError>().having(
              (error) => error.toString(),
              'message',
              allOf(
                contains('PublishFailed'),
                contains('PublishSuccess'),
                contains('subtype of'),
              ),
            ),
          ),
          reason:
              'If this assertion starts failing because no error was thrown, '
              'mocktail or Dart fixed the inference and the try/catch '
              'workaround in signed_event_relay_publisher.dart can be dropped.',
        );
      },
    );

    test('WORKAROUND A: try/catch on TimeoutException avoids the closure-cast '
        'trap (this is the production-code shape)', () async {
      final stubResult = PublishSuccess(event: event);
      when(() => mock.publishEvent(any())).thenAnswer((_) async => stubResult);

      PublishResult? result;
      try {
        result = await mock
            .publishEvent(event)
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        result = const PublishFailed();
      }

      expect(result, equals(stubResult));
    });

    test(
      'WORKAROUND B: stubbing with Future<PublishResult>.value(result) '
      'preserves the declared return type so onTimeout closure also works',
      () async {
        final stubResult = PublishSuccess(event: event);
        when(
          () => mock.publishEvent(any()),
        ).thenAnswer((_) => Future<PublishResult>.value(stubResult));

        final result = await mock
            .publishEvent(event)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => const PublishFailed(),
            );

        expect(result, equals(stubResult));
      },
    );

    test(
      'sanity: plain Future.value with the right type + .timeout works',
      () async {
        // Confirms the gotcha is mocktail-specific, not a Dart stdlib issue.
        final stubResult = PublishSuccess(event: event);
        final source = Future<PublishResult>.value(stubResult);
        final result = await source.timeout(
          const Duration(seconds: 30),
          onTimeout: () => const PublishFailed(),
        );
        expect(result, equals(stubResult));
      },
    );
  });
}
