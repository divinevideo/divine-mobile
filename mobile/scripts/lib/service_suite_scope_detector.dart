// ABOUTME: Verifies focused service suites remain inside their declared CI scopes.
// ABOUTME: Walks every local Dart import, export, part, and conditional branch.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'service_suite_workflow_parser.dart';

class ScopeDriftException implements Exception {
  const ScopeDriftException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ServiceSuiteScopeResult {
  const ServiceSuiteScopeResult({required this.files, required this.importers});
  final Set<String> files;
  final Map<String, String> importers;
}

ServiceSuiteScopeResult detectServiceSuiteScope({
  required String repoRoot,
  required String workflowPath,
  required String scopeScriptPath,
}) {
  final root = p.normalize(p.absolute(repoRoot));
  final mobileRoot = p.join(root, 'mobile');
  final arrays = _readWorkflow(workflowPath);
  final focusedSuites = arrays['focused_suites'];
  if (focusedSuites == null || focusedSuites.isEmpty) {
    throw const ScopeDriftException(
      'workflow focused_suites array is missing or empty',
    );
  }
  final scopes = _readScopes(scopeScriptPath);
  final focusedMatchers = scopes.focused.map(_bashCaseMatcher).toList();
  final sharedMatchers = scopes.shared.map(_bashCaseMatcher).toList();
  final packageRoots = _workspacePackages(mobileRoot);

  final queue = <String>[];
  final importers = <String, String>{};
  for (final suite in focusedSuites) {
    final path = p.normalize(p.join(mobileRoot, suite));
    _requireInside(root, path, 'focused suite $suite');
    if (!File(path).existsSync()) {
      throw ScopeDriftException('focused suite does not exist: mobile/$suite');
    }
    queue.add(path);
  }

  final visited = <String>{};
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!visited.add(file)) continue;
    final source = _readFile(file, root);
    final parsed = parseString(
      content: source,
      path: file,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    final errors = parsed.errors
        .where(
          (error) => error.diagnosticCode.severity == DiagnosticSeverity.ERROR,
        )
        .toList();
    if (errors.isNotEmpty) {
      throw ScopeDriftException(
        'Dart parse failed for ${_relative(root, file)}: ${errors.first.message}',
      );
    }

    for (final reference in _references(parsed.unit)) {
      final target = _resolveReference(
        reference,
        importer: file,
        repoRoot: root,
        packageRoots: packageRoots,
      );
      if (target == null) continue;
      if (!File(target).existsSync()) {
        throw ScopeDriftException(
          '${_relative(root, file)} references missing local file '
          '${_relative(root, target)}',
        );
      }
      importers.putIfAbsent(target, () => file);
      queue.add(target);
    }
  }

  final uncovered = <String>[];
  // Either selector arm sets focused=true, including for local path packages.
  final matchers = [...focusedMatchers, ...sharedMatchers];
  for (final file in visited) {
    final relative = _relative(root, file);
    if (!matchers.any((matcher) => matcher.hasMatch(relative))) {
      final parent = importers[file];
      uncovered.add(
        parent == null
            ? relative
            : '$relative (imported by ${_relative(root, parent)})',
      );
    }
  }

  final stale = <String>[];
  final paths = visited.map((file) => _relative(root, file)).toList();
  for (var index = 0; index < scopes.focused.length; index++) {
    if (!paths.any(focusedMatchers[index].hasMatch)) {
      stale.add(scopes.focused[index]);
    }
  }

  if (uncovered.isNotEmpty || stale.isNotEmpty) {
    final message = StringBuffer('service-suite dependency scope drifted');
    if (uncovered.isNotEmpty) {
      message.writeln('\nuncovered dependency paths:');
      for (final path in uncovered..sort()) {
        message.writeln('  $path');
      }
    }
    if (stale.isNotEmpty) {
      message.writeln('\nstale focused scope patterns:');
      for (final pattern in stale..sort()) {
        message.writeln('  $pattern');
      }
    }
    throw ScopeDriftException(message.toString().trimRight());
  }
  return ServiceSuiteScopeResult(files: visited, importers: importers);
}

Map<String, List<String>> _readWorkflow(String path) {
  try {
    return parseServiceSuiteWorkflow(File(path).readAsStringSync());
  } on FileSystemException catch (error) {
    throw ScopeDriftException('workflow read failed: ${error.message}');
  } on FormatException catch (error) {
    throw ScopeDriftException('workflow parse failed: ${error.message}');
  }
}

({List<String> focused, List<String> shared}) _readScopes(String path) {
  final source = _readFile(path, p.dirname(p.dirname(p.dirname(path))));
  List<String> extract(String name) {
    final start = RegExp(
      '^\\s*# $name'
      r'_SCOPE_START[^\n]*$',
      multiLine: true,
    );
    final end = RegExp(
      '^\\s*# $name'
      r'_SCOPE_END\s*$',
      multiLine: true,
    );
    final starts = start.allMatches(source).toList();
    final ends = end.allMatches(source).toList();
    if (starts.length != 1 ||
        ends.length != 1 ||
        starts.single.end >= ends.single.start) {
      throw ScopeDriftException(
        '$name scope must contain exactly one ordered marker pair',
      );
    }
    final block = source.substring(starts.single.end, ends.single.start);
    final normalized = block.replaceAll(RegExp(r'\\\s*\n'), '');
    final close = normalized.lastIndexOf(')');
    if (close < 0 || normalized.substring(close + 1).trim().isNotEmpty) {
      throw ScopeDriftException(
        '$name scope has an invalid case-pattern block',
      );
    }
    final patterns = normalized
        .substring(0, close)
        .split('|')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (patterns.isEmpty) {
      throw ScopeDriftException('$name scope must not be empty');
    }
    return patterns;
  }

  return (focused: extract('FOCUSED'), shared: extract('SHARED'));
}

Map<String, String> _workspacePackages(String mobileRoot) {
  final roots = <String, String>{};
  void addPackage(String directory) {
    final pubspec = File(p.join(directory, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      throw ScopeDriftException('missing pubspec: ${pubspec.path}');
    }
    Object? yaml;
    try {
      yaml = loadYaml(pubspec.readAsStringSync());
    } on Object catch (error) {
      throw ScopeDriftException('unreadable pubspec ${pubspec.path}: $error');
    }
    final name = yaml is YamlMap ? yaml['name'] : null;
    if (name is! String || name.isEmpty) {
      throw ScopeDriftException(
        'pubspec has no readable package name: ${pubspec.path}',
      );
    }
    if (roots.containsKey(name)) {
      throw ScopeDriftException('duplicate workspace package name: $name');
    }
    roots[name] = p.join(directory, 'lib');
  }

  addPackage(mobileRoot);
  final packages = Directory(p.join(mobileRoot, 'packages'));
  if (!packages.existsSync()) {
    throw ScopeDriftException(
      'workspace packages directory is missing: ${packages.path}',
    );
  }
  for (final entity in packages.listSync()) {
    if (entity is Directory) addPackage(entity.path);
  }

  // Path overrides can live elsewhere in the repo, outside the workspace list.
  final lockPath = p.join(mobileRoot, 'pubspec.lock');
  Object? lock;
  try {
    lock = loadYaml(File(lockPath).readAsStringSync());
  } on Object catch (error) {
    throw ScopeDriftException('unreadable lockfile $lockPath: $error');
  }
  final lockedPackages = lock is YamlMap ? lock['packages'] : null;
  if (lockedPackages is! YamlMap) {
    throw ScopeDriftException('lockfile has no package map: $lockPath');
  }
  for (final entry in lockedPackages.entries) {
    final package = entry.value;
    if (package is! YamlMap) {
      throw ScopeDriftException('invalid locked package: ${entry.key}');
    }
    if (package['source'] != 'path') continue;
    final description = package['description'];
    final path = description is YamlMap ? description['path'] : null;
    final relative = description is YamlMap ? description['relative'] : null;
    if (entry.key is! String ||
        path is! String ||
        path.isEmpty ||
        relative is! bool ||
        relative == p.isAbsolute(path)) {
      throw ScopeDriftException('invalid path package mapping: ${entry.key}');
    }
    final directory = p.normalize(
      relative ? p.join(mobileRoot, path) : path,
    );
    if (!p.isWithin(p.dirname(mobileRoot), directory)) continue;
    final lib = p.join(directory, 'lib');
    if (roots[entry.key] == lib) continue;
    addPackage(directory);
    if (roots[entry.key] != lib) {
      throw ScopeDriftException('path package name mismatch: ${entry.key}');
    }
  }
  return roots;
}

Iterable<String> _references(CompilationUnit unit) sync* {
  for (final directive in unit.directives) {
    if (directive is ImportDirective) {
      final value = directive.uri.stringValue;
      if (value != null) yield value;
      for (final configuration in directive.configurations) {
        final configured = configuration.uri.stringValue;
        if (configured != null) yield configured;
      }
    } else if (directive is ExportDirective) {
      final value = directive.uri.stringValue;
      if (value != null) yield value;
      for (final configuration in directive.configurations) {
        final configured = configuration.uri.stringValue;
        if (configured != null) yield configured;
      }
    } else if (directive is PartDirective) {
      final value = directive.uri.stringValue;
      if (value != null) yield value;
    }
  }
}

String? _resolveReference(
  String reference, {
  required String importer,
  required String repoRoot,
  required Map<String, String> packageRoots,
}) {
  final uri = Uri.tryParse(reference);
  if (uri == null || uri.hasQuery || uri.hasFragment) {
    throw ScopeDriftException(
      'invalid local URI in ${_relative(repoRoot, importer)}: $reference',
    );
  }
  if (uri.scheme == 'dart') return null;
  String? target;
  if (uri.scheme == 'package') {
    if (uri.pathSegments.length < 2) {
      throw ScopeDriftException(
        'invalid package URI in ${_relative(repoRoot, importer)}: $reference',
      );
    }
    final packageRoot = packageRoots[uri.pathSegments.first];
    if (packageRoot == null) return null;
    target = p.joinAll([packageRoot, ...uri.pathSegments.skip(1)]);
  } else if (uri.scheme.isEmpty &&
      !uri.hasAuthority &&
      !p.isAbsolute(reference)) {
    target = p.join(p.dirname(importer), uri.toFilePath());
  } else {
    throw ScopeDriftException(
      'unsupported local URI in ${_relative(repoRoot, importer)}: $reference',
    );
  }
  target = p.normalize(p.absolute(target));
  _requireInside(
    repoRoot,
    target,
    'URI $reference in ${_relative(repoRoot, importer)}',
  );
  return target;
}

RegExp _bashCaseMatcher(String pattern) {
  if (!RegExp(r'^[A-Za-z0-9_./*-]+$').hasMatch(pattern)) {
    throw ScopeDriftException('unsupported Bash case pattern: $pattern');
  }
  final escaped = pattern.split('*').map(RegExp.escape).join('.*');
  return RegExp('^$escaped\$');
}

String _readFile(String path, String root) {
  try {
    return File(path).readAsStringSync();
  } on FileSystemException catch (error) {
    throw ScopeDriftException(
      'could not read ${_relative(root, path)}: ${error.message}',
    );
  }
}

void _requireInside(String root, String path, String description) {
  if (path != root && !p.isWithin(root, path)) {
    throw ScopeDriftException('$description escapes the repository: $path');
  }
}

String _relative(String root, String path) => p.posix.normalize(
  p.relative(path, from: root).split(p.separator).join('/'),
);

void main(List<String> arguments) {
  var detail = false;
  var repoRoot = p.dirname(Directory.current.absolute.path);
  String? workflow;
  String? scopeScript;
  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--detail':
        detail = true;
      case '--repo-root':
        if (++index >= arguments.length) _usage();
        repoRoot = arguments[index];
      case '--workflow':
        if (++index >= arguments.length) _usage();
        workflow = arguments[index];
      case '--scope-script':
        if (++index >= arguments.length) _usage();
        scopeScript = arguments[index];
      default:
        _usage('unknown argument: ${arguments[index]}');
    }
  }
  workflow ??= p.join(
    repoRoot,
    '.github',
    'workflows',
    'mobile_service_integration_tests.yaml',
  );
  scopeScript ??= p.join(
    repoRoot,
    'mobile',
    'scripts',
    'ci',
    'detect_service_suite_scope.sh',
  );
  try {
    final result = detectServiceSuiteScope(
      repoRoot: repoRoot,
      workflowPath: workflow,
      scopeScriptPath: scopeScript,
    );
    if (detail) {
      final paths =
          result.files
              .map((file) => _relative(p.absolute(repoRoot), file))
              .toList()
            ..sort();
      paths.forEach(stdout.writeln);
    }
    stdout.writeln(
      'OK: focused service-suite dependency scopes cover ${result.files.length} files.',
    );
  } on ScopeDriftException catch (error) {
    stderr.writeln('FAIL [service_suite_scope]: ${error.message}');
    exitCode = 1;
  }
}

Never _usage([String? message]) {
  if (message != null) stderr.writeln(message);
  stderr.writeln(
    'usage: dart run service_suite_scope_detector.dart [--detail] '
    '[--repo-root <path>] [--workflow <path>] [--scope-script <path>]',
  );
  exit(64);
}
