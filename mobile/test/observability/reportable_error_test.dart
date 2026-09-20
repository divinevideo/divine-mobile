// ABOUTME: Tests for ReportableError marker, Reportable<T> wrapper, and the
// ABOUTME: npub/nsec sanitizer that runs on Reportable.toString().

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';

void main() {
  group(Reportable, () {
    test('is an Exception', () {
      final wrapped = Reportable(StateError('boom'));

      expect(wrapped, isA<Exception>());
    });

    test('is a ReportableError', () {
      final wrapped = Reportable(StateError('boom'));

      expect(wrapped, isA<ReportableError>());
    });

    test('unwrap returns the inner error identity', () {
      final inner = StateError('boom');
      final wrapped = Reportable(inner);

      expect(identical(wrapped.unwrap(), inner), isTrue);
    });

    test('toString includes the inner type and the inner message', () {
      final wrapped = Reportable(StateError('something broke'));

      expect(wrapped.toString(), contains('StateError'));
      expect(wrapped.toString(), contains('something broke'));
    });

    test('toString includes the context annotation when provided', () {
      final wrapped = Reportable(
        StateError('boom'),
        context: '_publishLike',
      );

      expect(wrapped.toString(), contains('_publishLike'));
    });

    test('toString omits the context annotation when null', () {
      final wrapped = Reportable(StateError('boom'));

      expect(wrapped.toString(), isNot(contains('()')));
    });

    test('toString sanitizes npub identifiers in the inner message', () {
      const npub =
          'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvw';
      final wrapped = Reportable(
        StateError('No public key for $npub during cold start'),
      );

      expect(wrapped.toString(), contains('npub1<redacted>'));
      expect(wrapped.toString(), isNot(contains(npub)));
    });

    test('toString sanitizes nsec identifiers in the inner message', () {
      const nsec =
          'nsec1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvw';
      final wrapped = Reportable(
        StateError('Signer leaked $nsec to logs'),
      );

      expect(wrapped.toString(), contains('nsec1<redacted>'));
      expect(wrapped.toString(), isNot(contains(nsec)));
    });
  });

  group('asReportableError', () {
    test('preserves explicitly reportable errors', () {
      final error = Reportable(Exception('invariant'), context: 'test');

      expect(asReportableError(error, context: 'ignored'), same(error));
    });

    test('wraps bare programming invariant errors', () {
      final error = StateError('closed');

      final reportable = asReportableError(error, context: 'detached work');

      expect(reportable, isA<Reportable<Object>>());
      final wrapped = reportable! as Reportable<Object>;
      expect(wrapped.unwrap(), same(error));
      expect(wrapped.context, 'detached work');
    });

    test('leaves expected operational errors unreportable', () {
      expect(
        asReportableError(Exception('timed out'), context: 'detached work'),
        isNull,
      );
    });
  });

  group('sanitizeForCrashReport', () {
    test('replaces a single npub with the redaction marker', () {
      const input =
          'No public key for npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefg';

      expect(
        sanitizeForCrashReport(input),
        'No public key for npub1<redacted>',
      );
    });

    test('replaces a single nsec with the redaction marker', () {
      const input = 'leaked nsec1qwertyuiopasdfghjklzxcvbnm0123456789abcdef';

      expect(sanitizeForCrashReport(input), 'leaked nsec1<redacted>');
    });

    test('replaces multiple identifiers in the same string', () {
      const input =
          'npub1aaaaaaaaaaaaaaaaaaaaaaaa shared nsec1bbbbbbbbbbbbbbbbbbbbbbbb';
      final out = sanitizeForCrashReport(input);

      expect(out, contains('npub1<redacted>'));
      expect(out, contains('nsec1<redacted>'));
      expect(out, isNot(contains('npub1aaa')));
      expect(out, isNot(contains('nsec1bbb')));
    });

    test('is a no-op for strings without nostr identifiers', () {
      const input = 'plain old failure with no nostr keys here';

      expect(sanitizeForCrashReport(input), equals(input));
    });

    test('does not redact note1 / nevent1 / nprofile1 references', () {
      // These encode pointers, not secrets — explicitly out of scope.
      const input =
          'failed to fetch note1abcdefghijklmnopqrstuvwxyz0123456789abcdef';

      expect(sanitizeForCrashReport(input), equals(input));
    });

    // Issue #4254 — emails are PII and must not flow to Crashlytics.
    test('replaces an email with the first-char + domain mask', () {
      const input = 'verification failed for user@example.com after 3 retries';

      expect(
        sanitizeForCrashReport(input),
        'verification failed for u***@example.com after 3 retries',
      );
    });

    test('replaces multiple emails in the same string', () {
      const input = 'forwarded alice@a.com to bob@b.io';
      final out = sanitizeForCrashReport(input);

      expect(out, contains('a***@a.com'));
      expect(out, contains('b***@b.io'));
      expect(out, isNot(contains('alice')));
      expect(out, isNot(contains('bob')));
    });

    test('strips email PII alongside npub / nsec in one pass', () {
      const input =
          'user@example.com leaked nsec1qwertyuiopasdfghjklzxcvbnm0123456789ab '
          'tied to npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnop';
      final out = sanitizeForCrashReport(input);

      expect(out, contains('u***@example.com'));
      expect(out, contains('nsec1<redacted>'));
      expect(out, contains('npub1<redacted>'));
      expect(out, isNot(contains('user@example.com')));
    });

    test('preserves the domain so ops can correlate failure patterns', () {
      // The whole point of partial (not opaque) redaction: ops can spot
      // "all gmail.com users are failing" without identifying anyone.
      const input = 'auth failed for alice@gmail.com';

      expect(
        sanitizeForCrashReport(input),
        contains('@gmail.com'),
      );
    });

    test('uses the shared email redactor so masking stays aligned', () {
      const email = 'first.last+tag@example.com';

      expect(
        // This locks the crash-report fallback to the same mask shape as logs.
        sanitizeForCrashReport('auth failed for $email'),
        'auth failed for ${redactEmailForLogs(email)}',
      );
    });
  });
}
