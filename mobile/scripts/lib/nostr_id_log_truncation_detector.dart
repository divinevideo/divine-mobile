// ABOUTME: Detector behind check_nostr_id_log_truncation.sh — finds Nostr
// ABOUTME: public IDs shortened or secret values disclosed in log/debug sinks.
//
// Usage (from mobile/):
//   dart run scripts/lib/nostr_id_log_truncation_detector.dart <scan-dir>... [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              one line per site instead of per-file counts
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// What counts
// -----------
// A site is either a public Nostr identifier that is shortened before reaching
// a logging sink, or a secret value that reaches one at all. Public identifiers
// retain diagnostic value only when whole. Secrets are credentials and must be
// omitted rather than logged whole or shortened. UI-only shortening is allowed.
//
//   Log.info('event ${event.id.substring(0, 8)}...')   COUNTED
//   Text(NostrKeyUtils.truncateNpub(pubkey))           not counted — UI sink
//   Log.info('event ${event.id}')                      not counted — public/full
//   Log.info('secret $nsec')                           COUNTED — secret disclosed
//
// Shortening shapes recognised — of the 19 sites #3372 closed, only ONE was the
// first shape, so the other two are the point rather than refinements:
//   • `<id>.substring(...)` / `<id>.characters.take(n)`. One site.
//   • a call to a SHORTENER — any function whose body substrings/takes one of
//     its own parameters — collected across the WHOLE scanned corpus, not just
//     the calling file. Thirteen sites (`_maskKey(npub)`). Corpus-wide because
//     `NostrKeyUtils.maskKey` and `StringUtils.formatIdForLogging` were both
//     public helpers documented for logging: the shortening and the log call
//     naturally live in different files.
//   • one hop through a local: `final p = id.substring(...)` then
//     `Log.debug('... $p')`. Five sites.
//
// One shape counts even though nothing is shortened: a WHOLE identifier
// followed by a literal ellipsis, `'event ${event.id}... '`. It reads as a cut
// id to anyone scanning a log — misreading exactly this produced #3372's
// `mobile/lib` evidence — and that issue's acceptance criterion names it
// ("prevents new event.id... / event.pubkey... patterns in logs"). Progress
// prose is unaffected, because `method` in `'Calling $method...'` is not an
// identifier name.
//
// Sinks recognised: `Log.<level>`, `developer.log` (qualified or bare — the
// SDK imports dart:developer unprefixed), `debugPrint`, `print`, and
// package:logging levels on a receiver named log/_log/logger/_logger.
//
// Why an AST and not a grep
// -------------------------
// A grep cannot separate the three cases above. `substring` and `...` are both
// overwhelmingly legitimate — the repo has ~60 substring call sites and every
// prose ellipsis ("Publishing Nostr event...") sits inside a real log line, so
// a text rule is either blind or all false positives. The signal is the PATH
// from a truncation to a log call, and a path is a tree property.
//
// Secret rule
// -----------
// Names such as nsec, ncryptsec, privateKey and signingKey are checked
// separately from public identifiers. Direct interpolation and shortening are
// rejected, as is a one-hop alias (`final backup = nsec;`), which otherwise
// launders the value past a rule that only sees the local's own name.
//
// What stays allowed is anything that discloses no key material: a status
// expression such as `account.nsec != null`, and equally a variable spelling
// of one — `canExportLocalNsec` and `hasPrivateKey` are both booleans in this
// repo. Matching finds a secret word at camelCase boundaries, so compound
// secrets (`rawPrivateKey`, `privateKeyHex`) are caught, with a
// predicate-prefix exclusion keeping the booleans out.
//
// Limits, stated plainly
// ----------------------
// The AST is UNRESOLVED (parseString, like its sibling detectors), so both
// "is this a Nostr identifier" and "is this a shortener" are decided by NAME —
// the first from [_identifierLexicon] below, the second by matching a call's
// method name against the collected set. So a value not named like an
// identifier is not seen, an unrelated function sharing a name with a
// shortener IS reported (measured: no such collision across 2351 files), and
// shortening reached through two hops of helper indirection is not seen. All
// three are deliberate — the guard exists to stop the shapes that actually
// recur, not to prove a theorem.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Names that mean "this value is a public Nostr identifier".
///
/// Matched against the whole identifier lowercased AND against its last
/// camelCase segment, so `eventId`, `giftWrapId` and `targetEventId` all reach
/// `id` without being enumerated. Grounded in the protocol vocabulary:
/// NIP-01 gives `id` / `pubkey` / `sig`, NIP-19 gives the bech32 prefixes,
/// NIP-42 gives the AUTH `challenge`, and the Blossom `x` tag carries
/// `sha256Hash`.
///
/// `hash` alone is intentionally absent: a blurhash is not an identifier, and
/// widening this set to catch one Blossom variable would flag it.
const _identifierLexicon = {
  'id',
  'ids',
  'eventid',
  'pubkey',
  'pubkeys',
  'pubkeyhex',
  'hexpubkey',
  'publickey',
  'npub',
  'note',
  'nevent',
  'naddr',
  'nprofile',
  'nrelay',
  'sig',
  'signature',
  'coordinate',
  'dtag',
  'challenge',
  'sha256hash',
  'blobhash',
};

/// Credential names that must never reach a diagnostic sink.
const _secretLexicon = {
  'nsec',
  'ncryptsec',
  'privatekey',
  'secretkey',
  'signingkey',
};

/// String members that shorten their receiver.
///
/// `take` only qualifies through a character view (see [_characterViews]).
/// `ids.take(3)` on a List is SAMPLING — it logs three whole identifiers, which
/// is exactly what this guard wants — so counting it would be backwards. Both
/// live examples in this repo are that shape.
const _shorteningMembers = {'substring', 'take'};

/// Views that turn a String into per-character elements, so a `take` over one
/// really does cut an identifier in half.
const _characterViews = {'characters', 'runes', 'codeUnits', 'split'};

/// `Log.<level>(...)` — the app-wide UnifiedLogger typedef.
const _unifiedLogLevels = {'verbose', 'debug', 'info', 'warning', 'error'};

/// Relay-diagnostics emitters. `diagnose`/`_diagnose` build a [RelayDiagnostic]
/// whose message nostr_client forwards to `UnifiedLogger`, so their message
/// argument reaches a support export exactly like a `Log.*` call. The string
/// literal lives at these call sites, not at the `Log.*` that later forwards
/// the opaque field, so the ratchet must read them here (#8930).
const _relayDiagnosticFunctions = {'diagnose', '_diagnose'};

/// package:logging levels, reached on a logger-shaped receiver.
const _loggingPackageLevels = {
  'finest',
  'finer',
  'fine',
  'config',
  'info',
  'warning',
  'severe',
  'shout',
  'log',
};

/// Receivers that are loggers rather than domain objects.
const _loggerReceivers = {'log', '_log', 'logger', '_logger', 'developer'};

/// Unqualified functions that write to a diagnostic sink.
const _bareLogFunctions = {'log', 'print', 'debugPrint'};

/// Cheap substrings that must appear in a file for it to hold a log sink.
///
/// DERIVED from the sink sets rather than written out, because a hand-written
/// prefilter silently un-guards whatever it forgets: an earlier draft listed
/// `log.` and so skipped every file logging through `logger.warning`, and the
/// only symptom was zero findings.
final _sinkTokens = <String>{
  'Log.',
  for (final r in _loggerReceivers) '$r.',
  for (final f in _bareLogFunctions) '$f(',
  for (final f in _relayDiagnosticFunctions) '$f(',
  'RelayDiagnostic(',
};

/// One forbidden Nostr value reaching a log sink.
class TruncationSite {
  TruncationSite({
    required this.path,
    required this.line,
    required this.identifier,
    required this.how,
    required this.sink,
  });

  final String path;
  final int line;

  /// The public identifier being shortened or secret being disclosed.
  final String identifier;

  /// The shortening operation, helper name, or `secret-in-log`.
  final String how;

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
      'usage: nostr_id_log_truncation_detector.dart <scan-dir>... '
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
      stdout.writeln(
        '${s.path}:${s.line}\t${s.identifier}\t${s.how}\t${s.sink}',
      );
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
///
/// The whole pipeline lives here — collect shorteners corpus-wide, then judge
/// each file against them — so `main` and the self-test exercise exactly the
/// same thing. Splitting them is how a prefilter once diverged from the sink
/// set it was supposed to mirror.
List<TruncationSite> findSitesUnder(
  List<Directory> dirs, {
  required String pathPrefix,
}) {
  // Shorteners are collected across every scanned root before any file is
  // judged, so a helper defined in one file and called inside a log in another
  // still counts. `StringUtils.formatIdForLogging` was exactly that shape.
  final shorteners = collectShorteners(dirs);
  final sites = <TruncationSite>[];
  for (final dir in dirs) {
    sites.addAll(
      findTruncationSites(dir, pathPrefix: pathPrefix, shorteners: shorteners),
    );
  }
  sites.sort((a, b) {
    final byPath = a.path.compareTo(b.path);
    return byPath != 0 ? byPath : a.line.compareTo(b.line);
  });
  return sites;
}

/// Hand-written Dart files under [dir], sorted, generated code excluded.
List<File> _dartFilesUnder(Directory dir) =>
    dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
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

/// Every function name in [dirs] whose body shortens one of its own parameters.
///
/// Collected corpus-wide, because the shortening and the log call do not have
/// to share a file: `NostrKeyUtils.maskKey` and `StringUtils.formatIdForLogging`
/// were both public helpers whose docs recommended them for logging. Matching
/// is by method name only — the unresolved AST has no types — so an unrelated
/// function that happens to share a name with a shortener is reported. That
/// trade is deliberate: the corpus currently yields no such collision, and a
/// name shared with a shortener is worth a look anyway.
Set<String> collectShorteners(List<Directory> dirs) {
  final names = <String>{};
  for (final dir in dirs) {
    for (final file in _dartFilesUnder(dir)) {
      final String source;
      try {
        source = file.readAsStringSync();
      } on Object {
        continue; // findTruncationSites reports this file again, with a reason.
      }
      if (!_shorteningMembers.any((m) => source.contains('$m('))) continue;
      try {
        final parsed = parseString(
          content: source,
          path: file.path,
          featureSet: FeatureSet.latestLanguageVersion(),
          throwIfDiagnostics: false,
        );
        names.addAll(
          (_ShortenerCollector()..visitCompilationUnit(parsed.unit)).names,
        );
      } on Object {
        continue;
      }
    }
  }
  return names;
}

/// Scans every non-generated Dart file under [dir], in path-then-line order.
List<TruncationSite> findTruncationSites(
  Directory dir, {
  required String pathPrefix,
  Set<String>? shorteners,
}) {
  final files = _dartFilesUnder(dir);

  final sites = <TruncationSite>[];
  for (final file in files) {
    final String source;
    try {
      source = file.readAsStringSync();
    } on Object catch (error) {
      // Never swallow this: an unreadable file drops its sites, which reads to
      // the ratchet as a file that was cleaned up.
      stderr.writeln(
        'nostr_id_log_truncation: unreadable ${file.path} ($error)',
      );
      continue;
    }
    // A site needs a shortening/secret trigger and a log sink in the same file.
    // prefilter drops ~2300 of the ~2350 files under lib/ and packages/*/lib.
    // Every rule this detector has must contribute a token here, or the file
    // is skipped before the AST sees it and the rule is silently dead. That
    // has now happened three times — the `logger.warning` sink, a cross-file
    // shortener whose caller contains no `substring(` of its own, and the
    // ellipsis-suffix rule — so the triggers are derived, never typed out.
    final triggers = <String>[
      for (final m in _shorteningMembers) '$m(',
      for (final n in shorteners ?? const <String>{}) '$n(',
      ..._ellipsisMarkers,
    ];
    final lowerSource = source.toLowerCase();
    final hasSecretToken = _secretLexicon.any(lowerSource.contains);
    if (!triggers.any(source.contains) && !hasSecretToken) continue;
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
      stderr.writeln('nostr_id_log_truncation: skipped ${file.path} ($error)');
      continue;
    }
    final relative = file.path.startsWith('$pathPrefix/')
        ? file.path.substring(pathPrefix.length + 1)
        : file.path;
    sites.addAll(
      findSitesInUnit(
        parsed.unit,
        parsed.lineInfo,
        path: relative,
        extraShorteners: shorteners,
      ),
    );
  }
  return sites;
}

/// Finds the sites in one already-parsed compilation unit.
List<TruncationSite> findSitesInUnit(
  CompilationUnit unit,
  LineInfo lineInfo, {
  required String path,
  Set<String>? extraShorteners,
}) {
  final local = _ShortenerCollector()..visitCompilationUnit(unit);
  final visitor = _SiteCollector(
    path: path,
    lineInfo: lineInfo,
    shorteners: {...local.names, ...?extraShorteners},
  );
  unit.accept(visitor);
  return visitor.sites;
}

/// Ellipsis spellings that read as "this value was cut".
const _ellipsisMarkers = ['...', '\u2026'];

/// True when [text] opens with one of [_ellipsisMarkers].
bool _startsWithEllipsis(String text) => _ellipsisMarkers.any(text.startsWith);

/// True when [name] reads as a Nostr identifier.
///
/// Matches the whole name lowercased, or its last camelCase segment, so
/// `eventId` / `giftWrapId` / `targetEventId` all reach `id`.
bool isIdentifierName(String name) {
  final bare = name.startsWith('_') ? name.substring(1) : name;
  if (bare.isEmpty) return false;
  if (_identifierLexicon.contains(bare.toLowerCase())) return true;
  // Last camelCase segment: index of the final uppercase run start. This is
  // what reaches `eventId` and `giftWrapId` without enumerating them.
  var cut = -1;
  for (var i = bare.length - 1; i > 0; i--) {
    final c = bare.codeUnitAt(i);
    if (c >= 0x41 && c <= 0x5A) {
      cut = i;
      break;
    }
  }
  if (cut <= 0) return false;
  return _identifierLexicon.contains(bare.substring(cut).toLowerCase());
}

/// Prefixes that make a name a PREDICATE rather than a value.
///
/// `canExportLocalNsec` and `hasPrivateKey` are both real booleans in this repo
/// (auth_service.dart:396 and its caller), and logging one is the "non-value
/// status expression" the secret rule explicitly means to allow — the same
/// thing `account.nsec != null` is, spelled as a variable. Without this, both
/// fail CI on correct code.
const _predicatePrefixes = {
  'allow',
  'allows',
  'can',
  'contains',
  'does',
  'has',
  'is',
  'must',
  'needs',
  'requires',
  'should',
  'supports',
  'use',
  'uses',
  'was',
  'will',
};

/// True when [name] names a credential rather than a public identifier.
///
/// A secret is routinely carried in a compound name (`rawPrivateKey`,
/// `privateKeyHex`). Match the full lexicon word at camelCase boundaries so
/// representation suffixes cannot hide it, without treating prose-like
/// substrings inside a single word as credentials.
bool isSecretName(String name) {
  if (_hasPredicatePrefix(name)) return false;
  final bare = name.startsWith('_') ? name.substring(1) : name;
  if (bare.isEmpty) return false;
  final lower = bare.toLowerCase();
  for (final secret in _secretLexicon) {
    var start = lower.indexOf(secret);
    while (start >= 0) {
      final end = start + secret.length;
      final startsAtBoundary = start == 0 || _isUppercaseAscii(bare, start);
      final endsAtBoundary = end == bare.length || _isUppercaseAscii(bare, end);
      if (startsAtBoundary && endsAtBoundary) return true;
      start = lower.indexOf(secret, start + 1);
    }
  }
  return false;
}

bool _isUppercaseAscii(String value, int index) {
  final codeUnit = value.codeUnitAt(index);
  return codeUnit >= 0x41 && codeUnit <= 0x5A;
}

/// True when [name] starts with a [_predicatePrefixes] word followed by an
/// uppercase letter — `hasPrivateKey` yes, `hashOfKey` no.
bool _hasPredicatePrefix(String name) {
  final bare = name.startsWith('_') ? name.substring(1) : name;
  for (final prefix in _predicatePrefixes) {
    if (bare.length <= prefix.length) continue;
    if (!bare.toLowerCase().startsWith(prefix)) continue;
    final next = bare.codeUnitAt(prefix.length);
    if (next >= 0x41 && next <= 0x5A) return true;
  }
  return false;
}

/// The identifier name an expression ultimately reads, or null.
///
/// `event.id` -> `id`; `_npub` -> `_npub`; `widget.video.pubkey` -> `pubkey`;
/// `event.id!` -> `id`. Returns the *written* name so reports quote source.
String? _rootIdentifierName(Expression? expr) {
  return switch (expr) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    PropertyAccess(:final propertyName) => propertyName.name,
    PostfixExpression(:final operand) => _rootIdentifierName(operand),
    ParenthesizedExpression(:final expression) => _rootIdentifierName(
      expression,
    ),
    _ => null,
  };
}

/// The identifier [node] shortens, or null when [node] is not a shortening.
///
/// Centralises the `take`-through-a-character-view rule so the shortener probe
/// and the site finder can never disagree about what counts.
String? shortenedRootName(MethodInvocation node) {
  final member = node.methodName.name;
  if (!_shorteningMembers.contains(member)) return null;
  final target = node.realTarget;
  if (member == 'substring') return _rootIdentifierName(target);

  final view = switch (target) {
    PropertyAccess(:final propertyName) => propertyName.name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    MethodInvocation(:final methodName) => methodName.name,
    _ => null,
  };
  if (view == null || !_characterViews.contains(view)) return null;
  final beneath = switch (target) {
    PropertyAccess(:final target) => target,
    PrefixedIdentifier(:final prefix) => prefix,
    MethodInvocation(:final realTarget) => realTarget,
    _ => null,
  };
  return _rootIdentifierName(beneath);
}

/// Collects functions in this unit that shorten one of their own parameters.
///
/// `_maskKey(String key) => '${key.substring(0, 8)}...'` registers `_maskKey`,
/// so `_log.fine('… ${_maskKey(_npub)}')` is seen as a truncation of `_npub`.
class _ShortenerCollector extends RecursiveAstVisitor<void> {
  final names = <String>{};

  void _record(String name, FormalParameterList? params, AstNode? body) {
    if (params == null || body == null) return;
    final paramNames = <String>{
      for (final p in params.parameters) ?p.name?.lexeme,
    };
    if (paramNames.isEmpty) return;
    final probe = _ShorteningProbe(paramNames);
    body.accept(probe);
    if (probe.found) names.add(name);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _record(node.name.lexeme, node.parameters, node.body);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _record(
      node.name.lexeme,
      node.functionExpression.parameters,
      node.functionExpression.body,
    );
    super.visitFunctionDeclaration(node);
  }
}

/// True once it sees `<oneOfThese>.substring(...)` / `.take(...)`.
class _ShorteningProbe extends RecursiveAstVisitor<void> {
  _ShorteningProbe(this._params);

  final Set<String> _params;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final root = shortenedRootName(node);
    if (root != null && _params.contains(root)) found = true;
    super.visitMethodInvocation(node);
  }
}

/// Walks a unit and records every shortened identifier reaching a log sink.
class _SiteCollector extends RecursiveAstVisitor<void> {
  _SiteCollector({
    required this.path,
    required this.lineInfo,
    required this.shorteners,
  });

  final String path;
  final LineInfo lineInfo;
  final Set<String> shorteners;
  final sites = <TruncationSite>[];

  /// Source offsets already reported, so a log call nested inside another
  /// log call's arguments is not counted twice.
  final _seen = <int>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final sink = _logSinkName(node);
    if (sink != null) _scanLogCall(node, sink);
    // A `parseString` AST is unresolved, so an unprefixed `RelayDiagnostic(...)`
    // is a MethodInvocation, not an InstanceCreationExpression (only const/new
    // forms are the latter). Emit-site messages interpolate ids so they are
    // never const — this shape is the one that reaches the export.
    if (node.realTarget == null && node.methodName.name == 'RelayDiagnostic') {
      _scanRelayDiagnostic(node.argumentList, node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // The const/new form of the same sink; see visitMethodInvocation.
    if (node.constructorName.type.name.lexeme == 'RelayDiagnostic') {
      _scanRelayDiagnostic(node.argumentList, node);
    }
    super.visitInstanceCreationExpression(node);
  }

  /// `RelayDiagnostic(message: ...)` forwards its message to UnifiedLogger via
  /// nostr_client, so the message is an export sink. The string literal lives
  /// here at the constructor, not at the Log.* call that later forwards an
  /// opaque field, so the ratchet is blind to it unless read here.
  void _scanRelayDiagnostic(ArgumentList args, AstNode scopeNode) {
    for (final argument in args.arguments) {
      if (argument is NamedExpression &&
          argument.name.label.name == 'message') {
        _scan(argument.expression, scopeNode, 'RelayDiagnostic.message');
      }
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

  void _scanLogCall(MethodInvocation call, String sink) =>
      _scan(call.argumentList, call, sink);

  void _scan(AstNode toScan, AstNode scopeNode, String sink) {
    final locals = _shortenedLocalsVisibleAt(scopeNode);
    final finder = _ShorteningFinder(shorteners: shorteners, locals: locals);
    toScan.accept(finder);
    for (final hit in finder.hits) {
      if (!_seen.add(hit.offset)) continue;
      sites.add(
        TruncationSite(
          path: path,
          line: lineInfo.getLocation(hit.offset).lineNumber,
          identifier: hit.identifier,
          how: hit.how,
          sink: sink,
        ),
      );
    }
  }

  /// Locals declared in [node]'s enclosing function body whose initializer
  /// shortens a Nostr identifier — the `final preview = id.substring(0, 8)`
  /// hop that sits between the truncation and the log call.
  Map<String, _Hit> _shortenedLocalsVisibleAt(AstNode node) {
    AstNode? scope = node;
    while (scope != null && scope is! FunctionBody) {
      scope = scope.parent;
    }
    if (scope == null) return const {};
    final collector = _ShortenedLocalCollector(
      shorteners,
      useSite: node,
    );
    scope.accept(collector);
    return collector.locals;
  }
}

/// A shortened identifier found inside a log call's arguments.
class _Hit {
  const _Hit({
    required this.offset,
    required this.identifier,
    required this.how,
  });

  final int offset;
  final String identifier;
  final String how;
}

/// Records locals whose initializer shortens a Nostr identifier.
class _ShortenedLocalCollector extends RecursiveAstVisitor<void> {
  _ShortenedLocalCollector(this._shorteners, {required this.useSite});

  final Set<String> _shorteners;
  final AstNode useSite;
  final locals = <String, _Hit>{};

  bool _isVisible(VariableDeclaration node) {
    if (node.offset >= useSite.offset) return false;
    AstNode? declarationScope = node.parent;
    while (declarationScope != null && declarationScope is! Block) {
      declarationScope = declarationScope.parent;
    }
    if (declarationScope == null) return true;
    AstNode? ancestor = useSite;
    while (ancestor != null) {
      if (identical(ancestor, declarationScope)) return true;
      ancestor = ancestor.parent;
    }
    return false;
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    // Every path falls through to super: a visitor that conditionally skips it
    // stops descending into the initializer, so anything nested there — a
    // closure with its own declarations — silently stops being collected. That
    // is invisible from outside, because a detector that looks at less just
    // reports fewer sites.
    if (_isVisible(node)) _record(node);
    super.visitVariableDeclaration(node);
  }

  void _record(VariableDeclaration node) {
    final initializer = node.initializer;
    // A secret aliased to a differently-named local and then logged —
    // `final backup = nsec;` — otherwise launders past the secret rule, which
    // only ever sees the local's own name. One hop only; see the header.
    final aliased = _rootIdentifierName(initializer);
    if (aliased != null && isSecretName(aliased)) {
      locals[node.name.lexeme] = _Hit(
        offset: node.offset,
        identifier: aliased,
        how: 'secret-in-log',
      );
      return;
    }
    if (initializer != null) {
      // Probe the whole initializer: the shortening is often inside a
      // conditional guard, e.g. `x.length > 8 ? x.substring(0, 8) : x`.
      final finder = _ShorteningFinder(
        shorteners: _shorteners,
        locals: const {},
      );
      initializer.accept(finder);
      if (finder.hits.isNotEmpty) {
        final first = finder.hits.first;
        locals[node.name.lexeme] = _Hit(
          offset: node.offset,
          identifier: first.identifier,
          how: first.how,
        );
      } else {
        // A nearer declaration shadows an outer shortened local of this name.
        locals.remove(node.name.lexeme);
      }
    } else {
      locals.remove(node.name.lexeme);
    }
  }
}

/// Finds forbidden public-ID shortening and secret disclosure in a subtree.
class _ShorteningFinder extends RecursiveAstVisitor<void> {
  _ShorteningFinder({required this.shorteners, required this.locals});

  final Set<String> shorteners;
  final Map<String, _Hit> locals;
  final hits = <_Hit>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final member = node.methodName.name;
    final shortened = shortenedRootName(node);
    if (shortened != null) {
      if (isSecretName(shortened)) {
        hits.add(
          _Hit(
            offset: node.offset,
            identifier: shortened,
            how: 'secret-in-log',
          ),
        );
      } else if (isIdentifierName(shortened)) {
        hits.add(_Hit(offset: node.offset, identifier: shortened, how: member));
      }
    } else if (shorteners.contains(member)) {
      for (final arg in node.argumentList.arguments) {
        final value = arg is NamedExpression ? arg.expression : arg;
        final root = _rootIdentifierName(value);
        if (root != null && isIdentifierName(root)) {
          hits.add(_Hit(offset: node.offset, identifier: root, how: member));
          break;
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    // `'event ${event.id}... '` — the value is WHOLE and the dots are three
    // literal characters. Nothing is shortened, but the line reads as a cut
    // identifier to anyone scanning a log, and misreading exactly this is what
    // produced #3372's `mobile/lib` evidence. That issue's own acceptance
    // criterion names this shape: "prevents new event.id... / event.pubkey...
    // patterns in logs".
    final elements = node.elements;
    for (var i = 0; i < elements.length - 1; i++) {
      final expr = elements[i];
      final next = elements[i + 1];
      if (expr is! InterpolationExpression || next is! InterpolationString) {
        continue;
      }
      if (!_startsWithEllipsis(next.value)) continue;
      final root = _rootIdentifierName(expr.expression);
      if (root == null || !isIdentifierName(root)) continue;
      hits.add(
        _Hit(offset: expr.offset, identifier: root, how: 'ellipsis-suffix'),
      );
    }
    super.visitStringInterpolation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (isSecretName(node.name) && _isDirectLoggedValueReference(node)) {
      hits.add(
        _Hit(
          offset: node.offset,
          identifier: node.name,
          how: 'secret-in-log',
        ),
      );
    }
    // A reference to a local that was assigned a shortened identifier.
    final local = locals[node.name];
    if (local != null && _isDirectLoggedValueReference(node)) {
      hits.add(
        _Hit(offset: node.offset, identifier: local.identifier, how: local.how),
      );
    }
    super.visitSimpleIdentifier(node);
  }
}

bool _isDirectLoggedValueReference(SimpleIdentifier node) {
  AstNode current = node;
  while (true) {
    final parent = current.parent;
    switch (parent) {
      case InterpolationExpression(:final expression)
          when identical(expression, current):
        return true;
      case ArgumentList(:final arguments) when arguments.contains(current):
        return true;
      case final ParenthesizedExpression parent
          when identical(parent.expression, current):
        current = parent;
      case final PostfixExpression parent
          when identical(parent.operand, current):
        current = parent;
      case final BinaryExpression parent
          when parent.operator.lexeme == '+' &&
              (identical(parent.leftOperand, current) ||
                  identical(parent.rightOperand, current)):
        current = parent;
      case final PrefixedIdentifier parent
          when identical(parent.identifier, current):
        current = parent;
      case final PropertyAccess parent
          when identical(parent.propertyName, current):
        current = parent;
      default:
        return false;
    }
  }
}
