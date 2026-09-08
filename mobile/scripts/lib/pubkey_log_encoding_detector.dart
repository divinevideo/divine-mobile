// ABOUTME: Detector behind check_pubkey_log_encoding.sh — finds pubkeys that
// ABOUTME: reach a log sink in one encoding instead of npub plus hex.
//
// Usage (from mobile/):
//   dart run scripts/lib/pubkey_log_encoding_detector.dart <scan-dir>... [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              one line per site instead of per-file counts
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// What counts
// -----------
// A pubkey-named value interpolated into a log sink without going through
// `pubkeyForLogs`. Hex is what greps against relay logs and backend rows; npub
// is what a person pastes into a client. A support log that carries only one of
// them answers "which account" in an encoding the reader cannot use, and #3372
// already established that half an identifier is worse than none.
//
//   Log.info('for $pubkey')                     COUNTED
//   Log.info('for ${pubkeyForLogs(pubkey)}')    not counted — both encodings
//   Log.info('for ${pubkeys.length} accounts')  not counted — a count
//   Log.info('bound=${pubkey != null}')         not counted — a boolean
//
// Naming decides what is a pubkey, matched on the LAST camelCase segment, so
// `userPubkey`, `authorPubkey`, `account.pubkeyHex` and `lastUsedNpub` are all
// reached without enumerating them. Plurals are excluded: `pubkeys` is a
// collection, and a collection needs `.map(pubkeyForLogs)` rather than a call.
//
// Only a plain value counts — an identifier, a property chain, or a call. An
// expression that has already reduced the pubkey to something else has no
// identifier left to encode, which is what keeps `.length`, `.isNotEmpty`,
// `.join(...)` and comparisons out: their last segment is the reducing member,
// not the pubkey. The one compound shape that IS unwrapped is `??`, whose left
// operand is still the pubkey — otherwise `${pubkey ?? ""}` would launder a
// bare hex past the guard.
//
// Sinks recognised: `Log.<level>`, `developer.log` (qualified or bare),
// `debugPrint`, `print`, and package:logging levels on a receiver named
// log/_log/logger/_logger. Deliberately the same set as
// nostr_id_log_truncation_detector.dart — a value that is a pubkey for one
// guard is a pubkey for the other, and two sink lists would drift.
//
// Why an AST and not a grep
// -------------------------
// Every one of these matches a text rule and none of them logs an identifier:
//
//   // TODO: log the pubkey                 a comment
//   Log.info('pubkey missing');             a string literal body
//   /// Renders [pubkey].                    a dartdoc reference
//   Log.info('${pubkeys.length} accounts');  a count that mentions one
//
// The signal is what a specific interpolation expression evaluates to inside a
// specific call, which is a tree property.
//
// Limits, stated plainly
// ----------------------
// The AST is UNRESOLVED (parseString, like its sibling detectors), so "is this
// a pubkey" is decided by NAME. A pubkey held in a variable named for its role
// rather than its type (`author`, `owner`) is not seen, and neither is one read
// out of a map (`json['pubkey']`) — that is an index expression, not a name.
// Both are deliberate: the guard exists to stop the shape that recurs, not to
// prove that no hex can ever reach a log.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// The formatter that renders both encodings. A call to it clears the site.
const kFormatter = 'pubkeyForLogs';

/// Names that mean "this value is one pubkey".
///
/// Matched against the whole name lowercased AND against its last camelCase
/// segment, so `userPubkey` reaches `pubkey` through the segment and
/// `account.pubkeyHex` reaches `pubkeyhex` through the whole name — the second
/// is why one rule is not enough, since that name's last segment is `hex`.
///
/// Singular only. `pubkeys` / `npubs` name a collection, which the formatter
/// cannot take, so flagging them would demand a rewrite the guard has no
/// opinion about.
const _pubkeyNames = {'pubkey', 'pubkeyhex', 'hexpubkey', 'npub'};

/// `Log.<level>` members that write to the unified logger.
const _unifiedLogLevels = {
  'verbose',
  'debug',
  'info',
  'warning',
  'error',
  'print',
  'log',
};

/// package:logging levels, reached through a logger-shaped receiver.
const _loggingPackageLevels = {
  'finest',
  'finer',
  'fine',
  'config',
  'info',
  'warning',
  'severe',
  'shout',
};

/// Receiver names that mean "this is a logger".
const _loggerReceivers = {'log', '_log', 'logger', '_logger'};

/// Log functions callable without a receiver.
const _bareLogFunctions = {'debugPrint', 'print', 'log'};

/// Relay-diagnostics emitters whose message nostr_client forwards to the
/// support export (#8930); their message argument is a log sink.
const _relayDiagnosticFunctions = {'diagnose', '_diagnose'};

/// Substrings that must appear in a file for it to hold a sink.
///
/// DERIVED from the sink sets rather than written out, so a sink added above
/// cannot be silently prefiltered away — the mistake that made three rules
/// dead in the sibling detector.
final _sinkTokens = <String>{
  'Log.',
  'developer.log',
  for (final f in _bareLogFunctions) '$f(',
  for (final r in _loggerReceivers) '$r.',
  for (final f in _relayDiagnosticFunctions) '$f(',
  'RelayDiagnostic(',
};

/// One pubkey reaching a log sink in a single encoding.
class PubkeyLogSite {
  const PubkeyLogSite({
    required this.path,
    required this.line,
    required this.expression,
    required this.sink,
  });

  /// Path relative to the configured prefix.
  final String path;

  /// 1-based line of the interpolation.
  final int line;

  /// The unencoded expression, as written.
  final String expression;

  /// The log call it reaches.
  final String sink;
}

void main(List<String> args) {
  final positional = <String>[];
  var pathPrefix = '';
  var detail = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--path-prefix':
        pathPrefix = i + 1 < args.length ? args[++i] : '';
      case '--detail':
        detail = true;
      default:
        positional.add(args[i]);
    }
  }
  if (positional.isEmpty) {
    stderr.writeln(
      'usage: pubkey_log_encoding_detector.dart <scan-dir>... '
      '[--path-prefix <dir>] [--detail]',
    );
    exit(2);
  }
  final dirs = <Directory>[];
  for (final p in positional) {
    final dir = Directory(p);
    if (!dir.existsSync()) {
      stderr.writeln('not a directory: $p');
      exit(2);
    }
    dirs.add(dir);
  }
  if (pathPrefix.isEmpty) pathPrefix = dirs.first.path;

  final sites = findSitesUnder(dirs, pathPrefix: pathPrefix);

  if (detail) {
    for (final s in sites) {
      stdout.writeln('${s.path}:${s.line}\t${s.expression}\t${s.sink}');
    }
    return;
  }
  final counts = <String, int>{};
  for (final s in sites) {
    counts[s.path] = (counts[s.path] ?? 0) + 1;
  }
  final paths = counts.keys.toList()..sort();
  for (final path in paths) {
    stdout.writeln('$path\t${counts[path]}');
  }
}

/// Scans [dirs] end to end and returns the sites in path-then-line order.
List<PubkeyLogSite> findSitesUnder(
  List<Directory> dirs, {
  required String pathPrefix,
}) {
  final sites = <PubkeyLogSite>[];
  for (final dir in dirs) {
    sites.addAll(findPubkeyLogSites(dir, pathPrefix: pathPrefix));
  }
  sites.sort((a, b) {
    final byPath = a.path.compareTo(b.path);
    return byPath != 0 ? byPath : a.line.compareTo(b.line);
  });
  return sites;
}

/// Hand-written production Dart files under [dir], sorted.
///
/// Test trees are out of scope: a test asserting on a log line is not a log a
/// support engineer reads, and pinning them would make every fixture carry an
/// encoder.
List<File> _dartFilesUnder(Directory dir) =>
    dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('/test/'))
        .where((f) => !f.path.contains('/integration_test/'))
        .where((f) => !f.path.contains('/l10n/generated/'))
        .where((f) => !f.path.contains('/.dart_tool/'))
        .where((f) => !f.path.contains('/build/'))
        .where(
          (f) => !const [
            '.g.dart',
            '.freezed.dart',
            '.gr.dart',
            '.config.dart',
            '.mocks.dart',
          ].any(f.path.endsWith),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Scans every non-generated production Dart file under [dir].
List<PubkeyLogSite> findPubkeyLogSites(
  Directory dir, {
  required String pathPrefix,
}) {
  final sites = <PubkeyLogSite>[];
  for (final file in _dartFilesUnder(dir)) {
    final String source;
    try {
      source = file.readAsStringSync();
    } on Object catch (error) {
      // Never swallow this: an unreadable file drops its sites, which reads to
      // the ratchet as a file that was cleaned up.
      stderr.writeln('pubkey_log_encoding: unreadable ${file.path} ($error)');
      continue;
    }
    final lowerSource = source.toLowerCase();
    if (!_pubkeyNames.any(lowerSource.contains)) continue;
    if (!_sinkTokens.any(source.contains)) continue;

    final ParseStringResult parsed;
    try {
      parsed = parseString(
        content: source,
        path: file.path,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
    } on Object catch (error) {
      stderr.writeln('pubkey_log_encoding: skipped ${file.path} ($error)');
      continue;
    }
    final relative = file.path.startsWith('$pathPrefix/')
        ? file.path.substring(pathPrefix.length + 1)
        : file.path;
    sites.addAll(
      findSitesInUnit(parsed.unit, parsed.lineInfo, path: relative),
    );
  }
  return sites;
}

/// Sites in one parsed unit, in line order. Exposed for the detector's test.
List<PubkeyLogSite> findSitesInUnit(
  CompilationUnit unit,
  LineInfo lineInfo, {
  required String path,
}) {
  final collector = _SiteCollector(path: path, lineInfo: lineInfo);
  unit.accept(collector);
  collector.sites.sort((a, b) => a.line.compareTo(b.line));
  return collector.sites;
}

/// Walks a unit and records every single-encoding pubkey reaching a log sink.
class _SiteCollector extends RecursiveAstVisitor<void> {
  _SiteCollector({required this.path, required this.lineInfo});

  final String path;
  final LineInfo lineInfo;
  final sites = <PubkeyLogSite>[];

  /// Offsets already reported, so a log call nested inside another log call's
  /// arguments is not counted twice.
  final _seen = <int>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final sink = _logSinkName(node);
    if (sink != null) _scan(node.argumentList, sink);
    // Unresolved parse: an unprefixed `RelayDiagnostic(...)` is a
    // MethodInvocation, and the diagnose/_diagnose helpers build it from a
    // message argument that reaches the export. Both are covered above via
    // `_logSinkName`; this catches a diagnostic built inline at a call site.
    if (node.realTarget == null && node.methodName.name == 'RelayDiagnostic') {
      _scanRelayDiagnostic(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'RelayDiagnostic') {
      _scanRelayDiagnostic(node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  void _scanRelayDiagnostic(ArgumentList args) {
    for (final argument in args.arguments) {
      if (argument is NamedExpression &&
          argument.name.label.name == 'message') {
        _scan(argument.expression, 'RelayDiagnostic.message');
      }
    }
  }

  void _scan(AstNode toScan, String sink) {
    final finder = _BarePubkeyFinder();
    toScan.accept(finder);
    for (final hit in finder.hits) {
      if (!_seen.add(hit.offset)) continue;
      sites.add(
        PubkeyLogSite(
          path: path,
          line: lineInfo.getLocation(hit.offset).lineNumber,
          expression: hit.expression,
          sink: sink,
        ),
      );
    }
  }

  /// The sink label for [node] if it writes to a diagnostic sink, else null.
  String? _logSinkName(MethodInvocation node) {
    final member = node.methodName.name;
    final target = node.realTarget;
    if (target == null) {
      if (_bareLogFunctions.contains(member) ||
          _relayDiagnosticFunctions.contains(member)) {
        return member;
      }
      return null;
    }
    final receiver = _rootIdentifierName(target);
    if (receiver == null) return null;
    if (receiver == 'Log' && _unifiedLogLevels.contains(member)) {
      return 'Log.$member';
    }
    if (receiver == 'developer' && member == 'log') return 'developer.log';
    if (_loggerReceivers.contains(receiver) &&
        _loggingPackageLevels.contains(member)) {
      return '$receiver.$member';
    }
    return null;
  }
}

/// One unencoded pubkey inside a log call's arguments.
class _Hit {
  const _Hit({required this.offset, required this.expression});

  final int offset;
  final String expression;
}

/// Finds interpolations that evaluate to one pubkey and are not encoded.
class _BarePubkeyFinder extends RecursiveAstVisitor<void> {
  final hits = <_Hit>[];

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    final expression = _unwrap(node.expression);
    if (_isFormatterCall(expression)) return;
    if (_namesOnePubkey(expression)) {
      hits.add(
        _Hit(offset: node.offset, expression: expression.toSource()),
      );
    }
    super.visitInterpolationExpression(node);
  }

  /// The pubkey-bearing side of `pubkey ?? fallback`, else [expression].
  ///
  /// `??` is the one compound shape worth unwrapping: its left operand is still
  /// the pubkey, so leaving it alone would let `${pubkey ?? ""}` past the guard
  /// while every other operator has genuinely consumed the identifier.
  Expression _unwrap(Expression expression) {
    if (expression is BinaryExpression && expression.operator.lexeme == '??') {
      return _unwrap(expression.leftOperand);
    }
    return expression;
  }

  bool _isFormatterCall(Expression expression) =>
      expression is MethodInvocation &&
      expression.methodName.name == kFormatter;

  /// Whether [expression] is a plain value whose name says "one pubkey".
  ///
  /// Plain means an identifier, a property chain, or a call — anything else has
  /// already reduced the pubkey to a count, a boolean or a joined string, and
  /// there is no identifier left to encode.
  bool _namesOnePubkey(Expression expression) {
    final name = _trailingName(expression);
    if (name == null) return false;
    final bare = name.startsWith('_') ? name.substring(1) : name;
    return _pubkeyNames.contains(bare.toLowerCase()) ||
        _pubkeyNames.contains(_lastSegment(name));
  }
}

/// The final member name of a plain value expression, else null.
String? _trailingName(Expression expression) {
  final target =
      expression is PostfixExpression && expression.operator.lexeme == '!'
      ? expression.operand
      : expression;
  return switch (target) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    PropertyAccess(:final propertyName) => propertyName.name,
    MethodInvocation(:final methodName) => methodName.name,
    _ => null,
  };
}

/// The last camelCase segment of [name], lowercased.
///
/// `userPubkey` and `account.pubkeyHex` both reduce to a lexicon word without
/// the lexicon having to enumerate every prefix anyone might use.
String _lastSegment(String name) {
  final trimmed = name.startsWith('_') ? name.substring(1) : name;
  final boundaries = <int>[0];
  for (var i = 1; i < trimmed.length; i++) {
    final c = trimmed[i];
    if (c == c.toUpperCase() && c != c.toLowerCase()) boundaries.add(i);
  }
  return trimmed.substring(boundaries.last).toLowerCase();
}

/// The leftmost identifier of a receiver chain, else null.
String? _rootIdentifierName(Expression expression) => switch (expression) {
  SimpleIdentifier(:final name) => name,
  PrefixedIdentifier(:final prefix) => prefix.name,
  PropertyAccess(:final target?) => _rootIdentifierName(target),
  MethodInvocation(:final target?) => _rootIdentifierName(target),
  _ => null,
};
