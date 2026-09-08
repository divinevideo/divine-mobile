// ABOUTME: Tests for the Nostr-ID log-truncation detector and its ratchet
// ABOUTME: (scripts/lib/nostr_id_log_truncation_detector.dart, #3372).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/nostr_id_log_truncation_detector.dart';

/// Pins the detector semantics behind `check_nostr_id_log_truncation.sh`
/// (#3372).
///
/// The load-bearing distinction is the SINK. Shortening a Nostr identifier for
/// the UI is allowed and common; shortening it into a log is the defect, and
/// the two are the same expression with a different parent. A detector that
/// confuses them is either unusable (every `truncateNpub` call site fails CI)
/// or blind (the log sites it exists for slip through).
///
/// The second load-bearing distinction is `take`: on a character view it cuts
/// an identifier in half, on a List it samples whole identifiers — which is
/// the behaviour the rule WANTS. Both live `.take()` call sites in this repo
/// were the second kind, so getting this backwards would have failed CI on
/// two correct log lines.
void main() {
  group('nostr_id_log_truncation_detector', () {
    late Directory tmp;

    List<TruncationSite> scan(String source, {String name = 'subject.dart'}) {
      File('${tmp.path}/lib/$name').writeAsStringSync(source);
      // Same entry point the CLI uses, so the harness cannot drift from it.
      return findSitesUnder([
        Directory('${tmp.path}/lib'),
      ], pathPrefix: tmp.path);
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('nostr_id_log_truncation_test');
      Directory('${tmp.path}/lib').createSync(recursive: true);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    group('counts', () {
      test('a substring interpolated straight into a log call', () {
        final sites = scan(r'''
void report(String eventId) {
  Log.info('found ${eventId.substring(0, 8)}...');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'eventId');
        expect(sites.single.how, 'substring');
        expect(sites.single.sink, 'Log.info');
        expect(sites.single.path, 'lib/subject.dart');
        expect(sites.single.line, 2);
      });

      test('a substring in a _diagnose message argument', () {
        // The real emit path: relay sites call the diagnose/_diagnose helpers,
        // which build the RelayDiagnostic and hand its message to nostr_client,
        // which forwards it to UnifiedLogger and thus the support export. The
        // literal is the helper argument, so the ratchet must read it there.
        final sites = scan(r'''
class RelayPool {
  void relayDoSubscribe(String eventId) {
    _diagnose(
      RelayDiagnosticSite.queryDispatch,
      RelayDiagnosticLevel.info,
      relayUrl,
      'found ${eventId.substring(0, 8)}...',
    );
  }
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'eventId');
        expect(sites.single.sink, '_diagnose');
      });

      test('a substring in a directly-built RelayDiagnostic message', () {
        // Belt for a call site that skips the helper and builds the diagnostic
        // inline with a literal message.
        final sites = scan(r'''
void report(String eventId) {
  emitRelayDiagnostic(
    sink,
    RelayDiagnostic(message: 'found ${eventId.substring(0, 8)}...'),
  );
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'eventId');
        expect(sites.single.sink, 'RelayDiagnostic.message');
      });

      test('a shortened local reaching a log one statement later', () {
        // The shape three of the four #3372 sites used: compute a `preview`,
        // then log it. The truncation and the log call are different
        // statements, so a check local to the log call sees nothing wrong.
        final sites = scan(r'''
void report(String pubkey) {
  final preview = pubkey.length > 8 ? pubkey.substring(0, 8) : pubkey;
  Log.debug('author: $preview');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'pubkey');
        expect(sites.single.line, 3);
      });

      test('every reference to that local, not just the first', () {
        final sites = scan(r'''
void report(String pubkey) {
  final preview = pubkey.substring(0, 8);
  Log.debug('a: $preview');
  Log.info('b: $preview');
}
''');

        expect(sites.map((s) => s.line), [3, 4]);
      });

      test('does not treat a collection property as the logged value', () {
        final member = ['sub', 'string'].join();
        expect(
          scan('''
void report(List<Event> events) {
  final ids = events.map((event) => event.id.$member(0, 8)).toList();
  Log.info('published \${ids.length} events');
}
'''),
          isEmpty,
        );
      });

      test('ignores matching locals declared in sibling closures', () {
        final member = ['sub', 'string'].join();
        expect(
          scan('''
void report(String pubkey, String tag) {
  void prepare() {
    final tag = pubkey.$member(0, 8);
    cache.store(tag);
  }

  Log.info('tag: \$tag');
}
'''),
          isEmpty,
        );
      });

      test('ignores matching locals declared after the log call', () {
        final member = ['sub', 'string'].join();
        expect(
          scan('''
void report(String pubkey, String preview) {
  Log.info('author: \$preview');
  final preview = pubkey.$member(0, 8);
}
'''),
          isEmpty,
        );
      });

      test('a same-file helper that shortens its own parameter', () {
        // `_maskKey(npub)` — eleven of the nineteen #3372 sites.
        final sites = scan(r'''
String _maskKey(String key) {
  if (key.length < 12) return key;
  return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
}

void report(String npub) {
  _log.info('identity: ${_maskKey(npub)}');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'npub');
        expect(sites.single.how, '_maskKey');
        expect(sites.single.sink, '_log.info');
        expect(sites.single.line, 7);
      });

      test('a shortener defined in another file', () {
        // `NostrKeyUtils.maskKey` and `StringUtils.formatIdForLogging` were
        // both public helpers whose docs recommended them for logging, so the
        // shortening and the log call routinely sit in different files.
        File('${tmp.path}/lib/helpers.dart').writeAsStringSync('''
class StringUtils {
  static String formatIdForLogging(String id) => id.substring(0, 8);
}
''');
        final sites = scan(r'''
void report(String eventId) {
  Log.info('found ${StringUtils.formatIdForLogging(eventId)}');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.path, 'lib/subject.dart');
        expect(sites.single.identifier, 'eventId');
        expect(sites.single.how, 'formatIdForLogging');
      });

      test('take over a character view of an identifier', () {
        final sites = scan(r'''
void report(String pubkey) {
  Log.info('author ${pubkey.characters.take(8)}');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'pubkey');
        expect(sites.single.how, 'take');
      });

      test('a camelCase name whose last segment is an identifier word', () {
        final sites = scan(r'''
void report(String giftWrapId, String senderPubkey) {
  Log.warning('${giftWrapId.substring(0, 8)} ${senderPubkey.substring(0, 8)}');
}
''');

        expect(sites.map((s) => s.identifier), ['giftWrapId', 'senderPubkey']);
      });

      test('a property access, not just a local', () {
        final sites = scan(r'''
void report(Event event) {
  Log.error('event ${event.id.substring(0, 8)}');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'id');
      });
    });

    group('counts an ellipsis after a WHOLE identifier', () {
      // Nothing is shortened here — `${event.id}` is the full 64-hex value and
      // the dots are three literal characters. It still counts: it reads as a
      // cut id, misreading exactly this produced #3372's `mobile/lib`
      // evidence, and that issue's acceptance criterion names the shape.
      test('flags an interpolated id followed by literal dots', () {
        final sites = scan(r'''
void report(Event event) {
  Log.info('Skipping repost event ${event.id}... (reposts disabled)');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'id');
        expect(sites.single.how, 'ellipsis-suffix');
      });

      test('flags a bare interpolation followed by dots', () {
        final sites = scan(r'''
void report(String npub) {
  Log.info('loading identity keys for npub=$npub...');
}
''');

        expect(sites.single.identifier, 'npub');
      });

      test('flags the single-character ellipsis too', () {
        // Both spellings feed the prefilter as well as the rule, so a file
        // that only uses the one-character form still gets parsed.
        final sites = scan(r'''
void report(Event event) {
  Log.info('e ${event.id}…');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.how, 'ellipsis-suffix');
      });

      test('leaves progress prose alone', () {
        // `method` and `subscriptionType` are not identifier names, so the
        // dots mean what they say. Both shapes are live in this repo.
        expect(
          scan(r'''
void report(String method, String subscriptionType) {
  Log.info('[Keycast RPC] Calling $method...');
  Log.info('Loading more historical events for $subscriptionType...');
}
'''),
          isEmpty,
        );
      });

      test('leaves a full identifier with no dots alone', () {
        expect(
          scan(r'''
void report(Event event) {
  Log.info('Skipping repost event ${event.id} (reposts disabled)');
}
'''),
          isEmpty,
        );
      });
    });

    group('does not count', () {
      test('a full identifier in a log call', () {
        expect(
          scan(r'''
void report(String eventId) {
  Log.info('found $eventId');
}
'''),
          isEmpty,
        );
      });

      test('secret names are not treated as public identifiers', () {
        final member = ['sub', 'string'].join();
        expect(
          scan('''
void report(String nsec) {
  cache.store(nsec.$member(0, 10));
}
'''),
          isEmpty,
        );
      });

      test('shortening whose sink is the UI rather than a log', () {
        // NostrKeyUtils.truncateNpub and its call sites live here. AGENTS.md
        // allows display shortening; only the log path is frozen.
        expect(
          scan(r'''
String truncateNpub(String npub) =>
    '${npub.substring(0, 10)}...${npub.substring(npub.length - 6)}';

Widget build(BuildContext context) => Text(truncateNpub(npub));
'''),
          isEmpty,
        );
      });

      test('take over a List, which samples whole identifiers', () {
        // `subscribedIds.take(3).join(', ')` logs three COMPLETE ids. Counting
        // it would fail CI on a log line that already does the right thing.
        expect(
          scan(r'''
void report(List<String> subscribedIds) {
  Log.warning('IDs: ${subscribedIds.take(3).join(', ')}');
}
'''),
          isEmpty,
        );
      });

      test('a prose ellipsis in a log message', () {
        expect(
          scan('''
void start() {
  Log.info('Publishing Nostr event...');
}
'''),
          isEmpty,
        );
      });

      test('shortening a value that is not an identifier', () {
        // Capping a response body or a blurhash is a length guard, not an
        // identifier being cut.
        expect(
          scan(r'''
void report(String responseBody, String blurhash) {
  Log.debug('body ${responseBody.substring(0, 1000)} ${blurhash.substring(0, 8)}');
}
'''),
          isEmpty,
        );
      });

      test('a shortening with no log call anywhere near it', () {
        expect(
          scan('''
String shortId(String eventId) => eventId.substring(0, 8);
'''),
          isEmpty,
        );
      });

      test('generated files', () {
        expect(
          scan(r'''
void report(String eventId) {
  Log.info('${eventId.substring(0, 8)}');
}
''', name: 'subject.g.dart'),
          isEmpty,
        );
      });
    });

    group('rejects secrets reaching logs', () {
      test('a whole nsec', () {
        final sites = scan(r'''
void report(String nsec) {
  Log.error('nsec=$nsec');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'nsec');
        expect(sites.single.how, 'secret-in-log');
      });

      test('a compound private-key name', () {
        final sites = scan(r'''
void report(String rawPrivateKey) {
  Log.error('key=$rawPrivateKey');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'rawPrivateKey');
        expect(sites.single.how, 'secret-in-log');
      });

      test('a secret with a trailing representation segment', () {
        final sites = scan(r'''
void report(
  String privateKeyHex,
  String senderPrivateKeyHex,
  String privateKeyBytes,
  String nsecString,
) {
  Log.error('$privateKeyHex $senderPrivateKeyHex $privateKeyBytes $nsecString');
}
''');

        expect(sites.map((site) => site.identifier), [
          'privateKeyHex',
          'senderPrivateKeyHex',
          'privateKeyBytes',
          'nsecString',
        ]);
        expect(sites.map((site) => site.how).toSet(), {'secret-in-log'});
      });

      test('a secret concatenated into a message', () {
        final sites = scan('''
void report(String nsec) {
  Log.error('secret=' + nsec);
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'nsec');
        expect(sites.single.how, 'secret-in-log');
      });

      test('a shortened private key', () {
        final member = ['sub', 'string'].join();
        final sites = scan('''
void report(String privateKey) {
  Log.error('key=\${privateKey.$member(0, 10)}');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'privateKey');
        expect(sites.single.how, 'secret-in-log');
      });

      test('secret words in prose are allowed', () {
        expect(
          scan("void report() { Log.info('nsec was omitted'); }"),
          isEmpty,
        );
      });

      test('a secret aliased through a local is still caught', () {
        // `final backup = nsec;` renames the value, and the rule only ever
        // sees the local's own name — so without alias tracking a one-line
        // assignment launders the secret straight past a security guard.
        final sites = scan(r'''
void report(String nsec) {
  final backup = nsec;
  Log.info('leaked $backup');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.identifier, 'nsec');
        expect(sites.single.how, 'secret-in-log');
      });

      test('predicate-named booleans are allowed, values are not', () {
        // `canExportLocalNsec` and `hasPrivateKey` are real booleans in this
        // repo (auth_service.dart), and logging one is the same non-value
        // status expression as `account.nsec != null`. Matching on a trailing
        // secret word alone failed CI on both. `clientNsec` has no predicate
        // prefix and is a value, so it must still fail.
        expect(
          scan(r'''
void report(bool canExportLocalNsec, bool hasPrivateKey, bool usesSigningKey) {
  Log.info('$canExportLocalNsec $hasPrivateKey $usesSigningKey');
}
'''),
          isEmpty,
        );

        final sites = scan(r'''
void report(String clientNsec, String privateKey) {
  Log.info('$clientNsec $privateKey');
}
''');
        expect(sites.map((s) => s.identifier), ['clientNsec', 'privateKey']);
      });

      test('a boolean secret-presence check is allowed', () {
        expect(
          scan(r'''
void report(Account account) {
  Log.info('has secret: ${account.nsec != null}');
}
'''),
          isEmpty,
        );
      });
    });

    group('recognises the sink', () {
      for (final (call, sink) in const [
        (r"Log.verbose('x: $p')", 'Log.verbose'),
        (r"Log.debug('x: $p')", 'Log.debug'),
        (r"Log.info('x: $p')", 'Log.info'),
        (r"Log.warning('x: $p')", 'Log.warning'),
        (r"Log.error('x: $p')", 'Log.error'),
        (r"developer.log('x: $p')", 'developer.log'),
        (r"log('x: $p')", 'log'),
        (r"print('x: $p')", 'print'),
        (r"debugPrint('x: $p')", 'debugPrint'),
        (r"_log.fine('x: $p')", '_log.fine'),
        (r"_log.severe('x: $p')", '_log.severe'),
        (r"logger.warning('x: $p')", 'logger.warning'),
      ]) {
        test(sink, () {
          final sites = scan('''
void report(String pubkey) {
  final p = pubkey.substring(0, 8);
  $call;
}
''');

          expect(sites, hasLength(1), reason: 'expected $sink to be a sink');
          expect(sites.single.sink, sink);
        });
      }

      test('a non-logging method call is not a sink', () {
        expect(
          scan(r'''
void report(String pubkey) {
  cache.store('x: ${pubkey.substring(0, 8)}');
}
'''),
          isEmpty,
        );
      });
    });
  });
}
