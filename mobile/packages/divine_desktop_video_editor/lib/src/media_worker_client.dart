import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// An installed media helper and its fixed launch configuration.
class MediaWorkerCommand {
  /// Creates a command. Media requests are sent over stdin, never arguments.
  MediaWorkerCommand(
    this.executable, {
    List<String> arguments = const [],
    Map<String, String> environment = const {},
  }) : arguments = List.unmodifiable(arguments),
       environment = Map.unmodifiable(environment);

  /// The absolute executable path supplied by the native locator.
  final String executable;

  /// Fixed arguments, such as those of a development harness.
  final List<String> arguments;

  /// Environment additions confined to this child process.
  final Map<String, String> environment;
}

/// A completed result, valid only inside its consumer callback.
class MediaWorkerOutput {
  /// Creates a completed output within its owned working directory.
  MediaWorkerOutput(this.value, this.directory);

  /// The decoded native result.
  final Object? value;

  /// The directory retained until result consumption completes.
  final Directory directory;
}

/// A progress update from a particular task.
class MediaWorkerProgress {
  /// Creates a progress update.
  MediaWorkerProgress(this.taskId, this.value);

  /// The submitting caller's task identifier.
  final String taskId;

  /// Progress between zero and one. One means consumption also succeeded.
  final double value;
}

/// A classified failure that contains no native payload or diagnostic text.
class MediaWorkerFailure implements Exception {
  /// Creates a failure with a stable technical code.
  MediaWorkerFailure(this.code);

  /// The failure category, without paths or request contents.
  final String code;

  @override
  String toString() => 'MediaWorkerFailure($code)';
}

/// Owns bounded, sequential media jobs and all of their temporary artifacts.
///
/// Each job gets its own process. Cancellation kills that captured process and
/// waits for exit before removing files. Result consumption starts the
/// commit boundary: cancellation waits for that consumer instead of deleting
/// an artifact while it is being copied into caller-owned storage.
class MediaWorkerClient {
  /// Creates a client with an installed helper locator and temporary parent.
  MediaWorkerClient({
    required this.locate,
    required this.temporaryDirectory,
    Future<Process> Function(MediaWorkerCommand)? start,
    this.claimProcess,
    this.registryPath,
    this.onCleanupError,
  }) : _start = start ?? _startProcess;

  /// Resolves the installed helper without launching it.
  final Future<MediaWorkerCommand> Function() locate;

  /// Provides a temporary parent; only a fresh child created by this client
  /// is ever removed.
  final Future<Directory> Function() temporaryDirectory;

  /// Attaches a started process to the native app's lifetime before input.
  ///
  /// Windows uses its job object here. Linux installs the parent-death signal
  /// inside the helper before reading requests.
  final Future<void> Function(int pid)? claimProcess;

  /// Optional stable GStreamer plugin registry path reused across jobs.
  ///
  /// When omitted, the client allocates one temporary registry file and reuses
  /// it across jobs until [dispose].
  final String? registryPath;

  /// Optional callback invoked when temporary directory cleanup still fails
  /// after retries.
  final void Function(FileSystemException error)? onCleanupError;

  final Future<Process> Function(MediaWorkerCommand) _start;

  final _progress = StreamController<MediaWorkerProgress>.broadcast(sync: true);
  final _jobs = <String, _Job>{};
  Directory? _registryDirectory;
  Future<void> _tail = Future<void>.value();
  Future<void>? _disposing;

  /// Progress for all jobs, without native payloads or file paths.
  Stream<MediaWorkerProgress> get progress => _progress.stream;

  /// Executes a snapshot of a request and consumes its completed result.
  ///
  /// Each [onEvent] callback holds its completed frame until it returns. Only
  /// then does the helper receive acknowledgement and reuse that frame's file.
  Future<T> execute<T>(
    String method,
    Map<String, Object?> arguments, {
    required String taskId,
    required FutureOr<T> Function(MediaWorkerOutput) consume,
    FutureOr<void> Function(MediaWorkerOutput)? onEvent,
  }) {
    if (_disposing != null) {
      return Future.error(MediaWorkerFailure('disposed'));
    }
    if (_jobs.containsKey(taskId)) {
      return Future.error(MediaWorkerFailure('duplicate_task'));
    }
    // Snapshot before the first await: callers may reuse their mutable maps.
    final String snapshot;
    try {
      snapshot = jsonEncode(arguments);
    } on Object {
      return Future.error(MediaWorkerFailure('request'));
    }
    final result = Completer<T>();
    final job = _Job(taskId, () {
      result.completeError(MediaWorkerFailure('cancelled'));
    });
    _jobs[taskId] = job;
    _tail = _tail.then((_) async {
      if (job.cancelled) return;
      try {
        final value = await _run(job, method, snapshot, consume, onEvent);
        _progress.add(MediaWorkerProgress(job.id, 1));
        result.complete(value);
      } on Object catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        _retire(job);
      }
    });
    return result.future;
  }

  Future<T> _run<T>(
    _Job job,
    String method,
    String snapshot,
    FutureOr<T> Function(MediaWorkerOutput) consume,
    FutureOr<void> Function(MediaWorkerOutput)? onEvent,
  ) async {
    job.started = true;
    Directory? directory;
    _OwnedProcess? owned;
    Future<void>? outputDone;
    Future<void>? stderrDone;
    try {
      final command = await locate();
      job.checkCancelled();
      final parent = await temporaryDirectory();
      job.checkCancelled();
      directory = await parent.createTemp('divine-media-');
      job.checkCancelled();
      final registry = await _resolveRegistryPath();
      job.checkCancelled();
      final process = await _start(
        MediaWorkerCommand(
          command.executable,
          arguments: command.arguments,
          environment: {
            ...command.environment,
            'GST_REGISTRY_1_0': registry,
            'GST_REGISTRY_FORK': 'no',
          },
        ),
      );
      owned = _OwnedProcess(process);
      job.process = owned;
      final workspace = directory;
      final writer = owned;
      final response = _ResponseReader(
        process,
        (value) {
          if (!job.cancelled && value < 1) {
            _progress.add(MediaWorkerProgress(job.id, value));
          }
        },
        (sequence) =>
            writer.sendLine(jsonEncode({'protocol': 1, 'ack': sequence})),
        onEvent == null
            ? null
            : (value) async {
                job.checkCancelled();
                await onEvent(MediaWorkerOutput(value, workspace));
                job.checkCancelled();
              },
      );
      outputDone = response.done;
      // Diagnostics can contain input paths or metadata. Drain without keeping
      // or forwarding them; protocol errors expose classified codes only.
      stderrDone = process.stderr.drain<void>().then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          response.failTransport();
        },
      );
      job.checkCancelled();
      await claimProcess?.call(process.pid);
      job.checkCancelled();
      // Flushing the single request does not close stdin: EOF acknowledges a
      // result and allows the helper's parent-lifetime monitor to distinguish
      // an abandoned caller from a successfully consumed response.
      await writer.sendLine(
        jsonEncode({
          'protocol': 1,
          'method': method,
          'arguments': jsonDecode(snapshot),
          'workingDirectory': directory.path,
        }),
      );
      await response.ready.future;
      job.checkCancelled();
      if (response.failure != null) {
        if (response.eofWithoutResult) {
          // A closed output pipe does not prove the process has exited. Stop
          // the captured child before awaiting exit, even after clean EOF.
          await owned.stop();
          final exit = await owned.exitCode;
          if (exit != 0) throw MediaWorkerFailure('exit_$exit');
        }
        throw response.failure!;
      }
      await owned.closeInput();
      final exit = await owned.exitCode;
      await response.done;
      await stderrDone;
      job.checkCancelled();
      if (exit != 0) throw MediaWorkerFailure('exit_$exit');
      if (response.failure != null) throw response.failure!;
      job.consuming = true;
      final value = await consume(MediaWorkerOutput(response.value, directory));
      return value;
    } on Object catch (error, stack) {
      if (job.consuming || error is MediaWorkerFailure) {
        Error.throwWithStackTrace(error, stack);
      }
      if (job.cancelled) throw MediaWorkerFailure('cancelled');
      if (error is ProcessException) throw MediaWorkerFailure('launch');
      if (error is FileSystemException) throw MediaWorkerFailure('storage');
      throw MediaWorkerFailure('transport');
    } finally {
      if (owned != null) await owned.stop();
      await outputDone;
      await stderrDone;
      if (directory != null) {
        await _deleteTemporaryDirectory(directory);
      }
    }
  }

  Future<String> _resolveRegistryPath() async {
    final explicit = registryPath;
    if (explicit != null) return explicit;
    final existing = _registryDirectory;
    if (existing != null) return '${existing.path}/gstreamer-registry.bin';
    final created = await Directory.systemTemp.createTemp(
      'divine-media-registry-',
    );
    _registryDirectory = created;
    return '${created.path}/gstreamer-registry.bin';
  }

  Future<void> _deleteTemporaryDirectory(Directory directory) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await directory.delete(recursive: true);
        return;
      } on FileSystemException catch (error) {
        if (attempt == 2) {
          onCleanupError?.call(error);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// Cancels queued or native work and waits until its resources are released.
  Future<void> cancel(String taskId) async {
    final job = _jobs[taskId];
    if (job == null) return;
    if (!job.consuming) {
      job.cancelled = true;
      final process = job.process;
      process?.kill();
      if (!job.started) {
        job.rejectQueued();
        _retire(job);
      }
    }
    await job.done.future;
  }

  void _retire(_Job job) {
    if (identical(_jobs[job.id], job)) _jobs.remove(job.id);
    if (!job.done.isCompleted) job.done.complete();
  }

  /// Stops owned native work, waits for consumers, and closes progress.
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    await Future.wait(_jobs.keys.toList().map(cancel));
    await _tail;
    final registryDirectory = _registryDirectory;
    _registryDirectory = null;
    if (registryDirectory != null) {
      await _deleteTemporaryDirectory(registryDirectory);
    }
    await _progress.close();
  }
}

Future<Process> _startProcess(MediaWorkerCommand command) => Process.start(
  command.executable,
  command.arguments,
  environment: command.environment,
);

class _OwnedProcess {
  _OwnedProcess(this.process) {
    exitCode = process.exitCode.then((code) {
      _exited = true;
      return code;
    });
  }

  final Process process;
  late final Future<int> exitCode;
  bool _exited = false;
  Future<void>? _inputClose;
  Future<void> _inputTail = Future<void>.value();

  Future<void> sendLine(String line) {
    final writing = _inputTail.then((_) async {
      try {
        process.stdin.writeln(line);
        await process.stdin.flush();
      } on Object {
        throw MediaWorkerFailure('transport');
      }
    });
    // The returned future reports failures to its caller. The sequencing fork
    // still settles so cleanup can close the pipe after a failed write.
    _inputTail = writing.then<void>((_) {}, onError: (Object error) {});
    return writing;
  }

  Future<void> closeInput() => _inputClose ??= _closeInput();

  Future<void> _closeInput() async {
    await _inputTail;
    try {
      await process.stdin.close();
    } on Object {
      throw MediaWorkerFailure('transport');
    }
  }

  void kill() {
    if (!_exited) {
      process.kill(
        Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigkill,
      );
    }
  }

  Future<void> stop() async {
    kill();
    await exitCode;
    try {
      await closeInput();
    } on MediaWorkerFailure {
      // The task reports failed EOF; after exit the pipe may already be closed.
    }
  }
}

class _Job {
  _Job(this.id, this.rejectQueued);
  final String id;
  final void Function() rejectQueued;
  final done = Completer<void>();
  _OwnedProcess? process;
  bool started = false;
  bool cancelled = false;
  bool consuming = false;

  void checkCancelled() {
    if (cancelled) throw MediaWorkerFailure('cancelled');
  }
}

class _ResponseReader {
  _ResponseReader(
    Process process,
    void Function(double) progress,
    Future<void> Function(int) acknowledge,
    Future<void> Function(Object?)? onEvent,
  ) {
    done = _read(process.stdout, progress, acknowledge, onEvent);
  }

  final ready = Completer<void>();
  late final Future<void> done;
  final _buffer = <int>[];
  Object? value;
  MediaWorkerFailure? failure;
  bool _hasResult = false;
  bool eofWithoutResult = false;
  int _nextSequence = 1;

  Future<void> _read(
    Stream<List<int>> stream,
    void Function(double) progress,
    Future<void> Function(int) acknowledge,
    Future<void> Function(Object?)? onEvent,
  ) async {
    try {
      await for (final chunk in stream) {
        if (failure != null) break;
        for (final byte in chunk) {
          if (byte == 10) {
            await _readLine(
              utf8.decode(_buffer),
              progress,
              acknowledge,
              onEvent,
            );
            _buffer.clear();
          } else if (_buffer.length >= 65536) {
            throw const FormatException();
          } else {
            _buffer.add(byte);
          }
          if (failure != null) break;
        }
        if (failure != null) break;
      }
      eofWithoutResult = failure == null && !_hasResult && _buffer.isEmpty;
      if (_buffer.isNotEmpty || !_hasResult) _fail();
    } on Object catch (error) {
      if (error is MediaWorkerFailure) failure ??= error;
      _fail();
    }
  }

  Future<void> _readLine(
    String line,
    void Function(double) progress,
    Future<void> Function(int) acknowledge,
    Future<void> Function(Object?)? onEvent,
  ) async {
    final message = jsonDecode(line) as Map<String, dynamic>;
    if (message['protocol'] != 1 || _hasResult) throw const FormatException();
    switch (message['event']) {
      case 'progress':
        final value = (message['value'] as num).toDouble();
        if (!value.isFinite || value < 0 || value > 1) {
          throw const FormatException();
        }
        progress(value);
      case 'data':
        final sequence = message['sequence'];
        if (sequence is! int || sequence != _nextSequence || onEvent == null) {
          throw const FormatException();
        }
        try {
          await onEvent(message['value']);
        } on MediaWorkerFailure {
          rethrow;
        } on FileSystemException {
          throw MediaWorkerFailure('storage');
        } on FormatException {
          throw MediaWorkerFailure('protocol');
        } on Object {
          throw MediaWorkerFailure('consumer');
        }
        if (failure != null) return;
        await acknowledge(sequence);
        _nextSequence++;
      case 'error':
        const codes = {
          'request',
          'unsupported',
          'input',
          'decoder',
          'encoder',
          'storage',
          'cancelled',
          'internal',
        };
        final code = message['value'];
        if (code is! String || !codes.contains(code)) {
          throw const FormatException();
        }
        failure = MediaWorkerFailure(code);
        _hasResult = true;
        ready.complete();
      case 'result':
        value = message['value'];
        _hasResult = true;
        ready.complete();
      default:
        throw const FormatException();
    }
  }

  void failTransport() {
    failure ??= MediaWorkerFailure('transport');
    if (!ready.isCompleted) ready.complete();
  }

  void _fail() {
    failure ??= MediaWorkerFailure('protocol');
    if (!ready.isCompleted) ready.complete();
  }
}
