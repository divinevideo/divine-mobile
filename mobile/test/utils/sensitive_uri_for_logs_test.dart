// ABOUTME: Unit tests for redactUriStringForLogs (issue #3360 AC / plan §5).
// ABOUTME: Query keys token/code/deviceCode/verifier/secret, paths, divine://.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';

/// Issue #3360 / plan §5 — URI redaction acceptance: query keys `token`, `code`,
/// `deviceCode`, `verifier`, `secret`, legacy invite paths, and `divine://`
/// callbacks.
void main() {
  group('redactUriStringForLogs', () {
    test('returns invalid placeholder when parse fails', () {
      expect(redactUriStringForLogs('::::'), '[invalid-uri]');
      expect(redactUriStringForLogs(''), '[invalid-uri]');
      expect(redactUriStringForLogs('   '), '[invalid-uri]');
    });

    group('AC #3360 — sensitive query keys', () {
      test('redacts values for token, code, deviceCode, verifier, secret (and any other query)', () {
        const raw =
            'https://divine.video/path?token=abc&code=CDEF&deviceCode=dd&'
            'verifier=vv&secret=ss&other=xx';
        final out = redactUriStringForLogs(raw);
        expect(out, isNot(contains('abc')));
        expect(out, isNot(contains('CDEF')));
        expect(out, isNot(contains('deviceCode=dd')));
        expect(out, isNot(contains('verifier=vv')));
        expect(out, isNot(contains('secret=ss')));
        expect(out, isNot(contains('other=xx')));
        expect(out, contains('token'));
        expect(out, contains('deviceCode'));
        expect(out, contains('verifier'));
        expect(out, contains('secret'));
        expect(out, contains(redactedUriComponentForLogs));
      });

      test('each AC-listed value is absent from output (single URL)', () {
        const uri =
            'https://divine.video/x?token=w1&code=w2&deviceCode=w3&verifier=w4&secret=w5';
        final out = redactUriStringForLogs(uri);
        for (final leaked in ['w1', 'w2', 'w3', 'w4', 'w5']) {
          expect(out, isNot(contains(leaked)));
        }
      });

      test('mixed-case query parameter names still redact values', () {
        const raw = 'https://divine.video/path?Code=up&TOKEN=t&VERIFIER=v';
        final out = redactUriStringForLogs(raw);
        expect(out, isNot(contains('Code=up')));
        expect(out, isNot(contains('TOKEN=t')));
        expect(out, isNot(contains('VERIFIER=v')));
        expect(
          out.split('Code=').last,
          startsWith(redactedUriComponentForLogs),
        );
      });
    });

    test('redacts duplicate query parameter values', () {
      const raw = 'https://divine.video/x?state=1&state=2';
      final out = redactUriStringForLogs(raw);
      expect(out, isNot(contains('state=1')));
      expect(
        out.split(redactedUriComponentForLogs).length - 1,
        greaterThanOrEqualTo(2),
      );
    });

    test('preserves video and profile refs (full path segments)', () {
      const note =
          'note1qqqqqqqzghd5m8qyv7qkz9q7qkqkqkqkqkqkqkqkqkqkqkqkqkqkqkqkqkqkqkqkq';
      const raw = 'https://divine.video/video/$note';
      final out = redactUriStringForLogs(raw);
      expect(out, contains(note));

      const npub =
          'npub180cvv07tjdrrgpa9jzd0cdkej42kwsaxq9rz7gvdpjx6nz004f9uulstw6';
      const rawProfile = 'https://divine.video/profile/$npub/3';
      final outProfile = redactUriStringForLogs(rawProfile);
      expect(outProfile, contains(npub));
      expect(outProfile, contains('/3'));
    });

    test('redacts the code from a legacy invite path', () {
      const raw =
          'https://divine.video/invite/ABCD-EFGH-INVITE?utm_source=test';
      final out = redactUriStringForLogs(raw);
      expect(out, isNot(contains('ABCD')));
      expect(out, isNot(contains('utm_source=test')));
      expect(out, contains('/invite/$redactedUriComponentForLogs'));
    });

    test('clears userInfo credentials', () {
      const raw = 'https://user:sekret@divine.video/video/foo';
      final out = redactUriStringForLogs(raw);
      expect(out, isNot(contains('sekret')));
      expect(out, startsWith('https://divine.video/'));
      expect(out, contains('/video/foo'));
    });

    test('redacts fragment contents', () {
      const raw = 'https://divine.video/page#oops=sensitive-bit';
      final out = redactUriStringForLogs(raw);
      expect(out, isNot(contains('sensitive-bit')));
      expect(out, endsWith('#$redactedUriComponentForLogs'));
    });

    test('divine:// callback query does not leak token values', () {
      const raw = 'divine://signer-return?token=supersecret&refresh=1';
      final out = redactUriStringForLogs(raw);
      expect(out, startsWith('divine://'));
      expect(out, isNot(contains('supersecret')));
    });

    test('redacts query values on a relative URI', () {
      const raw = '/welcome?code=SECRET&error=';
      final out = redactUriStringForLogs(raw);
      expect(out, startsWith('/welcome?'));
      expect(out, isNot(contains('SECRET')));
      expect(out, contains('code=$redactedUriComponentForLogs'));
    });
  });

  /// Issue #4254 — redact email PII from auth-flow logs.
  group('redactEmailForLogs', () {
    test('partial-redacts a standard email, preserves domain', () {
      expect(
        redactEmailForLogs('user@example.com'),
        equals('u***@example.com'),
      );
    });

    test('partial-redacts a single-character local-part', () {
      // Even one-char local-parts get the fixed `x***` mask — the original
      // length must not be leaked.
      expect(redactEmailForLogs('a@b.co'), equals('a***@b.co'));
    });

    test('preserves subdomains in the domain part', () {
      expect(
        redactEmailForLogs('alice@mail.corp.example.com'),
        equals('a***@mail.corp.example.com'),
      );
    });

    test('hides the full local-part even when it is long', () {
      final out = redactEmailForLogs('first.last+tag@example.com');
      expect(out, equals('f***@example.com'));
      expect(out, isNot(contains('first')));
      expect(out, isNot(contains('last')));
      expect(out, isNot(contains('tag')));
    });

    test('returns the opaque placeholder for empty input', () {
      expect(redactEmailForLogs(''), equals(redactedSensitiveLogPlaceholder));
    });

    test('returns the opaque placeholder for input without `@`', () {
      expect(
        redactEmailForLogs('not-an-email'),
        equals(redactedSensitiveLogPlaceholder),
      );
    });

    test('returns the opaque placeholder for empty local-part', () {
      expect(
        redactEmailForLogs('@example.com'),
        equals(redactedSensitiveLogPlaceholder),
      );
    });

    test('returns the opaque placeholder for a domain without a dot', () {
      // `a@b` (no TLD) is not a routable host — fail closed.
      expect(
        redactEmailForLogs('a@b'),
        equals(redactedSensitiveLogPlaceholder),
      );
    });

    test('returns the opaque placeholder for whitespace-only input', () {
      // No `@` → treated like any other malformed input.
      expect(
        redactEmailForLogs('   '),
        equals(redactedSensitiveLogPlaceholder),
      );
    });
  });
}
