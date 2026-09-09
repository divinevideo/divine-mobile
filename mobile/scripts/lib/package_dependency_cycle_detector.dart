// ABOUTME: Detects dependency cycles among Dart workspace packages.
// ABOUTME: Powers check_package_dependency_cycles.sh and its fixture tests.

import 'dart:io';

import 'package:yaml/yaml.dart';

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
    final document = loadYaml(pubspec.readAsStringSync()) as YamlMap;
    final name = document['name'] as String;
    pubspecsByName[name] = pubspec;
  }

  final graph = <String, List<String>>{};
  for (final entry in pubspecsByName.entries) {
    final document = loadYaml(entry.value.readAsStringSync()) as YamlMap;
    final dependencies = <String>{};
    for (final sectionName in const ['dependencies', 'dev_dependencies']) {
      final section = document[sectionName];
      if (section is! YamlMap) continue;
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

  final cycle = findPackageDependencyCycle(packagesDirectory);
  if (cycle != null) {
    stderr.writeln('FAIL [package_dependency_cycles]: ${cycle.join(' -> ')}');
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'OK [package_dependency_cycles]: workspace package graph is acyclic.',
  );
}
