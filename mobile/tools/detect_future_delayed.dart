// ABOUTME: Tool to detect and optionally replace Future.delayed usage
// ABOUTME: Provides suggestions for proper async patterns using AsyncUtils

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:openvine/utils/unified_logger.dart';

class FutureDelayedOccurrence {
  FutureDelayedOccurrence({
    required this.file,
    required this.line,
    required this.code,
    required this.suggestion,
  });
  final String file;
  final int line;
  final String code;
  final String suggestion;

  Map<String, dynamic> toJson() => {
    'file': file,
    'line': line,
    'code': code,
    'suggestion': suggestion,
  };
}

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('suggest', defaultsTo: true, help: 'Show replacement suggestions')
    ..addFlag('include-tests', defaultsTo: false, help: 'Include test files')
    ..addFlag('fix', defaultsTo: false, help: 'Automatically fix simple cases')
    ..addOption(
      'format',
      defaultsTo: 'text',
      allowed: ['text', 'json'],
      help: 'Output format',
    );

  final argResults = parser.parse(args);
  final paths = argResults.rest;

  if (paths.isEmpty) {
    Log.info(
      'Usage: dart detect_future_delayed.dart [options] <path>...',
      name: 'FutureDelayedDetector',
    );
    Log.info(parser.usage, name: 'FutureDelayedDetector');
    exit(1);
  }

  final occurrences = <FutureDelayedOccurrence>[];

  for (final pathArg in paths) {
    await _scanPath(pathArg, occurrences, argResults['include-tests']);
  }

  var fixed = false;
  if (argResults['fix'] && occurrences.isNotEmpty) {
    fixed = await _fixOccurrences(occurrences);
  }

  _reportResults(occurrences, argResults['format'], argResults['suggest']);

  // Exit with 0 if fixed successfully or no occurrences found
  exit(fixed || occurrences.isEmpty ? 0 : 1);
}

Future<void> _scanPath(
  String pathArg,
  List<FutureDelayedOccurrence> occurrences,
  bool includeTests,
) async {
  final entity = FileSystemEntity.typeSync(pathArg);

  if (entity == FileSystemEntityType.file) {
    await _scanFile(File(pathArg), occurrences, includeTests);
  } else if (entity == FileSystemEntityType.directory) {
    final dir = Directory(pathArg);
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        await _scanFile(entity, occurrences, includeTests);
      }
    }
  }
}

Future<void> _scanFile(
  File file,
  List<FutureDelayedOccurrence> occurrences,
  bool includeTests,
) async {
  // Skip test files unless explicitly included
  if (!includeTests && file.path.endsWith('_test.dart')) {
    return;
  }

  // Skip generated files
  if (file.path.endsWith('.g.dart') ||
      file.path.endsWith('.freezed.dart') ||
      file.path.endsWith('.mocks.dart')) {
    return;
  }

  final content = await file.readAsString();
  final lines = content.split('\n');

  // Regular expression to match Future.delayed
  final futureDelayedRegex = RegExp(r'Future\.delayed\s*\(');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (futureDelayedRegex.hasMatch(line)) {
      final occurrence = FutureDelayedOccurrence(
        file: path.relative(file.path),
        line: i + 1,
        code: line.trim(),
        suggestion: _getSuggestion(line, lines, i),
      );
      occurrences.add(occurrence);
    }
  }
}

String _getSuggestion(String line, List<String> lines, int lineIndex) {
  final code = line.trim();

  // Check for polling pattern (in a loop)
  if (_isInLoop(lines, lineIndex)) {
    return 'Use AsyncUtils.waitForCondition() for polling';
  }

  // Check for retry pattern
  if (_isRetryPattern(lines, lineIndex)) {
    return 'Use AsyncUtils.retry() with exponential backoff';
  }

  // Check for debounce/throttle pattern
  if (_isDebouncePattern(lines, lineIndex)) {
    return 'Use AsyncUtils.debounce() or AsyncUtils.throttle()';
  }

  // Check if it has a callback
  if (code.contains(',') && code.contains('=>') || code.contains('{')) {
    return 'Use Timer for callbacks or AsyncUtils.completeWithCallback()';
  }

  // Default suggestion for simple delays
  return 'Use Timer or platform callbacks instead of arbitrary delays';
}

bool _isInLoop(List<String> lines, int lineIndex) {
  // Look backwards for loop indicators
  for (var i = lineIndex - 1; i >= 0 && i > lineIndex - 10; i--) {
    final line = lines[i].trim();
    if (line.contains('while') || line.contains('for')) {
      return true;
    }
    if (line.contains('{')) {
      break;
    }
  }
  return false;
}

bool _isRetryPattern(List<String> lines, int lineIndex) {
  // Look for try-catch and retry indicators
  for (var i = lineIndex - 5; i <= lineIndex + 5 && i < lines.length; i++) {
    if (i < 0) continue;
    final line = lines[i].toLowerCase();
    if (line.contains('retry') ||
        line.contains('attempt') ||
        (line.contains('try') && line.contains('catch'))) {
      return true;
    }
  }
  return false;
}

bool _isDebouncePattern(List<String> lines, int lineIndex) {
  // Look for debounce/throttle indicators
  for (var i = lineIndex - 3; i <= lineIndex + 3 && i < lines.length; i++) {
    if (i < 0) continue;
    final line = lines[i].toLowerCase();
    if (line.contains('debounce') ||
        line.contains('throttle') ||
        line.contains('timer?.cancel')) {
      return true;
    }
  }
  return false;
}

Future<bool> _fixOccurrences(List<FutureDelayedOccurrence> occurrences) async {
  final fileGroups = <String, List<FutureDelayedOccurrence>>{};

  // Group occurrences by file
  for (final occurrence in occurrences) {
    fileGroups.putIfAbsent(occurrence.file, () => []).add(occurrence);
  }

  var fixedCount = 0;

  for (final entry in fileGroups.entries) {
    final file = File(entry.key);
    final fileOccurrences = entry.value;

    final content = await file.readAsString();
    final lines = content.split('\n');
    var modified = false;
    var needsTimerImport = !content.contains("import 'dart:async'");

    // Sort occurrences by line number in reverse order to avoid offset issues
    fileOccurrences.sort((a, b) => b.line.compareTo(a.line));

    for (final occurrence in fileOccurrences) {
      final lineIndex = occurrence.line - 1;
      final line = lines[lineIndex];

      // Simple delay without callback - replace with Timer
      if (!line.contains(',') ||
          (!line.contains('=>') && !line.contains('{'))) {
        final durationMatch = RegExp(r'Duration\s*\([^)]+\)').firstMatch(line);
        if (durationMatch != null) {
          final duration = durationMatch.group(0)!;
          final newLine = line.replaceFirst(
            RegExp(r'await\s+Future\.delayed\s*\([^)]+\)'),
            'await Future(() => Timer($duration, () {}))',
          );
          lines[lineIndex] = newLine;
          modified = true;
          fixedCount++;
          needsTimerImport = true;
        }
      }
    }

    if (modified) {
      // Add imports if needed
      if (needsTimerImport && !content.contains("import 'dart:async'")) {
        lines.insert(0, "import 'dart:async';");
      }

      await file.writeAsString(lines.join('\n'));
    }
  }

  Log.info(
    'Fixed $fixedCount occurrence${fixedCount == 1 ? '' : 's'}',
    name: 'FutureDelayedDetector',
  );
  return fixedCount > 0;
}

void _reportResults(
  List<FutureDelayedOccurrence> occurrences,
  String format,
  bool showSuggestions,
) {
  if (format == 'json') {
    Log.info(
      json.encode(occurrences.map((o) => o.toJson()).toList()),
      name: 'FutureDelayedDetector',
    );
    return;
  }

  if (occurrences.isEmpty) {
    Log.info(
      'No Future.delayed found in source files ✓',
      name: 'FutureDelayedDetector',
    );
    return;
  }

  Log.info('Future.delayed usage detected:', name: 'FutureDelayedDetector');
  Log.info('─' * 80, name: 'FutureDelayedDetector');

  final fileGroups = <String, List<FutureDelayedOccurrence>>{};
  for (final occurrence in occurrences) {
    fileGroups.putIfAbsent(occurrence.file, () => []).add(occurrence);
  }

  for (final entry in fileGroups.entries) {
    Log.info('\n${entry.key}:', name: 'FutureDelayedDetector');
    for (final occurrence in entry.value) {
      Log.info(
        '  Line ${occurrence.line}: ${occurrence.code}',
        name: 'FutureDelayedDetector',
      );
      if (showSuggestions) {
        Log.info(
          '    → ${occurrence.suggestion}',
          name: 'FutureDelayedDetector',
        );
      }
    }
  }

  Log.info('\n${'─' * 80}', name: 'FutureDelayedDetector');
  Log.info(
    'Total Future.delayed occurrences: ${occurrences.length}',
    name: 'FutureDelayedDetector',
  );
  Log.info(
    'Files affected: ${fileGroups.length}',
    name: 'FutureDelayedDetector',
  );
  Log.info(
    '\nConsider using AsyncUtils for proper async patterns.',
    name: 'FutureDelayedDetector',
  );
}
