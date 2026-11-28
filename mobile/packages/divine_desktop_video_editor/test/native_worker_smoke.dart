import 'dart:io';

import 'package:divine_desktop_video_editor/divine_desktop_video_editor.dart';
import 'package:divine_desktop_video_editor/src/media_worker_client.dart'
    show MediaWorkerCommand;
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import 'helpers/fixtures.dart';

// Run explicitly with the actual helper. This is kept outside default test
// discovery because native codec development libraries are a separate CI job.
void main() {
  const executable = String.fromEnvironment('DIVINE_MEDIA_WORKER');
  if (executable.isEmpty) {
    throw StateError('Provide DIVINE_MEDIA_WORKER for native transport tests.');
  }
  group('native media worker transport', () {
    test('exports through the existing editor SDK contract', () async {
      final parent = await Directory.systemTemp.createTemp('native SDK ');
      final editor = DesktopProVideoEditor(
        client: MediaWorkerClient(
          locate: () async => MediaWorkerCommand(executable),
          temporaryDirectory: () async => parent,
        ),
      );
      try {
        final destination = File.fromUri(parent.uri.resolve('sdk.mp4'));
        final source = EditorVideo.file(
          await fixtureFile('synthetic-colors.mp4'),
        );
        await editor.renderVideoToFile(
          destination.path,
          VideoRenderData(
            id: 'sdk-render',
            videoSegments: [
              VideoSegment(
                video: source,
                startTime: const Duration(milliseconds: 250),
                endTime: const Duration(milliseconds: 750),
              ),
            ],
            transform: const ExportTransform(flipX: true),
            maxFrameRate: 20,
          ),
        );
        final result = EditorVideo.file(destination);
        final metadata = await editor.getMetadata(result);
        expect(metadata.resolution.width, 128);
        expect(metadata.resolution.height, 240);
        expect(metadata.duration.inMilliseconds, closeTo(500, 60));
        expect(await editor.hasAudioTrack(result), isTrue);
        expect(parent.listSync().map((file) => file.path), [destination.path]);
      } finally {
        await editor.dispose();
        await parent.delete(recursive: true);
      }
    });

    test(
      'reads thumbnails and luma through the SDK and native transport',
      () async {
        final parent = await Directory.systemTemp.createTemp('native frames ');
        final editor = DesktopProVideoEditor(
          client: MediaWorkerClient(
            locate: () async => MediaWorkerCommand(executable),
            temporaryDirectory: () async => parent,
          ),
        );
        try {
          final video = EditorVideo.file(
            await fixtureFile('synthetic-colors.mp4'),
          );
          final configs = ThumbnailConfigs(
            video: video,
            outputSize: const Size(64, 64),
            outputFormat: ThumbnailFormat.png,
            boxFit: ThumbnailBoxFit.contain,
            timestamps: const [
              Duration(milliseconds: 100),
              Duration(milliseconds: 800),
            ],
          );
          final list = await editor.getThumbnails(configs);
          expect(list, hasLength(2));
          expect(list.first.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
          final frames = await editor.getThumbnailStream(configs).toList();
          expect(frames.map((frame) => frame.indices), [
            [0],
            [1],
          ]);
          expect(frames.first.bytes, list.first);
          expect(frames.last.bytes, list.last);
          final luma = await editor
              .getLumaFrameStream(
                LumaFrameConfigs(
                  video: video,
                  outputSize: const Size(63, 63),
                  startTime: const Duration(milliseconds: 200),
                  endTime: const Duration(milliseconds: 900),
                  maxFrameRate: 5,
                ),
              )
              .toList();
          expect(luma.map((frame) => frame.time.inMicroseconds), [
            200000,
            400000,
            600000,
            800000,
          ]);
          for (final frame in luma) {
            expect((frame.width, frame.height), (33, 63));
            expect(frame.bytes, hasLength(33 * 63));
            expect(
              frame.bytes[16 * 33 + 4],
              greaterThan(frame.bytes[16 * 33 + 28] + 20),
            );
          }
          expect(parent.listSync(), isEmpty);
        } finally {
          await editor.dispose();
          await parent.delete(recursive: true);
        }
      },
    );

    test(
      'exports and reads encoded output across the owned process boundary',
      () async {
        final parent = await Directory.systemTemp.createTemp(
          'native transport ',
        );
        final client = MediaWorkerClient(
          locate: () async => MediaWorkerCommand(executable),
          temporaryDirectory: () async => parent,
        );
        try {
          final source = (await fixtureFile('synthetic-colors.mp4')).path;
          final destination = File.fromUri(parent.uri.resolve('completed.mp4'));
          await client.execute(
            'renderVideo',
            {
              'videoClips': [
                {'inputPath': source, 'startUs': 250000, 'endUs': 750000},
              ],
              'flipX': true,
              'maxFrameRate': 20,
              'enableAudio': true,
            },
            taskId: 'render',
            consume: (output) async {
              final result = output.value! as Map<String, dynamic>;
              final encoded = File(result['path'] as String);
              expect(await encoded.length(), greaterThan(1000));
              await encoded.copy(destination.path);
            },
          );
          expect(parent.listSync().map((file) => file.path), [
            destination.path,
          ]);
          final metadata = await client.execute(
            'getMetadata',
            {
              'inputPath': destination.path,
            },
            taskId: 'read-export',
            consume: (output) => output.value! as Map<String, dynamic>,
          );
          expect(metadata['width'], 128);
          expect(metadata['height'], 240);
          expect(metadata['duration'], closeTo(500, 60));
          final hasAudio = await client.execute(
            'hasAudioTrack',
            {
              'inputPath': destination.path,
            },
            taskId: 'audio',
            consume: (output) => output.value,
          );
          expect(hasAudio, isTrue);
          expect(parent.listSync().map((file) => file.path), [
            destination.path,
          ]);
        } finally {
          await client.dispose();
          await parent.delete(recursive: true);
        }
      },
    );
  });
}
