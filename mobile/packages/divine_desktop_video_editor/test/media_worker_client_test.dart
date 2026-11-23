import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:divine_desktop_video_editor/src/media_worker_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaWorkerClient', () {
    late Directory root;
    late MediaWorkerCommand command;
    late MediaWorkerClient client;
    late List<Directory> jobDirectories;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('media worker test ');
      var directory = Directory.current;
      while (!File('${directory.path}/.dart_tool/package_config.json')
          .existsSync()) {
        if (directory.parent.path == directory.path) {
          throw StateError('Workspace package configuration not found.');
        }
        directory = directory.parent;
      }
      final config = File('${directory.path}/.dart_tool/package_config.json');
      final json =
          jsonDecode(await config.readAsString()) as Map<String, dynamic>;
      final flutter = (json['packages'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .singleWhere((package) => package['name'] == 'flutter');
      final sdk = Directory.fromUri(
        config.uri.resolve(flutter['rootUri'] as String),
      ).parent.parent;
      command = MediaWorkerCommand(
        '${sdk.path}/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}',
        arguments: [File('test/fixtures/worker.dart').absolute.path],
      );
      jobDirectories = [];
      client = MediaWorkerClient(
        locate: () async => command,
        temporaryDirectory: () async => root,
        start: (command) async {
          jobDirectories.add(
            File(command.environment['GST_REGISTRY_1_0']!).parent,
          );
          return Process.start(
            command.executable,
            command.arguments,
            environment: command.environment,
          );
        },
      );
    });

    tearDown(() async {
      await client.dispose();
      if (root.existsSync()) await root.delete(recursive: true);
    });

    test(
      'keeps a completed artifact alive until its consumer finishes',
      () async {
        final entered = Completer<void>();
        final finish = Completer<void>();
        final result = client.execute(
          'render',
          {'text': 'synthetic'},
          taskId: 'render',
          consume: (output) async {
            final value = output.value! as Map<String, dynamic>;
            expect(value['echo'], 'synthetic');
            final file = File(value['path'] as String);
            expect(await file.readAsBytes(), [7, 8, 9]);
            entered.complete();
            await finish.future;
            expect(file.existsSync(), isTrue);
            return 'consumed';
          },
        );
        await entered.future;
        expect(jobDirectories.single.existsSync(), isTrue);
        finish.complete();
        expect(await result, 'consumed');
        expect(jobDirectories.single.existsSync(), isFalse);
      },
    );

    test('delivers native progress before completion', () async {
      final values = <double>[];
      final subscription = client.progress.listen((event) {
        expect(event.taskId, 'render');
        values.add(event.value);
      });
      await client.execute('render', {}, taskId: 'render', consume: (_) {});
      await subscription.cancel();
      expect(values, [0.25, 1.0]);
    });

    test('reports native exit without exposing stderr payloads', () async {
      await expectLater(
        client.execute('exit', {}, taskId: 'exit', consume: (_) {}),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'exit_7',
          ),
        ),
      );
      expect(jobDirectories.single.existsSync(), isFalse);
    });

    test('terminates malformed protocol before consuming a result', () async {
      await expectLater(
        client.execute(
          'malformed',
          {},
          taskId: 'bad',
          consume: (_) {
            fail('Malformed output reached the artifact consumer.');
          },
        ),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.toString(),
            'sanitized error',
            'MediaWorkerFailure(protocol)',
          ),
        ),
      );
      expect(jobDirectories.single.existsSync(), isFalse);
    });

    test('cancels a live child before releasing its files', () async {
      final ready = client.progress.first;
      final work = client.execute(
        'block',
        {},
        taskId: 'blocked',
        consume: (_) {
          fail('Cancelled output reached the artifact consumer.');
        },
      );
      final rejected = expectLater(
        work,
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'cancelled',
          ),
        ),
      );
      await ready;
      await client.cancel('blocked');
      await rejected;
      expect(jobDirectories.single.existsSync(), isFalse);
    });

    test(
      'rejects a result when the native process exits unsuccessfully',
      () async {
        await expectLater(
          client.execute(
            'result-then-exit',
            {},
            taskId: 'bad-exit',
            consume: (_) {
              fail('An unsuccessful native result reached its consumer.');
            },
          ),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.code,
              'code',
              'exit_9',
            ),
          ),
        );
        expect(jobDirectories.single.existsSync(), isFalse);
      },
    );

    test('snapshots queued arguments before the caller mutates them', () async {
      final ready = client.progress.first;
      final blocked = client.execute(
        'block',
        {},
        taskId: 'blocked',
        consume: (_) {},
      );
      final rejected = expectLater(blocked, throwsA(isA<MediaWorkerFailure>()));
      await ready;
      final args = <String, Object?>{'text': 'original'};
      final queued = client.execute(
        'render',
        args,
        taskId: 'next',
        consume: (output) {
          return (output.value! as Map<String, dynamic>)['echo'];
        },
      );
      args['text'] = 'changed';
      await client.cancel('blocked');
      await rejected;
      expect(await queued, 'original');
    });

    test(
      'cancels queued work without launching it or cancelling another task',
      () async {
        final ready = client.progress.first;
        final blocked = client.execute(
          'block',
          {},
          taskId: 'blocked',
          consume: (_) {},
        );
        final rejected = expectLater(
          blocked,
          throwsA(isA<MediaWorkerFailure>()),
        );
        await ready;
        final queued = client.execute(
          'render',
          {},
          taskId: 'next',
          consume: (_) {
            fail('A cancelled queued task was consumed.');
          },
        );
        final cancelled = expectLater(
          queued,
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.code,
              'code',
              'cancelled',
            ),
          ),
        );
        await client.cancel('next');
        await cancelled;
        expect(jobDirectories, hasLength(1));
        expect(jobDirectories.single.existsSync(), isTrue);
        final reused = client.execute(
          'render',
          {},
          taskId: 'next',
          consume: (_) => 42,
        );
        await client.cancel('blocked');
        await rejected;
        expect(await reused, 42);
        expect(jobDirectories, hasLength(2));
      },
    );

    test(
      'rejects a duplicate task without replacing its running owner',
      () async {
        final ready = client.progress.first;
        final blocked = client.execute(
          'block',
          {},
          taskId: 'blocked',
          consume: (_) {},
        );
        final rejected = expectLater(
          blocked,
          throwsA(isA<MediaWorkerFailure>()),
        );
        await ready;
        await expectLater(
          client.execute('render', {}, taskId: 'blocked', consume: (_) {}),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.code,
              'code',
              'duplicate_task',
            ),
          ),
        );
        await client.cancel('blocked');
        await rejected;
        expect(jobDirectories.single.existsSync(), isFalse);
      },
    );

    test('cancels during helper lookup without starting a child', () async {
      await client.dispose();
      final lookup = Completer<MediaWorkerCommand>();
      final entered = Completer<void>();
      client = MediaWorkerClient(
        locate: () {
          entered.complete();
          return lookup.future;
        },
        temporaryDirectory: () async => root.createTemp('unexpected '),
      );
      final work = client.execute(
        'render',
        {},
        taskId: 'lookup',
        consume: (_) {
          fail('Cancelled lookup started work.');
        },
      );
      final rejected = expectLater(
        work,
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'cancelled',
          ),
        ),
      );
      await entered.future;
      final cancelling = client.cancel('lookup');
      lookup.complete(command);
      await cancelling;
      await rejected;
      expect(await root.list().toList(), isEmpty);
    });

    test(
      'preserves a parent supplied while cancellation was pending',
      () async {
        await client.dispose();
        final allocated = Completer<Directory>();
        final entered = Completer<void>();
        client = MediaWorkerClient(
          locate: () async => command,
          temporaryDirectory: () {
            entered.complete();
            return allocated.future;
          },
        );
        final work = client.execute(
          'render',
          {},
          taskId: 'allocation',
          consume: (_) {},
        );
        final rejected = expectLater(work, throwsA(isA<MediaWorkerFailure>()));
        await entered.future;
        final cancelling = client.cancel('allocation');
        final directory = await root.createTemp('allocated ');
        allocated.complete(directory);
        await cancelling;
        await rejected;
        expect(directory.existsSync(), isTrue);
        expect(directory.listSync(), isEmpty);
      },
    );

    test(
      'lets an already consuming result commit before cancellation completes',
      () async {
        final entered = Completer<void>();
        final finish = Completer<void>();
        final work = client.execute(
          'render',
          {},
          taskId: 'commit',
          consume: (output) async {
            entered.complete();
            await finish.future;
            expect(output.directory.existsSync(), isTrue);
            return 123;
          },
        );
        await entered.future;
        var cancelled = false;
        final cancelling = client.cancel('commit').then((_) {
          cancelled = true;
        });
        await pumpEventQueue();
        expect(cancelled, isFalse);
        finish.complete();
        expect(await work, 123);
        await cancelling;
        expect(jobDirectories.single.existsSync(), isFalse);
      },
    );

    test(
      'disposal cancels a running child and prevents future submissions',
      () async {
        final ready = client.progress.first;
        final work = client.execute(
          'block',
          {},
          taskId: 'blocked',
          consume: (_) {},
        );
        final rejected = expectLater(work, throwsA(isA<MediaWorkerFailure>()));
        await ready;
        await client.dispose();
        await rejected;
        expect(jobDirectories.single.existsSync(), isFalse);
        await expectLater(
          client.execute('render', {}, taskId: 'late', consume: (_) {}),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.code,
              'code',
              'disposed',
            ),
          ),
        );
      },
    );

    test(
      'rejects requests that cannot be serialized before allocating files',
      () async {
        await expectLater(
          client.execute(
            'render',
            {'invalid': Object()},
            taskId: 'bad-request',
            consume: (_) {},
          ),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.code,
              'code',
              'request',
            ),
          ),
        );
        expect(jobDirectories, isEmpty);
      },
    );

    test('classifies a missing executable and removes its directory', () async {
      command = MediaWorkerCommand('${root.path}/missing-worker');
      await expectLater(
        client.execute('render', {}, taskId: 'missing', consume: (_) {}),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'launch',
          ),
        ),
      );
      expect(jobDirectories.single.existsSync(), isFalse);
    });

    test('classifies an unavailable temporary directory', () async {
      await client.dispose();
      client = MediaWorkerClient(
        locate: () async => command,
        temporaryDirectory: () async =>
            throw const FileSystemException('synthetic-private-payload'),
      );
      await expectLater(
        client.execute('render', {}, taskId: 'missing', consume: (_) {}),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.toString(),
            'sanitized error',
            'MediaWorkerFailure(storage)',
          ),
        ),
      );
    });

    test('preserves a classified native encoder failure', () async {
      await expectLater(
        client.execute(
          'native-error',
          {},
          taskId: 'encoder',
          consume: (_) {
            fail('An encoder failure reached the consumer.');
          },
        ),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'encoder',
          ),
        ),
      );
    });

    for (final method in [
      'invalid-progress',
      'unknown-event',
      'invalid-utf8',
      'oversized',
      'unterminated',
      'bad-version',
      'second-result',
    ]) {
      test('rejects malformed worker output ($method)', () async {
        await expectLater(
          client.execute(
            method,
            {},
            taskId: 'bad',
            consume: (_) {
              fail('Invalid protocol reached the consumer.');
            },
          ),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.code,
              'code',
              'protocol',
            ),
          ),
        );
        expect(jobDirectories.single.existsSync(), isFalse);
      });
    }

    test('cancels a process returned after its launch was cancelled', () async {
      await client.dispose();
      final launched = Completer<void>();
      final returned = Completer<void>();
      var exited = false;
      client = MediaWorkerClient(
        locate: () async => command,
        temporaryDirectory: () async => root,
        start: (command) async {
          final process = await Process.start(
            command.executable,
            command.arguments,
          );
          unawaited(
            process.exitCode.then((_) {
              exited = true;
            }),
          );
          launched.complete();
          await returned.future;
          return process;
        },
      );
      final work = client.execute(
        'render',
        {},
        taskId: 'launch',
        consume: (_) {},
      );
      final rejected = expectLater(
        work,
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'cancelled',
          ),
        ),
      );
      await launched.future;
      var released = false;
      final cancelling = client.cancel('launch').then((_) {
        released = true;
      });
      await pumpEventQueue();
      expect(released, isFalse);
      returned.complete();
      await cancelling;
      await rejected;
      expect(exited, isTrue);
      expect(await root.list().toList(), isEmpty);
    });

    test('claims the real child before sending a media request', () async {
      await client.dispose();
      final claiming = Completer<void>();
      final claimed = Completer<void>();
      var exited = false;
      client = MediaWorkerClient(
        locate: () async => command,
        temporaryDirectory: () async => root,
        start: (command) async {
          final process = await Process.start(
            command.executable,
            command.arguments,
          );
          unawaited(
            process.exitCode.then((_) {
              exited = true;
            }),
          );
          return process;
        },
        claimProcess: (pid) async {
          expect(pid, greaterThan(0));
          claiming.complete();
          await claimed.future;
        },
      );
      final progress = <double>[];
      final subscription = client.progress.listen((event) {
        progress.add(event.value);
      });
      final work = client.execute(
        'render',
        {},
        taskId: 'claim',
        consume: (_) {},
      );
      final rejected = expectLater(
        work,
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'cancelled',
          ),
        ),
      );
      await claiming.future;
      final cancelling = client.cancel('claim');
      claimed.complete();
      await cancelling;
      await rejected;
      await subscription.cancel();
      expect(progress, isEmpty);
      expect(exited, isTrue);
      expect(await root.list().toList(), isEmpty);
    });

    test(
      'classifies native ownership failure without exposing its message',
      () async {
        await client.dispose();
        client = MediaWorkerClient(
          locate: () async => command,
          temporaryDirectory: () async => root,
          claimProcess: (_) async =>
              throw StateError('synthetic-private-payload'),
        );
        await expectLater(
          client.execute('render', {}, taskId: 'claim', consume: (_) {}),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.toString(),
              'sanitized error',
              'MediaWorkerFailure(transport)',
            ),
          ),
        );
        expect(await root.list().toList(), isEmpty);
      },
    );

    test('does not report completion when temporary cleanup fails', () async {
      final values = <double>[];
      final subscription = client.progress.listen((event) {
        values.add(event.value);
      });
      await expectLater(
        client.execute(
          'render',
          {},
          taskId: 'cleanup',
          consume: (output) async {
            await output.directory.delete(recursive: true);
          },
        ),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'cleanup',
          ),
        ),
      );
      await subscription.cancel();
      expect(values, [0.25]);
    });

    test('terminates a child whose output stream cannot be read', () async {
      await client.dispose();
      client = MediaWorkerClient(
        locate: () async => command,
        temporaryDirectory: () async => root,
        start: (command) async => _BrokenOutputProcess(
          await Process.start(command.executable, command.arguments),
        ),
      );
      await expectLater(
        client.execute('render', {}, taskId: 'broken', consume: (_) {}),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'protocol',
          ),
        ),
      );
      expect(await root.list().toList(), isEmpty);
    });

    test(
      'classifies a diagnostics stream failure and releases the child',
      () async {
        await client.dispose();
        client = MediaWorkerClient(
          locate: () async => command,
          temporaryDirectory: () async => root,
          start: (command) async => _BrokenDiagnosticsProcess(
            await Process.start(command.executable, command.arguments),
          ),
        );
        await expectLater(
          client.execute('render', {}, taskId: 'broken', consume: (_) {}),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.code,
              'code',
              'transport',
            ),
          ),
        );
        expect(await root.list().toList(), isEmpty);
      },
    );

    test('confines the native plugin registry to the job directory', () async {
      final original = Platform.environment['GST_REGISTRY_1_0'];
      await client.execute(
        'render',
        {},
        taskId: 'registry',
        consume: (output) {
          final value = output.value! as Map<String, dynamic>;
          expect(
            value['registry'],
            '${output.directory.path}/gstreamer-registry.bin',
          );
          expect(value['registryFork'], 'no');
        },
      );
      expect(Platform.environment['GST_REGISTRY_1_0'], original);
      expect(command.environment, isEmpty);
    });

    test(
      'preserves the caller temp directory and its unrelated files',
      () async {
        await client.dispose();
        final neighbor = await File('${root.path}/keep.bin').writeAsBytes([42]);
        client = MediaWorkerClient(
          locate: () async => command,
          temporaryDirectory: () async => root,
        );
        await client.execute(
          'render',
          {},
          taskId: 'safe-cleanup',
          consume: (_) {},
        );
        expect(root.existsSync(), isTrue);
        expect(await neighbor.readAsBytes(), [42]);
        expect(root.listSync().map((file) => file.path), [neighbor.path]);
      },
    );

    test('cleans artifacts when their consumer rejects the result', () async {
      await expectLater(
        client.execute<void>(
          'render',
          {},
          taskId: 'bad-consumer',
          consume: (_) {
            throw const FormatException('consumer rejected artifact');
          },
        ),
        throwsFormatException,
      );
      expect(jobDirectories.single.existsSync(), isFalse);
    });
    test(
      'closes the parent input pipe when a native job is cancelled',
      () async {
        await client.dispose();
        late Process native;
        var inputClosed = false;
        client = MediaWorkerClient(
          locate: () async => command,
          temporaryDirectory: () async => root,
          start: (command) async {
            native = await Process.start(
              command.executable,
              command.arguments,
              environment: command.environment,
            );
            unawaited(
              native.stdin.done.then<void>(
                (_) {
                  inputClosed = true;
                },
                onError: (Object error, StackTrace stack) {
                  inputClosed = true;
                },
              ),
            );
            return native;
          },
        );
        final ready = client.progress.first;
        final work = client.execute(
          'block',
          {},
          taskId: 'pipes',
          consume: (_) {},
        );
        final rejected = expectLater(work, throwsA(isA<MediaWorkerFailure>()));
        await ready;
        await client.cancel('pipes');
        await rejected;
        try {
          expect(inputClosed, isTrue);
        } finally {
          await native.stdin.close().then<void>(
            (_) {},
            onError: (Object error) {},
          );
        }
      },
    );
    test(
      'acknowledges each consumed frame before its file can be reused',
      () async {
        final frames = <List<int>>[];
        final result = await client.execute(
          'events',
          {},
          taskId: 'frames',
          onEvent: (event) async {
            final value = event.value! as Map<String, dynamic>;
            expect(event.directory.existsSync(), isTrue);
            frames.add(await File(value['path'] as String).readAsBytes());
          },
          consume: (output) => output.value,
        );
        expect(result, 2);
        expect(frames, [
          [1, 2, 3],
          [2, 3, 4],
        ]);
        expect(root.listSync(), isEmpty);
      },
    );
    test(
      'does not release a streamed frame while its consumer is suspended',
      () async {
        final entered = Completer<MediaWorkerOutput>();
        final release = Completer<void>();
        final work = client.execute(
          'events',
          {},
          taskId: 'held-frame',
          onEvent: (event) async {
            entered.complete(event);
            await release.future;
          },
          consume: (_) {},
        );
        final rejected = expectLater(
          work,
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.code,
              'code',
              'cancelled',
            ),
          ),
        );
        final event = await entered.future;
        var cancelled = false;
        final cancelling = client.cancel('held-frame').then((_) {
          cancelled = true;
        });
        try {
          await pumpEventQueue();
          expect(cancelled, isFalse);
          expect(event.directory.existsSync(), isTrue);
          final frame = File(
            (event.value! as Map<String, dynamic>)['path'] as String,
          );
          expect(await frame.readAsBytes(), [1, 2, 3]);
        } finally {
          release.complete();
        }
        await cancelling;
        await rejected;
        expect(event.directory.existsSync(), isFalse);
      },
    );

    for (final (code, failConsumer) in <(String, void Function())>[
      (
        'protocol',
        () => throw const FormatException('synthetic-private-payload'),
      ),
      (
        'storage',
        () => throw const FileSystemException('synthetic-private-payload'),
      ),
      ('consumer', () => throw StateError('synthetic-private-payload')),
    ]) {
      test('releases a failed streamed-frame consumer ($code)', () async {
        await expectLater(
          client.execute(
            'events',
            {},
            taskId: 'bad-frame',
            onEvent: (_) => failConsumer(),
            consume: (_) {
              fail('A failed frame reached its final consumer.');
            },
          ),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.toString(),
              'sanitized error',
              'MediaWorkerFailure($code)',
            ),
          ),
        );
        expect(root.listSync(), isEmpty);
      });
    }

    test('rejects streamed data when no consumer was supplied', () async {
      await expectLater(
        client.execute('events', {}, taskId: 'no-consumer', consume: (_) {}),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'protocol',
          ),
        ),
      );
      expect(root.listSync(), isEmpty);
    });
    test(
      'classifies a failed input pipe and still retires its process',
      () async {
        await client.dispose();
        late Process native;
        client = MediaWorkerClient(
          locate: () async => command,
          temporaryDirectory: () async => root,
          start: (command) async {
            native = await Process.start(
              command.executable,
              command.arguments,
              environment: command.environment,
            );
            return _BrokenInputProcess(native);
          },
        );
        try {
          await expectLater(
            client.execute(
              'render',
              {},
              taskId: 'broken-input',
              consume: (_) {},
            ),
            throwsA(
              isA<MediaWorkerFailure>().having(
                (failure) => failure.toString(),
                'sanitized error',
                'MediaWorkerFailure(transport)',
              ),
            ),
          );
          expect(await native.exitCode, isNot(0));
          expect(root.listSync(), isEmpty);
        } finally {
          await native.stdin.close().then<void>(
            (_) {},
            onError: (Object error) {},
          );
        }
      },
    );
    test(
      'classifies rejected EOF without consuming an unacknowledged result',
      () async {
        await client.dispose();
        client = MediaWorkerClient(
          locate: () async => command,
          temporaryDirectory: () async => root,
          start: (command) async => _RejectedEofProcess(
            await Process.start(
              command.executable,
              command.arguments,
              environment: command.environment,
            ),
          ),
        );
        await expectLater(
          client.execute(
            'render',
            {},
            taskId: 'bad-eof',
            consume: (_) {
              fail('A failed EOF acknowledgement reached the result consumer.');
            },
          ),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.toString(),
              'sanitized error',
              'MediaWorkerFailure(transport)',
            ),
          ),
        );
        expect(root.listSync(), isEmpty);
      },
    );
  });
}

class _BrokenOutputProcess implements Process {
  _BrokenOutputProcess(this.process);
  final Process process;
  @override
  Future<int> get exitCode => process.exitCode;
  @override
  int get pid => process.pid;
  @override
  IOSink get stdin => process.stdin;
  @override
  Stream<List<int>> get stdout =>
      Stream.error(const FormatException('synthetic-private-payload'));
  @override
  Stream<List<int>> get stderr => process.stderr;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) =>
      process.kill(signal);
}

class _BrokenDiagnosticsProcess extends _BrokenOutputProcess {
  _BrokenDiagnosticsProcess(super.process);
  @override
  Stream<List<int>> get stdout => process.stdout;
  @override
  Stream<List<int>> get stderr =>
      Stream.error(const FormatException('synthetic-private-payload'));
}

class _BrokenInputProcess extends _BrokenOutputProcess {
  _BrokenInputProcess(super.process) {
    unawaited(_input.done.then<void>((_) {}, onError: (Object error) {}));
  }
  final _input = IOSink(_FailingPipeConsumer());
  @override
  IOSink get stdin => _input;
  @override
  Stream<List<int>> get stdout => process.stdout;
}

class _FailingPipeConsumer implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
    throw const FileSystemException('synthetic-private-payload');
  }

  @override
  Future<void> close() async {}
}

class _RejectedEofProcess extends _BrokenOutputProcess {
  _RejectedEofProcess(super.process) : _input = _RejectedEofSink(process.stdin);
  final IOSink _input;
  @override
  IOSink get stdin => _input;
  @override
  Stream<List<int>> get stdout => process.stdout;
}

class _RejectedEofSink implements IOSink {
  _RejectedEofSink(this.sink);
  final IOSink sink;
  @override
  Encoding get encoding => sink.encoding;
  @override
  set encoding(Encoding value) {
    sink.encoding = value;
  }

  @override
  Future<void> get done => sink.done;
  @override
  void add(List<int> data) => sink.add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      sink.addError(error, stackTrace);
  @override
  Future<void> addStream(Stream<List<int>> stream) => sink.addStream(stream);
  @override
  Future<void> flush() => sink.flush();
  @override
  Future<void> close() async {
    await sink.close();
    throw const FileSystemException('synthetic-private-payload');
  }

  @override
  void write(Object? value) => sink.write(value);
  @override
  void writeln([Object? value = '']) => sink.writeln(value);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      sink.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => sink.writeCharCode(charCode);
}
