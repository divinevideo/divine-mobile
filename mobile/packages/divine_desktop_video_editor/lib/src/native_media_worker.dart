import 'dart:io';

import 'package:divine_desktop_video_editor/src/media_worker_client.dart';
import 'package:flutter/services.dart';

/// Resolves installed native media helpers and attaches them to app lifetime.
class NativeMediaWorker {
  /// Creates a bridge to the desktop plugin.
  NativeMediaWorker({
    this.channel = const MethodChannel('video.divine/desktop_media'),
  });

  /// The native locator and lifetime boundary.
  final MethodChannel channel;

  /// Locates a real bundled executable with a child-only runtime environment.
  Future<MediaWorkerCommand> locate() async {
    try {
      final result = await channel.invokeMapMethod<String, Object?>('locate');
      final executable = result?['executable'];
      if (executable is! String ||
          File(executable).absolute.path != executable ||
          FileSystemEntity.typeSync(executable) != FileSystemEntityType.file) {
        throw MediaWorkerFailure('locate');
      }
      final environment = result?['environment'] as Map<Object?, Object?>?;
      return MediaWorkerCommand(
        executable,
        environment: environment?.cast<String, String>() ?? const {},
      );
    } on Object {
      throw MediaWorkerFailure('locate');
    }
  }

  /// Claims a started child before it receives input or opens media.
  Future<void> claimProcess(int pid) async {
    if (pid <= 0) throw MediaWorkerFailure('ownership');
    try {
      await channel.invokeMethod<void>('claimProcess', pid);
    } on Object {
      throw MediaWorkerFailure('ownership');
    }
  }

  /// Creates a client whose native children are bound to this app instance.
  MediaWorkerClient createClient({
    required Future<Directory> Function() temporaryDirectory,
  }) => MediaWorkerClient(
    locate: locate,
    temporaryDirectory: temporaryDirectory,
    claimProcess: claimProcess,
  );
}
