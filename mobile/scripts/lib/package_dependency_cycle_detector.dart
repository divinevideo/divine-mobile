// ABOUTME: Detects dependency cycles among Dart workspace packages.
// ABOUTME: Powers check_package_dependency_cycles.sh and its fixture tests.

import 'dart:io';

import 'package:yaml/yaml.dart';

/// Parses [pubspec], reporting the offending path rather than a raw cast error.
///
/// Throws a [FormatException] naming the file when it is empty, comment-only,
/// or not valid YAML, so callers can render their own diagnostic.
YamlMap _readPubspec(File pubspec) {
  Object? document;
  try {
    document = loadYaml(pubspec.readAsStringSync());
  } on YamlException catch (error) {
    throw FormatException('${pubspec.path}: ${error.message}');
  }
  if (document is! YamlMap) {
    throw FormatException('${pubspec.path}: expected a YAML map');
  }
  return document;
}

/// Returns the first dependency cycle under [packagesDirectory], if any.
///
/// Dependencies participate when their package name belongs to the workspace,
/// regardless of whether the pubspec uses path, shorthand, or version syntax.
/// The returned path repeats its first package at the end.
List<String>? findPackageDependencyCycle(Directory packagesDirectory) {
  final pubspecsByName = <String, File>{};

  final pubspecs =
      packagesDirectory
          .listSync()
          .whereType<Directory>()
          .map((directory) => File('${directory.path}/pubspec.yaml'))
          .where((file) => file.existsSync())
          .toList()
        ..sort((first, second) => first.path.compareTo(second.path));

  for (final pubspec in pubspecs) {
    final document = _readPubspec(pubspec);
    final name = document['name'];
    if (name is! String || name.isEmpty) {
      throw FormatException('${pubspec.path}: missing a "name:" value');
    }
    pubspecsByName[name] = pubspec;
  }

  final graph = <String, List<String>>{};
  for (final entry in pubspecsByName.entries) {
    final document = _readPubspec(entry.value);
    final dependencies = <String>{};
    final section = document['dependencies'];
    if (section is YamlMap) {
      for (final dependency in section.entries) {
        final dependencyName = dependency.key;
        if (dependencyName is String &&
            pubspecsByName.containsKey(dependencyName)) {
          dependencies.add(dependencyName);
        }
      }
    }
    graph[entry.key] = dependencies.toList()..sort();
  }

  final visited = <String>{};
  final active = <String>{};
  final path = <String>[];

  List<String>? visit(String package) {
    if (active.contains(package)) {
      final cycleStart = path.indexOf(package);
      return [...path.sublist(cycleStart), package];
    }
    if (!visited.add(package)) return null;

    active.add(package);
    path.add(package);
    for (final dependency in graph[package] ?? const <String>[]) {
      final cycle = visit(dependency);
      if (cycle != null) return cycle;
    }
    path.removeLast();
    active.remove(package);
    return null;
  }

  for (final package in graph.keys.toList()..sort()) {
    final cycle = visit(package);
    if (cycle != null) return cycle;
  }
  return null;
}

void main(List<String> arguments) {
  final packagesDirectory = Directory(
    arguments.isEmpty ? 'packages' : arguments.single,
  );
  if (!packagesDirectory.existsSync()) {
    stderr.writeln(
      'FAIL [package_dependency_cycles]: package directory not found: '
      '${packagesDirectory.path}',
    );
    exitCode = 2;
    return;
  }

  List<String>? cycle;
  try {
    cycle = findPackageDependencyCycle(packagesDirectory);
  } on FormatException catch (error) {
    stderr.writeln('FAIL [package_dependency_cycles]: ${error.message}');
    exitCode = 2;
    return;
  }
  if (cycle != null) {
    stderr.writeln('FAIL [package_dependency_cycles]: ${cycle.join(' -> ')}');
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'OK [package_dependency_cycles]: workspace package graph is acyclic.',
  );
}
