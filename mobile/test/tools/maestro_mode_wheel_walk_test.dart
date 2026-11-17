// ABOUTME: Pins that Maestro helpers reach a recorder mode by walking the mode
// ABOUTME: wheel one entry at a time, in the order the app declares the modes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:yaml/yaml.dart';

const _maestroDir = 'e2e/maestro';

/// The mode whose wheel entry carries [id], or null for any other control.
VideoRecorderMode? _modeOf(Object? id) {
  for (final mode in VideoRecorderMode.values) {
    if (id == SemanticIds.cameraMode(mode.name)) return mode;
  }
  return null;
}

/// The modes whose wheel entries are tapped under [node], in the order
/// Maestro reaches them.
List<VideoRecorderMode> _wheelTaps(Object? node) {
  if (node is List) {
    return [for (final child in node) ..._wheelTaps(child)];
  }
  if (node is! YamlMap) return const [];

  final tap = node['tapOn'];
  final mode = _modeOf(tap is YamlMap ? tap['id'] : null);
  if (mode != null) return [mode];

  return [for (final child in node.values) ..._wheelTaps(child)];
}

/// The commands of [flow]: its last YAML document, after any config header.
Object? _commandsOf(File flow) {
  final documents = loadYamlDocuments(flow.readAsStringSync());
  return documents.isEmpty ? null : documents.last.contents.value;
}

void main() {
  group('Maestro mode-wheel walk', () {
    final files =
        Directory(_maestroDir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.yaml'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final walks = {
      for (final file in files) file.path: _wheelTaps(_commandsOf(file)),
    }..removeWhere((_, taps) => taps.isEmpty);

    test('still finds the helpers that select a mode', () {
      // Every check below skips a flow that taps no wheel entry, so an empty
      // set would pass them all for the wrong reason.
      expect(walks.keys, contains(endsWith('utils/openClassicMode.yaml')));
    });

    test('each helper taps every entry between Capture and its mode', () {
      for (final MapEntry(key: path, value: taps) in walks.entries) {
        final target = taps.last;
        expect(
          taps,
          orderedEquals(
            VideoRecorderMode.values.sublist(
              VideoRecorderMode.capture.index + 1,
              target.index + 1,
            ),
          ),
          reason:
              '$path selects ${target.name} starting from Capture, where the '
              'recorder opens after a clearState. The wheel is a lazy '
              'ListView that only builds entries near the armed one, so each '
              "tap has to land on the armed entry's neighbour: tap every "
              'entry in between, in the order VideoRecorderMode declares.',
        );
      }
    });
  });
}
