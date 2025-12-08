import 'package:nostr_gateway/src/exceptions/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('GatewayException', () {
    group('constructor', () {
      test('creates exception with message', () {
        const exception = GatewayException('Test error message');

        expect(exception.message, equals('Test error message'));
        expect(exception.statusCode, isNull);
      });

      test('creates exception with message and status code', () {
        const exception = GatewayException(
          'HTTP 404: Not found',
          statusCode: 404,
        );

        expect(exception.message, equals('HTTP 404: Not found'));
        expect(exception.statusCode, equals(404));
      });
    });

    group('toString', () {
      test('returns formatted string with message only', () {
        const exception = GatewayException('Network error');

        expect(
          exception.toString(),
          equals('GatewayException: Network error (status: null)'),
        );
      });

      test('returns formatted string with message and status code', () {
        const exception = GatewayException(
          'HTTP 500: Internal server error',
          statusCode: 500,
        );

        expect(
          exception.toString(),
          equals(
            'GatewayException: HTTP 500: '
            'Internal server error (status: 500)',
          ),
        );
      });
    });

    group('implements Exception', () {
      test('can be caught as Exception', () {
        const exception = GatewayException('Test error');

        expect(exception, isA<Exception>());
      });

      test('can be thrown and caught', () {
        expect(
          () => throw const GatewayException('Test error'),
          throwsA(isA<GatewayException>()),
        );
      });
    });
  });
}
