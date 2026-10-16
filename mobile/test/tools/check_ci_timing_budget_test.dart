// ABOUTME: Tests the CI wall-clock budget guard used by the mobile-ci gate.
// ABOUTME: Pins warn/fail thresholds, prefix matching, and fail-closed cases.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Drives `scripts/ci/check_ci_timing_budget.py` against synthetic job
/// payloads.
///
/// The guard exists to stop measured CI wins eroding, so the properties that
/// matter are that it actually fails when a job blows its budget, and that it
/// never reports success when it could not really check (bad budget file or no
/// job data), while surfacing budgeted jobs that are absent from the run.
void main() {
  group('check_ci_timing_budget.py', () {
    late Directory sandbox;
    late String repoRoot;
    late String scriptPath;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('ci_timing_budget_');
      repoRoot = repositoryRoot();
      scriptPath = p.join(
        repoRoot,
        'mobile',
        'scripts',
        'ci',
        'check_ci_timing_budget.py',
      );
      expect(
        File(scriptPath).existsSync(),
        isTrue,
        reason: 'scripts/ci/check_ci_timing_budget.py must exist',
      );
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    String writeJson(String name, Object value) {
      final file = File(p.join(sandbox.path, name))
        ..writeAsStringSync(jsonEncode(value));
      return file.path;
    }

    /// A job that started at 00:00:00Z and ran for [seconds].
    Map<String, Object?> job(
      String name,
      int seconds, {
      String? conclusion,
      String? startedAt,
      String? completedAt,
    }) {
      final minutes = seconds ~/ 60;
      final remainder = seconds % 60;
      return {
        'name': name,
        'conclusion': conclusion ?? 'success',
        'started_at': startedAt ?? '2026-07-25T00:00:00Z',
        'completed_at':
            completedAt ??
            '2026-07-25T00:${minutes.toString().padLeft(2, '0')}:'
                '${remainder.toString().padLeft(2, '0')}Z',
      };
    }

    ProcessResult run({
      required Object budgets,
      required List<Map<String, Object?>> jobs,
    }) {
      return Process.runSync('python3', [
        scriptPath,
        '--budgets',
        writeJson('budgets.json', budgets),
        '--jobs-json',
        writeJson('jobs.json', {'jobs': jobs}),
      ]);
    }

    const oneBudget = {
      'jobs': {
        'Tests': {'warn': 100, 'fail': 200},
      },
    };

    test('passes when a budgeted job is inside its warn threshold', () {
      final result = run(budgets: oneBudget, jobs: [job('Tests', 90)]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, isNot(contains('::warning')));
      expect(result.stdout, isNot(contains('::error')));
    });

    test('warns but still passes between warn and fail', () {
      final result = run(budgets: oneBudget, jobs: [job('Tests', 150)]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('::warning'));
      expect(result.stdout, contains('150s'));
    });

    test('fails once a job is over its fail threshold', () {
      final result = run(budgets: oneBudget, jobs: [job('Tests', 250)]);

      expect(result.exitCode, 1);
      expect(result.stdout, contains('::error'));
      expect(result.stdout, contains('250s'));
    });

    test('handles GitHub timestamp offsets', () {
      final result = run(
        budgets: oneBudget,
        jobs: [
          job(
            'Tests',
            90,
            startedAt: '2026-07-25T00:00:00-07:00',
            completedAt: '2026-07-25T00:01:30-07:00',
          ),
        ],
      );

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('90'));
    });

    test('one budget key covers every leg of a matrix job', () {
      // 'Tests' must match 'Tests (shard N/4)' so sharding does not silently
      // drop the whole job out of the budget.
      final result = run(
        budgets: oneBudget,
        jobs: [job('Tests (shard 0/4)', 90), job('Tests (shard 1/4)', 250)],
      );

      expect(result.exitCode, 1);
      expect(result.stdout, contains('Tests (shard 1/4)'));
    });

    test('does not let a similarly named job absorb the budget', () {
      // 'TestsExtra' is a different job, not a leg of 'Tests'.
      final result = run(budgets: oneBudget, jobs: [job('TestsExtra', 250)]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('skipped or renamed'));
    });

    test('reports a budgeted job that did not run rather than passing it', () {
      final result = run(budgets: oneBudget, jobs: [job('Something Else', 10)]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('::notice'));
      expect(result.stdout, contains('Tests'));
    });

    test('ignores a failed run of a budgeted job', () {
      // A job that failed was cut short; its duration says nothing about speed.
      final result = run(
        budgets: oneBudget,
        jobs: [job('Tests', 250, conclusion: 'failure')],
      );

      expect(result.exitCode, 0);
      expect(result.stdout, isNot(contains('::error')));
    });

    test('exits 2 when the job payload is empty', () {
      final result = run(budgets: oneBudget, jobs: []);

      expect(result.exitCode, 2);
      expect(result.stdout, contains('cannot run'));
    });

    test('exits 2 when a budget has warn above fail', () {
      final result = run(
        budgets: {
          'jobs': {
            'Tests': {'warn': 300, 'fail': 100},
          },
        },
        jobs: [job('Tests', 50)],
      );

      expect(result.exitCode, 2);
      expect(result.stdout, contains('cannot run'));
    });

    test('exits 2 when a budget threshold is not numeric', () {
      final result = run(
        budgets: {
          'jobs': {
            'Tests': {'warn': '100', 'fail': 200},
          },
        },
        jobs: [job('Tests', 50)],
      );

      expect(result.exitCode, 2);
      expect(result.stdout, contains('cannot run'));
    });

    test('exits 2 when a successful job has no completed duration', () {
      final result = run(
        budgets: oneBudget,
        jobs: [
          {
            'name': 'Tests',
            'conclusion': 'success',
            'started_at': '2026-07-25T00:00:00Z',
            'completed_at': null,
          },
        ],
      );

      expect(result.exitCode, 2);
      expect(result.stdout, contains('cannot run'));
    });

    test('exits 2 when the budget file has no jobs', () {
      final result = run(
        budgets: {'jobs': <String, Object>{}},
        jobs: [job('Tests', 50)],
      );

      expect(result.exitCode, 2);
    });

    test(
      'the committed budget file is well formed and covers the gate jobs',
      () {
        final committed = File(
          p.join(repoRoot, '.github', 'ci-timing-budgets.json'),
        );
        expect(committed.existsSync(), isTrue);

        final decoded = jsonDecode(committed.readAsStringSync());
        expect(decoded, isA<Map<String, dynamic>>());
        final jobs = (decoded as Map<String, dynamic>)['jobs'];
        expect(jobs, isA<Map<String, dynamic>>());
        final budgetJobs = jobs as Map<String, dynamic>;

        final gateJobs = mobileCiGateJobNames();
        expect(gateJobs, isNotEmpty);

        for (final name in gateJobs) {
          final budgetName = budgetNameForGateJob(
            jobName: name,
            budgetNames: budgetJobs.keys,
          );
          expect(
            budgetName,
            isNotNull,
            reason: '$name has no timing budget',
          );
          final entry = budgetJobs[budgetName] as Map<String, dynamic>;
          expect(
            (entry['warn'] as num) < (entry['fail'] as num),
            isTrue,
            reason: '$name has warn >= fail',
          );
        }
      },
    );

    test('the committed budget file budgets only jobs the gate waits on', () {
      // A budget for a removed or renamed job never matches again; the gate
      // only lists it as unseen on every run, so nothing else flags it.
      final committed = File(
        p.join(repoRoot, '.github', 'ci-timing-budgets.json'),
      ).readAsStringSync();
      final budgetJobs =
          (jsonDecode(committed) as Map<String, dynamic>)['jobs']
              as Map<String, dynamic>;
      expect(budgetJobs, isNotEmpty);

      final gateJobs = mobileCiGateJobNames();
      for (final budgetName in budgetJobs.keys) {
        expect(
          gateJobs.any(
            (name) =>
                budgetNameForGateJob(
                  jobName: name,
                  budgetNames: [budgetName],
                ) !=
                null,
          ),
          isTrue,
          reason: '$budgetName budgets a job the Mobile CI gate does not need',
        );
      }
    });

    test('the committed budget still catches a slow rendered shard', () {
      // The gate reads job names from the GitHub API, where a matrix name is
      // already rendered ('Tests (shard 0/4)'). Keying the budget on the raw
      // template instead is self-consistent — budgetNameForGateJob matches it
      // exactly — but silently drops every shard out of enforcement at run
      // time, so the well-formedness test above cannot see it.
      final committed = File(
        p.join(repoRoot, '.github', 'ci-timing-budgets.json'),
      ).readAsStringSync();

      final result = Process.runSync('python3', [
        scriptPath,
        '--budgets',
        writeJson('committed.json', jsonDecode(committed) as Object),
        '--jobs-json',
        writeJson('shards.json', {
          'jobs': [job('Tests (shard 0/4)', 3000)],
        }),
      ]);

      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('Tests (shard 0/4)'));
    });

    test('budget file edits require app CI', () {
      final scopeDetector = File(
        p.join(
          repoRoot,
          'mobile',
          'scripts',
          'ci',
          'detect_mobile_ci_scope.sh',
        ),
      ).readAsStringSync();

      expect(scopeDetector, contains('.github/ci-timing-budgets.json)'));
    });
  });
}

String repositoryRoot() {
  final result = Process.runSync('git', [
    'rev-parse',
    '--show-toplevel',
  ], workingDirectory: Directory.current.path);
  expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  return (result.stdout as String).trim();
}

List<String> mobileCiGateJobNames() {
  final workflow = File(
    p.join(
      repositoryRoot(),
      '.github',
      'workflows',
      'mobile_ci.yaml',
    ),
  ).readAsLinesSync();
  final jobNamesById = <String, String>{};
  String? currentJobId;
  for (final line in workflow) {
    final jobMatch = RegExp(r'^  ([a-z0-9-]+):$').firstMatch(line);
    if (jobMatch != null) {
      currentJobId = jobMatch.group(1);
      continue;
    }
    final nameMatch = RegExp(r'^    name: (.+)$').firstMatch(line);
    if (currentJobId != null && nameMatch != null) {
      jobNamesById[currentJobId] = nameMatch.group(1)!;
    }
  }

  final needs = <String>[];
  var inMobileCi = false;
  var inNeeds = false;
  for (final line in workflow) {
    if (line == '  mobile-ci:') {
      inMobileCi = true;
      continue;
    }
    if (inMobileCi && RegExp(r'^  [a-z0-9-]+:$').hasMatch(line)) {
      break;
    }
    if (inMobileCi && line == '    needs:') {
      inNeeds = true;
      continue;
    }
    if (inNeeds) {
      final needMatch = RegExp(r'^      - ([a-z0-9-]+)$').firstMatch(line);
      if (needMatch == null) {
        break;
      }
      needs.add(needMatch.group(1)!);
    }
  }

  return [
    for (final need in needs) jobNamesById[need] ?? need,
  ];
}

String? budgetNameForGateJob({
  required String jobName,
  required Iterable<String> budgetNames,
}) {
  for (final budgetName in budgetNames) {
    if (jobName == budgetName || jobName.startsWith('$budgetName (')) {
      return budgetName;
    }
  }
  return null;
}
