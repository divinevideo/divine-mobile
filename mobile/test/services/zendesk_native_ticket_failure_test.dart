import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/zendesk_native_ticket_failure.dart';

void main() {
  ZendeskNativeTicketFailure failure({
    String code = 'CREATE_FAILED',
    String? message,
    Map<String, Object>? details,
  }) => ZendeskNativeTicketFailure(
    PlatformException(code: code, message: message, details: details),
  );

  group(ZendeskNativeTicketFailure, () {
    group('needsAnotherIdentity', () {
      test('is true when the bridge found no identity', () {
        expect(failure(code: 'NO_IDENTITY').needsAnotherIdentity, isTrue);
      });

      test('is true when the bridge flags an authentication failure', () {
        expect(
          failure(details: {'authFailed': true}).needsAnotherIdentity,
          isTrue,
        );
      });

      test('ignores a message that only says unauthorized', () {
        // iOS used to be read this way; its bridge now flags `authFailed`.
        expect(
          failure(
            message: 'unauthorized',
            details: {'authFailed': false},
          ).needsAnotherIdentity,
          isFalse,
        );
      });
    });

    group('isRefusal', () {
      test('is true for the HTTP status of a ticket Zendesk refused', () {
        final refused = failure(
          details: {'status': 422, 'networkError': false, 'authFailed': false},
        );

        expect(refused.isRefusal, isTrue);
      });

      test('is false for a token exchange iOS failed with a 4xx', () {
        final exchange = failure(
          details: {
            'status': 403,
            'networkError': false,
            'authFailed': true,
            'errorDomain': 'com.zendesk.sdk.core',
            'errorCode': 1000,
          },
        );

        expect(exchange.isRefusal, isFalse);
      });

      test('is false without details', () {
        expect(failure().isRefusal, isFalse);
      });
    });

    group('reportedMessage', () {
      test('names the iOS error, the identity held and the one expected', () {
        final mismatch = failure(
          message:
              'The configured authentication type and the Identity type do '
              "not match. Can't authenticate.",
          details: {
            'status': -1,
            'networkError': false,
            'authFailed': true,
            'errorDomain': 'com.zendesk.core.identity',
            'errorCode': 303,
            'identity': 'anonymous',
            'expectedAuth': 'jwt',
          },
        );

        expect(
          mismatch.reportedMessage,
          'Zendesk SDK could not create ticket: CREATE_FAILED '
          '(com.zendesk.core.identity 303, identity anonymous, expects jwt): '
          'The configured authentication type and the Identity type do not '
          "match. Can't authenticate.",
        );
      });

      test('keeps the Android summary to the code and status', () {
        final android = failure(
          message: 'Unprocessable Entity',
          details: {'status': 422, 'networkError': false, 'authFailed': false},
        );

        expect(
          android.summary,
          'Zendesk SDK could not create ticket: '
          'CREATE_FAILED (HTTP 422)',
        );
      });

      test('cuts a long reason', () {
        final long = failure(message: 'x' * 300);

        expect(
          long.reportedMessage,
          'Zendesk SDK could not create ticket: CREATE_FAILED: '
          '${'x' * 200}...',
        );
      });
    });
  });
}
