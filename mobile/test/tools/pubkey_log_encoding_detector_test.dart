// ABOUTME: Tests for the pubkey log-encoding detector and its ratchet
// ABOUTME: (scripts/lib/pubkey_log_encoding_detector.dart, #8066).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/pubkey_log_encoding_detector.dart';

/// Pins the detector semantics behind `check_pubkey_log_encoding.sh` (#8066).
///
/// The load-bearing distinction is whether an interpolation still HOLDS a
/// pubkey. `$pubkey` does and must be encoded; `${pubkeys.length}` does not,
/// and flagging it would demand an encoder around an integer. Both spell
/// "pubkey" in the source, so a text rule gets one of them wrong — which is
/// the whole reason this is an AST.
void main() {
  group('pubkey_log_encoding_detector', () {
    late Directory tmp;

    List<PubkeyLogSite> scan(String source, {String name = 'subject.dart'}) {
      File('${tmp.path}/lib/$name').writeAsStringSync(source);
      // Same entry point the CLI uses, so the harness cannot drift from it.
      return findSitesUnder([
        Directory('${tmp.path}/lib'),
      ], pathPrefix: tmp.path);
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('pubkey_log_encoding_test');
      Directory('${tmp.path}/lib').createSync(recursive: true);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    group('counts', () {
      test('a bare pubkey interpolated into a log call', () {
        final sites = scan(r'''
void report(String pubkey) {
  Log.info('fetching for $pubkey');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.expression, 'pubkey');
        expect(sites.single.sink, 'Log.info');
        expect(sites.single.path, 'lib/subject.dart');
        expect(sites.single.line, 2);
      });

      test('a bare pubkey in a _diagnose message argument', () {
        // The relay diagnose/_diagnose helpers forward their message to the
        // support export via nostr_client, so a raw pubkey here is exported
        // unencoded exactly as a Log.* call would be.
        final sites = scan(r'''
class RelayPool {
  void relayDoSubscribe(String pubkey) {
    _diagnose(
      RelayDiagnosticSite.queryDispatch,
      RelayDiagnosticLevel.info,
      relayUrl,
      'fetching for $pubkey',
    );
  }
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.expression, 'pubkey');
        expect(sites.single.sink, '_diagnose');
      });

      test('a prefixed name, matched on its last camelCase segment', () {
        final sites = scan(r'''
void report(String authorPubkey) {
  Log.debug('author $authorPubkey');
}
''');

        expect(sites.single.expression, 'authorPubkey');
      });

      test('a property chain ending in a pubkey', () {
        final sites = scan(r'''
void report(Account account) {
  Log.warning('stale ${account.pubkeyHex}');
}
''');

        expect(sites.single.expression, 'account.pubkeyHex');
      });

      test('a hex-suffixed name, whose last segment is not the pubkey', () {
        final sites = scan(r'''
void report(String pubkeyHex) {
  Log.info('stale $pubkeyHex');
}
''');

        expect(sites.single.expression, 'pubkeyHex');
      });

      test('an npub, which is missing the hex half of the same problem', () {
        final sites = scan(r'''
void report(String lastUsedNpub) {
  Log.info('last used $lastUsedNpub');
}
''');

        expect(sites.single.expression, 'lastUsedNpub');
      });

      test('a value laundered through a null-coalescing fallback', () {
        final sites = scan(r'''
void report(String? sessionPubkey) {
  Log.info('session ${sessionPubkey ?? "none"}');
}
''');

        expect(sites, hasLength(1));
      });

      test('a call whose name says it returns a pubkey', () {
        final sites = scan(r'''
void report() {
  Log.info('active ${_activePubkey()}');
}
''');

        expect(sites.single.expression, '_activePubkey()');
      });

      test('a package:logging sink on a logger-shaped receiver', () {
        final sites = scan(r'''
void report(String npub) {
  _log.fine('stored $npub');
}
''');

        expect(sites.single.sink, '_log.fine');
      });

      test('a bare developer log call', () {
        final sites = scan(r'''
void report(String pubkey) {
  log('signer ready for $pubkey');
}
''');

        expect(sites.single.sink, 'log');
      });
    });

    group('does not count', () {
      test('a pubkey already routed through the formatter', () {
        final sites = scan(r'''
void report(String pubkey) {
  Log.info('fetching for ${pubkeyForLogs(pubkey)}');
}
''');

        expect(sites, isEmpty);
      });

      test('a count taken off a collection of pubkeys', () {
        final sites = scan(r'''
void report(List<String> pubkeys) {
  Log.info('${pubkeys.length} accounts');
}
''');

        expect(sites, isEmpty);
      });

      test('a collection, which the formatter cannot take', () {
        final sites = scan(r'''
void report(List<String> followingPubkeys) {
  Log.info('following $followingPubkeys');
}
''');

        expect(sites, isEmpty);
      });

      test('a boolean derived from a pubkey', () {
        final sites = scan(r'''
void report(String? pubkey) {
  Log.info('bound=${pubkey != null}');
}
''');

        expect(sites, isEmpty);
      });

      test('an emptiness check on a pubkey', () {
        final sites = scan(r'''
void report(String videoAuthorPubkey) {
  Log.info('has author ${videoAuthorPubkey.isNotEmpty}');
}
''');

        expect(sites, isEmpty);
      });

      test('a joined list of pubkeys', () {
        final sites = scan(r'''
void report(List<String> teamPubkeys) {
  Log.info('team ${teamPubkeys.join(", ")}');
}
''');

        expect(sites, isEmpty);
      });

      test('a comment naming a pubkey', () {
        final sites = scan('''
void report(String pubkey) {
  // TODO: log the pubkey
  Log.info('done');
}
''');

        expect(sites, isEmpty);
      });

      test('a string literal body naming a pubkey', () {
        final sites = scan('''
void report() {
  Log.info('pubkey missing');
}
''');

        expect(sites, isEmpty);
      });

      test('a dartdoc reference to a pubkey', () {
        final sites = scan('''
/// Renders [pubkey].
void report(String pubkey) {
  Log.info('done');
}
''');

        expect(sites, isEmpty);
      });

      test('a pubkey interpolated somewhere that is not a log sink', () {
        final sites = scan(r'''
String key(String pubkey) => 'following_list_$pubkey';
''');

        expect(sites, isEmpty);
      });

      test('a non-pubkey identifier that merely contains "author"', () {
        final sites = scan(r'''
void report(bool requireAuthoritative) {
  Log.info('authoritative=$requireAuthoritative');
}
''');

        expect(sites, isEmpty);
      });
    });

    group('reporting', () {
      test('counts each unencoded pubkey in one call separately', () {
        final sites = scan(r'''
void report(String pubkey, String ownerPubkey) {
  Log.info('moving $pubkey to $ownerPubkey');
}
''');

        expect(sites, hasLength(2));
      });

      test('orders sites by path then line', () {
        scan(r'''
void a(String pubkey) {
  Log.info('a $pubkey');
}
''', name: 'a.dart');
        final sites = scan(r'''
void b(String pubkey) {
  Log.info('b $pubkey');

  Log.info('b again $pubkey');
}
''', name: 'b.dart');

        expect(
          sites.map((s) => '${s.path}:${s.line}'),
          ['lib/a.dart:2', 'lib/b.dart:2', 'lib/b.dart:4'],
        );
      });

      test('skips generated files', () {
        final sites = scan(r'''
void report(String pubkey) {
  Log.info('generated $pubkey');
}
''', name: 'subject.g.dart');

        expect(sites, isEmpty);
      });
    });
  });
}
