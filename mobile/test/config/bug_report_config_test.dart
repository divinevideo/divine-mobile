// ABOUTME: Pins sanitizeDiagnosticText against all three failure directions:
// ABOUTME: missed credentials, partially-redacted secrets, and shredded prose.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/bug_report_config.dart';

/// Fragments that must never survive sanitization. Asserting on these rather
/// than only on the presence of `[REDACTED]` is what catches *partial*
/// redaction: half a secret next to a redaction marker is worse than no
/// redaction, because the marker reads as proof the value was handled.
const _secretFragments = [
  'hunter2',
  'eyJhbGciOi',
  'abc123',
  'deadbeef',
  'eyJabcdefghijk',
  'eyJdefghijkl',
  'YWJjOmRlZmc=',
  'correct horse battery staple',
  'beta gamma',
  'alpha',
  'Alice',
];

/// A real `DeepLinkService._describeUriForLogs` line.
const _deepLinkLogLine =
    'scheme=https, host=divine.video, route=/invite, '
    'segments=2, queryKeys=[code, state]';

void main() {
  group('sanitizeDiagnosticText', () {
    test('redacts a bare NIP-05 domain fragment', () {
      const input = 'profile nip05: @example.test';

      expect(sanitizeDiagnosticText(input), 'profile nip05: [REDACTED]');
    });
    group('redacts the whole credential value', () {
      // Serialized shapes are how credentials actually reach the log buffer,
      // so a quote between the key and the separator must not defeat the rule,
      // and a quoted value must be consumed to its closing quote.
      const cases = <String, String>{
        'quoted multi-word value':
            '{"password":"correct horse battery staple"}',
        'quoted value with comma': '{"password":"alpha,beta"}',
        'quoted value with escaped double quote':
            r'{"password":"alpha\"beta gamma"}',
        'quoted value with escaped single quote':
            r"{'password': 'alpha\'beta gamma'}",
        'quoted scheme-prefixed value': '{"token":"Bearer eyJhbGciOi"}',
        'json token array': '{"token":["eyJabcdefghijk","eyJdefghijkl"]}',
        'authorization header array':
            '"Authorization": ["Bearer eyJabcdefghijk"]',
        'unquoted scheme-prefixed value': 'Auth token: Bearer eyJhbGciOi',
        'fat arrow separator': 'password => hunter2',
        'json api key': '{"api_key":"abc123"}',
        'camel case api key': "{'apiKey': 'abc123'}",
        'hyphenated api key': '{"x-api-key":"abc123"}',
        'json private key': '{"private_key":"abc123"}',
        'underscored secret key': 'secret_key: abc123',
        'screaming snake compound key': 'AWS_SECRET_ACCESS_KEY=deadbeef',
        'underscored compound key': 'password_confirmation: hunter2',
        'camel case compound key': 'passwordHash: hunter2',
        'camel case json key': '{"tokenValue":"eyJhbGciOi"}',
        'pascal case compound key': 'PasswordHash: hunter2',
        'pascal case json key': '{"TokenValue":"eyJhbGciOi"}',
        'enumerated word at end of key': 'clientSecret: deadbeef',
        'passphrase alias': 'passphrase=hunter2',
        'plural password key': 'passwords=hunter2',
        'passcode alias': 'passcode: hunter2',
        'pwd alias': 'pwd=hunter2',
        'plural token key': '{"tokens":["eyJabcdefghijk"]}',
        'plural secret key': 'secrets: hunter2',
        'plural api key': 'apiKeys: abc123',
        // The `query` exemption is anchored, so a key that merely ends in
        // `query` is still a credential key.
        'key ending in query': 'bigquery_key=abc123',
        'camel case key ending in query': 'BigQueryKey: abc123',
        'generic signing key': 'signing_key: abc123',
        'generic encryption key': 'encryption_key=abc123',
        'screaming snake generic key': 'ENCRYPTION_KEY=deadbeef',
        'generic hyphenated key': 'master-key=hunter2',
        'generic camel case key': 'recoveryKey=abc123',
        'camel case session key': 'sessionKey: abc123',
        'camel case json key name': '{"signingKey":"abc123"}',
        'run-together api key': 'apikey: abc123',
        // A 64-char hex value is deliberately not redacted, so for hex-form
        // private keys the key *name* is the only thing standing between the
        // secret and a public ticket. `privateKeyHex` and `rawKeyHex` are the
        // spellings this repo actually uses, 122 and 112 times respectively.
        'camel case key with suffix': 'privateKeyHex: aabbccdd',
        'nested camel case key with suffix': 'senderPrivateKeyHex: aabbccdd',
        'raw camel case key with suffix': 'rawKeyHex: aabbccdd',
        // Plurals hide a credential exactly as well as singulars, and the
        // enumerated words already accept `s`. Without the same `s` on the two
        // `key` rules, `privateKey` is covered and `privateKeys` is not.
        'plural generic key': 'signing_keys: abc123',
        'plural camel case key': 'sessionKeys: abc123',
        'plural camel case private key': 'privateKeys: ["aabbccdd"]',
        'plural screaming snake generic key': 'ENCRYPTION_KEYS=deadbeef',
        // A braced value must be consumed to its closing brace for the same
        // reason a bracketed one is: otherwise the rule redacts `{"` and
        // leaves the secret sitting next to the `[REDACTED]` marker.
        'json object value': '{"token":{"value":"eyJhbGciOi"}}',
        'json object secret value': '{"secret":{"nested":"hunter2"}}',
        // Stopping at the *first* closing delimiter puts the secret right
        // back beside the marker as soon as the object has a sibling.
        'nested json object value':
            '{"token":{"header":{},"jwt":"eyJhbGciOi"}}',
        'nested json api key value':
            '{"api_key":{"meta":{"rotated":1},"value":"abc123"}}',
        'nested dart map value': 'Auth: {secret: {inner: {}, real: hunter2}}',
        'closing brace inside a quoted value': 'token: {"v":"hun}ter2"}',
        'array of objects value': '{"token":[{"a":1},{"jwt":"eyJhbGciOi"}]}',
        // Sanitization runs over the assembled multi-line body, so a
        // pretty-printed value is a real shape, not a synthetic one.
        'pretty printed object value': 'token: {\n  "value": "hunter2"\n}',
        'pretty printed array value': 'apiKey: [\n  "abc123"\n]',
        'pretty printed value mid report':
            '1. open app\npassword: {\n  "new": "hunter2"\n}\n2. it crashes',
        'acronym-prefixed key': 'AESKey: abc123',
        'hmac key': 'HMACKey=deadbeef',
        'pwd compound key': 'pwdHash: deadbeef',
        'pascal pwd compound key': 'PwdValue=hunter2',
        'yaml doubled single quote': "password: 'alpha''beta gamma'",
        'json access token': '{"access_token":"eyJhbGciOi"}',
        'json refresh token': '{"refresh_token":"eyJhbGciOi"}',
        'json bearer header': '{"Authorization":"Bearer eyJhbGciOi"}',
        'dart map bearer header': "{'Authorization': 'Bearer eyJhbGciOi'}",
        'basic header': 'Authorization: Basic YWJjOmRlZmc=',
        'bearer header': 'Authorization: Bearer eyJhbGciOi',
        'header with no scheme word': 'Authorization: abc123def',
        'colon separated': 'password: hunter2',
        'equals separated': 'secret=abc123',
        'nip46 bunker secret': 'bunker://relay.example?secret=deadbeef',
        // The bug report renders device info as markdown, and the emphasis
        // markers sit between the key and the value.
        'markdown emphasised key': '- **sessionKey:** abc123',
        'markdown emphasised password': '**password:** hunter2',
        // `jwt` is how a bearer token is labelled when it is not called a
        // token, and the policy doc promises bearer tokens never reach a
        // public payload.
        'json jwt key': '{"jwt":"eyJhbGciOi"}',
        'bare jwt key': 'jwt: eyJhbGciOi',
        'camel case jwt key': '{"jwtValue":"eyJhbGciOi"}',
        'pascal case jwt key': 'JwtCredential: eyJhbGciOi',
        'screaming jwt key': 'JWTValue: eyJhbGciOi',
      };

      for (final entry in cases.entries) {
        test(entry.key, () {
          final sanitized = sanitizeDiagnosticText(entry.value);

          expect(sanitized, contains('[REDACTED]'));
          for (final fragment in _secretFragments) {
            expect(
              sanitized,
              isNot(contains(fragment)),
              reason: 'leaked "$fragment" from ${entry.value}',
            );
          }
        });
      }
    });

    group('redacts filesystem paths that carry PII', () {
      // Each case pairs a path shape that reaches the log buffer through an
      // exception toString() with the PII fragment that must not survive: a
      // desktop account name, an install UUID, or a user-chosen imported-file
      // basename. The whole path is redacted rather than one segment: the
      // platform is already in the report's device info, so the FS root marker
      // adds no triage value worth the risk of a partial leak.
      const cases = <String, ({String input, String forbidden})>{
        'macos home account name': (
          input: "PathNotFoundException: path = '/Users/mjbradley/Library/Preferences/app.plist'",
          forbidden: 'mjbradley',
        ),
        'macos home directory terminal': (
          input: "FileSystemException: directory '/Users/mjbradley' is gone",
          forbidden: 'mjbradley',
        ),
        // A quoted path (the dominant exception render) whose basename holds a
        // space must redact whole. Stopping at the space would leave the
        // filename fragment beside the marker, a partial leak.
        'macos home spaced filename quoted': (
          input: "FileSystemException: path = '/Users/mjbradley/Music/My Song.m4a'",
          forbidden: 'Song',
        ),
        'ios container spaced filename quoted': (
          input: "FileSystemException: path = '/var/mobile/Containers/Data/Application/1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D/tmp/My Song.m4a'",
          forbidden: 'Song',
        ),
        'macos external volume spaced filename quoted': (
          input: "FileSystemException: path = '/Volumes/Backup Drive/Music/My Song.m4a'",
          forbidden: 'My Song',
        ),
        'linux home account name': (
          input: "FileSystemException: Cannot open, path = '/home/mbradley/notes.txt'",
          forbidden: 'mbradley',
        ),
        'windows home account name': (
          input: r'PathNotFoundException: C:\Users\mbradley\AppData\Local\Temp',
          forbidden: 'mbradley',
        ),
        'ios container user filename': (
          input: "FileSystemException: path = '/var/mobile/Containers/Data/Application/1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D/Documents/draft_audio_imports/d1/1699999999000_My_Song.m4a'",
          forbidden: 'My_Song',
        ),
        'ios container install uuid': (
          input: "FileSystemException: path = '/var/mobile/Containers/Data/Application/1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D/Documents/x.m4a'",
          forbidden: '1A2B3C4D',
        ),
        'android app-data user filename': (
          input: '/data/user/0/video.divine.app/cache/1699999999000_My_Song.m4a (No such file)',
          forbidden: 'My_Song',
        ),
        'android shared-storage user filename': (
          input: '/storage/emulated/0/Download/1699999999000_My_Song.m4a',
          forbidden: 'My_Song',
        ),
        'macos container user filename via home root': (
          input: "path = '/Users/mjbradley/Library/Containers/video.divine.app/Data/Documents/draft_audio_imports/d1/1699999999000_My_Song.m4a'",
          forbidden: 'My_Song',
        ),
      };

      for (final entry in cases.entries) {
        test(entry.key, () {
          final sanitized = sanitizeDiagnosticText(entry.value.input);

          expect(sanitized, contains('[REDACTED]'));
          expect(
            sanitized,
            isNot(contains(entry.value.forbidden)),
            reason:
                'leaked "${entry.value.forbidden}" from ${entry.value.input}',
          );
        });
      }

      test('quoted path preserves surrounding diagnostic context', () {
        const input =
            "FileSystemException: path = '/Users/mjbradley/Music/My Song.m4a' "
            '(OS Error: No such file, errno = 2)';

        expect(
          sanitizeDiagnosticText(input),
          equals(
            "FileSystemException: path = '[REDACTED]' "
            '(OS Error: No such file, errno = 2)',
          ),
        );
      });

      test('unbalanced path quote preserves later diagnostic context', () {
        const input =
            "path = '/Users/mjbradley/song.m4a then relay "
            'wss://relay.divine.video and event abc123';

        expect(
          sanitizeDiagnosticText(input),
          equals(
            "path = '[REDACTED] then relay "
            'wss://relay.divine.video and event abc123',
          ),
        );
      });

      test('apostrophe in a double-quoted path is redacted whole', () {
        const input =
            'path = "/Users/mjbradley/Music/it\'s here.m4a" next '
            'https://media.divine.video/a.mp4';

        expect(
          sanitizeDiagnosticText(input),
          equals(
            'path = "[REDACTED]" next '
            'https://media.divine.video/a.mp4',
          ),
        );
      });
    });

    test('an unbalanced quote costs one word, not the rest of the report', () {
      // A quoted branch that tolerated a missing closing quote would run to
      // the end of the payload, so a user typing `password: "test1` into
      // steps-to-reproduce would silently delete every field printed after it.
      const payload =
          '1. enter password: "test1\n'
          '[10:00] [INFO] feed loaded 42 videos\n'
          '[10:01] [ERROR] upload failed: connection reset';

      final sanitized = sanitizeDiagnosticText(payload);

      expect(sanitized, contains('[REDACTED]'));
      expect(sanitized, isNot(contains('test1')));
      expect(sanitized, contains('feed loaded 42 videos'));
      expect(sanitized, contains('upload failed: connection reset'));
    });

    test('an unclosed brace consumes at most the bound, not the report', () {
      // The filler must contain braces of its own. Real logs are full of them
      // (`Map.toString`), and without one the bounded branch never engages and
      // this test passes on the unquoted fallback instead of the property it
      // names.
      //
      // The honest property is not "nothing after the stray brace is lost" -
      // everything within the bound *is* lost, and in a short report that can
      // be all of it. It is that the loss stops at 4000 characters instead of
      // running to the end of a payload that can reach `maxLogSummaryLength`.
      const line = '[10:00] [INFO] upload failed {code: 500}\n';
      final payload =
          'password: {oops\n'
          '${line * 200}'
          '[99:99] [ERROR] relay disconnected: connection reset';

      final sanitized = sanitizeDiagnosticText(payload);

      expect(payload.length, greaterThan(6000));
      expect(sanitized, contains('[REDACTED]'));
      expect(sanitized, contains('relay disconnected: connection reset'));
      expect(payload.length - sanitized.length, lessThan(4100));
    });

    test('a collection value larger than the bound is still bounded', () {
      // Above 4000 characters a secret survives beside the marker. That is the
      // documented residual, and it is pinned so the bound cannot be lowered
      // into the range of an ordinary JWT or pretty-printed device dump
      // without this failing.
      final withinBound = 'token: {"v":"${'a' * 3000}hunter2"}';
      final beyondBound = 'token: {"v":"${'a' * 5000}hunter2"}';

      expect(sanitizeDiagnosticText(withinBound), isNot(contains('hunter2')));
      expect(sanitizeDiagnosticText(beyondBound), contains('hunter2'));
    });

    test('a long pasted collection value does not scan quadratically', () {
      // Every `token: {` candidate rescans forward for a closing delimiter.
      // Unbounded, that is quadratic in the size of a pasted field, and
      // `bug_report_dialog.dart` puts no maxLength on those fields - so it
      // runs on the UI thread over text an attacker can influence.
      //
      // Quadrupling the input costs ~4x bounded and ~11x unbounded (measured
      // 133/585ms vs 239/2680ms), so 7x separates them with margin on both
      // sides rather than pinning a machine-specific duration.
      // Min of three per size: a single sample leaves the ratio one GC pause
      // or scheduler preemption away from crossing the threshold, which under
      // the merged VGV isolate on a loaded shard is the classic wall-clock
      // flake shape.
      int measure(int reps) {
        var best = 1 << 30;
        for (var run = 0; run < 3; run++) {
          final stopwatch = Stopwatch()..start();
          sanitizeDiagnosticText('token: {x ' * reps);
          final elapsed = stopwatch.elapsedMilliseconds;
          if (elapsed < best) best = elapsed;
        }
        return best;
      }

      measure(500); // warm up, so the first measured run carries no setup cost
      final small = measure(2000);
      final large = measure(8000);

      expect(large, lessThan(small * 7));
    });

    test('a long compound key run does not scan quadratically', () {
      // Separate from the exponential case below: this one is linear per
      // attempt but walks the whole run at every start position, which is
      // quadratic overall. Measured 18.6s for 100KB of `password_` before the
      // segment cap, 94ms after - on the UI thread, over a field with no
      // maxLength.
      // The ceiling is a smoke threshold, not a budget: 94ms here against
      // 2000, because the failure it guards is three orders of magnitude away.
      // Do not tighten it toward the observed number - unlike the ratio-based
      // sibling test above, this one is machine-dependent.
      final stopwatch = Stopwatch()..start();
      sanitizeDiagnosticText('password_' * 11100);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('a long email-shaped run does not scan quadratically', () {
      // The email pattern used to have unbounded local-part and domain
      // quantifiers. Boundary-heavy text inside the allowed character class
      // (`.`, `-`, `_`) made every candidate rescan the rest of the run before
      // failing, which hit pasted paths, ids, and base64-like strings.
      //
      // The ceiling is a smoke threshold, not a performance budget. Bounded
      // runs are single-digit milliseconds here; the unbounded pattern takes
      // seconds at this input size.
      var best = 1 << 30;
      for (var run = 0; run < 3; run++) {
        final stopwatch = Stopwatch()..start();
        sanitizeDiagnosticText('a.b-c_' * 8000);
        final elapsed = stopwatch.elapsedMilliseconds;
        if (elapsed < best) best = elapsed;
      }

      expect(best, lessThan(1000));
    });

    test('a long compound key cannot be made to backtrack exponentially', () {
      // An ambiguous segment class (`(?:[_-]\w+)*`, where `\w` also matches
      // `_`) parses the same key 2^n ways and explores all of them before
      // failing for want of a separator. That runs on the UI thread, per log
      // entry, over text that can come from a remote profile name or an
      // attacker-typed report field.
      //
      // 28 segments is chosen so a reintroduced ambiguity fails this in ~17s
      // (measured) rather than hanging the suite, which is what a larger
      // exponent would do. Unambiguous classes run it in ~0ms.
      final ambiguousKeys = ['token${'_a' * 28}', 'token${'Aa' * 28}'];

      final stopwatch = Stopwatch()..start();
      ambiguousKeys.forEach(sanitizeDiagnosticText);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    group('preserves diagnostic signal', () {
      // Keys that merely start with a credential word, and prose that merely
      // uses one. Redacting these costs the reported symptom for no privacy
      // gain - the failure mode that makes a support ticket useless.
      const cases = <String>[
        // The signed-in public key is deliberately kept: support needs it to
        // connect a report to an account, and it is public by construction.
        'pubkey: npubxyz123',
        '**User Pubkey:** npub1abcdef',
        '{"user_pubkey":"abc123def"}',
        'pub_key: npub1abc',
        'public_key: npub1abc',
        'publicKey: npub1abc',
        'PublicKey: npub1abc',
        'recipientPublicKey: npub1abc',
        'theirPubKey: npub1abc',
        'pubkeyHex: abc123def',
        'user_pubkeyHex: abc123def',
        // Plural public-key spellings are the most common identifiers in this
        // repo (`pubkeys` alone appears ~900 times); the `s` on the key rules
        // must not reach past the public-key guards.
        'pubkeys: [npub1abc]',
        '- **platform:** ios',
        '**User Pubkey:** npub1abc',
        'participantPubkeys: [npub1abc]',
        'publicKeys: [npub1abc]',
        'pub_keys: [npub1abc]',
        'physicalKeys: {KeyA}',
        // `DeepLinkService._describeUriForLogs` logs a deep link's query
        // parameter *names* with no values, on purpose. Redacting it deletes
        // a diagnostic that was built to be privacy-safe, and deep links are
        // a common subject of bug reports.
        _deepLinkLogLine,
        'query_keys=[code, state]',
        // Bare `key` is an ordinary English word. These are real in-repo
        // strings: an l10n error message, a model's toString, and Flutter key
        // events - none of them carry a credential.
        'Failed to import key: SomeError at 0',
        'ClipChromaKey(key: green, backgroundVideoPath: x)',
        'KeyEvent: KeyDownEvent',
        // Flutter's KeyEvent.toString() prints these; never credentials.
        'KeyDownEvent(physicalKey: keyA, logicalKey: keyA, character: x)',
        'keyLabel: a',
        'KeyValue: 42',
        'Cache key: video_123',
        'monkey: banana',
        'hotkey: ctrl',
        'keyboard: qwerty',
        '{"secretaryName":"Alice"}',
        '{"tokenization":"failed"}',
        '{"passwordless":true}',
        '{"secretary":"Alice"}',
        'Tokenization: failed',
        'Password reset failed',
        'my password reset email never arrives',
        'the login token expired instantly and I got logged out',
        'Secret DMs are not decrypting',
        'Token refresh scheduled',
        // Triage-critical URLs and routes must survive. The team keeps hosts
        // and routes by design (see redactUriStringForLogs), and a media or
        // relay URL is often the whole point of a report.
        'https://media.divine.video/abcdef0123456789.mp4',
        'wss://relay.divine.video',
        'GoRouterState: /video/abcdef0123',
        '/invite',
        // `/home/<index>` is the video-feed route (RoutePaths.videoFeedForIndex),
        // not a Unix home directory. A home-dir path always has content below
        // the account name; the route is terminal, so it must survive.
        'navigated to /home/3',
        'GoRouterState: /home/12',
        // The quoted-path rule must not fire on a quoted value that is not a
        // path rooted at a covered directory.
        "error detail: 'connection reset by peer'",
        "resource url: 'https://media.divine.video/abcdef0123456789.mp4'",
        // The root is case-sensitive, so a lowercase `/users/` web-route
        // segment in a URL is not mistaken for a macOS home directory. This
        // guards against a regression that made the pattern case-insensitive.
        'https://example.com/users/profile/123',
        // Package and SDK references in stack frames are not PII.
        'package:openvine/services/local_audio_import_service.dart:54:11',
        'dart:async/zone.dart 1234:5',
        // Absolute system paths carry no account name or user file.
        '/usr/local/bin/dart',
        '/System/Library/Frameworks/Foundation.framework',
        // A relative asset path is not user data.
        'assets/images/logo.png',
      ];

      for (final input in cases) {
        test(input, () {
          expect(sanitizeDiagnosticText(input), equals(input));
        });
      }
    });

    test('still redacts nostr private keys', () {
      const nsec =
          'nsec1qqqsyrhq4p4d8hf40q7tlujzw87hqhz9axhfnm35s2a3u3rrnwsq9sp5p6';
      const ncryptsec = 'ncryptsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq';

      expect(sanitizeDiagnosticText('key $nsec'), isNot(contains(nsec)));
      expect(
        sanitizeDiagnosticText('key $ncryptsec'),
        isNot(contains(ncryptsec)),
      );
    });
  });
}
